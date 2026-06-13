####Sentinel Topographic Corrections####
library(RStoolbox)
library(terra)
library(tidyverse)
library(raster)

# Notes -------------------------------------------------------------------

## ALL OUTPUT FILES WILL MAINTAIN THEIR RAW PROJECTION/RESOLUTION (EXAMPLE: EPSG:32610 - WGS 84 / UTM zone 10N AT 20M RESOLUTION)

## The following abbreviations will be used to name variables based on the growing season period that the variable relates to
## BUD  = Bud Break;          Example Date: May 17, 2023
## LEAF = Leaf Expansion;     Example Date: June 24, 2023
## MAXP = Max Photosynthesis; Example Date: August 3, 2023
## SENC = Leaf Senescence;    Example Date: October 29, 2023 

## In addition to all the necessary inputs, you will need a folder named Outputs with the following sub-folders:
# Classification_Model
# CorrectedMosaics
# Intermediate GeoTiffs
# Maps and Figures
# NDVI_Corr_Mosaics
# Solar Angles
# VegMaskedRasters

# Inputs ------------------------------------------------------------------

# File path for outputs folder. Commonly used directory, so will shorten pasted file paths below
path<-"C:/ExampleFilepath/Outputs"

# Reading in rasters. These are the multi-(13) banded GeoTiff outputs of the Preprocessing_Preparation script
# Rast converts the GeoTiffs into SpatRaster objects (maintaining extent and dimensions)
BUD<-rast(paste(path, "Intermediate GeoTiffs/BUD_t1.tif", sep="/"))
LEAF<-rast(paste(path, "Intermediate GeoTiffs/LEAF_t1.tif", sep="/"))
MAXP<-rast(paste(path, "Intermediate GeoTiffs/MAXP_t1.tif", sep="/"))
SENC<-rast(paste(path, "Intermediate GeoTiffs/SENC_t1.tif", sep="/"))

# Reading in post-processed solar angle rasters
# These are the azimuth and zenith rasters for each growing season period that were outputs of the Preprocessing_Preparation script
# Rast converts the GeoTiffs into SpatRaster objects (maintaining extent and dimensions)
BUD_A<-rast(paste(path, "Solar Angles/ BUD_t1_Azimuth.tif", sep="/"))
BUD_Z<-rast(paste(path, "Solar Angles/ BUD_t1_Zenith.tif", sep="/"))
LEAF_A<-rast(paste(path, "Solar Angles/ LEAF_t1_Azimuth.tif", sep="/"))
LEAF_Z<-rast(paste(path, "Solar Angles/ LEAF_t1_Zenith.tif", sep="/"))
MAXP_A<-rast(paste(path, "Solar Angles/ MAXP_t1_Azimuth.tif", sep="/"))
MAXP_Z<-rast(paste(path, "Solar Angles/ MAXP_t1_Zenith.tif", sep="/"))
SENC_A<-rast(paste(path, "Solar Angles/ SENC_t1_Azimuth.tif", sep="/"))
SENC_Z<-rast(paste(path, "Solar Angles/ SENC_t1_Zenith.tif", sep="/"))

# Converts raw DEM to SpatRaster object
raw_dem<-rast("C:/ExampleFilepath/Prepped Data/10m_MRW_DEM.tif")

# Isolating Scene Classification Images (SCI)
# A folder named Scene_Classification_Images contains the Sentinel-2 Scene Classification Images for each growing season period, in .jp2 format
# Ensure that the order of files is BUD, LEAF, MAXP, SENC
SCI<-list.files("C:/ExampleFilepath/Prepped Data/Scene_Classification_Images/", pattern="*.jp2", full.names=TRUE)

# Code --------------------------------------------------------------------

## READING IN OF FILES

# Names the 13 bands in each SpatRaster object
names(BUD)<- c("AOT_20m","B01_20m","B02_20m","B03_20m","B04_20m","B05_20m",
               "B06_20m","B07_20m","B11_20m","B12_20m","B8A_20m","SCL_20m","WVP_20m")
