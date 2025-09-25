# Ledit Agent - AI-Powered GitHub Automation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automatically solve GitHub issues and review pull requests using AI-powered code analysis with [ledit](https://github.com/alantheprice/ledit).

## Features

### Issue Solving
- 🤖 **AI-Powered Implementation** - Analyzes issues and generates complete solutions
- 🖼️ **Vision Support** - Processes mockups and screenshots to implement UIs
- 🔄 **Iterative Development** - Refine implementations with follow-up commands
- 🌿 **Smart Git Management** - Creates branches and pull requests automatically
- 🔗 **PR-Aware Context** - Automatically includes PR reviews and feedback when working on issues
- 🔄 **Auto-Review Integration** - Optionally trigger PR reviews automatically after solving issues

### Code Review
- 🔍 **Comprehensive PR Analysis** - Thorough review of code changes
- 💬 **Inline Comments** - Specific feedback on exact lines of code
- 🎯 **Configurable Focus** - Security, performance, style, or comprehensive
- 📊 **Severity Levels** - Critical, major, minor, and suggestions
- 🔗 **Issue Validation** - Verifies PR actually solves linked issues

### General
- 🔧 **Multi-Provider Support** - Works with OpenAI, Groq, Gemini, DeepInfra, and more
- 🛡️ **Secure by Design** - All changes go through PR review process
- 💰 **Cost Tracking** - See AI costs for each operation

## Quick Start

> **⚠️ IMPORTANT for PR Reviews**: Always check out the PR branch, not the base branch:
> ```yaml
> - uses: actions/checkout@v4
>   with:
>     ref: ${{ github.event.pull_request.head.ref }}
> ```
> Without this, the reviewer will incorrectly report that new files don't exist.

### For Issue Solving

Create `.github/workflows/ledit-solve.yml` in your repository:

```yaml
name: Ledit Issue Solver

on:
  issue_comment:
    types: [created]

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  solve-issue:
    if: |
      github.event.issue.pull_request == null && 
      contains(github.event.comment.body, '/ledit')
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: alantheprice/ledit-agent@v1
        with:
          mode: 'solve'  # This is the default
          ai-provider: 'openai'
          ai-model: 'gpt-4o-mini'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          ai-api-key: ${{ secrets.OPENAI_API_KEY }}
```

### For PR Reviews

Create `.github/workflows/ledit-review.yml` in your repository:

```yaml
name: Ledit PR Review

on:
  pull_request:
    types: [opened, synchronize]
  issue_comment:
    types: [created]

permissions:
  contents: read
  pull-requests: write

jobs:
  review-pr:
    if: |
      (github.event_name == 'pull_request' && !github.event.pull_request.draft) ||
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '/review'))
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
        with:
          # IMPORTANT: Check out the PR branch, not the base branch
          ref: ${{ github.event.pull_request.head.ref || github.ref }}
          fetch-depth: 0
          
      - uses: alantheprice/ledit-agent@v1
        with:
          mode: 'review'
          ai-provider: 'deepinfra'
          ai-model: 'deepseek-ai/DeepSeek-V3.1'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          ai-api-key: ${{ secrets.DEEPINFRA_API_KEY }}
          review-type: 'comprehensive'
          comment-threshold: 'medium'
```

### 2. Configure Repository Permissions

**Important**: By default, GitHub Actions cannot create pull requests. You need to enable this:

1. Go to **Settings** → **Actions** → **General**
2. Scroll down to **Workflow permissions**
3. Select **Read and write permissions**
4. Check **Allow GitHub Actions to create and approve pull requests**
5. Click **Save**

### 3. Add API Key

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add your API key (name depends on provider):
   - OpenAI: `OPENAI_API_KEY`
   - Groq: `GROQ_API_KEY`
   - Gemini: `GEMINI_API_KEY`
   - DeepInfra: `DEEPINFRA_API_KEY`

### 4. Use It!

1. Create an issue describing what you want
2. Comment `/ledit` to trigger the agent
3. Watch as it creates a branch, implements the solution, and opens a PR

## Supported Providers

### OpenAI
```yaml
ai-provider: 'openai'
ai-model: 'gpt-5'          # Most capable
ai-model: 'gpt-5-mini'     # Cost-effective for an openai model
ai-api-key: ${{ secrets.OPENAI_API_KEY }}
```

