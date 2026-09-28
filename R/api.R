#' Calculate sample size, power, precision or detectable effect
#'
#' Execute the public planning engine on a named list of documented inputs.
#' Start with [causal_example()] to obtain a complete artificial scenario.
#'
#' @param scenario Named list describing the method, calculation, outcome,
#'   estimand, numerical parameters, assumptions and parameter provenance.
#' @return A named list. Inspect `status` before using any numerical fields.
#'   Successful results include `n_analyzable` or recruitment counts, inputs,
#'   method references, restrictions and a justification. Rejected scenarios
#'   return a status, message and, where available, diagnostic details.
#' @details Required common fields are `module_id`, `calculation`, `outcome`,
#'   `estimand`, `scenario_name`, `assumptions_confirmed = TRUE`, and
#'   `provenance`. Except for M05, also provide `effect_units`.
#'   Provenance is a named list indexed by parameter, each element containing
#'   `kind` (pilot, publication, explicit_assumption or sensitivity_scenario)
#'   and a nonempty `detail`. Use [causal_methods()] with `details = TRUE`
#'   for method-specific input definitions. Examples are fictional templates;
#'   replacing numerical assumptions also requires updating their provenance.
#'
#'   Public methods do not accept a research-mode override. M02 ATT remains
#'   withdrawn; experimental methods stay disabled. M06 uses the explicitly
#'   documented local E1 variance amendment and requires at least 100 residual
#'   degrees of freedom in each group. Power and precision are normal
#'   approximations, not universal operating guarantees. Statistical validation
#'   applies only to the scenarios and assumptions reported in the study.
#' @examples
#' scenario <- causal_example("T1")
#' result <- causal_calculate(scenario)
#' result$status
#' result$n_analyzable
#' result$power_recalculated
#' causal_calculate(causal_example("T4"))$status
#' @export
causal_calculate <- function(scenario) {
  .sc_engine()$sc_calculate(scenario, research = FALSE, require_metadata = TRUE)
}

#' List the public planning methods and their restrictions
#' @param details Logical; return complete method definitions instead of a table.
#' @return A data frame, or a named list with parameter definitions, references
#'   and restrictions when `details = TRUE`.
#' @examples
#' causal_methods()
#' causal_methods(details = TRUE)[["M06.prediction"]]$limitations
#' @export
causal_methods <- function(details = FALSE) {
  if (!is.logical(details) || length(details) != 1L || is.na(details)) {
    stop("details must be TRUE or FALSE.", call. = FALSE)
  }
  methods <- .sc_engine()$sc_config()$modules
  names(methods) <- vapply(methods, function(x) x$id, "")
  if (details) return(methods)
  do.call(rbind, lapply(methods, function(x) {
    data.frame(module_id = x$id, method = x$name,
               outcomes = paste(unlist(x$outcomes), collapse = ", "),
               estimands = paste(unlist(x$estimands), collapse = ", "),
               calculations = paste(unlist(x$functions), collapse = ", "),
               n_meaning = x$n_means, row.names = NULL, stringsAsFactors = FALSE)
  }))
}

#' Inspect the catalog of artificial scenarios
#' @return A data frame containing identifiers, method, outcome, estimand and
#'   scenario name. T1--T6B are the seven final technical cases; T4 and T6A
#'   intentionally demonstrate rejected requests. F identifiers preserve
#'   the original reference examples; some can be outside current restrictions.
#' @examples
#' causal_examples()
#' @export
causal_examples <- function() {
  examples <- .sc_examples()
  do.call(rbind, lapply(names(examples), function(id) {
    x <- examples[[id]]
    data.frame(id = id, module_id = x$module_id, outcome = x$outcome,
               estimand = x$estimand, scenario_name = x$scenario_name,
               stringsAsFactors = FALSE)
  }))
}

#' Get a complete artificial scenario
#' @param id Identifier shown by [causal_examples()], such as `"T1"`, `"T3"`
#'   or `"F01"`.
#' @return A named input list. All examples are fictional; their assumed
#'   provenance and confirmation apply only to that illustrative scenario.
#' @examples
#' scenario <- causal_example("T3")
#' causal_calculate(scenario)$n_analyzable
#' @export
causal_example <- function(id = "T1") {
  .sc_scalar_text(id, "id")
  examples <- .sc_examples()
  if (!id %in% names(examples)) stop("Unknown example; see causal_examples().", call. = FALSE)
  examples[[id]]
}

#' Compare up to five explicit parameter assumptions
#' @param scenario Complete input list, as for [causal_calculate()].
#' @param parameter Numerical parameter name present in the scenario.
#' @param values Numeric vector or list of one to five alternative values.
#' @return A named list with one result per value. Rejected rows are retained.
#' @details No minimum sample size is automatically selected. For binary
#'   outcomes, if varying p0 or p1, remove a redundant fixed `delta` from the
#'   scenario so it remains the difference of the two risks. The engine rejects
#'   inconsistent risks and effects instead of silently changing them.
#' @examples
#' causal_sensitivity(causal_example("T3"), "delta", c(0.03, 0.2, 0.3))
#' @export
causal_sensitivity <- function(scenario, parameter, values) {
  .sc_engine()$sc_sensitivity(scenario, parameter, values)
}

#' Recalculate a current or historical JSON record
#' @param record A result list or path to a JSON result file. The record must
#'   contain an explicit `software_version` and reproducible inputs.
#' @return A recalculated result list. Generation time may differ.
#' @details Versions 0.4.0--0.4.3 and 1.0.0 use their archived engines.
#'   Unsupported versions produce an error. Historical replay preserves old
#'   formulae and text and does not endorse a withdrawn recommendation.
#'   Current-version research-only records cannot enable withdrawn procedures
#'   through this public replay function.
#'   Rejected results without embedded inputs cannot be replayed independently;
#'   recalculate their saved original scenario with [causal_calculate()].
#' @examples
#' result <- causal_calculate(causal_example("T1"))
#' causal_replay(result)$n_analyzable
#' @export
causal_replay <- function(record) {
  if (is.character(record)) {
    .sc_scalar_text(record, "record")
    record <- jsonlite::fromJSON(record, simplifyVector = FALSE)
  }
  if (!is.list(record) || is.null(record$software_version)) {
    stop("A result with an explicit software_version is required.", call. = FALSE)
  }
  if (identical(record$software_version, "1.0.1") && isTRUE(record$research_only)) {
    stop("Current research-only records are not enabled by the public interface.", call. = FALSE)
  }
  .sc_engine()$sc_replay(record)
}

#' Export a successful result to uniquely named files
#' @param result A successful result from [causal_calculate()] or
#'   [causal_sensitivity()].
#' @param directory Destination directory. It is created if necessary.
#' @return A named list containing the created JSON path and, for a single
#'   scenario, the text justification path. Existing files are not overwritten.
#' @details Results are written only to the supplied directory, never to the
#'   package installation. A sensitivity export retains unsuccessful rows.
#' @examples
#' result <- causal_calculate(causal_example("T1"))
#' files <- causal_export(result, tempfile("samplecausal-example-"))
#' causal_replay(files$saved_json)$n_analyzable
#' @export
causal_export <- function(result, directory = file.path(getwd(), "SampleCausal-exports")) {
  .sc_scalar_text(directory, "directory")
  if (!is.list(result) || !identical(result$status, "ok")) {
    stop("Only successful results or sensitivity collections can be exported.", call. = FALSE)
  }
  .sc_engine()$sc_save_result(result, directory)
}
