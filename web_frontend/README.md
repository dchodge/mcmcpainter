# MCMC Painter - Web Frontend

Interactive web-based MCMC artistic painting using WebAssembly.

## Quick Start

```bash
# Build WASM module (auto-installs Emscripten if needed)
./build.sh

# Start web server
./start.sh

# Open http://localhost:3000
```

## Project Structure

```
web_frontend/
├── src/
│   └── mcmc_painter.cpp    # C++ MCMC implementation (matches R vignettes)
├── web/
│   ├── index.html          # Web interface
│   ├── app.js              # JavaScript controller
│   ├── mcmc_module.js      # Compiled WASM (generated)
│   ├── mcmc_module.wasm    # Compiled WASM binary (generated)
│   └── public/
│       └── lotus.png       # Default test image
├── build.sh                # Build script
└── start.sh                # Web server script
```

## Building

The `build.sh` script will:
1. Check for Emscripten (`emcc`)
2. If not found, clone and install emsdk locally
3. Compile `src/mcmc_painter.cpp` to WebAssembly
4. Output to `web/mcmc_module.js` and `web/mcmc_module.wasm`

```bash
./build.sh
```

## Running

```bash
./start.sh
```

This starts a Python HTTP server on port 3000.

## Usage

1. Open http://localhost:3000
2. Click "LOTUS" for default image or upload your own
3. Set parameters:
   - **Seed**: 42 (for reproducibility)
   - **Iterations**: 1000 (or more)
   - **Update Every**: 100
4. Click **START** to begin painting

## Matching R Vignette Implementation

The C++ code in `src/mcmc_painter.cpp` implements the **exact same algorithm** as the R package:

- ✅ Antialiased line rendering (soft edges)
- ✅ Data-driven birth proposals (residual-based)
- ✅ Four move types: Birth (25%), Death (25%), Jitter (45%), Swap (5%)
- ✅ Adaptive temperature: beta goes from 0.1 → 2.0
- ✅ Proper RJ-MCMC acceptance ratios with priors
- ✅ Same line priors (Half-normal on width, Beta(2,2) on alpha)
- ✅ Poisson prior on K (number of lines)

### Comparing with R

Run the R debug script:
```bash
cd ../create
Rscript debug_lotus_comparison.R
```

Then run web version with same parameters (seed=42, 1000 iterations) to compare.

## Notes

- The WASM module is compiled once and reused
- No Node.js required - just Python for simple HTTP server
- Emscripten SDK installs locally in `emsdk/` directory
- First build downloads ~1GB for Emscripten (one-time only)
