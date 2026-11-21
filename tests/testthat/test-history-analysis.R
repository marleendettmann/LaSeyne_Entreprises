source(testthat::test_path("..", "..", "pipeline", "history_analysis.R"), encoding = "UTF-8")

period_table <- function(statuses, starts, ends, changes = c(FALSE, rep(TRUE, length(statuses) - 1L)), purged = FALSE) {
  data.frame(
    siret = "12345678900011", period_start = as.Date(starts), period_end = as.Date(ends),
    administrative_status = statuses, status_change_indicator = changes,
    analysis_date = as.Date("2026-11-17"), snapshot_date = as.Date("2026-11-17"),
    is_purged = purged, period_number = seq_along(statuses),
    period_number_source = "derived_chronological",
    period_is_future = as.Date(starts) > as.Date("2026-11-17"),
    period_status_known = statuses %in% c("A", "F"), stringsAsFactors = FALSE
  )
}

test_that("a simple A to F transition is a closure", {
  x <- period_table(c("A", "F"), c("2020-01-01", "2022-01-01"), c("2021-12-31", NA))
  e <- classify_period_transitions(x)
  expect_equal(e$event_type, "closure")
  expect_equal(e$event_date, as.Date("2022-01-01"))
})

test_that("F to A is a reopening and multiple changes remain separate", {
  x <- period_table(c("A", "F", "A", "F"),
                    c("2020-01-01", "2021-01-01", "2022-01-01", "2023-01-01"),
                    c("2020-12-31", "2021-12-31", "2022-12-31", NA))
  e <- classify_period_transitions(x)
  expect_equal(e$event_type, c("closure", "reopening", "closure"))
})

test_that("same-status period changes are retained as other changes", {
  x <- period_table(c("A", "A"), c("2020-01-01", "2021-01-01"), c("2020-12-31", NA),
                    changes = c(FALSE, FALSE))
  expect_equal(classify_period_transitions(x)$event_type, "other_period_change")
})

test_that("future transitions are excluded from historical events", {
  x <- period_table(c("A", "F"), c("2020-01-01", "2026-12-01"), c("2026-11-30", NA))
  expect_equal(nrow(classify_period_transitions(x)), 0L)
  expect_true(classify_period_transitions(x, include_future = TRUE)$after_analysis_date)
})

test_that("missing status history is marked unresolved", {
  x <- period_table(c(NA, "A"), c("2020-01-01", "2021-01-01"), c("2020-12-31", NA))
  e <- classify_period_transitions(x)
  expect_equal(e$event_type, "unclear")
  expect_equal(e$unresolved_reason, "missing_or_invalid_status")
})

test_that("purged unit remains labelled and cannot invent a transition", {
  x <- period_table("F", NA, NA, changes = FALSE, purged = TRUE)
  expect_equal(nrow(classify_period_transitions(x)), 0L)
  expect_true(x$is_purged)
})

test_that("duplicate and overlapping boundaries do not yield clear events", {
  duplicate <- period_table(c("A", "F"), c("2020-01-01", "2020-01-01"),
                            c("2020-12-31", "2020-12-31"))
  overlap <- period_table(c("A", "F"), c("2020-01-01", "2020-12-31"),
                          c("2020-12-31", NA))
  expect_equal(classify_period_transitions(duplicate)$event_type, "unclear")
  expect_equal(classify_period_transitions(overlap)$event_type, "unclear")
})

test_that("creation dates distinguish missing, placeholder, future and valid", {
  expect_equal(classify_creation_date(as.Date(NA), "2026-11-17"), "missing")
  expect_equal(classify_creation_date("1900-01-01", "2026-11-17"), "placeholder_1900")
  expect_equal(classify_creation_date("2027-01-01", "2026-11-17"), "future")
  expect_equal(classify_creation_date("2020-01-01", "2026-11-17"), "included")
})

test_that("normalization verifies declared history count", {
  record <- list(
    siret = "12345678900011", nombrePeriodesEtablissement = 2,
    periodesEtablissement = list(list(
      dateDebut = "2020-01-01", dateFin = NULL,
      etatAdministratifEtablissement = "A",
      changementEtatAdministratifEtablissement = TRUE
    )), uniteLegale = list(unitePurgeeUniteLegale = FALSE)
  )
  expect_error(normalize_establishment_periods(record, "2026-11-17", "2026-11-17"),
               "nombrePeriodes")
})
