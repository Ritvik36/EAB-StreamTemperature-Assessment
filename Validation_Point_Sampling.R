####Validation Point Sampling####
install.packages("raster")
library(raster)
library(sf)
library(sp)
library(terra)

# Notes -------------------------------------------------------------------

## ODF,2024 states that below 500 feet (152.4 meters), Oregon ash forms pure stands: 
## ODF,2024 states that below 1000 feet (304.8 meters), 80% of Oregon ash is found: 
## ODF,2024 states that above 1000 feet (304.8 meters), 20% of Oregon ash is found:
## Oregon Dept. of Forestry (ODF). (2024). Forest facts: Emerald ash borer (EAB) Agrilus planipennis Fairmaire. ODF.
## https://www.oregon.gov/odf/Documents/forestbenefits/fact-sheet-emerald-ash-borer.pdf

## For code variables, using: pure stands < 500 ft =< mixed stands < 1000 ft =< sparse stands

## For a better understanding of terminology and process,
## see the graduate thesis at https://ir.library.oregonstate.edu/concern/graduate_thesis_or_dissertations/bv73c8453?locale=en
## Validation detailed information begins on Page 22 at Section 2.3.5 Validation

## NOTE: Process assumes validation point sampling is occurring within the boundaries of a watershed and script comments will reflect that

# Inputs ------------------------------------------------------------------

# Reads in Oregon ash pixels found within desired street buffer radius within the provided watershed (e.g. Marys River Watershed). 
# Raster can be created in QGIS in the following way: 
# 1) Select only ash pixels from tree map raster, 
# 2) From those ash pixels, include only ash pixels within set distance from roadways (increases accessibility for field visits)
# 3) From those street-buffered ash pixels, only include ash pixels within desired watershed (e.g. HUC-10 outline of Marys River Watershed)
rast_obj<-rast("C:/ExampleFilepath/Validation/MRWClipped_AshonlyStreet_100mbuffer.tif")

# Reads in elevation data and reprojects to ESPG:32610 UTM 10N/WGS84. Change this to whatever projection ash pixels raster is using
dem<-rast("C:/ExampleFilepath/Validation/10m_MRW_DEM.tif")
crs(dem) <- "epsg:32610"

## Elevation Zone Parameters
# This is the value (in meters since units depend on DEM units) for the break between pure stands and mixed stands (see Notes above)
pure_mixed_break<-152.4
# This is the value (in meters since units depend on DEM units) for the break between mixed stands and sparse stands (see Notes above)
mixed_sparse_break<-304.8

# Number of random pixels to select from each zone
select_numb<-10

# Output path for creation of folder for random sampled points shapefiles
samppoints.path<-"C:/ExampleFilepath/Validation/Random Sampled Points"

# Output path for pure stand random sampled points shapefile
purestand_filepath<-file.path(samppoints.path, "purestand_100mbuffer_10pt.shp")

# Output path for mixed stand random sampled points shapefile
mixedstand_filepath<-file.path(samppoints.path, "mixedstand_100mbuffer_10pt.shp")

# Output path for sparse stand random sampled points shapefile
sparsestand_filepath<-file.path(samppoints.path, "sparsestand_100mbuffer_10pt.shp")

# Code --------------------------------------------------------------------

# DEM attribute name to access the column of raster values within the SpatVector object
dem_attribute <- names(dem)[1]

# Creates polygon of portion of watershed extent that is below pure/mixed break (e.g. 500 feet (152.4 m)) in elevation.
# Then masks out Oregon ash pixels that don't fall within polygon.
initpolygon_purestand<-as.polygons(dem < pure_mixed_break)
polygon_purestand<-initpolygon_purestand[initpolygon_purestand[[dem_attribute]]==1]
masked_purestand<-mask(rast_obj,polygon_purestand)

# Creates polygon of portion of watershed extent that is above/equal-to pure/mixed break (e.g. 500 feet (152.4 m))
# but below mixed/sparse break (e.g. 1000 feet (304.8 m)) in elevation.
# Then masks out Oregon ash pixels that don't fall within polygon.
initpolygon_mixedstand<-as.polygons(dem >=pure_mixed_break & dem < mixed_sparse_break)
polygon_mixedstand<-initpolygon_mixedstand[initpolygon_mixedstand[[dem_attribute]]==1]
masked_mixedstand<-mask(rast_obj, polygon_mixedstand)

# Creates polygon of portion of watershed extent that is above/equal-to mixed/sparse break (e.g. 1000 feet (304.8 m)) in elevation.
# Then masks out Oregon ash pixels that don't fall within polygon.
initpolygon_sparsestand<-as.polygons(dem >= mixed_sparse_break)
polygon_sparsestand<-initpolygon_sparsestand[initpolygon_sparsestand[[dem_attribute]]==1]
masked_sparsestand<-mask(rast_obj, polygon_sparsestand)

# Select user-specified (in inputs section) number of random pixels (e.g. 10) from each masked SpatRaster and create .shp of those points
purestand_sampled<-spatSample(masked_purestand, select_numb, na.rm=TRUE, as.points=TRUE, xy=TRUE)
writeVector(purestand_sampled, purestand_filepath, overwrite=TRUE)

mixedstand_sampled<-spatSample(masked_mixedstand, select_numb, na.rm=TRUE, as.points=TRUE, xy=TRUE)
writeVector(mixedstand_sampled, mixedstand_filepath, overwrite=TRUE)

sparsestand_sampled<-spatSample(masked_sparsestand, select_numb, na.rm=TRUE, as.points=TRUE, xy=TRUE)
writeVector(sparsestand_sampled, rarestand_filepath, overwrite=TRUE)

# Convert each set of sampled points to sf-type points feature and transform each feature to WGS84 (EPSG:4326).
WGS_purestand_sampled<-st_transform(st_as_sf(purestand_sampled), crs=4326)

WGS_mixedstand_sampled<-st_transform(st_as_sf(mixedstand_sampled), crs=4326)

WGS_sparsestand_sampled<-st_transform(st_as_sf(sparsestand_sampled), crs=4326)


# Return coordinates of each sample point for each set
print("The selected purestand sample points are at the following coordinates:")
print(st_coordinates(WGS_purestand_sampled))

print("The selected mixedstand sample points are at the following coordinates:")
print(st_coordinates(WGS_mixedstand_sampled))

print("The selected sparsestand sample points are at the following coordinates:")
print(st_coordinates(WGS_sparsestand_sampled))