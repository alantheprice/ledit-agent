#!/bin/bash
set -e

echo "======================================"
echo "🚨 UPDATED SCRIPT IS RUNNING! 🚨"
echo "🔧 SCRIPT VERSION: analyze-diff.sh v1.01"
echo "📅 Script timestamp: $(date)"
echo "📁 Script path: ${BASH_SOURCE[0]}"
echo "======================================"
echo "Analyzing PR diff with ledit..."

# Set API key environment variable based on provider
case "$AI_PROVIDER" in
    openai)
        export OPENAI_API_KEY="$AI_API_KEY"
        ;;
    openrouter)
        export OPENROUTER_API_KEY="$AI_API_KEY"
        ;;
    deepinfra)
        export DEEPINFRA_API_KEY="$AI_API_KEY"
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
echo "Building prompt for PR review..."

# Write the prompt directly to a file
PROMPT_FILE="$PR_DATA_DIR/prompt.txt"
cat > "$PROMPT_FILE" << 'PROMPT_EOF'
You are an expert code reviewer helping to review GitHub Pull Request #PR_NUMBER_PLACEHOLDER.

The PR context and diff have been saved to: PR_DATA_DIR_PLACEHOLDER/context.md and PR_DATA_DIR_PLACEHOLDER/full.diff

You are running in the actual repository at the root directory, so you have FULL ACCESS to explore the codebase to verify claims.
Your current working directory is the repository root. You can use standard commands to explore and verify the codebase.

DO NOT make assumptions based only on the diff - validate everything against the actual code.

IMPORTANT: The context.md file contains linked GitHub issues if this PR claims to fix any. If issues are linked:
1. Verify the implementation actually solves the stated problems
2. Check if all requirements from the issue are met
3. Flag any missing functionality as a "major" or "critical" issue

Your task is to identify issues that NEED TO BE FIXED. Only comment on actual problems, not observations.

Comment threshold is 'COMMENT_THRESHOLD_PLACEHOLDER':
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

Based on review type 'REVIEW_TYPE_PLACEHOLDER':
- comprehensive: Look for all types of issues
- security: Focus only on security issues
- performance: Focus only on performance issues
- style: Skip review if comment threshold is medium/high

CRITICAL: You have full access to the codebase. Use the following tools to validate claims:
- Use 'find' or 'ls' to check if files/directories mentioned in the README actually exist
- Use 'cat' or 'grep' to verify technology claims (e.g., check package.json for dependencies)
- Use 'rg' (ripgrep) to search for specific implementations across the codebase
- DO NOT make assumptions - verify everything against the actual code

After analyzing the PR and validating against the codebase, write your review to these files:
1. Write the JSON review object to: PR_DATA_DIR_PLACEHOLDER/review.json
2. Write a 2-3 sentence human-readable summary to: PR_DATA_DIR_PLACEHOLDER/summary.md

The JSON format should be:
{
  "summary": "Brief 1-2 sentence assessment of issues found (or 'No issues found')",
  "approval_status": "approve|request_changes|comment",
  "comments": [
    {
      "file": "path/to/file.js",
      "line": 42,
      "side": "RIGHT",
      "body": "Specific issue that needs fixing and how to fix it",
      "severity": "critical|major|minor|suggestion"
    }
  ],
  "general_feedback": "Only if there are broader architectural concerns"
}

Severity levels (match to comment threshold):
- critical: Will cause crashes, data loss, or security breaches
- major: Bugs that affect functionality or moderate security risks
- minor: Code quality issues that should be fixed
- suggestion: Nice-to-have improvements (only for low threshold)

Start by:
1. Reading the context and diff files to understand the changes
2. Exploring the actual codebase to verify any claims made in the PR
3. Writing your review to the specified files

Verify any claims made in the PR by checking the actual codebase:
- Dependencies and libraries mentioned
- Files and directories referenced
- Features and functionality described
- Any technical claims or implementation details
PROMPT_EOF

# Replace placeholders with actual values
sed -i "s|PR_NUMBER_PLACEHOLDER|$PR_NUMBER|g" "$PROMPT_FILE"
sed -i "s|PR_DATA_DIR_PLACEHOLDER|$PR_DATA_DIR|g" "$PROMPT_FILE"
sed -i "s|COMMENT_THRESHOLD_PLACEHOLDER|$COMMENT_THRESHOLD|g" "$PROMPT_FILE"
sed -i "s|REVIEW_TYPE_PLACEHOLDER|$REVIEW_TYPE|g" "$PROMPT_FILE"

# Debug: Check if prompt was written correctly
echo "Prompt written to: $PROMPT_FILE"
echo "Prompt length: $(wc -c < "$PROMPT_FILE") characters"
echo "First 100 chars of prompt: $(head -c 100 "$PROMPT_FILE")"

# Debug: Check if context files exist
echo "Checking context files..."
if [ -f "$PR_DATA_DIR/context.md" ]; then
    echo "✅ Context file exists: $PR_DATA_DIR/context.md"
    echo "Context file size: $(wc -c < "$PR_DATA_DIR/context.md") bytes"
