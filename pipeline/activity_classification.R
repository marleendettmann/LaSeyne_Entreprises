normalize_ape_code <- function(code) {
  code <- toupper(trimws(as.character(code)))
  code[!nzchar(code)] <- NA_character_
  code
}

classify_activities <- function(establishments, reference) {
  required <- c("ape_code", "nomenclature_version", "section_code",
                "section_label", "activity_label")
  missing_reference <- setdiff(required, names(reference))
  if (length(missing_reference)) {
    stop("Missing reference columns: ", paste(missing_reference, collapse = ", "), call. = FALSE)
  }
  if (anyDuplicated(paste(reference$nomenclature_version, reference$ape_code))) {
    stop("Activity reference keys are not unique.", call. = FALSE)
  }
  out <- establishments
  out$original_ape_code <- normalize_ape_code(out$activity_code)
  out$original_nomenclature_version <- as.character(out$activity_nomenclature)
  key <- paste(out$original_nomenclature_version, out$original_ape_code, sep = "|")
  reference_key <- paste(reference$nomenclature_version, reference$ape_code, sep = "|")
  matched <- match(key, reference_key)
  out$section_code <- reference$section_code[matched]
  out$section_label <- reference$section_label[matched]
  out$official_activity_label <- reference$activity_label[matched]
  out$classification_status <- ifelse(
    is.na(out$original_ape_code), "missing_code",
    ifelse(is.na(out$original_nomenclature_version), "missing_nomenclature",
           ifelse(is.na(matched), "unmapped_code_or_version", "mapped"))
  )
  out
}

validate_activity_classification <- function(classified, expected_count) {
  errors <- character()
  if (nrow(classified) != expected_count) errors <- c(errors, "Classified row count differs from active stock.")
  allowed <- c("mapped", "missing_code", "missing_nomenclature", "unmapped_code_or_version")
  if (any(!classified$classification_status %in% allowed)) errors <- c(errors, "Unknown classification status.")
  mapped <- classified$classification_status == "mapped"
  if (any(mapped & (is.na(classified$section_code) | is.na(classified$official_activity_label)))) {
    errors <- c(errors, "Mapped records lack official labels.")
  }
  counts <- table(factor(classified$classification_status, levels = allowed))
  if (sum(counts) != expected_count) errors <- c(errors, "Classification status counts do not reconcile.")
  list(valid = !length(errors), errors = unique(errors), counts = as.list(counts))
}
