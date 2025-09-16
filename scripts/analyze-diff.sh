#!/bin/bash
set -e

echo "Analyzing PR diff with ledit..."

# Set API key environment variable based on provider
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
PROMPT="You are an expert code reviewer helping to review GitHub Pull Request #$PR_NUMBER.

The PR context and diff have been saved to: $PR_DATA_DIR/context.md and $PR_DATA_DIR/full.diff

Your review should be thorough but constructive. Focus on:
1. Bugs and potential issues
2. Security vulnerabilities
3. Performance concerns
4. Code quality and maintainability
5. Best practices and patterns

Based on the review type '$REVIEW_TYPE', adjust your focus:
- comprehensive: Review all aspects thoroughly
- security: Focus primarily on security issues
- performance: Focus on performance implications
- style: Focus on code style and conventions

Comment threshold is '$COMMENT_THRESHOLD':
- low: Comment on everything, including minor style issues
- medium: Comment on significant issues and improvements
- high: Only comment on critical bugs or major concerns

Output format:
1. First, provide a JSON object with your findings structured as:
{
  \"summary\": \"Overall assessment of the PR\",
  \"approval_status\": \"approve|request_changes|comment\",
  \"comments\": [
    {
      \"file\": \"path/to/file.js\",
      \"line\": 42,
      \"side\": \"RIGHT\",
      \"body\": \"Your comment here\",
      \"severity\": \"critical|major|minor|suggestion\"
    }
  ],
  \"general_feedback\": \"Additional feedback not tied to specific lines\"
}

2. Then provide a human-readable summary for the PR comment.

Start by reading the context and diff files."

# Create a temporary file to capture output
REVIEW_OUTPUT=$(mktemp)

# Run ledit agent with review focus
echo "Starting ledit agent for review..."
timeout "${LEDIT_TIMEOUT_MINUTES:-10}m" ledit agent --provider "$AI_PROVIDER" --model "$AI_MODEL" "$PROMPT" 2>&1 | tee "$REVIEW_OUTPUT"
EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ Ledit agent failed with exit code: $EXIT_CODE"
    rm -f "$REVIEW_OUTPUT"
    exit $EXIT_CODE
fi

# Extract JSON from the output (looking for the JSON block)
echo "Extracting review results..."
awk '/^{/,/^}/' "$REVIEW_OUTPUT" > "$PR_DATA_DIR/review.json" || true

# Extract human-readable summary (everything after the JSON)
awk 'BEGIN{p=0} /^}$/{p=1;next} p==1' "$REVIEW_OUTPUT" > "$PR_DATA_DIR/summary.md" || true

# Extract cost information if available
COST_LINE=$(grep -o "💰.*\$[0-9.]*" "$REVIEW_OUTPUT" | tail -1 || true)
if [ -n "$COST_LINE" ]; then
    COST=$(echo "$COST_LINE" | grep -o "\$[0-9.]*" | tail -1)
    echo "REVIEW_COST=$COST" >> $GITHUB_ENV
fi

# Clean up
rm -f "$REVIEW_OUTPUT"

# Validate that we got valid JSON
if [ -f "$PR_DATA_DIR/review.json" ] && jq -e . "$PR_DATA_DIR/review.json" > /dev/null 2>&1; then
    echo "✅ Review analysis completed successfully"
else
    echo "⚠️ Warning: Could not extract valid JSON review data"
    # Create a minimal review.json for fallback
    cat > "$PR_DATA_DIR/review.json" << EOF
{
  "summary": "Automated review could not parse detailed feedback. See summary for details.",
  "approval_status": "comment",
  "comments": [],
  "general_feedback": "Please check the action logs for the full review output."
}
EOF
fi

echo "Review results saved to: $PR_DATA_DIR/review.json"