else
    echo "❌ Context file missing: $PR_DATA_DIR/context.md"
fi

if [ -f "$PR_DATA_DIR/full.diff" ]; then
    echo "✅ Diff file exists: $PR_DATA_DIR/full.diff"
    echo "Diff file size: $(wc -c < "$PR_DATA_DIR/full.diff") bytes"
else
    echo "❌ Diff file missing: $PR_DATA_DIR/full.diff"
fi

# Debug: Check environment variables
echo "Debug environment:"
echo "AI_PROVIDER=$AI_PROVIDER"
echo "AI_MODEL=$AI_MODEL"
echo "LEDIT_TIMEOUT_MINUTES=${LEDIT_TIMEOUT_MINUTES:-10}"
echo "MAX_ITERATIONS=${MAX_ITERATIONS:-80}"
echo "GITHUB_WORKSPACE=$GITHUB_WORKSPACE"
echo "🔍 About to proceed with ledit command checks..."

# Check if files from the PR diff actually exist (indicates correct branch)
if [ -f "$PR_DATA_DIR/full.diff" ]; then
    # Extract first few added files from the diff
    ADDED_FILES=$(grep -E "^\+\+\+ b/" "$PR_DATA_DIR/full.diff" | head -3 | sed 's/^+++ b\///' | grep -v "^/dev/null")
    
    if [ -n "$ADDED_FILES" ]; then
        MISSING_COUNT=0
        for file in $ADDED_FILES; do
            if [ ! -f "$file" ]; then
                ((MISSING_COUNT++))
            fi
        done
        
        if [ "$MISSING_COUNT" -gt 0 ]; then
            echo "⚠️  WARNING: Some files being added in this PR don't exist in the current checkout."
            echo "⚠️  This usually means the base branch was checked out instead of the PR branch."
            echo "⚠️  The review may incorrectly report files as missing."
            echo ""
        fi
    fi
fi

# Debug: Check if ledit command works
echo "🔍 Checking if ledit command is available..."
echo "PATH: $PATH"
if ! command -v ledit &> /dev/null; then
    echo "❌ ERROR: ledit command not found in PATH"
    echo "which ledit: $(which ledit 2>&1 || echo 'which command failed')"
    echo "ls /home/runner/go/bin/: $(ls -la /home/runner/go/bin/ 2>&1 || echo 'directory not found')"
    exit 1
else
    echo "✅ ledit command found at: $(which ledit)"
fi

# Debug: Test basic ledit functionality
# echo "Testing ledit command..."
# if ! ledit --version 2>&1; then
#     echo "❌ ERROR: ledit --version failed"
#     exit 1
# fi

# Debug: Show final command that will be executed
echo "=== FINAL COMMAND DEBUG ==="
echo "Command: timeout ${LEDIT_TIMEOUT_MINUTES:-10}m ledit agent \\"
echo "  --provider '$AI_PROVIDER' \\"
echo "  --model '$AI_MODEL' \\"
echo "  --max-iterations ${MAX_ITERATIONS:-180} \\"
echo "  'prompt from $PROMPT_FILE'"
echo ""
echo "Environment:"
echo "  DEEPINFRA_API_KEY: ${DEEPINFRA_API_KEY:+SET (${#DEEPINFRA_API_KEY} chars)}${DEEPINFRA_API_KEY:-NOT SET}"
echo "  Working directory: $(pwd)"
echo "  Ledit version: $(ledit --version 2>/dev/null || echo 'version check failed')"
echo ""
echo "Files:"
echo "  Prompt file: $PROMPT_FILE ($(wc -c < "$PROMPT_FILE") chars)"
echo "  Context file: $PR_DATA_DIR/context.md ($([ -f "$PR_DATA_DIR/context.md" ] && wc -c < "$PR_DATA_DIR/context.md" || echo 0) chars)"
echo "  Diff file: $PR_DATA_DIR/full.diff ($([ -f "$PR_DATA_DIR/full.diff" ] && wc -c < "$PR_DATA_DIR/full.diff" || echo 0) chars)"
echo "============================"

echo "Running ledit agent with timeout..."
echo "🚀 EXECUTING LEDIT COMMAND NOW..."
set -x  # Enable command tracing

# Run the ledit command and capture both stdout and stderr
timeout "${LEDIT_TIMEOUT_MINUTES:-10}m" ledit agent --provider "$AI_PROVIDER" --model "$AI_MODEL" --max-iterations "${MAX_ITERATIONS:-180}" "$(cat "$PROMPT_FILE")" 2>&1 | tee "$REVIEW_OUTPUT"
EXIT_CODE=${PIPESTATUS[0]}

