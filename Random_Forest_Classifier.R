####Supervised Classification via Random Forest Model####
install.packages("sf")
library(terra)
library(dplyr)
library(caret)
library(sf)
library(RStoolbox)
library(doParallel)
library(tmap)
library(ranger)


# Notes -------------------------------------------------------------------

## All topographically-corrected input rasters (also to be referred to as corrected mosaics or corrected tiles) must have same extents
## If extents are different, all should be cropped to smallest tile extent first
## Run function ext to get extent of each tile or call each raster object

## There is a bug in the tmap_save function for the creation of the training patches map and final tree map 
## This may just be due to the R version, so the relevant lines of code were kept but commented out 
## To try using, first uncomment them (CNTRL+F tmap_save to find them)
## Alternatively, leave them commented and just manually save the temporary R Graphics versions that pop up when the code is run

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
output.path<-"C:/ExampleFilepath/Outputs"

# Corrected mosaics from topographic correction script (10 bands with vegetation masking (but not canopy masking, which occurs below))
corr_mosaics<-list.files(file.path(output.path, "CorrectedMosaics"), pattern="*.tif", full.names = TRUE)

# Used to shorten filepath to solely filename for a naming function below. Alternatively, the basename function can be used.
corr_mosaic_filenames<-list.files(file.path(output.path, "CorrectedMosaics"), pattern="*.tif", full.names = FALSE)

# Reading in of training patches. Training patches must be in shapefile form, with a single .shp file for all species of interest
# Attribute table should include a column (named ID) specifying the unique "ID" value of each polygon
# and a column (named Species) specifying the tree group the polygon pertains to
# Note: Although column is named Species, some of the tree groups can be groups of species (e.g. Conifers)
patches<-st_read("C:/ExampleFilePath/Patches/Training_Patches.shp")

# Canopy raster, to be used later to create the canopy mask
# May be useful to have raster already have an initial threshold height mask (e.g. 15 foot threshold mask)
# To create raster, need spectral imagery (e.g. 2022 NAIP four band imagery) to calculate NDVI to identify vegetation, 
# along with elevation data to determine canopy heights
canopy<-rast("C:/ExampleFilePath/Prepped Data/Canopy_Raster.tif")

# Watershed extent for training patches map creation
Watershed_AOI_extent<-st_read("C:/ExampleFilePath/Prepped Data/Watershed_Extent.shp")


## MACHINE LEARNING MODEL CHANGEABLE VARIABLES (see model code if interested in customization outside the script scope)
# For a better understanding of terminology and the model process, including the customizable variables offered by this script,
# see the graduate thesis at https://ir.library.oregonstate.edu/concern/graduate_thesis_or_dissertations/bv73c8453?locale=en
# Random Forest detailed information begins on Page 18 at Section 2.3.4 Supervised Classification: Random Forest

# Number of folds for K-Fold cross validation
folds<-10

# Number of repeats for K-Fold cross validation
number_repeats<-5

# Range of mtry values to test
# 8:15 means the entire K-Fold cross validation (e.g. 10 folds with 5 repeats) will be rerun 8 times
# in order to test each mtry separately at a value of 8, 9, 10, 11, 12, 13, 14, and 15
# The optimal mtry will then be used as the tuned hyperparameter for the output Random Forest model 
mtry_input<-8:15

# Each number in the ntree_number list represents a separate output Random Forest model (with its own set of tuned hyperparameters),
# developed using the specified number of decision trees.
# So 4 provided ntree sizes will result in 4 hyperparameter tunings and 4 final Random Forest models, 
# with each model uniquely corresponding to one of the supplied ntree sizes
# These results can then be used to compare model performance to estimate what can be considered a sufficient number of decision trees
ntree_number<-c(500, 1000, 1500, 2000)

## FINAL MODEL SELECTION/PRELIMINARY VALIDATION CHANGEABLE VARIABLES (see model code if interested in customization outside the script scope)

# Specifies which of the ntree-size model runs is to be used for Random Forest classification of all available pixels,
# which produces the final tree raster. 
# Optimal ntree-size can be based off estimated model accuracy, desired runtime, etc.
# Make sure that the selected number matches one of the numbers provided in ntree_number above
selected_ntree<-"1000"

