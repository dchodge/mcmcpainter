#' Utility functions for MCMC line painting
#' 
#' This file contains utility functions for line operations, priors, and proposals.

#' Strict, consistent version of as.vector for arrays
#' @param x Array to convert
#' @return Numeric vector
#' @keywords internal
as_vec <- function(x) {
  if (is.function(x)) {
    stop("Got a *function* where an [H,W,3] numeric array was expected.")
  }
  if (!is.array(x) || length(dim(x)) != 3 || dim(x)[3] != 3) {
    stop(sprintf("Expected [H,W,3] numeric array; got class=%s dim=%s",
                 paste(class(x), collapse = ","),
                 paste(dim(x), collapse = "x")))
  }
  storage.mode(x) <- "double"
  as.numeric(x)  # flatten
}

#' Compute axis-aligned bounding box for a line with width w (in px), clamped to image size
#' @param x1,y1,x2,y2 Line coordinates
#' @param w Line width
#' @param W,H Image dimensions
#' @param pad Padding around line
#' @return List with bbox coordinates
#' @export
line_bbox <- function(x1, y1, x2, y2, w, W, H, pad = 2) {
  line_bbox_cpp(x1, y1, x2, y2, w, W, H, pad)
}

#' Composite line into canvas within bbox
#' @param canvas Canvas array
#' @param line Line parameters
#' @param bbox Bounding box
#' @return Updated canvas
#' @export
composite_line_in_bbox <- function(canvas, line, bbox) {
  H <- dim(canvas)[1]; W <- dim(canvas)[2]
  yidx <- bbox$ymin:bbox$ymax
  xidx <- bbox$xmin:bbox$xmax
  ny <- length(yidx); nx <- length(xidx)
  if (ny <= 0 || nx <= 0) return(canvas)

  # call C++
  out_vec <- composite_line_bbox_cpp(
    canvas = as_vec(canvas),
    H = H, W = W,
    x1 = line$x1, y1 = line$y1,
    x2 = line$x2, y2 = line$y2,
    w  = line$w,  alpha = line$alpha,
    col = as.numeric(line$col),
    xmin = bbox$xmin, xmax = bbox$xmax,
    ymin = bbox$ymin, ymax = bbox$ymax
  )
  array(out_vec, dim = c(H, W, 3))
}

#' Re-render a bbox from lines
#' @param base_canvas Base canvas
#' @param lines List of lines
#' @param bbox Bounding box
#' @return Updated canvas
#' @export
re_render_bbox_from_lines <- function(base_canvas, lines, bbox) {
  H <- dim(base_canvas)[1]; W <- dim(base_canvas)[2]
  
  # Use C++ version for much faster performance
  out_vec <- re_render_bbox_from_lines_cpp(
    base_canvas = as_vec(base_canvas),
    lines = lines,
    xmin = bbox$xmin, xmax = bbox$xmax,
    ymin = bbox$ymin, ymax = bbox$ymax,
    H = H, W = W
  )
  array(out_vec, dim = c(H, W, 3))
}

#' Compute SSE in bbox
#' @param target_img Target image
#' @param canvas_img Canvas image
#' @param bbox Bounding box
#' @return SSE value
#' @export
sse_bbox_safe <- function(target_img, canvas_img, bbox) {
  H <- dim(target_img)[1]; W <- dim(target_img)[2]
  sse_bbox_cpp(
    target = as_vec(target_img),
    canvas = as_vec(canvas_img),
    H = H, W = W,
    xmin = bbox$xmin, xmax = bbox$xmax,
    ymin = bbox$ymin, ymax = bbox$ymax
  )
}

#' Sample line from prior
#' @param W,H Image dimensions
#' @return Line parameters
#' @export
sample_line_prior <- function(W, H) {
  sample_line_prior_cpp(W, H)
}

#' Log prior for line
#' @param line Line parameters
#' @param W,H Image dimensions
#' @return Log prior value
#' @export
log_prior_line <- function(line, W, H) {
  # Weak bounds: zero prior if outside bounds
  if (any(c(line$x1, line$x2) < 1 | c(line$x1, line$x2) > W |
          any(c(line$y1, line$y2) < 1 | c(line$y1, line$y2) > H) |
          line$w <= 0 | line$alpha <= 0 | line$alpha >= 1 |
          any(line$col < 0 | line$col > 1))) return(-Inf)
  # Simple independent priors (up to constants). We omit normalization constants.
  # width ~ half-normal(sigma=3), alpha ~ Beta(2,2), color ~ U(0,1)^3, positions ~ U
  lp <- 0
  # Half-normal on w (sigma=3): density ∝ exp(-w^2/(2*σ^2)) for w>0
  sigma_w <- 3
  lp <- lp - (line$w^2) / (2*sigma_w^2)
  # Beta(2,2) on alpha: log density ∝ (2-1)*log(alpha) + (2-1)*log(1-alpha)
  lp <- lp + (1)*log(line$alpha) + (1)*log(1 - line$alpha)
  # Colors uniform in [0,1]: constant, ignore
  # Positions uniform: constant, ignore
  lp
}

#' Poisson prior on K (model size)
#' @param K Number of lines
#' @param lambda Prior parameter
#' @return Log prior value
#' @export
log_prior_K <- function(K, lambda = 120) {
  if (K < 0) return(-Inf)
  # log Poisson PMF up to constant terms: K*log(lambda) - lambda - log(K!)
  # For RJ ratios, constants cancel; include main dependence
  K*log(lambda + 1e-12) - lambda - lgamma(K+1)
}

#' Jitter line proposal
#' @param line Line to jitter
#' @param W,H Image dimensions
#' @param s_xy,s_w,s_a,s_c Standard deviations for jittering
#' @return Jittered line
#' @export
jitter_line <- function(line, W, H, s_xy = 3, s_w = 0.6, s_a = 0.1, s_c = 0.08) {
  jitter_line_cpp(line, W, H, s_xy, s_w, s_a, s_c)
}

#' Data-driven birth proposal
#' @param target Target image
#' @param canvas Current canvas
#' @return Proposed line
#' @export
sample_line_birth_datadriven <- function(target, canvas) {
  H <- dim(target)[1]; W <- dim(target)[2]
  sample_line_birth_datadriven_cpp(as_vec(target), as_vec(canvas), H, W)
}

#' Log likelihood change from bbox
#' @param target Target image
#' @param canvas_before Canvas before change
#' @param canvas_after Canvas after change
#' @param bbox Bounding box
#' @param beta Temperature parameter
#' @return Log likelihood change
#' @export
log_lik_change_from_bbox <- function(target, canvas_before, canvas_after, bbox, beta) {
  sse_b <- sse_bbox_safe(target, canvas_before, bbox)
  sse_a <- sse_bbox_safe(target, canvas_after,  bbox)
  -beta * (sse_a - sse_b)
}