names(LEAF)<- c("AOT_20m","B01_20m","B02_20m","B03_20m","B04_20m","B05_20m",
                "B06_20m","B07_20m","B11_20m","B12_20m","B8A_20m","SCL_20m","WVP_20m")
names(MAXP)<- c("AOT_20m","B01_20m","B02_20m","B03_20m","B04_20m","B05_20m",
                "B06_20m","B07_20m","B11_20m","B12_20m","B8A_20m","SCL_20m","WVP_20m")
names(SENC)<- c("AOT_20m","B01_20m","B02_20m","B03_20m","B04_20m","B05_20m",
                "B06_20m","B07_20m","B11_20m","B12_20m","B8A_20m","SCL_20m","WVP_20m")

# Names the band in each solar angle SpatRaster object
names(BUD_A) <- "azimuth"
names(BUD_Z) <- "zenith"
names(LEAF_A) <- "azimuth"
names(LEAF_Z) <- "zenith"
names(MAXP_A) <- "azimuth"
names(MAXP_Z) <- "zenith"
names(SENC_A) <- "azimuth"
names(SENC_Z) <- "zenith"

# DEM SpatRaster object reprojected and resampled to the Intermediate GeoTiff (Sentinel) specs
# DEM SpatRaster object is then converted into RasterLayer object
# terrain function is used to create 2 RasterLayers: one for aspect (in radians) and one for slope (in radians) 
# RasterStack is then created from the 3 RasterLayers, with columns: elevation, aspect, and slope
# Finally, RasterStack is converted into a GeoTiff
res_dem<-project(raw_dem, BUD, method = "bilinear")
elevation_dem<-raster(res_dem)
aspect_dem<-terrain(elevation_dem, opt="aspect", unit="radians")
slope_rad<-terrain(elevation_dem, opt="slope", unit="radians")
stacked<-stack(elevation_dem,aspect_dem, slope_rad)
writeRaster(stacked, paste(path, "SlopeAspectDEM.tif", sep="/"), overwrite=TRUE, datatype="FLT4S")

# The previously created raster containing elevation, aspect, and slope data is converted back into a SpatRaster object
# and then projected/resampled once again to Intermediate GeoTiff (Sentinel) specs
# Best practice is to have the DEM already projected beforehand
# The code projection is more meant to account for any projection differences between terrain and rast packages
# Elevation data is also combed for any negative values, which are then changed to NoData
raw_TOPO<-rast(paste(path, "SlopeAspectDEM.tif", sep="/"))
names(raw_TOPO)<- c("elev","aspect","slope")
TOPO<-project(raw_TOPO, BUD, method = "bilinear")
TOPO[TOPO[[1]]<=0]<-NA


## VEGETATION MASKING

# For each of the scene classification images (one per growing season period), the .jp2 file is converted to a SpatRaster object
BUDM<-rast(SCI[1])
LEAFM<-rast(SCI[2])
MAXPM<-rast(SCI[3])
SENCM<-rast(SCI[4])

# Non-vegetation classes set to NA
# For each scene classification image, only keeps spatial data for vegetated land cover (Sentinel 2 classification = 4).
BUDM[BUDM!=4]<-NA
LEAFM[LEAFM!=4]<-NA
MAXPM[MAXPM!=4]<-NA
SENCM[SENCM!=4]<-NA


# Masking of the spectral imagery to vegetated areas
# For each 13-banded SpatRaster object, only keeps spatial data for MAXP vegetated land cover and only keeps bands B01-B07, B8A, B11-B12 
# (so only 10 bands now)
# MAXP used for mask since that is when vegetated land cover is at its greatest extent
# Using a mask from too early or too late in the growing season could cause omission errors.
BUD_veg<-mask(BUD[[c(2:11)]], MAXPM)
LEAF_veg<-mask(LEAF[[c(2:11)]], MAXPM)
MAXP_veg<-mask(MAXP[[c(2:11)]], MAXPM)
SENC_veg<-mask(SENC[[c(2:11)]], MAXPM)

