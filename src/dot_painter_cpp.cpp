// dot_painter_cpp.cpp
// MCMC Dot Painter - C++ implementation for high-performance dot rendering
#include <Rcpp.h>
#include <random>
#include <cmath>
using namespace Rcpp;

// ---- helpers ----
inline double clamp01(double v) {
  if (v < 0.0) return 0.0;
  if (v > 1.0) return 1.0;
  return v;
}

// Linear index for R array [H, W, 3] (column-major)
inline int idx3(int y, int x, int c, int H, int W) {
  // y, x are 1-based coming from R/loops; convert to 0-based
  int y0 = y - 1;
  int x0 = x - 1;
  return y0 + x0 * H + c * H * W;
}

// ---- 1) Composite one dot into a bbox (alpha-over) ----
// canvas: numeric array [H, W, 3] flattened (as.numeric(canvas))
// col: length-3 numeric (r,g,b) in [0,1]
// bbox and coords are in pixel coordinates (1..W / 1..H).
//
// Returns a NEW canvas vector (so it's easy to use with functional code).
//
// [[Rcpp::export]]
NumericVector composite_dot_bbox_cpp(NumericVector canvas,
                                     int H, int W,
                                     double x, double y,
                                     double radius, double alpha,
                                     NumericVector col,
                                     int xmin, int xmax,
                                     int ymin, int ymax) {
  // Work directly on 'canvas' (R copies if NAMED>1)
  const double r = radius;
  const double r2 = r * r;
  const double cr = col[0], cg = col[1], cb = col[2];

  for(int y0 = ymin; y0 <= ymax; ++y0) {
    const double py = (double)y0 - 0.5;
    const int y_idx = y0 - 1;
    
    for(int x0 = xmin; x0 <= xmax; ++x0) {
      const double px = (double)x0 - 0.5;
      const int x_idx = x0 - 1;

      // Bounds checking to prevent segmentation faults
      if (y_idx < 0 || y_idx >= H || x_idx < 0 || x_idx >= W) continue;

      // Calculate distance from dot center
      const double dx = px - x;
      const double dy = py - y;
      const double d2 = dx*dx + dy*dy;

      // Check if pixel is within dot radius
      if (d2 > r2) continue;

      // Calculate coverage based on distance (soft edges)
      double coverage = 1.0;
      if (d2 > (r - 1.0) * (r - 1.0)) {
        // Soft edge for anti-aliasing
        coverage = 1.0 - std::sqrt(d2) / r;
        if (coverage < 0.0) coverage = 0.0;
      }

      if (coverage <= 0.0 || alpha <= 0.0) continue;

      const double a = clamp01(coverage * alpha);

      const int i0 = idx3(y_idx, x_idx, 0, H, W);
      const int i1 = idx3(y_idx, x_idx, 1, H, W);
      const int i2 = idx3(y_idx, x_idx, 2, H, W);

      // Additional bounds checking for array indices
      if (i0 < 0 || i0 >= canvas.length() || 
          i1 < 0 || i1 >= canvas.length() || 
          i2 < 0 || i2 >= canvas.length()) continue;

      const double inR = canvas[i0];
      const double inG = canvas[i1];
      const double inB = canvas[i2];

      // Alpha compositing: out = in + a * (col - in)
      canvas[i0] = inR + a * (cr - inR);
      canvas[i1] = inG + a * (cg - inG);
      canvas[i2] = inB + a * (cb - inB);
    }
  }
  
  return canvas;
}

// ---- 2) Compute SSE in bbox for dots ----
// [[Rcpp::export]]
double sse_bbox_dots_cpp(NumericVector target, NumericVector canvas,
                          int H, int W,
                          int xmin, int xmax, int ymin, int ymax) {
  double sse = 0.0;
  
  for(int y = ymin; y <= ymax; ++y) {
    const int y_idx = y - 1;
    for(int x = xmin; x <= xmax; ++x) {
      const int x_idx = x - 1;
      
      // Bounds checking
      if (y_idx < 0 || y_idx >= H || x_idx < 0 || x_idx >= W) continue;
      
      for(int c = 0; c < 3; ++c) {
        const int idx = idx3(y_idx, x_idx, c, H, W);
        if (idx < 0 || idx >= target.length() || idx >= canvas.length()) continue;
        
        const double diff = target[idx] - canvas[idx];
        sse += diff * diff;
      }
    }
  }
  
  return sse;
}

