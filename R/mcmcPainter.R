#' MCMC Line Painting Art Generation Package
#' 
#' This package provides functions to generate artistic line paintings using 
#' Reversible Jump MCMC algorithms with automatic image analysis and optimization.
#' 
#' @docType package
#' @name mcmcPainter
#' @useDynLib mcmcPainter, .registration = TRUE
#' @importFrom Rcpp sourceCpp
NULL

#' Load and resize image to RGB format
#' 
#' @param path Path to the image file
#' @param out_w Output width in pixels
#' @param out_h Output height in pixels
#' @return Array of dimensions [H, W, 3] with values in [0,1]
#' @export
load_image_rgb <- function(path, out_w = 256, out_h = 256) {
  # Try fast PNG path when the file is a real PNG
  ext <- tolower(tools::file_ext(path))
  if (ext == "png") {
    # If png::readPNG fails (wrongly named file), fall back to magick
    x <- try(.load_png_as_rgb(path), silent = TRUE)
    if (!inherits(x, "try-error")) {
      # Resize via magick to keep behavior consistent
      img <- magick::image_read(path)
      img <- magick::image_resize(img, sprintf("%dx%d!", out_w, out_h))
      arr <- as.integer(magick::image_data(img, channels = "rgb"))
      # magick actually returns [height x width x channels] directly, no need for aperm
      arr <- arr / 255
      return(arr)
    }
  }
  
  # Fallback to magick for non-PNG files
  img <- magick::image_read(path)
  img <- magick::image_resize(img, sprintf("%dx%d!", out_w, out_h))
  arr <- as.integer(magick::image_data(img, channels = "rgb"))
  # magick actually returns [height x width x channels] directly, no need for aperm
  # arr is already in [height x width x channels] format
  arr <- arr / 255
  return(arr)
}

#' Fast PNG loading helper function
#' @param path Path to PNG file
#' @return Array in [H, W, 3] format
#' @keywords internal
.load_png_as_rgb <- function(path) {
  x <- png::readPNG(path)                  # gray [H,W], RGB [H,W,3], RGBA [H,W,4]
  d <- dim(x)
  if (length(d) == 2) {                    # grayscale -> RGB
    out <- array(0, dim = c(d[1], d[2], 3))
    out[,,1] <- x; out[,,2] <- x; out[,,3] <- x
    return(out)
  } else if (d[3] == 3) return(x)          # already RGB
  else if (d[3] == 4) return(x[,,1:3, drop = FALSE])  # drop alpha
  stop("Unexpected PNG shape")
}

#' Save array as PNG image
#' @param arr Array to save
#' @param path Output file path
#' @export
save_png <- function(arr, path) {
  # arr: [H,W,3] numeric in [0,1]
  if (length(dim(arr)) == 2) {
    png::writePNG(arr, target = path)
    return(invisible(NULL))
  }
  # writePNG expects [H,W,4] (RGBA) or [H,W,3]; we give [H,W,3]
  png::writePNG(arr, target = path)
}

#' View RGB array as image
#' @param arr RGB array to display
#' @export
view_rgb <- function(arr) {
  stopifnot(length(dim(arr)) == 3 && dim(arr)[3] == 3)
  op <- par(mar = c(0,0,0,0), xaxs = "i", yaxs = "i")
  on.exit(par(op))
  plot.new()
  rasterImage(arr, 0, 0, 1, 1)
}