### DeepInfra
```yaml
ai-provider: 'deepinfra'
ai-model: 'Qwen/Qwen3-Coder-480B-A35B-Instruct-Turbo'  # fast and capable
ai-model: 'deepseek-ai/DeepSeek-V3.1'                  # Slower, but excellent for complex reasoning
ai-model: 'moonshotai/Kimi-K2-Instruct-0905'           # Very capable, slightly higher cost
ai-api-key: ${{ secrets.DEEPINFRA_API_KEY }}
```


### OpenRouter
Open router does have multiple free models available, but they are slow and can run into rate limiting issues.
```yaml
ai-provider: 'openrouter'
ai-model: 'qwen/qwen3-coder-30b-a3b-instruct'          # Smallest and cheapest model, does handle some tasks, but might not perform well in complex tasks due to the smaller model size.
# Huge number of model options available both free and paid.
ai-api-key: ${{ secrets.OPENROUTER_API_KEY }}
```


## Usage Examples

### Basic Implementation
```markdown
**Issue**: Create a hello world function

**Comment**: /ledit
```

### With Additional Instructions
```markdown
**Issue**: Add user authentication

**Comment**: /ledit use JWT tokens and bcrypt for passwords
```

### UI from Mockup
```markdown
**Issue**: Implement this dashboard design
[Attach mockup image]

**Comment**: /ledit use React with Tailwind CSS
```

### Iterative Refinement
```markdown
**Issue**: Create REST API

**Comment**: /ledit
**Later**: /ledit add input validation
**Later**: /ledit add rate limiting
```

### PR Review Examples

#### Automatic Review on PR
When you open or update a PR, the bot automatically reviews it if you have the workflow configured.

#### Manual Review Request
```markdown
**PR Comment**: /review
```

#### Focused Review
```markdown
**PR Comment**: /review focus on security
```



## Alternative: Using Personal Access Token (PAT)

If you prefer not to enable PR creation for GitHub Actions, you can use a Personal Access Token:

