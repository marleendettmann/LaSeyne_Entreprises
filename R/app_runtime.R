required_section_stock_fields <- c(
  "section_code", "section_label", "active_count", "address_exact_oo_count",
  "spatial_released_count"
)
required_creation_cohort_fields <- c("cohort", "count")
required_geocoding_flow_fields <- c("category", "count")
required_spatial_aggregate_fields <- c(
  "grid_id", "section_code", "count", "anchor_longitude", "anchor_latitude"
)
required_app_history_fields <- c(
  "year", "creations", "closures", "reopenings", "other_period_changes",
  "coverage_complete", "coverage_status"
)

runtime_validation <- function(errors = character()) {
  list(valid = !length(errors), errors = errors)
}

validate_public_stock_aggregates <- function(stock) {
  errors <- character()
  required_objects <- c(
    "reference_date", "section_stock", "creation_cohorts", "geocoding_flow"
  )
  if (!is.list(stock) || !identical(names(stock), required_objects)) {
    return(runtime_validation("The public stock aggregate has an invalid object schema."))
  }
  section_stock <- stock$section_stock
  cohorts <- stock$creation_cohorts
  flow <- stock$geocoding_flow
  if (!identical(names(section_stock), required_section_stock_fields)) {
    errors <- c(errors, "The section-stock schema is not permitted.")
  }
  if (!identical(names(cohorts), required_creation_cohort_fields)) {
    errors <- c(errors, "The creation-cohort schema is not permitted.")
  }
  if (!identical(names(flow), required_geocoding_flow_fields)) {
    errors <- c(errors, "The geocoding-flow schema is not permitted.")
  }
  if (nrow(section_stock) != 18L || sum(section_stock$active_count) != 14213L) {
    errors <- c(errors, "The aggregate active stock does not reconcile to 14,213 and 18 sections.")
  }
  if (sum(section_stock$address_exact_oo_count) != 5214L) {
    errors <- c(errors, "The address-exact O/O basis does not reconcile to 5,214.")
  }
  expected_cohorts <- c(
    "Unknown / undetermined", "Before 2000", "2000\u20132009", "2010\u20132014",
    "2015\u20132019", "2020\u20132024", "2025\u20132026"
  )
  expected_counts <- c(42L, 999L, 1406L, 1473L, 2199L, 4677L, 3417L)
  if (anyDuplicated(section_stock$section_code) ||
      !identical(cohorts$cohort, expected_cohorts) ||
      !identical(cohorts$count, expected_counts) ||
      sum(cohorts$count) != 14213L) {
    errors <- c(errors, "The public creation cohorts do not reconcile.")
  }
  if (!identical(flow$category, c(
    "address_exact_oo", "less_precise", "unmatched", "restricted"
  )) || !identical(flow$count, c(5214L, 5925L, 719L, 2355L)) ||
      sum(flow$count) != 14213L) {
    errors <- c(errors, "The aggregate geocoding flow does not reconcile.")
  }
  runtime_validation(errors)
}

validate_public_spatial_aggregates <- function(spatial, section_stock) {
  errors <- character()
  if (!is.data.frame(spatial) || !identical(names(spatial), required_spatial_aggregate_fields)) {
    return(runtime_validation("The public spatial aggregate schema is not permitted."))
  }
  if (nrow(spatial) != 286L || sum(spatial$count) != 4272L ||
      length(unique(spatial$grid_id)) != 51L) {
    errors <- c(errors, "The released spatial aggregates do not reconcile.")
  }
  if (any(spatial$count < 5L) || any(!is.finite(spatial$anchor_longitude)) ||
      any(!is.finite(spatial$anchor_latitude))) {
    errors <- c(errors, "A public spatial aggregate violates the threshold or anchor rules.")
  }
  spatial_by_section <- table(factor(
    rep(spatial$section_code, spatial$count), levels = section_stock$section_code
  ))
  if (!identical(as.integer(spatial_by_section), section_stock$spatial_released_count)) {
    errors <- c(errors, "Section-level released counts do not match the spatial table.")
  }
  forbidden <- c(
    "siret", "siren", "name", "address", "query", "naf_code",
    "creation_year", "person", "legal"
  )
  if (any(vapply(forbidden, function(value) {
    any(grepl(tolower(value), tolower(names(spatial)), fixed = TRUE))
  }, logical(1)))) {
    errors <- c(errors, "The public spatial table contains a forbidden field.")
  }
  runtime_validation(errors)
}