## Reading in of validation patches. Validation patches must be in shapefile form, with a single .shp file for all species of interest
# Attribute table should include a column (named ID) specifying the unique "ID" value of each polygon
# and a column (named Species) specifying the tree group the polygon pertains to
# Note: Although column is named Species, some of the tree groups can be groups of species (e.g. Conifers)
patches_val<-st_read("C:/ExampleFilePath/Patches/Validation_Patches.shp")


# Code --------------------------------------------------------------------

# Used as template for reprojection of the CRS of the patches shapefile and canopy raster to the CRS of the corrected mosaic rasters
rast_for_proj<-rast(corr_mosaics[1])

# Training patches are transformed into same CRS as corrected mosaic rasters
patches_proj<-st_transform(patches, crs = st_crs(rast_for_proj))

# Canopy raster is projected to same CRS and resolution as the corrected mosaic rasters
canopy_proj<-project(canopy, rast_for_proj, method = "bilinear")

# Breaks up each filename string into separate words as determined by underscores in the filename. This will be used for naming
namesplit<-strsplit(corr_mosaic_filenames, split="_")

# Reads in each corrected mosaic raster and converts each to a Spatial Raster object
rst_list<-lapply(corr_mosaics, rast)

# Renames each band in each raster using the following format: growingseasonperiod_bandnumber
for(i in 1:length(rst_list)){
  names(rst_list[[i]])<-paste(namesplit[[i]][1], names(rst_list[[i]]), sep="_")
}

# Calculates spectral indices (ratios of different bands to one another (e.g. NDVI)) using the spectralIndices function 
# mresr is another spectral index not covered by the spectralIndices function and therefore calculated manually
# All input rasters must have same extents. If extents are different, all should be cropped to smallest tile extent first
# Run function ext to get extent of tiles or call the raster object
# NOTE: mresr is currently misnamed as B06_20m but will be fixed later in the script
newrst<-list()
for(i in 1:length(rst_list)){
    tmp_rst<-spectralIndices(img=rst_list[[i]], blue=2, green=3, red=4, redEdge1=5, redEdge2=6, redEdge3=7, nir=10, swir2=8, swir3=9, indices=c("DVI", "NDVI", "GNDVI", "MCARI"))
    mresr<-(rst_list[[i]][[6]] - rst_list[[i]][[2]])/(rst_list[[i]][[5]] - rst_list[[i]][[2]])
    rst<-c(rst_list[[i]], mresr, tmp_rst)
    newrst[[i]]<-rst
}

# Renames each band in each updated raster with growingseasonperiod_bandname
# Index bands will become growingseasonperiod_spectralindexname
# Spectral bands are already named growingseasonperiod_bandnumber and so will become:
# growingseasonperiod_growingseasonperiod_bandnumber temporarily and will be fixed later in the script 
for(i in 1:length(rst_list)){
  names(newrst[[i]])<-paste(namesplit[[i]][1], names(newrst[[i]]), sep="_")
}

# First removes name (if any) from each raster (not from the spectral/index bands)
# Next combines all rasters into a single multispectral/indices combined raster 
# (all growing season periods and corresponding bands within a single multi-banded raster).
# The resultant combined raster then has its extent cropped by a canopy raster that has been resampled to match the 
# combined raster grid alignment. 
# The canopy raster is also used as a mask to remove any pixels within the cropped combined raster extent that have 
# a canopy height below a certain threshold value 
# If the raw input canopy raster already has had its pixels removed that are lower than threshold height (e.g. 7m), code can be ran as is.
# If raw input canopy raster still contains pixels less than threshold height, 
# use commented out line of code to remove them (threshold can be adjusted to whatever value is desired).
names(newrst)<-NULL
RS_data<-do.call(c, newrst)
canopy_20m<-resample(canopy_proj, RS_data)
tree_Rs<-crop(RS_data, canopy_20m)
##canopy_20m[canopy_20m < 7*3.3]<-NA
tree_multispectral<-mask(tree_Rs, canopy_20m)

# Fixes naming error caused earlier by adding mresr (see earlier comment for more information) so that mresr name is correctly updated
names(tree_multispectral)[c(11,26,41,56)]<-gsub("*B06_20m$", "MRESR", names(tree_multispectral)[c(11,26,41,56)])