# Writing rasters of the masked 10-banded SpatRaster objects for each growing season month
# Puts vegetated mask rasters in VegMaskedRasters folder
writeRaster(BUD_veg, paste(path, "VegMaskedRasters/BUD_masked.tif", sep="/"), overwrite=TRUE)
writeRaster(LEAF_veg, paste(path, "VegMaskedRasters/LEAF_masked.tif", sep="/"), overwrite=TRUE)
writeRaster(MAXP_veg, paste(path, "VegMaskedRasters/MAXP_masked.tif", sep="/"), overwrite=TRUE)
writeRaster(SENC_veg, paste(path, "VegMaskedRasters/SENC_masked.tif", sep="/"), overwrite=TRUE)

# Reading rasters back in 
BUD_vegmask<-rast(paste(path, "VegMaskedRasters/BUD_masked.tif", sep="/"))
LEAF_vegmask<-rast(paste(path, "VegMaskedRasters/LEAF_masked.tif", sep="/"))
MAXP_vegmask<-rast(paste(path, "VegMaskedRasters/MAXP_masked.tif", sep="/"))
SENC_vegmask<-rast(paste(path, "VegMaskedRasters/SENC_masked.tif", sep="/"))


## RANDOM SAMPLING FOR LINEAR MODELING

# Resamples SlopeAspectDEM to same extent/resolution as vegetated masks (any of the vegetation masks would work here)
# Do not need to mask SlopeAspectDEM, because during sampling will use na.rm=TRUE which will omit pixels where ANY layer=NA
res_TOPO<-resample(TOPO, SENC_vegmask)

# For each growing season period creates a SpatRaster object that includes:
# the 10 bands, SlopeAspectDEM, zenith solar angles, and azimuth solar angles
# Then collects a sample of points within each SpatRaster to be used for topographic correction
# These sampled points will only be from non-null points of the vegetated mask because na.rm is set to TRUE
BUD_topo<-rast(list(BUD_vegmask, res_TOPO, BUD_Z, BUD_A))
BUD_samp<-spatSample(x=BUD_topo, size=1000, xy=TRUE, as.df=TRUE, na.rm=TRUE)

LEAF_topo<-rast(list(LEAF_vegmask, res_TOPO, LEAF_Z, LEAF_A))
LEAF_samp<-spatSample(x=LEAF_topo, size=1000, xy=TRUE, as.df=TRUE, na.rm=TRUE)

MAXP_topo<-rast(list(MAXP_vegmask, res_TOPO, MAXP_Z, MAXP_A))
MAXP_samp<-spatSample(x=MAXP_topo, size=1000, xy=TRUE, as.df=TRUE, na.rm=TRUE)

SENC_topo<-rast(list(SENC_vegmask, res_TOPO,  SENC_Z, SENC_A))
SENC_samp<-spatSample(x=SENC_topo, size=1000, xy=TRUE, as.df=TRUE, na.rm=TRUE)


## LINEAR MODELING

# Custom function to run a linear model for each raster band that relates brightness of band to topographic position/solar angles
# For each sampled point of each band, the linear coefficient values are calculated and stored in dataframes
# Each of the sets of calculated linear coefficient values are then averaged to determine each averaged linear coefficient of each raster band
# The averaged linear coefficients (stored in dataframes) can then be applied out over their whole respective raster later in the script
# The linear model is based off the Statistical Empirical Topographic Correction formula mentioned in (Füreder, 2010)
# Füreder, P. (2010). Topographic correction of satellite images for improved LULC classification in alpine areas. 
# Grazer Schriften Der Geographie Und Raumforschung, 45, 187–194.
# The outputs of these functions will be used in the later topographic correction formulas. These functions will be called later in the script
cos_i<-function(azm, zen, slope, aspect){
  out<-cos(slope)*cos(zen)+sin(slope)*sin(zen)*cos(azm - aspect) 
  return(out)
}

