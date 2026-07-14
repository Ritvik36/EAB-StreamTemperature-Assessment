import os

## INPUTS -------------------------------------------------------------------------------------------------------------------------------

# Specify the folder that contains the text files (keep the r in front)
directory = r"C:\ExampleFilepath\Intermediate Outputs\TextFiles\Precipitation_TextFiles"


# Specify the start date of all the data in format yyyymmdd. 
# If PRISM data was downloaded for the years 2010 to 2013, start date would be 20100101
start_date = "20100101"

## CODE ----------------------------------------------------------------------------------------------------------------------------------

# Loops over all files in the directory
for filename in os.listdir(directory):
    # Checks if the file is a .txt file
    if filename.endswith('.txt'):
        # Gets the full path of the file
        filepath = os.path.join(directory, filename)
        
        # Reads the original file
        with open(filepath, 'r') as file:
            lines = file.readlines()

        # Adds line to top of text file and places start_date there
        lines.insert(0, start_date + "\n")

        # Writes the new lines back to the file
        with open(filepath, 'w') as file:
            file.writelines(lines)
