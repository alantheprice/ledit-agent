#!/bin/bash
set -e

echo "Running ledit agent..."

# Debug: Print environment variables
if [ "$LEDIT_DEBUG" == "true" ]; then
    echo "DEBUG: AI_PROVIDER=$AI_PROVIDER"
    echo "DEBUG: AI_MODEL=$AI_MODEL"
fi

# Validate required environment variables
if [ -z "$LEDIT_WORKSPACE" ]; then
    echo "❌ ERROR: LEDIT_WORKSPACE is not set"
    exit 1
fi

if [ -z "$ISSUE_NUMBER" ]; then
    echo "❌ ERROR: ISSUE_NUMBER is not set"
    exit 1
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

# Build the prompt for ledit
PROMPT="You are helping to solve GitHub issue #$ISSUE_NUMBER from the repository $GITHUB_REPOSITORY.

The issue context and details have been saved to: $ISSUE_CONTEXT_FILE
This file includes:
- Issue description and comments
- Any associated Pull Requests with their reviews and feedback
- Code review comments from PRs

Images from the issue (if any) have been saved to: $ISSUE_IMAGES_DIR

IMPORTANT: You are working on branch '$BRANCH_NAME' which follows the pattern 'issue/<number>'.

Your task:
1. Read the issue context from $ISSUE_CONTEXT_FILE (includes PR feedback if any)
2. Analyze any images in $ISSUE_IMAGES_DIR using the vision tools
3. Implement the necessary changes to solve the issue
4. Address any PR review feedback mentioned in the context
5. Follow the repository's code style and conventions
6. Add tests if appropriate

If there are existing PRs with feedback, make sure to address the review comments.

CRITICAL: If you see 'Inline Code Review Comments' in the context, these are specific file/line issues that MUST be fixed. Address each one by:
1. Navigating to the specified file and line
2. Understanding the issue raised
3. Implementing the requested fix
4. Do not consider the task complete until ALL inline comments are addressed

For image-related tasks:
- Check the image mapping in the context to understand which image is which
- Use vision tools to analyze image content if filenames aren't clear
- When replacing images/assets, find the current implementation first
- Copy new image files to the appropriate asset directories
- Update all references to point to the new images
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

# Write the solve prompt to a temp file for the workflow config
SOLVE_PROMPT_FILE=$(mktemp --suffix="-solve-prompt.txt")
printf '%s\n' "$PROMPT" > "$SOLVE_PROMPT_FILE"

# Create a verification audit prompt: after implementation, check completeness against requirements
SOLVE_AUDIT_FILE=$(mktemp --suffix="-solve-audit.txt")
cat > "$SOLVE_AUDIT_FILE" << SOLVE_AUDIT_INNER_EOF
You are reviewing the implementation just completed for GitHub issue #${ISSUE_NUMBER}.

1. Re-read the original issue requirements from: ${ISSUE_CONTEXT_FILE}
2. Examine the changes made in this branch (use git diff HEAD~1 or check recently modified files)
3. Confirm every requirement stated in the issue is addressed
4. Check that every 'Inline Code Review Comment' referenced in the context has been resolved
5. If the project has a build/test command (e.g. 'go build ./...', 'npm test', 'pytest', 'cargo check'), run it and report the result

Write a brief verification report to ${LEDIT_WORKSPACE}/.ledit-verify.md covering:
- Requirements met / not met
- Any missing functionality or unresolved review comments
- Build/test result (pass, fail, or skipped if no test runner found)

Be factual and concise. Do not rewrite code — report only.
SOLVE_AUDIT_INNER_EOF

# Create a fix prompt for the third workflow step: orchestrator resolves issues found by the code reviewer
SOLVE_FIX_FILE=$(mktemp --suffix="-solve-fix.txt")
cat > "$SOLVE_FIX_FILE" << SOLVE_FIX_INNER_EOF
The code reviewer has completed a verification pass and written a report to ${LEDIT_WORKSPACE}/.ledit-verify.md.

Read that report now. For every item listed as 'not met', 'missing', or 'failed':
1. Resolve the gap — implement the missing functionality, fix the failing build/test, or address the unresolved review comment
2. Re-run any build or test command from the report to confirm the fix
3. Update ${LEDIT_WORKSPACE}/.ledit-verify.md to mark each resolved item as fixed

If the report shows everything is met and the build passes, there is nothing to do — just confirm that in the report.
SOLVE_FIX_INNER_EOF

# Create a three-step solve workflow: implement → review → fix
SOLVE_WORKFLOW_FILE=$(mktemp --suffix="-solve-workflow.json")
cat > "$SOLVE_WORKFLOW_FILE" << SOLVE_WORKFLOW_INNER_EOF
{
  "continue_on_error": false,
  "persist_runtime_overrides": false,
  "initial": {
    "prompt_file": "${SOLVE_PROMPT_FILE}",
    "persona": "orchestrator",
    "provider": "${AI_PROVIDER}",
    "model": "${AI_MODEL}",
    "max_iterations": ${MAX_ITERATIONS:-180},
    "skip_prompt": true,
    "no_stream": true
  },
  "steps": [
    {
      "name": "verify_implementation",
      "when": "on_success",
      "persona": "code_reviewer",
      "reasoning_effort": "high",
      "max_iterations": 40,
      "skip_prompt": true,
      "no_stream": true,
      "prompt_file": "${SOLVE_AUDIT_FILE}"
    },
    {
      "name": "fix_review_findings",
      "when": "on_success",
      "file_exists": ["${LEDIT_WORKSPACE}/.ledit-verify.md"],
      "persona": "orchestrator",
      "max_iterations": 90,
      "skip_prompt": true,
      "no_stream": true,
      "prompt_file": "${SOLVE_FIX_FILE}"
    }
  ]
}
SOLVE_WORKFLOW_INNER_EOF

# Run ledit agent with two-step solve workflow
echo "Starting ledit agent with ${LEDIT_TIMEOUT_MINUTES} minute timeout..."
echo "Using model: $AI_MODEL with provider: $AI_PROVIDER"
echo "Running 3-step workflow: orchestrate solution (${MAX_ITERATIONS:-180} iterations) + code_reviewer verify (40 iterations) + orchestrator fix (90 iterations)"

# Create a temporary file to capture the output
OUTPUT_FILE=$(mktemp)

# Run ledit workflow and capture output
timeout "${LEDIT_TIMEOUT_MINUTES}m" ledit agent --no-stream --workflow-config "$SOLVE_WORKFLOW_FILE" 2>&1 | tee "$OUTPUT_FILE"
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

# Clean up temp files
rm -f "$OUTPUT_FILE" "$SOLVE_PROMPT_FILE" "$SOLVE_AUDIT_FILE" "$SOLVE_FIX_FILE" "$SOLVE_WORKFLOW_FILE"

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