set +x  # Disable command tracing

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Ledit command completed successfully"
else
    echo "❌ Ledit command failed with exit code: $EXIT_CODE"
    echo "🔍 IMMEDIATE ERROR INVESTIGATION:"
    
    # Show the full output for debugging
    echo "=== FULL LEDIT OUTPUT (last 100 lines) ==="
    if [ -f "$REVIEW_OUTPUT" ]; then
        tail -100 "$REVIEW_OUTPUT" 2>/dev/null || echo "Failed to read output file"
    else
        echo "❌ No output file created at: $REVIEW_OUTPUT"
    fi
    echo "=== END LEDIT OUTPUT ==="
    
    # Check for specific error patterns
    if [ -f "$REVIEW_OUTPUT" ]; then
        echo "=== ERROR ANALYSIS ==="
        
        if grep -qi "401\|unauthorized\|invalid.*key" "$REVIEW_OUTPUT"; then
            echo "🔑 AUTHENTICATION ERROR: API key is invalid or missing"
        elif grep -qi "403\|forbidden\|permission" "$REVIEW_OUTPUT"; then
            echo "🚫 AUTHORIZATION ERROR: API key lacks required permissions"
        elif grep -qi "404\|not found" "$REVIEW_OUTPUT"; then
            echo "❓ NOT FOUND ERROR: Model or endpoint not found"
        elif grep -qi "429\|rate.*limit\|quota" "$REVIEW_OUTPUT"; then
            echo "⏱️ RATE LIMIT ERROR: Too many requests"
        elif grep -qi "timeout\|timed out" "$REVIEW_OUTPUT"; then
            echo "⏱️ TIMEOUT ERROR: Request took too long"
        elif grep -qi "connection\|network\|dns" "$REVIEW_OUTPUT"; then
            echo "🌐 CONNECTION ERROR: Network connectivity issue"
        elif grep -qi "model.*not.*available\|model.*error" "$REVIEW_OUTPUT"; then
            echo "🤖 MODEL ERROR: Issue with the specified model"
        elif grep -qi "error\|failed" "$REVIEW_OUTPUT"; then
            echo "❓ GENERIC ERROR DETECTED: Check the full output above"
        else
            echo "❓ NO OBVIOUS ERROR PATTERN: Exit code $EXIT_CODE with no clear error message"
        fi
        
        echo "=== END ERROR ANALYSIS ==="
    else
        echo "❌ CANNOT ANALYZE: Output file missing"
    fi
    
    echo "💡 Troubleshooting tips:"
    echo "   1. Verify your API key is valid and has the right permissions"
    echo "   2. Check if the model '${AI_MODEL}' is available on ${AI_PROVIDER}"
    echo "   3. Try a different model or provider"
    echo "   4. Check network connectivity to the AI provider"
    
    # Don't remove the output file yet - keep it for debugging
    echo "📁 Debug output saved at: $REVIEW_OUTPUT"
    
    # FORCE EXIT HERE to ensure we see this error output
    exit $EXIT_CODE
fi
set +x  # Disable command tracing

if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ Ledit agent failed with exit code: $EXIT_CODE"
    echo "💡 Troubleshooting tips:"
    echo "   1. Verify your API key is valid and has the right permissions"
    echo "   2. Check if the model '${AI_MODEL}' is available on ${AI_PROVIDER}"
    echo "   3. Try a different model or provider"
    echo "   4. Check network connectivity to the AI provider"
    
    # Don't remove the output file yet - keep it for debugging
    echo "📁 Debug output saved at: $REVIEW_OUTPUT"
    exit $EXIT_CODE
fi

# Check if the agent created the review files
echo "Checking for review results..."

if [ ! -f "$PR_DATA_DIR/review.json" ]; then
    echo "⚠️ Warning: Agent did not create review.json"
    echo '{"summary": "Review failed - no output generated", "approval_status": "comment", "comments": []}' > "$PR_DATA_DIR/review.json"
fi

if [ ! -f "$PR_DATA_DIR/summary.md" ]; then
    echo "⚠️ Warning: Agent did not create summary.md"
    echo "Automated review encountered an error. Please check the logs." > "$PR_DATA_DIR/summary.md"
fi

# Validate the JSON
if jq . "$PR_DATA_DIR/review.json" > /dev/null 2>&1; then
    echo "✅ Valid JSON review found"
    echo "Review summary: $(jq -r '.summary' "$PR_DATA_DIR/review.json")"
else
    echo "⚠️ Warning: Invalid JSON in review.json"
    # Try to fix common issues
    if jq . "$PR_DATA_DIR/review.json" 2>&1 | grep -q "Invalid numeric literal"; then
        # Sometimes line numbers are strings instead of numbers
        jq 'walk(if type == "object" and has("line") then .line = (.line | tonumber) else . end)' "$PR_DATA_DIR/review.json" > "$PR_DATA_DIR/review.json.tmp" && mv "$PR_DATA_DIR/review.json.tmp" "$PR_DATA_DIR/review.json"
    fi
fi

# Extract cost information if available
COST_LINE=$(grep -o "💰.*\$[0-9.]*" "$REVIEW_OUTPUT" | tail -1 || true)
if [ -n "$COST_LINE" ]; then
    COST=$(echo "$COST_LINE" | grep -o "\$[0-9.]*" | tail -1)
    echo "REVIEW_COST=$COST" >> $GITHUB_ENV
fi

# Clean up (only remove on success)
if [ $EXIT_CODE -eq 0 ]; then
    rm -f "$REVIEW_OUTPUT"
else
    echo "📁 Preserving debug output at: $REVIEW_OUTPUT"
fi

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