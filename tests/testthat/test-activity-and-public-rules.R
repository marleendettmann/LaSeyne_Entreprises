source(testthat::test_path("..", "..", "pipeline", "activity_classification.R"), encoding = "UTF-8")
source(testthat::test_path("..", "..", "pipeline", "public_snapshot_rules.R"), encoding = "UTF-8")

test_that("NAF mapping is version-dependent and preserves originals", {
  x <- data.frame(activity_code = c("47.11D", "47.11D"),
                  activity_nomenclature = c("NAFRev2", "NAF25"))
  ref <- data.frame(ape_code = "47.11D", nomenclature_version = "NAFRev2",
                    section_code = "G", section_label = "Commerce",
                    activity_label = "Supermarchés")
  out <- classify_activities(x, ref)
  expect_equal(out$classification_status, c("mapped", "unmapped_code_or_version"))
  expect_equal(out$original_ape_code, c("47.11D", "47.11D"))
})

test_that("unknown and missing activity codes remain explicit", {
  x <- data.frame(activity_code = c("99.99X", NA), activity_nomenclature = c("NAFRev2", "NAFRev2"))
  ref <- data.frame(ape_code = "47.11D", nomenclature_version = "NAFRev2",
                    section_code = "G", section_label = "Commerce", activity_label = "Supermarchés")
  expect_equal(classify_activities(x, ref)$classification_status,
               c("unmapped_code_or_version", "missing_code"))
})

test_that("classification totals reconcile", {
  x <- data.frame(activity_code = c("47.11D", NA), activity_nomenclature = c("NAFRev2", "NAFRev2"))
  ref <- data.frame(ape_code = "47.11D", nomenclature_version = "NAFRev2",
                    section_code = "G", section_label = "Commerce", activity_label = "Supermarchés")
  result <- validate_activity_classification(classify_activities(x, ref), 2L)
  expect_true(result$valid)
  expect_equal(sum(unlist(result$counts)), 2L)
})

test_that("both diffusion levels govern exact coordinate publication", {
  expect_equal(coordinate_publication_eligibility(c("O", "O", "P"), c("O", "P", "O")),
               c("eligible_exact_point", "exact_point_prohibited", "exact_point_prohibited"))
})

test_that("geocode quality distinguishes precision and municipality", {
  expect_equal(assess_geocode_result(.92, "housenumber", "83126"), "accepted_exact")
  expect_equal(assess_geocode_result(.90, "street", "83126"), "accepted_approximate")
  expect_equal(assess_geocode_result(.95, "housenumber", "83000"), "outside_expected_commune")
  expect_equal(assess_geocode_result(.50, "housenumber", "83126"), "low_score")
})

test_that("public schema rejects identifiers and protected coordinates", {
  safe <- data.frame(snapshot_date = as.Date("2026-11-17"), analysis_date = as.Date("2026-11-17"),
                     status_at_analysis_date = "active", creation_year = 2020L,
                     section_code = "G", section_label = "Commerce",
                     longitude = NA_real_, latitude = NA_real_,
                     geocoding_quality = "restricted", geocoding_source = NA_character_)
  expect_true(validate_public_snapshot_schema(safe)$valid)
  unsafe <- safe; unsafe$siret <- "12345678900011"; unsafe$longitude <- 5.88
  expect_false(validate_public_snapshot_schema(unsafe)$valid)
})

test_that("BAN keys normalize punctuation and accents", {
  a <- make_address_key("5", NA, "Avenue Frédéric-Mistral", "83500", "83126")
  b <- make_address_key("5", "", "AVENUE FREDERIC MISTRAL", "83500", "83126")
  expect_equal(a, b)
})

test_that("BAN position quality is explicit", {
  expect_equal(classify_ban_position(c("entrée", "bâtiment", "parcelle", "segment")),
               c("address_exact", "address_exact", "address_approximate", "address_approximate"))
})

test_that("BAN matching preserves several establishments at one address", {
  matches <- match_unique_ban_keys(c("A", "A", "B"), c("A", "B"))
  expect_equal(matches, c(1L, 1L, 2L))
  expect_error(match_unique_ban_keys("A", c("A", "A")), "unique")
})

test_that("missing and shared address identifiers are counted", {
  result <- summarize_address_identifiers(c("ID1", "ID1", "ID2", NA, ""))
  expect_equal(result$present, 3L)
  expect_equal(result$missing, 2L)
  expect_equal(result$unique, 2L)
  expect_equal(result$used_multiple, 1L)
})

test_that("ambiguous API candidates cannot become exact markers", {
  expect_equal(classify_api_candidate(.90, "housenumber", "83126", TRUE, 2L, .03),
               "address_approximate")
  expect_equal(classify_api_candidate(.90, "housenumber", "83126", TRUE, 2L, .15),
               "address_exact")
  expect_equal(classify_api_candidate(.95, "street", "83126", FALSE), "street_only")
})

test_that("only exact rows may carry marker coordinates", {
  data <- data.frame(snapshot_date = as.Date("2026-11-17"), analysis_date = as.Date("2026-11-17"),
                     status_at_analysis_date = "active", creation_year = 2020L,
                     section_code = "G", section_label = "Commerce",
                     longitude = 5.88, latitude = 43.10,
                     geocoding_quality = "street_only", geocoding_source = "IGN")
  expect_false(validate_public_snapshot_schema(data)$valid)
  data$geocoding_quality <- "address_exact"
  expect_true(validate_public_snapshot_schema(data)$valid)
})
