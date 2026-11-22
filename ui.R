header <- dashboardHeader(
  title = tags$div(
    class = "project-brand",
    tags$strong("La Seyne Business Explorer"),
    tags$span("Exploring business establishments in La Seyne-sur-Mer")
  ),
  color = "black", inverted = TRUE,
  show_menu_button = FALSE
)

sidebar <- dashboardSidebar(
  side = "left", size = "thin", color = "orange", inverted = FALSE,
  sidebarMenu(
    menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
    menuItem(
      "Methodology and Data", tabName = "methodology",
      icon = icon("table")
    ),
    menuItem(
      "About", tabName = "about",
      icon = icon("bullseye")
    )
  )
)

frow1 <- fluidRow(
  valueBoxOutput("value1"),
  valueBoxOutput("value2"),
  valueBoxOutput("value3")
)

frow2 <- fluidRow(column(
  1, align = "center",
  box(
    title = "Establishments by economic activity", status = "primary",
    solidHeader = FALSE, collapsible = TRUE,
    tags$div(
      class = "privacy-aggregation-label",
      tags$span("Privacy-aware aggregation \u00b7 500 m grid"),
      tags$i(
        class = "info circle icon",
        title = paste(
          "Individual establishment locations are not displayed.",
          "Counts are aggregated into 500 m grid cells.",
          "Groups with fewer than five establishments are excluded from the spatial display."
        )
      )
    ),
    leafletOutput("mymap"),
    uiOutput("map_coverage"),
    tags$p(
      class = "ui tiny text",
      paste(
        "The map shows aggregated counts in 500 m grid cells, not individual establishment locations.",
        "Only grid cell\u2013sector combinations with at least five establishments are shown.",
        "Statistical totals include all active establishments, including those not represented on the map."
      )
    ),
    selectInput(
      inputId = "select_Sectio", label = h3(""),
      choices = section_choices, selected = "ALL"
    )
  )
))

partial_year_note <- tags$p(
  class = "ui tiny text",
  tags$strong("2026 is incomplete:"), " figures cover 1 January to 17 November 2026."
)

frow3 <- fluidRow(
  box(
    title = "Administrative register events over time", status = "primary",
    solidHeader = FALSE, collapsible = TRUE,
    tags$p(
      class = "chart-subtitle",
      "Annual administrative register events reconstructed from the current SIRENE snapshot."
    ),
    plotlyOutput("plot1", height = "347px"),
    uiOutput("history_event_control"),
    uiOutput("history_period_note_left")
  ),
  box(
    align = "center",
    title = "Register events by year",
    status = "primary",
    solidHeader = FALSE, collapsible = TRUE,
    plotlyOutput("plot2", height = "326px"),
    uiOutput("history_time_control"),
    uiOutput("history_period_note_right")
  )
)

frow4 <- fluidRow(column(
  1, align = "center",
  box(
    title = "Active establishments by creation year and economic section",
    status = "primary",
    solidHeader = FALSE, collapsible = TRUE,
    tags$p(
      class = "chart-subtitle",
      "Creation year of establishments still active in November 2026; eight largest sections by current stock."
    ),
    plotlyOutput("plot3", height = "460px"),
    sliderInput("select_creation_year", "", 2015L, 2026L, 2026L, step = 1L, sep = ""),
    uiOutput("creation_year_note")
  )
))

methodology_page <- fluidRow(column(
  1,
  box(
    title = "Methodology and Data", status = "primary",
    solidHeader = FALSE, collapsible = FALSE,
    tags$h3("Data sources"),
    tags$p(
      "The app uses a validated local snapshot of official INSEE SIRENE data for municipality code 83126. The data and analysis refer to 17 November 2026. The app makes no request to SIRENE, BAN or IGN when it starts."
    ),
    tags$p(
      tags$a(
        "INSEE SIRENE documentation", href = "https://www.insee.fr/fr/information/3591226",
        target = "_blank", rel = "noopener noreferrer"
      ),
      " \u00b7 ",
      tags$a(
        "INSEE API portal", href = "https://portail-api.insee.fr/",
        target = "_blank", rel = "noopener noreferrer"
      )
    ),
    tags$h3("Definitions"),
    tags$p(
      "The statistical unit is the establishment. The active stock includes establishments whose administrative status was active on the reference date. Administrative creations use the registered establishment creation date. Closures and reopenings are derived from documented status transitions. The start of a register period is not treated as a creation date. The value 1900 denotes an unknown or undetermined creation date."
    ),
    tags$h3("Geographic coverage"),
    tags$p(
      "The statistical totals include all 14,213 active establishments assigned to La Seyne-sur-Mer by the official municipality code. Of these, 5,214 have address-level geocoding and unrestricted diffusion at both establishment and legal-unit level, making them suitable for spatial aggregation. The published 500 m grid aggregates represent 4,272 establishments. Individual establishment locations are never shown."
    ),
    tags$div(
      class = "aggregation-explainer",
      tags$div(
        class = "aggregation-step",
        tags$div(class = "synthetic-points", lapply(seq_len(7), function(i) tags$span(class = paste0("point point-", i)))),
        tags$strong("Eligible establishments"),
        tags$p("Synthetic points illustrate the 5,214 records suitable for spatial aggregation.")
      ),
      tags$div(class = "aggregation-arrow", icon("arrow right")),
      tags$div(
        class = "aggregation-step",
        tags$div(class = "synthetic-grid", lapply(seq_len(4), function(i) tags$span(class = paste0("grid-cell grid-cell-", i)))),
        tags$strong("500 m aggregation"),
        tags$p("Eligible records are counted by fixed grid cell and NAF section.")
      ),
      tags$div(class = "aggregation-arrow", icon("arrow right")),
      tags$div(
        class = "aggregation-step",
        tags$div(class = "synthetic-published-circle", "7"),
        tags$strong("Published aggregates"),
        tags$p("A cell-section combination is shown only when it contains at least five establishments.")
      )
    ),
    tags$h3("Data quality"),
    plotlyOutput("quality_sankey", height = "330px"),
    tags$p(
      "The flow chart distinguishes the full active stock, the 5,214 establishments suitable for spatial aggregation, and the 4,272 establishments represented in published grid aggregates. Establishments with less precise geocoding, no match or restricted diffusion remain part of the non-spatial totals."
    ),
    tags$p(
      "The spatial table contains 286 grid-cell and economic-section combinations, each with at least five establishments. Smaller combinations are excluded. No unfiltered cell total or suppressed remainder is published for an individual grid cell. Section totals reveal how many establishments are excluded overall, but not how they are distributed among unpublished cells."
    ),
    tags$h3("Limitations"),
    tags$p(
      "Historical figures are reconstructed from the SIRENE register snapshot and reflect administrative events rather than the full history of business activity. Figures for 2026 cover only the period up to 17 November."
    ),
    tags$p(
      "The creation-year chart shows the eight largest economic sections among establishments still active on the reference date. It does not represent all establishments created in those years."
    ),
    tags$p(
      "The map displays aggregated counts rather than individual locations. Spatial coverage depends on geocoding quality, diffusion status and a minimum of five establishments per grid cell and economic section."
    )
  )
))

