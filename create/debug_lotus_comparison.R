#!/usr/bin/env Rscript
# Debug script to run lotus image with fixed seed for comparison
# This will allow comparing R implementation with web frontend

library(mcmcPainter)

# Fixed parameters for reproducibility
SEED <- 42
MAX_DIM <- 400  # Small for fast debugging
ITERS <- 1000   # Small number for debugging
SAVE_EVERY <- 100

cat("===========================================\n")
cat("MCMC Debug Run: Lotus Image\n")
cat("===========================================\n")
cat("Seed:", SEED, "\n")
cat("Max dimension:", MAX_DIM, "\n")
cat("Iterations:", ITERS, "\n")
cat("Save frequency:", SAVE_EVERY, "\n")
cat("===========================================\n\n")

# Path to lotus image
image_path <- "../inst/extdata/lotus.png"

if (!file.exists(image_path)) {
  stop("Lotus image not found at: ", image_path)
}

# Output directory
out_dir <- "../inst/results/lotus_debug_comparison"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Run with EXACT parameters
res <- run_line_painter(
  image_path = image_path,
  max_dimension = MAX_DIM,
  iters = ITERS,
  out_dir = out_dir,
  seed = SEED,
  auto_config = FALSE,  # Use exact parameters, no auto-config
  save_every = SAVE_EVERY,
  verbose = TRUE
)

# Get actual dimensions used
target <- load_image_rgb(image_path, out_w = res$dimensions[1], out_h = res$dimensions[2])
H <- dim(target)[1]
W <- dim(target)[2]

cat("\n===========================================\n")
cat("Run Complete!\n")
cat("===========================================\n")
cat("Final dimensions:", W, "x", H, "\n")
cat("Final number of lines:", length(res$lines), "\n")
cat("Final SSE:", sum((target - res$canvas)^2), "\n")
cat("Best SSE:", res$best$sse, "\n")
cat("Best iteration:", res$best$iter, "\n")
cat("Output directory:", out_dir, "\n")
cat("===========================================\n\n")

# Save detailed parameters to file for web comparison
params <- list(
  seed = SEED,
  width = W,
  height = H,
  iters = ITERS,
  beta_init = 0.1,
  beta_final = 2.0,
  K_lambda = 0.5 * W,
  prob_moves = c(birth = 0.25, death = 0.25, jitter = 0.45, swap = 0.05),
  final_lines = length(res$lines),
  final_sse = sum((target - res$canvas)^2),
  best_sse = res$best$sse,
  best_iter = res$best$iter
)

# Save parameters as JSON for easy comparison
jsonlite::write_json(params, file.path(out_dir, "run_parameters.json"), 
                     pretty = TRUE, auto_unbox = TRUE)

# Save first few lines for detailed comparison
if (length(res$lines) > 0) {
  # Save detailed line info
  lines_df <- data.frame(
    line_id = 1:min(10, length(res$lines)),
    x1 = sapply(res$lines[1:min(10, length(res$lines))], function(l) l$x1),
    y1 = sapply(res$lines[1:min(10, length(res$lines))], function(l) l$y1),
    x2 = sapply(res$lines[1:min(10, length(res$lines))], function(l) l$x2),
    y2 = sapply(res$lines[1:min(10, length(res$lines))], function(l) l$y2),
    w = sapply(res$lines[1:min(10, length(res$lines))], function(l) l$w),
    alpha = sapply(res$lines[1:min(10, length(res$lines))], function(l) l$alpha),
    r = sapply(res$lines[1:min(10, length(res$lines))], function(l) l$col[1]),
    g = sapply(res$lines[1:min(10, length(res$lines))], function(l) l$col[2]),
    b = sapply(res$lines[1:min(10, length(res$lines))], function(l) l$col[3])
  )
  
  write.csv(lines_df, file.path(out_dir, "first_10_lines.csv"), row.names = FALSE)
  cat("Saved first", nrow(lines_df), "lines to CSV for comparison\n")
}

# Create a step-by-step trace for first 50 iterations
cat("\n===========================================\n")
cat("Running detailed trace (first 50 iters)\n")
cat("===========================================\n")

# Re-run with detailed logging
set.seed(SEED)
target <- load_image_rgb(image_path, out_w = W, out_h = H)

trace_file <- file.path(out_dir, "detailed_trace.txt")
trace_conn <- file(trace_file, "w")

writeLines("Iteration,Move,Accepted,K,SSE,Beta", trace_conn)

# Simulate first 50 iterations manually to trace
canvas <- array(1, dim = c(H, W, 3))
lines <- list()
K <- 0

beta_sched <- function(t, iters) 0.1 * ((2.0 / 0.1) ^ (t / iters))

