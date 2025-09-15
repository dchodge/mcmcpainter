// mcmc_painter_cpp.cpp
#include <Rcpp.h>
#include <random>
#include <cmath>
using namespace Rcpp;

// ---- helpers ----
inline double clamp01(double v) {
  if (v < 0.0) return 0.0;
  if (v > 1.0) return v;
  return v;
}

// Linear index for R array [H, W, 3] (column-major)
inline int idx3(int y, int x, int c, int H, int W) {
  // y, x are 1-based coming from R/loops; convert to 0-based
  int y0 = y - 1;
  int x0 = x - 1;
  return y0 + x0 * H + c * H * W;
}

// ---- 1) Composite one line into a bbox (alpha-over) ----
// canvas: numeric array [H, W, 3] flattened (as.numeric(canvas))
// col: length-3 numeric (r,g,b) in [0,1]
// bbox and coords are in pixel coordinates (1..W / 1..H).
//
// Returns a NEW canvas vector (so it's easy to use with functional code).
//
// [[Rcpp::export]]
NumericVector composite_line_bbox_cpp(NumericVector canvas,
                                      int H, int W,
                                      double x1, double y1,
                                      double x2, double y2,
                                      double w,  double alpha,
                                      NumericVector col,
                                      int xmin, int xmax,
                                      int ymin, int ymax){
  // Work directly on 'canvas' (R copies if NAMED>1)
  double vx = x2 - x1, vy = y2 - y1;
  double v2 = vx*vx + vy*vy + 1e-12;

  const double r   = 0.5*w;
  const double aa  = 0.5;
  const double inr = r - aa;
  const double outr= r + aa;
  const double in2 = (inr>0)? inr*inr : 0.0;
  const double ou2 = outr*outr;

  const double cr = col[0], cg = col[1], cb = col[2];

  for(int y=ymin; y<=ymax; ++y){
    const double py = (double)y - 0.5;
    const int y0 = y-1;
    for(int x=xmin; x<=xmax; ++x){
      const double px = (double)x - 0.5;
      const int x0 = x-1;

      // Bounds checking to prevent segmentation faults
      if (y0 < 0 || y0 >= H || x0 < 0 || x0 >= W) continue;

      double t = ((px-x1)*vx + (py-y1)*vy) / v2;
      if (t<0.0) t=0.0; else if (t>1.0) t=1.0;

      const double projx = x1 + t*vx;
      const double projy = y1 + t*vy;

      const double dx = px - projx;
      const double dy = py - projy;
      const double d2 = dx*dx + dy*dy;

      double cov = 0.0;
      if (inr <= 0.0){
        // soft ramp 0..1 over [0, outr]
        if (d2 < ou2){
          cov = 1.0 - std::sqrt(d2) / outr;
          if (cov < 0.0) cov = 0.0;
        }
      } else {
        if (d2 <= in2) cov = 1.0;
        else if (d2 >= ou2) cov = 0.0;
        else {
          cov = 1.0 - (std::sqrt(d2) - inr) / (outr - inr);
        }
      }
      if (cov<=0.0 || alpha<=0.0) continue;

      const double a = clamp01(cov * alpha);

      const int i0 = idx3(y0,x0,0,H,W);
      const int i1 = idx3(y0,x0,1,H,W);
      const int i2 = idx3(y0,x0,2,H,W);

      // Additional bounds checking for array indices
      if (i0 < 0 || i0 >= canvas.length() || 
          i1 < 0 || i1 >= canvas.length() || 
          i2 < 0 || i2 >= canvas.length()) continue;

      const double inR = canvas[i0];
      const double inG = canvas[i1];
      const double inB = canvas[i2];

      canvas[i0] = a*cr + (1.0-a)*inR;
      canvas[i1] = a*cg + (1.0-a)*inG;
      canvas[i2] = a*cb + (1.0-a)*inB;
    }
  }
  return canvas; // same SEXP, possibly duplicated by R if needed
}

