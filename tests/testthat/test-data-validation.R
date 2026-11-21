source(
  testthat::test_path("..", "..", "pipeline", "data_validation.R"),
  encoding = "UTF-8"
)

synthetic_establishments <- function() {
  data.frame(
    siret = c("12345678900011", "98765432100022"),
    siren = c("123456789", "987654321"),
    commune_code = c("83126", "83126"),
    administrative_status = c("active", "closed"),
    analysis_date = as.Date(c("2026-10-31", "2026-10-31")),
    future_creation = c(FALSE, FALSE),
    future_period = c(FALSE, FALSE),
    status_at_analysis_date = c("active", "closed"),
    status_at_analysis_date_source = c("period_interval", "period_interval"),
    status_unresolved = c(FALSE, FALSE),
    is_headquarters = c(TRUE, FALSE),
    diffusion_status = c("O", "P"),
    legal_unit_diffusion_status = c("O", "P"),
    creation_date = as.Date(c("2010-01-01", "2015-06-30")),
    creation_year = c(2010L, 2015L),
    period_start_date = as.Date(c("2010-01-01", "2020-12-31")),
    activity_code = c("47.11D", "62.01Z"),
    activity_nomenclature = c("NAFRev2", "NAFRev2"),
    sector = c(NA, NA),
    longitude = c(5.88, NA),
    latitude = c(43.10, NA),
    snapshot_date = as.Date(c("2026-10-31", "2026-10-31")),
    stringsAsFactors = FALSE
  )
}

test_that("valid synthetic establishments pass all critical checks", {
  result <- validate_establishment_current(synthetic_establishments())
  expect_true(result$valid)
  expect_length(result$errors, 0L)
  expect_equal(result$metrics$record_count, 2L)
  expect_equal(result$metrics$unique_siret_count, 2L)
})

test_that("required columns are enforced", {
  data <- synthetic_establishments()
  data$siret <- NULL
  result <- validate_establishment_current(data)
  expect_false(result$valid)
  expect_match(result$errors, "Missing required columns")
})

test_that("SIRET structure, uniqueness, and SIREN linkage are enforced", {
  malformed <- synthetic_establishments()
  malformed$siret[1] <- "123"
  expect_false(validate_establishment_current(malformed)$valid)

  duplicated <- synthetic_establishments()
  duplicated$siret[2] <- duplicated$siret[1]
  duplicated$siren[2] <- duplicated$siren[1]
  expect_match(validate_establishment_current(duplicated)$errors, "not unique")

  unlinked <- synthetic_establishments()
  unlinked$siren[1] <- "111111111"
  expect_match(validate_establishment_current(unlinked)$errors, "inconsistent")
})

test_that("status and commune values are constrained", {
  bad_status <- synthetic_establishments()
  bad_status$administrative_status[1] <- "unknown"
  expect_match(validate_establishment_current(bad_status)$errors, "administrative status")

  bad_commune <- synthetic_establishments()
  bad_commune$commune_code[1] <- "83000"
  expect_match(validate_establishment_current(bad_commune)$errors, "commune 83126")
})

test_that("analysis date and derived creation year are validated", {
  future_creation <- synthetic_establishments()
  future_creation$creation_date[1] <- as.Date("2027-01-01")
  future_creation$creation_year[1] <- 2027L
  future_creation$future_creation[1] <- TRUE
  future_creation$future_period[1] <- TRUE
  future_creation$status_at_analysis_date[1] <- NA_character_
  future_creation$status_at_analysis_date_source[1] <- "not_yet_created"
  expect_true(validate_establishment_current(future_creation)$valid)

  wrong_year <- synthetic_establishments()
  wrong_year$creation_year[1] <- 2011L
  expect_match(validate_establishment_current(wrong_year)$errors, "Creation year")
})

test_that("future establishment creation is retained without a status", {
  periods <- list(list(dateDebut = "2027-01-04", dateFin = NULL,
                       etatAdministratifEtablissement = "A"))
  state <- derive_analysis_state(periods, as.Date("2027-01-04"), as.Date("2026-11-17"))
  expect_true(state$future_creation)
  expect_true(state$future_period)
  expect_false(state$status_unresolved)
  expect_true(is.na(state$status_at_analysis_date))
})

test_that("future period uses the preceding valid period", {
  periods <- list(
    list(dateDebut = "2026-11-20", dateFin = NULL, etatAdministratifEtablissement = "F"),
    list(dateDebut = "2026-06-07", dateFin = "2026-11-19", etatAdministratifEtablissement = "A")
  )
  state <- derive_analysis_state(periods, as.Date("2026-03-18"), as.Date("2026-11-17"))
  expect_false(state$future_creation)
  expect_true(state$future_period)
  expect_equal(state$status_at_analysis_date, "active")
  expect_false(state$status_unresolved)
})

