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

# Step 1: Fetch PR details and diff
echo "📋 Fetching PR details..."
$LEDIT_ACTION_PATH/scripts/fetch-pr.sh

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