#' Get image dimensions and verify PNG file
#' @param image_path Path to the image file
#' @return List with width, height, and PNG verification status
#' @export
get_image_info <- function(image_path) {
  # Check if file exists
  if (!file.exists(image_path)) {
    stop("Image file not found: ", image_path)
  }
  
  # Get file extension
  ext <- tolower(tools::file_ext(image_path))
  
  # Initialize variables
  width <- NULL
  height <- NULL
  is_true_png <- FALSE
  
  # Try to read PNG header for true PNG files
  if (ext == "png") {
    tryCatch({
      # Read PNG header using png package
      png_info <- png::readPNG(image_path, info = TRUE)
      is_true_png <- TRUE
      width <- attr(png_info, "info")$width
      height <- attr(png_info, "info")$height
      
      # If dimensions are still NULL, fall back to magick
      if (is.null(width) || is.null(height)) {
        img <- magick::image_read(image_path)
        info <- magick::image_info(img)
        width <- info$width
        height <- info$height
      }
    }, error = function(e) {
      # If png::readPNG fails, it's not a true PNG
      is_true_png <- FALSE
      # Fall back to magick for dimensions
      img <- magick::image_read(image_path)
      info <- magick::image_info(img)
      width <<- info$width
      height <<- info$height
    })
  } else {
    # For non-PNG files, use magick
    img <- magick::image_read(image_path)
    info <- magick::image_info(img)
    width <- info$width
    height <- info$height
  }
  
  # Return image information
  list(
    width = width,
    height = height,
    is_true_png = is_true_png,
    file_extension = ext,
    file_size = file.size(image_path)
  )
}

#' Auto-Configure MCMC Parameters
#'
#' Automatically determines optimal MCMC parameters based on image analysis.
#' Analyzes image dimensions, complexity, and file properties to suggest
#' appropriate canvas size, iteration count, and save frequency.
#'
#' @param image_path Character string. Path to the target image file
#' @param max_dimension Integer. Maximum dimension (width or height) to scale to (default: 800)
#' @param target_iterations Integer. Target number of MCMC iterations (default: 20000)
#' 
#' @return A list containing:
#' \item{width}{Recommended canvas width in pixels}
#' \item{height}{Recommended canvas height in pixels}
#' \item{iters}{Recommended number of MCMC iterations}
#' \item{save_every}{Recommended save frequency}
#' \item{scale_factor}{Scaling factor applied to original image}
#' \item{original_dimensions}{Original image dimensions [width, height]}
#' \item{file_size}{Image file size in bytes}
#' \item{is_true_png}{Logical indicating if file is a true PNG}
#' 
#' @details The function analyzes:
#' \itemize{
#'   \item Image dimensions and aspect ratio
#'   \item File size and complexity
#'   \item PNG format verification
#'   \item Optimal scaling for performance vs quality
#' }
#' 
#' @examples
#' \dontrun{
#' # Auto-configure for an image
#' config <- auto_configure_mcmc("path/to/image.png")
#' 
#' # Use with custom max dimension
#' config <- auto_configure_mcmc("path/to/image.png", max_dimension = 1200)
#' 
#' # Use the configuration
#' res <- run_line_painter("path/to/image.png", 
#'                        width = config$width, 
#'                        height = config$height,
#'                        iters = config$iters)
#' }
#' @export
auto_configure_mcmc <- function(image_path, max_dimension = 800, target_iterations = 20000) {
  # Get image information
  img_info <- get_image_info(image_path)
  
  cat("Image Analysis:\n")
  cat("==============\n")
  cat("File:", basename(image_path), "\n")
  cat("Original dimensions:", img_info$width, "x", img_info$height, "pixels\n")
  cat("File size:", round(img_info$file_size / 1024, 1), "KB\n")
  cat("PNG verification:", ifelse(img_info$is_true_png, "✓ True PNG", "✗ Not a true PNG"), "\n")
  
  # Calculate scaling factor to fit within max_dimension
  scale_factor <- min(max_dimension / max(img_info$width, img_info$height), 1)
  new_width <- round(img_info$width * scale_factor)
  new_height <- round(img_info$height * scale_factor)
  
  # Adjust iterations based on image complexity
  pixel_count <- new_width * new_height
  base_iterations <- target_iterations
  
  # Scale iterations based on image size (larger images need more iterations)
  if (pixel_count > 800 * 800) {
    adjusted_iterations <- round(base_iterations * (pixel_count / (800 * 800))^0.5)
  } else {
    adjusted_iterations <- base_iterations
  }
  
  # Calculate save frequency
  save_every <- max(1000, round(adjusted_iterations / 20))
  
  cat("\nOptimized MCMC Parameters:\n")
  cat("==========================\n")
  cat("Scaled dimensions:", new_width, "x", new_height, "pixels\n")
  cat("Scaling factor:", round(scale_factor, 3), "\n")
  cat("Adjusted iterations:", adjusted_iterations, "\n")
  cat("Save frequency:", save_every, "\n")
  
  return(list(
    original_width = img_info$width,
    original_height = img_info$height,
    scaled_width = new_width,
    scaled_height = new_height,
    iterations = adjusted_iterations,
    save_every = save_every,
    is_true_png = img_info$is_true_png,
    scale_factor = scale_factor
  ))
}

