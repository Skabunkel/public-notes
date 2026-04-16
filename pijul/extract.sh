#!/bin/bash

# Create diff files from pijul history, so we can train on them and compress them.
# Essentaly creating a pijul gc command.
# Usage: ./checkout_commits.sh /path/to/.pijul

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path>"
    echo "Example: $0 ~/cool/.pijul"
    exit 1
fi

FOLDER_PATH="$1"

mkdir /tmp/pchanges
cd "$FOLDER_PATH"

pijul log --hash-only | shuf -n 2000 | while read f; do
  hash=$(basename "$f" | sed 's/\.change$//')
  pijul change "$hash" > "/tmp/pchanges/$hash" 2>/dev/null
done
zstd --train -B4096 --maxdict=128KB /tmp/pchanges/* -o /tmp/changes.dict