source(testthat::test_path("..", "..", "R", "app_runtime.R"), encoding = "UTF-8")

public_bundle <- testthat::test_path(
  "..", "..", "data", "app", "insee_2026-11-17_grid500_privacy_v6_simplified"
)

test_that("simplified aggregate runtime loads with validated totals", {
  app <- load_public_app_data(public_bundle)
  expect_named(app, c("stock", "spatial", "history"))
  expect_equal(sum(app$stock$section_stock$active_count), 14213L)
  expect_equal(sum(app$stock$section_stock$address_exact_oo_count), 5214L)
  expect_equal(sum(app$stock$section_stock$spatial_released_count), 4272L)
  expect_equal(nrow(app$stock$section_stock), 18L)
  expect_true(validate_public_runtime_data(app$stock, app$spatial, app$history)$valid)
})

test_that("creation cohorts are municipality-wide and reconcile", {
  cohorts <- load_public_app_data(public_bundle)$stock$creation_cohorts
  expect_named(cohorts, c("cohort", "count"))
  expect_identical(cohorts$cohort, c(
    "Unknown / undetermined", "Before 2000", "2000–2009", "2010–2014",
    "2015–2019", "2020–2024", "2025–2026"
  ))
  expect_identical(cohorts$count, c(42L, 999L, 1406L, 1473L, 2199L, 4677L, 3417L))
  expect_equal(sum(cohorts$count), 14213L)
  expect_false(any(grepl("section|grid|geocod|legal|person", names(cohorts), ignore.case = TRUE)))
})

test_that("P0 historical and creation-year tables are absent", {
  app <- load_public_app_data(public_bundle)
  expect_false("history_sections" %in% names(app))
  expect_false("creation_year_section" %in% names(app$stock))
  expect_false(file.exists(file.path(public_bundle, "history_section_3year.rds")))
  expect_false(any(grepl("creation_year|section_code", names(app$stock$creation_cohorts))))
})

test_that("spatial runtime remains unchanged and threshold protected", {
  spatial <- load_public_app_data(public_bundle)$spatial
  expect_equal(nrow(spatial), 286L)
  expect_equal(length(unique(spatial$grid_id)), 51L)
  expect_equal(sum(spatial$count), 4272L)
  expect_true(all(spatial$count >= 5L))
  expect_named(spatial, required_spatial_aggregate_fields)
  expect_false(any(grepl(
    "siret|siren|name|address|query|naf_code|creation_year|person|legal",
    names(spatial), ignore.case = TRUE
  )))
})

test_that("public RDS values contain no register identifiers or establishment rows", {
  app <- load_public_app_data(public_bundle)
  expect_false("establishments" %in% names(app))
  field_names <- tolower(unlist(lapply(app, function(x) {
    if (is.data.frame(x)) names(x) else if (is.list(x)) unlist(lapply(x, names)) else names(x)
  }), use.names = FALSE))
  forbidden <- c(
    "siret", "siren", "address", "street", "house_number", "legal_name",
    "trade_name", "usual_name", "source_longitude", "source_latitude"
  )
  expect_false(any(field_names %in% forbidden))
  character_values <- unlist(lapply(app, function(x) {
    unlist(lapply(if (is.list(x)) x else list(x), function(part) {
      if (is.data.frame(part)) unlist(part[vapply(part, is.character, logical(1))], use.names = FALSE)
      else if (is.character(part)) part else character()
    }), use.names = FALSE)
  }), use.names = FALSE)
  expect_false(any(grepl("^[0-9]{9}$|^[0-9]{14}$", character_values)))
  expect_false(file.exists(file.path(public_bundle, "establishments.rds")))
})

test_that("annual history remains unchanged and 2026 is partial", {
  history <- load_public_app_data(public_bundle)$history
  expect_equal(nrow(history), 54L)
  expect_identical(as.integer(history$year), 1973:2026)
  expect_equal(history$year[history$coverage_status == "partial_year_current_snapshot"], 2026L)
  expect_equal(history$creations[history$year == 2025L], 2084L)
  expect_equal(history$closures[history$year == 2025L], 1590L)
})

test_that("map aggregates and section filters remain protected", {
  app <- load_public_app_data(public_bundle)
  all_cells <- filter_spatial_aggregates(app$spatial, "ALL")
  expect_equal(nrow(all_cells), 51L)
  expect_equal(sum(all_cells$count), 4272L)
  expect_true(all(all_cells$count >= 5L))
  sections <- app$stock$section_stock$section_code
  filtered <- lapply(sections, function(code) filter_spatial_aggregates(app$spatial, code))
  expect_true(all(vapply(filtered, function(x) all(x$count >= 5L), logical(1))))
  expect_setequal(sections[vapply(filtered, nrow, integer(1)) == 0L], c("A", "D", "E", "O"))
  expect_equal(sum(vapply(filtered, function(x) sum(x$count), integer(1))), 4272L)
})

test_that("aggregate popups disclose approved fields only", {
  app <- load_public_app_data(public_bundle)
  labels <- stats::setNames(app$stock$section_stock$section_label,
                            app$stock$section_stock$section_code)
  popup <- build_aggregate_popup(app$spatial[1:2, ], labels)
  expect_length(popup, 2L)
  expect_match(popup[[1]], "500 m aggregation grid", fixed = TRUE)
  expect_match(popup[[1]], "Published establishments:", fixed = TRUE)
  expect_match(popup[[1]], "not an establishment location", fixed = TRUE)
  expect_false(any(grepl(
    "SIRET|SIREN|address|name|creation year|NAF code", popup, ignore.case = TRUE
  )))
})

test_that("circle area and Sankey totals remain unchanged", {
  count <- c(5L, 20L, 80L)
  radius <- aggregate_circle_radius(count)
  expect_equal(radius^2 / count, rep(4, length(count)))
  expect_error(aggregate_circle_radius(4L), "at least five", fixed = TRUE)
  flow <- public_geocoding_flow_counts(load_public_app_data(public_bundle)$stock)
  expect_equal(flow, c(
    address_exact_oo = 5214L, spatial_released = 4272L,
    threshold_excluded = 942L, less_precise = 5925L,
    unmatched = 719L, restricted = 2355L
  ))
  expect_equal(sum(flow[c("address_exact_oo", "less_precise", "unmatched", "restricted")]), 14213L)
})

test_that("public app constructs without internal files", {
  old <- setwd(testthat::test_path("..", "..")); on.exit(setwd(old), add = TRUE)
  app_env <- new.env(parent = globalenv())
  sys.source("global.R", envir = app_env)
  sys.source("ui.R", envir = app_env)
  sys.source("server.R", envir = app_env)
  expect_equal(app_env$active_total, 14213L)
  expect_equal(app_env$address_exact_oo_total, 5214L)
  expect_equal(app_env$spatial_released_total, 4272L)
  expect_equal(length(app_env$section_choices), 19L)
  expect_s3_class(app_env$ui, "shiny.tag.list")
  expect_true(is.function(app_env$server))
})

test_that("UI contains cohorts but no historical sector controls", {
  project <- testthat::test_path("..", "..")
  source_text <- paste(vapply(
    file.path(project, c("global.R", "ui.R", "server.R", "R/app_runtime.R")),
    function(path) paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n"),
    character(1)
  ), collapse = "\n")
  expect_match(source_text, "Active establishments by creation period", fixed = TRUE)
  expect_match(source_text, "Creation periods of establishments active on 17 November 2026.", fixed = TRUE)
  expect_false(grepl("select_history_section|select_history_interval|creation_year_section", source_text))
  expect_false(grepl("downloadHandler|downloadButton|downloadLink", source_text))
})
