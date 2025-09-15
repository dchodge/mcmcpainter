\name{mcmcPainter-package}
\alias{mcmcPainter-package}
\alias{mcmcPainter}
\docType{package}
\title{MCMC Line Painting Art Generation}
\description{
Generate artistic line paintings using Reversible Jump MCMC algorithms with 
automatic image analysis and parameter optimization. Creates beautiful line-based 
artwork from target images through iterative optimization of line parameters.
}
\details{
\tabular{ll}{
Package: \tab mcmcPainter\cr
Type: \tab Package\cr
Version: \tab 0.1.0\cr
License: \tab MIT + file LICENSE\cr
}

The package provides functions to:
\itemize{
  \item Load and analyze target images with automatic dimension detection
  \item Verify PNG files and detect renamed image files
  \item Auto-configure MCMC parameters for optimal performance
  \item Run MCMC algorithms to generate line paintings
  \item Create beautiful triptych visualizations
  \item Save results in multiple formats
}

Key functions:
\itemize{
  \item \code{\link{run_line_painter}}: Main function with auto-configuration
  \item \code{\link{auto_configure_mcmc}}: Intelligent parameter optimization
  \item \code{\link{get_image_info}}: Image analysis and PNG verification
  \item \code{\link{create_triptych}}: Create triptych visualizations
  \item \code{\link{save_triptych}}: Save triptychs to files
  \item \code{\link{load_image_rgb}}: Load and resize images
  \item \code{\link{save_png}}: Save images to PNG format
  \item \code{\link{view_rgb}}: Display RGB arrays as images
}
}
\author{
David Hodgson <david@example.com>
}
\references{
Reversible Jump MCMC algorithms for line-based artwork generation.
}
\keyword{package}
\keyword{art}
\keyword{mcmc}
\keyword{image processing}
