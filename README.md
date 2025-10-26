# mcmcPainter

**MCMC-Based Artistic Line and Dot Painting Generation**

Transform any image into line-based or pointillism-style artwork using Reversible Jump MCMC algorithms. This R package combines statistical optimization with digital art generation to create stunning artistic interpretations of photographs.

Live web app is here: mcmcpainter.davidhodgson.me

## Visual Example

Here's an example of the MCMC line painting algorithm in action, showing the complete transformation from a white canvas to a detailed portrait:

![vi_leigh_triptych](man/figures/vi_leigh_line_triptych.png)

*Complete progression from white canvas to final artwork over 100,000 iterations*

## Overview

`mcmcPainter` uses advanced Markov Chain Monte Carlo (MCMC) techniques to iteratively build artwork by adding, removing, and modifying artistic elements (lines or dots) until the result closely matches a target image. The algorithm intelligently explores the space of possible artworks, gradually improving the match through statistical optimization.

## Key Features

- **🎨 Dual Art Styles**: Generate both line-based and dot-based (pointillism) artwork
- **⚡ High Performance**: C++ optimized core functions for fast MCMC sampling
- **🖼️ Flexible Input**: Supports various image formats (PNG, JPEG, etc.)
- **📐 Smart Scaling**: Automatic image analysis and parameter optimization
- **📊 Progress Tracking**: Saves intermediate results every N iterations
- **🎯 Quality Control**: PNG verification and intelligent parameter tuning
- **📦 Professional Package**: Full R package structure with comprehensive documentation

## Installation

```r
# Install dependencies
install.packages(c("Rcpp", "magick", "png", "knitr", "rmarkdown"))

# Clone the repository
# git clone https://github.com/davidhodgson/mcmcPainter.git

# Load the package
source("R/mcmcPainter.R")
source("R/mcmc_core.R") 
source("R/utilities.R")

# Compile C++ code
Rcpp::sourceCpp("src/mcmc_painter_cpp.cpp")
```

## Quick Start

### Line Painting

```r
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

## How It Works

### The MCMC Algorithm

The package implements a Reversible Jump MCMC algorithm with four types of moves:

1. **Birth**: Add new artistic elements (lines or dots) based on image residuals
2. **Death**: Remove existing elements
3. **Jitter**: Perturb element parameters (position, color, opacity, size)
4. **Swap**: Reorder element rendering for better composition

### Line Painting Algorithm

For line-based artwork, each line is defined by:

- **Position**: Start and end coordinates (x1, y1, x2, y2)
- **Color**: RGB values (r, g, b)
- **Opacity**: Alpha transparency (0-1)
- **Thickness**: Line width in pixels

The algorithm uses data-driven birth proposals, sampling new lines from areas with high image residuals to focus on important features.

### Performance Optimization

- **C++ Implementation**: Core rendering functions written in C++ for 3-20x speedup
- **Bounding Box Optimization**: Only re-renders affected regions for efficiency
- **Adaptive Temperature**: Gradually increases exploration to balance quality and speed
- **Memory Management**: Efficient array operations and memory usage

## Main Functions

### Line Painting

- `run_line_painter()`: Main function to generate line paintings
- `create_triptych()`: Create before/after visualizations
- `save_triptych()`: Save triptychs to PDF/PNG

### Utilities

- `load_image_rgb()`: Load and resize target images
- `save_png()`: Save generated artwork
- `view_rgb()`: Display images
- `get_image_info()`: Analyze image properties
- `auto_configure_mcmc()`: Optimize parameters automatically

## Examples

### High-Quality Line Painting: Portrait Progression

Here's a stunning example of the MCMC line painting algorithm in action, showing the progression from a white canvas to a detailed portrait over 100,000 iterations:

|               Initial Canvas               |         25,000 Iterations         |         50,000 Iterations         |         75,000 Iterations         |          Final Result (100K)          |
| :----------------------------------------: | :--------------------------------: | :--------------------------------: | :--------------------------------: | :------------------------------------: |
| ![Initial](man/figures/vi_leigh_initial.png) | ![25K](man/figures/vi_leigh_25k.png) | ![50K](man/figures/vi_leigh_50k.png) | ![75K](man/figures/vi_leigh_75k.png) | ![Final](man/figures/vi_leigh_final.png) |

*This example demonstrates the algorithm's ability to capture fine facial details, hair texture, and subtle shading through strategic line placement and optimization.*

### Additional Examples

The package includes several other example images and pre-generated results:

- **Leaf**: Botanical line artwork (132KB image)
- **Iamami**: Portrait with auto-configuration (336KB image)
- **Butterfly**: High-detail 100K iteration run (4.2MB image)
- **Octopus**: Marine life pointillism (380KB image)
- **Portrait**: Personal photo artwork (3.2MB image)

## Vignettes

Comprehensive tutorials are available:

- **Complete Demo**: Full package functionality walkthrough
- **Leaf Tutorial**: Step-by-step line painting example
- **Iamami Tutorial**: Auto-configuration and optimization
- **High-Quality Examples**: 100K iteration demonstrations

## License

MIT License - see LICENSE file for details.
