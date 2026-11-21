required_establishment_columns <- function() {
  c(
    "siret", "siren", "commune_code", "administrative_status",
    "analysis_date", "future_creation", "future_period",
    "status_at_analysis_date", "status_at_analysis_date_source", "status_unresolved",
    "is_headquarters", "diffusion_status", "legal_unit_diffusion_status",
    "creation_date", "creation_year", "period_start_date",
    "activity_code", "activity_nomenclature", "sector", "longitude",
    "latitude", "snapshot_date"
  )
}

scalar_character <- function(value, default = NA_character_) {
  if (is.null(value) || !length(value) || is.na(value[[1]])) {
    default
  } else {
    as.character(value[[1]])
  }
}

map_establishment_status <- function(value) {
  switch(toupper(scalar_character(value, "")), A = "active", F = "closed", NA_character_)
}

derive_analysis_state <- function(
    periods,
    creation_date,
    analysis_date,
    snapshot_date = NULL,
    is_purged = FALSE) {
  analysis_date <- as.Date(analysis_date)
  creation_date <- as.Date(creation_date)
  if (length(analysis_date) != 1L || is.na(analysis_date)) {
    stop("Exactly one valid analysis date is required.", call. = FALSE)
  }

  if (is.null(periods)) periods <- list()
  starts <- as.Date(vapply(periods, function(x) scalar_character(x$dateDebut), ""))
  ends <- as.Date(vapply(periods, function(x) scalar_character(x$dateFin), ""))
  statuses <- vapply(periods, function(x) scalar_character(x$etatAdministratifEtablissement), "")
  errors <- character()

  if (any(!is.na(starts) & !is.na(ends) & ends < starts)) {
    errors <- c(errors, "An establishment period ends before it starts.")
  }
  if (sum(is.na(ends)) > 1L) {
    errors <- c(errors, "More than one open-ended establishment period exists.")
  }
  order_index <- order(starts, na.last = TRUE)
  ordered_starts <- starts[order_index]
  ordered_ends <- ends[order_index]
  if (length(periods) > 1L) {
    overlaps <- !is.na(ordered_starts[-1L]) & !is.na(ordered_ends[-length(ordered_ends)]) &
      ordered_starts[-1L] <= ordered_ends[-length(ordered_ends)]
    if (any(overlaps)) errors <- c(errors, "Establishment periods overlap.")
  }

  future_creation <- !is.na(creation_date) && creation_date > analysis_date
  future_period <- any(!is.na(starts) & starts > analysis_date)
  valid_at_date <- !is.na(starts) & starts <= analysis_date &
    (is.na(ends) | ends >= analysis_date)

  if (future_creation) {
    status <- NA_character_
    unresolved <- FALSE
    status_source <- "not_yet_created"
  } else if (sum(valid_at_date) == 1L) {
    status <- map_establishment_status(statuses[valid_at_date])
    unresolved <- is.na(status)
    status_source <- if (unresolved) "unresolved" else "period_interval"
  } else if (
      isTRUE(is_purged) &&
      !is.null(snapshot_date) &&
      !is.na(as.Date(snapshot_date)) &&
      analysis_date == as.Date(snapshot_date) &&
      length(periods) == 1L &&
      is.na(starts[[1]]) &&
      is.na(ends[[1]]) &&
      !is.na(map_establishment_status(statuses[[1]]))) {
    # INSEE current-stock data represent the current register state. Purged
    # establishments can have one closed period without a known dateDebut.
    # This fallback is valid only for the API snapshot date, never historically.
    status <- map_establishment_status(statuses[[1]])
    unresolved <- FALSE
    status_source <- "api_current_purged_missing_start"
  } else {
    status <- NA_character_
    unresolved <- TRUE
    status_source <- "unresolved"
  }

  list(
    future_creation = future_creation,
    future_period = future_period,
    status_at_analysis_date = status,
    status_at_analysis_date_source = status_source,
    status_unresolved = unresolved,
    matching_period_count = sum(valid_at_date),
    errors = unique(errors)
  )
}

empty_validation_result <- function() {
  list(errors = character(), warnings = character())
}

add_validation_issue <- function(result, level, message) {
  result[[level]] <- c(result[[level]], message)
  result
}

