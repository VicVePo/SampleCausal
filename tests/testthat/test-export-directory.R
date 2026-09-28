test_that("relative exports stay anchored after the working directory changes", {
  original <- getwd()
  on.exit(setwd(original), add = TRUE)
  root <- tempfile("samplecausal-directory-")
  first <- file.path(root, "construction")
  second <- file.path(root, "execution")
  dir.create(first, recursive = TRUE)
  dir.create(second)
  setwd(first)
  app <- samplecausal_app("nested/export folder")
  expected <- file.path(first, "nested", "export folder")
  expect_true(dir.exists(expected))
  setwd(second)
  shiny::testServer(app, {
    session$setInputs(sc_request = list(id = "relative-destination-test",
      route = "/api/save", payload = causal_example("T1")))
    session$flushReact()
  })
  json <- list.files(expected, pattern = "[.]json$", full.names = TRUE)
  text <- list.files(expected, pattern = "[.]txt$", full.names = TRUE)
  expect_length(json, 1L)
  expect_length(text, 1L)
  expect_false(dir.exists(file.path(second, "nested")))
  expect_equal(causal_replay(json)$n_analyzable, 1035)
})

test_that("existing files cannot be selected as an export directory", {
  destination <- tempfile("samplecausal-file-")
  writeLines("Existing file: must remain intact.", destination)
  expect_error(samplecausal_app(destination), "could not be created as a directory")
  expect_identical(readLines(destination), "Existing file: must remain intact.")
})

test_that("an existing absolute export directory is retained", {
  destination <- tempfile("samplecausal-existing-")
  dir.create(destination)
  app <- samplecausal_app(destination)
  server <- app$serverFuncSource()
  expect_identical(get("export_dir", envir = environment(server)),
                   normalizePath(destination, winslash = "/", mustWork = TRUE))
})
