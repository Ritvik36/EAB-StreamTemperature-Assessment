import shutil

## INPUTS -------------------------------------------------------------------------------------------------------------------------------

# Replace filepath with tab-delimited text file containing the locations data
# If following folder organization detailed in Weather Data Protocol, text file should be found in Intermediate Outputs --> TextFiles
locations_txtfile = r"C:\ExampleFilepath\Intermediate Outputs\TextFiles\watershed_weather_location_points.txt"

# Replace filepath with folder location of processed precipitation data text files
# See Weather Data Protocol for recommended folder organization (Intermediate Outputs --> TextFiles --> Precipitation_TextFiles)
precipitation_folder = r"C:\ExampleFilepath\Intermediate Outputs\TextFiles\Precipitation_TextFiles"

# Replace filepath with folder location of processed temperature data text files
# See Weather Data Protocol for recommended folder organization (Intermediate Outputs --> TextFiles --> Temperature_TextFiles)
temperature_folder = r"C:\ExampleFilepath\Intermediate Outputs\TextFiles\Temperature_TextFiles"

## CODE ----------------------------------------------------------------------------------------------------------------------------------

# Open the input file in read mode
with open(locations_txtfile, 'r') as infile:
    # Read the file
    lines = infile.readlines()

# Replace blank spaces with commas
lines = [line.replace('\t', ',') for line in lines]

# Open the output file in write mode
with open(locations_txtfile, 'w') as outfile:
    # Write the modified content to the file
    outfile.writelines(lines)

# Copy the updated locations text file to the processed precipitation data text files folder
shutil.copy2(locations_txtfile, precipitation_folder)

# Copy the updated locations text file to the processed temperature data text files folder
shutil.copy2(locations_txtfile, temperature_folder)

print("Updated locations text file copied to the Precipitation and Temperature TextFiles folders.")