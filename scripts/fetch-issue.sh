#!/bin/bash
set -e

# Fetch issue details and prepare context for ledit

REPO_OWNER=$(echo $GITHUB_REPOSITORY | cut -d'/' -f1)
REPO_NAME=$(echo $GITHUB_REPOSITORY | cut -d'/' -f2)
ISSUE_DATA_DIR="/tmp/ledit-issue-$ISSUE_NUMBER"

echo "Fetching issue #$ISSUE_NUMBER from $GITHUB_REPOSITORY..."

# Create temporary directory for issue data
rm -rf "$ISSUE_DATA_DIR"
mkdir -p "$ISSUE_DATA_DIR"

# Fetch issue details
gh api "/repos/$REPO_OWNER/$REPO_NAME/issues/$ISSUE_NUMBER" > "$ISSUE_DATA_DIR/issue.json"

# Extract issue information
ISSUE_TITLE=$(jq -r '.title' "$ISSUE_DATA_DIR/issue.json")
ISSUE_BODY=$(jq -r '.body // ""' "$ISSUE_DATA_DIR/issue.json")
ISSUE_STATE=$(jq -r '.state' "$ISSUE_DATA_DIR/issue.json")
ISSUE_LABELS=$(jq -r '.labels[].name' "$ISSUE_DATA_DIR/issue.json" | tr '\n' ',')

echo "Issue: $ISSUE_TITLE (state: $ISSUE_STATE)"

# Fetch all comments
echo "Fetching comments..."
gh api "/repos/$REPO_OWNER/$REPO_NAME/issues/$ISSUE_NUMBER/comments" --paginate > "$ISSUE_DATA_DIR/comments.json"

# Check for associated PRs
echo "Checking for associated pull requests..."
ASSOCIATED_PRS=$(gh api "/repos/$REPO_OWNER/$REPO_NAME/issues/$ISSUE_NUMBER/timeline" \
    --jq '[.[] | select(.event == "cross-referenced" and .source.issue.pull_request != null) | .source.issue] | unique_by(.number)' 2>/dev/null || echo "[]")

# Also check for PRs that reference this issue in their body/title
REFERENCING_PRS=$(gh pr list --json number,title,body,state,headRefName --jq \
    "[.[] | select((.body // \"\" | contains(\"#$ISSUE_NUMBER\")) or (.title | contains(\"#$ISSUE_NUMBER\")))]" 2>/dev/null || echo "[]")

# Check for PR with branch name pattern issue/NUMBER
BRANCH_PR=$(gh pr list --json number,headRefName,state --jq \
    "[.[] | select(.headRefName == \"issue/$ISSUE_NUMBER\")]" 2>/dev/null || echo "[]")

# Combine and deduplicate PRs
ALL_PRS=$(echo "$ASSOCIATED_PRS $REFERENCING_PRS $BRANCH_PR" | jq -s 'add | unique_by(.number // .)')
PR_COUNT=$(echo "$ALL_PRS" | jq 'length')

echo "Found $PR_COUNT associated PR(s)"

# Create issue context file
cat > "$ISSUE_DATA_DIR/context.md" << EOF
# GitHub Issue #$ISSUE_NUMBER: $ISSUE_TITLE

**Repository**: $GITHUB_REPOSITORY
**State**: $ISSUE_STATE
**Labels**: $ISSUE_LABELS
**URL**: https://github.com/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER

## Description

$ISSUE_BODY

## Issue Comments
EOF

# Add issue comments to context
jq -r '.[] | "### Comment by @\(.user.login) on \(.created_at)\n\n\(.body)\n"' "$ISSUE_DATA_DIR/comments.json" >> "$ISSUE_DATA_DIR/context.md" || echo "(No comments)" >> "$ISSUE_DATA_DIR/context.md"