# Scalar multiplication of index bands allows for all bands (spectral/index bands) to be visibly graphed on same scale. 
# Multiplied value is dependent on range of values for the band in question
tree_multispectral[[c(13:14, 28:29, 43:44, 58:59)]]<-tree_multispectral[[c(13:14, 28:29, 43:44, 58:59)]]*10000
tree_multispectral[[c(15, 30, 45, 60)]]<-tree_multispectral[[c(15, 30, 45, 60)]] * 10
tree_multispectral[[c(11, 26, 41, 56)]]<-tree_multispectral[[c(11, 26, 41, 56)]]*1000

# Saving the now fully processed multispectral/indices combined raster to 'local' computer
# so previous code does not have to be re-run on each re-run of this project. 
writeRaster(tree_multispectral, filename = file.path(output.path, "ProcessedSentinelImage.tif"), filetype= 'GTiff', datatype= 'FLT8S', overwrite=TRUE)

# Immediately calling previously locally saved raster back and creating a Spatial Raster object out of it
tree_multspec<-rast(file.path(output.path, "ProcessedSentinelImage.tif"))

# Extracts raster values from each pixel within training patches and stores in a dataframe
traindf<-terra::extract(tree_multspec, vect(patches_proj), ID=TRUE)

# Ensures reflectances/index values are assigned to correct tree group (Species identifier)
mergeit<-patches_proj %>% mutate(ID =rownames(patches_proj)) %>%   group_by(Species) %>%  
  st_as_sf() %>% st_drop_geometry() %>% select(ID, Species)
traindf2<-merge(traindf, mergeit, by="ID")
trainme<-traindf2[,-1]

# Converts Species identifier to a factor variable as setup for the Random Forest Classifier. 
# Assigns an integer code (also known as a dummy variable) for each unique tree group
trainme$Species<-factor(trainme$Species)

# Removes NA values 
# Final dataframe consists of each row being a training pixel and the columns being the following:
# one column for each spectral band reflectance (for each growing season period as well)
# one column for each spectral index value (for each growing season period as well),
# the class factor variable
trainme2<-trainme[complete.cases(trainme),]

# Fixes double growing season period naming error caused earlier for the spectral bands (see earlier comment for more information)
# Spectral band column header names will no longer have the growing season period included twice (e.g. BUD_BUD_B08A becomes BUD_BO8A)
# Column header names without this double naming error will be left unchanged
colnames(trainme2)<-gsub("BUD_BUD", "BUD", colnames(trainme2))
colnames(trainme2)<-gsub("LEAF_LEAF", "LEAF", colnames(trainme2))
colnames(trainme2)<-gsub("MAXP_MAXP", "MAXP", colnames(trainme2))
colnames(trainme2)<-gsub("SENC_SENC", "SENC", colnames(trainme2))

names(tree_multspec)<-gsub("BUD_BUD", "BUD", names(tree_multspec))
names(tree_multspec)<-gsub("LEAF_LEAF", "LEAF", names(tree_multspec))
names(tree_multspec)<-gsub("MAXP_MAXP", "MAXP", names(tree_multspec))
names(tree_multspec)<-gsub("SENC_SENC", "SENC", names(tree_multspec))

# Graph to see how reflectance/index values vary across bands and spectral indices for each growing season period
plotdf<-trainme2 %>% tidyr::pivot_longer(1:(ncol(trainme2)-1), names_sep="_", names_to=c("Growing_Period", "Band", "Resolution"))
df_summary<- plotdf %>% group_by(Species, Growing_Period, Band) %>% summarize(mean_reflectance= mean(value),
                                          sd_reflectance = sd(value))