1. [Create a PAT](https://github.com/settings/tokens) with `repo` scope
2. Add it as a secret named `GH_PAT`
3. Update your workflow:

```yaml
- uses: alantheprice/ledit-agent@v1
  with:
    github-token: ${{ secrets.GH_PAT }}  # Use PAT instead
    # ... other options
```

## Configuration Reference

### Common Options

Both modes support these options:

```yaml
- uses: alantheprice/ledit-agent@v1
  with:
    # Required
    ai-provider: 'openai'           # Provider: openai, deepinfra, groq, etc.
    ai-model: 'gpt-4o-mini'         # Model name for the provider
    github-token: ${{ secrets.GITHUB_TOKEN }}
    ai-api-key: ${{ secrets.OPENAI_API_KEY }}
    
    # Optional
    timeout-minutes: 20              # Max runtime (default: 10)
    ledit-version: 'latest'         # Specific ledit version (e.g., 'v0.5.10')
    debug: 'false'                  # Enable debug logging
    auto-review: 'false'            # Auto-add /ledit-review comment after solving issues
```

### Issue Solving Options

Additional options for `mode: 'solve'` (default):

```yaml
- uses: alantheprice/ledit-agent@v1
  with:
    mode: 'solve'                    # Default mode
    # ... common options ...
    
    # Solve-specific options
    max-iterations: 30              # Max agent iterations (default: 180 for solve, 80 for review)
    enable-mcp: 'true'              # Enable GitHub MCP tools
    workspace-dir: '.'              # Working directory
```

### PR Review Options

Additional options for `mode: 'review'`:

```yaml
- uses: alantheprice/ledit-agent@v1
  with:
    mode: 'review'                   # Review mode
    # ... common options ...
    
    # Review-specific options
    review-type: 'comprehensive'     # Focus area (see below)
    comment-threshold: 'medium'      # Comment verbosity (see below)
    summary-only: 'false'           # Only post summary, no inline comments
```

**Review Types:**
- `comprehensive` - All aspects (default)
- `security` - Focus on security vulnerabilities
- `performance` - Focus on performance issues
- `style` - Focus on code style and conventions

**Comment Thresholds:**
- `low` - All issues that need fixing (bugs, errors, quality problems)
- `medium` - Moderate risks and above (bugs, security, performance issues)
- `high` - Critical issues only (crashes, security vulnerabilities, data loss)

**Note:** The reviewer only comments on problems that need to be fixed. It won't provide positive feedback or style suggestions unless they represent actual issues. This keeps reviews focused and actionable.

**Technical Note:** The review agent writes its analysis directly to files (`review.json` and `summary.md`) for reliable parsing, avoiding issues with stdout parsing.

**GitHub Limitation:** The bot cannot approve its own PRs. If the review bot attempts to approve a PR it created (e.g., from issue solving mode), the approval will automatically be downgraded to a comment.

**Issue-Aware Reviews:** When reviewing PRs, the bot automatically fetches linked issues (via #123 references, closing keywords, or branch names) and validates whether the implementation meets the issue requirements.

**Codebase Validation:** The reviewer has full access to explore the repository, not just the diff. It verifies claims by checking actual files, dependencies, and implementations rather than making assumptions.

## Advanced Configuration

### Custom Trigger Commands

```yaml
# Trigger on different commands
if: |
  github.event.issue.pull_request == null && 
  (contains(github.event.comment.body, '/ledit') ||
   contains(github.event.comment.body, '/implement') ||
   contains(github.event.comment.body, '/solve'))
```

### Manual Trigger

```yaml
on:
  workflow_dispatch:
    inputs:
      issue_number:
        description: 'Issue number to solve'
        required: true
        type: number
```

## How It Works

### Issue Solver Mode (Default)
1. **Trigger** - User comments `/ledit` on an issue
2. **Analysis** - Agent reads issue, comments, and attached images
3. **Planning** - Breaks down the task into implementation steps
4. **Implementation** - Generates code following your project's patterns
5. **Review** - Creates PR with detailed description of changes
6. **Iteration** - Supports refinement through additional commands

### PR Review Mode
1. **Trigger** - PR is opened/updated or user comments `/review`
2. **Analysis** - Agent analyzes the diff and changes
3. **Review** - Provides comprehensive feedback on:
   - Code quality and best practices
   - Potential bugs and edge cases
   - Security vulnerabilities
   - Performance implications
4. **Comments** - Posts inline comments and overall assessment

## Best Practices

### For Issues
- **Be Specific** - Clear requirements lead to better implementations
- **Add Examples** - Show desired input/output
- **Attach Mockups** - Visual references for UI work
- **Use Labels** - Help categorize the type of work
- **PR Feedback** - The agent automatically sees PR reviews and comments, so you can ask it to "address the PR feedback" or "fix the issues mentioned in the review"

### For Cost Control
- Start with cheaper models (`gpt-4o-mini`, `gemini-flash`)
- Use Groq's free tier for testing
- Set timeout limits for long-running tasks
- Monitor usage in your provider's dashboard

### For Security
- Review all PRs before merging
- Use branch protection rules
- Limit permissions in workflow file
- Keep API keys in secrets

## Troubleshooting

### Action Not Triggering
- Ensure workflow file is in default branch
- Check the `/ledit` comment has no typos
- Verify workflow permissions are set

### API Errors
- Confirm API key is set correctly
- Check provider service status
- Ensure sufficient credits/quota

### No Changes Made
- Issue might need more context
- Try adding specific instructions
- Check action logs for errors

### Pull Request Creation Failed
If you see: `GitHub Actions is not permitted to create or approve pull requests`
1. Go to **Settings** → **Actions** → **General**
2. Under **Workflow permissions**, check **Allow GitHub Actions to create and approve pull requests**
3. Save and try again

### Wrong Ledit Version Installed
If the action installs an older version (e.g., v0.5.9) when 'latest' is specified:
- Specify the exact version: `ledit-version: 'v0.5.10'`
- This can happen due to Go module proxy caching
- Minimum v0.5.10 is required for max-iterations support

### PR Review Claims Files Don't Exist
If the reviewer says files added in the PR don't exist:
- Ensure your checkout step includes: `ref: ${{ github.event.pull_request.head.ref }}`
- The reviewer needs to analyze the PR branch, not the base branch
- See the PR Review example for correct checkout configuration

## Contributing

Contributions are welcome! Please see the [ledit repository](https://github.com/alantheprice/ledit) for development guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/alantheprice/ledit-agent/issues)
- **Discussions**: [GitHub Discussions](https://github.com/alantheprice/ledit/discussions)