# Add PR context if PRs exist
if [ "$PR_COUNT" -gt 0 ]; then
    echo "" >> "$ISSUE_DATA_DIR/context.md"
    echo "## Associated Pull Requests" >> "$ISSUE_DATA_DIR/context.md"
    echo "" >> "$ISSUE_DATA_DIR/context.md"
    
    # Process each PR
    echo "$ALL_PRS" | jq -c '.[]' | while read -r pr; do
        PR_NUM=$(echo "$pr" | jq -r '.number')
        
        # Fetch detailed PR info
        echo "Fetching PR #$PR_NUM details..."
        PR_DATA=$(gh pr view "$PR_NUM" --json title,state,author,body,headRefName,reviews,comments,url 2>/dev/null || echo "{}")
        
        if [ "$PR_DATA" != "{}" ]; then
            PR_TITLE=$(echo "$PR_DATA" | jq -r '.title // "Unknown"')
            PR_STATE=$(echo "$PR_DATA" | jq -r '.state // "Unknown"')
            PR_AUTHOR=$(echo "$PR_DATA" | jq -r '.author.login // "Unknown"')
            PR_URL=$(echo "$PR_DATA" | jq -r '.url // ""')
            PR_BODY=$(echo "$PR_DATA" | jq -r '.body // ""')
            PR_BRANCH=$(echo "$PR_DATA" | jq -r '.headRefName // ""')
            
            cat >> "$ISSUE_DATA_DIR/context.md" << EOF

### Pull Request #$PR_NUM: $PR_TITLE
- **State**: $PR_STATE
- **Author**: @$PR_AUTHOR  
- **Branch**: $PR_BRANCH
- **URL**: $PR_URL

#### PR Description
$PR_BODY

EOF
            
            # Add PR reviews
            REVIEWS=$(echo "$PR_DATA" | jq -r '.reviews // []')
            if [ "$REVIEWS" != "[]" ]; then
                echo "#### PR Reviews" >> "$ISSUE_DATA_DIR/context.md"
                echo "" >> "$ISSUE_DATA_DIR/context.md"
                echo "$REVIEWS" | jq -r '.[] | "**@\(.author.login)** (\(.state)):\n\(.body)\n"' >> "$ISSUE_DATA_DIR/context.md" 2>/dev/null || true
            fi
            
            # Add PR comments (not review comments, just general PR comments)
            COMMENTS=$(echo "$PR_DATA" | jq -r '.comments // []')
            if [ "$COMMENTS" != "[]" ] && [ "$(echo "$COMMENTS" | jq 'length')" -gt 0 ]; then
                echo "#### PR Comments" >> "$ISSUE_DATA_DIR/context.md"
                echo "" >> "$ISSUE_DATA_DIR/context.md"
                echo "$COMMENTS" | jq -r '.[] | "**@\(.author.login)** on \(.createdAt):\n\(.body)\n"' >> "$ISSUE_DATA_DIR/context.md" 2>/dev/null || true
            fi
            
            # Fetch review comments (inline code comments)
            echo "Fetching PR #$PR_NUM review comments..."
            REVIEW_COMMENTS=$(gh api "/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR_NUM/comments" --paginate 2>/dev/null || echo "[]")
            
            if [ "$REVIEW_COMMENTS" != "[]" ] && [ "$(echo "$REVIEW_COMMENTS" | jq 'length')" -gt 0 ]; then
                echo "#### Code Review Comments" >> "$ISSUE_DATA_DIR/context.md"
                echo "" >> "$ISSUE_DATA_DIR/context.md"
                echo "$REVIEW_COMMENTS" | jq -r '.[] | "**@\(.user.login)** on `\(.path):\(.line)`:\n\(.body)\n"' >> "$ISSUE_DATA_DIR/context.md" 2>/dev/null || true
            fi
        fi
    done
fi

# Download images from issue body and comments
echo "Extracting and downloading images..."
mkdir -p "$ISSUE_DATA_DIR/images"

# Create image mapping file
IMAGE_MAP="$ISSUE_DATA_DIR/image_map.txt"
> "$IMAGE_MAP"