validate_establishment_current <- function(
    data,
    commune_code = "83126",
    snapshot_date = NULL,
    analysis_date = NULL) {
  result <- empty_validation_result()
  required <- required_establishment_columns()
  missing_columns <- setdiff(required, names(data))

  if (length(missing_columns)) {
    result <- add_validation_issue(
      result, "errors",
      paste("Missing required columns:", paste(missing_columns, collapse = ", "))
    )
    return(c(result, list(valid = FALSE, metrics = list())))
  }

  n <- nrow(data)
  snapshot <- if (is.null(snapshot_date)) {
    unique(as.Date(data$snapshot_date))
  } else {
    as.Date(snapshot_date)
  }
  snapshot <- snapshot[!is.na(snapshot)]
  if (length(snapshot) != 1L) {
    result <- add_validation_issue(
      result, "errors", "Exactly one valid snapshot date is required."
    )
    snapshot <- as.Date(NA)
  }
  analysis <- if (is.null(analysis_date)) {
    unique(as.Date(data$analysis_date))
  } else {
    as.Date(analysis_date)
  }
  analysis <- analysis[!is.na(analysis)]
  if (length(analysis) != 1L) {
    result <- add_validation_issue(
      result, "errors", "Exactly one valid analysis date is required."
    )
    analysis <- as.Date(NA)
  }
  if (!is.na(snapshot) && !is.na(analysis) && analysis > snapshot) {
    result <- add_validation_issue(
      result, "errors", "Analysis date must not occur after the API snapshot date."
    )
  }

  missing_siret <- is.na(data$siret) | !nzchar(data$siret)
  malformed_siret <- !missing_siret & !grepl("^[0-9]{14}$", data$siret)
  if (any(missing_siret)) {
    result <- add_validation_issue(result, "errors", "SIRET contains missing values.")
  }
  if (any(malformed_siret)) {
    result <- add_validation_issue(result, "errors", "SIRET must contain exactly 14 digits.")
  }
  if (anyDuplicated(data$siret)) {
    result <- add_validation_issue(result, "errors", "SIRET values are not unique.")
  }

  missing_siren <- is.na(data$siren) | !nzchar(data$siren)
  malformed_siren <- !missing_siren & !grepl("^[0-9]{9}$", data$siren)
  if (any(missing_siren) || any(malformed_siren)) {
    result <- add_validation_issue(result, "errors", "SIREN must contain exactly 9 digits.")
  }
  linked_siren <- !missing_siret & !malformed_siret & !missing_siren &
    !malformed_siren & substr(data$siret, 1L, 9L) != data$siren
  if (any(linked_siren)) {
    result <- add_validation_issue(result, "errors", "SIRET and SIREN are inconsistent.")
  }

  invalid_commune <- is.na(data$commune_code) | data$commune_code != commune_code
  if (any(invalid_commune)) {
    result <- add_validation_issue(
      result, "errors", paste("All records must belong to commune", commune_code)
    )
  }

  allowed_status <- c("active", "closed")
  invalid_status <- is.na(data$administrative_status) |
    !data$administrative_status %in% allowed_status
  if (any(invalid_status)) {
    result <- add_validation_issue(result, "errors", "Invalid administrative status values.")
  }

  logical_flags <- c("future_creation", "future_period", "status_unresolved")
  invalid_flags <- vapply(
    data[logical_flags], function(x) !is.logical(x) || any(is.na(x)), logical(1)
  )
  if (any(invalid_flags)) {
    result <- add_validation_issue(result, "errors", "Analysis flags must be non-missing logical values.")
  }
  invalid_analysis_status <- !is.na(data$status_at_analysis_date) &
    !data$status_at_analysis_date %in% allowed_status
  if (any(invalid_analysis_status)) {
    result <- add_validation_issue(result, "errors", "Invalid status at analysis date.")
  }
  allowed_status_sources <- c(
    "period_interval", "api_current_purged_missing_start",
    "not_yet_created", "unresolved"
  )
  invalid_status_source <- is.na(data$status_at_analysis_date_source) |
    !data$status_at_analysis_date_source %in% allowed_status_sources
  if (any(invalid_status_source)) {
    result <- add_validation_issue(result, "errors", "Invalid status-at-analysis source.")
  }
  future_with_status <- data$future_creation & !is.na(data$status_at_analysis_date)
  unresolved_with_status <- data$status_unresolved & !is.na(data$status_at_analysis_date)
  existing_without_status <- !data$future_creation & !data$status_unresolved &
    is.na(data$status_at_analysis_date)
  inconsistent_source <-
    (data$future_creation & data$status_at_analysis_date_source != "not_yet_created") |
    (data$status_unresolved & data$status_at_analysis_date_source != "unresolved") |
    (!data$future_creation & !data$status_unresolved &
       !data$status_at_analysis_date_source %in% c(
         "period_interval", "api_current_purged_missing_start"
       ))
  if (any(
      future_with_status | unresolved_with_status | existing_without_status |
        inconsistent_source,
      na.rm = TRUE)) {
    result <- add_validation_issue(
      result, "errors", "Status-at-analysis flags and status value are inconsistent."
    )
  }

  allowed_diffusion <- c("O", "P")
  invalid_diffusion <- is.na(data$diffusion_status) |
    !data$diffusion_status %in% allowed_diffusion
  invalid_legal_diffusion <- is.na(data$legal_unit_diffusion_status) |
    !data$legal_unit_diffusion_status %in% allowed_diffusion
  if (any(invalid_diffusion) || any(invalid_legal_diffusion)) {
    result <- add_validation_issue(result, "errors", "Invalid or missing diffusion status.")
  }

  creation_date <- as.Date(data$creation_date)
  period_start <- as.Date(data$period_start_date)
  if (any(!is.na(creation_date) & creation_date < as.Date("1900-01-01"))) {
    result <- add_validation_issue(result, "errors", "Creation dates before 1900 are implausible.")
  }
  # INSEE documents that period boundaries are effective dates and that the
  # earliest period can predate dateCreationEtablissement. Future effective
  # dates are retained and represented by the explicit analysis flags.

  derived_year <- suppressWarnings(as.integer(format(creation_date, "%Y")))
  bad_creation_year <- xor(is.na(derived_year), is.na(data$creation_year)) |
    (!is.na(derived_year) & derived_year != data$creation_year)
  if (any(bad_creation_year)) {
    result <- add_validation_issue(result, "errors", "Creation year does not match creation date.")
  }

  allowed_nomenclatures <- c("NAP", "NAF1993", "NAFRev1", "NAFRev2", "NAF25")
  invalid_nomenclature <- !is.na(data$activity_nomenclature) &
    nzchar(data$activity_nomenclature) &
    !data$activity_nomenclature %in% allowed_nomenclatures
  if (any(invalid_nomenclature)) {
    result <- add_validation_issue(result, "errors", "Unknown activity nomenclature.")
  }
  missing_nomenclature <- is.na(data$activity_nomenclature) |
    !nzchar(data$activity_nomenclature)
  if (any(missing_nomenclature)) {
    result <- add_validation_issue(
      result, "warnings",
      sprintf("Activity nomenclature is missing for %d records.", sum(missing_nomenclature))
    )
  }

  lon <- suppressWarnings(as.numeric(data$longitude))
  lat <- suppressWarnings(as.numeric(data$latitude))
  one_coordinate_missing <- xor(is.na(lon), is.na(lat))
  if (any(one_coordinate_missing)) {
    result <- add_validation_issue(result, "errors", "Longitude and latitude must be missing together.")
  }
  invalid_coordinate <- (!is.na(lon) & (lon < -180 | lon > 180)) |
    (!is.na(lat) & (lat < -90 | lat > 90))
  if (any(invalid_coordinate)) {
    result <- add_validation_issue(result, "errors", "Coordinates fall outside valid ranges.")
  }
  outside_local_bounds <- !is.na(lon) & !is.na(lat) &
    (lon < 5.75 | lon > 6.00 | lat < 43.00 | lat > 43.20)
  if (any(outside_local_bounds)) {
    result <- add_validation_issue(
      result, "warnings",
      sprintf("%d coordinates fall outside broad La Seyne-sur-Mer bounds.",
              sum(outside_local_bounds))
    )
  }

  partially_diffused <- data$diffusion_status == "P" |
    data$legal_unit_diffusion_status == "P"
  partial_with_coordinates <- partially_diffused & !is.na(lon) & !is.na(lat)
  if (any(partial_with_coordinates, na.rm = TRUE)) {
    result <- add_validation_issue(
      result, "warnings",
      sprintf("%d partially diffused records contain coordinates; do not publish them.",
              sum(partial_with_coordinates, na.rm = TRUE))
    )
  }

  missing_values <- vapply(
    data[required],
    function(x) sum(is.na(x) | as.character(x) == "", na.rm = TRUE),
    integer(1)
  )
  metrics <- list(
    record_count = n,
    unique_siret_count = length(unique(data$siret)),
    unique_siren_count = length(unique(data$siren)),
    status_distribution = as.list(table(data$administrative_status, useNA = "ifany")),
    status_at_analysis_date_distribution = as.list(table(
      data$status_at_analysis_date, useNA = "ifany"
    )),
    status_at_analysis_date_source_distribution = as.list(table(
      data$status_at_analysis_date_source, useNA = "ifany"
    )),
    headquarters_distribution = as.list(table(data$is_headquarters, useNA = "ifany")),
    diffusion_distribution = as.list(table(data$diffusion_status, useNA = "ifany")),
    missing_values = as.list(missing_values),
    future_creation_count = sum(data$future_creation, na.rm = TRUE),
    future_period_count = sum(data$future_period, na.rm = TRUE),
    status_unresolved_count = sum(data$status_unresolved, na.rm = TRUE),
    establishments_at_analysis_date = sum(!data$future_creation, na.rm = TRUE),
    missing_creation_date_count = sum(is.na(creation_date)),
    partially_diffused_count = sum(partially_diffused, na.rm = TRUE),
    missing_coordinate_count = sum(is.na(lon) & is.na(lat))
  )

  c(result, list(valid = !length(result$errors), metrics = metrics))
}

assert_valid_establishment_current <- function(...) {
  validation <- validate_establishment_current(...)
  if (!validation$valid) {
    stop(paste(validation$errors, collapse = "\n"), call. = FALSE)
  }
  validation
}

sha256_file <- function(path) {
  shasum <- Sys.which("shasum")
  if (!nzchar(shasum)) {
    stop("The 'shasum' command is required to create a SHA-256 checksum.", call. = FALSE)
  }
  output <- system2(shasum, c("-a", "256", shQuote(path)), stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (!is.null(status) && status != 0L) {
    stop("Could not calculate SHA-256 checksum.", call. = FALSE)
  }
  strsplit(output[[1]], "[[:space:]]+")[[1]][[1]]
}
