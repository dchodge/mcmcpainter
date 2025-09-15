#!/usr/bin/env Rscript
# Create Octopus Triptych with 100K MCMC Steps
# High-quality run for maximum detail and artistic quality

cat("mcmcPainter: Octopus 100K MCMC Run\n")
cat("===================================\n\n")

# Load the package functions
source("R/mcmcPainter.R")
source("R/mcmc_core.R") 
source("R/utilities.R")

# Compile the C++ code for performance
cat("Compiling C++ code...\n")
Rcpp::sourceCpp("src/mcmc_painter_cpp.cpp")
cat("C++ code compiled successfully!\n\n")

# Analyze the octopus image
image_path <- "inst/extdata/octopus.png"
cat("Analyzing image:", basename(image_path), "\n")
cat("=====================================\n")

img_info <- get_image_info(image_path)
cat("File:", basename(image_path), "\n")
cat("Original dimensions:", img_info$width, "x", img_info$height, "pixels\n")
cat("File size:", round(img_info$file_size / 1024, 1), "KB\n")
cat("PNG verification:", ifelse(img_info$is_true_png, "✓ True PNG", "✗ Not a true PNG"), "\n")
cat("Aspect ratio:", round(img_info$width / img_info$height, 3), "\n\n")

# High-quality configuration for 100K steps
cat("High-Quality Configuration:\n")
cat("==========================\n")
cat("Target iterations: 100,000\n")
cat("Save frequency: Every 5,000 iterations\n")
cat("Max dimension: 1200 (high resolution)\n")
cat("Expected runtime: 3-5 hours (depending on system)\n\n")

# Run MCMC with high-quality settings
cat("Starting high-quality MCMC run for octopus...\n")
cat("This will take several hours. Progress will be saved every 5,000 iterations.\n\n")

res <- run_line_painter(
  image_path = image_path,
  max_dimension = 1200,        # High resolution
  iters = 100000,              # 100K iterations
  out_dir = "inst/results/octopus_100k_high_quality",
  seed = 42,
  auto_config = TRUE,          # Enable auto-configuration
  verbose = TRUE
)

cat("\n🎉 MCMC completed successfully!\n")
cat("===============================\n")
cat("Final number of lines:", length(res$lines), "\n")
cat("Best iteration:", res$best$iter, "\n")
cat("Best SSE:", round(res$best$sse, 2), "\n")

# Create triptych visualization
cat("\nCreating triptych visualization...\n")
cat("==================================\n")

# Load the final image with the same dimensions used in MCMC
target_img <- load_image_rgb(image_path, 
                            out_w = dim(res$canvas)[2], 
                            out_h = dim(res$canvas)[1])

# Create default white canvas
H <- dim(target_img)[1]
W <- dim(target_img)[2]
default_canvas <- array(1, dim = c(H, W, 3))

# Create triptych
create_triptych(
  default_canvas = default_canvas,
  best_canvas = res$best$canvas,
  target_img = target_img,
  titles = c("Default (White Canvas)", "Best MCMC Result (100K steps)", "True Octopus Image"),
  main_title = "Octopus Image: 100K MCMC Progression"
)

# Save triptych in multiple formats
cat("Saving triptych...\n")
output_dir <- "inst/results/octopus_100k_high_quality"

# Save as PDF
pdf_path <- file.path(output_dir, "octopus_100k_triptych.pdf")
save_triptych(
  default_canvas = default_canvas,
  best_canvas = res$best$canvas,
  target_img = target_img,
  output_path = pdf_path,
  width = 18, height = 7,  # Larger for high-quality output
  titles = c("Default (White Canvas)", "Best MCMC Result (100K steps)", "True Octopus Image"),
  main_title = "Octopus Image: 100K MCMC Progression",
  format = "pdf"
)

# Save as PNG
png_path <- file.path(output_dir, "octopus_100k_triptych.png")
save_triptych(
  default_canvas = default_canvas,
  best_canvas = res$best$canvas,
  target_img = target_img,
  output_path = png_path,
  width = 18, height = 7,  # Larger for high-quality output
  titles = c("Default (White Canvas)", "Best MCMC Result (100K steps)", "True Octopus Image"),
  main_title = "Octopus Image: 100K MCMC Progression",
  format = "png"
)

cat("Triptych saved successfully!\n")
cat("Files created:\n")
cat("- PDF:", pdf_path, "\n")
cat("- PNG:", png_path, "\n")

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
cat("Original dimensions:", img_info$width, "x", img_info$height, "\n")
cat("Final dimensions:", W, "x", H, "\n")
cat("Total iterations:", 100000, "\n")
cat("Save frequency:", 5000, "\n")
cat("PNG verification:", ifelse(img_info$is_true_png, "✓ True PNG", "✗ Not a true PNG"), "\n")

# List all saved iterations
cat("\nSaved Iterations:\n")
cat("=================\n")
iter_files <- list.files(output_dir, pattern = "iter_.*\\.png", full.names = FALSE)
iter_files <- sort(iter_files)
for (file in iter_files) {
  cat("-", file, "\n")
}

cat("\n🐙 High-quality octopus MCMC run completed!\n")
cat("Check the results in:", output_dir, "\n")
cat("The triptych shows the progression from white canvas to final artwork.\n")
cat("With 100K iterations, you should see incredible detail in the tentacles and texture!\n")
