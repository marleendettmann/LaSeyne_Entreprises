#!/usr/bin/env Rscript

if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package 'jsonlite' is required.", call. = FALSE)

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(script_arg)) sub("^--file=", "", script_arg[[1]]) else "scripts/prepare_history.R"
project_root <- dirname(dirname(normalizePath(script_path, mustWork = TRUE)))
source(file.path(project_root, "pipeline", "history_analysis.R"), encoding = "UTF-8")
source(file.path(project_root, "pipeline", "data_validation.R"), encoding = "UTF-8")

parse_args <- function(args) {
  out <- list(input = NULL, current = NULL, analysis_date = NULL, output_dir = NULL)
  for (arg in args) {
    if (grepl("^--input=", arg)) out$input <- sub("^--input=", "", arg)
    else if (grepl("^--current=", arg)) out$current <- sub("^--current=", "", arg)
    else if (grepl("^--analysis-date=", arg)) out$analysis_date <- as.Date(sub("^--analysis-date=", "", arg))
    else if (grepl("^--output-dir=", arg)) out$output_dir <- sub("^--output-dir=", "", arg)
    else stop("Unknown argument: ", arg, call. = FALSE)
  }
  if (is.null(out$input) || is.null(out$current) || is.null(out$output_dir) ||
      is.null(out$analysis_date) || is.na(out$analysis_date)) stop("Required arguments are missing.", call. = FALSE)
  out
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
input_dir <- normalizePath(args$input, mustWork = TRUE)
current_path <- normalizePath(args$current, mustWork = TRUE)
manifest <- jsonlite::fromJSON(file.path(input_dir, "manifest.json"), simplifyVector = FALSE)
if (!isTRUE(manifest$complete)) stop("Input download is not complete.", call. = FALSE)
snapshot_date <- as.Date(manifest$snapshot_date)
pages <- sort(list.files(input_dir, pattern = "json$", full.names = TRUE))
pages <- pages[grepl("establishments_", basename(pages), fixed = TRUE)]

period_parts <- list(); event_parts <- list(); creation_parts <- list(); idx <- 0L
declared_mismatches <- 0L
future_transition_count <- 0L
for (page_path in pages) {
  records <- jsonlite::fromJSON(page_path, simplifyVector = FALSE)$etablissements
  for (record in records) {
    idx <- idx + 1L
    normalized <- normalize_establishment_periods(record, args$analysis_date, snapshot_date)
    period_parts[[idx]] <- normalized
    all_transitions <- classify_period_transitions(normalized, include_future = TRUE)
    if (nrow(all_transitions)) {
      event_parts[[idx]] <- all_transitions[!all_transitions$after_analysis_date, , drop = FALSE]
      future_transition_count <- future_transition_count + sum(all_transitions$after_analysis_date)
    } else {
      event_parts[[idx]] <- all_transitions
    }
    creation <- as.Date(history_scalar(record$dateCreationEtablissement))
    creation_parts[[idx]] <- data.frame(
      siret = history_scalar(record$siret), creation_date = creation,
      creation_date_class = classify_creation_date(creation, args$analysis_date),
      analysis_date = args$analysis_date, snapshot_date = snapshot_date,
      is_purged = isTRUE(record$uniteLegale$unitePurgeeUniteLegale),
      stringsAsFactors = FALSE
    )
  }
}
establishment_periods <- do.call(rbind, period_parts)
creation_cohorts <- do.call(rbind, creation_parts)
event_parts <- event_parts[vapply(event_parts, nrow, integer(1)) > 0L]
establishment_events <- if (length(event_parts)) do.call(rbind, event_parts) else data.frame()
rownames(establishment_periods) <- rownames(establishment_events) <- rownames(creation_cohorts) <- NULL

current <- readRDS(current_path)
validation <- validate_history_tables(establishment_periods, establishment_events, current)
if (!validation$valid) stop(paste(validation$errors, collapse = " "), call. = FALSE)

first_year <- 1973L
last_year <- as.integer(format(args$analysis_date, "%Y"))
years <- data.frame(year = seq.int(first_year, last_year))
count_year <- function(dates) table(as.integer(format(as.Date(dates), "%Y")))
creation_counts <- count_year(creation_cohorts$creation_date[creation_cohorts$creation_date_class == "included"])
closure_counts <- count_year(establishment_events$event_date[establishment_events$event_type == "closure"])
reopening_counts <- count_year(establishment_events$event_date[establishment_events$event_type == "reopening"])
other_counts <- count_year(establishment_events$event_date[establishment_events$event_type == "other_period_change"])
lookup <- function(tab) as.integer(tab[match(years$year, as.integer(names(tab)))])
establishment_yearly <- transform(
  years,
  creations = lookup(creation_counts), closures = lookup(closure_counts),
  reopenings = lookup(reopening_counts), other_period_changes = lookup(other_counts),
  coverage_complete = FALSE,
  coverage_status = ifelse(year == last_year, "partial_year_current_snapshot", "retrospective_current_snapshot_only")
)
# Missing cells remain NA: the current-snapshot population cannot establish a
# true zero for historical municipality-wide events.

missing_start_sirets <- unique(establishment_periods$siret[is.na(establishment_periods$period_start)])
missing_status_sirets <- unique(establishment_periods$siret[!establishment_periods$period_status_known])
incomplete_sirets <- unique(c(missing_start_sirets, missing_status_sirets))

dir.create(args$output_dir, recursive = TRUE, showWarnings = FALSE)
label <- format(snapshot_date, "%Y-%m-%d")
paths <- c(
  periods = file.path(args$output_dir, paste0("establishment_periods_", label, ".rds")),
  events = file.path(args$output_dir, paste0("establishment_events_", label, ".rds")),
  creations = file.path(args$output_dir, paste0("creation_cohorts_", label, ".rds")),
  yearly = file.path(args$output_dir, paste0("establishment_yearly_", label, ".rds")),
  metadata = file.path(args$output_dir, paste0("establishment_history_", label, "_metadata.json"))
)
if (any(file.exists(paths))) stop("Refusing to overwrite an existing history artifact.", call. = FALSE)
temps <- setNames(paste0(unname(paths), ".tmp"), names(paths))
on.exit(unlink(temps), add = TRUE)
saveRDS(establishment_periods, temps[["periods"]], version = 3)
saveRDS(establishment_events, temps[["events"]], version = 3)
saveRDS(creation_cohorts, temps[["creations"]], version = 3)
saveRDS(establishment_yearly, temps[["yearly"]], version = 3)
checksums <- vapply(temps[names(temps) != "metadata"], sha256_file, character(1))
metadata <- list(
  source = manifest$source, input_batch = basename(input_dir), current_snapshot = basename(current_path),
  analysis_date = format(args$analysis_date, "%Y-%m-%d"), snapshot_date = manifest$snapshot_date,
  population = "Establishments returned by the current municipal snapshot query; not an official business-demography population.",
  completeness = list(
    records = idx, returned_periods = nrow(establishment_periods),
    declared_period_count_mismatches = declared_mismatches,
    siret_with_missing_period_start = length(missing_start_sirets),
    siret_with_missing_status = length(missing_status_sirets),
    incomplete_history_siret = length(incomplete_sirets),
    future_periods = sum(establishment_periods$period_is_future),
    future_transitions_excluded = future_transition_count
  ),
  event_counts = as.list(table(factor(establishment_events$event_type,
                                      levels = c("closure", "reopening", "other_period_change", "unclear")))),
  creation_date_counts = as.list(table(factor(creation_cohorts$creation_date_class,
                                              levels = c("included", "missing", "placeholder_1900", "future")))),
  yearly_range = list(first_year = first_year, last_year = last_year,
                      note = "All years are incomplete retrospective observations; 2026 is additionally a partial calendar year. Zeros are not imputed."),
  validation = validation, sha256 = as.list(checksums)
)
jsonlite::write_json(metadata, temps[["metadata"]], pretty = TRUE, auto_unbox = TRUE,
                     na = "null", null = "null", Date = "ISO8601")
for (name in names(paths)) if (!file.rename(temps[[name]], paths[[name]])) stop("Could not finalize ", name, call. = FALSE)
message("Prepared history artifacts in: ", args$output_dir)
