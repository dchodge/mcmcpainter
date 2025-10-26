#include <emscripten.h>
#include <emscripten/bind.h>
#include <vector>
#include <random>
#include <cmath>
#include <algorithm>

using namespace emscripten;

// Seedable random number generator (matching R's behavior as closely as possible)
class SeededRNG {
private:
    std::mt19937 gen;
    
public:
    SeededRNG(unsigned int seed = 42) : gen(seed) {}
    
    void setSeed(unsigned int seed) {
        gen.seed(seed);
    }
    
    // Uniform [min, max]
    double runif(double min, double max) {
        std::uniform_real_distribution<double> dis(min, max);
        return dis(gen);
    }
    
    // Standard normal
    double rnorm(double mean, double sd) {
        std::normal_distribution<double> dis(mean, sd);
        return dis(gen);
    }
    
    // Beta distribution (using method from Rcpp/R)
    double rbeta(double a, double b) {
        std::gamma_distribution<double> gamma_a(a, 1.0);
        std::gamma_distribution<double> gamma_b(b, 1.0);
        double x = gamma_a(gen);
        double y = gamma_b(gen);
        return x / (x + y);
    }
    
    // Uniform integer [0, n)
    int sample_int(int n) {
        std::uniform_int_distribution<int> dis(0, n - 1);
        return dis(gen);
    }
    
    // Get generator for shuffle
    std::mt19937& get_gen() {
        return gen;
    }
};

// Global RNG instance
SeededRNG rng(42);

// Helper: clamp to [0,1]
inline double clamp01(double v) {
    if (v < 0.0) return 0.0;
    if (v > 1.0) return 1.0;
    return v;
}

// Helper: linear index for [H, W, 3] array
inline int idx3(int y, int x, int c, int H, int W) {
    // Row-major order for flat [H*W*3] array: [y][x][c]
    return (y * W + x) * 3 + c;
}

// Structure for a line element (matching R implementation)
struct Line {
    double x1, y1, x2, y2;  // coordinates (1-based like R)
    double r, g, b;          // color
    double alpha;            // opacity
    double w;                // width
};

// Bounding box structure
struct BBox {
    int xmin, xmax, ymin, ymax;
};

// Calculate bounding box for a line (matching line_bbox_cpp)
BBox line_bbox(double x1, double y1, double x2, double y2, double w, int W, int H, int pad = 2) {
    double r = w / 2.0 + pad;
    BBox bbox;
    bbox.xmin = std::max(1, (int)std::floor(std::min(x1, x2) - r));
    bbox.xmax = std::min(W, (int)std::ceil(std::max(x1, x2) + r));
    bbox.ymin = std::max(1, (int)std::floor(std::min(y1, y2) - r));
    bbox.ymax = std::min(H, (int)std::ceil(std::max(y1, y2) + r));
    return bbox;
}