df_summary$Band[df_summary$Band=="B8A"]<-"B08"
X11()
reflectances<-ggplot(data=df_summary, aes(x=Band, y=mean_reflectance,
                            ymin = mean_reflectance - sd_reflectance,
                            ymax = mean_reflectance + sd_reflectance, color=Species)) +
  geom_point() +

  geom_line(aes(group=Species), lwd=1.5)+
  geom_errorbar(width = 0.2)+
  scale_color_manual(values=c("darkgoldenrod4", "slateblue4", "darkgreen",  "lemonchiffon",  "magenta", "orange", "olivedrab", "azure4"))+
  facet_wrap("Growing_Period")+
  xlab("Sentinel 2 Wavelength Band")+
  ylab("Reflectance")+
  theme_classic()+
  guides(color=guide_legend("Tree Species"))+
  theme(strip.background = element_rect(fill="yellow"),
        #plot.margin = margin(t=rel(1), r=rel(1.25), b=rel(1.5), l=rel(1.5)),
        strip.text = element_text(face = "bold", size = rel(1.5)),
        axis.title.x = element_text(face = "bold", size = rel(1.25), vjust = -2, margin=margin(t=15, b=15)),
        axis.title.y = element_text(face = "bold", size = rel(1.25), vjust = -2, margin=margin(l=15, r=15)),
        axis.text.x = element_text(angle=45, hjust = 1, vjust = 0.95, face="bold"),
        axis.text.y = element_text(face="bold"),
        legend.title = element_text(face="bold"))
X11()
reflectances
ggsave(paste(output.path, "Maps and Figures/Reflectances.png", sep = "/"), plot = reflectances)

# Adds buffer to training patches to make them more visible on map
buff_patch<-st_buffer(st_make_valid(patches_proj), dist=100)

# Processing of watershed extent for display on maps
Watershed_AOI<-as.polygons(tree_multspec$LEAF_B8A_20m > -Inf)
Watershed_AOI_initbuff<-(st_buffer(st_as_sf(Watershed_AOI),dist=100))
Watershed_AOI_union<-st_union(Watershed_AOI_initbuff)
Watershed_AOI_buff<-st_buffer(Watershed_AOI_union, dist=0)
Watershed_AOI_bound<-st_boundary(Watershed_AOI_buff)
Watershed_AOI_rm<-st_buffer(Watershed_AOI_bound, dist = -5)
Watershed_erase<-st_convex_hull(Watershed_AOI_bound)
Watershed_erase<-st_difference(Watershed_erase, Watershed_AOI_buff)
tmap_mode("plot")
tmap_options(check.and.fix = TRUE)

# Creation of map of training patches. The extent is created from the input shapefile Watershed_AOI_extent
# (with its CRS updated to that of the corrected mosaic rasters)
Watershed_AOI_extent_proj<-st_transform(Watershed_AOI_extent, crs = st_crs(rast_for_proj))
WatershedOutline<-st_as_sf(Watershed_AOI_extent_proj)
WatershedOutline[,"Watershed_Area"]<-""

patches_map<-tm_shape(buff_patch[order(buff_patch$Species),])+
  tm_polygons(col = "Species",
              border.col=NA,
              palette = c("darkgoldenrod4", "slateblue4", "darkgreen",  "lemonchiffon",  "magenta", "orange", "olivedrab", "azure4"),
              title="Tree Species")+
  tm_shape(WatershedOutline)+
    tm_polygons(col="Watershed_Area", alpha=0, border.col = "red", lwd=2, title="Watershed Area")+
  tm_compass(position = c("RIGHT", "BOTTOM"), text.size = 0.35)+
  tm_scale_bar(breaks = c(0, 5, 10), position=c("RIGHT", "TOP"), text.size = 0.35)+
  tm_layout(inner.margins=c(0.1, 0.1, 0.1, 0.1), main.title="Supervised Classification Training Patches", main.title.fontface = "bold", main.title.position = "left", legend.show = TRUE,legend.outside = TRUE, legend.position = c("right", "top"), legend.text.size = 0.6, legend.title.size = 0.75)
X11()
patches_map
## Commented out due to bug (likely due to computer R version). Option to uncomment and run is available
#tmap_save(patches_map, filename = file.path(output.path, "Maps and Figures/TrainingPatches.png"), device = 'png')


## Machine Learning Model
# For a better understanding of terminology and the model process, including the customizable variables offered by this script,
# see the graduate thesis at https://ir.library.oregonstate.edu/concern/graduate_thesis_or_dissertations/bv73c8453?locale=en
# Random Forest detailed information begins on Page 18 at Section 2.3.4 Supervised Classification: Random Forest

# Repeated K-Fold cross validation is used to tune hyperparameters and assess general decision-making accuracy
# Folds is set in the inputs section and represents the number of folds for the K-Fold cross validation process
# Repeats is set in the inputs section and represents how many times one K-Fold cross validation process will be repeated (aids stability)
trCrtl<-trainControl(method="repeatedcv", number = folds, repeats = number_repeats)