TOPO_lm<-function(df){
  df[,"X"]<-cos_i(azm=df$azimuth, 
                  zen=df$zenith, 
                  slope=df$slope, 
                  aspect=df$aspect)  
  models <- df %>% 
    pivot_longer(
      cols = c(3:12),
      names_to = "y_name",
      values_to = "y_value"
    ) %>% 
    split(.$y_name) %>% 
    map(~lm(y_value ~ X, data = .)) %>% 
    tibble(
      dvsub = names(.),
      untidied = .
    ) %>%
    mutate(tidy = map(untidied, broom::tidy)) %>%
    unnest(tidy) %>% 
    pivot_wider(id_cols="dvsub",
                names_from="term",
                values_from="estimate")
  out<-as.data.frame(models)
  colnames(out)<-c("band", "Beta_0", "Beta_1")
  return(out)
}

L_bar_fxn<-function(df){
  df2<-df %>% summarize(across(.cols = c(3:14), mean)) %>% 
    pivot_longer(cols=everything(),
                 names_to="band",
                 values_to="intensity")
  out<-as.data.frame(df2)
  return(out)
}


## APPLYING LINEAR MODEL TO RANDOM SAMPLE

# Creates a list of the sample points for each growing season period (see "RANDOM SAMPLING FOR LINEAR MODELING" above for more information)
# Then writes that list to an RDS file (R Data Serialization) and then immediately reads the file back
TOPO_LM_VALS_for_rds<-list(BUD_samp, LEAF_samp, MAXP_samp, SENC_samp)
write_rds(TOPO_LM_VALS_for_rds, paste(path, "Classification_Model/TOPO_LM_LIST.rds", sep="/"))
TOPO_LM_VALS<-readRDS(paste(path, "Classification_Model/TOPO_LM_LIST.rds", sep="/"))

# The topographic correction functions (that produce the averaged linear model coefficients) 
# are called for each set of sampled points that correspond to each of the growing season periods
# (see "LINEAR MODELING" above for more information)
# The coefficient outputs are saved under their respective names as unnested dataframes
TOPO_CORR<-lapply(TOPO_LM_VALS, TOPO_lm)
names(TOPO_CORR)<-c("BUD", "LEAF", "MAXP", "SENC")
TOPO_MEAN<-lapply(TOPO_LM_VALS, L_bar_fxn)
names(TOPO_MEAN)<-c("BUD", "LEAF", "MAXP", "SENC")
CORR<-unnest(tibble(SCENE=names(TOPO_CORR),TOPO_CORR), cols=c(TOPO_CORR))
MEAN<-unnest(tibble(SCENE=names(TOPO_MEAN),TOPO_MEAN), cols=c(TOPO_MEAN))

CORRECTION_DF<-merge(CORR, MEAN, by=c("SCENE", "band"))


## APPLYING CORRECTION TO RASTERS

# With the averaged linear model coefficients already found, 
# each spectral imagery raster can now be entirely corrected using the formula based off (Füreder, 2010).   
RAST_CORR<-function(SOLAR){
  azm<-SOLAR[["azimuth"]] 
  zen<-SOLAR[["zenith"]] 
  slope<-SOLAR[["slope"]]
  aspect<-SOLAR[["aspect"]]
  cosI<-cos(slope)*cos(zen)+sin(slope)*sin(zen)*cos(azm - aspect)
  return(cosI)
}

BUD_CORR<-subset(CORRECTION_DF, SCENE=="BUD")
BUD_COS<-app(BUD_topo, function(i, ff) ff(i),ff=RAST_CORR,cores=12)
BUD_FINAL<-BUD_vegmask - BUD_COS*BUD_CORR$Beta_1 - BUD_CORR$Beta_0+ BUD_CORR$intensity
writeRaster(BUD_FINAL, paste(path, "CorrectedMosaics/BUD_Scene_TopoCorr.tif", sep="/"), overwrite=TRUE)

