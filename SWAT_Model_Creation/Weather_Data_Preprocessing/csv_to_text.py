import pandas as pd
import os

## INPUTS -------------------------------------------------------------------------------------------------------------------------------

# Replace filepath with merged Precipitation data CSV (keep the r in front)
mergedcsv_file = r"C:\ExampleFilepath\Intermediate Outputs\MergedCSVs\Precipitation_merged.csv"

# Replace number with number of Precipitation gage data Locations in CSV
gage_Locations = 100

# Replace filepath with folder to place output text files (keep the r in front)
# See Weather Data Protocol for recommended folder organization (Intermediate Outputs --> TextFiles --> Precipitation_TextFiles)
output_folder = r"C:\ExampleFilepath\Intermediate Outputs\TextFiles\Precipitation_TextFiles"

## CODE ----------------------------------------------------------------------------------------------------------------------------------

# Loads CSV file
data = pd.read_csv(mergedcsv_file)

# Loops through columns (starting from the 2nd column, ending at the nth [Last Location Number + 1] column)
for i in range(1, (gage_Locations + 1)):
    column_data = data.iloc[0:, i]  # Selects the relevant column
    txt_file = os.path.join(output_folder, f"gage_{i}.txt")  # Creates a filename based on gage index and user specified output folder
    column_data.to_string(txt_file, index=False, header=False)  # Writes relevant data to text file

print(f"{gage_Locations} text files created successfully!")