# Function to extract and download images
download_images() {
    local text="$1"
    local prefix="$2"
    local count=0
    
    # Extract markdown image links ![alt](url) with alt text preserved
    echo "$text" | grep -oE '!\[([^\]]*)\]\(([^)]+)\)' | while IFS= read -r match; do
        alt_text=$(echo "$match" | sed -E 's/!\[([^\]]*)\]\(([^)]+)\)/\1/')
        url=$(echo "$match" | sed -E 's/!\[([^\]]*)\]\(([^)]+)\)/\2/')
        
        if [[ "$url" =~ ^https?:// ]]; then
            count=$((count + 1))
            ext="${url##*.}"
            ext="${ext%%\?*}" # Remove query params
            [[ "$ext" =~ ^(jpg|jpeg|png|gif|webp|svg)$ ]] || ext="png"
            
            # Try to use alt text or URL filename for better naming
            if [[ "$alt_text" =~ \.(png|jpg|jpeg|svg|gif)$ ]]; then
                # Alt text looks like a filename, use it
                filename="${alt_text// /_}"
            elif [[ "$url" =~ /([^/]+\.(png|jpg|jpeg|svg|gif))(\?|$) ]]; then
                # Extract filename from URL
                filename=$(echo "$url" | sed -E 's/.*\/([^/]+\.(png|jpg|jpeg|svg|gif))(\?.*)?$/\1/')
            else
                # Fallback to generic naming
                filename="${prefix}_${count}.${ext}"
            fi
            
            echo "  Downloading: $url -> $filename"
            curl -sL "$url" -o "$ISSUE_DATA_DIR/images/$filename" || echo "  Failed to download: $url"
            
            # Save mapping for agent reference
            echo "$filename|$alt_text|$url" >> "$IMAGE_MAP"
        fi
    done
    
    # Extract HTML img tags <img src="url">
    echo "$text" | grep -oE '<img[^>]+src="([^"]+)"' | sed -E 's/<img[^>]+src="([^"]+)"/\1/' | while read -r url; do
        if [[ "$url" =~ ^https?:// ]]; then
            count=$((count + 1))
            ext="${url##*.}"
            ext="${ext%%\?*}"
            [[ "$ext" =~ ^(jpg|jpeg|png|gif|webp|svg)$ ]] || ext="png"
            filename="${prefix}_${count}.${ext}"
            echo "  Downloading: $url -> $filename"
            curl -sL "$url" -o "$ISSUE_DATA_DIR/images/$filename" || echo "  Failed to download: $url"
        fi
    done
}

# Download images from issue body
download_images "$ISSUE_BODY" "issue"

# Download images from comments
jq -r '.[].body // ""' "$ISSUE_DATA_DIR/comments.json" 2>/dev/null | while IFS= read -r comment; do
    download_images "$comment" "comment"
done

# List downloaded images
IMAGE_COUNT=$(find "$ISSUE_DATA_DIR/images" -type f 2>/dev/null | wc -l)
echo "Downloaded $IMAGE_COUNT images"

# Add image information to context
if [ "$IMAGE_COUNT" -gt 0 ]; then
    echo "" >> "$ISSUE_DATA_DIR/context.md"
    echo "## Attached Images" >> "$ISSUE_DATA_DIR/context.md"
    echo "" >> "$ISSUE_DATA_DIR/context.md"
    echo "The following images were downloaded to $ISSUE_DATA_DIR/images/:" >> "$ISSUE_DATA_DIR/context.md"
    echo "" >> "$ISSUE_DATA_DIR/context.md"
    
    if [ -f "$IMAGE_MAP" ]; then
        while IFS='|' read -r filename alt_text url; do
            echo "- **$filename**: $alt_text" >> "$ISSUE_DATA_DIR/context.md"
        done < "$IMAGE_MAP"
    else
        ls -1 "$ISSUE_DATA_DIR/images/" | while read -r img; do
            echo "- $img" >> "$ISSUE_DATA_DIR/context.md"
        done
    fi
    
    echo "" >> "$ISSUE_DATA_DIR/context.md"
    echo "Note: Based on the issue description, identify which images are 'old' vs 'new' by their filenames or by analyzing their content." >> "$ISSUE_DATA_DIR/context.md"
fi

# Export paths for other scripts
echo "ISSUE_CONTEXT_FILE=$ISSUE_DATA_DIR/context.md" >> $GITHUB_ENV
echo "ISSUE_IMAGES_DIR=$ISSUE_DATA_DIR/images" >> $GITHUB_ENV
echo "ISSUE_DATA_DIR=$ISSUE_DATA_DIR" >> $GITHUB_ENV

# Save PR numbers if any
if [ "$PR_COUNT" -gt 0 ]; then
    PR_NUMBERS=$(echo "$ALL_PRS" | jq -r '.[].number' | tr '\n' ',' | sed 's/,$//')
    echo "ASSOCIATED_PR_NUMBERS=$PR_NUMBERS" >> $GITHUB_ENV
    echo "Associated PRs: $PR_NUMBERS"
fi

echo "Issue data prepared at: $ISSUE_DATA_DIR"