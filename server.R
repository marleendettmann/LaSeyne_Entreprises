server <- function(input, output, session) {
  add_aggregate_layers <- function(map, section_code) {
    circles <- filter_spatial_aggregates(spatial_aggregates, section_code)
    if (!nrow(circles)) return(map)
    circles$popup <- build_aggregate_popup(circles, section_labels)
    circles$radius <- aggregate_circle_radius(circles$count)
    cells <- filter_released_grid_cells(released_grid_geometry, circles)
    cells$popup <- circles$popup[match(cells$grid_id, circles$grid_id)]
    for (cell_index in seq_len(nrow(cells))) {
      map <- map |>
        addPolygons(
          lng = cells$longitude_path[[cell_index]],
          lat = cells$latitude_path[[cell_index]],
          popup = cells$popup[[cell_index]], group = "released-grid-cells",
          stroke = TRUE, color = "#467f73", weight = 0.8,
          opacity = 0.55, fillColor = "#69b3a2", fillOpacity = 0.07,
          options = leaflet::pathOptions(className = "released-grid-cell")
        )
    }
    map |>
      addCircleMarkers(
        data = circles,
        lng = ~anchor_longitude, lat = ~anchor_latitude,
        radius = ~radius, popup = ~popup, group = "aggregate-circles",
        stroke = TRUE, color = "#467f73", weight = 1.4,
        opacity = 0.9, fillColor = "#69b3a2", fillOpacity = 0.48
      )
  }

  output$value1 <- renderValueBox({
    valueBox(
      subtitle = "Active establishments (17 Nov 2026)",
      formatC(active_total, format = "d", big.mark = ","),
      color = "orange", size = "tiny"
    )
  })

  output$value2 <- renderValueBox({
    value <- history_yearly$creations[history_yearly$year == latest_complete_calendar_year]
    valueBox(
      paste("Administrative creations in", latest_complete_calendar_year),
      formatC(value, format = "d", big.mark = ","),
      color = "orange", size = "tiny"
    )
  })

  output$value3 <- renderValueBox({
    value <- history_yearly$closures[history_yearly$year == latest_complete_calendar_year]
    valueBox(
      paste("Administrative closures in", latest_complete_calendar_year),
      formatC(value, format = "d", big.mark = ","),
      color = "orange", size = "tiny"
    )
  })

  output$mymap <- renderLeaflet({
    home_button <- create_map_home_button(map_start_bounds)
    map <- leaflet() |>
      addTiles() |>
      addEasyButton(home_button) |>
      fitBounds(
        map_start_bounds[["west"]], map_start_bounds[["south"]],
        map_start_bounds[["east"]], map_start_bounds[["north"]]
      )
    add_aggregate_layers(map, "ALL") |>
      htmlwidgets::onRender(
        "function(el, x) {
          var map = this;
          function updateGridVisibility() {
            var visible = map.getZoom() >= 15;
            map.getContainer().classList.toggle('show-released-grid', visible);
          }
          map.on('zoom zoomend layeradd', function() {
            window.setTimeout(updateGridVisibility, 0);
          });
          window.setTimeout(updateGridVisibility, 0);
        }"
      )
  })

  observeEvent(input$select_Sectio, {
    proxy <- leafletProxy("mymap", session = session) |>
      clearGroup("released-grid-cells") |>
      clearGroup("aggregate-circles")
    add_aggregate_layers(proxy, input$select_Sectio)
  }, ignoreInit = TRUE)

  output$map_coverage <- renderUI({
    req(input$select_Sectio)
    coverage <- section_spatial_summary(section_stock, input$select_Sectio)
    if (identical(coverage$section_code, "ALL")) {
      detail <- paste0(
        formatC(coverage$active, format = "d", big.mark = ","),
        " active establishments \u00b7 ",
        formatC(coverage$address_exact_oo, format = "d", big.mark = ","),
        " address-exact O/O records in the internal map basis \u00b7 ",
        formatC(coverage$spatial_released, format = "d", big.mark = ","),
        " spatially published"
      )
    } else {
      detail <- paste0(
        formatC(coverage$active, format = "d", big.mark = ","),
        " active establishments \u00b7 ",
        formatC(coverage$spatial_released, format = "d", big.mark = ","),
        " spatially published"
      )
    }
    tags$div(
      class = "map-coverage-summary",
      tags$strong(paste0(coverage$section_code, " \u2014 ", coverage$section_label)),
      tags$br(),
      detail,
      if (coverage$spatial_released == 0L) tags$p(
        class = "map-threshold-note",
        "No spatial cell meets the minimum publication threshold for this section. Statistical totals remain available."
      )
    )
  })

  output$quality_sankey <- renderPlotly({
    total <- active_total
    labels <- c(
      paste0("Active establishments<br>", format(total, big.mark = ",")),
      paste0("Address-exact O/O<br>aggregation basis<br>", format(geocoding_flow[["address_exact_oo"]], big.mark = ",")),
      paste0("Less-precise geocodings<br>not spatially published<br>", format(geocoding_flow[["less_precise"]], big.mark = ",")),
      paste0("Not geocoded<br>", format(geocoding_flow[["unmatched"]], big.mark = ",")),
      paste0("Restricted diffusion<br>", format(geocoding_flow[["restricted"]], big.mark = ",")),
      paste0("Spatially published<br>500 m aggregates<br>", format(geocoding_flow[["spatial_released"]], big.mark = ",")),
      paste0("Excluded by n < 5 rule<br>", format(geocoding_flow[["threshold_excluded"]], big.mark = ","))
    )
    source <- c(rep(0L, 4L), 1L, 1L)
    target <- c(1:4, 5L, 6L)
    values <- c(
      geocoding_flow[["address_exact_oo"]], geocoding_flow[["less_precise"]],
      geocoding_flow[["unmatched"]], geocoding_flow[["restricted"]],
      geocoding_flow[["spatial_released"]], geocoding_flow[["threshold_excluded"]]
    )
    shares <- c(
      sprintf("%.1f%% of all active establishments", 100 * values[1:4] / total),
      sprintf("%.1f%% of the address-exact O/O basis", 100 * values[5:6] / values[[1]])
    )
    plotly::plot_ly(
      type = "sankey", orientation = "h",
      node = list(
        label = labels, pad = 18, thickness = 18,
        color = c("#5f627b", "#7a9f96", "#e9b872", "#b8bbc7", "#9b9eb4", "#69b3a2", "#d9a15b"),
        line = list(color = "#ffffff", width = 0.5),
        hovertemplate = "%{label}<extra></extra>"
      ),
      link = list(
        source = source, target = target, value = values, customdata = shares,
        color = c("rgba(122,159,150,0.42)", "rgba(233,184,114,0.40)",
                  "rgba(184,187,199,0.38)", "rgba(155,158,180,0.38)",
                  "rgba(105,179,162,0.52)", "rgba(217,161,91,0.42)"),
        hovertemplate = "%{value:,d} establishments<br>%{customdata}<extra></extra>"
      )
    ) |>
      plotly::layout(
        font = list(size = 12), margin = list(l = 20, r = 20, b = 20, t = 20)
      ) |>
      plotly::config(displayModeBar = FALSE, responsive = TRUE)
  })

  output$history_event_control <- renderUI({
    radioButtons(
      inputId = "select_RegClos", label = h3(" "),
      choices = c("Administrative creations", "Administrative closures", "Reopenings"),
      selected = "Administrative creations"
    )
  })

  output$history_time_control <- renderUI({
    sliderInput(
      "select_yearcreatio", "", 2015L, history_end_year,
      history_end_year, step = 1, sep = ""
    )
  })

  history_partial_note <- function() {
    tags$p(
      class = "ui tiny text",
      tags$strong("2026 is incomplete:"), " figures cover 1 January to 17 November 2026."
    )
  }
  output$history_period_note_left <- renderUI({
    history_partial_note()
  })
  output$history_period_note_right <- renderUI({
    history_partial_note()
  })

  output$plot1 <- renderPlotly({
    req(input$select_RegClos)
    series <- history_event_series(history_yearly, input$select_RegClos)
    series <- series[series$year >= history_start_year, , drop = FALSE]
    plot <- ggplot(series, aes(x = year, y = value)) +
      geom_area(fill = "#e08800", alpha = 0.8) +
      geom_line(color = "#e08800") +
      scale_y_continuous(labels = comma_format(big.mark = ",", decimal.mark = ".", suffix = " ")) +
      labs(x = "Year", y = input$select_RegClos) +
      theme_minimal(base_size = 12)
    ggplotly(plot, tooltip = c("x", "y")) |>
      plotly::layout(
        margin = list(l = 85, r = 35, b = 65, t = 45),
        xaxis = list(automargin = TRUE), yaxis = list(automargin = TRUE)
      ) |>
      plotly::config(displaylogo = FALSE, responsive = TRUE)
  })

  output$plot2 <- renderPlotly({
    req(input$select_yearcreatio)
    selected <- history_yearly[history_yearly$year == input$select_yearcreatio, , drop = FALSE]
    values <- data.frame(
      event = factor(
        c("Creations", "Closures", "Reopenings"),
        levels = c("Creations", "Closures", "Reopenings")
      ),
      n = c(selected$creations, selected$closures, selected$reopenings)
    )
    plot <- ggplot(values, aes(x = event, y = n, fill = event)) +
      geom_col() +
      scale_fill_manual(values = c("#9b9eb4", "#aebe39", "#e08800")) +
      labs(x = "Register event", y = "Establishments", title = input$select_yearcreatio) +
      scale_y_continuous(labels = comma_format(big.mark = ",", decimal.mark = ".", suffix = " ")) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "none")
    ggplotly(plot, tooltip = c("x", "y")) |>
      plotly::layout(
        margin = list(l = 80, r = 35, b = 85, t = 60),
        xaxis = list(automargin = TRUE), yaxis = list(automargin = TRUE)
      ) |>
      plotly::config(displaylogo = FALSE, responsive = TRUE)
  })

  output$plot3 <- renderPlotly({
    cohorts <- creation_cohorts
    cohorts$cohort <- factor(cohorts$cohort, levels = rev(cohorts$cohort))
    cohorts$tooltip <- paste0(
      as.character(cohorts$cohort), "<br>",
      formatC(cohorts$count, format = "d", big.mark = ","), " establishments"
    )
    plot <- ggplot(cohorts, aes(x = cohort, y = count, text = tooltip)) +
      geom_col(fill = "#69b3a2", width = 0.68) +
      geom_text(
        aes(label = scales::comma(count)), hjust = -0.12,
        color = "#4f5267", size = 3.6
      ) +
      coord_flip() +
      labs(
        x = NULL, y = "Active establishments"
      ) +
      scale_y_continuous(
        labels = comma_format(big.mark = ","),
        expand = expansion(mult = c(0, 0.12))
      ) +
      theme_minimal(base_size = 11) +
      theme(
        legend.position = "none",
        axis.text.y = element_text(size = 10),
        axis.title.x = element_text(margin = margin(t = 12))
      )
    ggplotly(plot, tooltip = "text") |>
      plotly::layout(
        margin = list(l = 170, r = 55, b = 70, t = 70),
        xaxis = list(automargin = TRUE), yaxis = list(automargin = TRUE)
      ) |>
      plotly::config(displaylogo = FALSE, responsive = TRUE)
  })
}
