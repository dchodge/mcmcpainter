# Compiling and Running the Web Frontend

## Overview

The web frontend now uses the EXACT same MCMC algorithm as the R implementation. This document explains how to compile the WebAssembly module and run the debug comparison.

## Prerequisites

1. **Emscripten SDK** - for compiling C++ to WebAssembly
2. **R and mcmcPainter package** - for running comparison tests
3. **Node.js** - for running the web server

### Install Emscripten

```bash
# Download and install Emscripten
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

## Step 1: Compile WebAssembly Module

From the `web_frontend` directory:

```bash
cd /Users/davidhodgson/Dropbox/personal_new/play/mcmc_art/practice/web_frontend

# Compile the WASM module
emcc mcmc_wasm.cpp \
  -o mcmc_wasm.js \
  -s WASM=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s MODULARIZE=1 \
  -s EXPORT_NAME='Module' \
  -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap"]' \
  -s EXPORTED_FUNCTIONS='["_malloc","_free"]' \
  --bind \
  -O3 \
  -std=c++11
```

This will generate:
- `mcmc_wasm.js` - JavaScript glue code
- `mcmc_wasm.wasm` - WebAssembly binary

## Step 2: Run the Web Server

```bash
cd web_frontend
npm install
npm start
```

The server will start on http://localhost:3000

## Step 3: Run Debug Comparison with R

Open a new terminal and run the R debug script:

```bash
cd /Users/davidhodgson/Dropbox/personal_new/play/mcmc_art/practice/create
Rscript debug_lotus_comparison.R
```

This will:
- Run the R implementation with seed=42 for 1000 iterations
- Save detailed trace and parameters to `inst/results/lotus_debug_comparison/`
- Generate comparison files:
  - `run_parameters.json` - All run parameters
  - `first_10_lines.csv` - Details of first 10 lines
  - `detailed_trace.txt` - Move-by-move trace of first 50 iterations

## Step 4: Run Web Frontend with Same Parameters

1. Open http://localhost:3000 in your browser
2. Click "LOTUS" to load the default lotus image
3. Set parameters to match R debug run:
   - Seed: **42**
   - Iterations: **1000**
   - Update Every: **100**
   - Click "ADVANCED PARAMETERS" and verify:
     - Beta Init: **0.1**
     - Beta Final: **2.0**
     - K Lambda: **0** (will auto-set to 0.5 × width)
     - Max Dimension: **400**
4. Click **START**

## Step 5: Compare Results

### Visual Comparison
- Compare the final paintings side-by-side
- They should look VERY similar (not identical due to floating point differences)

### Numerical Comparison
Compare these metrics from both runs:

1. **Final SSE** - should be very close
2. **Number of lines** - should be similar (within 10%)
3. **Line parameters** - check first_10_lines.csv against web console

### Debug with Detailed Trace

If results differ significantly:

1. Check the `detailed_trace.txt` from R run
2. Add console logging to web frontend to trace first 50 iterations
3. Compare move-by-move:
   - Move types accepted/rejected
   - K (number of lines) after each move
   - SSE changes
   - Beta values

## Key Differences to Check

If implementations still differ, check these critical areas:

### 1. Random Number Generation
- R uses: `runif()`, `rnorm()`, `rbeta()`
- WASM uses: `std::mt19937` with same seed

RNG differences are the most common source of divergence.

### 2. Line Rendering
- Both should use EXACT same antialiasing algorithm
- Check pixel centers: (x - 0.5, y - 0.5)
- Check coverage calculation matches exactly

### 3. Acceptance Ratios
- Birth: includes data-driven proposal, priors, K prior
- Death: inverse of birth
- Jitter: symmetric proposal with priors
- Swap: simple likelihood ratio

### 4. Temperature Schedule
- Beta(t) = beta_init * (beta_final/beta_init)^(t/iters)
- Should be identical at each iteration

## Troubleshooting

### WASM compilation fails
- Make sure Emscripten is activated: `source ./emsdk_env.sh`
- Check C++ syntax - must be C++11 compatible

### Web page shows "MCMC engine ready!" but nothing happens
- Open browser console (F12) to see errors
- Check that `mcmc_wasm.js` and `mcmc_wasm.wasm` are loaded
- Verify image is processed correctly

### Results differ significantly
1. Double-check seed is the same
2. Verify all parameters match
3. Check image dimensions match
4. Run detailed trace comparison
5. Look for floating point precision differences

### Performance is slow
- Make sure WASM is compiled with `-O3` optimization
- Check that bounding box optimization is working
- Reduce update frequency to update less often

## Expected Performance

- **R implementation**: ~100-500 iterations/second (depends on image size)
- **WASM implementation**: Should be similar or faster

For 1000 iterations on 400×400px image:
- Expected time: 2-10 seconds
- Final K (lines): 50-150
- Final SSE: varies by image, should be decreasing

## Next Steps

Once you confirm both implementations produce similar results:

1. Run longer test (10,000 iterations)
2. Try different images
3. Test with different seeds
4. Experiment with different parameters
5. Create side-by-side comparison gallery

