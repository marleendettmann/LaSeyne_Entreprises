#!/usr/bin/env Rscript

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required.", call. = FALSE)
}

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(script_arg)) sub("^--file=", "", script_arg[[1]]) else "scripts/prepare_data.R"
project_root <- dirname(dirname(normalizePath(script_path, mustWork = TRUE)))
source(file.path(project_root, "pipeline", "data_validation.R"), encoding = "UTF-8")

parse_args <- function(args) {
  result <- list(
    input = NULL,
    analysis_date = NULL,
    output_dir = file.path(project_root, "data", "processed")
  )
  for (arg in args) {
    if (grepl("^--input=", arg)) {
      result$input <- sub("^--input=", "", arg)
    } else if (grepl("^--analysis-date=", arg)) {
      result$analysis_date <- as.Date(sub("^--analysis-date=", "", arg))
    } else if (grepl("^--output-dir=", arg)) {
      result$output_dir <- sub("^--output-dir=", "", arg)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }
  if (is.null(result$input)) stop("--input must name a completed download batch.", call. = FALSE)
  if (is.null(result$analysis_date) || is.na(result$analysis_date)) {
    stop("--analysis-date must be an ISO date (YYYY-MM-DD).", call. = FALSE)
  }
  result
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
input_dir <- normalizePath(args$input, mustWork = TRUE)
manifest_path <- file.path(input_dir, "manifest.json")
if (!file.exists(manifest_path)) stop("Download manifest is missing.", call. = FALSE)
manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
if (!isTRUE(manifest$complete)) {
  stop("The download batch is incomplete and cannot produce a snapshot.", call. = FALSE)
}

page_paths <- sort(list.files(
  input_dir, pattern = "^establishments_[0-9]{4}\\.json$", full.names = TRUE
))
if (!length(page_paths)) stop("No establishment pages were found.", call. = FALSE)

scalar <- function(value, default = NA_character_) {
  if (is.null(value) || !length(value) || is.na(value[[1]])) default else as.character(value[[1]])
}

current_period <- function(periods, siret) {
  if (is.null(periods) || !length(periods)) {
    stop("No establishment period for SIRET ", siret, call. = FALSE)
  }
  current <- Filter(function(period) is.null(period$dateFin) || !nzchar(scalar(period$dateFin, "")), periods)
  if (length(current) != 1L) {
    stop("Expected exactly one current period for SIRET ", siret, call. = FALSE)
  }
  current[[1]]
}

map_establishment <- function(record, snapshot_date, analysis_date) {
  siret <- scalar(record$siret)
  period <- current_period(record$periodesEtablissement, siret)
  declared_period_count <- suppressWarnings(as.integer(scalar(record$nombrePeriodesEtablissement)))
  returned_period_count <- length(record$periodesEtablissement)
  if (is.na(declared_period_count) || declared_period_count != returned_period_count) {
    stop("Period count mismatch for SIRET ", siret, call. = FALSE)
  }
  address <- record$adresseEtablissement
  legal_unit <- record$uniteLegale
  creation_date <- as.Date(scalar(record$dateCreationEtablissement))
  analysis_state <- derive_analysis_state(
    record$periodesEtablissement,
    creation_date,
    analysis_date,
    snapshot_date = snapshot_date,
    is_purged = isTRUE(legal_unit$unitePurgeeUniteLegale)
  )
  if (length(analysis_state$errors)) {
    stop(
      "Invalid period sequence for SIRET ", siret, ": ",
      paste(analysis_state$errors, collapse = " "), call. = FALSE
    )
  }
  data.frame(
    siret = siret,
    siren = scalar(record$siren),
    commune_code = scalar(address$codeCommuneEtablissement),
    administrative_status = map_establishment_status(period$etatAdministratifEtablissement),
    analysis_date = as.Date(analysis_date),
    future_creation = analysis_state$future_creation,
    future_period = analysis_state$future_period,
    status_at_analysis_date = analysis_state$status_at_analysis_date,
    status_at_analysis_date_source = analysis_state$status_at_analysis_date_source,
    status_unresolved = analysis_state$status_unresolved,
    is_headquarters = isTRUE(record$etablissementSiege),
    diffusion_status = toupper(scalar(record$statutDiffusionEtablissement)),
    legal_unit_diffusion_status = toupper(scalar(legal_unit$statutDiffusionUniteLegale)),
    creation_date = creation_date,
    creation_year = if (is.na(creation_date)) NA_integer_ else as.integer(format(creation_date, "%Y")),
    period_start_date = as.Date(scalar(period$dateDebut)),
    activity_code = scalar(period$activitePrincipaleEtablissement),
    activity_nomenclature = scalar(period$nomenclatureActivitePrincipaleEtablissement),
    sector = NA_character_,
    longitude = NA_real_,
    latitude = NA_real_,
    snapshot_date = as.Date(snapshot_date),
    stringsAsFactors = FALSE
  )
}

snapshot_date <- as.Date(manifest$snapshot_date)
rows <- list()
row_index <- 0L
for (page_path in page_paths) {
  page <- jsonlite::fromJSON(page_path, simplifyVector = FALSE)
  for (record in page$etablissements) {
    row_index <- row_index + 1L
    rows[[row_index]] <- map_establishment(record, snapshot_date, args$analysis_date)
  }
}
establishment_current <- do.call(rbind, rows)

if (!identical(nrow(establishment_current), as.integer(manifest$records_downloaded))) {
  stop("Prepared record count differs from the download manifest.", call. = FALSE)
}

validation <- assert_valid_establishment_current(
  establishment_current,
  commune_code = manifest$commune_code,
  snapshot_date = snapshot_date,
  analysis_date = args$analysis_date
)

dir.create(args$output_dir, recursive = TRUE, showWarnings = FALSE)
date_label <- format(snapshot_date, "%Y-%m-%d")
snapshot_path <- file.path(args$output_dir, paste0("establishment_current_", date_label, ".rds"))
metadata_path <- file.path(args$output_dir, paste0("establishment_current_", date_label, "_metadata.json"))
if (file.exists(snapshot_path) || file.exists(metadata_path)) {
  stop("Refusing to overwrite an existing prepared snapshot for ", date_label, call. = FALSE)
}

temporary_snapshot <- paste0(snapshot_path, ".tmp")
temporary_metadata <- paste0(metadata_path, ".tmp")
on.exit(unlink(c(temporary_snapshot, temporary_metadata)), add = TRUE)
saveRDS(establishment_current, temporary_snapshot, version = 3)
checksum <- sha256_file(temporary_snapshot)
metadata <- list(
  source = manifest$source,
  query = manifest$query,
  commune_code = manifest$commune_code,
  retrieved_at = manifest$retrieved_at,
  snapshot_date = manifest$snapshot_date,
  analysis_date = format(args$analysis_date, "%Y-%m-%d"),
  input_batch = basename(input_dir),
  record_count = nrow(establishment_current),
  unique_siret_count = length(unique(establishment_current$siret)),
  validation = validation,
  sha256 = checksum,
  privacy = list(
    snapshot_type = "internal_processing",
    contains_names_or_addresses = FALSE,
    public_snapshot_created = FALSE,
    note = "Do not publish coordinates for partially diffused establishments or legal units."
  ),
  limitations = list(
    coordinates = "The official SIRENE API does not provide geographic coordinates; values remain missing.",
    sector = "No official nomenclature lookup is joined in phase 2C.1; values remain missing.",
    history = paste(
      "All API periods are used only to determine status at analysis_date;",
      "the prepared table stores the API current status and the reconstructed",
      "status at analysis_date, but it is not an event-history table."
    )
  )
)
jsonlite::write_json(
  metadata, temporary_metadata, pretty = TRUE, auto_unbox = TRUE,
  na = "null", null = "null", Date = "ISO8601"
)

if (!file.rename(temporary_snapshot, snapshot_path)) stop("Could not finalize snapshot.", call. = FALSE)
if (!file.rename(temporary_metadata, metadata_path)) {
  unlink(snapshot_path)
  stop("Could not finalize metadata; snapshot was removed.", call. = FALSE)
}
message("Prepared snapshot: ", snapshot_path)
message("Metadata: ", metadata_path)
message("SHA-256: ", checksum)