about_page <- fluidRow(column(
  1,
  box(
    title = "About", status = "primary",
    solidHeader = FALSE, collapsible = FALSE,
    tags$h3("Project overview"),
    tags$p(
      "La Seyne Business Explorer uses official INSEE SIRENE data to explore business establishments in La Seyne-sur-Mer through interactive maps and visualizations. The application was developed with R and Shiny."
    ),
    tags$h3("Technology"),
    tags$p(
      "The application is built with ",
      tags$a("R", href = "https://www.r-project.org/", target = "_blank", rel = "noopener noreferrer"),
      " and ",
      tags$a("Shiny.", href = "https://shiny.posit.co/", target = "_blank", rel = "noopener noreferrer"),
      " It uses ",
      tags$a("semantic.dashboard", href = "https://appsilon.github.io/semantic.dashboard/", target = "_blank", rel = "noopener noreferrer"),
      " for the interface, ",
      tags$a("Leaflet", href = "https://rstudio.github.io/leaflet/", target = "_blank", rel = "noopener noreferrer"),
      " for the aggregate map and ",
      tags$a("Plotly", href = "https://plotly.com/r/", target = "_blank", rel = "noopener noreferrer"),
      " for interactive charts. Package versions are recorded in renv.lock."
    ),
    tags$p(
      "The application builds on an earlier project developed by the author and was revised and extended with AI assistance."
    ),
    tags$h3("Author"),
    tags$div(
      class = "author-details",
      tags$strong("Dr. Marleen Dettmann"),
      tags$span("Demographer and data analyst"),
      tags$span(
        "Website: ",
        tags$a(
          "https://marleen-dettmann.de/", href = "https://marleen-dettmann.de/",
          target = "_blank", rel = "noopener noreferrer"
        )
      )
    ),
    tags$div(
      class = "author-mark",
      tags$img(
        src = "Logo_sRGB_WEB.jpg",
        alt = "Dr. Marleen Dettmann \u00b7 demographer and data analyst"
      )
    ),
    tags$h3("Limitations"),
    tags$p(
      "The analysis is based on an INSEE SIRENE snapshot from 17 November 2026. Historical figures reflect administrative records rather than a complete history of business activity. The map shows aggregated data, not individual establishment locations."
    ),
    tags$h3("Source code"),
    tags$p(tags$a(
      "GitHub repository", href = "https://github.com/marleendettmann/LaSeyne_Entreprises",
      target = "_blank", rel = "noopener noreferrer"
    ))
  )
))

source_footer <- function() {
  tags$footer(
    class = "source-footer",
    tags$p(
      "Sources: ",
      tags$a(
        "Insee, API Sirene 3.11 (SIRENE)",
        href = "https://www.insee.fr/fr/information/3591226",
        target = "_blank", rel = "noopener noreferrer"
      ),
      "; data reference date 17 November 2026. Geographic reference data: ",
      tags$a(
        "IGN ADMIN EXPRESS COG and BD TOPO",
        href = "https://geoservices.ign.fr/",
        target = "_blank", rel = "noopener noreferrer"
      ),
      ". Own calculations and spatial aggregation. Source data: ",
      tags$a(
        "Licence Ouverte 2.0 (Etalab)",
        href = "https://www.etalab.gouv.fr/licence-ouverte-open-licence/",
        target = "_blank", rel = "noopener noreferrer"
      ),
      "."
    )
  )
}

body <- dashboardBody(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css?v=20261121d")
  ),
  tabItems(
    tabItem(tabName = "dashboard", frow1, frow2, frow3, frow4, source_footer()),
    tabItem(tabName = "methodology", methodology_page, source_footer()),
    tabItem(tabName = "about", about_page, source_footer())
  )
)
ui <- dashboardPage(
  header, sidebar, body,
  title = "La Seyne Business Explorer \u00b7 Exploring business establishments in La Seyne-sur-Mer"
)
