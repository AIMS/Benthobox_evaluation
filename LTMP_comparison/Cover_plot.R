# install.packages('RJDBC')
# install.packages("rJava")
rm(list=ls())
#### SET UP ENVIRONMENT ####

library(dplyr)
library(ggplot2)
library(caret)
library(rgdal)
library(rgdal)


outdir="/media/pearl/monshare/A_Indiv/Manu/BenthoBox_evaluation/fig"

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
# df=df%>%
#   group_by(CRUISE_CODE, SHELF, REEF_NAME,SITE_NO,TRANSECT_NO,FILENAME)%>%
#   tidyr::gather(key='METHOD',value='LABEL', OBS:PRED)%>%
#   ungroup()%>%
#   group_by(CRUISE_CODE, SHELF,REEF_NAME,SITE_NO,TRANSECT_NO,FILENAME,METHOD, LABEL)%>%
#   summarise(n=n()) %>%
#   mutate(COVER=n/sum(n))%>%
#   ungroup()%>%
#   dplyr::select(-n)%>%
#   group_by(CRUISE_CODE, SHELF,REEF_NAME,SITE_NO,TRANSECT_NO,FILENAME,METHOD) %>%
#   tidyr::spread(LABEL, COVER, fill=0)%>%
#   tidyr::gather(key='LABEL',value='COVER',-c(CRUISE_CODE, SHELF,REEF_NAME,SITE_NO,TRANSECT_NO,FILENAME,METHOD))%>%
#   ungroup()%>%
#   group_by(CRUISE_CODE, SHELF,REEF_NAME,SITE_NO,TRANSECT_NO,METHOD, LABEL)%>%
#   summarise(COVER=mean(COVER))%>%
#   tidyr::spread(METHOD,COVER)%>%
#   mutate(error=abs(PRED-OBS))%>%
#   group_by(CRUISE_CODE, SHELF,REEF_NAME,SITE_NO,TRANSECT_NO, LABEL)%>%
#   tidyr::gather(key='METHOD',value='COVER', OBS:error)%>%
#   inner_join(lset)%>%
#   ungroup()

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


### SUBSET DATA FOR PLOTTING
df_sub<- df%>%
  filter(METHOD %in% c('OBS','PRED'))
df_sub <- droplevels(df_sub)
##PLOT DATA

p<-ggplot(df_sub, aes(x=LABEL, y=COVER, fill=METHOD))+
  stat_summary(fun.data="mean_cl_boot", geom="errorbar",position = "dodge",size=0.5, width=0.3)+
  stat_summary(fun.data="mean_cl_boot", geom="bar", position = "dodge",aes(fill=METHOD))+
  facet_grid(SHELF~GROUP_DESC,scales = "free", space="free_x")+
  theme_bw()+
  theme(axis.text=element_text(angle=45, hjust=1),
        strip.background =element_rect(fill="dark grey"),
        strip.text = element_text(colour = 'white', angle=90,hjust=0.5))
p


### MAP ERROR
gbr=readOGR("/Users/uqmgonz1/OneDrive - Australian Institute of Marine Science/GIS_Datasets/GBRMPA/GBR_DRY_REEF.shp")
gbr.f=fortify(gbr)

df.map=df %>%
  filter(GROUP_CODE=="HC")%>%
  group_by(A_SECTOR, SHELF,REEF_NAME)%>%
  summarise(lat=mean(lat), lng=mean(lng), error=mean(error))

map.error=ggplot()+geom_polygon(data = subset(gbr.f,lat < max(df.map$lat+0.1)), 
                                aes(x = long, y = lat, group = group),
                                color = 'gray', fill = 'darkgrey', size = .2)
map.error<-map.error+
  geom_point(data=df.map, aes(x=lng, y=lat,size=error), color="red", alpha=0.3)+theme_bw()+
  labs(title="Spatial Distribution of the annotation error for Hard Corals")
map.error
ggsave(filename = file.path(outdir,"HC_errormap.png"),map.error)

