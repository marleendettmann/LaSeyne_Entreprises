test_that("Shiny autoload contains public runtime code only", {
  project <- testthat::test_path("..", "..")
  runtime_files <- sort(list.files(file.path(project, "R"), pattern = "[.]R$"))
  expect_identical(runtime_files, "app_runtime.R")

  definitions <- unlist(lapply(file.path(project, "R", runtime_files), function(path) {
    lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
    sub("\\s*<-.*", "", grep(
      "^[A-Za-z][A-Za-z0-9_.]*\\s*<-\\s*function", lines, value = TRUE
    ))
  }), use.names = FALSE)
  expect_false(anyDuplicated(definitions) > 0L)
  expect_false(any(grepl("internal|marker|geocod|pipeline", runtime_files, ignore.case = TRUE)))
})

test_that("release allowlists are explicit, complete and runtime-safe", {
  project <- testthat::test_path("..", "..")
  repository <- readLines(file.path(project, "release/public-repository-files.txt"))
  deployment <- readLines(file.path(project, "release/shinyapps-files.txt"))
  expect_false(anyDuplicated(repository) > 0L)
  expect_false(anyDuplicated(deployment) > 0L)
  expect_true(all(file.exists(file.path(project, repository))))
  expect_true(all(file.exists(file.path(project, deployment))))
  expect_setequal(
    deployment[grepl("^R/", deployment)],
    "R/app_runtime.R"
  )
  expect_false(any(grepl("app_data|internal|legacy|data/(raw|processed|reference)", deployment)))
})

test_that("deployed R sources are locale-portable ASCII", {
  project <- testthat::test_path("..", "..")
  deployment <- readLines(file.path(project, "release/shinyapps-files.txt"))
  r_sources <- deployment[grepl("[.]R$", deployment)]
  bytes <- lapply(file.path(project, r_sources), function(path) {
    readBin(path, what = "raw", n = file.info(path)$size)
  })
  expect_true(all(vapply(bytes, function(value) all(as.integer(value) <= 127L), logical(1))))
})

test_that("UI terminology matches the simplified data model", {
  project <- testthat::test_path("..", "..")
  ui_source <- paste(readLines(file.path(project, "ui.R"), encoding = "UTF-8"), collapse = "\n")
  server_source <- paste(readLines(file.path(project, "server.R"), encoding = "UTF-8"), collapse = "\n")
  expect_match(ui_source, "Establishments by economic activity", fixed = TRUE)
  expect_match(ui_source, "Active establishments by creation period", fixed = TRUE)
  expect_false(grepl("Companies by business activities", ui_source, fixed = TRUE))
  expect_false(grepl("select_history_section|select_history_interval", paste(ui_source, server_source)))
  expect_match(ui_source, "Creation periods of establishments active on 17 November 2026.", fixed = TRUE)
})

test_that("public schema validators reject cross-schema substitutions", {
  project <- testthat::test_path("..", "..")
  source(file.path(project, "R/app_runtime.R"), local = TRUE)
  bundle <- file.path(project, "data/app/insee_2026-11-17_grid500_privacy_v6_simplified")
  app <- load_public_app_data(bundle)
  expect_true(validate_public_stock_aggregates(app$stock)$valid)
  expect_true(validate_public_spatial_aggregates(app$spatial, app$stock$section_stock)$valid)
  expect_true(validate_public_history_yearly(app$history)$valid)
  expect_false(validate_public_stock_aggregates(app$spatial)$valid)
  expect_false(validate_public_history_yearly(app$stock$creation_cohorts)$valid)
  expect_false(validate_public_spatial_aggregates(app$history, app$stock$section_stock)$valid)
})
