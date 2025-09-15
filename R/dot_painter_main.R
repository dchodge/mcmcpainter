#' Run Dot Painter MCMC
#' 
#' Main function to run MCMC dot painting on an image. This creates artistic
#' representations using dots of varying radius, alpha, and color.
#' 
#' @param image_path Path to the target image
#' @param width Output width (if NULL, auto-configured)
#' @param height Output height (if NULL, auto-configured)
#' @param iters Number of MCMC iterations
#' @param out_dir Output directory for results
#' @param seed Random seed for reproducibility
#' @param auto_config Enable automatic parameter configuration
#' @param max_dimension Maximum dimension for auto-configuration
#' @param save_every Save progress every N iterations
#' @param verbose Print progress information
#' @return List with MCMC results
#' @export
run_dot_painter <- function(image_path, width = NULL, height = NULL,
                           iters = 20000, out_dir = NULL, seed = 42,
                           auto_config = TRUE, max_dimension = 800,
                           save_every = 1000, verbose = TRUE) {
  
  # Load required functions
  source("R/dot_painter.R")
  source("R/dot_mcmc_core.R")
  
  # Load and compile C++ code
  if (verbose) cat("Loading dot painter C++ code...\n")
  load_dot_painter_cpp()
  
  # Auto-configure if requested
  if (auto_config) {
    if (verbose) cat("Auto-configuring MCMC parameters...\n")
    config <- auto_configure_mcmc(image_path, max_dimension, iters)
    
    # Use auto-configured dimensions if not specified
    width <- width %||% config$scaled_width
    height <- height %||% config$scaled_height
    
    if (verbose) {
      cat("  Dimensions:", width, "x", height, "\n")
      cat("  Iterations:", config$iterations, "\n")
      cat("  Save frequency:", config$save_every, "\n")
    }
    
    # Update parameters
    iters <- config$iterations
    save_every <- config$save_every
  }
  
  # Set default dimensions if not specified
  if (is.null(width) || is.null(height)) {
    width <- width %||% 256
    height <- height %||% 256
  }
  
  # Set default output directory
  if (is.null(out_dir)) {
    out_dir <- file.path("inst/results", 
                        paste0("dot_painter_", format(Sys.time(), "%Y%m%d_%H%M%S")))
  }
  
  if (verbose) {
    cat("Dot Painter Configuration:\n")
    cat("==========================\n")
    cat("Image:", basename(image_path), "\n")
    cat("Dimensions:", width, "x", height, "\n")
    cat("Iterations:", iters, "\n")
    cat("Save frequency:", save_every, "\n")
    cat("Output directory:", out_dir, "\n\n")
  }
  
  # Load and resize target image
  target <- load_image_rgb(image_path, out_w = width, out_h = height)
  
  if (verbose) {
    cat("Starting MCMC dot painting...\n")
    cat("Target image loaded:", dim(target)[2], "x", dim(target)[1], "\n\n")
  }
  
  # Run MCMC
  results <- rjmcmc_dot_paint(
    target = target,
    iters = iters,
    out_dir = out_dir,
    seed = seed,
    save_every = save_every,
    verbose = verbose
  )
  
  # Add metadata
  results$image_path <- image_path
  results$dimensions <- c(width, height)
  results$auto_config <- auto_config
  
  if (verbose) {
    cat("\n🎨 Dot painting completed!\n")
    cat("==========================\n")
    cat("Final dots:", length(results$dots), "\n")
    cat("Best iteration:", results$best$iter, "\n")
    cat("Best SSE:", round(results$best$sse, 2), "\n")
    cat("Results saved to:", out_dir, "\n")
  }
  
  results
}

#' Create Dot Painting Triptych
#' 
#' Create a triptych visualization showing the progression from white canvas
#' to final dot painting result.
#' 
#' @param default_canvas White canvas (starting point)
#' @param best_canvas Best MCMC result
#' @param target_img Target image
#' @param titles Panel titles
#' @param main_title Main plot title
#' @export
create_dot_triptych <- function(default_canvas, best_canvas, target_img,
                                titles = c("Default (White Canvas)", "Best MCMC Result", "Target Image"),
                                main_title = "Dot Painting Progression") {
  
  # Set up plotting
  op <- par(mar = c(2, 2, 4, 2), mfrow = c(1, 3))
  on.exit(par(op))
  
  # Plot default canvas
  plot.new()
  rasterImage(default_canvas, 0, 0, 1, 1)
  title(titles[1], cex.main = 1.2)
  
  # Plot best result
  plot.new()
  rasterImage(best_canvas, 0, 0, 1, 1)
  title(titles[2], cex.main = 1.2)
  
  # Plot target image
  plot.new()
  rasterImage(target_img, 0, 0, 1, 1)
  title(titles[3], cex.main = 1.2)
  
  # Add main title
  mtext(main_title, side = 3, line = -2, outer = TRUE, cex = 1.5, font = 2)
}

