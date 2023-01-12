#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#


library(shiny)
library(semantic.dashboard)
source("global.R")
#-----------------------------------------------------------------------------------------------------
header <- dashboardHeader(title = "La Seyne-sur-mer",  color="black", inverted = TRUE,
                          tags$li(tags$a(href = 'https://marleen-dettmann.de/',
                                    img(src = 'Logo_RGB_WEB_ohneSchrift.png',
                                        heigth="76.5px", width="202.5"))),show_menu_button=F)
sidebar <- dashboardSidebar(side = "left", size = "thin", color = "orange",inverted = FALSE,
        sidebarMenu(
            menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
            menuItem("Data Source", icon = icon("send",lib='glyphicon'), href = "https://public.opendatasoft.com/explore/dataset/economicref-france-sirene-v3/table/?disjunctive.libellecommuneetablissement&disjunctive.etatadministratifetablissement&disjunctive.activiteprincipaleetablissement&disjunctive.sectionetablissement&disjunctive.soussectionetablissement&disjunctive.divisionetablissement&disjunctive.groupeetablissement&disjunctive.classeetablissement&disjunctive.sectionunitelegale&disjunctive.soussectionunitelegale&disjunctive.classeunitelegale&disjunctive.naturejuridiqueunitelegale"),   
            menuItem("Source Code", href="https://github.com/marleendettmann/LaSeyne_Entreprises")
                                 ))
frow1<- fluidRow(
        valueBoxOutput("value1"),
        valueBoxOutput("value2"),
        valueBoxOutput("value3")
        )

frow2 <- fluidRow(column(1, align="center",
                box(title = "Companies by business activities",
                      status = "primary",
                      solidHeader = TRUE, 
                      collapsible = TRUE,
                      leafletOutput("mymap"),
                      selectInput(inputId = "select_Sectio", 
                      label = h3(""),choices = sectio))))
frow3 <- fluidRow(box(title = "Business Registrations / Closures",
                      status = "primary",
                      solidHeader = TRUE, 
                      collapsible = TRUE,
                      plotlyOutput("plot1", height = "347px"),
                      radioButtons(inputId = "select_RegClos", 
                      label = h3(" "),choices = c("Registrations", "Closures"),
                      selected = "Registrations")),
                  box(align="center",title = "Companies by registration year",
                      status = "primary",
                      solidHeader = TRUE, 
                      collapsible = TRUE,
                      plotlyOutput("plot2", height = "326px"),
                      sliderInput("select_yearcreatio", "", 2015, 2022, 2020, sep = "")))
                  
 frow4 <-  fluidRow(column(1, align="center",
         box(title = "Year of business registration",
                      status = "primary",
                      solidHeader = TRUE, 
                      collapsible = TRUE,
                      plotlyOutput("plot3", height = "300px"),      
                      sliderInput("select_year", "", 2015, 2022, 2020, sep = ""))))  
  
body <- dashboardBody(frow1, frow2, frow3, frow4)
ui <- dashboardPage(header, sidebar, body)  