test_that("announced status changes do not replace the status at analysis date", {
  periods <- list(
    list(dateDebut = "2026-12-01", dateFin = NULL, etatAdministratifEtablissement = "A"),
    list(dateDebut = "2020-01-01", dateFin = "2026-11-30", etatAdministratifEtablissement = "F")
  )
  state <- derive_analysis_state(periods, as.Date("2020-01-01"), as.Date("2026-11-17"))
  expect_equal(state$status_at_analysis_date, "closed")
})

test_that("missing valid period leaves status unresolved", {
  periods <- list(
    list(dateDebut = "2026-12-01", dateFin = NULL, etatAdministratifEtablissement = "A"),
    list(dateDebut = "2020-01-01", dateFin = "2026-10-31", etatAdministratifEtablissement = "F")
  )
  state <- derive_analysis_state(periods, as.Date("2020-01-01"), as.Date("2026-11-17"))
  expect_true(state$status_unresolved)
  expect_true(is.na(state$status_at_analysis_date))
})

test_that("purged current stock without period start resolves only at snapshot", {
  periods <- list(
    list(dateDebut = NULL, dateFin = NULL, etatAdministratifEtablissement = "F")
  )
  current <- derive_analysis_state(
    periods, as.Date(NA), as.Date("2026-11-17"),
    snapshot_date = as.Date("2026-11-17"), is_purged = TRUE
  )
  historical <- derive_analysis_state(
    periods, as.Date(NA), as.Date("2020-01-01"),
    snapshot_date = as.Date("2026-11-17"), is_purged = TRUE
  )
  expect_equal(current$status_at_analysis_date, "closed")
  expect_equal(current$status_at_analysis_date_source, "api_current_purged_missing_start")
  expect_false(current$status_unresolved)
  expect_true(historical$status_unresolved)
  expect_true(is.na(historical$status_at_analysis_date))
})

test_that("regular active and closed periods resolve", {
  active <- list(list(dateDebut = "2020-01-01", dateFin = NULL,
                      etatAdministratifEtablissement = "A"))
  closed <- list(list(dateDebut = "2020-01-01", dateFin = NULL,
                      etatAdministratifEtablissement = "F"))
  expect_equal(
    derive_analysis_state(active, as.Date("2020-01-01"), as.Date("2026-11-17"))$status_at_analysis_date,
    "active"
  )
  expect_equal(
    derive_analysis_state(closed, as.Date("2020-01-01"), as.Date("2026-11-17"))$status_at_analysis_date,
    "closed"
  )
})

test_that("overlapping periods are rejected", {
  periods <- list(
    list(dateDebut = "2020-01-01", dateFin = "2022-01-01", etatAdministratifEtablissement = "A"),
    list(dateDebut = "2022-01-01", dateFin = NULL, etatAdministratifEtablissement = "F")
  )
  expect_match(
    derive_analysis_state(periods, as.Date("2020-01-01"), as.Date("2021-01-01"))$errors,
    "overlap"
  )
})

test_that("date missingness is counted numerically", {
  data <- synthetic_establishments()
  data$creation_date[1] <- as.Date(NA)
  data$creation_year[1] <- NA_integer_
  result <- validate_establishment_current(data)
  expect_identical(result$metrics$missing_values$creation_date, 1L)
  expect_identical(result$metrics$missing_values$period_start_date, 0L)
})

test_that("coordinate pairs and ranges are validated", {
  half_pair <- synthetic_establishments()
  half_pair$latitude[1] <- NA_real_
  expect_match(validate_establishment_current(half_pair)$errors, "missing together")

  impossible <- synthetic_establishments()
  impossible$longitude[1] <- 181
  expect_match(validate_establishment_current(impossible)$errors, "outside valid ranges")

  absent <- synthetic_establishments()
  absent$longitude <- NA_real_
  absent$latitude <- NA_real_
  expect_true(validate_establishment_current(absent)$valid)
})

test_that("diffusion status is required and partial coordinates are flagged", {
  invalid <- synthetic_establishments()
  invalid$diffusion_status[1] <- "X"
  expect_match(validate_establishment_current(invalid)$errors, "diffusion status")

  partial_location <- synthetic_establishments()
  partial_location$diffusion_status[1] <- "P"
  result <- validate_establishment_current(partial_location)
  expect_true(result$valid)
  expect_match(result$warnings, "do not publish")
})

test_that("known historical and forthcoming nomenclatures are accepted", {
  data <- synthetic_establishments()
  data$activity_nomenclature <- c("NAF1993", "NAF25")
  expect_true(validate_establishment_current(data)$valid)

  data$activity_nomenclature[1] <- "UNKNOWN"
  expect_match(validate_establishment_current(data)$errors, "Unknown activity nomenclature")
})
