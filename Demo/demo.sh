#!/bin/bash

########################
# Import Magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################

clear
caption "Welcome to Vault Demo"
echo ""

p "After preparing the environment, we now have a fully initialized Vault Cluster:"
pe "vault status"

echo ""

p ""

# Extract the file names using yq (YAML processor)
demo_files=$(yq eval '.demo_files[]' "$CONFIG_FILE")

# Iterate through each file and execute it
for FILE in $demo_files; do
    if [[ -f "$DEMO_FILES_PATH/$FILE" ]]; then
        clear
        bash "$DEMO_FILES_PATH/$FILE"

        # Run cleanup
        cd ./configuration
        bash ./cleanup.sh "$(basename "$FILE" .sh)" > /dev/null
        cd ..

    else
        echo "Demo file $FILE not found."
    fi
done

caption "Thanks for participating @Terasky"