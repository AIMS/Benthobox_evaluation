
# This is the server logic for a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

library(shiny)
library(dplyr)
library(ggplot2)

myserver<-shinyServer(function(input, output) {

    
    ##SUMARISE DATA BASED ON SLIDER INPUT
    
    dat<- reactive({dfs<- df%>%
      filter(CRUISE_CODE %in% input$cruise,METHOD %in% c('OBS','PRED'), GROUP_DESC %in% input$group)
    print(dfs)
      dfs})
    ##PLOT DATA
    
    output$CoverPlot<-renderPlot({
      ggplot(dat(), aes(x=LABEL, y=COVER, fill=METHOD))+
      stat_summary(fun.data="mean_cl_boot", geom="errorbar",position = "dodge",size=0.5, width=0.3)+
      stat_summary(fun.data="mean_cl_boot", geom="bar", position = "dodge",aes(fill=METHOD))+
      facet_grid(SHELF~GROUP_DESC,scales = "free", space="free_x")+
      theme(axis.text=element_text(angle=45, hjust=1))
    })

})
