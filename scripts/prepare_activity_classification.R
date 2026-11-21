#!/usr/bin/env Rscript

for (package in c("jsonlite", "readxl")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Package '", package, "' is required.", call. = FALSE)
}
script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(script_arg)) sub("^--file=", "", script_arg[[1]]) else "scripts/prepare_activity_classification.R"
project_root <- dirname(dirname(normalizePath(script_path, mustWork = TRUE)))
source(file.path(project_root, "pipeline", "activity_classification.R"), encoding = "UTF-8")
source(file.path(project_root, "pipeline", "data_validation.R"), encoding = "UTF-8")

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) stop("Missing --", name, call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1]])
}
current_path <- normalizePath(arg("current"), mustWork = TRUE)
reference_dir <- normalizePath(arg("reference-dir"), mustWork = TRUE)
output_dir <- arg("output-dir")
analysis_date <- as.Date(arg("analysis-date"))
if (is.na(analysis_date)) stop("Invalid analysis date.", call. = FALSE)

levels <- readxl::read_excel(file.path(reference_dir, "naf2008_5_niveaux.xls"))
names(levels) <- c("ape_code", "class_code", "group_code", "division_code", "section_code")
titles_raw <- readxl::read_excel(
  file.path(reference_dir, "intitules_naf_rev2.xls"), col_names = FALSE
)
titles <- data.frame(
  ape_code = normalize_ape_code(titles_raw[[2]]),
  activity_label = as.character(titles_raw[[3]]), stringsAsFactors = FALSE
)
titles <- titles[grepl("^[0-9]{2}\\.[0-9]{2}[A-Z]$", titles$ape_code), , drop = FALSE]
sections <- readxl::read_excel(
  file.path(reference_dir, "sections_naf_rev2.xls"), skip = 3,
  col_names = c("section_code", "section_label")
)
reference <- merge(levels[c("ape_code", "section_code")], titles, by = "ape_code", all.x = TRUE)
reference <- merge(reference, sections, by = "section_code", all.x = TRUE)
reference$nomenclature_version <- "NAFRev2"
reference <- reference[c("ape_code", "nomenclature_version", "section_code", "section_label", "activity_label")]
if (nrow(reference) != 732L || anyDuplicated(reference$ape_code) || anyNA(reference$activity_label)) {
  stop("NAF Rev. 2 reference validation failed.", call. = FALSE)
}

current <- readRDS(current_path)
active <- current[!is.na(current$status_at_analysis_date) &
                    current$status_at_analysis_date == "active" &
                    current$analysis_date == analysis_date, , drop = FALSE]
classified <- classify_activities(active, reference)
validation <- validate_activity_classification(classified, expected_count = nrow(active))
if (!validation$valid) stop(paste(validation$errors, collapse = " "), call. = FALSE)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
label <- format(analysis_date, "%Y-%m-%d")
paths <- c(
  reference = file.path(output_dir, paste0("naf_rev2_reference_", label, ".rds")),
  classified = file.path(output_dir, paste0("active_establishment_activity_", label, ".rds")),
  metadata = file.path(output_dir, paste0("activity_classification_", label, "_metadata.json"))
)
if (any(file.exists(paths))) stop("Refusing to overwrite an existing classification artifact.", call. = FALSE)
temps <- setNames(paste0(unname(paths), ".tmp"), names(paths)); on.exit(unlink(temps), add = TRUE)
saveRDS(reference, temps[["reference"]], version = 3)
saveRDS(classified, temps[["classified"]], version = 3)
checksums <- c(reference = sha256_file(temps[["reference"]]), classified = sha256_file(temps[["classified"]]))
distribution <- as.data.frame(table(
  section_code = ifelse(classified$classification_status == "mapped", classified$section_code,
                        classified$classification_status)
), stringsAsFactors = FALSE)
metadata <- list(
  analysis_date = format(analysis_date, "%Y-%m-%d"), active_count = nrow(active),
  reference = list(name = "NAF r\u00e9v. 2 (2008), five nested levels and official titles",
                   source = "https://www.insee.fr/fr/information/2120875", entries = nrow(reference)),
  validation = validation, section_distribution = distribution,
  sha256 = as.list(checksums),
  naf_2025_note = paste("NAF 2025 becomes the APE reference on 2027-01-01.",
                        "The October 2026 structure and correspondence table are stored as source references,",
                        "but no ambiguous automatic harmonisation is applied in this phase.")
)
jsonlite::write_json(metadata, temps[["metadata"]], pretty = TRUE, auto_unbox = TRUE,
                     na = "null", null = "null")
for (name in names(paths)) if (!file.rename(temps[[name]], paths[[name]])) stop("Could not finalize ", name, call. = FALSE)
message("Prepared activity classification in: ", output_dir)
