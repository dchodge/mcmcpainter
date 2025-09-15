# mcmcPainter

**MCMC-Based Artistic Line and Dot Painting Generation**

A high-performance R package for generating artistic line and dot paintings using Reversible Jump MCMC algorithms. Transform any image into beautiful line-based or pointillism-style artwork through iterative optimization.

## Package Structure

```
mcmcPainter/
├── DESCRIPTION                 # Package metadata
├── README.md                  # This file
├── R/                        # R source code
│   ├── mcmcPainter.R         # Main package functions
│   ├── mcmc_core.R           # Core MCMC algorithm
│   └── utilities.R           # Utility functions
├── inst/                     # Package data and results
│   ├── extdata/              # Input images (leaf.png, leaf_converted.png, iamami.png)
│   ├── figures/              # Generated artwork and examples
│   └── results/              # MCMC output directories
├── man/                      # Package documentation
│   └── mcmcPainter-package.Rd # Main package documentation
├── src/                      # C++ source code
│   └── mcmc_painter_cpp.cpp # C++ optimization code
├── vignettes/                # Package vignettes
│   ├── mcmcPainter_demo.Rmd # Complete package demo
│   ├── leaf_mcmc_demo.Rmd   # Leaf image MCMC demo
│   └── iamami_mcmc_demo.Rmd # Iamami image MCMC demo with auto-configuration
├── demo_mcmcPainter.R        # Package functionality demo
├── create_leaf_triptych.R    # Standalone triptych script
├── create_iamami_triptych.R  # Iamami triptych with auto-configuration
└── OPTIMIZATION_SUMMARY.md   # Performance optimization details
```

## Key Features

- **🎨 Dual Art Styles**: Generate both line-based and dot-based (pointillism) artwork
- **⚡ High Performance**: C++ optimized core functions for fast MCMC sampling
- **🖼️ Flexible Input**: Supports various image formats (PNG, JPEG, etc.)
- **📐 Smart Scaling**: Automatic image analysis and parameter optimization
- **📊 Progress Tracking**: Saves intermediate results every N iterations
- **🎯 Quality Control**: PNG verification and intelligent parameter tuning
- **📦 Professional Package**: Full R package structure with vignettes and documentation

## Quick Start

```r
# Install dependencies
install.packages(c("Rcpp", "magick", "png", "knitr", "rmarkdown"))

# Load the package
source("R/mcmcPainter.R")
source("R/mcmc_core.R") 
source("R/utilities.R")

# Compile C++ code
Rcpp::sourceCpp("src/mcmc_painter_cpp.cpp")

# Generate line painting
res <- run_line_painter(
  image_path = "inst/extdata/leaf_converted.png",
  iters = 10000,
  out_dir = "inst/results/my_artwork"
)

# Create visualization
create_triptych(
  default_canvas = array(1, dim = c(800, 1422, 3)),
  best_canvas = res$best$canvas,
  target_img = load_image_rgb("inst/extdata/leaf_converted.png", 800, 1422)
)
```

## Key Functions

### **Line Painting**
- `run_line_painter()`: Main function to generate line paintings
- `create_triptych()`: Create before/after visualizations
- `save_triptych()`: Save triptychs to PDF/PNG

### **Dot Painting** 🆕
- `run_dot_painter()`: Main function to generate dot paintings
- `create_dot_triptych()`: Create dot painting visualizations
- `save_dot_triptych()`: Save dot triptychs to PDF/PNG

### **Utilities**
- `load_image_rgb()`: Load and resize target images
- `save_png()`: Save generated artwork
- `view_rgb()`: Display images
- `get_image_info()`: Analyze image properties
- `auto_configure_mcmc()`: Optimize parameters automatically

## MCMC Algorithms

### **Line Painting Algorithm**
The package implements a Reversible Jump MCMC algorithm with four move types:

1. **Birth**: Add new lines based on image residuals
2. **Death**: Remove existing lines
3. **Jitter**: Perturb line parameters
4. **Swap**: Reorder line rendering

