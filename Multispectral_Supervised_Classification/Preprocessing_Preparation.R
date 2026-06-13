####Preparations for Sentinel Topographic Corrections and Other Preprocessing####
library(terra)
library(RStoolbox)
library(xml2)


# Notes -------------------------------------------------------------------
## The following abbreviations will be used to name variables based on the growing season period that the variable relates to
## BUD  = Bud Break;          Example Date: May 17, 2023
## LEAF = Leaf Expansion;     Example Date: June 24, 2023
## MAXP = Max Photosynthesis; Example Date: August 3, 2023
## SENC = Leaf Senescence;    Example Date: October 29, 2023 

## ALL OUTPUT FILES WILL MAINTAIN THEIR RAW PROJECTION/RESOLUTION (Example: EPSG:32610 - WGS 84 / UTM zone 10N AT 20M RESOLUTION)

## In addition to all the necessary inputs, you will need a folder named Outputs with the following sub-folders:
# Classification_Model
# CorrectedMosaics
# Intermediate GeoTiffs
# Maps and Figures
# NDVI_Corr_Mosaics
# Solar Angles
# VegMaskedRasters

# Inputs ------------------------------------------------------------------

# Creates list of MTD .xml files (one for each growing season image) from specified folder 
# Folder should have subfolders where each subfolder contains one .xml file 
# (Each .xml file should be pulled out of its respective Sentinel 2 data download)
tmpxml<-list.files("C:/ExampleFilepath/Prepped Data/MTD XML 2023 Files", pattern="*MTD_TL.xml", recursive = TRUE, full.names = TRUE)

# Creates list of Scene Classification Images (one for each growing season image) from specified folder
# No subfolders required
# (Each .jp2 file should be copied (with replacement) from its respective Sentinel 2 data download)
SCI_list<-list.files("C:/ExampleFilePath/Prepped Data/Scene_Classification_Images", full.names = TRUE)

# Calls Solar_Angles_Function.R, which allows that script's functions to be used
# Also calls two folders: "Solar Angles" (to be filled with the solar angle rasters) 
# and "Intermediate GeoTiffs" (to be filled with the 13-band rasters)
source("C:/ExampleFilePath/Code/Solar_Angles_Function.R")
solarangle_path<-"C:/ExampleFilePath/Outputs/Solar Angles/"
band_path<-"C:/ExampleFilePath/Outputs/Intermediate GeoTiffs"

# Creates list of band data folders (one for each growing season image) from specified folder
# Folder should have subfolders where each band data folder has general file path of: 
# [date_of_image] -> R20m -> the 14 band .jp2 files (AOT,B01-B07, B8A, B11, B12, SCL, TCI, WVP)
# (Each set of bands should be sourced from their respective Sentinel 2 data download and copy/pasted into their respective subfolder) 
# In total 56 bands should be copied over to four subfolders, 14 bands (.jp2 files) for each growing season image)
# R20m intermediate folder is needed for grep identification to find folders that contain bands in order to pull out full list of .jp2 files

tmpband<-list.files(path = "C:/ExampleFilePath/Prepped Data/Band Data",recursive=TRUE, full.names = TRUE)
Img_dirs<-tmpband[grep("*R20m*", tmpband)]

# Creates list of substrings to be used to select the appropriate .jp2 files from each growing season band data subfolder
band_substr<-list("*T10TDQ_20230517*", "*T10TDQ_20230624*", "*T10TDQ_20230803*", "*T10TDQ_20231029*")


# Code --------------------------------------------------------------------

####Creating Rasters of Zenith and Azimuth Solar Angles####

# For each image in question (where each image corresponds to a different time of growing season), 
# solar function pulls necessary data in SpatRaster object format (therefore georeferenced) from .xml file.
# (Make sure correct .xml paired to correct growing season period)
# The Scene Classification Layer (SCL) image that was found in Sentinel 2 data download (pulled and placed in separate folder), 
# is converted into a SpatRaster object while maintaining its dimensions/extent,
# and then is resampled twice to create two SpatRaster objects: one with zenith solar angle data
# and one with azimuth solar angle data (resampling also helps to homogenize resolution)
# These objects are then each converted into raster format and placed into Solar Angles folder
# Therefore, the output for BUD is two solar angle rasters (one for zenith data and one for azimuth data)
# t1 is listed for each image, because area of interest only consists of one tile region (image)
# If multiple images were needed for each time of growing season, this process would have to
# be repeated for each image for each time of the growing season

##BUD (Bud Break)##
#t1#
BUDt1_solar<-solar(tmpxml[1])
BUDt1_SCI<-rast(SCI_list[1])
BUDt1_zen<-resample(BUDt1_solar$Zenith, BUDt1_SCI)
BUDt1_azm<-resample(BUDt1_solar$Azimuth, BUDt1_SCI)

writeRaster(BUDt1_zen, paste(solarangle_path, "BUD_t1_Zenith.tif"), filetype="GTiff", overwrite=TRUE)
writeRaster(BUDt1_azm, paste(solarangle_path, "BUD_t1_Azimuth.tif"), filetype="GTiff", overwrite=TRUE)


