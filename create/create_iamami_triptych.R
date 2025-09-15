#!/usr/bin/env Rscript
# Create Iamami Triptych: MCMC Line Painting Demo with Auto-Configuration
# This script automatically analyzes the iamami.png image and runs MCMC with optimized parameters

# Load the package functions
source("R/mcmcArt.R")
source("R/mcmc_core.R") 
source("R/utilities.R")

# Compile the C++ code for performance
cat("Compiling C++ code...\n")
Rcpp::sourceCpp("src/mcmc_painter_cpp.cpp")
cat("C++ code compiled successfully!\n\n")

# Analyze the iamami image automatically
image_path <- "inst/extdata/iamami.png"
cat("Analyzing image:", basename(image_path), "\n")
cat("=====================================\n")

img_analysis <- auto_configure_mcmc(image_path, max_dimension = 800, target_iterations = 20000)

# Load the target image with optimized dimensions
cat("\nLoading target image with optimized dimensions...\n")
target_img <- load_image_rgb(image_path, 
                            out_w = img_analysis$scaled_width, 
                            out_h = img_analysis$scaled_height)

cat("Image loaded successfully!\n")
cat("Final dimensions:", dim(target_img)[2], "x", dim(target_img)[1], "pixels\n\n")

# Create default white canvas
H <- dim(target_img)[1]
W <- dim(target_img)[2]
default_canvas <- array(1, dim = c(H, W, 3))  # White background

# Run MCMC with automatically configured parameters
cat("Starting MCMC run with optimized parameters...\n")
cat("Iterations:", img_analysis$iterations, "\n")
cat("Dimensions:", img_analysis$scaled_width, "x", img_analysis$scaled_height, "\n")
cat("This may take several minutes depending on your system.\n\n")

res <- run_line_painter(
  image_path = image_path,
  width = img_analysis$scaled_width, 
  height = img_analysis$scaled_height,
  iters = img_analysis$iterations,
  out_dir = "inst/results/iamami_optimized",
  seed = 42
)

cat("\nMCMC completed successfully!\n")
cat("Final number of lines:", length(res$lines), "\n")
cat("Best iteration:", res$best$iter, "\n")
cat("Best SSE:", round(res$best$sse, 2), "\n")

# Function to create triptych
create_triptych <- function(default_canvas, best_canvas, target_img, 
                           titles = c("Default (White Canvas)", "Best MCMC Result", "True Image")) {
  
  # Set up the plotting area
  par(mfrow = c(1, 3), mar = c(2, 2, 3, 2), oma = c(0, 0, 2, 0))
  
  # Plot 1: Default white canvas
  plot.new()
  rasterImage(default_canvas, 0, 0, 1, 1)
  title(main = titles[1], cex.main = 1.2, font.main = 2)
  
  # Plot 2: Best MCMC result
  plot.new()
  rasterImage(best_canvas, 0, 0, 1, 1)
  title(main = titles[2], cex.main = 1.2, font.main = 2)
  
  # Plot 3: True target image
  plot.new()
  rasterImage(target_img, 0, 0, 1, 1)
  title(main = titles[3], cex.main = 1.2, font.main = 2)
  
  # Overall title
  mtext("MCMC Line Painting: Iamami Image Progression", 
        outer = TRUE, line = 0, cex = 1.5, font = 2)
}

# Create the triptych
cat("\nCreating triptych visualization...\n")
create_triptych(default_canvas, res$best$canvas, target_img)

# Save the triptych
cat("Saving triptych to PDF...\n")
pdf("inst/results/iamami_optimized/iamami_triptych.pdf", width = 15, height = 6)
create_triptych(default_canvas, res$best$canvas, target_img)
dev.off()

# Save the triptych as PNG
cat("Saving triptych to PNG...\n")
png("inst/results/iamami_optimized/iamami_triptych.png", width = 1500, height = 600, res = 150)
create_triptych(default_canvas, res$best$canvas, target_img)
dev.off()

cat("\nTriptych saved successfully!\n")
cat("Files created:\n")
cat("- inst/results/iamami_optimized/iamami_triptych.pdf\n")
cat("- inst/results/iamami_optimized/iamami_triptych.png\n")
cat("- All MCMC iteration files in inst/results/iamami_optimized/\n")

# Display performance metrics
cat("\nPerformance Metrics:\n")
cat("==================\n")
sse <- sum((target_img - res$best$canvas)^2)
mse <- sse / length(target_img)
psnr <- 20 * log10(1 / sqrt(mse))
cat("Best SSE:", round(sse, 2), "\n")
cat("Best MSE:", round(mse, 6), "\n")
cat("Best PSNR:", round(psnr, 2), "dB\n")
cat("Number of lines:", length(res$lines), "\n")

# Display optimization summary
cat("\nOptimization Summary:\n")
cat("====================\n")
cat("Original dimensions:", img_analysis$original_width, "x", img_analysis$original_height, "\n")
cat("Scaled dimensions:", img_analysis$scaled_width, "x", img_analysis$scaled_height, "\n")
cat("Scaling factor:", round(img_analysis$scale_factor, 3), "\n")
cat("PNG verification:", ifelse(img_analysis$is_true_png, "✓ True PNG", "✗ Not a true PNG"), "\n")
cat("Complexity reduction:", round((1 - (img_analysis$scaled_width * img_analysis$scaled_height) / (img_analysis$original_width * img_analysis$original_height)) * 100, 1), "%\n")

cat("\nDemo completed successfully! Check the results in inst/results/iamami_optimized/\n")
cat("The automatic configuration optimized the parameters for best performance!\n")
