#' Dot Painter Functions
#' 
#' This module provides functions for MCMC-based dot painting, creating artistic
#' representations using dots of varying radius, alpha, and color.

#' @importFrom Rcpp sourceCpp
NULL

#' Load and compile dot painter C++ code
#' @export
load_dot_painter_cpp <- function() {
  Rcpp::sourceCpp("src/dot_painter_cpp.cpp")
}

#' Sample dot from prior distribution
#' @param W,H Image dimensions
#' @return Dot parameters (x, y, radius, alpha, col)
#' @export
sample_dot_prior <- function(W, H) {
  sample_dot_prior_cpp(W, H)
}

#' Jitter dot proposal
#' @param dot Dot to jitter
#' @param W,H Image dimensions
#' @param s_xy,s_r,s_a,s_c Standard deviations for jittering
#' @return Jittered dot
#' @export
jitter_dot <- function(dot, W, H, s_xy = 3, s_r = 1, s_a = 0.1, s_c = 0.08) {
  jitter_dot_cpp(dot, W, H, s_xy, s_r, s_a, s_c)
}

#' Data-driven dot birth proposal
#' @param target Target image
#' @param canvas Current canvas
#' @return Proposed dot
#' @export
sample_dot_birth_datadriven <- function(target, canvas) {
  H <- dim(target)[1]
  W <- dim(target)[2]
  sample_dot_birth_datadriven_cpp(as.numeric(target), as.numeric(canvas), H, W)
}

#' Compute dot bounding box
#' @param x,y Dot center coordinates
#' @param radius Dot radius
#' @param W,H Image dimensions
#' @return Bounding box coordinates
#' @export
dot_bbox <- function(x, y, radius, W, H) {
  dot_bbox_cpp(x, y, radius, W, H)
}

#' Composite dot into canvas bbox
#' @param canvas Canvas to modify
#' @param x,y Dot center coordinates
#' @param radius Dot radius
#' @param alpha Dot alpha value
#' @param col Dot color (RGB vector)
#' @param bbox Bounding box
#' @return Modified canvas
#' @export
composite_dot_bbox <- function(canvas, x, y, radius, alpha, col, bbox) {
  H <- dim(canvas)[1]
  W <- dim(canvas)[2]
  result <- composite_dot_bbox_cpp(
    as.numeric(canvas), H, W, x, y, radius, alpha, col,
    bbox$xmin, bbox$xmax, bbox$ymin, bbox$ymax
  )
  array(result, dim = dim(canvas))
}

#' Compute SSE in bbox for dots
#' @param target Target image
#' @param canvas Canvas image
#' @param bbox Bounding box
#' @return SSE value
#' @export
sse_bbox_dots <- function(target, canvas, bbox) {
  H <- dim(target)[1]
  W <- dim(target)[2]
  sse_bbox_dots_cpp(
    as.numeric(target), as.numeric(canvas), H, W,
    bbox$xmin, bbox$xmax, bbox$ymin, bbox$ymax
  )
}

#' Re-render bbox from dots
#' @param canvas Canvas to modify
#' @param dots List of dots
#' @param bbox Bounding box
#' @return Modified canvas
#' @export
re_render_bbox_from_dots <- function(canvas, dots, bbox) {
  H <- dim(canvas)[1]
  W <- dim(canvas)[2]
  result <- re_render_bbox_from_dots_cpp(
    as.numeric(canvas), dots, H, W,
    bbox$xmin, bbox$xmax, bbox$ymin, bbox$ymax
  )
  array(result, dim = dim(canvas))
}

#' Render full canvas from dots
#' @param canvas Canvas to render
#' @param dots List of dots
#' @return Rendered canvas
#' @export
render_full_canvas_from_dots <- function(canvas, dots) {
  H <- dim(canvas)[1]
  W <- dim(canvas)[2]
  result <- render_full_canvas_from_dots_cpp(as.numeric(canvas), dots, H, W)
  array(result, dim = dim(canvas))
}

#' Log prior for dot
#' @param dot Dot parameters
#' @param W,H Image dimensions
#' @return Log prior value
#' @export
log_prior_dot <- function(dot, W, H) {
  # Weak bounds: zero prior if outside bounds
  if (any(c(dot$x, dot$y) < 1 | c(dot$x, dot$y) > c(W, H) |
          dot$radius <= 0 | dot$alpha <= 0 | dot$alpha >= 1 |
          any(dot$col < 0 | dot$col > 1))) return(-Inf)
  
  # Simple independent priors (up to constants)
  lp <- 0
  
  # Much more permissive radius prior (sigma=4 for balanced radii)
  sigma_r <- 4
  lp <- lp - (dot$radius^2) / (2*sigma_r^2)
  
  # More permissive alpha prior (Beta(1.5,1.5) instead of Beta(2,2))
  lp <- lp + (0.5)*log(dot$alpha) + (0.5)*log(1 - dot$alpha)
  
  # Colors uniform in [0,1]: constant, ignore
  # Positions uniform: constant, ignore
  
  lp
}

#' Log prior on number of dots
#' @param K Number of dots
#' @param lambda Prior parameter
#' @return Log prior value
#' @export
log_prior_K_dots <- function(K, lambda = 200) {
  if (K < 0) return(-Inf)
  # log Poisson PMF up to constant terms: K*log(lambda) - lambda - log(K!)
  K*log(lambda + 1e-12) - lambda - lgamma(K+1)
}

#' Log likelihood change from bbox for dots
#' @param target Target image
#' @param canvas_before Canvas before change
#' @param canvas_after Canvas after change
#' @param bbox Bounding box
#' @param beta Temperature parameter
#' @return Log likelihood change
#' @export
log_lik_change_from_bbox_dots <- function(target, canvas_before, canvas_after, bbox, beta) {
  sse_b <- sse_bbox_dots(target, canvas_before, bbox)
  sse_a <- sse_bbox_dots(target, canvas_after, bbox)
  -beta * (sse_a - sse_b)
}

#' Convert canvas to vector for C++ operations
#' @param arr Array to convert
#' @return Flattened vector
#' @export
as_vec_dots <- function(arr) {
  if (length(dim(arr)) == 3) {
    # [H, W, 3] -> flattened vector
    as.numeric(arr)
  } else {
    as.numeric(arr)
  }
}

#' Convert vector back to canvas array
#' @param vec Flattened vector
#' @param H,W Height and width
#' @return Array with dimensions [H, W, 3]
#' @export
as_array_dots <- function(vec, H, W) {
  array(vec, dim = c(H, W, 3))
}