#' Run MCMC Line Painting Algorithm
#'
#' Generates artistic line paintings from target images using Reversible Jump MCMC.
#' The algorithm iteratively adds, removes, and modifies lines to minimize the 
#' difference between the canvas and target image.
#'
#' @param image_path Character string. Path to the target image file (PNG, JPEG, etc.)
#' @param width Integer. Output canvas width in pixels. If NULL, uses auto-configuration
#' @param height Integer. Output canvas height in pixels. If NULL, uses auto-configuration  
#' @param iters Integer. Number of MCMC iterations to run. If NULL, uses auto-configuration
#' @param out_dir Character string. Directory to save results and intermediate images
#' @param seed Integer. Random seed for reproducibility (default: 42)
#' @param save_every Integer. Save intermediate results every N iterations. If NULL, uses auto-configuration
#' @param max_dimension Integer. Maximum dimension for auto-scaling (default: 800)
#' @param auto_config Logical. Whether to use automatic parameter optimization (default: TRUE)
#' @param verbose Logical. Whether to print progress information (default: TRUE)
#' 
#' @return A list containing:
#' \item{lines}{List of line objects with parameters (x1, y1, x2, y2, r, g, b, alpha, w)}
#' \item{best}{List with best iteration results (canvas, sse, iter)}
#' \item{canvas}{Final canvas array [H, W, 3]}
#' \item{dimensions}{Vector of final dimensions [width, height]}
#' \item{iterations}{Total number of iterations completed}
#' \item{sse_history}{Vector of SSE values over iterations}
#' 
#' @details The algorithm uses four types of MCMC moves:
#' \itemize{
#'   \item Birth: Add new lines based on image residuals
#'   \item Death: Remove existing lines
#'   \item Jitter: Perturb line parameters (position, color, opacity, thickness)
#'   \item Swap: Reorder line rendering for better composition
#' }
#' 
#' @examples
#' \dontrun{
#' # Basic usage with auto-configuration
#' res <- run_line_painter("path/to/image.png", iters = 5000)
#' 
#' # Manual configuration
#' res <- run_line_painter("path/to/image.png", width = 800, height = 600, iters = 10000)
#' 
#' # High-quality run
#' res <- run_line_painter("path/to/image.png", iters = 100000, max_dimension = 1200)
#' }
#' @export
run_line_painter <- function(image_path,
                             width = NULL, height = NULL,
                             iters = NULL,
                             out_dir = "mcmc_out",
                             seed = 42,
                             save_every = NULL,
                             max_dimension = 800,
                             auto_config = TRUE,
                             verbose = TRUE) {
  
  # Auto-configure if requested
  if (auto_config) {
    cat("Auto-configuring MCMC parameters...\n")
    config <- auto_configure_mcmc(image_path, max_dimension, iters %||% 20000)
    
    # Use auto-configured values if not specified
    width <- width %||% config$scaled_width
    height <- height %||% config$scaled_height
    iters <- iters %||% config$iterations
    save_every <- save_every %||% config$save_every
    
    cat("Using auto-configured parameters:\n")
    cat("  Dimensions:", width, "x", height, "\n")
    cat("  Iterations:", iters, "\n")
    cat("  Save frequency:", save_every, "\n\n")
  } else {
    # Use provided values or defaults
    width <- width %||% 256
    height <- height %||% 256
    iters <- iters %||% 20000
    save_every <- save_every %||% max(1000, round(iters / 20))
  }
  
  # Load target image
  target <- load_image_rgb(image_path, out_w = width, out_h = height)
  
  # Run MCMC
  res <- rjmcmc_line_paint(
    target_img = target,
    iters      = iters,
    beta_init  = 0.1,
    beta_final = 2.0,
    prob_moves = c(birth=0.25, death=0.25, jitter=0.45, swap=0.05),
    K_lambda   = 0.5 * width,
    save_every = save_every,
    out_dir    = out_dir,
    seed       = seed,
    verbose    = verbose
  )
  
  # Save final and best canvases
  final_path <- file.path(out_dir, "final.png")
  best_path  <- file.path(out_dir, sprintf("best_iter_%06d.png", res$best$iter))
  save_png(res$canvas, final_path)
  save_png(res$best$canvas, best_path)
  
  if (verbose) {
    message("Saved: ", final_path, " and ", best_path)
  }
  
  invisible(res)
}

