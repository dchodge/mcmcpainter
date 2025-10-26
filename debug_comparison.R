# Debug comparison: R vs Web Frontend
# This script runs the MCMC algorithm with specific parameters and logs outputs

library(png)

# Source the R functions
source("R/mcmcPainter.R")
source("R/mcmc_core.R")
source("R/utilities.R")

# Compile C++ code
cat("Compiling C++ code...\n")
Rcpp::sourceCpp("src/mcmc_painter_cpp.cpp")

# Load lotus image
image_path <- "inst/extdata/lotus.png"
cat("\n=== Loading Image ===\n")

# Load at a small size for fast debugging
target <- load_image_rgb(image_path, out_w = 200, out_h = 200)
cat("Image dimensions:", dim(target), "\n")
cat("Image range:", range(target), "\n")

# Set seed for reproducibility
set.seed(42)

# Run a short MCMC for debugging (100 iterations)
cat("\n=== Running MCMC (100 iterations) ===\n")
res <- rjmcmc_line_paint(
  target_img = target,
  iters      = 100,
  beta_init  = 0.1,
  beta_final = 2.0,
  prob_moves = c(birth=0.25, death=0.25, jitter=0.45, swap=0.05),
  K_lambda   = 0.5 * 200,  # 0.5 * width
  save_every = 25,
  out_dir    = "debug_output",
  seed       = 42,
  verbose    = TRUE
)

# Save detailed debug info
cat("\n=== Debug Output ===\n")
cat("Final number of lines:", length(res$lines), "\n")
cat("Best SSE:", res$best$sse, "\n")
cat("Best iteration:", res$best$iter, "\n")
cat("Final SSE:", res$sse, "\n")

# Save the best canvas
save_png(res$best$canvas, "debug_output/r_best_canvas.png")
cat("Saved R canvas to: debug_output/r_best_canvas.png\n")

# Print first few lines for comparison
cat("\n=== First 5 lines (if any) ===\n")
if (length(res$lines) > 0) {
  for (i in 1:min(5, length(res$lines))) {
    line <- res$lines[[i]]
    cat(sprintf("Line %d: x1=%.2f, y1=%.2f, x2=%.2f, y2=%.2f, w=%.2f, alpha=%.3f, r=%.3f, g=%.3f, b=%.3f\n",
                i, line$x1, line$y1, line$x2, line$y2, line$w, line$alpha, line$col[1], line$col[2], line$col[3]))
  }
}

# Save target image for comparison
save_png(target, "debug_output/target.png")
cat("\nSaved target image to: debug_output/target.png\n")

# Create a side-by-side comparison
png("debug_output/comparison.png", width=600, height=200)
par(mfrow=c(1,3), mar=c(2,2,3,2))
plot.new()
rasterImage(array(1, dim=dim(target)), 0, 0, 1, 1)
title("Initial (White)")
plot.new()
rasterImage(res$best$canvas, 0, 0, 1, 1)
title(sprintf("R Result (K=%d)", length(res$lines)))
plot.new()
rasterImage(target, 0, 0, 1, 1)
title("Target")
dev.off()

cat("\nSaved comparison to: debug_output/comparison.png\n")
cat("\n=== Parameters for Web Frontend ===\n")
cat("Image size: 200x200\n")
cat("Seed: 42\n")
cat("Iterations: 100\n")
cat("Beta init: 0.1\n")
cat("Beta final: 2.0\n")
cat("K_lambda: 100\n")
cat("Update every: 25\n")
cat("\nRun the web frontend with these EXACT parameters and compare outputs!\n")

