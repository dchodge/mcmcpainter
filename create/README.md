# Create Scripts

This folder contains standalone scripts for running MCMC painting on specific images and generating triptych visualizations. The package supports both **line painting** and **dot painting** algorithms.

## 🎨 **Available Scripts**

### **Line Painting Scripts**

#### **High-Quality 100K MCMC Runs**
- **`create_butterfly_triptych.R`** - Butterfly image (4.2MB, 2068x2091px)
  - 100,000 iterations with saves every 5,000 steps
  - High resolution (max dimension 1200px)
  - Expected runtime: 3-5 hours

- **`create_me_triptych.R`** - Personal image (3.2MB, 1500x1825px)
  - 100,000 iterations with saves every 5,000 steps
  - High resolution (max dimension 1200px)
  - Expected runtime: 3-5 hours

- **`create_octopus_triptych.R`** - Octopus image (380KB, 964x900px)
  - 100,000 iterations with saves every 5,000 steps
  - High resolution (max dimension 1200px)
  - Expected runtime: 3-5 hours

- **`run_iamami_100k.R`** - Iamami image (336KB, 788x605px)
  - 100,000 iterations with saves every 5,000 steps
  - High resolution (max dimension 1200px)
  - Expected runtime: 3-5 hours

#### **Standard MCMC Runs**
- **`create_iamami_triptych.R`** - Iamami image (336KB, 788x605px)
  - 20,000 iterations with auto-configuration
  - Optimized parameters for medium complexity
  - Expected runtime: 30-60 minutes

- **`create_leaf_triptych.R`** - Leaf image (132KB, 800x1422px)
  - 20,000 iterations with auto-configuration
  - Optimized parameters for medium complexity
  - Expected runtime: 30-60 minutes

### **Dot Painting Scripts** 🆕

- **`create_dot_triptych.R`** - Leaf image (132KB, 800x1422px)
  - 20,000 iterations with saves every 1,000 steps
  - Pointillism-style artwork using dots
  - Optimized for dot rendering (max dimension 800px)
  - Expected runtime: 30-60 minutes

## 🚀 **Usage**

### **Quick Start**

```r
# Line Painting - High Quality (100K iterations)
source("create/create_butterfly_triptych.R")
source("create/create_me_triptych.R")
source("create/create_octopus_triptych.R")
source("create/run_iamami_100k.R")

# Line Painting - Standard (20K iterations)
source("create/create_iamami_triptych.R")
source("create/create_leaf_triptych.R")

# Dot Painting - Pointillism Style 🆕
source("create/create_dot_triptych.R")
```

### **Background Execution (Recommended for Long Runs)**

```bash
# Run in background with logging
nohup Rscript -e "source('create/create_butterfly_triptych.R')" > butterfly_100k.log 2>&1 &

# Monitor progress
tail -f butterfly_100k.log
```

## 📊 **Output Structure**

Each script creates a results folder with:

```
inst/results/[image_name]_[quality]/
├── iter_000000.png          # Initial white canvas
├── iter_005000.png          # Progress snapshots
├── iter_010000.png          # Every 5K iterations
├── ...
├── iter_100000.png          # Final result
├── best_canvas.png          # Best canvas found
├── final_lines.RData        # Line parameters
├── [image]_triptych.pdf     # Triptych visualization
├── [image]_triptych.png     # Triptych visualization
└── mcmc_progress.log        # Progress log
```

## 🎯 **Performance Expectations**

### **High-Quality 100K Runs**
- **Line Count**: 800-2000+ lines
- **Quality**: Near-photorealistic
- **Memory**: 50-200 MB
- **Runtime**: 3-5 hours

### **Standard 20K Runs**
- **Line Count**: 300-800 lines
- **Quality**: High artistic quality
- **Memory**: 20-100 MB
- **Runtime**: 30-60 minutes

## 🔧 **Customization**

### **Modify Parameters**

Edit any script to change:
- `iters`: Number of MCMC iterations
- `max_dimension`: Maximum image dimension
- `seed`: Random seed for reproducibility
- `out_dir`: Output directory path

### **Add New Images**

1. Copy an existing script
2. Change `image_path` to your image
3. Adjust parameters as needed
4. Run the script

## 📚 **Related Documentation**

- **Main Package**: See `../README.md`
- **Vignettes**: See `../vignettes/`
- **Core Functions**: See `../R/`
- **C++ Code**: See `../src/`

## ⚠️ **Notes**

- **Long Runs**: 100K iterations take several hours
- **Memory**: High-resolution images use significant memory
- **Storage**: Results can be several GB
- **Backup**: Consider backing up important results

---

**Happy Painting!** 🎨✨