#' Create Triptych Visualization
#'
#' Creates a three-panel visualization showing the progression from default canvas
#' to final MCMC result, alongside the target image for comparison.
#'
#' @param default_canvas Array [H, W, 3]. Initial white canvas (usually array of 1s)
#' @param best_canvas Array [H, W, 3]. Best MCMC result canvas from run_line_painter()
#' @param target_img Array [H, W, 3]. Target image array
#' @param titles Character vector of length 3. Titles for each panel (default: c("Default (White Canvas)", "Best MCMC Result", "True Image"))
#' @param main_title Character string. Main title for the entire plot (default: "MCMC Line Painting Progression")
#' 
#' @return Invisible NULL. Creates a plot in the current graphics device.
#' 
#' @details This function creates a side-by-side comparison showing:
#' \itemize{
#'   \item Left panel: Initial white canvas
#'   \item Center panel: Best MCMC result
#'   \item Right panel: Target image
#' }
#' 
#' @examples
#' \dontrun{
#' # After running MCMC
#' res <- run_line_painter("image.png", iters = 5000)
#' target_img <- load_image_rgb("image.png", 800, 600)
#' default_canvas <- array(1, dim = c(600, 800, 3))
#' 
#' # Create triptych
#' create_triptych(default_canvas, res$best$canvas, target_img)
#' }
#' @export
create_triptych <- function(default_canvas, best_canvas, target_img, 
                           titles = c("Default (White Canvas)", "Best MCMC Result", "True Image"),
                           main_title = "MCMC Line Painting Progression") {
  
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
  mtext(main_title, outer = TRUE, line = 0, cex = 1.5, font = 2)
  
  invisible(NULL)
}

#' Save triptych to file
#' @param default_canvas Default white canvas
#' @param best_canvas Best MCMC result canvas
#' @param target_img Target image
#' @param output_path Output file path
#' @param width Figure width
#' @param height Figure height
#' @param titles Panel titles
#' @param main_title Main title
#' @param format Output format ("pdf" or "png")
#' @return Invisible NULL
#' @export
save_triptych <- function(default_canvas, best_canvas, target_img, 
                          output_path, width = 15, height = 6,
                          titles = c("Default (White Canvas)", "Best MCMC Result", "True Image"),
                          main_title = "MCMC Line Painting Progression",
                          format = "pdf") {
  
  if (format == "pdf") {
    pdf(output_path, width = width, height = height)
  } else if (format == "png") {
    # Convert inches to pixels (assuming 150 DPI)
    png_width <- round(width * 150)
    png_height <- round(height * 150)
    png(output_path, width = png_width, height = png_height, res = 150)
  } else {
    stop("Format must be 'pdf' or 'png'")
  }
  
  create_triptych(default_canvas, best_canvas, target_img, titles, main_title)
  dev.off()
  
  invisible(NULL)
}

#' Helper function for NULL coalescing
#' @param x First value
#' @param y Second value
#' @return x if not NULL, otherwise y
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
