#!/usr/bin/env Rscript
# mcmcPainter Package Demo
# This script demonstrates the complete functionality of the mcmcPainter package

cat("mcmcPainter Package Demo\n")
cat("========================\n\n")

# Load the package functions
source("R/mcmcPainter.R")
source("R/mcmc_core.R") 
source("R/utilities.R")

# Compile the C++ code for performance
cat("Compiling C++ code...\n")
Rcpp::sourceCpp("src/mcmc_painter_cpp.cpp")
cat("C++ code compiled successfully!\n\n")

# Demo 1: Image Analysis and PNG Verification
cat("Demo 1: Image Analysis and PNG Verification\n")
cat("===========================================\n")
images <- c("inst/extdata/leaf_converted.png", "inst/extdata/iamami.png")

for (img_path in images) {
  cat("\nAnalyzing:", basename(img_path), "\n")
  cat("----------------------------------------\n")
  
  img_info <- get_image_info(img_path)
  
  cat("Dimensions:", img_info$width, "x", img_info$height, "pixels\n")
  cat("File size:", round(img_info$file_size / 1024, 1), "KB\n")
  cat("PNG verification:", ifelse(img_info$is_true_png, "✓ True PNG", "✗ Not a true PNG"), "\n")
  cat("Aspect ratio:", round(img_info$width / img_info$height, 3), "\n")
}

# Demo 2: Automatic MCMC Configuration
cat("\n\nDemo 2: Automatic MCMC Configuration\n")
cat("=====================================\n")

# Test with leaf image
leaf_path <- "inst/extdata/leaf_converted.png"
cat("\nLeaf Image - Standard Quality (max_dimension = 800):\n")
cat("----------------------------------------------------\n")
leaf_std <- auto_configure_mcmc(leaf_path, max_dimension = 800, target_iterations = 20000)

cat("\nLeaf Image - High Quality (max_dimension = 1200):\n")
cat("--------------------------------------------------\n")
leaf_hq <- auto_configure_mcmc(leaf_path, max_dimension = 1200, target_iterations = 30000)

# Test with iamami image
iamami_path <- "inst/extdata/iamami.png"
cat("\nIamami Image - Standard Quality (max_dimension = 800):\n")
cat("--------------------------------------------------------\n")
iamami_std <- auto_configure_mcmc(iamami_path, max_dimension = 800, target_iterations = 20000)

# Demo 3: Triptych Creation and Saving
cat("\n\nDemo 3: Triptych Creation and Saving\n")
cat("=====================================\n")

# Create triptych for leaf image
cat("Creating triptych for leaf image...\n")
target_img <- load_image_rgb(leaf_path, out_w = 400, out_h = 400)
H <- dim(target_img)[1]
W <- dim(target_img)[2]
default_canvas <- array(1, dim = c(H, W, 3))

# Create simulated best result for demonstration
set.seed(42)
simulated_best <- default_canvas + array(rnorm(H * W * 3, 0, 0.1), dim = c(H, W, 3))
simulated_best <- pmin(pmax(simulated_best, 0), 1)

# Create and display triptych
create_triptych(
  default_canvas = default_canvas,
  best_canvas = simulated_best,
  target_img = target_img,
  titles = c("Default Canvas", "Best Result", "Target Image"),
  main_title = "Leaf Image MCMC Progression"
)

# Save triptych
cat("Saving triptych...\n")
dir.create("inst/results/demo", showWarnings = FALSE, recursive = TRUE)

# Save as PDF
pdf_path <- "inst/results/demo/leaf_triptych.pdf"
save_triptych(
  default_canvas = default_canvas,
  best_canvas = simulated_best,
  target_img = target_img,
  output_path = pdf_path,
  width = 12, height = 5,
  titles = c("Default Canvas", "Best Result", "Target Image"),
  main_title = "Leaf Image MCMC Progression",
  format = "pdf"
)

# Save as PNG
png_path <- "inst/results/demo/leaf_triptych.png"
save_triptych(
  default_canvas = default_canvas,
  best_canvas = simulated_best,
  target_img = target_img,
  output_path = png_path,
  width = 12, height = 5,
  titles = c("Default Canvas", "Best Result", "Target Image"),
  main_title = "Leaf Image MCMC Progression",
  format = "png"
)

cat("Triptych saved:\n")
cat("- PDF:", pdf_path, "\n")
cat("- PNG:", png_path, "\n\n")

# Demo 4: Performance Analysis
cat("Demo 4: Performance Analysis\n")
cat("============================\n")

configs <- list(leaf_std, leaf_hq, iamami_std)
image_names <- c("Leaf (Standard)", "Leaf (High Quality)", "Iamami (Standard)")

for (i in seq_along(configs)) {
  config <- configs[[i]]
  name <- image_names[i]
  
  cat(name, "Image:\n")
  cat("--------\n")
  
  # Original vs scaled complexity
  original_pixels <- config$original_width * config$original_height
  scaled_pixels <- config$scaled_width * config$scaled_height
  
  cat("Original complexity:", format(original_pixels, big.mark = ","), "pixels\n")
  cat("Scaled complexity:", format(scaled_pixels, big.mark = ","), "pixels\n")
  cat("Complexity reduction:", round((1 - scaled_pixels/original_pixels) * 100, 1), "%\n")
  
  # Performance estimates
  estimated_memory_mb <- round(scaled_pixels * 3 * 8 / (1024 * 1024), 1)
  estimated_time_min <- round(config$iterations / 1000, 1)
  
  cat("Estimated memory:", estimated_memory_mb, "MB\n")
  cat("Estimated runtime:", estimated_time_min, "minutes\n")
  cat("Save frequency:", config$save_every, "iterations\n")
  cat("PNG verification:", ifelse(config$is_true_png, "✓ True PNG", "✗ Not a true PNG"), "\n\n")
}

# Demo 5: MCMC Options Summary
cat("Demo 5: MCMC Configuration Options\n")
cat("==================================\n")

cat("The mcmcPainter package provides three configuration modes:\n\n")

cat("1. Full Auto-Configuration (Recommended):\n")
cat("   run_line_painter(image_path, auto_config = TRUE)\n")
cat("   - Automatically determines all parameters\n")
cat("   - Optimizes for best performance\n")
cat("   - No manual configuration needed\n\n")

cat("2. Partial Auto-Configuration:\n")
cat("   run_line_painter(image_path, iters = 15000, auto_config = TRUE)\n")
cat("   - Override specific parameters\n")
cat("   - Keep auto-optimization for others\n")
cat("   - Balance of control and automation\n\n")

cat("3. Manual Configuration:\n")
cat("   run_line_painter(image_path, width = 512, height = 512, auto_config = FALSE)\n")
cat("   - Complete control over all parameters\n")
cat("   - Manual dimension specification\n")
cat("   - Custom iteration counts and save frequency\n\n")

cat("Demo completed successfully!\n")
cat("Check the results in inst/results/demo/\n")
cat("\nTo run actual MCMC:\n")
cat("source('create/create_leaf_triptych.R')  # For leaf image\n")
cat("source('create/create_iamami_triptych.R') # For iamami image\n")
cat("source('create/create_butterfly_triptych.R') # For butterfly image (100K steps)\n")
cat("source('create/create_me_triptych.R') # For me image (100K steps)\n")
cat("source('create/create_octopus_triptych.R') # For octopus image (100K steps)\n")