// ---- 2) SSE in bbox: sum((target - canvas)^2) over bbox ----
// target, canvas are [H,W,3] flattened numeric vectors
// [[Rcpp::export]]
double sse_bbox_cpp(NumericVector target,
                    NumericVector canvas,
                    int H, int W,
                    int xmin, int xmax,
                    int ymin, int ymax) {
  double acc = 0.0;
  for (int y = ymin; y <= ymax; ++y) {
    for (int x = xmin; x <= xmax; ++x) {
      int i0 = idx3(y, x, 0, H, W);
      int i1 = idx3(y, x, 1, H, W);
      int i2 = idx3(y, x, 2, H, W);
      double d0 = target[i0] - canvas[i0];
      double d1 = target[i1] - canvas[i1];
      double d2 = target[i2] - canvas[i2];
      acc += d0*d0 + d1*d1 + d2*d2;
    }
  }
  return acc;
}

// ---- 3) Fast bounding box calculation ----
// [[Rcpp::export]]
List line_bbox_cpp(double x1, double y1, double x2, double y2, 
                   double w, int W, int H, int pad = 2) {
  double r = w / 2.0 + pad;
  int xmin = std::max(1, (int)std::floor(std::min(x1, x2) - r));
  int xmax = std::min(W, (int)std::ceil(std::max(x1, x2) + r));
  int ymin = std::max(1, (int)std::floor(std::min(y1, y2) - r));
  int ymax = std::min(H, (int)std::ceil(std::max(y1, y2) + r));
  
  return List::create(
    Named("xmin") = xmin,
    Named("xmax") = xmax,
    Named("ymin") = ymin,
    Named("ymax") = ymax
  );
}

// ---- 4) Fast line proposal generation ----
// [[Rcpp::export]]
List sample_line_prior_cpp(int W, int H) {
  // Use R's random number generator
  double x1 = R::runif(1.0, W);
  double y1 = R::runif(1.0, H);
  double ang = R::runif(0.0, 2.0 * M_PI);
  double len = std::abs(R::rnorm(0.0, 30.0)) + 5.0;
  double x2 = std::max(1.0, std::min((double)W, x1 + len * std::cos(ang)));
  double y2 = std::max(1.0, std::min((double)H, y1 + len * std::sin(ang)));
  double w = std::abs(R::rnorm(0.0, 3.0)) + 1.0;
  double alpha = R::rbeta(2.0, 2.0);
  NumericVector col(3);
  col[0] = R::runif(0.0, 1.0);
  col[1] = R::runif(0.0, 1.0);
  col[2] = R::runif(0.0, 1.0);
  
  return List::create(
    Named("x1") = x1, Named("y1") = y1,
    Named("x2") = x2, Named("y2") = y2,
    Named("w") = w, Named("alpha") = alpha,
    Named("col") = col
  );
}

// ---- 5) Fast jitter proposal ----
// [[Rcpp::export]]
List jitter_line_cpp(List line, int W, int H, 
                     double s_xy = 3.0, double s_w = 0.6, 
                     double s_a = 0.1, double s_c = 0.08) {
  List l2 = clone(line);
  
  l2["x1"] = std::max(1.0, std::min((double)W, as<double>(line["x1"]) + R::rnorm(0.0, s_xy)));
  l2["y1"] = std::max(1.0, std::min((double)H, as<double>(line["y1"]) + R::rnorm(0.0, s_xy)));
  l2["x2"] = std::max(1.0, std::min((double)W, as<double>(line["x2"]) + R::rnorm(0.0, s_xy)));
  l2["y2"] = std::max(1.0, std::min((double)H, as<double>(line["y2"]) + R::rnorm(0.0, s_xy)));
  l2["w"] = std::max(0.2, as<double>(line["w"]) + R::rnorm(0.0, s_w));
  l2["alpha"] = std::min(0.999, std::max(0.001, as<double>(line["alpha"]) + R::rnorm(0.0, s_a)));
  
  NumericVector col = as<NumericVector>(line["col"]);
  NumericVector new_col(3);
  for (int i = 0; i < 3; i++) {
    new_col[i] = std::min(1.0, std::max(0.0, col[i] + R::rnorm(0.0, s_c)));
  }
  l2["col"] = new_col;
  
  return l2;
}

