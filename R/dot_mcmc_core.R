#' RJMCMC Dot Painting Algorithm
#' 
#' This implements the core MCMC algorithm for dot painting using Reversible Jump MCMC.
#' The algorithm can add, remove, and modify dots to minimize the sum of squared errors.

#' @importFrom stats runif
NULL

#' RJMCMC Dot Painting Algorithm
#' 
#' @param target Target image array [H, W, 3]
#' @param iters Number of MCMC iterations
#' @param out_dir Output directory for saving results
#' @param seed Random seed
#' @param save_every Save progress every N iterations
#' @param verbose Print progress
#' @return List with final results
#' @export
rjmcmc_dot_paint <- function(target, iters = 20000, out_dir = "inst/results/dot_painter",
                             seed = 42, save_every = 1000, verbose = TRUE) {
  
  # Set seed for reproducibility
  set.seed(seed)
  
  # Create output directory
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }
  
  # Get dimensions
  H <- dim(target)[1]
  W <- dim(target)[2]
  
  # Initialize canvas (white)
  canvas <- array(1, dim = c(H, W, 3))
  
  # Initialize dots list
  dots <- list()
  K <- 0
  
  # Initialize best state
  best <- list(
    dots = dots,
    canvas = canvas,
    sse = sum((target - canvas)^2),
    iter = 0
  )
  
  # Save initial state (iteration 0) - white canvas with no dots
  if (save_every > 0) {
    save_png(canvas, file.path(out_dir, "iter_000000.png"))
  }
  
  # MCMC parameters
  beta <- 0.01  # Temperature parameter (balanced)
  K_lambda <- 200  # Prior mean for number of dots
  
  # Progress tracking
  if (verbose) {
    cat("Starting RJMCMC dot painting...\n")
    cat("Target dimensions:", W, "x", H, "\n")
    cat("Iterations:", iters, "\n")
    cat("Save frequency:", save_every, "\n\n")
  }
  
  for (iter in 1:iters) {
    
    # Progress indicator
    if (verbose && iter %% 100 == 0) {
      cat("t:", iter, "\n")
    }
    
    # Propose new dot - favor birth when K is low
    birth_prob <- ifelse(K == 0, 0.9, 0.5)  # 90% birth when no dots, 50% otherwise
    if (runif(1) < birth_prob) {
      # Birth move - use simple random proposal for now
      prop <- sample_dot_prior(W, H)
      lp_new <- log_prior_dot(prop, W, H)
      
      # Calculate acceptance ratio for birth
      # Ratio = (likelihood_new * prior_new * proposal_death) / (likelihood_old * prior_old * proposal_birth)
      # proposal_birth = 1, proposal_death = 1/K if K > 0, else 1
      proposal_ratio <- ifelse(K > 0, 1/K, 1)
      
      # Calculate likelihood change
      bbox <- dot_bbox(prop$x, prop$y, prop$radius, W, H)
      canvas_prop <- composite_dot_bbox(canvas, prop$x, prop$y, prop$radius, prop$alpha, prop$col, bbox)
      ll_change <- log_lik_change_from_bbox_dots(target, canvas, canvas_prop, bbox, beta)
      
      log_ratio <- lp_new + ll_change + log(proposal_ratio)
      
      if (log(runif(1)) < log_ratio) {
        # Accept birth
        dots <- c(dots, list(prop))
        K <- K + 1
        
        # Update canvas with new dot
        canvas <- canvas_prop
      }
    } else {
      # Death move
      if (K > 0) {
        j <- sample(1:K, 1)
        
        # Re-render bbox WITHOUT this dot (and with the others)
        bbox <- dot_bbox(dots[[j]]$x, dots[[j]]$y, dots[[j]]$radius, W, H)
        canvas_wo <- re_render_bbox_from_dots(canvas, dots[-j], bbox)
        
        # Calculate acceptance ratio for death
        # Ratio = (likelihood_new * prior_new * proposal_birth) / (likelihood_old * prior_old * proposal_death)
        # proposal_death = 1/K, proposal_birth = 1
        proposal_ratio <- K
        lp_old <- log_prior_dot(dots[[j]], W, H)
        
        # Calculate likelihood change
        ll_change <- log_lik_change_from_bbox_dots(target, canvas, canvas_wo, bbox, beta)
        
        log_ratio <- -lp_old + ll_change + log(proposal_ratio)
        
        if (log(runif(1)) < log_ratio) {
          # Accept death
          dots <- dots[-j]
          K <- K - 1
          canvas <- canvas_wo
        }
      }
    }
    
    # Jitter move (modify existing dot)
    if (K > 0) {
      j <- sample(1:K, 1)
      
      # Propose jittered dot
      prop <- jitter_dot(dots[[j]], W, H)
      
      # Re-render bbox without current dot j, then add proposed
      bbox <- dot_bbox(dots[[j]]$x, dots[[j]]$y, dots[[j]]$radius, W, H)
      canvas_wo <- re_render_bbox_from_dots(canvas, dots[-j], bbox)
      canvas_prop <- composite_dot_bbox(canvas_wo, prop$x, prop$y, prop$radius, prop$alpha, prop$col, bbox)
      
      # Calculate acceptance ratio
      lp_old <- log_prior_dot(dots[[j]], W, H)
      lp_new <- log_prior_dot(prop, W, H)
      
      # Calculate likelihood change
      ll_change <- log_lik_change_from_bbox_dots(target, canvas, canvas_prop, bbox, beta)
      
      log_ratio <- lp_new - lp_old + ll_change
      
      if (log(runif(1)) < log_ratio) {
        # Accept jitter
        dots[[j]] <- prop
        canvas <- canvas_prop
      }
    }
    
    # Update best state
    current_sse <- sum((target - canvas)^2)
    if (current_sse < best$sse) {
      best <- list(
        dots = dots,
        canvas = canvas,
        sse = current_sse,
        iter = iter
      )
    }
    
    # Save progress
    if (save_every > 0 && iter %% save_every == 0) {
      filename <- sprintf("iter_%06d.png", iter)
      save_png(canvas, file.path(out_dir, filename))
      
      if (verbose) {
        cat(sprintf("[iter %d] K=%d, beta=%.3f, SSE=%.2f\n", 
                   iter, K, beta, current_sse))
      }
    }
    
    # Adaptive temperature
    if (iter %% 1000 == 0) {
      beta <- min(0.1, beta * 1.005)  # Gradually increase temperature
    }
  }
  
  # Save final results
  save_png(canvas, file.path(out_dir, "final.png"))
  save_png(best$canvas, file.path(out_dir, sprintf("best_iter_%06d.png", best$iter)))
  
  # Save dot data
  saveRDS(dots, file.path(out_dir, "final_dots.RData"))
  saveRDS(best$dots, file.path(out_dir, "best_dots.RData"))
  
  if (verbose) {
    cat("\nMCMC completed!\n")
    cat("Final number of dots:", K, "\n")
    cat("Best iteration:", best$iter, "\n")
    cat("Best SSE:", round(best$sse, 2), "\n")
    cat("Results saved to:", out_dir, "\n")
  }
  
  # Return results
  list(
    dots = dots,
    canvas = canvas,
    best = best,
    target = target,
    out_dir = out_dir,
    iterations = iters
  )
}
