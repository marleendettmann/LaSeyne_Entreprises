source(testthat::test_path("..", "..", "R", "app_runtime.R"), encoding = "UTF-8")

public_bundle <- testthat::test_path(
  "..", "..", "data", "app", "insee_2026-11-17_grid500_privacy_v6_simplified"
)

test_that("simplified aggregate runtime loads with validated totals", {
  app <- load_public_app_data(public_bundle)
  expect_named(app, c("stock", "spatial", "history", "creation_year_top8"))
  expect_equal(sum(app$stock$section_stock$active_count), 14213L)
  expect_equal(sum(app$stock$section_stock$address_exact_oo_count), 5214L)
  expect_equal(sum(app$stock$section_stock$spatial_released_count), 4272L)
  expect_equal(nrow(app$stock$section_stock), 18L)
  expect_true(validate_public_runtime_data(
    app$stock, app$spatial, app$history, app$creation_year_top8
  )$valid)
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

test_that("P0 tables remain absent and only the approved Top-8 table is public", {
  app <- load_public_app_data(public_bundle)
  expect_false("history_sections" %in% names(app))
  expect_false("creation_year_section" %in% names(app$stock))
  expect_false(file.exists(file.path(public_bundle, "history_section_3year.rds")))
  expect_false(any(grepl("creation_year|section_code", names(app$stock$creation_cohorts))))
  top8 <- app$creation_year_top8
  expect_named(top8, required_creation_year_top8_fields)
  expect_equal(nrow(top8), 96L)
  expect_identical(sort(unique(top8$creation_year)), 2015:2026)
  expect_identical(unique(top8$section_code), c("L", "G", "S", "F", "Q", "M", "N", "R"))
  expect_equal(min(top8$count), 13L)
  expect_false(anyNA(top8))
  expect_true(validate_public_creation_year_top8(top8, app$stock$section_stock)$valid)
})

test_that("Top-8 ranking and year-specific plot payload are deterministic", {
  app <- load_public_app_data(public_bundle)
  ranked <- app$stock$section_stock[
    order(-app$stock$section_stock$active_count,
          app$stock$section_stock$section_code),
  ]
  expect_identical(head(ranked$section_code, 8L), c("L", "G", "S", "F", "Q", "M", "N", "R"))
  expect_equal(sum(head(ranked$active_count, 8L)), 11247L)
  for (year in 2015:2026) {
    selected <- creation_year_plot_data(app$creation_year_top8, year)
    expect_equal(nrow(selected), 8L)
    expect_true(all(diff(selected$count) >= 0L))
    expect_true(all(selected$creation_year == year))
    expect_true(all(selected$count >= 13L))
  }
})

test_that("Top-8 release creates no small reconstructable margin", {
  app <- load_public_app_data(public_bundle)
  top8 <- app$creation_year_top8
  window_by_section <- stats::aggregate(count ~ section_code, top8, sum)
  section_margins <- merge(
    app$stock$section_stock[c("section_code", "active_count")],
    window_by_section, by = "section_code"
  )
  section_margins$residual <- section_margins$active_count - section_margins$count
  expect_gte(min(section_margins$residual), 232L)

  period <- ifelse(
    top8$creation_year <= 2019L, "2015\u20132019",
    ifelse(top8$creation_year <= 2024L, "2020\u20132024", "2025\u20132026")
  )
  released_period <- stats::aggregate(top8$count, list(period = period), sum)
  names(released_period)[[2L]] <- "released"
  cohort <- app$stock$creation_cohorts
  cohort <- cohort[cohort$cohort %in% released_period$period, ]
  joined <- merge(cohort, released_period, by.x = "cohort", by.y = "period")
  expect_identical(joined$count - joined$released, c(394L, 1046L, 892L))
  expect_false(any(c("grid_id", "longitude", "latitude") %in% names(top8)))
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

test_that("missing reopening observations remain gaps rather than zeroes", {
  history <- load_public_app_data(public_bundle)$history
  expect_true(all(is.na(history$reopenings[history$year %in% 1986:1989])))
  expect_identical(history$reopenings[history$year == 1985L], 1L)
  expect_identical(history$reopenings[history$year == 1990L], 2L)

  series <- history_event_plot_series(history, "Reopenings", 1985L)
  expect_false(anyNA(series$value))
  expect_false(any(series$year %in% 1986:1989))
  expect_false(identical(
    series$observed_run[series$year == 1985L],
    series$observed_run[series$year == 1990L]
  ))
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
  expect_equal(nrow(app_env$creation_year_top8), 96L)
  expect_equal(length(app_env$section_choices), 19L)
  expect_s3_class(app_env$ui, "shiny.tag.list")
  expect_true(is.function(app_env$server))
})

test_that("global startup replaces an incomplete stale runtime", {
  old <- setwd(testthat::test_path("..", "..")); on.exit(setwd(old), add = TRUE)
  stale_env <- new.env(parent = globalenv())
  stale_env$load_public_app_data <- function(...) {
    stop("stale runtime loader should have been replaced", call. = FALSE)
  }
  expect_false(exists(
    "creation_year_plot_data", envir = stale_env, inherits = FALSE
  ))
  sys.source("global.R", envir = stale_env)
  expect_true(exists(
    "history_event_plot_series", envir = stale_env, inherits = FALSE
  ))
  expect_true(exists(
    "creation_year_plot_data", envir = stale_env, inherits = FALSE
  ))
  expect_equal(nrow(stale_env$creation_year_top8), 96L)
})

test_that("Figure 3 sends only the selected year's eight values", {
  old <- setwd(testthat::test_path("..", "..")); on.exit(setwd(old), add = TRUE)
  app_env <- new.env(parent = globalenv())
  sys.source("global.R", envir = app_env)
  sys.source("server.R", envir = app_env)
  shiny::testServer(app_env$server, {
    session$setInputs(select_creation_year = 2026L)
    session$flushReact()
    payload <- as.character(output$plot3)
    expect_match(payload, "2026", fixed = TRUE)
    expect_false(grepl("2015", payload, fixed = TRUE))
    expect_false(grepl("SIRET|SIREN|address|grid_id", payload, ignore.case = TRUE))
  })
})

test_that("Figure 2 is a single responsive radio selection", {
  old <- setwd(testthat::test_path("..", "..")); on.exit(setwd(old), add = TRUE)
  app_env <- new.env(parent = globalenv())
  sys.source("global.R", envir = app_env)
  sys.source("server.R", envir = app_env)
  shiny::testServer(app_env$server, {
    control <- paste(as.character(output$history_event_control), collapse = "\n")
    expect_match(control, "history-event-selector", fixed = TRUE)
    expect_match(control, "radio-inline", fixed = TRUE)
    expect_match(control, "Administrative creations", fixed = TRUE)
    expect_match(control, "Administrative closures", fixed = TRUE)
    expect_match(control, "Reopenings", fixed = TRUE)
    expect_false(grepl("checkbox", control, ignore.case = TRUE))
    for (event in c(
      "Administrative creations", "Administrative closures", "Reopenings"
    )) {
      session$setInputs(select_RegClos = event)
      session$flushReact()
      expect_s3_class(output$plot1, "json")
    }
  })
})

test_that("Figure 1 keeps event values and uses the matching visual series", {
  old <- setwd(testthat::test_path("..", "..")); on.exit(setwd(old), add = TRUE)
  app_env <- new.env(parent = globalenv())
  sys.source("global.R", envir = app_env)
  sys.source("server.R", envir = app_env)
  shiny::testServer(app_env$server, {
    for (event in c(
      "Administrative creations", "Administrative closures", "Reopenings"
    )) {
      session$setInputs(select_RegClos = event)
      session$flushReact()
      payload <- as.character(output$plot1)
      expect_match(payload, event, fixed = TRUE)
    }
  })
  expect_identical(
    app_env$history_yearly$creations[app_env$history_yearly$year == 2025L],
    2084L
  )
  expect_identical(
    app_env$history_yearly$closures[app_env$history_yearly$year == 2025L],
    1590L
  )
})

test_that("UI contains the approved Top-8 chart but no historical sector controls", {
  project <- testthat::test_path("..", "..")
  source_text <- paste(vapply(
    file.path(project, c("global.R", "ui.R", "server.R", "R/app_runtime.R")),
    function(path) paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n"),
    character(1)
  ), collapse = "\n")
  expect_match(source_text, "Active establishments by creation year and economic section", fixed = TRUE)
  expect_match(source_text, "eight largest sections by current stock", fixed = TRUE)
  expect_match(source_text, "select_creation_year", fixed = TRUE)
  expect_match(source_text, "2026 is incomplete", fixed = TRUE)
  expect_false(grepl("select_history_section|select_history_interval|creation_year_section", source_text))
  expect_false(grepl("downloadHandler|downloadButton|downloadLink", source_text))
})

test_that("source footer is present on every public page", {
  old <- setwd(testthat::test_path("..", "..")); on.exit(setwd(old), add = TRUE)
  app_env <- new.env(parent = globalenv())
  sys.source("global.R", envir = app_env)
  sys.source("ui.R", envir = app_env)
  html <- htmltools::renderTags(app_env$ui)$html
  footer_hits <- gregexpr('class="source-footer"', html, fixed = TRUE)[[1L]]
  expect_equal(sum(footer_hits > 0L), 3L)
  expect_match(html, "Insee, API Sirene 3.11 (SIRENE)", fixed = TRUE)
  expect_match(html, "IGN ADMIN EXPRESS COG and BD TOPO", fixed = TRUE)
  expect_match(html, "Licence Ouverte 2.0 (Etalab)", fixed = TRUE)
})

test_that("geographic explainer uses only the orange accent", {
  project <- testthat::test_path("..", "..")
  styles <- paste(
    readLines(file.path(project, "www/styles.css"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(styles, ".synthetic-points .point", fixed = TRUE)
  expect_match(styles, "background: #e08800", fixed = TRUE)
  expect_match(styles, "background: rgba(224, 136, 0, 0.24)", fixed = TRUE)
  expect_match(styles, "background: rgba(224, 136, 0, 0.34)", fixed = TRUE)
})
