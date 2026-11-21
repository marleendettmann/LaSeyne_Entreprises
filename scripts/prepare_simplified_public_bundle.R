#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(script_arg)) sub("^--file=", "", script_arg[[1]]) else
  "scripts/prepare_simplified_public_bundle.R"
project_root <- dirname(dirname(normalizePath(script_path, mustWork = TRUE)))

source_bundle <- file.path(project_root, "data", "app",
  "insee_2026-11-17_grid500_privacy_v5_history3y")
target_bundle <- file.path(project_root, "data", "app",
  "insee_2026-11-17_grid500_privacy_v6_simplified")
current_path <- file.path(project_root, "data", "processed",
  "insee_sirene_20261117103727", "establishment_current_2026-11-17.rds")

if (dir.exists(target_bundle)) {
  stop("Refusing to overwrite the public target bundle.", call. = FALSE)
}

stock <- readRDS(file.path(source_bundle, "stock_aggregates.rds"))
current <- readRDS(current_path)
active <- current[
  !is.na(current$status_at_analysis_date) &
    current$status_at_analysis_date == "active",
  , drop = FALSE
]
if (nrow(active) != 14213L) {
  stop("Expected 14,213 active establishments.", call. = FALSE)
}

creation_year <- suppressWarnings(as.integer(active$creation_year))
cohort <- ifelse(
  is.na(creation_year) | creation_year == 1900L, "Unknown / undetermined",
  ifelse(creation_year < 2000L, "Before 2000",
    ifelse(creation_year <= 2009L, "2000\u20132009",
      ifelse(creation_year <= 2014L, "2010\u20132014",
        ifelse(creation_year <= 2019L, "2015\u20132019",
          ifelse(creation_year <= 2024L, "2020\u20132024", "2025\u20132026")))))
)
cohort_levels <- c(
  "Unknown / undetermined", "Before 2000", "2000\u20132009", "2010\u20132014",
  "2015\u20132019", "2020\u20132024", "2025\u20132026"
)
creation_cohorts <- data.frame(
  cohort = cohort_levels,
  count = as.integer(table(factor(cohort, levels = cohort_levels))),
  stringsAsFactors = FALSE
)
expected <- c(42L, 999L, 1406L, 1473L, 2199L, 4677L, 3417L)
if (!identical(creation_cohorts$count, expected) ||
    sum(creation_cohorts$count) != 14213L) {
  stop("Creation cohorts do not match the validated expected totals.", call. = FALSE)
}

public_stock <- list(
  reference_date = stock$reference_date,
  section_stock = stock$section_stock,
  creation_cohorts = creation_cohorts,
  geocoding_flow = stock$geocoding_flow
)

temporary <- paste0(target_bundle, ".tmp")
if (dir.exists(temporary)) unlink(temporary, recursive = TRUE)
dir.create(temporary, recursive = TRUE, showWarnings = FALSE)
on.exit(if (dir.exists(temporary)) unlink(temporary, recursive = TRUE), add = TRUE)

saveRDS(public_stock, file.path(temporary, "stock_aggregates.rds"), version = 3)
unchanged <- c("spatial_aggregates.rds", "history_yearly.rds")
copied <- file.copy(file.path(source_bundle, unchanged),
                    file.path(temporary, unchanged))
if (!all(copied)) stop("Could not copy unchanged public runtime files.", call. = FALSE)
source_md5 <- tools::md5sum(file.path(source_bundle, unchanged))
copy_md5 <- tools::md5sum(file.path(temporary, unchanged))
if (!identical(unname(source_md5), unname(copy_md5))) {
  stop("An unchanged runtime file differs after copying.", call. = FALSE)
}
if (!file.rename(temporary, target_bundle)) {
  stop("Could not finalize the simplified public bundle.", call. = FALSE)
}

message("Created simplified public bundle: ", target_bundle)
