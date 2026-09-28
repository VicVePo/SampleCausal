# From the repository root, in a writable working directory:
# Rscript tools/build-release.R . ../release
# Prerequisite development packages: jsonlite, shiny, digest, testthat, knitr, markdown.
args <- commandArgs(trailingOnly = TRUE)
source <- normalizePath(if (length(args)) args[1L] else ".", winslash = "/", mustWork = TRUE)
destination <- if (length(args) > 1L) args[2L] else file.path(dirname(source), "release")
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
destination <- normalizePath(destination, winslash = "/", mustWork = TRUE)
metadata <- read.dcf(file.path(source, "DESCRIPTION"))
archive <- paste0(metadata[1L, "Package"], "_", metadata[1L, "Version"], ".tar.gz")
setwd(destination)
run <- function(arguments, log) {
  code <- system2(file.path(R.home("bin"), "R"), arguments, stdout = log, stderr = log)
  cat(readLines(log, warn = FALSE), sep = "\n")
  if (code != 0L) stop("Failed; see ", log)
}
run(c("CMD", "build", shQuote(source)), "build-source.log")
run(c("CMD", "check", "--no-manual", shQuote(archive)), "check.log")
check <- readLines(file.path(paste0(metadata[1L,"Package"], ".Rcheck"), "00check.log"), warn = FALSE)
if (!any(grepl("Status: OK", check, fixed = TRUE))) stop("Check did not finish with Status: OK")
cat("Source archive built and checked: ", file.path(destination, archive), "\n", sep = "")
# To build a Windows binary in a separate library:
# R CMD INSTALL --build --library=<existing-empty-directory> SampleCausal_1.0.2.tar.gz
# To verify installed archives with no attached default packages:
# Rscript --vanilla --default-packages=NULL tools/verify-installed.R <package-library> <dependency-library> <evidence-directory>
