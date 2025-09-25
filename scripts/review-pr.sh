#!/bin/bash
set -e

# Main orchestration script for ledit PR reviewer

echo "🔍 Ledit PR Reviewer Starting..."

# Determine PR number based on event type
if [ "$GITHUB_EVENT_NAME" == "pull_request" ]; then
    PR_NUMBER=$(jq -r '.pull_request.number' "$GITHUB_EVENT_PATH")
elif [ "$GITHUB_EVENT_NAME" == "issue_comment" ]; then
    # For /review comments on PRs
    if [ "$(jq -r '.issue.pull_request' "$GITHUB_EVENT_PATH")" != "null" ]; then
        PR_NUMBER=$(jq -r '.issue.number' "$GITHUB_EVENT_PATH")
    else
        echo "ERROR: Comment is not on a pull request"
        exit 1
    fi
else
    echo "ERROR: Unsupported event type: $GITHUB_EVENT_NAME"
    exit 1
fi

if [ -z "$PR_NUMBER" ]; then
    echo "ERROR: No PR number found"
    exit 1
fi

echo "Processing PR #$PR_NUMBER"

# Export for other scripts
export PR_NUMBER
export REVIEW_TYPE="${REVIEW_TYPE:-comprehensive}"
export COMMENT_THRESHOLD="${COMMENT_THRESHOLD:-medium}"
export SUMMARY_ONLY="${SUMMARY_ONLY:-false}"
export PR_DATA_DIR="/tmp/ledit-pr-$PR_NUMBER"

# Create data directory
mkdir -p "$PR_DATA_DIR"

# Check if we're on the correct branch for PR review
if [ -n "$GITHUB_HEAD_REF" ]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" != "$GITHUB_HEAD_REF" ]; then
        echo "⚠️  WARNING: You're on branch '$CURRENT_BRANCH' but the PR is from branch '$GITHUB_HEAD_REF'"
        echo "⚠️  The reviewer may report files as missing if they only exist in the PR branch."
        echo "⚠️  To fix this, update your workflow's checkout step to:"
        echo "⚠️    - uses: actions/checkout@v4"
        echo "⚠️      with:"
        echo "⚠️        ref: \${{ github.event.pull_request.head.ref }}"
        echo ""
    fi
fi

# Step 1: Fetch PR details and diff
echo "📋 Fetching PR details..."
# Ensure PR data directory exists
mkdir -p "$PR_DATA_DIR"

# Run fetch-pr.sh but don't exit on failure - create fallback context files if needed
if $LEDIT_ACTION_PATH/scripts/fetch-pr.sh; then
    echo "✅ PR details fetched successfully"
else
    echo "⚠️  WARNING: Failed to fetch PR details, creating fallback context files"
    
    # Create minimal context files to ensure downstream scripts work
    if [ ! -f "$PR_DATA_DIR/context.md" ]; then
        cat > "$PR_DATA_DIR/context.md" << EOF
# Pull Request #$PR_NUMBER - Limited Information

**WARNING**: Unable to fetch complete PR details. Reviewing with limited information.

## Review Instructions
- Review Type: $REVIEW_TYPE
- Comment Threshold: $COMMENT_THRESHOLD
- Summary Only: $SUMMARY_ONLY

Please review the available code changes. Some PR metadata may be missing.
EOF
    fi
    
    if [ ! -f "$PR_DATA_DIR/full.diff" ]; then
        echo "# Unable to fetch PR diff - reviewing current code state" > "$PR_DATA_DIR/full.diff"
    fi
    
    if [ ! -f "$PR_DATA_DIR/files.txt" ]; then
        echo "# Unable to fetch file list" > "$PR_DATA_DIR/files.txt"
    fi
    
    echo "Proceeding with limited review capabilities..."
fi

# Step 2: Analyze the diff with ledit
echo "🧠 Analyzing PR with AI..."
if ! $LEDIT_ACTION_PATH/scripts/analyze-diff.sh; then
    echo "❌ PR analysis failed"
    exit 1
fi

# Step 3: Post review comments
echo "💬 Posting review..."
$LEDIT_ACTION_PATH/scripts/post-review.sh

echo "🎯 Ledit PR Review completed"