#' SampleCausal: documented planning methods and artificial examples
#'
#' The package retains the validated 1.0.1 engine and its historical engines.
#' Current public calculations keep the method restrictions established during
#' computational validation. See [causal_methods()] and the getting-started
#' vignette for scope, inputs and limitations.
#' @keywords internal
#' @import stats
"_PACKAGE"

.sc_state <- new.env(parent = emptyenv())

.sc_engine <- function() {
  if (!is.null(.sc_state$engine)) return(.sc_state$engine)
  root <- system.file("engine", package = "SampleCausal", mustWork = TRUE)
  engine <- new.env(parent = environment(.sc_engine))
  for (key in c("SC_ROOT", "SC_CONTRACT", "SC_MODULES", "SC_PRESENTATION")) {
    engine[[key]] <- NULL
  }
  # Frozen replay code expects attached stats. Resolve that name privately,
  # without attaching a package or modifying the caller's search path.
  engine$as.environment <- function(x) {
    if (identical(x, "package:stats")) asNamespace("stats") else base::as.environment(x)
  }
  for (file in c("engine.R", "replay.R", "server.R")) {
    sys.source(file.path(root, "R", file), envir = engine, keep.source = FALSE)
  }
  engine$sc_init(root)
  .sc_state$engine <- engine
  engine
}

.sc_examples <- function() {
  engine <- .sc_engine()
  tasks <- jsonlite::fromJSON(system.file("extdata", "phase5-inputs.json",
                                         package = "SampleCausal", mustWork = TRUE),
                             simplifyVector = FALSE)
  examples <- engine$sc_config()$examples
  ids <- vapply(examples, function(x) sub(".*(F[0-9]{2}).*", "\\1", x$scenario_name), "")
  names(examples) <- ids
  c(tasks, examples)
}

.sc_scalar_text <- function(x, argument) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop(argument, " must be one non-empty character string.", call. = FALSE)
  }
  x
}