# caret package function train() will first run the repeated K-Fold cross validation and then use optimal hyperparameters
# to rerun Random Forest classification with all training data to produce final model
# If multiple ntree-sizes are provided in ntree_number list (see in Inputs), 
# this entire process (hyperparameter tuning and final Random Forest model creation) will occur using each provided ntree-size.
# So 4 provided ntree-sizes will result in 4 hyperparameter tunings and 4 final Random Forest models 
# (with each model composed of a different n-tree number)
# The model performance of each output will later be compared to manually select the model to be used for classification of the whole tree map
# mtry input sets number of randomly selected predictors tested at each node of the classification trees that make up a single random forest
# Setting mtry to 8:15 means the entire K-Fold cross validation (with x folds and x repeats) would be rerun 8 times in order to
# test each mtry separately at a value of 8, 9, 10, 11, 12, 13, 14, and 15 in order to determine the optimal mtry
# The optimal mtry will then be automatically used as the tuned hyperparameter for the Random Forest classification model output(s) 
# .splitrule determines the methodology for how data is separated at each node
# .min.node.size determines the minimum number of data points necessary to form a node
# cl sets up parallel processing. 
# for loop with mod[[i]] is where machine learning model occurs. 

tgrid <- expand.grid(
  .mtry = mtry_input,
  .splitrule = "gini",
  .min.node.size = 1
)
cl <- makePSOCKcluster(15)
registerDoParallel(cl, cores = detectCores()-1)
ntree<-ntree_number
mod<-list()
for(i in 1:length(ntree)) {
mod[[i]]<-train(Species~., data=trainme2, num.trees=ntree[i], method="ranger", trControl = trCrtl, tuneGrid = tgrid)
}

# Collapses list of Random Forest models for upcoming comparison of model performance 
# and adds ntree identifier to differentiate between models (since each model is composed of a different number of trees (ntree-size))
names(mod)<-ntree
out<-list()
for(i in 1:length(mod)){
  mod[[i]]$results[,"ntree"]<-ntree[i]
  out[[i]]<-mod[[i]]$results
}
0
tuning<-do.call(rbind, out)

# Creates graph for model performance comparisons
mod_perf_comp<-ggplot(data=tuning, aes(x=mtry, y=Accuracy,
                          color=factor(ntree))) +
  geom_point(color="black") +
  geom_line(aes(group=ntree), lwd=1.5)+
  scale_color_brewer(palette = "Accent")+
  xlab("Mtry")+
  ylab("Accuracy")+
  theme_classic()
ggsave(paste(output.path, "Maps and Figures/Accuracy vs Mtry and ntree.png", sep = "/"), plot = mod_perf_comp)


# Stops the parallel processing
stopCluster(cl)

# Saves Random Forest models so that the machine learning portion does not have to be run every time project is opened
saveRDS(mod, paste(output.path, "Classification_Model/SpecClass_model.rds", sep="/"))

# Reads Random Forest models back in immediately
mod<-readRDS(paste(output.path, "Classification_Model/SpecClass_model.rds", sep="/"))


## Final Results/Selected Model Preliminary Validation

# User specifies which of the Random Forest models is to be used (each model is composed of a different ntree-size))
# (this is done in inputs section)
# For preliminary validation, creates confusion matrix using selected model training-pixel classifications referenced against 
# the actual training-pixel tree group identities
val<-predict(mod[[selected_ntree]], trainme2)
confusionMatrix(val, trainme2$Species)

# Takes the selected Random Forest model and applies it to the fully processed multispectral/indices combined raster.
# This brings the geospatial attributes back into play for the tree delineation
# Outputs the tree delineation raster (final product)
terra::predict(tree_multspec, mod[[selected_ntree]], factors=list(Species=levels(mod[[selected_ntree]])), na.rm=TRUE, filename = file.path(output.path, "Maps and Figures/Tree_Classification_Map.tif"), filetype="GTiff", memfrac=0.9, tempdir=tempdir(), todisk = TRUE, overwrite=TRUE)

# Calls back the tree classification map raster just created and reads it into a SpatRast object
panini<-rast(file.path(output.path, "Maps and Figures/Tree_Classification_Map.tif"))