// Composite one line into canvas within bbox (matching composite_line_bbox_cpp)
void composite_line_bbox(std::vector<double>& canvas, int H, int W,
                         const Line& line, const BBox& bbox) {
    double vx = line.x2 - line.x1;
    double vy = line.y2 - line.y1;
    double v2 = vx * vx + vy * vy + 1e-12;
    
    const double r = 0.5 * line.w;
    const double aa = 0.5;
    const double inr = r - aa;
    const double outr = r + aa;
    const double in2 = (inr > 0) ? inr * inr : 0.0;
    const double ou2 = outr * outr;
    
    const double cr = line.r, cg = line.g, cb = line.b;
    
    for (int y = bbox.ymin; y <= bbox.ymax; ++y) {
        const double py = (double)y - 0.5;
        const int y0 = y - 1;
        
        for (int x = bbox.xmin; x <= bbox.xmax; ++x) {
            const double px = (double)x - 0.5;
            const int x0 = x - 1;
            
            // Bounds checking
            if (y0 < 0 || y0 >= H || x0 < 0 || x0 >= W) continue;
            
            double t = ((px - line.x1) * vx + (py - line.y1) * vy) / v2;
            if (t < 0.0) t = 0.0; else if (t > 1.0) t = 1.0;
            
            const double projx = line.x1 + t * vx;
            const double projy = line.y1 + t * vy;
            
            const double dx = px - projx;
            const double dy = py - projy;
            const double d2 = dx * dx + dy * dy;
            
            double cov = 0.0;
            if (inr <= 0.0) {
                // Soft ramp 0..1 over [0, outr]
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
            
            if (cov <= 0.0 || line.alpha <= 0.0) continue;
            
            const double a = clamp01(cov * line.alpha);
            
            const int i0 = idx3(y0, x0, 0, H, W);
            const int i1 = idx3(y0, x0, 1, H, W);
            const int i2 = idx3(y0, x0, 2, H, W);
            
            // Bounds checking
            if (i0 < 0 || i0 >= (int)canvas.size() || 
                i1 < 0 || i1 >= (int)canvas.size() || 
                i2 < 0 || i2 >= (int)canvas.size()) continue;
            
            const double inR = canvas[i0];
            const double inG = canvas[i1];
            const double inB = canvas[i2];
            
            canvas[i0] = a * cr + (1.0 - a) * inR;
            canvas[i1] = a * cg + (1.0 - a) * inG;
            canvas[i2] = a * cb + (1.0 - a) * inB;
        }
    }
}

// Compute SSE in bbox (matching sse_bbox_cpp)
double sse_bbox(const std::vector<double>& target, const std::vector<double>& canvas,
                int H, int W, const BBox& bbox) {
    double acc = 0.0;
    for (int y = bbox.ymin; y <= bbox.ymax; ++y) {
        for (int x = bbox.xmin; x <= bbox.xmax; ++x) {
            int i0 = idx3(y - 1, x - 1, 0, H, W);
            int i1 = idx3(y - 1, x - 1, 1, H, W);
            int i2 = idx3(y - 1, x - 1, 2, H, W);
            double d0 = target[i0] - canvas[i0];
            double d1 = target[i1] - canvas[i1];
            double d2 = target[i2] - canvas[i2];
            acc += d0 * d0 + d1 * d1 + d2 * d2;
        }
    }
    return acc;
}

// Render full canvas from lines (matching render_full_canvas_cpp)
std::vector<double> render_full_canvas(const std::vector<Line>& lines, int H, int W) {
    std::vector<double> canvas(H * W * 3, 1.0);  // white background
    
    for (const auto& line : lines) {
        BBox bbox = line_bbox(line.x1, line.y1, line.x2, line.y2, line.w, W, H, 2);
        composite_line_bbox(canvas, H, W, line, bbox);
    }
    
    return canvas;
}

// Re-render bbox from lines (matching re_render_bbox_from_lines_cpp)
std::vector<double> re_render_bbox_from_lines(const std::vector<double>& base_canvas,
                                               const std::vector<Line>& lines,
                                               const BBox& bbox, int H, int W) {
    std::vector<double> canvas = base_canvas;
    
    // Clear bbox region to white background
    for (int y = bbox.ymin; y <= bbox.ymax; ++y) {
        for (int x = bbox.xmin; x <= bbox.xmax; ++x) {
            for (int c = 0; c < 3; ++c) {
                canvas[idx3(y - 1, x - 1, c, H, W)] = 1.0;
            }
        }
    }
    
    // Draw lines that intersect bbox
    for (const auto& line : lines) {
        double r = line.w / 2.0 + 2.0;
        double line_xmin = std::min(line.x1, line.x2) - r;
        double line_xmax = std::max(line.x1, line.x2) + r;
        double line_ymin = std::min(line.y1, line.y2) - r;
        double line_ymax = std::max(line.y1, line.y2) + r;
        
        // Check if line intersects bbox
        if (!(line_xmax < bbox.xmin || line_xmin > bbox.xmax || 
              line_ymax < bbox.ymin || line_ymin > bbox.ymax)) {
            BBox draw_bbox;
            draw_bbox.xmin = std::max(bbox.xmin, (int)std::floor(line_xmin));
            draw_bbox.xmax = std::min(bbox.xmax, (int)std::ceil(line_xmax));
            draw_bbox.ymin = std::max(bbox.ymin, (int)std::floor(line_ymin));
            draw_bbox.ymax = std::min(bbox.ymax, (int)std::ceil(line_ymax));
            
            composite_line_bbox(canvas, H, W, line, draw_bbox);
        }
    }
    
    return canvas;
}

// Sample line from prior (matching sample_line_prior_cpp)
Line sample_line_prior(int W, int H) {
    Line line;
    line.x1 = rng.runif(1.0, W);
    line.y1 = rng.runif(1.0, H);
    double ang = rng.runif(0.0, 2.0 * M_PI);
    double len = std::abs(rng.rnorm(0.0, 30.0)) + 5.0;
    line.x2 = std::max(1.0, std::min((double)W, line.x1 + len * std::cos(ang)));
    line.y2 = std::max(1.0, std::min((double)H, line.y1 + len * std::sin(ang)));
    line.w = std::abs(rng.rnorm(0.0, 3.0)) + 1.0;
    line.alpha = rng.rbeta(2.0, 2.0);
    line.r = rng.runif(0.0, 1.0);
    line.g = rng.runif(0.0, 1.0);
    line.b = rng.runif(0.0, 1.0);
    return line;
}

// Data-driven birth proposal (matching sample_line_birth_datadriven_cpp)
Line sample_line_birth_datadriven(const std::vector<double>& target,
                                   const std::vector<double>& canvas,
                                   int H, int W) {
    // Calculate residual magnitude per pixel
    std::vector<double> mag_sq(H * W);
    
    for (int i = 0; i < H * W; ++i) {
        double sum = 0.0;
        for (int c = 0; c < 3; ++c) {
            double diff = target[i * 3 + c] - canvas[i * 3 + c];
            sum += diff * diff;
        }
        mag_sq[i] = std::sqrt(sum);
    }
    
    // Find max magnitude
    double max_mag = 0.0;
    for (int i = 0; i < H * W; ++i) {
        if (mag_sq[i] > max_mag) max_mag = mag_sq[i];
    }
    
    // Sample seed pixel
    double x0, y0;
    if (max_mag < 1e-6) {
        // Fallback to uniform
        x0 = rng.runif(1.0, W);
        y0 = rng.runif(1.0, H);
    } else {
        // Sample proportional to residual magnitude
        double total_weight = 0.0;
        for (int i = 0; i < H * W; ++i) {
            mag_sq[i] /= max_mag;
            total_weight += mag_sq[i];
        }
        
        double r = rng.runif(0.0, total_weight);
        double cumsum = 0.0;
        int idx = 0;
        for (int i = 0; i < H * W; ++i) {
            cumsum += mag_sq[i];
            if (cumsum >= r) {
                idx = i;
                break;
            }
        }
        
        int y = idx / W;
        int x = idx % W;
        y0 = y + 1;
        x0 = x + 1;
    }
    
    // Generate line parameters
    double ang = rng.runif(0.0, 2.0 * M_PI);
    double len = std::abs(rng.rnorm(0.0, 35.0)) + 8.0;
    
    Line line;
    line.x1 = std::max(1.0, std::min((double)W, x0 - len / 2.0 * std::cos(ang)));
    line.y1 = std::max(1.0, std::min((double)H, y0 - len / 2.0 * std::sin(ang)));
    line.x2 = std::max(1.0, std::min((double)W, x0 + len / 2.0 * std::cos(ang)));
    line.y2 = std::max(1.0, std::min((double)H, y0 + len / 2.0 * std::sin(ang)));
    line.w = std::abs(rng.rnorm(0.0, 3.0)) + 1.0;
    line.alpha = rng.rbeta(3.0, 3.0);
    
    // Sample color from target along the line
    int nprobe = 20;
    double col_r = 0.0, col_g = 0.0, col_b = 0.0;
    int count = 0;
    
    for (int i = 0; i < nprobe; ++i) {
        double t = (double)i / (nprobe - 1);
        int px = std::min(W, std::max(1, (int)std::round(line.x1 + t * (line.x2 - line.x1))));
        int py = std::min(H, std::max(1, (int)std::round(line.y1 + t * (line.y2 - line.y1))));
        
        if (px >= 1 && px <= W && py >= 1 && py <= H) {
            col_r += target[idx3(py - 1, px - 1, 0, H, W)];
            col_g += target[idx3(py - 1, px - 1, 1, H, W)];
            col_b += target[idx3(py - 1, px - 1, 2, H, W)];
            count++;
        }
    }
    
    if (count > 0) {
        line.r = col_r / count;
        line.g = col_g / count;
        line.b = col_b / count;
    } else {
        line.r = rng.runif(0.0, 1.0);
        line.g = rng.runif(0.0, 1.0);
        line.b = rng.runif(0.0, 1.0);
    }
    
    return line;
}

// Jitter line (matching jitter_line_cpp)
Line jitter_line(const Line& line, int W, int H,
                 double s_xy = 3.0, double s_w = 0.6,
                 double s_a = 0.1, double s_c = 0.08) {
    Line l2 = line;
    
    l2.x1 = std::max(1.0, std::min((double)W, line.x1 + rng.rnorm(0.0, s_xy)));
    l2.y1 = std::max(1.0, std::min((double)H, line.y1 + rng.rnorm(0.0, s_xy)));
    l2.x2 = std::max(1.0, std::min((double)W, line.x2 + rng.rnorm(0.0, s_xy)));
    l2.y2 = std::max(1.0, std::min((double)H, line.y2 + rng.rnorm(0.0, s_xy)));
    l2.w = std::max(0.2, line.w + rng.rnorm(0.0, s_w));
    l2.alpha = std::min(0.999, std::max(0.001, line.alpha + rng.rnorm(0.0, s_a)));
    
    l2.r = std::min(1.0, std::max(0.0, line.r + rng.rnorm(0.0, s_c)));
    l2.g = std::min(1.0, std::max(0.0, line.g + rng.rnorm(0.0, s_c)));
    l2.b = std::min(1.0, std::max(0.0, line.b + rng.rnorm(0.0, s_c)));
    
    return l2;
}

// Log prior for line (matching log_prior_line)
double log_prior_line(const Line& line, int W, int H) {
    // Check bounds
    if (line.x1 < 1 || line.x1 > W || line.x2 < 1 || line.x2 > W ||
        line.y1 < 1 || line.y1 > H || line.y2 < 1 || line.y2 > H ||
        line.w <= 0 || line.alpha <= 0 || line.alpha >= 1 ||
        line.r < 0 || line.r > 1 || line.g < 0 || line.g > 1 || line.b < 0 || line.b > 1) {
        return -INFINITY;
    }
    
    double lp = 0.0;
    
    // Half-normal on w (sigma=3)
    double sigma_w = 3.0;
    lp -= (line.w * line.w) / (2.0 * sigma_w * sigma_w);
    
    // Beta(2,2) on alpha
    lp += std::log(line.alpha) + std::log(1.0 - line.alpha);
    
    return lp;
}

// Log prior on K (matching log_prior_K)
double log_prior_K(int K, double lambda = 120.0) {
    if (K < 0) return -INFINITY;
    return K * std::log(lambda + 1e-12) - lambda - std::lgamma(K + 1);
}

// MCMC Painter class
class MCMCPainter {
private:
    std::vector<Line> lines;
    std::vector<double> targetImage;
    std::vector<double> canvas;
    int width, height;
    double currentSSE;
    double bestSSE;
    int bestIteration;
    std::vector<Line> bestLines;
    
    // MCMC parameters (matching R defaults)
    double beta_init = 0.1;
    double beta_final = 2.0;
    double prob_birth = 0.25;
    double prob_death = 0.25;
    double prob_jitter = 0.45;
    double prob_swap = 0.05;
    double K_lambda = 120.0;
    
public:
    MCMCPainter() : width(0), height(0), currentSSE(0), bestSSE(INFINITY), bestIteration(0) {}
    
    void setSeed(unsigned int seed) {
        rng.setSeed(seed);
    }
    
    void initialize(int imgWidth, int imgHeight, const std::vector<double>& imageData) {
        // Convert from flat [H*W*3] array
        width = imgWidth;
        height = imgHeight;
        
        targetImage.resize(height * width * 3);
        canvas.resize(height * width * 3, 1.0);  // white background
        
        // Copy image data
        for (size_t i = 0; i < imageData.size() && i < targetImage.size(); ++i) {
            targetImage[i] = imageData[i];
        }
        
        lines.clear();
        currentSSE = calculateFullSSE();
        bestSSE = currentSSE;
        bestIteration = 0;
        bestLines = lines;
        
        // Auto-configure K_lambda based on image size
        K_lambda = 0.5 * width;
    }
    
    void setParameters(double beta_i, double beta_f, double lambda) {
        beta_init = beta_i;
        beta_final = beta_f;
        K_lambda = lambda;
    }
    
    double calculateFullSSE() {
        double sse = 0.0;
        for (size_t i = 0; i < targetImage.size(); ++i) {
            double diff = targetImage[i] - canvas[i];
                    sse += diff * diff;
        }
        return sse;
    }
    
    double beta_schedule(int t, int iters) {
        return beta_init * std::pow(beta_final / beta_init, (double)t / iters);
    }
    
    bool mcmcStep(int iteration, int totalIterations) {
        double beta = beta_schedule(iteration, totalIterations);
        int K = lines.size();
        
        // Choose move type
        double r = rng.runif(0.0, 1.0);
        
        if (r < prob_birth) {
            // Birth move
            return birthMove(beta, K);
        } else if (r < prob_birth + prob_death && K > 0) {
            // Death move
            return deathMove(beta, K);
        } else if (r < prob_birth + prob_death + prob_jitter && K > 0) {
            // Jitter move
            return jitterMove(beta, K);
        } else if (K > 1) {
            // Swap move
            return swapMove(beta, K);
        }
        
        return false;
    }
    
    bool birthMove(double beta, int K) {
        // Propose new line using data-driven proposal
        Line prop = sample_line_birth_datadriven(targetImage, canvas, height, width);
        
        double lp_new = log_prior_line(prop, width, height);
        if (!std::isfinite(lp_new)) return false;
        
        BBox bbox = line_bbox(prop.x1, prop.y1, prop.x2, prop.y2, prop.w, width, height, 2);
        
        // Compute proposed canvas
        std::vector<double> canvas_prop = canvas;
        composite_line_bbox(canvas_prop, height, width, prop, bbox);
        
        // Compute acceptance ratio
        double sse_before = sse_bbox(targetImage, canvas, height, width, bbox);
        double sse_after = sse_bbox(targetImage, canvas_prop, height, width, bbox);
        
        double log_acc = -beta * (sse_after - sse_before) +
                         lp_new +
                         log_prior_K(K + 1, K_lambda) - log_prior_K(K, K_lambda) +
                         std::log(1.0 / (K + 1 + 1e-12));
        
        if (std::log(rng.runif(0.0, 1.0)) < log_acc) {
            // Accept
            lines.push_back(prop);
            canvas = canvas_prop;
            currentSSE = calculateFullSSE();
            
            if (currentSSE < bestSSE) {
                bestSSE = currentSSE;
                bestLines = lines;
            }
            return true;
        }
        
        return false;
    }
    
    bool deathMove(double beta, int K) {
        // Choose random line to remove
        int j = rng.sample_int(K);
        Line rem = lines[j];
        
        BBox bbox = line_bbox(rem.x1, rem.y1, rem.x2, rem.y2, rem.w, width, height, 2);
        
        // Build temp line list excluding j
        std::vector<Line> lines_wo;
        for (int i = 0; i < K; ++i) {
            if (i != j) lines_wo.push_back(lines[i]);
        }
        
        // Re-render bbox
        std::vector<double> canvas_prop = re_render_bbox_from_lines(canvas, lines_wo, bbox, height, width);
        
        double lp_rem = log_prior_line(rem, width, height);
        
        double sse_before = sse_bbox(targetImage, canvas, height, width, bbox);
        double sse_after = sse_bbox(targetImage, canvas_prop, height, width, bbox);
        
        double log_acc = -beta * (sse_after - sse_before) +
                         log_prior_K(K - 1, K_lambda) - log_prior_K(K, K_lambda) -
                         lp_rem +
                         std::log(K + 1e-12);
        
        if (std::log(rng.runif(0.0, 1.0)) < log_acc) {
            // Accept
            lines = lines_wo;
            canvas = render_full_canvas(lines, height, width);
            currentSSE = calculateFullSSE();
            
            if (currentSSE < bestSSE) {
                bestSSE = currentSSE;
                bestLines = lines;
            }
            return true;
        }
        
        return false;
    }
    
    bool jitterMove(double beta, int K) {
        // Choose random line to jitter
        int j = rng.sample_int(K);
        Line cur = lines[j];
        Line prop = jitter_line(cur, width, height);
        
        // Union bbox
        BBox b1 = line_bbox(cur.x1, cur.y1, cur.x2, cur.y2, cur.w, width, height, 2);
        BBox b2 = line_bbox(prop.x1, prop.y1, prop.x2, prop.y2, prop.w, width, height, 2);
        BBox bbox;
        bbox.xmin = std::max(1, std::min(b1.xmin, b2.xmin));
        bbox.xmax = std::min(width, std::max(b1.xmax, b2.xmax));
        bbox.ymin = std::max(1, std::min(b1.ymin, b2.ymin));
        bbox.ymax = std::min(height, std::max(b1.ymax, b2.ymax));
        
        // Remove current line from bbox, add proposed
        std::vector<Line> lines_wo;
        for (int i = 0; i < K; ++i) {
            if (i != j) lines_wo.push_back(lines[i]);
        }
        
        std::vector<double> canvas_wo = re_render_bbox_from_lines(canvas, lines_wo, bbox, height, width);
        std::vector<double> canvas_prop = canvas_wo;
        composite_line_bbox(canvas_prop, height, width, prop, bbox);
        
        double lp_cur = log_prior_line(cur, width, height);
        double lp_new = log_prior_line(prop, width, height);
        
        if (!std::isfinite(lp_new) || !std::isfinite(lp_cur)) return false;
        
        double sse_before = sse_bbox(targetImage, canvas, height, width, bbox);
        double sse_after = sse_bbox(targetImage, canvas_prop, height, width, bbox);
        
        double log_acc = -beta * (sse_after - sse_before) + (lp_new - lp_cur);
        
        if (std::log(rng.runif(0.0, 1.0)) < log_acc) {
            // Accept
            lines[j] = prop;
            canvas = render_full_canvas(lines, height, width);
            currentSSE = calculateFullSSE();
            
                if (currentSSE < bestSSE) {
                    bestSSE = currentSSE;
                bestLines = lines;
                }
                return true;
        }
        
        return false;
    }
    
    bool swapMove(double beta, int K) {
        // Random permutation
        std::vector<Line> lines_prop = lines;
        std::shuffle(lines_prop.begin(), lines_prop.end(), rng.get_gen());
        
        // Re-render full canvas
        std::vector<double> canvas_prop = render_full_canvas(lines_prop, height, width);
        
        double sse_old = currentSSE;
        double sse_new = 0.0;
        for (size_t i = 0; i < targetImage.size(); ++i) {
            double diff = targetImage[i] - canvas_prop[i];
            sse_new += diff * diff;
        }
        
        double log_acc = -beta * (sse_new - sse_old);
        
        if (std::log(rng.runif(0.0, 1.0)) < log_acc) {
            // Accept
            lines = lines_prop;
            canvas = canvas_prop;
            currentSSE = sse_new;
            
                if (currentSSE < bestSSE) {
                    bestSSE = currentSSE;
                bestLines = lines;
            }
            return true;
        }
        
        return false;
    }
    
    // Getters
    double getCurrentSSE() const { return currentSSE; }
    double getBestSSE() const { return bestSSE; }
    int getLinesCount() const { return lines.size(); }
    
    std::vector<double> getCurrentCanvas() {
        return canvas;
    }
    
    int getWidth() const { return width; }
    int getHeight() const { return height; }
};

// Emscripten bindings
EMSCRIPTEN_BINDINGS(mcmc_painter) {
    class_<MCMCPainter>("MCMCPainter")
        .constructor<>()
        .function("setSeed", &MCMCPainter::setSeed)
        .function("initialize", &MCMCPainter::initialize)
        .function("setParameters", &MCMCPainter::setParameters)
        .function("mcmcStep", &MCMCPainter::mcmcStep)
        .function("getCurrentSSE", &MCMCPainter::getCurrentSSE)
        .function("getBestSSE", &MCMCPainter::getBestSSE)
        .function("getLinesCount", &MCMCPainter::getLinesCount)
        .function("getCurrentCanvas", &MCMCPainter::getCurrentCanvas)
        .function("getWidth", &MCMCPainter::getWidth)
        .function("getHeight", &MCMCPainter::getHeight);
    
    register_vector<double>("DoubleVector");
}

