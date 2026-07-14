import os

## INPUTS -------------------------------------------------------------------------------------------------------------------------------

# Specify the folder that contains the text files (keep the r in front)
directory = r"C:\ExampleFilepath\Intermediate Outputs\TextFiles\Precipitation_TextFiles"

## CODE ----------------------------------------------------------------------------------------------------------------------------------

# Loops over all files in the directory
for filename in os.listdir(directory):
    # Checks if the file is one of the files to be renamed
    if filename.startswith('gage_') and filename.endswith('.txt'):
        # Gets the number from the filename
        number = filename.replace('gage_', '').replace('.txt', '')
        
        # Creates the new filename
        new_filename = f'{number}.txt'
        
        # Gets the full paths of the old and new file
        old_filepath = os.path.join(directory, filename)
        new_filepath = os.path.join(directory, new_filename)
        
        # Renames the file
        os.rename(old_filepath, new_filepath)
