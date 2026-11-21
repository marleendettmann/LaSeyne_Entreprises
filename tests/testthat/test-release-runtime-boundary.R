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

test_that("runtime reload and event-control styles are deployed", {
  project <- testthat::test_path("..", "..")
  global_source <- paste(readLines(file.path(project, "global.R")), collapse = "\n")
  server_source <- paste(readLines(file.path(project, "server.R")), collapse = "\n")
  styles <- paste(readLines(file.path(project, "www/styles.css")), collapse = "\n")
  expect_match(global_source, "required_runtime_functions", fixed = TRUE)
  expect_match(global_source, "source(\"R/app_runtime.R\", local = TRUE", fixed = TRUE)
  expect_match(server_source, "inline = TRUE", fixed = TRUE)
  expect_match(styles, ".history-event-selector", fixed = TRUE)
  expect_match(styles, "background: #27313A", fixed = TRUE)
  expect_match(styles, ".source-footer", fixed = TRUE)
})

test_that("UI terminology matches the simplified data model", {
  project <- testthat::test_path("..", "..")
  ui_source <- paste(readLines(file.path(project, "ui.R"), encoding = "UTF-8"), collapse = "\n")
  server_source <- paste(readLines(file.path(project, "server.R"), encoding = "UTF-8"), collapse = "\n")
  expect_match(ui_source, "Establishments by economic activity", fixed = TRUE)
  expect_match(ui_source, "Active establishments by creation year and economic section", fixed = TRUE)
  expect_false(grepl("Companies by business activities", ui_source, fixed = TRUE))
  expect_false(grepl("select_history_section|select_history_interval", paste(ui_source, server_source)))
  expect_match(ui_source, "eight largest sections by current stock", fixed = TRUE)
  expect_match(ui_source, '"Methodology and Data"', fixed = TRUE)
  expect_match(ui_source, 'icon("table")', fixed = TRUE)
  expect_match(ui_source, 'icon("bullseye")', fixed = TRUE)
  expect_match(
    ui_source,
    "Annual administrative register events reconstructed from the current SIRENE snapshot.",
    fixed = TRUE
  )
  expect_match(
    ui_source,
    "uses official INSEE SIRENE data to explore business establishments",
    fixed = TRUE
  )
  expect_match(ui_source, "https://www.r-project.org/", fixed = TRUE)
  expect_match(ui_source, "https://shiny.posit.co/", fixed = TRUE)
  expect_match(ui_source, "https://appsilon.github.io/semantic.dashboard/", fixed = TRUE)
  expect_match(ui_source, "https://rstudio.github.io/leaflet/", fixed = TRUE)
  expect_match(ui_source, "https://plotly.com/r/", fixed = TRUE)
  expect_match(
    server_source,
    "represented on the map",
    fixed = TRUE
  )
  expect_match(
    ui_source,
    "Only grid cell\\u2013sector combinations with at least five establishments are shown.",
    fixed = TRUE
  )
})

test_that("public schema validators reject cross-schema substitutions", {
  project <- testthat::test_path("..", "..")
  source(file.path(project, "R/app_runtime.R"), local = TRUE)
  bundle <- file.path(project, "data/app/insee_2026-11-17_grid500_privacy_v6_simplified")
  app <- load_public_app_data(bundle)
  expect_true(validate_public_stock_aggregates(app$stock)$valid)
  expect_true(validate_public_spatial_aggregates(app$spatial, app$stock$section_stock)$valid)
  expect_true(validate_public_history_yearly(app$history)$valid)
  expect_true(validate_public_creation_year_top8(
    app$creation_year_top8, app$stock$section_stock
  )$valid)
  expect_false(validate_public_stock_aggregates(app$spatial)$valid)
  expect_false(validate_public_history_yearly(app$stock$creation_cohorts)$valid)
  expect_false(validate_public_spatial_aggregates(app$history, app$stock$section_stock)$valid)
  expect_false(validate_public_creation_year_top8(
    app$history, app$stock$section_stock
  )$valid)
})