# Creation of map to display predicted tree locations (final results map)
final_map<-tm_shape(panini, raster.downsample = FALSE)+
  tm_raster(style="cat",palette = c("darkgoldenrod4", "slateblue4", "darkgreen",  "lemonchiffon",  "magenta", "orange", "olivedrab", "azure4"),
            title="Tree Species")+
  tm_shape(WatershedOutline)+
  tm_polygons(col="Watershed_Area", alpha=0, border.col = "red", lwd=2, title="Watershed Area")+
  tm_compass(position = "right", text.size = 1)+
  tm_scale_bar(breaks = c(0, 5, 10, 25), position="right", text.size = 0.95)+
  tm_layout(inner.margins=c(0.02, 0.02, 0.02, 0.175), main.title="Supervised Classification Common Hardwoods and Conifers", main.title.fontface = "bold", main.title.position = "left", legend.show = TRUE,legend.outside = FALSE, legend.position = c("right", "top"), legend.text.size = 1.25, legend.title.size = 1.5)
X11()
final_map
## Commented out due to bug (likely due to computer R version). Option to uncomment and run is available
#tmap_save(final_map, filename = file.path(output.path, "Maps and Figures/SupervisedClassification_CommonHardwoodsandConifers.png"), device = 'png')


## Selected Model Secondary-Preliminary Validation/Confusion Matrices

# Validation patches are transformed into same CRS as corrected mosaic rasters
patches_val_proj<-st_transform(patches_val, crs = st_crs(rast_for_proj))

# Extracts raster values from each pixel within validation patches and stores in a dataframe
traindf_val<-terra::extract(tree_multspec, vect(patches_val_proj), ID=TRUE)

# Ensures reflectances/index values are assigned to correct tree group (Species identifier)
mergeit_val<-patches_val_proj %>% mutate(ID =rownames(patches_val_proj)) %>%   group_by(Species) %>%  
  st_as_sf() %>% st_drop_geometry() %>% select(ID, Species)
traindf2_val<-merge(traindf_val, mergeit_val, by="ID")
trainme_val<-traindf2_val[,-1]

# Converts Species identifier to a factor variable as setup for the Random Forest Classifier. 
# Assigns an integer code (also known as a dummy variable) for each unique tree group 
trainme_val$Species<-factor(trainme_val$Species)

# Removes NA values 
# Final dataframe consists of each row being a validation pixel and the columns being the following:
# one column for each spectral band reflectance (for each growing season period as well)
# one column for each spectral index value (for each growing season period as well),
# the class factor variable
trainme2_val<-trainme_val[complete.cases(trainme_val),]

# Fixes double growing season period naming error caused earlier for the spectral bands (see earlier comment for more information)
# Spectral band column header names will no longer have the growing season period included twice (e.g. BUD_BUD_B08A becomes BUD_BO8A)
# Column header names without this double naming error will be left unchanged
colnames(trainme2_val)<-gsub("BUD_BUD", "BUD", colnames(trainme2_val))
colnames(trainme2_val)<-gsub("LEAF_LEAF", "LEAF", colnames(trainme2_val))
colnames(trainme2_val)<-gsub("MAXP_MAXP", "MAXP", colnames(trainme2_val))
colnames(trainme2_val)<-gsub("SENC_SENC", "SENC", colnames(trainme2_val))

# For secondary-preliminary validation, creates another confusion matrix this time using
# selected model validation-pixel classifications referenced against the actual validation pixel tree group identities
# Selected model should be same one used for final results/preliminary validation
true_val<-predict(mod[[selected_ntree]], trainme2_val)
confusionMatrix(true_val, trainme2_val$Species)

# Commission and Omission error (User and Producer error) calculations from confusion matrix
CMT_list<-confusionMatrix(true_val, trainme2_val$Species)
CMT<-CMT_list$table

commission<-NULL

for(i in 1:nrow(CMT)){
  commission[i]<-sum(CMT[!rownames(CMT)==rownames(CMT)[i],i]/sum(CMT[,i]))
}

omission<-NULL

for(i in 1:nrow(CMT)){
  dropit<-colnames(CMT)[i]
  
  omission[i]<-sum(CMT[i,!colnames(CMT) %in% dropit]/sum(CMT[i,]))
}

# Commission error (User error)
commission
# Omission error (Producer error)
omission