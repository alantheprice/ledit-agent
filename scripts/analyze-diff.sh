#!/bin/bash
set -e

echo "Analyzing PR diff with ledit..."

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

CRITICAL ASSERTION VALIDATION REQUIREMENT:
Before marking ANY issue as a problem, you MUST:
1. Double-check the assertion by examining the actual code
2. Verify the issue exists in the current codebase state
3. Confirm the issue will actually cause problems (not just theoretical)
4. Use available tools (cat, grep, rg, find) to validate your claims
5. Only mark as an issue if you can demonstrate it with concrete evidence
6. Ask yourself: "Will this actually break something in practice?"
7. Provide specific examples of how the issue would manifest

EVIDENCE-BASED REPORTING REQUIREMENT:
Every issue reported MUST include:
- Specific file path and line numbers where the issue occurs
- Exact code snippet that demonstrates the problem
- Explanation of how this would cause a real-world failure
- Evidence from the actual codebase (not just assumptions)

DO NOT report issues based on:
- Assumptions about code behavior without verification
- Theoretical problems that won't manifest in practice
- Minor type issues that don't affect functionality
- Style preferences or conventions that don't cause bugs
- Potential issues that cannot be demonstrated with concrete evidence

IMPORTANT: The context.md file contains full details of any linked GitHub issues that this PR addresses. 
- The linked issues section includes the complete issue title, description, and comments
- You DO NOT need to search elsewhere for issue context - it's all in context.md
- If issues are linked, you MUST:
  1. Verify the implementation actually solves the stated problems in the linked issues
  2. Check if all requirements from the issue are met
  3. Flag any missing functionality as a "major" or "critical" issue

Your task is to identify ALL issues that NEED TO BE FIXED - this is a COMPREHENSIVE review. 
DO NOT stop after finding the first issue. Continue analyzing until you are confident you've found all significant problems.

For very large PRs (200+ lines changed), maintain an external tracking system to capture all findings:
- Keep a running list of issues in PR_DATA_DIR_PLACEHOLDER/issues_found.txt
- Log each issue as you find it to prevent loss during context limitations
- This helps ensure comprehensive coverage even when context window is limited

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

Severity levels (use these precisely to avoid overuse of 'critical'):

CRITICAL SEVERITY - USE EXTREMELY SPARINGLY:
Only use "critical" for issues that WILL DEFINITELY cause:
- Production crashes or system failures (null pointer exceptions, divide by zero, infinite loops)
- Data loss or corruption (SQL injection, missing authentication on sensitive data)
- Security breaches that can be exploited immediately
- Memory leaks that will crash the system
- Complete failure of core functionality

DO NOT use "critical" for:
- Type issues that don't affect functionality
- Style or convention problems
- Theoretical security concerns that cannot be exploited
- Performance issues that don't cause system failure
- Missing error handling in non-critical paths

MAJOR SEVERITY - For real functional problems:
- Bugs that break features or incorrect business logic
- Security vulnerabilities in non-critical paths
- Performance issues that significantly impact users
- Missing error handling that could cause problems
- Authentication or authorization bypasses

MINOR SEVERITY - Code quality issues:
- Inconsistent error handling that doesn't break functionality
- Unused variables, poor naming conventions
- Missing input validation in non-critical code
- Code organization or maintainability issues

SUGGESTION SEVERITY - Nice improvements only:
- Code organization, minor optimizations
- Documentation improvements
- Style improvements (only for low threshold)

Start by:
1. Reading the context and diff files to understand the changes
2. Exploring the actual codebase to verify any claims made in the PR
3. Writing your review to the specified files

Verify any claims made in the PR by checking the actual codebase:
- Dependencies and libraries mentioned
- Files and directories referenced
- Features and functionality described
- Any technical claims or implementation details

