#!/bin/bash
set -e

echo "Running ledit agent..."

# Initialize workspace
cd "$LEDIT_WORKSPACE"

# Create .ledit directory if it doesn't exist
mkdir -p .ledit

# Copy API keys configuration if it exists
if [ -f ~/.ledit/api_keys.json ]; then
    cp ~/.ledit/api_keys.json .ledit/
fi

# Create config.json with the model configuration
cat > .ledit/config.json << EOF
{
  "editing_model": "$AI_MODEL",
  "summary_model": "$AI_MODEL", 
  "workspace_analysis_model": "$AI_MODEL",
  "orchestration_model": "$AI_MODEL",
  "code_review_model": "$AI_MODEL",
  "embedding_model": "$AI_MODEL",
  "autotrack": false,
  "check_for_keys": false,
  "provider": "$AI_PROVIDER"
}
EOF

# Set the appropriate API key environment variable based on provider
case "$AI_PROVIDER" in
    openai)
        export OPENAI_API_KEY="$AI_API_KEY"
        ;;
    openrouter)
        export OPENROUTER_API_KEY="$AI_API_KEY"
        ;;
    groq)
        export GROQ_API_KEY="$AI_API_KEY"
        ;;
    deepinfra)
        export DEEPINFRA_API_KEY="$AI_API_KEY"
        ;;
    cerebras)
        export CEREBRAS_API_KEY="$AI_API_KEY"
        ;;
    deepseek)
        export DEEPSEEK_API_KEY="$AI_API_KEY"
        ;;
    anthropic)
        export ANTHROPIC_API_KEY="$AI_API_KEY"
        ;;
    ollama)
        # Ollama doesn't need API key
        ;;
    *)
        echo "ERROR: Unknown AI provider: $AI_PROVIDER"
        exit 1
        ;;
esac

# Build the prompt for ledit
PROMPT="You are helping to solve GitHub issue #$ISSUE_NUMBER from the repository $GITHUB_REPOSITORY.

The issue context and details have been saved to: $ISSUE_CONTEXT_FILE
Images from the issue (if any) have been saved to: $ISSUE_IMAGES_DIR

IMPORTANT: You are working on branch '$BRANCH_NAME' which follows the pattern 'issue/<number>'.

Your task:
1. Read the issue context from $ISSUE_CONTEXT_FILE
2. Analyze any images in $ISSUE_IMAGES_DIR using the vision tools
3. Implement the necessary changes to solve the issue
4. Follow the repository's code style and conventions
5. Add tests if appropriate

"

# Add user-specific prompt if provided
if [ -n "$USER_PROMPT" ]; then
    PROMPT+="
Additional instructions from the user: $USER_PROMPT
"
fi

# Add MCP instructions if enabled
if [ "$ENABLE_MCP" == "true" ]; then
    PROMPT+="
You have access to GitHub MCP tools. You can use these to:
- Check the PR status using the branch name '$BRANCH_NAME'
- Read PR comments and feedback
- View CI/CD check results
- Update the PR description if needed
"
fi

PROMPT+="
Start by reading the issue context to understand what needs to be done."

# Run ledit agent with timeout
echo "Starting ledit agent with ${LEDIT_TIMEOUT_MINUTES} minute timeout..."
timeout "${LEDIT_TIMEOUT_MINUTES}m" ledit agent "$PROMPT" || {
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 124 ]; then
        echo "⏱️ Ledit agent timed out after ${LEDIT_TIMEOUT_MINUTES} minutes"
        exit 1
    else
        echo "❌ Ledit agent failed with exit code: $EXIT_CODE"
        exit $EXIT_CODE
    fi
}

echo "Ledit agent completed successfully"