#!/bin/bash

# Clear all Aumeno data
echo "🗑️ Clearing all Aumeno data..."

# Remove database
DB_PATH="$HOME/Library/Application Support/Aumeno/aumeno.sqlite"
if [ -f "$DB_PATH" ]; then
    rm "$DB_PATH"
    echo "✅ Database deleted: $DB_PATH"
else
    echo "⚠️ Database not found: $DB_PATH"
fi

# Remove the entire Aumeno directory
AUMENO_DIR="$HOME/Library/Application Support/Aumeno"
if [ -d "$AUMENO_DIR" ]; then
    rm -rf "$AUMENO_DIR"
    echo "✅ Aumeno directory deleted: $AUMENO_DIR"
else
    echo "⚠️ Aumeno directory not found: $AUMENO_DIR"
fi

echo "✨ All data cleared! The database will be recreated on next app launch."