validate_public_history_yearly <- function(history) {
  errors <- character()
  if (!is.data.frame(history) || !identical(names(history), required_app_history_fields)) {
    return(runtime_validation("The public annual-history schema is not permitted."))
  }
  if (nrow(history) != 54L || !identical(as.integer(history$year), 1973:2026) ||
      anyDuplicated(history$year)) {
    errors <- c(errors, "The annual history must contain one row for every year from 1973 to 2026.")
  }
  partial <- history$coverage_status == "partial_year_current_snapshot"
  if (sum(partial) != 1L || history$year[partial] != 2026L) {
    errors <- c(errors, "Only 2026 may be marked as the partial current-snapshot year.")
  }
  event_fields <- c("creations", "closures", "reopenings", "other_period_changes")
  if (any(vapply(history[event_fields], function(x) any(x < 0L, na.rm = TRUE), logical(1)))) {
    errors <- c(errors, "Annual register-event counts cannot be negative.")
  }
  runtime_validation(errors)
}

validate_public_runtime_data <- function(stock, spatial, history) {
  stock_check <- validate_public_stock_aggregates(stock)
  if (!stock_check$valid) return(stock_check)
  checks <- list(
    stock_check,
    validate_public_spatial_aggregates(spatial, stock$section_stock),
    validate_public_history_yearly(history)
  )
  runtime_validation(unlist(lapply(checks, `[[`, "errors"), use.names = FALSE))
}

load_public_app_data <- function(bundle_dir) {
  paths <- c(
    stock = file.path(bundle_dir, "stock_aggregates.rds"),
    spatial = file.path(bundle_dir, "spatial_aggregates.rds"),
    history = file.path(bundle_dir, "history_yearly.rds")
  )
  missing <- paths[!file.exists(paths)]
  if (length(missing)) {
    stop("Missing public runtime data: ", paste(basename(missing), collapse = ", "), call. = FALSE)
  }
  result <- list(
    stock = readRDS(paths[["stock"]]),
    spatial = readRDS(paths[["spatial"]]),
    history = readRDS(paths[["history"]])
  )
  validation <- validate_public_runtime_data(
    result$stock, result$spatial, result$history
  )
  if (!validation$valid) stop(paste(validation$errors, collapse = " "), call. = FALSE)
  result
}

filter_spatial_aggregates <- function(spatial, section_code) {
  if (!identical(section_code, "ALL")) {
    return(spatial[spatial$section_code %in% section_code, , drop = FALSE])
  }
  counts <- stats::aggregate(count ~ grid_id, spatial, sum)
  anchors <- unique(spatial[c("grid_id", "anchor_longitude", "anchor_latitude")])
  if (anyDuplicated(anchors$grid_id)) stop("A grid cell has inconsistent display anchors.", call. = FALSE)
  result <- merge(counts, anchors, by = "grid_id", sort = TRUE)
  result$section_code <- "ALL"
  result[c("grid_id", "section_code", "count", "anchor_longitude", "anchor_latitude")]
}

lambert93_to_wgs84 <- function(x, y) {
  n <- 0.725607765053267
  c_constant <- 11754255.426096
  x_origin <- 700000
  y_origin <- 12655612.049876
  longitude_origin <- 3 * pi / 180
  eccentricity <- 0.0818191910428158
  radius <- sqrt((x - x_origin)^2 + (y - y_origin)^2)
  gamma <- atan2(x - x_origin, y_origin - y)
  longitude <- longitude_origin + gamma / n
  latitude_iso <- -log(radius / c_constant) / n
  latitude <- 2 * atan(exp(latitude_iso)) - pi / 2
  for (iteration in seq_len(8L)) {
    latitude <- 2 * atan(
      exp(latitude_iso) *
        ((1 + eccentricity * sin(latitude)) /
           (1 - eccentricity * sin(latitude)))^(eccentricity / 2)
    ) - pi / 2
  }
  data.frame(
    longitude = longitude * 180 / pi,
    latitude = latitude * 180 / pi
  )
}

released_grid_cells <- function(spatial) {
  grid_index <- data.frame(
    grid_id = sprintf("G%03d", seq_len(51L)),
    grid_x = c(
      1864, 1864, 1864, 1864, 1865, 1865, 1865, 1865, 1865, 1866,
      1866, 1866, 1867, 1867, 1867, 1867, 1867, 1868, 1868, 1868,
      1868, 1868, 1868, 1868, 1868, 1869, 1869, 1869, 1869, 1869,
      1869, 1869, 1870, 1870, 1870, 1870, 1870, 1870, 1871, 1871,
      1871, 1871, 1871, 1871, 1872, 1872, 1872, 1872, 1872, 1873, 1873
    ),
    grid_y = c(
      12454, 12455, 12456, 12457, 12448, 12449, 12454, 12455, 12456, 12454,
      12455, 12456, 12446, 12453, 12454, 12455, 12456, 12446, 12447, 12450,
      12451, 12453, 12454, 12455, 12456, 12448, 12449, 12450, 12451, 12452,
      12453, 12455, 12448, 12449, 12450, 12451, 12452, 12453, 12448, 12449,
      12450, 12451, 12452, 12453, 12448, 12450, 12451, 12452, 12453, 12451,
      12452
    )
  )
  released_ids <- sort(unique(as.character(spatial$grid_id)))
  if (!identical(released_ids, grid_index$grid_id)) {
    stop("The released grid-cell identifiers do not match the approved grid.", call. = FALSE)
  }
  paths <- lapply(seq_len(nrow(grid_index)), function(index) {
    x_min <- grid_index$grid_x[[index]] * 500
    y_min <- grid_index$grid_y[[index]] * 500
    lambert93_to_wgs84(
      c(x_min, x_min + 500, x_min + 500, x_min, x_min),
      c(y_min, y_min, y_min + 500, y_min + 500, y_min)
    )
  })
  grid_index$longitude_path <- lapply(paths, `[[`, "longitude")
  grid_index$latitude_path <- lapply(paths, `[[`, "latitude")
  grid_index[c("grid_id", "longitude_path", "latitude_path")]
}

