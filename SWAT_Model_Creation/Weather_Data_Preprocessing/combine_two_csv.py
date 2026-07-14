import pandas as pd
import os

## INPUTS -------------------------------------------------------------------------------------------------------------------------------

# Replace filepath with merged Maximum Temperature data CSV (keep the r in front)
mergedmxtcsv_filepath = r"C:\ExampleFilepath\Intermediate Outputs\MergedCSVs\MaximumTemperature_merged.csv"

# Replace filepath with merged Minimum Temperature data CSV (keep the r in front)
mergedmntcsv_filepath = r"C:\ExampleFilepath\Intermediate Outputs\MergedCSVs\MinimumTemperature_merged.csv"

# Replace number with number of Temperature gage data Locations
gage_Locations = 100

# Replace filepath with folder to place output text files (keep the r in front)
# See Weather Data Protocol for recommended folder organization (Intermediate Outputs --> TextFiles --> Temperature_TextFiles)
output_folder = r"C:\ExampleFilepath\Intermediate Outputs\TextFiles\Temperature_TextFiles"

## CODE ----------------------------------------------------------------------------------------------------------------------------------

# Reads in merged CSVs
mergedmxtcsv_file = pd.read_csv(mergedmxtcsv_filepath)
mergedmntcsv_file = pd.read_csv(mergedmntcsv_filepath)

# Selects the desired columns from both merged CSVs
mxtdf = mergedmxtcsv_file.columns[1:gage_Locations+1]
mntdf = mergedmntcsv_file.columns[1:gage_Locations+1]

# Iterates over the maximum and minimum temperature data and creates separate text files for each Location
# where maximum temperature and minimum temperature for each day are combined in a row with a space in between
for i, (mxt, mnt) in enumerate(zip(mxtdf, mntdf)):
    mxt_mnt_combined = mergedmxtcsv_file[mxt].astype(float).astype(str) + ' ' + mergedmntcsv_file[mnt].astype(float).astype(str)
    # Creates a filename based on gage index and user specified output folder. The number i+1 is the gage number
    txt_file = os.path.join(output_folder, f"gage_{i+1}.txt")
    # Writes to text file
    mxt_mnt_combined.to_csv(txt_file, index=False)

print(f"{gage_Locations} text files created successfully!")