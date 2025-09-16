#!/bin/bash
set -e

echo "Posting review comments..."

# Load review data
REVIEW_JSON="$PR_DATA_DIR/review.json"
SUMMARY_MD="$PR_DATA_DIR/summary.md"

if [ ! -f "$REVIEW_JSON" ]; then
    echo "ERROR: Review results not found"
    exit 1
fi

# Extract review components (analyze-diff.sh already validated the JSON)
APPROVAL_STATUS=$(jq -r '.approval_status // "comment"' "$REVIEW_JSON")
SUMMARY=$(jq -r '.summary // "Automated review completed"' "$REVIEW_JSON")
GENERAL_FEEDBACK=$(jq -r '.general_feedback // ""' "$REVIEW_JSON")

# Check if this is the bot's own PR
CURRENT_USER=$(gh api /user --jq '.login' 2>/dev/null || echo "unknown")
PR_AUTHOR=$(gh pr view "$PR_NUMBER" --json author --jq '.author.login' 2>/dev/null || echo "unknown")

# Map approval status to GitHub review event
case "$APPROVAL_STATUS" in
    "approve")
        # Can't approve own PRs - downgrade to comment
        if [ "$CURRENT_USER" == "$PR_AUTHOR" ] || [[ "$PR_AUTHOR" == *"github-actions"* ]]; then
            echo "Note: Cannot approve own PR, posting as comment instead"
            REVIEW_EVENT="COMMENT"
        else
            REVIEW_EVENT="APPROVE"
        fi
        ;;
    "request_changes")
        REVIEW_EVENT="REQUEST_CHANGES"
        ;;
    *)
        REVIEW_EVENT="COMMENT"
        ;;
esac

# Build review body
REVIEW_BODY="## 🤖 Automated Code Review

$SUMMARY"

# Add human-readable summary if available
if [ -f "$SUMMARY_MD" ] && [ -s "$SUMMARY_MD" ]; then
    REVIEW_BODY="$REVIEW_BODY

$(cat "$SUMMARY_MD")"
fi

# Add general feedback if available
if [ -n "$GENERAL_FEEDBACK" ] && [ "$GENERAL_FEEDBACK" != "null" ]; then
    REVIEW_BODY="$REVIEW_BODY

### 📝 General Feedback
$GENERAL_FEEDBACK"
fi

# Add metadata
REVIEW_BODY="$REVIEW_BODY