// ---- 3) Compute bounding box for a dot ----
// [[Rcpp::export]]
List dot_bbox_cpp(double x, double y, double radius, int W, int H) {
  int xmin = std::max(1, (int)std::floor(x - radius));
  int xmax = std::min(W, (int)std::ceil(x + radius));
  int ymin = std::max(1, (int)std::floor(y - radius));
  int ymax = std::min(H, (int)std::ceil(y + radius));
  
  return List::create(
    Named("xmin") = xmin,
    Named("xmax") = xmax,
    Named("ymin") = ymin,
    Named("ymax") = ymax
  );
}

// ---- 4) Sample dot from prior ----
// [[Rcpp::export]]
List sample_dot_prior_cpp(int W, int H) {
  // Use R's random number generator
  double x = R::runif(1.0, W);
  double y = R::runif(1.0, H);
  double radius = std::abs(R::rnorm(0.0, 2.0)) + 1.0;  // 1-6 pixels typical
  double alpha = R::rbeta(2.0, 2.0);  // Beta distribution for alpha
  NumericVector col(3);
  col[0] = R::runif(0.0, 1.0);  // R
  col[1] = R::runif(0.0, 1.0);  // G
  col[2] = R::runif(0.0, 1.0);  // B
  
  return List::create(
    Named("x") = x, Named("y") = y,
    Named("radius") = radius, Named("alpha") = alpha,
    Named("col") = col
  );
}

// ---- 5) Jitter dot proposal ----
// [[Rcpp::export]]
List jitter_dot_cpp(List dot, int W, int H, 
                    double s_xy = 3.0, double s_r = 1.0, 
                    double s_a = 0.1, double s_c = 0.08) {
  List d2 = clone(dot);
  
  d2["x"] = std::max(1.0, std::min((double)W, as<double>(dot["x"]) + R::rnorm(0.0, s_xy)));
  d2["y"] = std::max(1.0, std::min((double)H, as<double>(dot["y"]) + R::rnorm(0.0, s_xy)));
  d2["radius"] = std::max(1.0, as<double>(dot["radius"]) + R::rnorm(0.0, s_r));
  d2["alpha"] = std::min(0.999, std::max(0.001, as<double>(dot["alpha"]) + R::rnorm(0.0, s_a)));
  
  NumericVector col = as<NumericVector>(dot["col"]);
  NumericVector new_col(3);
  for (int i = 0; i < 3; i++) {
    new_col[i] = std::min(1.0, std::max(0.0, col[i] + R::rnorm(0.0, s_c)));
  }
  d2["col"] = new_col;
  
  return d2;
}

