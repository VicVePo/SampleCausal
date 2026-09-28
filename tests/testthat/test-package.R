read_fixture <- function(name) {
  jsonlite::fromJSON(system.file("extdata", name, package = "SampleCausal", mustWork = TRUE), simplifyVector = FALSE)
}
without_time <- function(x) {
  if (is.list(x)) { x$generated_at <- NULL; x <- lapply(x, without_time) }
  x
}

test_that("seven final cases preserve all validated fields", {
  inputs <- read_fixture("phase5-inputs.json")
  expected <- read_fixture("phase5-results-1.0.1.json")
  actual <- lapply(inputs, causal_calculate)
  expect_equal(without_time(actual), without_time(expected), tolerance = 1e-10)
  independent <- f5_independent(inputs, actual)
  expect_true(independent$all_passed)
  expect_lt(independent$T2$difference, 1e-10)
  expect_true(all(unlist(independent$T4$checks)))
})

test_that("engine resources are byte-identical to the frozen release", {
  skip_if_not_installed("digest")
  root <- system.file("engine", package = "SampleCausal", mustWork = TRUE)
  manifest <- jsonlite::fromJSON(file.path(root, "source-manifest.json"), simplifyVector = FALSE)
  expect_identical(manifest$engine_version, "1.0.1")
  for (item in manifest$files) {
    expect_identical(digest::digest(file = file.path(root, item$path), algo = "sha256"), item$sha256, info = item$path)
  }
})

test_that("public R catalog and controls retain restricted methods", {
  methods <- causal_methods()
  expect_equal(nrow(methods), 6L)
  expect_setequal(methods$module_id, c("M01.weights", "M01.adjusted_variance", "M02.table", "M03.normal", "M06.prediction", "M05.summary"))
  expect_false("ATT" %in% unlist(causal_methods(TRUE)[["M02.table"]]$estimands))
  expect_error(causal_example("unknown"), "Unknown")
  expect_error(causal_methods(NA), "TRUE or FALSE")
  catalog <- causal_examples()
  expect_false(anyDuplicated(catalog$id) > 0)
  expect_true(all(c("T1", "T2", "T3", "T4", "T5", "T6A", "T6B") %in% catalog$id))
  p <- causal_example("T6A");p$research <- TRUE
  expect_identical(causal_calculate(p)$status, "disabled_variant")
  p <- causal_example("T1");p$module_id <- "M07.pilot"
  expect_false(identical(causal_calculate(p)$status, "ok"))
  p <- causal_example("T1");p$assumptions_confirmed <- FALSE
  expect_identical(causal_calculate(p)$status, "invalid_input")
  p <- causal_example("T1");p$provenance <- NULL
  expect_identical(causal_calculate(p)$status, "invalid_input")
})

test_that("exports and sensitivity replay without writing installation files", {
  install_root <- system.file(package = "SampleCausal")
  before <- list.files(install_root, recursive = TRUE, all.files = TRUE)
  dest <- tempfile("causal-test-export-")
  p <- causal_example("T1");result <- causal_calculate(p)
  first <- causal_export(result, dest);second <- causal_export(result, dest)
  expect_false(identical(first$saved_json, second$saved_json))
  expect_true(file.exists(first$saved_text))
  expect_equal(without_time(causal_replay(first$saved_json)), without_time(result), tolerance = 1e-12)
  expect_error(causal_export(causal_calculate(causal_example("T4")), dest), "Only successful")
  sensitivity <- causal_sensitivity(causal_example("T3"), "delta", c(0.03, 0.2, 0.3))
  expect_identical(sensitivity$rows[[1]]$result$status, "unattainable")
  saved <- causal_export(sensitivity, dest)
  expect_equal(without_time(causal_replay(saved$saved_json)), without_time(sensitivity), tolerance = 1e-12)
  expect_equal(list.files(install_root, recursive = TRUE, all.files = TRUE), before)
})

test_that("current and historical replay are distinct", {
  baseline <- read_fixture("phase5-results-1.0.0.json")
  valid <- Filter(function(x) !is.null(x$inputs), baseline)
  for (old in valid) {
    expect_equal(without_time(causal_replay(old)), without_time(old), tolerance = 1e-10)
  }
  actual_old <- read_fixture("historical-0.4.3.json")
  expect_equal(without_time(causal_replay(actual_old)), without_time(actual_old), tolerance = 1e-10)
  x <- causal_calculate(causal_example());x$software_version <- "99.0.0"
  expect_error(causal_replay(x), "Versi")
  x$software_version <- NULL
  expect_error(causal_replay(x), "software_version")
  x$software_version <- "1.0.1";x$research_only <- TRUE
  expect_error(causal_replay(x), "research-only")
})

test_that("all public operations agree with the standalone validated engine", {
  root <- system.file("engine", package = "SampleCausal", mustWork = TRUE)
  reference <- new.env(parent = asNamespace("stats"))
  for (key in c("SC_ROOT", "SC_CONTRACT", "SC_MODULES", "SC_PRESENTATION")) reference[[key]] <- NULL
  sys.source(file.path(root, "R/engine.R"), envir = reference)
  reference$sc_init(root)
  scenarios <- jsonlite::fromJSON(file.path(root, "data/examples.json"), simplifyVector = FALSE)
  seen <- character()
  for (base in scenarios) {
    key <- paste(base$module_id, base$outcome, base$estimand)
    if (key %in% seen || !base$module_id %in% reference$SC_PUBLIC ||
        (base$module_id == "M02.table" && base$estimand == "ATT")) next
    seen <- c(seen, key)
    operations <- unlist(reference$SC_MODULES[[base$module_id]]$functions)
    for (op in operations) {
      p <- base;p$calculation <- op
      if (op %in% c("power", "minimum_detectable_effect")) p$sample_size <- 1000
      if (op == "minimum_detectable_effect") {
        p$delta <- NULL
        if (p$outcome == "binary") p$p1 <- NULL
      }
      if (op == "precision") {
        variance <- reference$sc_variance(p)
        p$confidence <- 0.95;p$half_width <- qnorm(.975)*sqrt(variance$A/300 + variance$B)
        p[c("delta", "target_power", "alpha", "test")] <- NULL
      }
      for (k in reference$sc_required_design(p)) {
        if (is.null(p$provenance[[k]])) p$provenance[[k]] <- list(kind = "explicit_assumption", detail = "Package integration test")
      }
      expected <- reference$sc_calculate(p)
      actual <- causal_calculate(p)
      expect_equal(without_time(actual), without_time(expected), tolerance = 1e-10, info = paste(key, op))
    }
  }
  expect_gte(length(seen), 10L)
})

test_that("Shiny construction uses packaged assets and an external export path", {
  before <- getwd();search_before <- search()
  app <- samplecausal_app(tempfile("samplecausal-shiny-"))
  expect_s3_class(app, "shiny.appobj")
  expect_identical(getwd(), before)
  expect_identical(search(), search_before)
  expect_true(dir.exists(shiny::resourcePaths()[["samplecausal-assets-102"]]))
  expect_false(exists("SC_ROOT", envir = .GlobalEnv, inherits = FALSE))
})
