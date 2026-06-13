####Solar Angles Function####

if(!require(xml2)){
  install.packages("xml2")
}

if(!require(terra)){
  install.packages("terra")
}

library(xml2)
library(terra)

## Pulls solar angle data (azimuth and zenith) from provided .xml file and creates two SpatRaster objects: 
## one for georeferenced zenith data and one for georeferenced azimuth data, both in .xml-provided projection/CRS
solar<-function(X){
  tmpxml<-read_xml(X)
  chld<-xml_children(tmpxml)
  geo_info<-xml_children(chld[2])
  GC<-xml_children(geo_info[1])
  EPSG<-xml_text(GC[2])
  BB<-xml_children(GC[8])
  XLM<-xml_integer(BB[1])
  YLM<-xml_integer(BB[2])
  angle<-xml_children(geo_info[2])
  sun<-xml_children(angle[1])
  Zen<-xml_children(sun[1])
  Azm<-xml_children(sun[2])
  COL_STEP_ZEN<-xml_integer(Zen[1])
  ROW_STEP_ZEN<-xml_integer(Zen[2])
  COL_STEP_Azm<-xml_integer(Azm[1])
  ROW_STEP_Azm<-xml_integer(Azm[2])
  Zen_vals<-xml_children(Zen[3])
  Zen_txt<-xml_text(Zen_vals)
  Zen_grid<-read.csv(textConnection(Zen_txt), sep=" ", header=FALSE)
  Azm_vals<-xml_children(Azm[3])
  Azm_txt<-xml_text(Azm_vals)
  Azm_grid<-read.csv(textConnection(Azm_txt), sep=" ", header=FALSE)
  xmn_a<-XLM
  xmx_a<-XLM+(nrow(Azm_grid)*ROW_STEP_Azm)
  ymx_a<-YLM
  ymn_a<-YLM-(ncol(Azm_grid)*COL_STEP_Azm)
  AZM_rast<-rast(nrows=nrow(Azm_grid), ncols=ncol(Azm_grid), nlyrs=1,
                  ymax=ymx_a, ymin=ymn_a, xmax=xmx_a, xmin=xmn_a, crs=EPSG, vals=as.matrix(Azm_grid), names="Solar_Azimuth")
  xmn_z<-XLM
  xmx_z<-XLM+(nrow(Zen_grid)*ROW_STEP_ZEN)
  ymx_z<-YLM
  ymn_z<-YLM-(ncol(Zen_grid)*COL_STEP_ZEN)
  ZEN_rast<-rast(nrows=nrow(Zen_grid), ncols=ncol(Zen_grid), nlyrs=1,
                  ymax=ymx_z, ymin=ymn_z, xmax=xmx_z, xmin=xmn_z, crs=EPSG, vals=as.matrix(Zen_grid), names="Solar_Zenith")
  return(list(Zenith=ZEN_rast, Azimuth=AZM_rast))
}
