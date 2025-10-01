# Create Lotus MCMC Line Painting Triptych
# This script runs the MCMC line painting algorithm on lotus.png for 100,000 steps
# and creates a triptych showing the progression from white canvas to final artwork

# Load the package functions
source("R/mcmcPainter.R")

# Set up paths
image_path <- "inst/extdata/lotus.png"
out_dir <- "inst/results/lotus_line_painting_100k"

# Create output directory if it doesn't exist
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

# Run the MCMC line painting algorithm
cat("Starting MCMC line painting for lotus.png...\n")
cat("This will run for 100,000 iterations and may take several hours.\n")

res <- run_line_painter(
  image_path = image_path,
  max_dimension = 1200,
  iters = 100000,
  out_dir = out_dir,
  seed = 42,
  auto_config = TRUE,
  save_every = 5000,
  verbose = TRUE
)

# Create the triptych
cat("Creating triptych...\n")
triptych_path <- create_triptych(
  image_path = image_path,
  result = res,
  out_path = "inst/results/lotus_line_triptych.png",
  max_dimension = 1200
)

cat("Lotus MCMC line painting completed!\n")
cat("Results saved to:", out_dir, "\n")
cat("Triptych saved to:", triptych_path, "\n")
