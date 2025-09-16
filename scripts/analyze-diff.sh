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

Your task is to identify issues that NEED TO BE FIXED. Only comment on actual problems, not observations.

Comment threshold is '$COMMENT_THRESHOLD':
- high: ONLY critical issues (will break production, security vulnerabilities, data loss risks)
- medium: Moderate risks (bugs, security concerns, significant performance issues, logic errors)  
- low: All issues including code quality, but still ONLY things that need fixing (no nitpicks)

DO NOT comment on:
- Code that works correctly
- Style preferences or conventions (unless they cause bugs)
- Minor improvements or optimizations
- Positive feedback or acknowledgments
- Things that are "fine as-is"

ONLY comment on problems that need fixing:
1. Bugs and logic errors
2. Security vulnerabilities  
3. Performance issues that will cause problems
4. Missing critical error handling
5. Incorrect implementations

For documentation:
- ONLY comment on factual errors or broken links
- Skip style/formatting unless it makes docs unusable

Maximum comments by PR size:
- 1-10 lines: 1 comment max
- 10-50 lines: 3 comments max
- 50-200 lines: 5 comments max
- 200+ lines: 10 comments max

These are MAXIMUMS. If there are no issues, make NO comments.

Based on review type '$REVIEW_TYPE':
- comprehensive: Look for all types of issues
- security: Focus only on security issues
- performance: Focus only on performance issues
- style: Skip review if comment threshold is medium/high

Output format:
FIRST output this exact line: === JSON START ===
Then output ONLY the JSON object (no markdown code blocks):
{
  \"summary\": \"Brief 1-2 sentence assessment of issues found (or 'No issues found')\",
  \"approval_status\": \"approve|request_changes|comment\",
  \"comments\": [
    {
      \"file\": \"path/to/file.js\",
      \"line\": 42,
      \"side\": \"RIGHT\",
      \"body\": \"Specific issue that needs fixing and how to fix it\",
      \"severity\": \"critical|major|minor|suggestion\"
    }
  ],
  \"general_feedback\": \"Only if there are broader architectural concerns\"
}
Then output this exact line: === JSON END ===

Severity levels (use these to match comment threshold):
- critical: Will cause crashes, data loss, or security breaches
- major: Bugs that affect functionality or moderate security risks
- minor: Code quality issues that should be fixed
- suggestion: Nice-to-have improvements (only for low threshold)

After the JSON, provide a brief human-readable summary (2-3 sentences max) for the PR comment.

Start by reading the context and diff files."

# Create a temporary file for the prompt
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

# Create a temporary file to capture output
REVIEW_OUTPUT=$(mktemp)

# Run ledit agent with review focus using stdin for the prompt
echo "Starting ledit agent for review..."
timeout "${LEDIT_TIMEOUT_MINUTES:-10}m" ledit agent --provider "$AI_PROVIDER" --model "$AI_MODEL" < "$PROMPT_FILE" 2>&1 | tee "$REVIEW_OUTPUT"
EXIT_CODE=${PIPESTATUS[0]}

# Clean up prompt file
rm -f "$PROMPT_FILE"

if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ Ledit agent failed with exit code: $EXIT_CODE"
    rm -f "$REVIEW_OUTPUT"
    exit $EXIT_CODE
fi

# Extract JSON from the output using the markers
echo "Extracting review results..."
sed -n '/=== JSON START ===/,/=== JSON END ===/p' "$REVIEW_OUTPUT" | grep -v "=== JSON" > "$PR_DATA_DIR/review.json" || true

# Extract human-readable summary (everything after JSON END marker)
sed -n '/=== JSON END ===/,$p' "$REVIEW_OUTPUT" | tail -n +2 > "$PR_DATA_DIR/summary.md" || true

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