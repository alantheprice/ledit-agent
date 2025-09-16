#!/bin/bash
set -e

echo "Running ledit agent..."

# Debug: Print environment variables
if [ "$LEDIT_DEBUG" == "true" ]; then
    echo "DEBUG: AI_PROVIDER=$AI_PROVIDER"
    echo "DEBUG: AI_MODEL=$AI_MODEL"
    echo "DEBUG: AI_API_KEY=${AI_API_KEY:0:10}..." # Print first 10 chars for security
fi

# Set default paths if not already set
if [ -z "$ISSUE_CONTEXT_FILE" ]; then
    ISSUE_CONTEXT_FILE="/tmp/ledit-issue-$ISSUE_NUMBER/context.md"
fi
if [ -z "$ISSUE_IMAGES_DIR" ]; then
    ISSUE_IMAGES_DIR="/tmp/ledit-issue-$ISSUE_NUMBER/images"
fi

# Initialize workspace
cd "$LEDIT_WORKSPACE"

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

# Verify API key is set before running
case "$AI_PROVIDER" in
    openai)
        if [ -z "$OPENAI_API_KEY" ]; then
            echo "❌ ERROR: OPENAI_API_KEY is not set for provider 'openai'"
            exit 1
        fi
        ;;
    openrouter)
        if [ -z "$OPENROUTER_API_KEY" ]; then
            echo "❌ ERROR: OPENROUTER_API_KEY is not set for provider 'openrouter'"
            exit 1
        fi
        ;;
    groq)
        if [ -z "$GROQ_API_KEY" ]; then
            echo "❌ ERROR: GROQ_API_KEY is not set for provider 'groq'"
            exit 1
        fi
        ;;
    deepinfra)
        if [ -z "$DEEPINFRA_API_KEY" ]; then
            echo "❌ ERROR: DEEPINFRA_API_KEY is not set for provider 'deepinfra'"
            exit 1
        fi
        ;;
    cerebras)
        if [ -z "$CEREBRAS_API_KEY" ]; then
            echo "❌ ERROR: CEREBRAS_API_KEY is not set for provider 'cerebras'"
            exit 1
        fi
        ;;
    deepseek)
        if [ -z "$DEEPSEEK_API_KEY" ]; then
            echo "❌ ERROR: DEEPSEEK_API_KEY is not set for provider 'deepseek'"
            exit 1
        fi
        ;;
    anthropic)
        if [ -z "$ANTHROPIC_API_KEY" ]; then
            echo "❌ ERROR: ANTHROPIC_API_KEY is not set for provider 'anthropic'"
            exit 1
        fi
        ;;
    ollama)
        # Ollama doesn't need API key
        ;;
esac

# Run ledit agent with timeout and provider/model flags
echo "Starting ledit agent with ${LEDIT_TIMEOUT_MINUTES} minute timeout..."
echo "Using model: $AI_MODEL with provider: $AI_PROVIDER"

# Create a temporary file to capture the output
OUTPUT_FILE=$(mktemp)

# Run ledit and capture output
timeout "${LEDIT_TIMEOUT_MINUTES}m" ledit agent --provider "$AI_PROVIDER" --model "$AI_MODEL" "$PROMPT" 2>&1 | tee "$OUTPUT_FILE"
EXIT_CODE=${PIPESTATUS[0]}

# Check for specific error patterns in the output
if grep -q "API error.*401.*not authorized" "$OUTPUT_FILE"; then
    echo "❌ ERROR: Authentication failed - API key is invalid or missing"
    rm -f "$OUTPUT_FILE"
    exit 1
fi

if grep -q "API error.*403.*forbidden" "$OUTPUT_FILE"; then
    echo "❌ ERROR: Access forbidden - API key may not have required permissions"
    rm -f "$OUTPUT_FILE"
    exit 1
fi

# Extract cost information if available
COST_LINE=$(grep -o "💰.*\$[0-9.]*" "$OUTPUT_FILE" | tail -1 || true)
if [ -n "$COST_LINE" ]; then
    # Extract just the dollar amount
    COST=$(echo "$COST_LINE" | grep -o "\$[0-9.]*" | tail -1)
    echo "LEDIT_COST=$COST" >> $GITHUB_ENV
fi

# Clean up temp file
rm -f "$OUTPUT_FILE"

# Handle exit codes
if [ $EXIT_CODE -ne 0 ]; then
    if [ $EXIT_CODE -eq 124 ]; then
        echo "⏱️ Ledit agent timed out after ${LEDIT_TIMEOUT_MINUTES} minutes"
        exit 1
    else
        echo "❌ Ledit agent failed with exit code: $EXIT_CODE"
        exit $EXIT_CODE
    fi
fi

echo "Ledit agent completed successfully"