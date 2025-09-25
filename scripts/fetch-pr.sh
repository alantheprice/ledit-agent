#!/bin/bash
set -e

echo "Fetching PR #$PR_NUMBER from $GITHUB_REPOSITORY..."

# Create data directory immediately to ensure context files can be created
mkdir -p "$PR_DATA_DIR"

# Check if PR exists and provide detailed debugging info
echo "Checking if PR exists..."
PR_VIEW_OUTPUT=$(gh pr view "$PR_NUMBER" 2>&1) || {
    echo "❌ ERROR: Failed to fetch PR #$PR_NUMBER"
    echo "Actual error message from GitHub CLI:"
    echo "$PR_VIEW_OUTPUT"
    echo ""
    echo "Debug info:"
    echo "  - Repository: $GITHUB_REPOSITORY"
    echo "  - PR Number: $PR_NUMBER"
    echo "  - Event: $GITHUB_EVENT_NAME"
    echo "  - Branch: $GITHUB_HEAD_REF"
    echo "  - Current branch: $(git rev-parse --abbrev-ref HEAD)"
    echo "  - GitHub token available: $([[ -n "$GITHUB_TOKEN" ]] && echo "Yes" || echo "No")"
    
    # Try to get more information about the error
    if command -v gh > /dev/null 2>&1; then
        echo "  - GitHub CLI version: $(gh --version 2>/dev/null || echo 'Not available')"
        echo "  - GitHub CLI auth status: $(gh auth status 2>/dev/null || echo 'Not available')"
    fi
    
    echo "This is a critical failure - the system cannot access the PR data needed for review."
    echo "PR review cannot proceed without PR metadata and diff information."
    echo "Please check:"
    echo "  1. The PR number is correct"
    echo "  2. The GitHub token has appropriate permissions"
    echo "  3. The repository is accessible"
    echo "  4. The workflow has proper pull request permissions"
    exit 1
}

# Fetch PR metadata including head SHA
echo "Fetching PR metadata..."
# Use minimal fields to avoid permission issues with statusCheckRollup
if ! gh pr view "$PR_NUMBER" --json number,title,body,author,baseRefName,headRefName,headRefOid,files > "$PR_DATA_DIR/metadata.json"; then
    echo "❌ ERROR: Failed to fetch PR metadata"
    echo "Debug info:"
    echo "  - PR Number: $PR_NUMBER"
    echo "  - Repository: $GITHUB_REPOSITORY"
    echo "  - Error occurred during metadata fetch"
    exit 1
fi

# Extract key information with error handling
PR_TITLE=$(jq -r '.title // "Unknown Title"' "$PR_DATA_DIR/metadata.json")
PR_BODY=$(jq -r '.body // ""' "$PR_DATA_DIR/metadata.json")
PR_AUTHOR=$(jq -r '.author.login // "Unknown Author"' "$PR_DATA_DIR/metadata.json")
BASE_BRANCH=$(jq -r '.baseRefName // "Unknown"' "$PR_DATA_DIR/metadata.json")
HEAD_BRANCH=$(jq -r '.headRefName // "Unknown"' "$PR_DATA_DIR/metadata.json")

echo "PR: $PR_TITLE"
echo "Author: $PR_AUTHOR"
echo "Base: $BASE_BRANCH <- Head: $HEAD_BRANCH"

# Fetch the full diff
echo "Fetching diff..."
if ! gh pr diff "$PR_NUMBER" > "$PR_DATA_DIR/full.diff"; then
    echo "⚠️  WARNING: Failed to fetch PR diff, creating empty diff file"
    echo "# Unable to fetch diff for PR #$PR_NUMBER" > "$PR_DATA_DIR/full.diff"
fi

# Fetch file list (simpler version without stats to avoid permission issues)
echo "Fetching file list..."
if ! gh pr view "$PR_NUMBER" --json files --jq '.files[].path' > "$PR_DATA_DIR/files.txt" 2>/dev/null; then
    echo "⚠️  WARNING: Failed to fetch file list"
    echo "# Unable to fetch file list" > "$PR_DATA_DIR/files.txt"
fi

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

# Check for linked issues
echo "Checking for linked issues..."
LINKED_ISSUES=$(mktemp)

# Method 1: Check PR body and title for issue references
echo "$PR_TITLE $PR_BODY" | grep -oE '#[0-9]+' | sed 's/#//' | sort -u > "$LINKED_ISSUES"

