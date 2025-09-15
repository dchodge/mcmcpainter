\name{mcmcArt-package}
\alias{mcmcArt-package}
\alias{mcmcArt}
\docType{package}
\title{MCMC Line Painting Art Generation}
\description{
Generate artistic line paintings using Reversible Jump MCMC algorithms. 
Creates beautiful line-based artwork from target images through iterative 
optimization of line parameters.
}
\details{
\tabular{ll}{
Package: \tab mcmcArt\cr
Type: \tab Package\cr
Version: \tab 0.1.0\cr
License: \tab MIT + file LICENSE\cr
}

The package provides functions to:
\itemize{
  \item Load and resize target images
  \item Run MCMC algorithms to generate line paintings
  \item Save intermediate results and final artwork
  \item View and manipulate generated images
}

Key functions:
\itemize{
  \item \code{\link{run_line_painter}}: Main function to generate line paintings
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
