#' RJ-MCMC Line Painting Core Algorithm
#' 
#' This file contains the core MCMC algorithm functions for line painting.

#' Main RJ-MCMC sampler for line-based painting
#' @param target_img Target image array
#' @param iters Number of iterations
#' @param beta_init Initial beta value
#' @param beta_final Final beta value
#' @param prob_moves Move probabilities
#' @param K_lambda Prior on number of lines
#' @param save_every Save frequency
#' @param out_dir Output directory
#' @param seed Random seed
#' @param verbose Verbose output
#' @return List with results
#' @export
rjmcmc_line_paint <- function(target_img,
                              iters      = 80000,
                              beta_init  = 0.1,
                              beta_final = 2.0,
                              prob_moves = c(birth=0.25, death=0.25, jitter=0.45, swap=0.05),
                              K_lambda   = 120,
                              save_every = 5000,
                              out_dir    = "mcmc_out",
                              seed       = 42,
                              verbose    = TRUE) {

  set.seed(seed)
  H <- dim(target_img)[1]; W <- dim(target_img)[2]

  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  canvas <- array(1, dim = c(H, W, 3))  # white background
  lines <- list()
  K <- 0L

  # Save initial state (iteration 0) - white canvas with no lines
  if (save_every > 0) {
    save_png(canvas, file.path(out_dir, "iter_000000.png"))
    if (verbose) cat(sprintf("[iter 0] K=%d, beta=%.3f, SSE=%.2f (initial white canvas)\n", K, beta_init, sum((target_img - canvas)^2)))
  }

  # Track best (MAP) by SSE
  sse_full <- sum((target_img - canvas)^2)
  best <- list(sse = sse_full, canvas = canvas, lines = lines, iter = 0)

  # convenience
  beta_sched <- function(t) beta_init * ( (beta_final / beta_init) ^ (t / iters) )

  # Helper to compute full SSE occasionally
  full_sse <- function() sum((target_img - canvas)^2)

  for (t in 1:iters) {
    if (verbose && t %% 100 == 0) cat("t: ", t, "\n")
    beta <- beta_sched(t)
    mtype <- sample(names(prob_moves), size = 1, prob = prob_moves)

    if (mtype == "birth") {
      # Propose new line
      prop <- sample_line_birth_datadriven(target_img, canvas)

      lp_new <- log_prior_line(prop, W, H)

      if (is.finite(lp_new)) {
        bbox <- line_bbox(prop$x1, prop$y1, prop$x2, prop$y2, prop$w, W, H, pad = 2)
        # compose in bbox
        canvas_prop <- composite_line_in_bbox(canvas, prop, bbox)

        # RJ ratio: L(new)*p(theta_new)*p(K+1) / [L(old)*p(K)] * [q_death / q_birth]
        # We use symmetric death choice (1/(K+1)) and treat q_birth approx constant (data-driven)
        # => include  log p(theta_new) + log p(K+1) - log p(K) + log( (1/(K+1)) / c ) .
        # We'll ignore constant q_birth c in both birth/death for simplicity; sampler still valid.
        log_acc <- log_lik_change_from_bbox(target_img, canvas, canvas_prop, bbox, beta) +
          lp_new + log_prior_K(K + 1, lambda = K_lambda) - log_prior_K(K, lambda = K_lambda) +
          log(1 / (K + 1 + 1e-12)) # death will pick 1 of K+1 lines

        if (log(runif(1)) < log_acc) {
          # accept
          lines[[length(lines) + 1]] <- prop
          canvas <- canvas_prop
          K <- K + 1L
        }
      }
    } else if (mtype == "death" && K > 0) {

      j <- sample.int(K, 1)
      rem <- lines[[j]]

      # Re-render bbox WITHOUT this line (and with the others)
      bbox <- line_bbox(rem$x1, rem$y1, rem$x2, rem$y2, rem$w, W, H, pad = 2)
      # Build a temp line list excluding j
      lines_wo <- if (K == 1) list() else lines[-j]
      canvas_prop <- re_render_bbox_from_lines(canvas, lines_wo, bbox) # start from current canvas in bbox

      lp_rem <- log_prior_line(rem, W, H)
      log_acc <- log_lik_change_from_bbox(target_img, canvas, canvas_prop, bbox, beta) +
        log_prior_K(K - 1, lambda = K_lambda) - log_prior_K(K, lambda = K_lambda) -
        lp_rem + log((K + 1e-12))  # inverse of birth's 1/(K+1)

      if (log(runif(1)) < log_acc) {
        # accept: commit removal
        lines <- lines_wo
        # We must update the whole canvas, since bbox re-render used blank base for bbox.
        # Easiest is to re-render entire canvas from scratch using all lines (still fast enough).
        # Now using C++ version for much faster performance
        canvas_vec <- render_full_canvas_cpp(lines, H, W)
        canvas <- array(canvas_vec, dim = c(H, W, 3))
        K <- K - 1L
      }
    } else if (mtype == "jitter" && K > 0) {

      j <- sample.int(K, 1)
      cur <- lines[[j]]
      prop <- jitter_line(cur, W, H)

      # bbox union of before/after
      b1 <- line_bbox(cur$x1, cur$y1, cur$x2, cur$y2, cur$w, W, H)
      b2 <- line_bbox(prop$x1, prop$y1, prop$x2, prop$y2, prop$w, W, H)
      bbox <- list(
        xmin = max(1, min(b1$xmin, b2$xmin)),
        xmax = min(W, max(b1$xmax, b2$xmax)),
        ymin = max(1, min(b1$ymin, b2$ymin)),
        ymax = min(H, max(b1$ymax, b2$ymax))
      )

      # Re-render bbox without current line j, then add proposed
      # 1) remove current j in bbox (render bbox from all lines except j)
      lines_wo <- if (K == 1) list() else lines[-j]
      canvas_wo <- re_render_bbox_from_lines(canvas, lines_wo, bbox)
      # 2) add proposed line in bbox
      canvas_prop <- composite_line_in_bbox(canvas_wo, prop, bbox)

      lp_cur <- log_prior_line(cur, W, H)
      lp_new <- log_prior_line(prop, W, H)
      if (is.finite(lp_new) && is.finite(lp_cur)) {
        log_acc <- log_lik_change_from_bbox(target_img, canvas, canvas_prop, bbox, beta) +
          (lp_new - lp_cur) # symmetric proposal
        if (log(runif(1)) < log_acc) {
          # accept
          lines[[j]] <- prop
          # Commit bbox to full canvas: easiest rebuild full canvas (keeps code simple)
          # Now using C++ version for much faster performance
          canvas_vec <- render_full_canvas_cpp(lines, H, W)
          canvas <- array(canvas_vec, dim = c(H, W, 3))
        }
      }
    } else if (mtype == "swap" && K > 1) {
      # Our renderer is order-agnostic because we redraw fresh each time;
      # with proper alpha stacking, order can matter. Here we skip order effects,
      # or you can randomly permute lines and accept if SSE improves.
      # We'll implement a no-op or occasional small random permutation:
      perm <- sample.int(K, K, replace = FALSE)
      lines_prop <- lines[perm]
      # Re-render full canvas to evaluate effect
      # Now using C++ version for much faster performance
      canvas_vec <- render_full_canvas_cpp(lines_prop, H, W)
      canv_prop <- array(canvas_vec, dim = c(H, W, 3))
      
      sse_old <- sum((target_img - canvas)^2)
      sse_new <- sum((target_img - canv_prop)^2)
      log_acc <- -beta * (sse_new - sse_old)
      if (log(runif(1)) < log_acc) {
        lines <- lines_prop
        canvas <- canv_prop
      }
    }

    # Track best by SSE occasionally (cheap full scan every 250 iters)
    if (t %% 250 == 0) {
      sse_full <- full_sse()
      if (sse_full < best$sse) {
        best <- list(sse = sse_full, canvas = canvas, lines = lines, iter = t)
      }
    }

    # Save snapshots
    if (save_every > 0 && t %% save_every == 0) {
      save_png(canvas, file.path(out_dir, sprintf("iter_%06d.png", t)))
      if (verbose) cat(sprintf("[iter %d] K=%d, beta=%.3f, SSE=%.2f\n", t, length(lines), beta, sum((target_img - canvas)^2)))
    }
  }

  list(canvas = canvas, lines = lines, best = best)
}
