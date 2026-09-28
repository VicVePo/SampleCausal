# Optional project library restored from renv.lock; otherwise use installed R packages.
sc_use_library <- function(root) {
  lib<-file.path(root,"r-library")
  if(dir.exists(lib)) .libPaths(c(normalizePath(lib,winslash="/"),.libPaths()))
  invisible(.libPaths())
}