REVIEW GUIDELINES FOR THOROUGHNESS:
- Look for patterns of issues (multiple files with similar problems)
- Check for edge cases that might not be obvious
- Validate that all claims in the PR description are correct
- Ensure implementation matches requirements from linked issues
- Look for potential logic errors that might not cause immediate failures but are problematic
- Check for missing error handling or validation
- Verify that any new features are properly tested
- Look for security vulnerabilities that could be missed in a cursory review

CONTINUOUS ANALYSIS:
- Keep asking yourself "What else could be wrong?"
- Don't assume things are correct just because they look fine at first glance
- Re-read your findings to make sure you haven't missed anything
- Even if you find one critical issue, keep looking for more
- Your goal is to find ALL significant problems, not just the most obvious ones

EXTERNAL TRACKING FOR LARGE REVIEWS:
- For large PRs (>200 lines changed), maintain an external issues log:
  - Create PR_DATA_DIR_PLACEHOLDER/issues_found.txt to track all findings
  - Log each issue as discovered to prevent loss due to context limitations
  - This ensures comprehensive coverage regardless of context window size

Remember: You are being paid to find issues, not to praise code. Focus on what needs improvement, not what's good.
PROMPT_EOF

# Replace placeholders with actual values
sed -i "s|PR_NUMBER_PLACEHOLDER|$PR_NUMBER|g" "$PROMPT_FILE"
sed -i "s|PR_DATA_DIR_PLACEHOLDER|$PR_DATA_DIR|g" "$PROMPT_FILE"
sed -i "s|COMMENT_THRESHOLD_PLACEHOLDER|$COMMENT_THRESHOLD|g" "$PROMPT_FILE"
sed -i "s|REVIEW_TYPE_PLACEHOLDER|$REVIEW_TYPE|g" "$PROMPT_FILE"

# Add optional action instructions if provided
if [ -n "$REVIEW_ACTION" ] && [ "$REVIEW_ACTION" != "null" ] && [ "$REVIEW_ACTION" != "" ]; then
    echo "" >> "$PROMPT_FILE"
    echo "ADDITIONAL REVIEW INSTRUCTIONS:" >> "$PROMPT_FILE"
    echo "$REVIEW_ACTION" >> "$PROMPT_FILE"
    echo "" >> "$PROMPT_FILE"
fi

# Debug: Check if prompt was written correctly
echo "Prompt written to: $PROMPT_FILE"
echo "Prompt length: $(wc -c < "$PROMPT_FILE") characters"
echo "First 100 chars of prompt: $(head -c 100 "$PROMPT_FILE")"

# Debug: Check if context files exist
echo "Checking context files..."
if [ -f "$PR_DATA_DIR/context.md" ]; then
    echo "✅ Context file exists: $PR_DATA_DIR/context.md"
    echo "Context file size: $(wc -c < "$PR_DATA_DIR/context.md") bytes"
    
    # Check if context file indicates an error
    if grep -qi "ERROR\|WARNING.*Unable to fetch\|Limited Information" "$PR_DATA_DIR/context.md"; then
        echo "⚠️  Context file indicates PR fetch failure - review will be limited"
        echo "PR_FETCH_FAILED=true" >> $GITHUB_ENV
    fi
else
    echo "❌ Context file missing: $PR_DATA_DIR/context.md"
fi

