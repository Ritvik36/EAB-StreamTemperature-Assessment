import os

## INPUTS -------------------------------------------------------------------------------------------------------------------------------

# Specify the folder that contains the text files (keep the r in front)
directory = r"C:\ExampleFilepath\Intermediate Outputs\TextFiles\Temperature_TextFiles"

## CODE ----------------------------------------------------------------------------------------------------------------------------------

# Iterate over each file in the directory
for filename in os.listdir(directory):
    # Check if the file is a .txt file
    if filename.endswith('.txt'):
        filepath = os.path.join(directory, filename)
        
        # Read the contents of the file
        with open(filepath, 'r') as file:
            content = file.read()
        
        # Add commas between two integers
        content = content.replace(' ', ',')
        
        # Write the modified content back to the file
        with open(filepath, 'w') as file:
            file.write(content)