for (t in 1:50) {
  beta <- beta_sched(t, ITERS)
  
  # Sample move type
  prob_moves <- c(birth = 0.25, death = 0.25, jitter = 0.45, swap = 0.05)
  mtype <- sample(names(prob_moves), size = 1, prob = prob_moves)
  
  sse_before <- sum((target - canvas)^2)
  accepted <- FALSE
  
  if (mtype == "birth") {
    prop <- sample_line_birth_datadriven(target, canvas)
    lp_new <- log_prior_line(prop, W, H)
    
    if (is.finite(lp_new)) {
      bbox <- line_bbox(prop$x1, prop$y1, prop$x2, prop$y2, prop$w, W, H, pad = 2)
      canvas_prop <- composite_line_in_bbox(canvas, prop, bbox)
      
      log_acc <- log_lik_change_from_bbox(target, canvas, canvas_prop, bbox, beta) +
        lp_new + log_prior_K(K + 1, lambda = 0.5 * W) - log_prior_K(K, lambda = 0.5 * W) +
        log(1 / (K + 1 + 1e-12))
      
      if (log(runif(1)) < log_acc) {
        lines[[length(lines) + 1]] <- prop
        canvas <- canvas_prop
        K <- K + 1L
        accepted <- TRUE
      }
    }
  } else if (mtype == "death" && K > 0) {
    j <- sample.int(K, 1)
    rem <- lines[[j]]
    
    bbox <- line_bbox(rem$x1, rem$y1, rem$x2, rem$y2, rem$w, W, H, pad = 2)
    lines_wo <- if (K == 1) list() else lines[-j]
    canvas_prop <- re_render_bbox_from_lines(canvas, lines_wo, bbox)
    
    lp_rem <- log_prior_line(rem, W, H)
    log_acc <- log_lik_change_from_bbox(target, canvas, canvas_prop, bbox, beta) +
      log_prior_K(K - 1, lambda = 0.5 * W) - log_prior_K(K, lambda = 0.5 * W) -
      lp_rem + log((K + 1e-12))
    
    if (log(runif(1)) < log_acc) {
      lines <- lines_wo
      canvas_vec <- render_full_canvas_cpp(lines, H, W)
      canvas <- array(canvas_vec, dim = c(H, W, 3))
      K <- K - 1L
      accepted <- TRUE
    }
  } else if (mtype == "jitter" && K > 0) {
    j <- sample.int(K, 1)
    cur <- lines[[j]]
    prop <- jitter_line(cur, W, H)
    
    b1 <- line_bbox(cur$x1, cur$y1, cur$x2, cur$y2, cur$w, W, H)
    b2 <- line_bbox(prop$x1, prop$y1, prop$x2, prop$y2, prop$w, W, H)
    bbox <- list(
      xmin = max(1, min(b1$xmin, b2$xmin)),
      xmax = min(W, max(b1$xmax, b2$xmax)),
      ymin = max(1, min(b1$ymin, b2$ymin)),
      ymax = min(H, max(b1$ymax, b2$ymax))
    )
    
    lines_wo <- if (K == 1) list() else lines[-j]
    canvas_wo <- re_render_bbox_from_lines(canvas, lines_wo, bbox)
    canvas_prop <- composite_line_in_bbox(canvas_wo, prop, bbox)
    
    lp_cur <- log_prior_line(cur, W, H)
    lp_new <- log_prior_line(prop, W, H)
    
    if (is.finite(lp_new) && is.finite(lp_cur)) {
      log_acc <- log_lik_change_from_bbox(target, canvas, canvas_prop, bbox, beta) +
        (lp_new - lp_cur)
      
      if (log(runif(1)) < log_acc) {
        lines[[j]] <- prop
        canvas_vec <- render_full_canvas_cpp(lines, H, W)
        canvas <- array(canvas_vec, dim = c(H, W, 3))
        accepted <- TRUE
      }
    }
  } else if (mtype == "swap" && K > 1) {
    perm <- sample.int(K, K, replace = FALSE)
    lines_prop <- lines[perm]
    canvas_vec <- render_full_canvas_cpp(lines_prop, H, W)
    canv_prop <- array(canvas_vec, dim = c(H, W, 3))
    
    sse_old <- sum((target - canvas)^2)
    sse_new <- sum((target - canv_prop)^2)
    log_acc <- -beta * (sse_new - sse_old)
    
    if (log(runif(1)) < log_acc) {
      lines <- lines_prop
      canvas <- canv_prop
      accepted <- TRUE
    }
  }
  
  sse_after <- sum((target - canvas)^2)
  
  # Write trace
  line_out <- sprintf("%d,%s,%s,%d,%.4f,%.6f", t, mtype, accepted, K, sse_after, beta)
  writeLines(line_out, trace_conn)
  
  if (t %% 10 == 0) {
    cat("Traced iteration", t, "- K:", K, "SSE:", round(sse_after, 2), "\n")
  }
}

close(trace_conn)

cat("\n===========================================\n")
cat("Detailed trace saved to:", trace_file, "\n")
cat("===========================================\n")

cat("\n\nTo compare with web frontend:\n")
cat("1. Copy lotus.png to web_frontend/public/\n")
cat("2. Update web frontend to use same seed (42) and parameters\n")
cat("3. Run for 1000 iterations with same image dimensions (", W, "x", H, ")\n")
cat("4. Compare SSE values, line counts, and visual output\n")
cat("5. Check detailed_trace.txt for move-by-move comparison\n")