LEAF_CORR<-subset(CORRECTION_DF, SCENE=="LEAF")
LEAF_COS<-app(LEAF_topo, function(i, ff) ff(i), ff=RAST_CORR, cores=12)
LEAF_FINAL<-LEAF_vegmask - LEAF_COS*LEAF_CORR$Beta_1 - LEAF_CORR$Beta_0 + LEAF_CORR$intensity
writeRaster(LEAF_FINAL, paste(path, "CorrectedMosaics/LEAF_Scene_TopoCorr.tif", sep = "/"), overwrite=TRUE)

MAXP_CORR<-subset(CORRECTION_DF, SCENE=="MAXP")
MAXP_COS<-app(MAXP_topo, function(i, ff) ff(i), ff=RAST_CORR, cores=12)
MAXP_FINAL<-MAXP_vegmask - MAXP_COS*MAXP_CORR$Beta_1 - MAXP_CORR$Beta_0 + MAXP_CORR$intensity
writeRaster(MAXP_FINAL, paste(path, "CorrectedMosaics/MAXP_Scene_TopoCorr.tif", sep = "/"), overwrite=TRUE)

SENC_CORR<-subset(CORRECTION_DF, SCENE=="SENC")
SENC_COS<-app(SENC_topo, function(i, ff) ff(i), ff=RAST_CORR, cores=12)
SENC_FINAL<-SENC_vegmask - SENC_COS*SENC_CORR$Beta_1 - SENC_CORR$Beta_0 + SENC_CORR$intensity
writeRaster(SENC_FINAL, paste(path, "CorrectedMosaics/SENC_Scene_TopoCorr.tif", sep = "/"), overwrite=TRUE)


## ADDING NDVI BAND

# Calculates and adds NDVI band to each growing season period topographically-corrected raster
# Utilizes the formula: Band 8A - Band 4 / Band 8A + Band 4
TOPO_BUD<-rast(paste(path, "CorrectedMosaics/BUD_Scene_TopoCorr.tif", sep="/"))
TOPO_BUD[["NDVI"]]<-(TOPO_BUD$B8A_20m-TOPO_BUD$B04_20m)/(TOPO_BUD$B8A_20m+TOPO_BUD$B04_20m)
writeRaster(TOPO_BUD, paste(path, "NDVI_Corr_Mosaics/BUD_Scene_TopoCorrwNDVI.tif", sep="/"), overwrite=TRUE)

TOPO_LEAF<-rast(paste(path, "CorrectedMosaics/LEAF_Scene_TopoCorr.tif", sep="/"))
TOPO_LEAF[["NDVI"]]<-(TOPO_LEAF$B8A_20m-TOPO_LEAF$B04_20m)/(TOPO_LEAF$B8A_20m+TOPO_LEAF$B04_20m)
writeRaster(TOPO_LEAF, paste(path, "NDVI_Corr_Mosaics/LEAF_Scene_TopoCorrwNDVI.tif", sep="/"), overwrite=TRUE)

TOPO_MAXP<-rast(paste(path, "CorrectedMosaics/MAXP_Scene_TopoCorr.tif", sep="/"))
TOPO_MAXP[["NDVI"]]<-(TOPO_MAXP$B8A_20m-TOPO_MAXP$B04_20m)/(TOPO_MAXP$B8A_20m+TOPO_MAXP$B04_20m)
writeRaster(TOPO_MAXP, paste(path, "NDVI_Corr_Mosaics/MAXP_Scene_TopoCorrwNDVI.tif", sep="/"), overwrite=TRUE)

TOPO_SENC<-rast(paste(path, "CorrectedMosaics/SENC_Scene_TopoCorr.tif", sep="/"))
TOPO_SENC[["NDVI"]]<-(TOPO_SENC$B8A_20m-TOPO_SENC$B04_20m)/(TOPO_SENC$B8A_20m+TOPO_SENC$B04_20m)
writeRaster(TOPO_SENC, paste(path, "NDVI_Corr_Mosaics/SENC_Scene_TopoCorrwNDVI.tif", sep="/"), overwrite=TRUE)