if [ -f "$PR_DATA_DIR/full.diff" ]; then
    echo "✅ Diff file exists: $PR_DATA_DIR/full.diff"
    echo "Diff file size: $(wc -c < "$PR_DATA_DIR/full.diff") bytes"
    
    # Check if diff file indicates an error
    if grep -qi "Unable to fetch diff\|ERROR\|WARNING" "$PR_DATA_DIR/full.diff"; then
        echo "⚠️  Diff file indicates fetch failure - reviewing current code state"
        echo "DIFF_FETCH_FAILED=true" >> $GITHUB_ENV
    fi
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
echo "🔧 CHECKPOINT: Starting diff file checks"
if [ -f "$PR_DATA_DIR/full.diff" ]; then
    echo "🔧 CHECKPOINT: Diff file exists, extracting added files"
    # Extract first few added files from the diff (handle case where no files match)
    ADDED_FILES=$(grep -E "^\+\+\+ b/" "$PR_DATA_DIR/full.diff" | head -3 | sed 's/^+++ b\///' | grep -v "^/dev/null" || true)
    echo "🔧 CHECKPOINT: Found added files: $ADDED_FILES"
    
    if [ -n "$ADDED_FILES" ]; then
        echo "🔧 CHECKPOINT: Checking if added files exist in current checkout"
        MISSING_COUNT=0
        for file in $ADDED_FILES; do
            if [ ! -f "$file" ]; then
                MISSING_COUNT=$((MISSING_COUNT + 1))
                echo "🔧 Missing file: $file"
            else
                echo "🔧 Found file: $file"
            fi
        done
        echo "🔧 CHECKPOINT: File check complete, missing count: $MISSING_COUNT"
        
        if [ "$MISSING_COUNT" -gt 0 ]; then
            echo "⚠️  WARNING: Some files being added in this PR don't exist in the current checkout."
            echo "⚠️  This usually means the base branch was checked out instead of the PR branch."
            echo "⚠️  The review may incorrectly report files as missing."
            echo ""
        fi
    fi
else
    echo "🔧 CHECKPOINT: No diff file found"
fi
echo "🔧 CHECKPOINT: Finished diff file checks"

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

# Create the audit prompt for the second workflow step: verify finding accuracy before publishing
AUDIT_PROMPT_FILE="$PR_DATA_DIR/audit-prompt.txt"
cat > "$AUDIT_PROMPT_FILE" << AUDIT_PROMPT_INNER_EOF
You have just completed a code review for PR #${PR_NUMBER}. Now audit your own findings for accuracy before they are published.

Read your review results from: ${PR_DATA_DIR}/review.json

For EVERY finding marked 'critical' or 'major':
1. Re-examine the actual code at the specified file and line number using cat/grep/rg
2. Verify the issue definitively exists and will cause the stated problem in real-world usage
3. Confirm the severity is warranted:
   - 'critical' = will cause production crashes, data loss, or immediately exploitable security vulnerabilities
   - 'major' = real bugs that break features, genuine security vulnerabilities, significant performance degradation
4. If the finding cannot be demonstrated with concrete evidence in the actual code, DOWNGRADE it

Common false positives to catch and correct:
- Type mismatches labeled 'critical' that do not cause runtime failures in this language/framework
- Security concerns labeled 'critical' that require privileged access to exploit or cannot be triggered by an attacker
- Performance issues labeled 'critical' that do not cause system crashes or data loss
- Missing error handling labeled 'critical' in edge-case or non-critical code paths
- Race conditions that are theoretical but not practically triggerable
- Issues that exist in pre-existing code that was NOT changed by this PR

After completing your audit:
1. Rewrite ${PR_DATA_DIR}/review.json with corrected, accurate severity levels
2. Reassess 'approval_status': if only minor/suggestion-level issues remain, change to 'approve' or 'comment' instead of 'request_changes'
3. Update ${PR_DATA_DIR}/summary.md to reflect the audited, accurate findings

Accuracy matters: missing a minor issue is preferable to incorrectly alarming engineers with a false 'critical' finding.
AUDIT_PROMPT_INNER_EOF

