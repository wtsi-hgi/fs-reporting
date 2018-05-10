# Bootstrap environment for running the pipeline on the farm
# Christopher Harrison <ch12@sanger.ac.uk>

# n.b., This must be sourced

# Add build tools and teepot
module purge
module add hgi/git/latest \
           hgi/gcc/latest \
           hgi/autoconf/latest \
           hgi/automake/latest \
           hgi/teepot/latest

# Use R 3.4.2 and our localised package library
export PATH="/software/R-3.4.2/bin:${PATH}"
export R_LIBS="$(git rev-parse --show-toplevel)/sanger/R-modules:${R_LIBS}"

# Make sure our R dependencies are installed
Rscript - <<R
install <- function(pkg) {
  if (!require(pkg)) {
    install.packages(pkg, repos = "https://cloud.r-project.org/")
  } else {
    write(sprintf("%s is installed", pkg), stderr())
  }
}

install("dplyr")
install("ggplot2")
install("xtable")
install("functional")
R

# TODO Make sure LaTeX packages are installed...
