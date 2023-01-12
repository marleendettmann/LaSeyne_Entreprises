library(shiny)
library(tidyverse)
library(ggplot2)
library(stringr)
library(plotly)
library(scales)
library(leaflet)
library(semantic.dashboard)

dat<-read.table("dataseed-sirene_mde.csv", sep=";", header=T)
my.col <- c("69b3a2", "75002B")

dat0 <- subset(dat, etatadminis=="Actif"  & is.na(yearfermetu))
sectio <- unique(dat0$sectionetab)

#---------------------------
my.tab01 <- as.data.frame(table(dat$yearcreatio))
names(my.tab01) <- c("Year", "Registrations")
my.tab02 <- as.data.frame(table(dat$yearfermetu))
names(my.tab02) <- c("Year", "Closures")
my.tab0 <- merge(my.tab01, my.tab02, by="Year")
my.tab0<-pivot_longer(
        data=my.tab0, # identify the data
        cols=c(Registrations,Closures), # select the columns we want to stretch
        names_to="RegClos", # name a new column that will be home to the pivoted column titles (this will have time1,time2, and time3 in it),
        values_to="value" # name a new column that will be home to the pivoted row values. This will be the sequences of numbers
)
my.tab0$Year <- as.integer(as.character(my.tab0$Year))
my.tab0 <- subset(my.tab0, Year>=1985 & Year<2023)
#-----------------------------------------------------------------------------------------------------
my.tab1<- subset(dat, yearcreatio>=2015 & yearcreatio<2023) %>%
        group_by(yearcreatio,etatadminis) %>%
        count()
my.tab1$etatadminis<- factor(my.tab1$etatadminis, levels=c("Actif", "Fermé"), labels=c("Active", "Closed"))
#-----------------------------------------------------------------------------------------------------

my.tab2<- subset(dat, yearfermetu>=2010 & yearfermetu<2023) %>%
        group_by(yearfermetu,cat_duree) %>%
        count()

my.tab2$cat_duree <- factor(
        my.tab2$cat_duree, levels=c("< 1 year",  "1-2 years","2-5 years", "5-10 years", 
                                    "10-20 years",  "20 years and more"))
#-----------------------------------------------------------------------------------------------------

my.tab3<- subset(dat, yearcreatio>=2010 & yearcreatio<2023)  %>%
        group_by(yearcreatio,sectionetab) %>%
        count()
sectio<- unique(my.tab3$sectionetab)


my.tab4 <- data.frame(my.tab3)
years <- c(2015:2022)