// ---- 6) Fast data-driven birth proposal ----
// [[Rcpp::export]]
List sample_line_birth_datadriven_cpp(NumericVector target, NumericVector canvas, 
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
  
  // Generate line parameters
  double ang = R::runif(0.0, 2.0 * M_PI);
  double len = std::abs(R::rnorm(0.0, 35.0)) + 8.0;
  double x1 = std::max(1.0, std::min((double)W, x0 - len/2.0 * std::cos(ang)));
  double y1 = std::max(1.0, std::min((double)H, y0 - len/2.0 * std::sin(ang)));
  double x2 = std::max(1.0, std::min((double)W, x0 + len/2.0 * std::cos(ang)));
  double y2 = std::max(1.0, std::min((double)H, y0 + len/2.0 * std::sin(ang)));
  double w = std::abs(R::rnorm(0.0, 3.0)) + 1.0;
  double alpha = R::rbeta(3.0, 3.0);
  
  // Sample color from target along the line
  int nprobe = 20;
  NumericVector col(3, 0.0);
  int count = 0;
  
  for (int i = 0; i < nprobe; i++) {
    double t = (double)i / (nprobe - 1);
    int px = std::min(W, std::max(1, (int)std::round(x1 + t * (x2 - x1))));
    int py = std::min(H, std::max(1, (int)std::round(y1 + t * (y2 - y1))));
    
    if (px >= 1 && px <= W && py >= 1 && py <= H) {
      for (int c = 0; c < 3; c++) {
        col[c] += target[idx3(py, px, c, H, W)];
      }
      count++;
    }
  }
  
  if (count > 0) {
    for (int c = 0; c < 3; c++) {
      col[c] /= count;
    }
  }
  
  return List::create(
    Named("x1") = x1, Named("y1") = y1,
    Named("x2") = x2, Named("y2") = y2,
    Named("w") = w, Named("alpha") = alpha,
    Named("col") = col
  );
}

// ---- 7) Fast canvas re-rendering in bbox ----
// [[Rcpp::export]]
NumericVector re_render_bbox_from_lines_cpp(NumericVector base_canvas, 
                                           List lines, 
                                           int xmin, int xmax, int ymin, int ymax,
                                           int H, int W) {
  NumericVector canvas = clone(base_canvas);
  
  // Clear bbox region to white background
  for (int y = ymin; y <= ymax; y++) {
    for (int x = xmin; x <= xmax; x++) {
      for (int c = 0; c < 3; c++) {
        canvas[idx3(y, x, c, H, W)] = 1.0;  // white background
      }
    }
  }
  
  // Draw lines that intersect the bbox
  int n_lines = lines.length();
  for (int i = 0; i < n_lines; i++) {
    List line = lines[i];
    double x1 = as<double>(line["x1"]);
    double y1 = as<double>(line["y1"]);
    double x2 = as<double>(line["x2"]);
    double y2 = as<double>(line["y2"]);
    double w = as<double>(line["w"]);
    
    // Check if line intersects bbox
    double r = w / 2.0 + 2.0; // pad
    double line_xmin = std::min(x1, x2) - r;
    double line_xmax = std::max(x1, x2) + r;
    double line_ymin = std::min(y1, y2) - r;
    double line_ymax = std::max(y1, y2) + r;
    
    if (!(line_xmax < xmin || line_xmin > xmax || line_ymax < ymin || line_ymin > ymax)) {
      // Line intersects bbox, draw it
      double alpha = as<double>(line["alpha"]);
      NumericVector col = as<NumericVector>(line["col"]);
      
      // Calculate actual bbox overlap
      int draw_xmin = std::max(xmin, (int)std::floor(line_xmin));
      int draw_xmax = std::min(xmax, (int)std::ceil(line_xmax));
      int draw_ymin = std::max(ymin, (int)std::floor(line_ymin));
      int draw_ymax = std::min(ymax, (int)std::ceil(line_ymax));
      
      // Draw line in overlap region
      double vx = x2 - x1, vy = y2 - y1;
      double v2 = vx*vx + vy*vy + 1e-12;
      double r_line = 0.5 * w;
      double aa = 0.5;
      double inr = r_line - aa;
      double outr = r_line + aa;
      double in2 = (inr > 0) ? inr * inr : 0.0;
      double ou2 = outr * outr;
      
      for (int y = draw_ymin; y <= draw_ymax; y++) {
        double py = (double)y - 0.5;
        for (int x = draw_xmin; x <= draw_xmax; x++) {
          double px = (double)x - 0.5;
          
          double t = ((px - x1) * vx + (py - y1) * vy) / v2;
          if (t < 0.0) t = 0.0; else if (t > 1.0) t = 1.0;
          
          double projx = x1 + t * vx;
          double projy = y1 + t * vy;
          
          double dx = px - projx;
          double dy = py - projy;
          double d2 = dx * dx + dy * dy;
          
          double cov = 0.0;
          if (inr <= 0.0) {
            if (d2 < ou2) {
              cov = 1.0 - std::sqrt(d2) / outr;
              if (cov < 0.0) cov = 0.0;
            }
          } else {
            if (d2 <= in2) cov = 1.0;
            else if (d2 >= ou2) cov = 0.0;
            else {
              cov = 1.0 - (std::sqrt(d2) - inr) / (outr - inr);
            }
          }
          
          if (cov > 0.0 && alpha > 0.0) {
            double a = clamp01(cov * alpha);
            
            for (int c = 0; c < 3; c++) {
              int i = idx3(y, x, c, H, W);
              double in_val = canvas[i];
              canvas[i] = a * col[c] + (1.0 - a) * in_val;
            }
          }
        }
      }
    }
  }
  
  return canvas;
}