### **Dot Painting Algorithm** 🆕
A specialized MCMC algorithm for pointillism-style artwork:

1. **Birth**: Add new dots based on image residuals
2. **Death**: Remove existing dots
3. **Jitter**: Modify dot position, radius, alpha, and color
4. **Adaptive**: Temperature adjustment for optimal exploration

## Performance

- **3-20x speedup** compared to pure R implementation
- **Optimized C++** core functions for line rendering
- **Efficient memory** management and array operations
- **Scalable** to large images (1000x1000+ pixels)

## Output Structure

Each MCMC run creates:
- `iter_000000.png`: Initial white canvas
- `iter_001000.png`: After 1,000 iterations
- `iter_002000.png`: After 2,000 iterations
- `...`
- `final.png`: Final result
- `best_iter_XXXXXX.png`: Best iteration found

## Requirements

- R >= 4.0.0
- Rcpp
- magick
- png

## Installation

```r
# Install dependencies
install.packages(c("Rcpp", "magick", "png", "knitr", "rmarkdown"))

# Clone or download the package
# git clone https://github.com/davidhodgson/mcmcPainter.git

# Source the package
source("R/mcmcPainter.R")
source("R/mcmc_core.R")
source("R/utilities.R")

# Compile C++ code
Rcpp::sourceCpp("src/mcmc_painter_cpp.cpp")
```

## Examples

See the `inst/results/` directory for example outputs from various MCMC runs.

## Vignettes

The package includes comprehensive vignettes demonstrating the workflow:

- **`vignettes/mcmcPainter_demo.Rmd`**: Complete package functionality demo
- **`vignettes/leaf_mcmc_demo.Rmd`**: Leaf image MCMC demo
- **`vignettes/iamami_mcmc_demo.Rmd`**: Iamami image MCMC demo with auto-configuration
- **`vignettes/butterfly_mcmc_demo.Rmd`**: Butterfly image 100K MCMC demo
- **`vignettes/octopus_mcmc_demo.Rmd`**: Octopus image 100K MCMC demo
- **`vignettes/me_mcmc_demo.Rmd`**: Personal image 100K MCMC demo

## Pre-built Scripts

For quick results, use the pre-built scripts in the `create/` folder:

### **Line Painting Scripts**
#### **High-Quality 100K MCMC Runs**
```r
# Maximum detail and quality (3-5 hours runtime)
source("create/create_butterfly_triptych.R")  # 4.2MB image
source("create/create_me_triptych.R")         # 3.2MB image
source("create/create_octopus_triptych.R")    # 380KB image
source("create/run_iamami_100k.R")            # 336KB image
```

#### **Standard MCMC Runs**
```r
# Quick results (30-60 minutes runtime)
source("create/create_leaf_triptych.R")       # 132KB image
source("create/create_iamami_triptych.R")     # 336KB image
```

### **Dot Painting Scripts** 🆕
```r
# Pointillism-style artwork (30-60 minutes runtime)
source("create/create_dot_triptych.R")        # Leaf image with dots
```

### **Running the Demos**

```r
# Run the complete package demo
source("demo_mcmcPainter.R")

# Run any specific image demo
source("create/create_butterfly_triptych.R")

# Or render the vignettes
rmarkdown::render("vignettes/mcmcPainter_demo.Rmd")
rmarkdown::render("vignettes/leaf_mcmc_demo.Rmd")
rmarkdown::render("vignettes/iamami_mcmc_demo.Rmd")
```

### New Auto-Configuration Features

The package now includes intelligent image analysis:

- **`get_image_info()`**: Automatically detects image dimensions and verifies PNG files
- **`auto_configure_mcmc()`**: Optimizes MCMC parameters based on image complexity
- **Smart scaling**: Automatically adjusts dimensions for optimal performance
- **PNG verification**: Distinguishes between true PNG files and renamed files

## License

MIT License - see LICENSE file for details.