##LEAF (Leaf Expansion)##
#t1#
LEAFt1_solar<-solar(tmpxml[2])
LEAFt1_SCI<-rast(SCI_list[2])
LEAFt1_zen<-resample(LEAFt1_solar$Zenith, LEAFt1_SCI)
LEAFt1_azm<-resample(LEAFt1_solar$Azimuth, LEAFt1_SCI)

writeRaster(LEAFt1_zen, paste(solarangle_path, "LEAF_t1_Zenith.tif"), filetype="GTiff", overwrite=TRUE)
writeRaster(LEAFt1_azm, paste(solarangle_path, "LEAF_t1_Azimuth.tif"), filetype="GTiff", overwrite=TRUE)


##MAXP (Max Photosynthesis)##
#t1#
MAXPt1_solar<-solar(tmpxml[3])
MAXPt1_SCI<-rast(SCI_list[3])
MAXPt1_zen<-resample(MAXPt1_solar$Zenith, MAXPt1_SCI)
MAXPt1_azm<-resample(MAXPt1_solar$Azimuth, MAXPt1_SCI)

writeRaster(MAXPt1_zen, paste(solarangle_path, "MAXP_t1_Zenith.tif"), filetype="GTiff", overwrite=TRUE)
writeRaster(MAXPt1_azm, paste(solarangle_path, "MAXP_t1_Azimuth.tif"), filetype="GTiff", overwrite=TRUE)


##SENC (Leaf Senescence)##
#t1#
SENCt1_solar<-solar(tmpxml[4])
SENCt1_SCI<-rast(SCI_list[4]) 
SENCt1_zen<-resample(SENCt1_solar$Zenith, SENCt1_SCI)
SENCt1_azm<-resample(SENCt1_solar$Azimuth, SENCt1_SCI)

writeRaster(SENCt1_zen, paste(solarangle_path, "SENC_t1_Zenith.tif"), filetype="GTiff", overwrite=TRUE)
writeRaster(SENCt1_azm, paste(solarangle_path, "SENC_t1_Azimuth.tif"), filetype="GTiff", overwrite=TRUE)


####Creating GeoTiffs of Atmospherically-Corrected Sentinel Imagery####

# For each image in question (where each image corresponds to a different time of growing season), 
# grep function pulls relevant band files that correspond to that particular image (same growing season), which equals 14 of the 56 bands, 
# and then creates a SpatRaster object (maintaining extent and dimensions) that contains 13 of those bands (the TCI band is excluded)
# Each of the now 13 bands in the SpatRaster object are next renamed to their band names
# Finally, the SpatRaster object is converted into a raster named after its growing season period
# and then placed into the Intermediate GeoTiffs folder
# Therefore, the output for BUD is a raster that is composed of 13 named bands
# t1 is listed for each image, because area of interest only consists of one image region
# If multiple images were needed for each time of growing season, this process would have to
# be repeated for each image for each time of the growing season

##BUD (Bud Break)##
#t1#
BUD_infiles<-Img_dirs[grep(band_substr[1], Img_dirs)]
BUD_bnames<-substring(BUD_infiles, nchar(BUD_infiles)-10, nchar(BUD_infiles) -4) 
BUDt1Img<-rast(BUD_infiles[-13])
names(BUDt1Img)<-BUD_bnames[-13]
writeRaster(BUDt1Img, filename=paste(band_path, "BUD_t1.tif", sep="/"), 
            filetype="GTiff", overwrite=TRUE)


##LEAF (Leaf Expansion)##
#t1#
LEAF_infiles<-Img_dirs[grep(band_substr[2], Img_dirs)]
LEAF_bnames<-substring(LEAF_infiles, nchar(LEAF_infiles)-10, nchar(LEAF_infiles) -4) 
LEAFt1Img<-rast(LEAF_infiles[-13])
names(LEAFt1Img)<-LEAF_bnames[-13]
writeRaster(LEAFt1Img, filename=paste(band_path, "LEAF_t1.tif", sep="/"),
            filetype="GTiff", overwrite = TRUE)


##MAXP (Max Photosynthesis)##
#t1#
MAXP_infiles<-Img_dirs[grep(band_substr[3], Img_dirs)]
MAXP_bnames<-substring(MAXP_infiles, nchar(MAXP_infiles)-10, nchar(MAXP_infiles) -4)
MAXPt1Img<-rast(MAXP_infiles[-13])
names(MAXPt1Img)<-MAXP_bnames[-13]
writeRaster(MAXPt1Img, filename=paste(band_path, "MAXP_t1.tif", sep="/"),
            filetype="GTiff", overwrite = TRUE)


##SENC (Leaf Senescence)## 
#t1#
SENC_infiles<-Img_dirs[grep(band_substr[4], Img_dirs)]
SENC_bnames<-substring(SENC_infiles, nchar(SENC_infiles)-10, nchar(SENC_infiles) -4)
SENCt1Img<-rast(SENC_infiles[-13])
names(SENCt1Img)<-SENC_bnames[-13]
writeRaster(SENCt1Img, filename=paste(band_path, "SENC_t1.tif", sep="/"),
            filetype="GTiff", overwrite = TRUE)