#' Save Dot Painting Triptych
#' 
#' Save the dot painting triptych to PDF or PNG format.
#' 
#' @param default_canvas White canvas
#' @param best_canvas Best MCMC result
#' @param target_img Target image
#' @param output_path Output file path
#' @param width Figure width
#' @param height Figure height
#' @param titles Panel titles
#' @param main_title Main plot title
#' @param format Output format ("pdf" or "png")
#' @export
save_dot_triptych <- function(default_canvas, best_canvas, target_img,
                              output_path, width = 15, height = 6,
                              titles = c("Default (White Canvas)", "Best MCMC Result", "Target Image"),
                              main_title = "Dot Painting Progression",
                              format = "pdf") {
  
  if (format == "pdf") {
    pdf(output_path, width = width, height = height)
  } else if (format == "png") {
    png_width <- round(width * 150)
    png_height <- round(height * 150)
    png(output_path, width = png_width, height = png_height, res = 150)
  } else {
    stop("Format must be 'pdf' or 'png'")
  }
  
  create_dot_triptych(default_canvas, best_canvas, target_img, titles, main_title)
  dev.off()
  
  invisible(NULL)
}

#' Analyze Dot Painting Results
#' 
#' Analyze the results of a dot painting MCMC run.
#' 
#' @param results Results from run_dot_painter
#' @return Analysis summary
#' @export
analyze_dot_results <- function(results) {
  
  # Calculate metrics
  target <- results$target
  best_canvas <- results$best$canvas
  
  sse <- sum((target - best_canvas)^2)
  mse <- sse / length(target)
  psnr <- 20 * log10(1 / sqrt(mse))
  
  # Dot statistics
  dots <- results$dots
  radii <- sapply(dots, function(d) d$radius)
  alphas <- sapply(dots, function(d) d$alpha)
  colors <- do.call(rbind, lapply(dots, function(d) d$col))
  
  # Analysis
  analysis <- list(
    performance = list(
      sse = sse,
      mse = mse,
      psnr = psnr,
      iterations = results$iterations,
      best_iteration = results$best$iter
    ),
    dots = list(
      count = length(dots),
      mean_radius = mean(radii),
      sd_radius = sd(radii),
      mean_alpha = mean(alphas),
      sd_alpha = sd(alphas),
      color_stats = list(
        mean_r = mean(colors[,1]),
        mean_g = mean(colors[,2]),
        mean_b = mean(colors[,3])
      )
    ),
    dimensions = results$dimensions,
    image_path = results$image_path
  )
  
  analysis
}

#' Print Dot Painting Summary
#' 
#' Print a formatted summary of dot painting results.
#' 
#' @param results Results from run_dot_painter
#' @export
print_dot_summary <- function(results) {
  
  analysis <- analyze_dot_results(results)
  
  cat("🎨 Dot Painting Results Summary\n")
  cat("==============================\n")
  cat("Image:", basename(analysis$image_path), "\n")
  cat("Dimensions:", analysis$dimensions[1], "x", analysis$dimensions[2], "\n")
  cat("Iterations:", analysis$iterations, "\n")
  cat("Best iteration:", analysis$best_iteration, "\n\n")
  
  cat("Performance Metrics:\n")
  cat("--------------------\n")
  cat("SSE:", round(analysis$performance$sse, 2), "\n")
  cat("MSE:", round(analysis$performance$mse, 6), "\n")
  cat("PSNR:", round(analysis$performance$psnr, 2), "dB\n\n")
  
  cat("Dot Statistics:\n")
  cat("----------------\n")
  cat("Total dots:", analysis$dots$count, "\n")
  cat("Mean radius:", round(analysis$dots$mean_radius, 2), "pixels\n")
  cat("Radius SD:", round(analysis$dots$sd_radius, 2), "pixels\n")
  cat("Mean alpha:", round(analysis$dots$mean_alpha, 3), "\n")
  cat("Alpha SD:", round(analysis$dots$sd_alpha, 3), "\n")
  cat("Mean colors (R,G,B):", 
      round(analysis$dots$color_stats$mean_r, 3), ",",
      round(analysis$dots$color_stats$mean_g, 3), ",",
      round(analysis$dots$color_stats$mean_b, 3), "\n")
}
