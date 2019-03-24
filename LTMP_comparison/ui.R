
# This is the user-interface definition of a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

library(shiny)
library("shinyWidgets")
#### SET UP ENVIRONMENT ####

library(dplyr)
library(ggplot2)
library(caret)
library(rgdal)

df=read.delim2("~/Dropbox/projects/BenthoBox_evaluation/data/summary_allcamp_090319.csv.csv", sep=",")

# Data extracted from REEFMON using this query:
# Select s.CRUISE_CODE, vs.SHELF, vs.REEF_NAME, vs.SITE_NO, vs.TRANSECT_NO, v.Filename,  v.Point_No, 
# c.KER_CODE AS obs, p.CATEGORY AS pred
# From V_IMAGE_CLASSIFICATION p, RM_VPOINT v, V_ALL_VPOINT_CODES_KER c, V_IN_SAMPLE vs, SAMPLE s
# Where p.Vpoint_Sid = v.Vpoint_Sid
# And V.Video_Code Is Not Null
# and v.video_code = c.video_code
# And v.TIME_SEC>0
# and vs.sample_id = v.sample_id
# AND vs.MASTER_SAMPLE_ID=s.MASTER_SAMPLE_ID


lset=read.delim2("~/Dropbox/projects/BenthoBox_evaluation/data/ker_codes.csv", sep=",")
lset=lset[,c('GROUP_DESC','KER_CODE')]
names(lset)[2]='LABEL'

## SUMARISE DATA
df=df%>%
  group_by(CRUISE_CODE, SHELF, REEF_NAME,SITE_NO,TRANSECT_NO,FILENAME)%>%
  tidyr::gather(key='METHOD',value='LABEL', OBS:PRED)%>%
  ungroup()%>%
  group_by(CRUISE_CODE, SHELF,REEF_NAME,SITE_NO,TRANSECT_NO,FILENAME,METHOD, LABEL)%>%
  summarise(n=n()) %>%
  mutate(COVER=n/sum(n))%>%
  ungroup()%>%
  dplyr::select(-n)%>%
  group_by(CRUISE_CODE, SHELF,REEF_NAME,SITE_NO,TRANSECT_NO,FILENAME,METHOD) %>%
  tidyr::spread(LABEL, COVER, fill=0)%>%
  tidyr::gather(key='LABEL',value='COVER',-c(CRUISE_CODE, SHELF,REEF_NAME,SITE_NO,TRANSECT_NO,FILENAME,METHOD))%>%
  ungroup()%>%
  group_by(CRUISE_CODE, SHELF,REEF_NAME,SITE_NO,TRANSECT_NO,METHOD, LABEL)%>%
  summarise(COVER=mean(COVER)*100)%>%
  tidyr::spread(METHOD,COVER)%>%
  mutate(error=abs(PRED-OBS))%>%
  group_by(CRUISE_CODE, SHELF,REEF_NAME,SITE_NO,TRANSECT_NO, LABEL)%>%
  tidyr::gather(key='METHOD',value='COVER', OBS:error)%>%
  inner_join(lset)%>%
  ungroup()


myui<- shinyUI(fluidPage(

  # Application title
  titlePanel("BenthoBox Evaluation"),

  # Sidebar with a slider input for number of bins
  sidebarLayout(
    sidebarPanel(
      sliderTextInput("cruise","Select Cruise Code" , 
                      choices = as.character(unique(df$CRUISE_CODE)), 
                                  selected = as.character(unique(df$CRUISE_CODE)[1:2]), #if you want any default values 
                                  animate = FALSE, grid = TRUE, 
                                  hide_min_max = FALSE, from_fixed = FALSE,
                                  to_fixed = FALSE, from_min = NULL, from_max = NULL, to_min = NULL,
                                  to_max = NULL, force_edges = FALSE, width = NULL, pre = NULL,
                                  post = NULL, dragRange = TRUE),
      sliderTextInput("group","Select Functional groups" , 
                      choices = as.character(unique(df$GROUP_DESC)), 
                      selected = as.character(unique(df$GROUP_DESC)), #if you want any default values 
                      animate = FALSE, grid = TRUE, 
                      hide_min_max = FALSE, from_fixed = FALSE,
                      to_fixed = FALSE, from_min = NULL, from_max = NULL, to_min = NULL,
                      to_max = NULL, force_edges = FALSE, width = NULL, pre = NULL,
                      post = NULL, dragRange = TRUE)
      
    ),

    # Show a plot of covers
    mainPanel(
      plotOutput("CoverPlot")
    )
  )
))