# Method 2: Check branch name for issue pattern
if [[ "$HEAD_BRANCH" =~ ^issue/([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}" >> "$LINKED_ISSUES"
fi

# Method 3: Use GitHub API to find linked issues (requires GraphQL)
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        closingIssuesReferences(first: 10) {
          nodes {
            number
            title
            body
            state
            labels(first: 10) {
              nodes { name }
            }
          }
        }
      }
    }
  }' -f owner="$(echo $GITHUB_REPOSITORY | cut -d'/' -f1)" \
     -f repo="$(echo $GITHUB_REPOSITORY | cut -d'/' -f2)" \
     -F pr="$PR_NUMBER" \
     --jq '.data.repository.pullRequest.closingIssuesReferences.nodes[].number' 2>/dev/null >> "$LINKED_ISSUES" || true

# Deduplicate issue numbers
UNIQUE_ISSUES=$(cat "$LINKED_ISSUES" | sort -u | grep -E '^[0-9]+$' | tr '\n' ' ')
rm -f "$LINKED_ISSUES"

# Check if we found any linked issues
if [ -n "$UNIQUE_ISSUES" ]; then
    echo "Found linked issues: $UNIQUE_ISSUES"
    ISSUE_CONTEXT=""
    
    # Fetch each linked issue
    for ISSUE_NUM in $UNIQUE_ISSUES; do
        echo "Fetching issue #$ISSUE_NUM..."
        ISSUE_DATA=$(gh issue view "$ISSUE_NUM" --json title,body,state,labels,comments 2>/dev/null || echo "{}")
        
        if [ "$ISSUE_DATA" != "{}" ]; then
            ISSUE_TITLE=$(echo "$ISSUE_DATA" | jq -r '.title // "Unknown"')
            ISSUE_BODY=$(echo "$ISSUE_DATA" | jq -r '.body // ""')
            ISSUE_STATE=$(echo "$ISSUE_DATA" | jq -r '.state // "Unknown"')
            ISSUE_LABELS=$(echo "$ISSUE_DATA" | jq -r '.labels[].name' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
            
            ISSUE_CONTEXT="$ISSUE_CONTEXT

### Issue #$ISSUE_NUM: $ISSUE_TITLE
- **State**: $ISSUE_STATE
- **Labels**: $ISSUE_LABELS

#### Issue Description:
$ISSUE_BODY"
            
            # Add key issue comments (limit to last 3 for context)
            ISSUE_COMMENT_COUNT=$(echo "$ISSUE_DATA" | jq '.comments | length' 2>/dev/null || echo "0")
            if [ "$ISSUE_COMMENT_COUNT" -gt 0 ]; then
                ISSUE_CONTEXT="$ISSUE_CONTEXT

#### Recent Issue Comments:"
                COMMENTS=$(echo "$ISSUE_DATA" | jq -r '.comments[-3:] | reverse | .[] | "**@\(.author.login)**: \(.body)\n"' 2>/dev/null || true)
                ISSUE_CONTEXT="$ISSUE_CONTEXT
$COMMENTS"
            fi
        fi
    done
else
    echo "No linked issues found"
fi

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
EOF

# Add linked issues section if any were found
if [ -n "$UNIQUE_ISSUES" ]; then
    cat >> "$PR_DATA_DIR/context.md" << EOF

## Linked Issues
$ISSUE_CONTEXT

## Issue Validation Requirements
Since this PR is linked to issue(s), please verify:
1. **Completeness**: Does the implementation fully address all requirements stated in the issue(s)?
2. **Approach**: Does the solution align with any proposed approach or discussion in the issue?
3. **Edge Cases**: Are all scenarios mentioned in the issue properly handled?
4. **Testing**: Are there adequate tests for the issue requirements?
5. **Documentation**: Is the fix properly documented if the issue mentions documentation needs?
EOF
fi

# Add review instructions
cat >> "$PR_DATA_DIR/context.md" << EOF

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
EOF

# Add issue-specific review guidance if applicable
if [ -n "$UNIQUE_ISSUES" ]; then
    cat >> "$PR_DATA_DIR/context.md" << EOF
6. **Issue Resolution Assessment**: Does this PR successfully resolve the linked issue(s)?

Focus on:
- Whether the implementation matches the issue requirements
- Any missing functionality described in the issue
- Edge cases mentioned in issue comments
EOF
else
    cat >> "$PR_DATA_DIR/context.md" << EOF

Focus on:
EOF
fi

# Complete the review instructions
cat >> "$PR_DATA_DIR/context.md" << EOF
- Correctness and functionality
- Edge cases and error handling
- Code maintainability
- Performance implications
- Security vulnerabilities
EOF

echo "PR data prepared at: $PR_DATA_DIR"