# Create a two-step review workflow: initial review then accuracy audit
WORKFLOW_FILE="$PR_DATA_DIR/review-workflow.json"
cat > "$WORKFLOW_FILE" << WORKFLOW_JSON_INNER_EOF
{
  "continue_on_error": true,
  "persist_runtime_overrides": false,
  "initial": {
    "prompt_file": "${PROMPT_FILE}",
    "persona": "code_reviewer",
    "provider": "${AI_PROVIDER}",
    "model": "${AI_MODEL}",
    "max_iterations": ${MAX_ITERATIONS:-80},
    "skip_prompt": true,
    "no_stream": true
  },
  "steps": [
    {
      "name": "audit_review_accuracy",
      "when": "on_success",
      "persona": "code_reviewer",
      "reasoning_effort": "high",
      "max_iterations": 40,
      "skip_prompt": true,
      "no_stream": true,
      "prompt_file": "${AUDIT_PROMPT_FILE}"
    }
  ]
}
WORKFLOW_JSON_INNER_EOF

# Debug: Show workflow command that will be executed
echo "=== FINAL COMMAND DEBUG ==="
echo "Command: timeout ${LEDIT_TIMEOUT_MINUTES:-10}m ledit agent --no-stream --workflow-config '$WORKFLOW_FILE'"
echo ""
echo "Workflow: 2-step review + accuracy audit"
echo "  Step 1 (initial): code_reviewer persona - ${MAX_ITERATIONS:-80} max iterations"
echo "  Step 2 (audit):   code_reviewer persona - 40 max iterations, reasoning_effort=high"
echo ""
echo "Environment:"
echo "  DEEPINFRA_API_KEY: ${DEEPINFRA_API_KEY:+SET (${#DEEPINFRA_API_KEY} chars)}${DEEPINFRA_API_KEY:-NOT SET}"
echo "  Working directory: $(pwd)"
echo "  Ledit version: $(ledit --version 2>/dev/null || echo 'version check failed')"
echo ""
echo "Files:"
echo "  Prompt file:  $PROMPT_FILE ($(wc -c < "$PROMPT_FILE") chars)"
echo "  Audit file:   $AUDIT_PROMPT_FILE ($(wc -c < "$AUDIT_PROMPT_FILE") chars)"
echo "  Context file: $PR_DATA_DIR/context.md ($([ -f "$PR_DATA_DIR/context.md" ] && wc -c < "$PR_DATA_DIR/context.md" || echo 0) chars)"
echo "  Diff file:    $PR_DATA_DIR/full.diff ($([ -f "$PR_DATA_DIR/full.diff" ] && wc -c < "$PR_DATA_DIR/full.diff" || echo 0) chars)"
echo "  Workflow:     $WORKFLOW_FILE"
echo "============================"

echo "Running ledit review+audit workflow..."
echo "🚀 EXECUTING LEDIT WORKFLOW NOW..."

# Create temporary file for output capture
REVIEW_OUTPUT=$(mktemp)
echo "🔧 Output will be captured to: $REVIEW_OUTPUT"

set -x  # Enable command tracing

# Run the two-step review workflow: step 1 reviews the PR, step 2 audits findings for accuracy
timeout "${LEDIT_TIMEOUT_MINUTES:-10}m" ledit agent --no-stream --workflow-config "$WORKFLOW_FILE" 2>&1 | tee "$REVIEW_OUTPUT"
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
echo "🔧 CHECKPOINT: Validating review.json"
if [ -f "$PR_DATA_DIR/review.json" ]; then
    echo "🔧 review.json exists, checking JSON validity..."
    if jq -e . "$PR_DATA_DIR/review.json" > /dev/null 2>&1; then
        echo "✅ Review analysis completed successfully"
    else
        echo "⚠️ Warning: JSON validation failed"
        echo "🔧 JSON content preview:"
        head -10 "$PR_DATA_DIR/review.json" || echo "Could not read file"
        echo "🔧 JQ error:"
        jq . "$PR_DATA_DIR/review.json" 2>&1 || echo "JQ command failed"
    fi
else
    echo "❌ review.json file missing"
fi

if [ -f "$PR_DATA_DIR/review.json" ] && jq -e . "$PR_DATA_DIR/review.json" > /dev/null 2>&1; then
    echo "✅ Final validation: Review analysis completed successfully"
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