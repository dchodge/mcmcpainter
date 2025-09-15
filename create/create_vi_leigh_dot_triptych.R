#!/usr/bin/env Rscript
# Create Dot Painting Triptych for vi_leigh.png
# Demonstrates the new dot-based MCMC painter on a portrait image

cat("mcmcPainter: Dot Painting Demo - vi_leigh.png\n")
cat("============================================\n\n")

# Load the package functions
source("R/mcmcPainter.R")
source("R/dot_painter_main.R")

# Compile the C++ code for performance
cat("Compiling C++ code...\n")
Rcpp::sourceCpp("src/dot_painter_cpp.cpp")
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

# Configuration for dot painting
cat("Dot Painting Configuration:\n")
cat("==========================\n")
cat("Target iterations: 20,000\n")
cat("Save frequency: Every 1,000 iterations\n")
cat("Max dimension: 800 (optimized for dots)\n")
cat("Expected runtime: 30-60 minutes\n")
cat("Style: Pointillism portrait artwork\n\n")

# Run dot painting MCMC
cat("Starting dot painting MCMC...\n")
cat("This will create a beautiful pointillism-style portrait!\n\n")

res <- run_dot_painter(
  image_path = image_path,
  max_dimension = 800,        # Optimized for dots
  iters = 20000,              # 20K iterations
  out_dir = "inst/results/vi_leigh_dot_painting",
  seed = 42,
  auto_config = TRUE,         # Enable auto-configuration
  verbose = TRUE
)

cat("\n🎨 Dot painting completed successfully!\n")
cat("=====================================\n")
cat("Final number of dots:", length(res$dots), "\n")
cat("Best iteration:", res$best$iter, "\n")
cat("Best SSE:", round(res$best$sse, 2), "\n")

# Create triptych visualization
cat("\nCreating dot painting triptych...\n")
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
create_dot_triptych(
  default_canvas = default_canvas,
  best_canvas = res$best$canvas,
  target_img = target_img,
  titles = c("Default (White Canvas)", "Best Dot Painting Result", "True vi_leigh Image"),
  main_title = "vi_leigh Portrait: Dot Painting Progression"
)

# Save triptych in multiple formats
cat("Saving triptych...\n")
output_dir <- "inst/results/vi_leigh_dot_painting"

# Save as PDF
pdf_path <- file.path(output_dir, "vi_leigh_dot_triptych.pdf")
save_dot_triptych(
  default_canvas = default_canvas,
  best_canvas = res$best$canvas,
  target_img = target_img,
  output_path = pdf_path,
  width = 15, height = 6,
  titles = c("Default (White Canvas)", "Best Dot Painting Result", "True vi_leigh Image"),
  main_title = "vi_leigh Portrait: Dot Painting Progression",
  format = "pdf"
)

# Save as PNG
png_path <- file.path(output_dir, "vi_leigh_dot_triptych.png")
save_dot_triptych(
  default_canvas = default_canvas,
  best_canvas = res$best$canvas,
  target_img = target_img,
  output_path = png_path,
  width = 15, height = 6,
  titles = c("Default (White Canvas)", "Best Dot Painting Result", "True vi_leigh Image"),
  main_title = "vi_leigh Portrait: Dot Painting Progression",
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
cat("Number of dots:", length(res$dots), "\n")

# Display dot statistics
cat("\nDot Statistics:\n")
cat("===============\n")
dots <- res$dots
radii <- sapply(dots, function(d) d$radius)
alphas <- sapply(dots, function(d) d$alpha)
colors <- do.call(rbind, lapply(dots, function(d) d$col))

cat("Total dots:", length(dots), "\n")
cat("Mean radius:", round(mean(radii), 2), "pixels\n")
cat("Radius range:", round(min(radii), 2), "-", round(max(radii), 2), "pixels\n")
cat("Mean alpha:", round(mean(alphas), 3), "\n")
cat("Alpha range:", round(min(alphas), 3), "-", round(max(alphas), 3), "\n")
cat("Mean colors (R,G,B):", 
    round(mean(colors[,1]), 3), ",",
    round(mean(colors[,2]), 3), ",",
    round(mean(colors[,3]), 3), "\n")

# Display optimization summary
cat("\nOptimization Summary:\n")
cat("====================\n")
cat("Original dimensions:", img_info$width, "x", img_info$height, "\n")
cat("Final dimensions:", W, "x", H, "\n")
cat("Total iterations:", 20000, "\n")
cat("Save frequency:", 1000, "\n")
cat("PNG verification:", ifelse(img_info$is_true_png, "✓ True PNG", "✗ Not a true PNG"), "\n")

# List all saved iterations
cat("\nSaved Iterations:\n")
cat("=================\n")
iter_files <- list.files(output_dir, pattern = "iter_.*\\.png", full.names = FALSE)
iter_files <- sort(iter_files)
for (file in iter_files) {
  cat("-", file, "\n")
}

cat("\n🎨 Dot painting demo completed!\n")
cat("Check the results in:", output_dir, "\n")
cat("The triptych shows the progression from white canvas to final dot artwork.\n")
cat("This creates a beautiful pointillism-style portrait using thousands of dots!\n")

# Print detailed analysis
cat("\n" %+% "="*50 %+% "\n")
print_dot_summary(res)
