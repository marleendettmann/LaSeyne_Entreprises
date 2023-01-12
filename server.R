#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
library(shiny)
library(semantic.dashboard)
source("global.R")

server <- function(input,output){
             #creating the valueBoxOutput content
        output$value1 <- renderValueBox({
                valueBox(subtitle="Companies",
                        formatC(dim(dat0)[[1]], format="d", big.mark=','),
                        
                        color = "orange", size="tiny")
        })
        output$value2 <- renderValueBox({ 
                valueBox("Registrations in 2022",
                        formatC(subset(my.tab0, RegClos=="Registrations" & Year==2022)$value, format="d", big.mark=','),
                        
                        color = "orange", size="tiny")
        })
        output$value3 <- renderValueBox({
                valueBox("Closures in 2022",
                        formatC(subset(my.tab0, RegClos=="Closures" & Year==2022)$value, format="d", big.mark=','),
                        
                        color = "orange", size="tiny")  
        })
        
        
# Define server logic required to draw a Leaflet map 
## 1. MYMAP
               output$mymap <- renderLeaflet({
                filtered <- 
                        dat0 %>% 
                        dplyr::filter(sectionetab %in% input$select_Sectio)
                filtered %>%
                leaflet() %>%
                        addTiles() %>%
                        addMarkers(lng = ~Lon, lat = ~Lat, clusterOptions = markerClusterOptions())
        })
# Define server logic required to draw a ggplotly: AREA PLot 
## 2. PLOT1    
         output$plot1<-renderPlotly({
               data_filter1 <- filter(my.tab0, RegClos %in% input$select_RegClos)
                ggplot(data=data_filter1, aes(x=Year, y=value)) +
                         geom_area(fill="#e08800", alpha=0.8) +
                         geom_line(color="#e08800") +
                        scale_y_continuous(labels = comma_format(big.mark = ",",
                                                                 decimal.mark = ".", suffix = " "))+
                         ylab(input$select_RegClos) +xlab("Year") +
                        theme_minimal(base_size=12)
         })
# Define server logic required to draw a Barplot
## 3. PLOT2       
         output$plot2<-renderPlotly({ 
                 data_filter2 <- filter(my.tab1, yearcreatio %in% input$select_yearcreatio)
                         ggplot(data=data_filter2,
                                aes(x=etatadminis,y=n, fill=etatadminis))+
                                 geom_bar(stat = "identity")+
                                  scale_fill_manual("Status", values = c("#9b9eb4", "#aebe39"))+
                                 labs(x = "Status", 
                                      y = "Registrations",
                                     title = "") + ggtitle(input$select_yearcreatio) +
                                 scale_y_continuous(labels = comma_format(big.mark = ",",
                                                                         decimal.mark = ".", suffix = " "))+
                                 theme_minimal(base_size=12) +
                                 theme(legend.position="none")
                 })
# Define server logic required to draw a ggplotly: AREA PLot 
#server logic required to draw a ggplotly: Lolliplot
## 4. PLOT3 
output$plot3 <- renderPlotly({
                data_filter4 <- filter(my.tab4, yearcreatio %in% input$select_year)
                my.year <- input$select_year
                 ggplot(data=data_filter4,
                        aes(x=sectionetab, y=n)) +
                        geom_segment(aes(x=sectionetab, xend=sectionetab, y=0, yend=n))+ 
                        #ylab("Nombre de fermetures d'entreprise \nà partir de 1985") +xlab("Date de fermeture de l'entreprise") +
                        geom_point(size=2, alpha=1, shape=21, stroke=1)+
                        coord_flip() +
                       xlab("Companies by Activities") +ylab("Registration") +
                        theme_minimal(base_size=12)+
                        #theme(axis.text.y=element_blank())+
                        theme(legend.position="none") + 
                        ggtitle(paste(my.year))
        })
}