filter_released_grid_cells <- function(grid_cells, circles) {
  cells <- grid_cells[grid_cells$grid_id %in% circles$grid_id, , drop = FALSE]
  values <- circles[c("grid_id", "section_code", "count")]
  result <- merge(cells, values, by = "grid_id", sort = TRUE)
  if (nrow(result) != nrow(circles)) {
    stop("A published aggregate is missing its released grid cell.", call. = FALSE)
  }
  result
}

build_aggregate_popup <- function(data, section_labels) {
  missing <- setdiff(required_spatial_aggregate_fields, names(data))
  if (length(missing)) {
    stop("Aggregate popup data are missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  escape <- function(value) {
    htmltools::htmlEscape(ifelse(is.na(value), "Not available", as.character(value)))
  }
  label <- ifelse(
    data$section_code == "ALL", "All published economic sections",
    paste0(data$section_code, " \u2014 ", unname(section_labels[data$section_code]))
  )
  paste0(
    "<strong>", escape(label), "</strong><br>",
    "500 m aggregation grid<br>",
    "Published establishments: ", escape(data$count), "<br>",
    "<em>Aggregated spatial display; not an establishment location.</em>"
  )
}

section_spatial_summary <- function(section_stock, section_code) {
  if (identical(section_code, "ALL")) {
    return(list(
      section_code = "ALL", section_label = "All economic sections",
      active = sum(section_stock$active_count),
      address_exact_oo = sum(section_stock$address_exact_oo_count),
      spatial_released = sum(section_stock$spatial_released_count)
    ))
  }
  section <- section_stock[section_stock$section_code %in% section_code, , drop = FALSE]
  if (nrow(section) != 1L) stop("Unknown economic section: ", section_code, call. = FALSE)
  list(
    section_code = section_code,
    section_label = section$section_label[[1]],
    active = section$active_count[[1]],
    address_exact_oo = section$address_exact_oo_count[[1]],
    spatial_released = section$spatial_released_count[[1]]
  )
}

public_geocoding_flow_counts <- function(stock) {
  flow <- stats::setNames(stock$geocoding_flow$count, stock$geocoding_flow$category)
  released <- sum(stock$section_stock$spatial_released_count)
  value <- c(
    address_exact_oo = unname(flow[["address_exact_oo"]]),
    spatial_released = released,
    threshold_excluded = unname(flow[["address_exact_oo"]]) - released,
    less_precise = unname(flow[["less_precise"]]),
    unmatched = unname(flow[["unmatched"]]),
    restricted = unname(flow[["restricted"]])
  )
  endpoints <- value[c("address_exact_oo", "less_precise", "unmatched", "restricted")]
  if (anyNA(value) || sum(endpoints) != 14213L) {
    stop("Public geocoding flow endpoints do not reconcile with the active stock.", call. = FALSE)
  }
  value
}

aggregate_circle_radius <- function(count) {
  count <- as.numeric(count)
  if (any(!is.finite(count)) || any(count < 5)) {
    stop("Published circle counts must be at least five.", call. = FALSE)
  }
  2 * sqrt(count)
}

history_event_series <- function(history, event) {
  field <- switch(event,
    "Administrative creations" = "creations",
    "Administrative closures" = "closures",
    "Reopenings" = "reopenings",
    stop("Unknown history event.", call. = FALSE)
  )
  data.frame(
    year = history$year,
    value = history[[field]],
    event = event,
    coverage_status = history$coverage_status,
    stringsAsFactors = FALSE
  )
}

create_map_home_button <- function(bounds) {
  required <- c("west", "south", "east", "north")
  if (!all(required %in% names(bounds)) || any(!is.finite(bounds[required]))) {
    stop("Map bounds must contain finite west, south, east and north values.", call. = FALSE)
  }
  leaflet::easyButton(
    icon = "fa-home", title = "Return to the La Seyne-sur-Mer overview",
    onClick = htmlwidgets::JS(sprintf(
      paste0("function(btn, map) { map.fitBounds(",
             "[[%.8f, %.8f], [%.8f, %.8f]]); }"),
      bounds[["south"]], bounds[["west"]],
      bounds[["north"]], bounds[["east"]]
    ))
  )
}
