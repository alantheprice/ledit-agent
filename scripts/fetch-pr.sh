#!/bin/bash
set -e

echo "Fetching PR #$PR_NUMBER from $GITHUB_REPOSITORY..."

# Fetch PR metadata
gh pr view "$PR_NUMBER" --json title,body,author,baseRefName,headRefName,files,additions,deletions > "$PR_DATA_DIR/metadata.json"

# Extract key information
PR_TITLE=$(jq -r '.title' "$PR_DATA_DIR/metadata.json")
PR_BODY=$(jq -r '.body // ""' "$PR_DATA_DIR/metadata.json")
PR_AUTHOR=$(jq -r '.author.login' "$PR_DATA_DIR/metadata.json")
BASE_BRANCH=$(jq -r '.baseRefName' "$PR_DATA_DIR/metadata.json")
HEAD_BRANCH=$(jq -r '.headRefName' "$PR_DATA_DIR/metadata.json")

echo "PR: $PR_TITLE"
echo "Author: $PR_AUTHOR"
echo "Base: $BASE_BRANCH <- Head: $HEAD_BRANCH"

# Fetch the full diff
echo "Fetching diff..."
gh pr diff "$PR_NUMBER" > "$PR_DATA_DIR/full.diff"

# Fetch file list with changes stats
gh pr view "$PR_NUMBER" --json files --jq '.files[] | "\(.path) +\(.additions) -\(.deletions)"' > "$PR_DATA_DIR/files.txt"

# Detect if this is a documentation-only PR
DOC_ONLY="true"
while IFS= read -r file; do
    filename=$(echo "$file" | cut -d' ' -f1)
    # Check if any non-documentation file is changed
    if ! echo "$filename" | grep -qE "\.(md|txt|rst|adoc)$|^docs/|^documentation/|README|CHANGELOG|LICENSE"; then
        DOC_ONLY="false"
        break
    fi
done < "$PR_DATA_DIR/files.txt"

echo "DOC_ONLY=$DOC_ONLY" >> $GITHUB_ENV

# Auto-adjust comment threshold for doc-only changes
if [ "$DOC_ONLY" == "true" ] && [ "$COMMENT_THRESHOLD" == "low" ]; then
    echo "Detected documentation-only changes, adjusting comment threshold to medium"
    COMMENT_THRESHOLD="medium"
    echo "COMMENT_THRESHOLD=medium" >> $GITHUB_ENV
fi

# Fetch existing comments to avoid duplicates
echo "Fetching existing comments..."
gh pr view "$PR_NUMBER" --json comments --jq '.comments[].body' > "$PR_DATA_DIR/existing_comments.txt" 2>/dev/null || true

# Create a context file for the AI
cat > "$PR_DATA_DIR/context.md" << EOF
# Pull Request #$PR_NUMBER

**Title**: $PR_TITLE
**Author**: $PR_AUTHOR
**Branch**: $HEAD_BRANCH -> $BASE_BRANCH

## Description
$PR_BODY

## Files Changed
$(cat "$PR_DATA_DIR/files.txt")

## Review Instructions
- Review Type: $REVIEW_TYPE
- Comment Threshold: $COMMENT_THRESHOLD
- Summary Only: $SUMMARY_ONLY
- Documentation Only: $DOC_ONLY

Please review this pull request and provide:
1. A high-level summary of the changes
2. Any potential issues, bugs, or concerns
3. Suggestions for improvements
4. Security or performance considerations
5. Code style and best practices feedback

Focus on:
- Correctness and functionality
- Edge cases and error handling
- Code maintainability
- Performance implications
- Security vulnerabilities
EOF

echo "PR data prepared at: $PR_DATA_DIR"