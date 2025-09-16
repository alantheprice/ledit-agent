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

# Extract review components
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
    # Extract and process comments
    COMMENTS=$(jq -c '.comments // []' "$REVIEW_JSON" 2>/dev/null || echo "[]")
    
    # Filter comments based on threshold
    FILTERED_COMMENTS=$(echo "$COMMENTS" | jq -c '[.[] | 
        select(.file != null and .line != null and (.line | type) == "number") |
        select(
            if env.COMMENT_THRESHOLD == "high" then
                .severity == "critical"
            elif env.COMMENT_THRESHOLD == "medium" then
                .severity == "critical" or .severity == "major"
            else
                true
            end
        )]' 2>/dev/null || echo "[]")
    
    COMMENT_COUNT=$(echo "$FILTERED_COMMENTS" | jq 'length' 2>/dev/null || echo "0")
    
    if [ "$COMMENT_COUNT" -gt 0 ]; then
        echo "Found $COMMENT_COUNT inline comments to post"
        
        # Get the head commit SHA
        HEAD_SHA=$(jq -r '.headRefOid // ""' "$PR_DATA_DIR/metadata.json" 2>/dev/null || echo "")
        
        # Build the comments array with severity prefixes
        FORMATTED_COMMENTS=$(echo "$FILTERED_COMMENTS" | jq -c '[.[] | {
            path: .file,
            line: .line,
            side: (.side // "RIGHT"),
            body: (
                if .severity == "critical" then "🚨 **Critical**: " + .body
                elif .severity == "major" then "⚠️ **Major**: " + .body
                elif .severity == "minor" then "💡 **Minor**: " + .body
                else "💭 **Suggestion**: " + .body
                end
            )
        }]')
        
        # Create the review with comments in a single request
        echo "Creating review with inline comments..."
        
        # Build the review request
        REVIEW_REQUEST=$(jq -n \
            --arg body "$REVIEW_BODY" \
            --arg event "$REVIEW_EVENT" \
            --arg sha "$HEAD_SHA" \
            --argjson comments "$FORMATTED_COMMENTS" \
            '{
                body: $body,
                event: $event,
                comments: $comments
            } + if $sha != "" and $sha != "null" then {commit_id: $sha} else {} end')
        
        # Post the review
        REVIEW_POSTED=false
        REVIEW_ERROR=""
        
        if REVIEW_ERROR=$(gh api \
            --method POST \
            -H "Accept: application/vnd.github+json" \
            "/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews" \
            --input - <<< "$REVIEW_REQUEST" 2>&1); then
            REVIEW_POSTED=true
            echo "Review posted successfully with inline comments"
        else
            echo "Failed to post review: $REVIEW_ERROR"
            
            # Check if it's because we can't request changes on our own PR
            if echo "$REVIEW_ERROR" | grep -q "Can not request changes on your own pull request"; then
                echo "Cannot request changes on own PR, trying with COMMENT status..."
                
                # Change event to COMMENT
                REVIEW_REQUEST=$(jq -n \
                    --arg body "$REVIEW_BODY" \
                    --arg event "COMMENT" \
                    --arg sha "$HEAD_SHA" \
                    --argjson comments "$FORMATTED_COMMENTS" \
                    '{
                        body: $body,
                        event: $event,
                        comments: $comments
                    } + if $sha != "" and $sha != "null" then {commit_id: $sha} else {} end')
                
                if gh api \
                    --method POST \
                    -H "Accept: application/vnd.github+json" \
                    "/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews" \
                    --input - <<< "$REVIEW_REQUEST" 2>&1; then
                    REVIEW_POSTED=true
                    echo "Review posted as COMMENT with inline comments"
                fi
            fi
        fi
        
        # If review still failed, post comments individually
        if [ "$REVIEW_POSTED" != "true" ]; then
            echo "Failed to post review, falling back to individual comments"
            
            # First post the summary
            gh pr comment "$PR_NUMBER" --body "$REVIEW_BODY"
            
            # Then try to post inline comments using review comment API
            echo "Posting inline comments..."
            INLINE_FAILED=false
            
            # Get the latest commit SHA if we don't have it
            if [ -z "$HEAD_SHA" ] || [ "$HEAD_SHA" == "null" ] || [ "$HEAD_SHA" == "" ]; then
                HEAD_SHA=$(gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid')
            fi
            
            echo "$FORMATTED_COMMENTS" | jq -c '.[]' | while read -r comment; do
                FILE=$(echo "$comment" | jq -r '.path')
                LINE=$(echo "$comment" | jq -r '.line')
                BODY=$(echo "$comment" | jq -r '.body')
                SIDE=$(echo "$comment" | jq -r '.side // "RIGHT"')
                
                echo "Posting inline comment on $FILE:$LINE"
                
                # Try to post as a review comment (inline)
                if ! gh api \
                    --method POST \
                    -H "Accept: application/vnd.github+json" \
                    "/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/comments" \
                    -f body="$BODY" \
                    -f commit_id="$HEAD_SHA" \
                    -f path="$FILE" \
                    -F line="$LINE" \
                    -f side="$SIDE" 2>&1; then
                    
                    # If inline comment fails, post as regular comment
                    COMMENT_BODY="📍 **\`$FILE:$LINE\`**

$BODY"
                    
                    echo "Inline comment failed, posting as regular PR comment"
                    gh pr comment "$PR_NUMBER" --body "$COMMENT_BODY" || echo "Failed to post comment for $FILE:$LINE"
                fi
            done
        fi
    else
        # No inline comments, just post the review
        echo "No inline comments, posting review summary"
        if ! gh pr review "$PR_NUMBER" --body "$REVIEW_BODY" --$( echo "$REVIEW_EVENT" | tr '[:upper:]' '[:lower:]' | tr '_' '-' ) 2>&1; then
            echo "Failed to post review, trying as comment"
            gh pr comment "$PR_NUMBER" --body "$REVIEW_BODY"
        fi
    fi
    
else
    # Summary only mode
    echo "Summary-only mode, posting as comment"
    gh pr comment "$PR_NUMBER" --body "$REVIEW_BODY"
fi

echo "Review posted successfully"