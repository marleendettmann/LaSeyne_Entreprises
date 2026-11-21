library(shiny)
library(ggplot2)
library(plotly)
library(scales)
library(leaflet)
library(semantic.dashboard)

required_runtime_functions <- c(
  "load_public_app_data", "history_event_plot_series",
  "creation_year_plot_data"
)
runtime_ready <- all(vapply(
  required_runtime_functions,
  exists, logical(1), mode = "function", inherits = FALSE
))
if (!runtime_ready) {
  source("R/app_runtime.R", local = TRUE, encoding = "UTF-8")
}

app_bundle_dir <- "data/app/insee_2026-11-17_grid500_privacy_v6_simplified"
app_data <- load_public_app_data(app_bundle_dir)
stock_aggregates <- app_data$stock
section_stock <- stock_aggregates$section_stock
spatial_aggregates <- app_data$spatial
released_grid_geometry <- released_grid_cells(spatial_aggregates)
history_yearly <- app_data$history
creation_year_top8 <- app_data$creation_year_top8
geocoding_flow <- public_geocoding_flow_counts(stock_aggregates)
creation_cohorts <- stock_aggregates$creation_cohorts

active_total <- sum(section_stock$active_count)
address_exact_oo_total <- sum(section_stock$address_exact_oo_count)
spatial_released_total <- sum(section_stock$spatial_released_count)

sections <- section_stock[c("section_code", "section_label")]
section_choices <- stats::setNames(
  c("ALL", sections$section_code),
  c("All economic sections", paste0(sections$section_code, " \u2014 ", sections$section_label))
)
section_labels <- stats::setNames(sections$section_label, sections$section_code)
history_yearly <- history_yearly[order(history_yearly$year), , drop = FALSE]
latest_complete_calendar_year <- max(
  history_yearly$year[history_yearly$coverage_status != "partial_year_current_snapshot"],
  na.rm = TRUE
)
history_start_year <- max(1985L, min(history_yearly$year, na.rm = TRUE))
history_end_year <- max(history_yearly$year, na.rm = TRUE)
map_start_bounds <- c(west = 5.842, south = 43.060, east = 5.914, north = 43.124)

my.col <- c("69b3a2", "75002B")
