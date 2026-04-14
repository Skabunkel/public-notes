#!/bin/bash

# Script to loop through commits from a file and check out each one
# Usage: ./checkout_commits.sh commits.txt

# Check if file argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <commits_file>"
    echo "Example: $0 commits.txt"
    exit 1
fi

COMMITS_FILE="$1"

# Check if file exists
if [ ! -f "$COMMITS_FILE" ]; then
    echo "Error: File '$COMMITS_FILE' not found"
    exit 1
fi

# Read each line (commit hash) from the file
while IFS= read -r commit || [ -n "$commit" ]; do
    # Skip empty lines and comments (lines starting with #)
    if [ -z "$commit" ] || [[ "$commit" =~ ^#.* ]]; then
        continue
    fi
    
    echo "Checking out commit: $commit"
    
    # Checkout the commit
    if git checkout "$commit"; then
        echo "Successfully checked out $commit"
        
        # Extract and display the commit message
        commit_message=$(git log -1 --pretty=format:"%s" "$commit")
        commit_date=$(git log -1 --pretty=format:"%aI" "$commit")
        echo "Commit message: $commit_message"
        echo "---"

	pijul add . --recursive
	pijul rec -m "$commit_message" --all --timestamp "$commit_date"

        # Optional: Add a pause or wait for user input
        # read -p "Press enter to continue to next commit..."
    else
        echo "Error: Failed to checkout $commit"
        exit 1
    fi
    
done < "$COMMITS_FILE"

echo "All commits processed successfully!"
