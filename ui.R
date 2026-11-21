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
      "Methodology & Data", tabName = "methodology",
      icon = icon("database")
    ),
    menuItem(
      "About", tabName = "about",
      icon = icon("info circle")
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
      "The map contains only published 500 m aggregates. Statistical figures include all active establishments, independently of geocoding quality and spatial publication eligibility."
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
    title = "Active establishments by creation period", status = "primary",
    solidHeader = FALSE, collapsible = TRUE,
    tags$p(
      class = "chart-subtitle",
      "Creation periods of establishments active on 17 November 2026."
    ),
    plotlyOutput("plot3", height = "460px")
  )
))

methodology_page <- fluidRow(column(
  1,
  box(
    title = "Methodology & Data", status = "primary",
    solidHeader = FALSE, collapsible = FALSE,
    tags$h3("Data sources"),
    tags$p(
      "The application uses a validated local snapshot of the official INSEE SIRENE register for municipality code 83126. The reference and analysis date is 17 November 2026. The application makes no live SIRENE, BAN or IGN request when it starts."
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
      "The primary unit is the establishment. Current stock is defined from the administrative status valid on the analysis date. Administrative creations use the registered establishment creation date; closures and reopenings use documented status transitions. Period starts are not treated as creation dates. The value 1900 is treated as an unknown or undetermined creation date, not as an actual creation year."
    ),
    tags$h3("Geographic coverage"),
    tags$p(
      "Statistical totals cover all 14,213 active establishments assigned to La Seyne-sur-Mer by the official municipality code. The internal spatial basis contains 5,214 address-exact establishments with unrestricted diffusion at both establishment and legal-unit level. The public map publishes 4,272 of these records in 500 metre grid aggregates; no individual establishment locations are displayed."
    ),
    tags$div(
      class = "aggregation-explainer",
      tags$div(
        class = "aggregation-step",
        tags$div(class = "synthetic-points", lapply(seq_len(7), function(i) tags$span(class = paste0("point point-", i)))),
        tags$strong("Individual records"),
        tags$p("Synthetic example points used only to explain the method.")
      ),
      tags$div(class = "aggregation-arrow", icon("arrow right")),
      tags$div(
        class = "aggregation-step",
        tags$div(class = "synthetic-grid", lapply(seq_len(4), function(i) tags$span(class = paste0("grid-cell grid-cell-", i)))),
        tags$strong("Spatial aggregation"),
        tags$p("Records are counted within a fixed 500 m grid cell and NAF section.")
      ),
      tags$div(class = "aggregation-arrow", icon("arrow right")),
      tags$div(
        class = "aggregation-step",
        tags$div(class = "synthetic-published-circle", "7"),
        tags$strong("Published statistics"),
        tags$p("Aggregates are shown only at n \u2265 5; smaller groups are excluded spatially.")
      )
    ),
    tags$h3("Data quality"),
    plotlyOutput("quality_sankey", height = "330px"),
    tags$p(
      "The flow chart separates the complete active stock, the address-exact O/O aggregation basis, the spatially published aggregates and the records excluded by the minimum-count rule. Less precise, unmatched and restricted records remain included in non-spatial statistical totals."
    ),
    tags$p(
      "The spatial table contains only 286 cell-section combinations with at least five establishments. Public cell totals are calculated exclusively from these released combinations; no uncut cell totals or suppressed residual categories are published."
    ),
    tags$h3("Limitations"),
    tags$p(
      "Historical figures are municipality-wide retrospective reconstructions from the current register snapshot and may change after retrospective corrections. They are not broken down by economic section or geography. The year 2026 is incomplete through 17 November. Spatial coverage is lower than the total establishment stock because diffusion status, geocoding quality and the minimum-count rule are respected."
    ),
    tags$p(
      "The creation-period chart is a municipality-wide aggregation of the 14,213 establishments active on 17 November 2026. It contains seven fixed cohorts and cannot be combined with economic section, map grid, geocoding quality or another establishment attribute."
    ),
    tags$p(
      "The spatial publication threshold of five applies to grid-cell and economic-section combinations. It is not presented as a universal rule for every municipality-wide statistic. A small number of early annual closure and reopening counts are retained because they contain no sector, location or establishment attribute and are needed for an unbroken retrospective series."
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
      "La Seyne Business Explorer is a public portfolio project for exploring the active establishment stock and administrative register events in La Seyne-sur-Mer, France."
    ),
    tags$h3("Technology"),
    tags$p(
      "Built with R and Shiny, semantic.dashboard for the interface, Leaflet for the privacy-aware aggregate map, and Plotly and ggplot2 for charts. Reproducible spatial preprocessing uses sf outside the public app runtime."
    ),
    tags$h3("Author"),
    tags$p(
      "Dr. Marleen Dettmann, demographer and data analyst. ",
      tags$a(
        "marleen-dettmann.de", href = "https://marleen-dettmann.de/",
        target = "_blank", rel = "noopener noreferrer"
      )
    ),
    tags$div(
      class = "author-mark",
      tags$img(
        src = "Logo_sRGB_WEB.jpg",
        alt = "Dr. Marleen Dettmann \u00b7 demographer and data analyst"
      )
    ),
    tags$h3("Source code"),
    tags$p(tags$a(
      "GitHub repository", href = "https://github.com/marleendettmann/LaSeyne_Entreprises",
      target = "_blank", rel = "noopener noreferrer"
    ))
  )
))

body <- dashboardBody(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css?v=20261121b")
  ),
  tabItems(
    tabItem(tabName = "dashboard", frow1, frow2, frow3, frow4),
    tabItem(tabName = "methodology", methodology_page),
    tabItem(tabName = "about", about_page)
  )
)
ui <- dashboardPage(
  header, sidebar, body,
  title = "La Seyne Business Explorer \u00b7 Exploring business establishments in La Seyne-sur-Mer"
)
