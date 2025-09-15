#!/usr/bin/env Rscript
# Create Line Painting Triptych for vi_leigh.png
# High-quality 100K iteration MCMC line painting

cat("mcmcPainter: Line Painting Demo - vi_leigh.png (100K steps)\n")
cat("========================================================\n\n")

# Load the package functions
source("R/mcmcPainter.R")
source("R/mcmc_core.R")
source("R/utilities.R")

# Compile the C++ code for performance
cat("Compiling C++ code...\n")
Rcpp::sourceCpp("src/mcmc_painter_cpp.cpp")
cat("C++ code compiled successfully!\n\n")

# Analyze the target image
image_path <- "inst/extdata/vi_leigh.png"
cat("Analyzing image:", basename(image_path), "\n")
cat("=====================================\n")

img_info <- get_image_info(image_path)
cat("File:", basename(image_path), "\n")
cat("Original dimensions:", img_info$width, "x", img_info$height, "pixels\n")
cat("File size:", round(img_info$file_size / 1024, 1), "KB\n")
cat("PNG verification:", ifelse(img_info$is_true_png, "✓ True PNG", "✗ Not a true PNG"), "\n")
cat("Aspect ratio:", round(img_info$width / img_info$height, 3), "\n\n")

# Configuration for high-quality line painting
cat("High-Quality Line Painting Configuration:\n")
cat("=======================================\n")
cat("Target iterations: 100,000\n")
cat("Save frequency: Every 5,000 iterations\n")
cat("Max dimension: 1200 (high quality)\n")
cat("Expected runtime: 3-5 hours\n")
cat("Style: High-quality line artwork\n\n")

# Run line painting MCMC
cat("Starting high-quality line painting MCMC...\n")
cat("This will create a detailed line artwork with 100K iterations!\n\n")

res <- run_line_painter(
  image_path = image_path,
  max_dimension = 1200,        # High quality
  iters = 100000,              # 100K iterations
  out_dir = "inst/results/vi_leigh_line_painting_100k",
  seed = 42,
  auto_config = TRUE,          # Enable auto-configuration
  save_every = 5000,           # Save every 5K iterations
  verbose = TRUE
)

cat("\n🎨 High-quality line painting completed successfully!\n")
cat("==================================================\n")
cat("Final number of lines:", length(res$lines), "\n")
cat("Best iteration:", res$best$iter, "\n")
cat("Best SSE:", round(res$best$sse, 2), "\n")

# Create triptych visualization
cat("\nCreating line painting triptych...\n")
cat("==================================\n")

# Load the final image with the same dimensions used in MCMC
target_img <- load_image_rgb(image_path, 
                            out_w = res$dimensions[1], 
                            out_h = res$dimensions[2])

# Create default white canvas
H <- dim(target_img)[1]
W <- dim(target_img)[2]
default_canvas <- array(1, dim = c(H, W, 3))

# Create triptych
create_triptych(
  default_canvas = default_canvas,
  best_canvas = res$best$canvas,
  target_img = target_img,
  titles = c("Default (White Canvas)", "Best Line Painting Result", "True vi_leigh Image"),
  main_title = "vi_leigh Portrait: High-Quality Line Painting Progression"
)

# Save triptych in multiple formats
cat("Saving triptych...\n")
output_dir <- "inst/results/vi_leigh_line_painting_100k"

# Save as PDF
pdf_path <- file.path(output_dir, "vi_leigh_line_triptych.pdf")
save_triptych(
  default_canvas = default_canvas,
  best_canvas = res$best$canvas,
  target_img = target_img,
  output_path = pdf_path,
  width = 15, height = 6,
  titles = c("Default (White Canvas)", "Best Line Painting Result", "True vi_leigh Image"),
  main_title = "vi_leigh Portrait: High-Quality Line Painting Progression",
  format = "pdf"
)

# Save as PNG
png_path <- file.path(output_dir, "vi_leigh_line_triptych.png")
save_triptych(
  default_canvas = default_canvas,
  best_canvas = res$best$canvas,
  target_img = target_img,
  output_path = png_path,
  width = 15, height = 6,
  titles = c("Default (White Canvas)", "Best Line Painting Result", "True vi_leigh Image"),
  main_title = "vi_leigh Portrait: High-Quality Line Painting Progression",
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

# Display line statistics
cat("\nLine Statistics:\n")
cat("================\n")
lines <- res$lines
thicknesses <- sapply(lines, function(l) l$w)
alphas <- sapply(lines, function(l) l$alpha)

cat("Total lines:", length(lines), "\n")
cat("Mean thickness:", round(mean(thicknesses), 2), "pixels\n")
cat("Thickness range:", round(min(thicknesses), 2), "-", round(max(thicknesses), 2), "pixels\n")
cat("Mean alpha:", round(mean(alphas), 3), "\n")
cat("Alpha range:", round(min(alphas), 3), "-", round(max(alphas), 3), "\n")

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

cat("\n🎨 High-quality line painting demo completed!\n")
cat("Check the results in:", output_dir, "\n")
cat("The triptych shows the progression from white canvas to final line artwork.\n")
cat("With 100K iterations, you should see incredible detail in facial features and expressions!\n")

# Print detailed analysis
cat("\n" %+% "="*50 %+% "\n")
if (exists("print_line_summary")) {
  print_line_summary(res)
}

