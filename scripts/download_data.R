#!/usr/bin/env Rscript

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required.", call. = FALSE)
}
if (!requireNamespace("curl", quietly = TRUE)) {
  stop("Package 'curl' is required.", call. = FALSE)
}

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(script_arg)) sub("^--file=", "", script_arg[[1]]) else "scripts/download_data.R"
project_root <- dirname(dirname(normalizePath(script_path, mustWork = TRUE)))

parse_args <- function(args) {
  result <- list(max_pages = Inf, output_dir = file.path(project_root, "data", "raw"))
  for (arg in args) {
    if (grepl("^--max-pages=", arg)) {
      result$max_pages <- as.integer(sub("^--max-pages=", "", arg))
    } else if (grepl("^--output-dir=", arg)) {
      result$output_dir <- sub("^--output-dir=", "", arg)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }
  if (is.na(result$max_pages) || result$max_pages < 1L) {
    stop("--max-pages must be a positive integer.", call. = FALSE)
  }
  result
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
api_key <- Sys.getenv("INSEE_API_KEY", "")
if (!nzchar(api_key)) {
  stop(
    "INSEE_API_KEY is not set. Create an application on portail-api.insee.fr, ",
    "subscribe to API Sirene 3.11, and provide the integration key only through ",
    "the environment.",
    call. = FALSE
  )
}

scalar_character <- function(value, default = NA_character_) {
  if (is.null(value) || !length(value) || is.na(value[[1]])) {
    default
  } else {
    as.character(value[[1]])
  }
}

api_base <- "https://api.insee.fr/api-sirene/3.11"
commune_code <- "83126"
page_size <- 1000L
retrieved_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
batch_id <- paste0("insee_sirene_", gsub("[-:TZ]", "", retrieved_at))
dir.create(args$output_dir, recursive = TRUE, showWarnings = FALSE)
staging_dir <- file.path(args$output_dir, paste0(".", batch_id, "_staging"))
final_dir <- file.path(args$output_dir, batch_id)
if (dir.exists(staging_dir) || dir.exists(final_dir)) {
  stop("Refusing to overwrite an existing download batch: ", batch_id, call. = FALSE)
}
dir.create(staging_dir, recursive = FALSE)

last_request_time <- NULL
request_count <- 0L
minimum_request_interval <- 2.1

wait_for_rate_limit <- function() {
  if (!is.null(last_request_time)) {
    elapsed <- as.numeric(difftime(Sys.time(), last_request_time, units = "secs"))
    if (elapsed < minimum_request_interval) Sys.sleep(minimum_request_interval - elapsed)
  }
}

response_headers <- function(raw_headers) {
  lines <- strsplit(rawToChar(raw_headers), "\r?\n")[[1]]
  values <- list()
  for (line in lines[grepl(":", lines, fixed = TRUE)]) {
    parts <- strsplit(line, ":", fixed = TRUE)[[1]]
    values[[tolower(trimws(parts[[1]]))]] <- trimws(paste(parts[-1L], collapse = ":"))
  }
  values
}

download_json <- function(url, destination, max_attempts = 5L) {
  temporary <- paste0(destination, ".tmp")
  on.exit(unlink(temporary), add = TRUE)
  for (attempt in seq_len(max_attempts)) {
    wait_for_rate_limit()
    handle <- curl::new_handle()
    curl::handle_setheaders(
      handle,
      Accept = "application/json",
      `X-INSEE-Api-Key-Integration` = api_key
    )
    response <- tryCatch(
      curl::curl_fetch_disk(url, temporary, handle = handle),
      error = function(error) stop("INSEE download failed: ", conditionMessage(error), call. = FALSE)
    )
    last_request_time <<- Sys.time()
    request_count <<- request_count + 1L
    headers <- response_headers(response$headers)
    if (response$status_code == 429L) {
      retry_after <- suppressWarnings(as.numeric(headers[["retry-after"]]))
      reset_ms <- suppressWarnings(as.numeric(headers[["x-rate-limit-reset"]]))
      reset_wait <- if (is.na(reset_ms)) NA_real_ else reset_ms / 1000 - as.numeric(Sys.time())
      wait_seconds <- max(c(minimum_request_interval, retry_after, reset_wait), na.rm = TRUE)
      Sys.sleep(min(max(wait_seconds, 0), 60))
      next
    }
    if (response$status_code < 200L || response$status_code >= 300L) {
      stop("INSEE API returned HTTP status ", response$status_code, call. = FALSE)
    }
    parsed <- jsonlite::fromJSON(temporary, simplifyVector = FALSE)
    if (!file.rename(temporary, destination)) {
      stop("Could not finalize downloaded file: ", destination, call. = FALSE)
    }
    return(parsed)
  }
  stop("INSEE API rate limit persisted after retries.", call. = FALSE)
}

collect_dates <- function(value) {
  found <- character()
  walk <- function(node) {
    if (!is.list(node)) return(invisible(NULL))
    node_names <- names(node)
    if (!is.null(node_names)) {
      hits <- grepl("dateDerniereMiseADisposition", node_names, ignore.case = TRUE)
      for (item in node[hits]) {
        if (is.character(item) && length(item) == 1L) found <<- c(found, item)
      }
    }
    for (item in node) walk(item)
    invisible(NULL)
  }
  walk(value)
  parsed <- as.Date(substr(found, 1L, 10L))
  parsed[!is.na(parsed)]
}

information_path <- file.path(staging_dir, "informations.json")
information <- download_json(paste0(api_base, "/informations"), information_path)
updates <- information$datesDernieresMisesAJourDesDonnees
establishment_updates <- Filter(
  function(x) grepl("tablissements", scalar_character(x$collection, ""), ignore.case = TRUE),
  updates
)
if (length(establishment_updates) != 1L) {
  stop("Could not determine the official SIRENE snapshot date.", call. = FALSE)
}
snapshot_timestamp <- scalar_character(
  establishment_updates[[1]]$dateDerniereMiseADisposition
)
snapshot_date <- as.Date(substr(snapshot_timestamp, 1L, 10L))

cursor <- "*"
page <- 0L
downloaded_records <- 0L
reported_total <- NA_integer_
repeat {
  page <- page + 1L
  query <- paste0(
    "q=", utils::URLencode(paste0("codeCommuneEtablissement:", commune_code), reserved = TRUE),
    "&nombre=", page_size,
    "&curseur=", utils::URLencode(cursor, reserved = TRUE)
  )
  page_url <- paste0(api_base, "/siret?", query)
  page_path <- file.path(staging_dir, sprintf("establishments_%04d.json", page))
  response <- download_json(page_url, page_path)
  records <- response$etablissements
  if (is.null(records)) records <- list()
  downloaded_records <- downloaded_records + length(records)

  if (is.na(reported_total) && !is.null(response$header$total)) {
    reported_total <- as.integer(response$header$total)
  }
  next_cursor <- response$header$curseurSuivant
  complete <- !length(records) || is.null(next_cursor) || !nzchar(next_cursor) ||
    (!is.na(reported_total) && downloaded_records >= reported_total)
  if (complete || page >= args$max_pages) break
  cursor <- next_cursor
}

complete <- !is.na(reported_total) && downloaded_records >= reported_total
if (complete) {
  ending_information_path <- file.path(staging_dir, "informations_end.json")
  ending_information <- download_json(paste0(api_base, "/informations"), ending_information_path)
  ending_updates <- Filter(
    function(x) grepl("tablissements", scalar_character(x$collection, ""), ignore.case = TRUE),
    ending_information$datesDernieresMisesAJourDesDonnees
  )
  ending_timestamp <- if (length(ending_updates) == 1L) {
    scalar_character(ending_updates[[1]]$dateDerniereMiseADisposition)
  } else {
    NA_character_
  }
  if (is.na(ending_timestamp) || ending_timestamp != snapshot_timestamp) {
    stop("SIRENE establishment data changed during cursor pagination.", call. = FALSE)
  }
}
page_files <- list.files(
  staging_dir, pattern = "^establishments_[0-9]{4}\\.json$", full.names = TRUE
)
downloaded_page_bytes <- sum(file.info(page_files)$size)
estimated_total_page_bytes <- if (!is.na(reported_total) && downloaded_records > 0L) {
  ceiling(downloaded_page_bytes / downloaded_records * reported_total)
} else {
  NA_real_
}
manifest <- list(
  source = "INSEE API Sirene 3.11",
  api_base = api_base,
  query = paste0("codeCommuneEtablissement:", commune_code),
  commune_code = commune_code,
  retrieved_at = retrieved_at,
  snapshot_date = format(snapshot_date, "%Y-%m-%d"),
  snapshot_timestamp = snapshot_timestamp,
  page_size = page_size,
  pages_downloaded = page,
  records_downloaded = downloaded_records,
  records_reported_by_api = reported_total,
  downloaded_page_bytes = downloaded_page_bytes,
  estimated_total_page_bytes = estimated_total_page_bytes,
  api_requests = request_count,
  minimum_request_interval_seconds = minimum_request_interval,
  complete = complete,
  note = if (complete) "Complete municipality result." else "Controlled partial download; not suitable for preparation."
)
jsonlite::write_json(
  manifest, file.path(staging_dir, "manifest.json"),
  pretty = TRUE, auto_unbox = TRUE, na = "null"
)

if (!file.rename(staging_dir, final_dir)) {
  stop("Could not finalize download batch.", call. = FALSE)
}
message("Download batch: ", final_dir)
message("Records downloaded: ", downloaded_records)
message("Estimated complete JSON page bytes: ", estimated_total_page_bytes)
message("Complete municipality result: ", complete)
