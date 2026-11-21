coordinate_publication_eligibility <- function(establishment_diffusion, legal_unit_diffusion) {
  establishment_diffusion <- toupper(as.character(establishment_diffusion))
  legal_unit_diffusion <- toupper(as.character(legal_unit_diffusion))
  ifelse(
    establishment_diffusion == "O" & legal_unit_diffusion == "O",
    "eligible_exact_point",
    ifelse(establishment_diffusion %in% c("O", "P") & legal_unit_diffusion %in% c("O", "P"),
           "exact_point_prohibited", "unresolved_diffusion")
  )
}

assess_geocode_result <- function(score, result_type, result_citycode,
                                  expected_citycode = "83126", threshold = 0.80) {
  score <- suppressWarnings(as.numeric(score))
  result_type <- as.character(result_type)
  result_citycode <- as.character(result_citycode)
  if (is.na(score) || is.na(result_type) || is.na(result_citycode)) return("missing_or_invalid_result")
  if (result_citycode != expected_citycode) return("outside_expected_commune")
  if (!result_type %in% c("housenumber", "street", "locality", "municipality")) return("unsupported_precision")
  if (score < threshold) return("low_score")
  if (result_type == "housenumber") "accepted_exact" else "accepted_approximate"
}

normalize_address_text <- function(value) {
  value <- ifelse(is.na(value), "", as.character(value))
  if (!requireNamespace("stringi", quietly = TRUE)) {
    stop("Package 'stringi' is required for stable address normalization.", call. = FALSE)
  }
  value <- toupper(stringi::stri_trans_general(value, "Latin-ASCII"))
  value <- gsub("[^A-Z0-9]+", " ", value)
  trimws(gsub(" +", " ", value))
}

make_address_key <- function(number, repetition, street, postcode, citycode) {
  paste(normalize_address_text(number), normalize_address_text(repetition),
        normalize_address_text(street), as.character(postcode), as.character(citycode), sep = "|")
}

identify_cross_street_coordinate_rows <- function(longitude, latitude, street) {
  if (!identical(length(longitude), length(latitude)) || !identical(length(longitude), length(street))) {
    stop("longitude, latitude and street must have equal lengths.", call. = FALSE)
  }
  coordinate_key <- ifelse(
    is.finite(longitude) & is.finite(latitude),
    sprintf("%.7f|%.7f", longitude, latitude), NA_character_
  )
  street_key <- ifelse(is.na(street), "", as.character(street))
  if (!requireNamespace("stringi", quietly = TRUE)) {
    stop("Package 'stringi' is required for stable street normalization.", call. = FALSE)
  }
  street_key <- toupper(stringi::stri_trans_general(
    trimws(gsub("[[:space:]]+", " ", street_key)), "Latin-ASCII"
  ))
  counts <- tapply(street_key[!is.na(coordinate_key)], coordinate_key[!is.na(coordinate_key)],
    function(value) length(unique(value[nzchar(value)])))
  result <- rep(FALSE, length(coordinate_key))
  located <- !is.na(coordinate_key)
  result[located] <- counts[coordinate_key[located]] > 1L
  result[is.na(result)] <- FALSE
  result
}

classify_ban_position <- function(position_type) {
  position_type <- tolower(as.character(position_type))
  ifelse(position_type %in% c("entr\u00e9e", "entree", "b\u00e2timent", "batiment",
                              "cage d'escalier", "d\u00e9livrance postale", "delivrance postale"),
         "address_exact", "address_approximate")
}

match_unique_ban_keys <- function(address_keys, ban_keys) {
  if (anyDuplicated(ban_keys)) stop("BAN keys must be unique.", call. = FALSE)
  match(address_keys, ban_keys)
}

summarize_address_identifiers <- function(values) {
  values <- as.character(values)
  present <- values[!is.na(values) & nzchar(values)]
  counts <- table(present)
  list(present = length(present), missing = length(values) - length(present),
       unique = length(counts), used_once = sum(counts == 1L),
       used_multiple = sum(counts > 1L))
}

classify_api_candidate <- function(score, result_type, citycode, has_number,
                                   result_count = 1L, score_gap = Inf,
                                   expected_citycode = "83126") {
  score <- suppressWarnings(as.numeric(score))
  if (is.na(score) || is.na(result_type) || is.na(citycode)) return("unmatched")
  if (citycode != expected_citycode) return("unmatched")
  if (result_type == "housenumber" && isTRUE(has_number) && score >= 0.80 &&
      (result_count == 1L || (!is.na(score_gap) && score_gap >= 0.10))) return("address_exact")
  if (result_type == "housenumber") return("address_approximate")
  if (result_type %in% c("street", "locality", "municipality")) return("street_only")
  "unmatched"
}

validate_public_snapshot_schema <- function(data) {
  permitted <- c("snapshot_date", "analysis_date", "status_at_analysis_date",
                 "creation_year", "section_code", "section_label",
                 "longitude", "latitude", "geocoding_quality", "geocoding_source")
  forbidden <- setdiff(names(data), permitted)
  errors <- character()
  if (length(forbidden)) errors <- c(errors, paste("Forbidden public fields:", paste(forbidden, collapse = ", ")))
  if (all(c("longitude", "latitude", "geocoding_quality") %in% names(data))) {
    marker <- !is.na(data$longitude) | !is.na(data$latitude)
    if (any(xor(is.na(data$longitude), is.na(data$latitude)))) errors <- c(errors, "Coordinate pairs are incomplete.")
    if (any(marker & data$geocoding_quality != "address_exact")) {
      errors <- c(errors, "Non-exact rows contain public coordinates.")
    }
    if (any(!is.na(data$longitude) & (data$longitude < 5.75 | data$longitude > 6.00)) ||
        any(!is.na(data$latitude) & (data$latitude < 43.00 | data$latitude > 43.20))) {
      errors <- c(errors, "Public coordinates fall outside plausible bounds.")
    }
  }
  character_columns <- names(data)[vapply(data, is.character, logical(1))]
  if (length(character_columns) && any(vapply(data[character_columns], function(x) {
    any(grepl("\\[ND\\]|NON DIFFUSIBLE", x, ignore.case = TRUE), na.rm = TRUE)
  }, logical(1)))) errors <- c(errors, "Protected placeholder values remain.")
  if (length(character_columns) && any(vapply(data[character_columns], function(x) {
    any(grepl("^[0-9]{14}$", x), na.rm = TRUE)
  }, logical(1)))) errors <- c(errors, "A SIRET-like identifier remains in public values.")
  list(valid = !length(errors), errors = unique(errors))
}
