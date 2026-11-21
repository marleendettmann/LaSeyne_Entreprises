history_scalar <- function(value, default = NA_character_) {
  if (is.null(value) || !length(value) || is.na(value[[1]])) default else as.character(value[[1]])
}

normalize_establishment_periods <- function(record, analysis_date, snapshot_date) {
  periods <- record$periodesEtablissement
  if (is.null(periods)) periods <- list()
  declared <- suppressWarnings(as.integer(history_scalar(record$nombrePeriodesEtablissement)))
  if (is.na(declared) || declared != length(periods)) {
    stop("Returned periods do not match nombrePeriodesEtablissement for SIRET ",
         history_scalar(record$siret), call. = FALSE)
  }
  if (!length(periods)) return(data.frame())

  rows <- lapply(periods, function(period) {
    data.frame(
      siret = history_scalar(record$siret),
      period_start = as.Date(history_scalar(period$dateDebut)),
      period_end = as.Date(history_scalar(period$dateFin)),
      administrative_status = history_scalar(period$etatAdministratifEtablissement),
      status_change_indicator = isTRUE(period$changementEtatAdministratifEtablissement),
      analysis_date = as.Date(analysis_date),
      snapshot_date = as.Date(snapshot_date),
      is_purged = isTRUE(record$uniteLegale$unitePurgeeUniteLegale),
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  result <- result[order(result$period_start, result$period_end, na.last = TRUE), , drop = FALSE]
  rownames(result) <- NULL
  result$period_number <- seq_len(nrow(result))
  result$period_number_source <- "derived_chronological"
  result$period_is_future <- !is.na(result$period_start) & result$period_start > as.Date(analysis_date)
  result$period_status_known <- result$administrative_status %in% c("A", "F")
  result
}

classify_period_transitions <- function(periods, include_future = FALSE) {
  if (!nrow(periods) || nrow(periods) == 1L) return(data.frame())
  periods <- periods[order(periods$period_number), , drop = FALSE]
  rows <- vector("list", nrow(periods) - 1L)
  for (i in 2:nrow(periods)) {
    previous <- periods[i - 1L, , drop = FALSE]
    current <- periods[i, , drop = FALSE]
    contiguous <- !is.na(previous$period_end) && !is.na(current$period_start) &&
      current$period_start == previous$period_end + 1
    statuses_known <- previous$administrative_status %in% c("A", "F") &&
      current$administrative_status %in% c("A", "F")
    indicator_consistent <- statuses_known &&
      identical(isTRUE(current$status_change_indicator),
                previous$administrative_status != current$administrative_status)
    clear <- contiguous && statuses_known && indicator_consistent
    transition <- if (clear) {
      paste0(previous$administrative_status, "_to_", current$administrative_status)
    } else {
      "unclear"
    }
    event_type <- switch(
      transition,
      A_to_F = "closure",
      F_to_A = "reopening",
      A_to_A = "other_period_change",
      F_to_F = "other_period_change",
      "unclear"
    )
    reason <- if (clear) NA_character_ else if (!contiguous) {
      "non_contiguous_or_missing_period_boundary"
    } else if (!statuses_known) {
      "missing_or_invalid_status"
    } else {
      "status_change_indicator_inconsistent"
    }
    rows[[i - 1L]] <- data.frame(
      siret = current$siret,
      event_date = current$period_start,
      from_period_number = previous$period_number,
      to_period_number = current$period_number,
      status_from = previous$administrative_status,
      status_to = current$administrative_status,
      transition = transition,
      event_type = event_type,
      unresolved_reason = reason,
      analysis_date = current$analysis_date,
      snapshot_date = current$snapshot_date,
      is_purged = current$is_purged,
      after_analysis_date = !is.na(current$period_start) && current$period_start > current$analysis_date,
      stringsAsFactors = FALSE
    )
  }
  result <- do.call(rbind, rows)
  if (!include_future) result <- result[!result$after_analysis_date, , drop = FALSE]
  rownames(result) <- NULL
  result
}

classify_creation_date <- function(value, analysis_date) {
  value <- as.Date(value)
  if (is.na(value)) return("missing")
  if (value == as.Date("1900-01-01")) return("placeholder_1900")
  if (value > as.Date(analysis_date)) return("future")
  "included"
}

validate_history_tables <- function(periods, events, current) {
  errors <- character()
  warnings <- character()
  key <- paste(periods$siret, periods$period_start, periods$period_end,
               periods$administrative_status, sep = "|")
  if (anyDuplicated(key)) errors <- c(errors, "Duplicate period rows exist.")
  if (any(events$event_date > events$analysis_date, na.rm = TRUE)) {
    errors <- c(errors, "Events after analysis_date exist.")
  }
  event_key <- paste(events$siret, events$event_date, events$from_period_number,
                     events$to_period_number, sep = "|")
  if (anyDuplicated(event_key)) errors <- c(errors, "Duplicate transition events exist.")
  invalid_transition <- !events$transition %in% c(
    "A_to_F", "F_to_A", "A_to_A", "F_to_F", "unclear"
  )
  if (any(invalid_transition)) errors <- c(errors, "Invalid transition labels exist.")

  eligible <- periods[!is.na(periods$period_start) & periods$period_start <= periods$analysis_date &
                        (is.na(periods$period_end) | periods$period_end >= periods$analysis_date), , drop = FALSE]
  eligible_counts <- table(eligible$siret)
  last_rows <- eligible[eligible$siret %in% names(eligible_counts[eligible_counts == 1L]), , drop = FALSE]
  comparable <- merge(
    last_rows[c("siret", "administrative_status")],
    current[c("siret", "status_at_analysis_date", "status_at_analysis_date_source")],
    by = "siret", all = FALSE
  )
  expected <- ifelse(comparable$administrative_status == "A", "active",
                     ifelse(comparable$administrative_status == "F", "closed", NA_character_))
  inconsistent <- !is.na(expected) & !is.na(comparable$status_at_analysis_date) &
    expected != comparable$status_at_analysis_date
  if (any(inconsistent)) errors <- c(errors, "Period status disagrees with current snapshot status.")

  list(
    valid = !length(errors),
    errors = unique(errors),
    warnings = unique(warnings),
    metrics = list(
      period_count = nrow(periods),
      event_count = nrow(events),
      unresolved_transition_count = sum(events$event_type == "unclear"),
      current_status_comparisons = nrow(comparable),
      current_status_mismatches = sum(inconsistent)
    )
  )
}