// ---- 6) Data-driven dot birth proposal ----
// [[Rcpp::export]]
List sample_dot_birth_datadriven_cpp(NumericVector target, NumericVector canvas, 
                                     int H, int W) {
  // Calculate residual magnitude per pixel
  NumericVector E = target - canvas;
  NumericVector mag_sq(H * W);
  
  for (int i = 0; i < H * W; i++) {
    double sum = 0.0;
    for (int c = 0; c < 3; c++) {
      double diff = E[i + c * H * W];
      sum += diff * diff;
    }
    mag_sq[i] = std::sqrt(sum);
  }
  
  // Find max magnitude for normalization
  double max_mag = 0.0;
  for (int i = 0; i < H * W; i++) {
    if (mag_sq[i] > max_mag) max_mag = mag_sq[i];
  }
  
  // Normalize and sample seed pixel
  double x0, y0;
  if (max_mag < 1e-6) {
    // Fallback to uniform if no residual
    x0 = R::runif(1.0, W);
    y0 = R::runif(1.0, H);
  } else {
    // Sample proportional to residual magnitude
    double total_weight = 0.0;
    for (int i = 0; i < H * W; i++) {
      mag_sq[i] /= max_mag;
      total_weight += mag_sq[i];
    }
    
    double r = R::runif(0.0, total_weight);
    double cumsum = 0.0;
    int idx = 0;
    for (int i = 0; i < H * W; i++) {
      cumsum += mag_sq[i];
      if (cumsum >= r) {
        idx = i;
        break;
      }
    }
    
    y0 = (idx % H) + 1;
    x0 = (idx / H) + 1;
  }
  
  // Sample dot parameters around the seed point
  double radius = std::abs(R::rnorm(0.0, 1.5)) + 1.0;
  double alpha = R::rbeta(2.0, 2.0);
  
  // Sample color from target image around seed point
  NumericVector col(3);
  int x_idx = (int)x0 - 1;
  int y_idx = (int)y0 - 1;
  
  if (x_idx >= 0 && x_idx < W && y_idx >= 0 && y_idx < H) {
    for (int c = 0; c < 3; c++) {
      int target_idx = idx3(y_idx, x_idx, c, H, W);
      if (target_idx >= 0 && target_idx < target.length()) {
        col[c] = target[target_idx];
      } else {
        col[c] = R::runif(0.0, 1.0);
      }
    }
  } else {
    col[0] = R::runif(0.0, 1.0);
    col[1] = R::rnorm(0.0, 1.0);
    col[2] = R::runif(0.0, 1.0);
  }
  
  return List::create(
    Named("x") = x0, Named("y") = y0,
    Named("radius") = radius, Named("alpha") = alpha,
    Named("col") = col
  );
}

// ---- 7) Re-render bbox from dots ----
// [[Rcpp::export]]
NumericVector re_render_bbox_from_dots_cpp(NumericVector canvas, List dots,
                                           int H, int W,
                                           int xmin, int xmax, int ymin, int ymax) {
  // Start with white canvas in bbox
  for(int y = ymin; y <= ymax; ++y) {
    const int y_idx = y - 1;
    for(int x = xmin; x <= xmax; ++x) {
      const int x_idx = x - 1;
      
      if (y_idx < 0 || y_idx >= H || x_idx < 0 || x_idx >= W) continue;
      
      const int i0 = idx3(y_idx, x_idx, 0, H, W);
      const int i1 = idx3(y_idx, x_idx, 1, H, W);
      const int i2 = idx3(y_idx, x_idx, 2, H, W);
      
      if (i0 < 0 || i0 >= canvas.length() || 
          i1 < 0 || i1 >= canvas.length() || 
          i2 < 0 || i2 >= canvas.length()) continue;
      
      canvas[i0] = 1.0;  // White background
      canvas[i1] = 1.0;
      canvas[i2] = 1.0;
    }
  }
  
  // Render all dots that intersect the bbox
  for (int i = 0; i < dots.length(); i++) {
    List dot = dots[i];
    double x = as<double>(dot["x"]);
    double y = as<double>(dot["y"]);
    double radius = as<double>(dot["radius"]);
    
    // Check if dot intersects bbox
    if (x + radius < xmin || x - radius > xmax || 
        y + radius < ymin || y - radius > ymax) continue;
    
    // Render this dot
    double alpha = as<double>(dot["alpha"]);
    NumericVector col = as<NumericVector>(dot["col"]);
    
    // Calculate dot's bbox
    int dot_xmin = std::max(xmin, (int)std::floor(x - radius));
    int dot_xmax = std::min(xmax, (int)std::ceil(x + radius));
    int dot_ymin = std::max(ymin, (int)std::floor(y - radius));
    int dot_ymax = std::min(ymax, (int)std::ceil(y + radius));
    
    // Render dot in overlap region
    for(int y0 = dot_ymin; y0 <= dot_ymax; ++y0) {
      const double py = (double)y0 - 0.5;
      const int y_idx = y0 - 1;
      
      for(int x0 = dot_xmin; x0 <= dot_xmax; ++x0) {
        const double px = (double)x0 - 0.5;
        const int x_idx = x0 - 1;

        if (y_idx < 0 || y_idx >= H || x_idx < 0 || x_idx >= W) continue;

        const double dx = px - x;
        const double dy = py - y;
        const double d2 = dx*dx + dy*dy;
        const double r2 = radius * radius;

        if (d2 > r2) continue;

        double coverage = 1.0;
        if (d2 > (radius - 1.0) * (radius - 1.0)) {
          coverage = 1.0 - std::sqrt(d2) / radius;
          if (coverage < 0.0) coverage = 0.0;
        }

        if (coverage <= 0.0 || alpha <= 0.0) continue;

        const double a = clamp01(coverage * alpha);

        const int i0 = idx3(y_idx, x_idx, 0, H, W);
        const int i1 = idx3(y_idx, x_idx, 1, H, W);
        const int i2 = idx3(y_idx, x_idx, 2, H, W);

        if (i0 < 0 || i0 >= canvas.length() || 
            i1 < 0 || i1 >= canvas.length() || 
            i2 < 0 || i2 >= canvas.length()) continue;

        const double inR = canvas[i0];
        const double inG = canvas[i1];
        const double inB = canvas[i2];

        // Alpha compositing: out = in + a * (col - in)
        canvas[i0] = inR + a * (col[0] - inR);
        canvas[i1] = inG + a * (col[1] - inG);
        canvas[i2] = inB + a * (col[2] - inB);
      }
    }
  }
  
  return canvas;
}

