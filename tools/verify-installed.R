# Run after installing a distribution archive, with R_DEFAULT_PACKAGES=NULL.
# Arguments: package library, dependency library, evidence directory.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
.libPaths(c(args[1L], args[2L], .Library))
destination <- args[3L]
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
search_before <- search()
stopifnot(!"package:stats" %in% search_before)
pkg <- normalizePath(find.package("SampleCausal"), winslash = "/")
stopifnot(identical(pkg, normalizePath(file.path(args[1L], "SampleCausal"), winslash = "/")))
hash_tree <- function(root) {
  paths <- list.files(root, recursive = TRUE, all.files = TRUE, full.names = TRUE)
  paths <- paths[!file.info(paths)$isdir]
  hashes <- vapply(paths, function(p) digest::digest(file = p, algo = "sha256"), "")
  names(hashes) <- substring(paths, nchar(root) + 2L)
  hashes
}
before <- hash_tree(pkg)
omit_time <- function(x) {
  if (is.list(x)) { x$generated_at <- NULL; x <- lapply(x, omit_time) }
  x
}
fixture <- function(name) jsonlite::fromJSON(system.file("extdata", name, package = "SampleCausal"), simplifyVector = FALSE)
inputs <- fixture("phase5-inputs.json")
expected <- fixture("phase5-results-1.0.1.json")
actual <- lapply(inputs, SampleCausal::causal_calculate)
stopifnot(isTRUE(all.equal(omit_time(actual), omit_time(expected), tolerance = 1e-10)))
stopifnot(identical(vapply(actual, function(x) x$status, ""),
                   c(T1="ok", T2="ok", T3="ok", T4="unattainable", T5="ok", T6A="disabled_variant", T6B="ok")))
for (case in actual) if (!is.null(case$inputs)) {
  stopifnot(isTRUE(all.equal(omit_time(SampleCausal::causal_replay(case)), omit_time(case), tolerance = 1e-10)))
}
historical <- Filter(function(x) !is.null(x$inputs), fixture("phase5-results-1.0.0.json"))
historical[["0.4.3"]] <- fixture("historical-0.4.3.json")
for (case in historical) {
  stopifnot(isTRUE(all.equal(omit_time(SampleCausal::causal_replay(case)), omit_time(case), tolerance = 1e-10)))
}
engine_root <- system.file("engine", package = "SampleCausal")
manifest <- jsonlite::fromJSON(file.path(engine_root, "source-manifest.json"), simplifyVector = FALSE)
for (item in manifest$files) {
  stopifnot(identical(digest::digest(file = file.path(engine_root, item$path), algo = "sha256"), item$sha256))
}
exports <- SampleCausal::causal_export(actual$T1, file.path(destination, "exports"))
stopifnot(isTRUE(all.equal(omit_time(SampleCausal::causal_replay(exports$saved_json)), omit_time(actual$T1), tolerance = 1e-10)))
sensitivity <- SampleCausal::causal_sensitivity(SampleCausal::causal_example("T3"), "delta", c(.03,.2,.3))
saved <- SampleCausal::causal_export(sensitivity, file.path(destination, "exports"))
stopifnot(isTRUE(all.equal(omit_time(SampleCausal::causal_replay(saved$saved_json)), omit_time(sensitivity), tolerance = 1e-10)))
stopifnot(nrow(SampleCausal::causal_methods()) == 6L)
app <- SampleCausal::samplecausal_app(file.path(destination, "app-exports"))
stopifnot(inherits(app, "shiny.appobj"))
stopifnot(identical(search(), search_before))
stopifnot(!exists("SC_ROOT", envir = .GlobalEnv, inherits = FALSE))
stopifnot(identical(before, hash_tree(pkg)))
loaded_paths <- vapply(setdiff(loadedNamespaces(), "base"), function(p) getNamespaceInfo(asNamespace(p), "path"), "")
allowed <- normalizePath(c(args[1L], args[2L], .Library), winslash = "/")
stopifnot(all(vapply(loaded_paths, function(p) any(startsWith(normalizePath(p, winslash = "/"), paste0(allowed, "/"))), TRUE)))
receipt <- list(status = "passed", package_version = as.character(utils::packageVersion("SampleCausal")),
  package_path = pkg, library_paths = .libPaths(), namespace_paths = as.list(loaded_paths),
  default_stats_attached = FALSE, search_path_unchanged = TRUE, installation_unchanged = TRUE,
  frozen_engine_files = length(manifest$files), final_cases = length(actual),
  historical_records = length(historical), exports_and_replay = TRUE,
  shiny_construction = TRUE, session = utils::capture.output(utils::sessionInfo()))
jsonlite::write_json(receipt, file.path(destination, "installation-receipt.json"), auto_unbox = TRUE, pretty = TRUE)
jsonlite::write_json(actual, file.path(destination, "final-cases.json"), auto_unbox = TRUE, pretty = TRUE, digits = 17)
cat("PASS: installed distribution, 7 cases, 6 historical records, 25 frozen files, exports and Shiny construction.\n")
