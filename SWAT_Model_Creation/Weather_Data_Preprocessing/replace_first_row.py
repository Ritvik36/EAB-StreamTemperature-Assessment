import os

## INPUTS -------------------------------------------------------------------------------------------------------------------------------

# Specify the folder that contains the text files (keep the r in front)
directory = r"C:\ExampleFilepath\Intermediate Outputs\TextFiles\Temperature_TextFiles"

# Specify the start date of all the data in format yyyymmdd. 
# If PRISM data was downloaded for the years 2010 to 2013, start date would be 20100101
start_date = "20100101\n"

## CODE ----------------------------------------------------------------------------------------------------------------------------------

# Loop over all files in the directory
for filename in os.listdir(directory):
    # Check if the file is a .txt file
    if filename.endswith('.txt'):
        # Get the full path of the file
        filepath = os.path.join(directory, filename)
        
        # Read the original file
        with open(filepath, 'r') as file:
            lines = file.readlines()

        # Change the first line to user-specified date
        lines[0] = start_date

        # Write the new lines back to the file
        with open(filepath, 'w') as file:
            file.writelines(lines)
