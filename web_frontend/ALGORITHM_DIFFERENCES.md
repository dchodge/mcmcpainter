# Algorithm Differences: Web Frontend vs R Implementation

## Critical Differences Found

### 1. Line Rendering
**Web Frontend:**
- Simple pixel-by-pixel linear interpolation
- NO antialiasing
- NO variable line width support (width parameter ignored)
- Basic alpha blending: `canvas = canvas * (1-alpha) + color * alpha`

**R/C++ Implementation:**
- Sophisticated antialiased line rendering with soft edges
- Full line width support with distance-based coverage
- Smooth antialiasing with inner/outer radius (0.5 pixel transition)
- Coverage calculation: `cov = 1.0 - (sqrt(d2) - inr) / (outr - inr)`
- Pixel centers at (x - 0.5, y - 0.5)

### 2. Birth Proposals
**Web Frontend:**
- Uniform random sampling only
- Random position, angle, length, color
- No data-driven proposals

**R/C++ Implementation:**
- Data-driven birth proposals (sample_line_birth_datadriven)
- Samples position weighted by residual magnitude
- Samples color from target image along proposed line
- Much smarter placement of new lines

### 3. MCMC Moves
**Web Frontend:**
- Only birth and death moves
- 50% birth probability when canvas not empty

**R/C++ Implementation:**
- Four move types: birth (25%), death (25%), jitter (45%), swap (5%)
- Jitter moves perturb existing line parameters
- Swap moves reorder lines for better composition

### 4. Temperature Schedule
**Web Frontend:**
- Fixed temperature: `exp(-(newSSE - currentSSE) * 0.001)`
- No adaptation over time

**R/C++ Implementation:**
- Adaptive temperature schedule: `beta_init * (beta_final/beta_init)^(t/iters)`
- Default: beta_init=0.1, beta_final=2.0
- Allows exploration early, refinement later

### 5. Acceptance Ratios
**Web Frontend:**
- Simple Metropolis-Hastings: `exp(-beta * delta_SSE)`
- No proper RJ-MCMC ratios
- No prior terms

**R/C++ Implementation:**
- Full RJ-MCMC acceptance ratios
- Includes: likelihood change + prior terms + proposal ratio + dimension change term
- Birth: `log_acc = -beta*delta_SSE + log_prior(line) + log_prior_K(K+1) - log_prior_K(K) + log(1/(K+1))`
- Death: inverse of birth ratio
- Proper Poisson prior on K (number of lines)

### 6. Line Prior
**Web Frontend:**
- No explicit prior evaluation
- Uniform sampling bounds

**R/C++ Implementation:**
- Half-normal prior on width: `w ~ N(0, 3^2)` truncated to w>0
- Beta(2,2) prior on alpha
- Proper log prior evaluation for acceptance ratios

### 7. Bounding Box Optimization
**Web Frontend:**
- Recomputes full canvas SSE every step
- Very inefficient

**R/C++ Implementation:**
- Bounding box calculations for local updates
- Only recomputes SSE in affected region
- Much faster, allows more complex operations

### 8. Random Number Generation
**Web Frontend:**
- C++ std::mt19937 with random_device seed
- Cannot be controlled for reproducibility

**R/C++ Implementation:**
- Uses R's RNG (can be seeded with set.seed())
- Reproducible results

## Impact on Results

These differences mean the web frontend:
1. Produces much cruder lines (no antialiasing)
2. Makes less intelligent placement decisions (no data-driven proposals)
3. Cannot refine existing lines (no jitter moves)
4. Less efficient exploration (no temperature schedule)
5. Different equilibrium distribution (missing prior terms)
6. Much slower (no bounding box optimization)

## Action Plan

To make implementations EXACTLY match:
1. Port complete line rendering from C++ to WASM
2. Implement data-driven birth proposals
3. Add jitter and swap moves
4. Implement temperature schedule
5. Add proper RJ-MCMC acceptance ratios with priors
6. Implement bounding box optimization
7. Add seedable RNG for reproducibility