// ---- 8) Render full canvas from dots ----
// [[Rcpp::export]]
NumericVector render_full_canvas_from_dots_cpp(NumericVector canvas, List dots,
                                               int H, int W) {
  // Start with white canvas
  for(int i = 0; i < canvas.length(); i++) {
    canvas[i] = 1.0;
  }
  
  // Render all dots
  for (int i = 0; i < dots.length(); i++) {
    List dot = dots[i];
    double x = as<double>(dot["x"]);
    double y = as<double>(dot["y"]);
    double radius = as<double>(dot["radius"]);
    double alpha = as<double>(dot["alpha"]);
    NumericVector col = as<NumericVector>(dot["col"]);
    
    // Calculate dot's bbox
    int xmin = std::max(1, (int)std::floor(x - radius));
    int xmax = std::min(W, (int)std::ceil(x + radius));
    int ymin = std::max(1, (int)std::floor(y - radius));
    int ymax = std::min(H, (int)std::ceil(y + radius));
    
    // Render dot
    for(int y0 = ymin; y0 <= ymax; ++y0) {
      const double py = (double)y0 - 0.5;
      const int y_idx = y0 - 1;
      
      for(int x0 = xmin; x0 <= xmax; ++x0) {
        const double px = (double)x0 - 0.5;
        const int x_idx = x0 - 1;

        if (y_idx < 0 || y_idx >= H || x_idx < 0 || x_idx >= W) continue;

        const double dx = px - x;
        const double dy = py - y;
        const double d2 = dx*dx + dy*dy;
        const double r2 = radius * radius;

        if (d2 > r2) continue;

        double coverage = 1.0;
        if (d2 > (radius - 1.0) * (radius - 1.0)) {
          coverage = 1.0 - std::sqrt(d2) / radius;
          if (coverage < 0.0) coverage = 0.0;
        }

        if (coverage <= 0.0 || alpha <= 0.0) continue;

        const double a = clamp01(coverage * alpha);

        const int i0 = idx3(y_idx, x_idx, 0, H, W);
        const int i1 = idx3(y_idx, x_idx, 1, H, W);
        const int i2 = idx3(y_idx, x_idx, 2, H, W);

        if (i0 < 0 || i0 >= canvas.length() || 
            i1 < 0 || i1 >= canvas.length() || 
            i2 < 0 || i2 >= canvas.length()) continue;

        const double inR = canvas[i0];
        const double inG = canvas[i1];
        const double inB = canvas[i2];

        // Alpha compositing: out = in + a * (col - in)
        canvas[i0] = inR + a * (col[0] - inR);
        canvas[i1] = inG + a * (col[1] - inG);
        canvas[i2] = inB + a * (col[2] - inB);
      }
    }
  }
  
  return canvas;
}
