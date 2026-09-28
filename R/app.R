#' Create the local Shiny application
#' @param export_dir Directory for exports. Defaults to a session temporary
#'   directory; supply a persistent directory if those server copies are needed.
#' @return A Shiny application object. No server is started by this function.
#' @details Browser downloads and the save button use `export_dir`. Installation
#'   files remain read-only. Download any wanted files or choose a persistent
#'   directory before the R session ends. This is a computational tool using
#'   explicit assumptions; the accompanying evaluation does not involve users.
#'   The destination directory is created when this function is called and its
#'   absolute path is retained, so changing the working directory before starting
#'   the application does not redirect its exports. An invalid destination
#'   produces an error before the application is created.
#' @examples
#' app <- samplecausal_app(export_dir = tempfile("samplecausal-app-"))
#' inherits(app, "shiny.appobj")
#' @export
samplecausal_app <- function(export_dir = file.path(tempdir(), "SampleCausal-exports")) {
  .sc_scalar_text(export_dir, "export_dir")
  if (!dir.exists(export_dir) &&
      !dir.create(export_dir, recursive = TRUE, showWarnings = FALSE)) {
    stop("export_dir could not be created as a directory.", call. = FALSE)
  }
  export_dir <- normalizePath(export_dir, winslash = "/", mustWork = TRUE)
  engine <- .sc_engine()
  assets <- system.file("appwww", package = "SampleCausal", mustWork = TRUE)
  prefix <- "samplecausal-assets-102"
  shiny::addResourcePath(prefix, assets)
  template <- paste(readLines(file.path(assets, "index.html"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  template <- sub('href="style.css"', paste0('href="', prefix, '/style.css"'), template, fixed = TRUE)
  template <- sub('src="app.js"', paste0('src="', prefix, '/app.js"'), template, fixed = TRUE)
  # Package users must see where the server copy is stored rather than a
  # misleading reference to a writable source-project folder.
  template <- sub("</footer>", paste0("<br>Las copias de servidor se guardan en la carpeta de exportaci\u00f3n de esta sesi\u00f3n.</footer>"), template, fixed = TRUE)
  ui <- shiny::htmlTemplate(text_ = template,
    downloads = shiny::tags$div(style = "display:none",
      shiny::downloadLink("download_json", "JSON"),
      shiny::downloadLink("download_text", "Texto"),
      shiny::downloadLink("download_sensitivity", "Sensibilidad")))
  shiny::shinyApp(ui = ui, server = engine$sc_make_server(export_dir = export_dir))
}

#' Open the SampleCausal calculator
#' @param export_dir Destination for server export copies; see [samplecausal_app()].
#' @param launch.browser Whether to open the system browser. TRUE in interactive
#'   R sessions by default.
#' @param port Optional local port; NULL lets Shiny select an available port.
#' @param host Host address; defaults to the loopback address for local use.
#' @return The value returned by [shiny::runApp()] when the application stops.
#' @examples
#' if (interactive()) run_samplecausal()
#' @export
run_samplecausal <- function(export_dir = file.path(tempdir(), "SampleCausal-exports"),
                            launch.browser = interactive(), port = NULL,
                            host = "127.0.0.1") {
  shiny::runApp(samplecausal_app(export_dir), launch.browser = launch.browser,
                port = port, host = host)
}