---
**Review by**: [ledit-agent](https://github.com/alantheprice/ledit-agent)
**Model**: $AI_MODEL via $AI_PROVIDER"

# Add cost if available
if [ -n "$REVIEW_COST" ] && [ "$REVIEW_COST" != "$0.00" ]; then
    REVIEW_BODY="$REVIEW_BODY
**Cost**: $REVIEW_COST"
fi

# Check if we should post inline comments
if [ "$SUMMARY_ONLY" != "true" ]; then
    # Extract comments array
    COMMENTS_FILE=$(mktemp)
    jq -c '.comments // []' "$REVIEW_JSON" > "$COMMENTS_FILE"
    
    # Validate and clean comments
    CLEANED_COMMENTS=$(mktemp)
    jq -c '.[] | select(.file != null and .line != null and (.line | type) == "number")' "$COMMENTS_FILE" > "$CLEANED_COMMENTS" 2>/dev/null || true
    mv "$CLEANED_COMMENTS" "$COMMENTS_FILE"
    
    # Count valid comments
    COMMENT_COUNT=$(jq -s '. | length' "$COMMENTS_FILE" 2>/dev/null || echo "0")
    
    if [ "$COMMENT_COUNT" -gt 0 ]; then
        echo "Found $COMMENT_COUNT inline comments to post"
        
        # Create a review with comments
        # Get the head commit SHA
        HEAD_SHA=$(jq -r '.headRefOid // ""' "$PR_DATA_DIR/metadata.json")
        
        # First, create a pending review
        REVIEW_CREATE_ARGS=(
            --method POST
            -H "Accept: application/vnd.github+json"
            "/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews"
            -f body="$REVIEW_BODY"
            -f event="PENDING"
        )
        
        # Add commit SHA if available
        if [ -n "$HEAD_SHA" ] && [ "$HEAD_SHA" != "null" ]; then
            REVIEW_CREATE_ARGS+=(-f commit_id="$HEAD_SHA")
        fi
        
        REVIEW_ID=$(gh api "${REVIEW_CREATE_ARGS[@]}" --jq '.id' 2>/dev/null || echo "")
        
        if [ -n "$REVIEW_ID" ] && [ "$REVIEW_ID" != "null" ]; then
            echo "Created pending review: $REVIEW_ID"
            
            # Add each comment to the review
            cat "$COMMENTS_FILE" | while read -r comment; do
                FILE=$(echo "$comment" | jq -r '.file')
                LINE=$(echo "$comment" | jq -r '.line')
                SIDE=$(echo "$comment" | jq -r '.side // "RIGHT"')
                BODY=$(echo "$comment" | jq -r '.body')
                SEVERITY=$(echo "$comment" | jq -r '.severity // "suggestion"')
                
                # Filter comments based on threshold - only post actionable issues
                case "$COMMENT_THRESHOLD" in
                    "high")
                        # High threshold: Only critical issues that must be fixed
                        if [ "$SEVERITY" != "critical" ]; then
                            continue
                        fi
                        ;;
                    "medium")
                        # Medium threshold: Moderate risk issues and above
                        if [ "$SEVERITY" == "suggestion" ] || [ "$SEVERITY" == "minor" ]; then
                            continue
                        fi
                        ;;
                    "low")
                        # Low threshold: All issues including nitpicks, but no positive feedback
                        # Skip any purely positive comments
                        if echo "$BODY" | grep -qiE "^[[:space:]]*(excellent|great|good job|well.*(done|written)|nice|perfect|correct|appropriate)[[:space:]]*[\.!]?[[:space:]]*$"; then
                            continue
                        fi
                        # Skip comments that don't suggest any changes
                        if ! echo "$BODY" | grep -qiE "(should|could|consider|recommend|suggest|fix|change|update|improve|avoid|don't|issue|problem|error|warning|missing|incorrect|wrong)"; then
                            continue
                        fi
                        ;;
                esac
                
                # Add severity emoji to comment
                case "$SEVERITY" in
                    "critical")
                        BODY="🚨 **Critical**: $BODY"
                        ;;
                    "major")
                        BODY="⚠️ **Major**: $BODY"
                        ;;
                    "minor")
                        BODY="💡 **Minor**: $BODY"
                        ;;
                    "suggestion")
                        BODY="💭 **Suggestion**: $BODY"
                        ;;
                esac
                
                # Validate required fields
                if [ -z "$FILE" ] || [ -z "$LINE" ] || [ "$LINE" == "null" ] || [ "$FILE" == "null" ]; then
                    echo "Skipping comment with invalid file/line: $FILE:$LINE"
                    continue
                fi
                
                # Ensure line is a number
                if ! [[ "$LINE" =~ ^[0-9]+$ ]]; then
                    echo "Skipping comment with non-numeric line: $LINE"
                    continue
                fi
                
                # Post the comment
                echo "Adding comment on $FILE:$LINE (severity: $SEVERITY)"
                if ! gh api \
                    --method POST \
                    -H "Accept: application/vnd.github+json" \
                    "/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews/$REVIEW_ID/comments" \
                    -f body="$BODY" \
                    -f path="$FILE" \
                    -F line="$LINE" \
                    -f side="$SIDE" 2>&1; then
                    echo "Failed to add comment on $FILE:$LINE - continuing with other comments"
                fi
            done
            
            # Submit the review
            echo "Submitting review with status: $REVIEW_EVENT"
            gh api \
                --method POST \
                -H "Accept: application/vnd.github+json" \
                "/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews/$REVIEW_ID/events" \
                -f event="$REVIEW_EVENT" > /dev/null
        else
            echo "Failed to create review, falling back to simple comment"
            gh pr comment "$PR_NUMBER" --body "$REVIEW_BODY"
        fi
    else
        # No inline comments, just post the review
        echo "No inline comments, posting review summary"
        if ! gh pr review "$PR_NUMBER" --body "$REVIEW_BODY" --$( echo "$REVIEW_EVENT" | tr '[:upper:]' '[:lower:]' | tr '_' '-' ) 2>&1; then
            echo "Failed to post review, trying as comment"
            gh pr comment "$PR_NUMBER" --body "$REVIEW_BODY"
        fi
    fi
    
    rm -f "$COMMENTS_FILE"
else
    # Summary only mode
    echo "Summary-only mode, posting as comment"
    gh pr comment "$PR_NUMBER" --body "$REVIEW_BODY"
fi

echo "Review posted successfully"