// ---- 8) Fast full canvas rendering from lines ----
// [[Rcpp::export]]
NumericVector render_full_canvas_cpp(List lines, int H, int W) {
  NumericVector canvas(H * W * 3, 1.0);  // white background
  
  int n_lines = lines.length();
  for (int i = 0; i < n_lines; i++) {
    List line = lines[i];
    double x1 = as<double>(line["x1"]);
    double y1 = as<double>(line["y1"]);
    double x2 = as<double>(line["x2"]);
    double y2 = as<double>(line["y2"]);
    double w = as<double>(line["w"]);
    double alpha = as<double>(line["alpha"]);
    NumericVector col = as<NumericVector>(line["col"]);
    
    // Calculate bbox
    double r = w / 2.0 + 2.0;
    int xmin = std::max(1, (int)std::floor(std::min(x1, x2) - r));
    int xmax = std::min(W, (int)std::ceil(std::max(x1, x2) + r));
    int ymin = std::max(1, (int)std::floor(std::min(y1, y2) - r));
    int ymax = std::min(H, (int)std::ceil(std::max(y1, y2) + r));
    
    // Draw line
    double vx = x2 - x1, vy = y2 - y1;
    double v2 = vx * vx + vy * vy + 1e-12;
    double r_line = 0.5 * w;
    double aa = 0.5;
    double inr = r_line - aa;
    double outr = r_line + aa;
    double in2 = (inr > 0) ? inr * inr : 0.0;
    double ou2 = outr * outr;
    
    for (int y = ymin; y <= ymax; y++) {
      double py = (double)y - 0.5;
      for (int x = xmin; x <= xmax; x++) {
        double px = (double)x - 0.5;
        
        double t = ((px - x1) * vx + (py - y1) * vy) / v2;
        if (t < 0.0) t = 0.0; else if (t > 1.0) t = 1.0;
        
        double projx = x1 + t * vx;
        double projy = y1 + t * vy;
        
        double dx = px - projx;
        double dy = py - projy;
        double d2 = dx * dx + dy * dy;
        
        double cov = 0.0;
        if (inr <= 0.0) {
          if (d2 < ou2) {
            cov = 1.0 - std::sqrt(d2) / outr;
            if (cov < 0.0) cov = 0.0;
          }
        } else {
          if (d2 <= in2) cov = 1.0;
          else if (d2 >= ou2) cov = 0.0;
          else {
            cov = 1.0 - (std::sqrt(d2) - inr) / (outr - inr);
          }
        }
        
        if (cov > 0.0 && alpha > 0.0) {
          double a = clamp01(cov * alpha);
          
          for (int c = 0; c < 3; c++) {
            int i = idx3(y, x, c, H, W);
            double in_val = canvas[i];
            canvas[i] = a * col[c] + (1.0 - a) * in_val;
          }
        }
      }
    }
  }
  
  return canvas;
}
