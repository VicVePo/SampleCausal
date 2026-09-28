# Build a Windows binary from an already installed, verified source archive.
# Useful when the external Info-ZIP executable is unavailable.
# Requires the development package zip (not a runtime dependency).
# Rscript tools/build-windows-binary.R <library-containing-package> <output-directory>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(.Platform$OS.type == "windows", length(args) == 2L)
library_path <- normalizePath(args[1L], winslash = "/", mustWork = TRUE)
destination <- normalizePath(args[2L], winslash = "/", mustWork = TRUE)
metadata <- read.dcf(file.path(library_path, "SampleCausal", "DESCRIPTION"))
stopifnot(grepl("windows", metadata[1L, "Built"], fixed = TRUE))
stopifnot(file.exists(file.path(library_path, "SampleCausal", "MD5")))
stopifnot(isTRUE(tools::checkMD5sums(dir = file.path(library_path, "SampleCausal"))))
archive <- file.path(destination, paste0("SampleCausal_", metadata[1L, "Version"], ".zip"))
zip::zip(archive, "SampleCausal", root = library_path, mode = "mirror")
cat("Windows binary archive: ", archive, "\n", sep = "")
cat("Payload: installed package and MD5 index, no source-library dependencies included.\n")
