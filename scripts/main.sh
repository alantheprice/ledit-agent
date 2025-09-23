#!/bin/bash
set -e

# Main orchestration script for ledit issue solver

echo "🤖 Ledit Issue Solver Starting..."

# Determine if this is triggered by a /ledit command
IS_LEDIT_COMMAND="false"
USER_PROMPT=""
ISSUE_NUMBER=""

if [ "$GITHUB_EVENT_NAME" == "issue_comment" ]; then
    # Check if comment starts with /ledit
    COMMENT_BODY=$(jq -r '.comment.body' "$GITHUB_EVENT_PATH")
    if [[ "$COMMENT_BODY" =~ ^/ledit(.*)$ ]]; then
        IS_LEDIT_COMMAND="true"
        USER_PROMPT="${BASH_REMATCH[1]}"
        USER_PROMPT="${USER_PROMPT#"${USER_PROMPT%%[![:space:]]*}"}" # Trim leading whitespace
        ISSUE_NUMBER=$(jq -r '.issue.number' "$GITHUB_EVENT_PATH")
        echo "Detected /ledit command with prompt: $USER_PROMPT"
    fi
elif [ "$GITHUB_EVENT_NAME" == "workflow_dispatch" ] || [ "$GITHUB_EVENT_NAME" == "issues" ]; then
    # Manual trigger or issue event
    ISSUE_NUMBER=$(jq -r '.issue.number // .inputs.issue_number // empty' "$GITHUB_EVENT_PATH")
fi

if [ -z "$ISSUE_NUMBER" ]; then
    echo "ERROR: No issue number found"
    exit 1
fi

# Validate optional variables have proper defaults
if [ -z "$USER_PROMPT" ]; then
    USER_PROMPT=""
fi

# Set default branch name pattern
export BRANCH_NAME="issue/$ISSUE_NUMBER"

# Validate ENABLE_MCP has a proper value
if [ -z "$ENABLE_MCP" ]; then
    ENABLE_MCP="false"
elif [ "$ENABLE_MCP" != "true" ] && [ "$ENABLE_MCP" != "false" ]; then
    echo "WARNING: ENABLE_MCP should be 'true' or 'false', got '$ENABLE_MCP'. Defaulting to 'false'"
    ENABLE_MCP="false"
fi

echo "Processing issue #$ISSUE_NUMBER"

# Export for other scripts
export ISSUE_NUMBER
export USER_PROMPT
export ENABLE_MCP

# Step 1: Fetch issue details
echo "📋 Fetching issue details..."
$LEDIT_ACTION_PATH/scripts/fetch-issue.sh

# Step 2: Create or checkout branch
echo "🌿 Setting up branch..."
$LEDIT_ACTION_PATH/scripts/setup-branch.sh

# Step 3: Run ledit agent
echo "🧠 Running ledit agent..."
if ! $LEDIT_ACTION_PATH/scripts/run-ledit.sh; then
    echo "❌ Ledit agent failed to run successfully"
    # Report failure to issue
    $LEDIT_ACTION_PATH/scripts/report-status.sh "agent-failed"
    exit 1
fi

# Check if ledit made any changes
if [ -n "$(git status --porcelain)" ]; then
    echo "✅ Changes detected, creating PR..."
    
    # Step 4: Create commit
    $LEDIT_ACTION_PATH/scripts/create-commit.sh
    
    # Step 5: Create or update PR
    $LEDIT_ACTION_PATH/scripts/manage-pr.sh
    
    echo "success=true" >> $GITHUB_OUTPUT
else
    echo "ℹ️ No changes were made by ledit"
    echo "success=false" >> $GITHUB_OUTPUT
    
    # Still report back to the issue
    $LEDIT_ACTION_PATH/scripts/report-status.sh "no-changes"
fi

echo "🎯 Ledit Issue Solver completed"