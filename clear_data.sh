#!/bin/bash

echo "🗑️ Clearing all Aumeno data..."
echo "---"
echo "This script will force-delete the database and its related files."
echo "Please ensure the Aumeno application is completely quit."
echo "---"

# Correct path for the shared App Group container
CONTAINER_PATH="$HOME/Library/Group Containers/group.com.sandbox.Aumeno"
DB_FILE_BASE="$CONTAINER_PATH/aumeno.sqlite"

# Check if the container directory exists
if [ ! -d "$CONTAINER_PATH" ]; then
    echo "❌ Error: App Group container not found at $CONTAINER_PATH"
    echo "Please run the app at least once to create it."
    exit 1
fi

echo "Searching for and deleting database files in: $CONTAINER_PATH"

# Force-remove the database and any associated journal/WAL files
# Use `find` to locate and show what's being deleted.
find "$CONTAINER_PATH" -name 'aumeno.sqlite*' -print -exec rm -f {} \;

echo ""
echo "✨ Verification:"
echo "Listing contents of the container to confirm deletion:"
ls -l "$CONTAINER_PATH"
echo ""
echo "✅ Cleanup attempt finished."