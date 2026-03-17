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
- 🔧 **Multi-Provider Support** - Works with OpenAI, OpenRouter, ZAI, DeepInfra, Chutes, Mistral, and custom OpenAI-compatible endpoints
- 🔍 **Jina AI Web Search** - Orchestrator and reviewer can look up docs and validate libraries in real time

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
          openai-api-key: ${{ secrets.OPENAI_API_KEY }}
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
          deepinfra-api-key: ${{ secrets.DEEPINFRA_API_KEY }}
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

### 3. Add API Keys

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add your API key(s) — use whichever providers you plan to use:
   - OpenAI: `OPENAI_API_KEY`
   - DeepInfra: `DEEPINFRA_API_KEY`
   - OpenRouter: `OPENROUTER_API_KEY`
   - ZAI: `ZAI_API_KEY`
   - Chutes: `CHUTES_API_KEY`
   - Mistral: `MISTRAL_API_KEY`
   - Jina AI (web search): `JINA_API_KEY` — [free tier available](https://jina.ai)

### 4. Use It!

1. Create an issue describing what you want
2. Comment `/ledit` to trigger the agent
3. Watch as it creates a branch, implements the solution, and opens a PR

## Supported Providers

### ZAI
Built-in vision support via GLM models.
```yaml
ai-provider: 'zai'           # Balanced
ai-model: 'glm-4.6v'           # Fast and cost-effective
zai-api-key: ${{ secrets.ZAI_API_KEY }}
```

### OpenAI
```yaml
ai-provider: 'openai'
ai-model: 'gpt-5'                # Most capable
ai-model: 'gpt-5-mini'           # Cost-effective
openai-api-key: ${{ secrets.OPENAI_API_KEY }}
```

### DeepInfra
```yaml
ai-provider: 'deepinfra'
ai-model: 'Qwen/Qwen3-Coder-480B-A35B-Instruct-Turbo'  # Fast and capable
ai-model: 'deepseek-ai/DeepSeek-V3.1'                   # Excellent for complex reasoning
ai-model: 'moonshotai/Kimi-K2-Instruct-0905'            # Very capable, slightly higher cost
deepinfra-api-key: ${{ secrets.DEEPINFRA_API_KEY }}
```

### OpenRouter
Large model catalogue including free tiers (may be slow or rate-limited).
```yaml
ai-provider: 'openrouter'
ai-model: 'qwen/qwen3-coder-30b-a3b-instruct'
openrouter-api-key: ${{ secrets.OPENROUTER_API_KEY }}
```

### Chutes
```yaml
ai-provider: 'chutes'
ai-model: 'deepseek-ai/DeepSeek-V3-0324'
chutes-api-key: ${{ secrets.CHUTES_API_KEY }}
```

### Mistral
```yaml
ai-provider: 'mistral'
ai-model: 'mistral-large-latest'
mistral-api-key: ${{ secrets.MISTRAL_API_KEY }}
```

### Custom Provider (any OpenAI-compatible endpoint)
```yaml
ai-provider: 'myprovider'          # matches custom-provider-name
custom-provider-name: 'myprovider'
custom-provider-url: 'https://api.example.com/v1'
custom-provider-model: 'my-model'
custom-provider-api-key: ${{ secrets.MY_PROVIDER_KEY }}
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
    ai-provider: 'zai'              # Provider: openai, zai, deepinfra, openrouter, chutes, mistral, or a custom name
    ai-model: 'GLM-4-Plus'          # Model name for the provider
    github-token: ${{ secrets.GITHUB_TOKEN }}

    # Provider API keys — set whichever providers you use
    zai-api-key: ${{ secrets.ZAI_API_KEY }}
    jina-api-key: ${{ secrets.JINA_API_KEY }}  # Optional: enables web search for orchestrator/reviewer

    # Optional
    timeout-minutes: 20             # Default: 20 (3-step workflow needs time)
    ledit-version: 'latest'         # Specific ledit version (e.g., 'v0.11.0')
    debug: 'false'                  # Enable debug logging
    auto-review: 'false'            # Auto-add /ledit-review comment after solving
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
    review-action: 'Focus specifically on security vulnerabilities and SQL injection risks'  # Custom review instructions
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

**Custom Review Instructions (review-action):**
The `review-action` parameter allows you to extend the code review prompt with additional instructions. This is useful for:
- Focusing on specific security concerns
- Highlighting particular coding standards
- Adding project-specific review criteria
- Emphasizing certain types of issues

**Examples:**
```yaml
# Focus on security
review-action: 'Pay special attention to authentication, authorization, and input validation issues'

# Focus on performance
review-action: 'Look for performance bottlenecks, inefficient algorithms, and database query optimization opportunities'

# Project-specific standards
review-action: 'Ensure all new code follows our TypeScript strict mode guidelines and includes proper error handling'

# Compliance requirements
review-action: 'Verify all changes comply with GDPR data protection requirements and include proper logging'
```

The custom instructions are appended to the standard review prompt under "ADDITIONAL REVIEW INSTRUCTIONS" and will be followed by the AI agent during the review process.

**Note:** The reviewer only comments on problems that need to be fixed. It won't provide positive feedback or style suggestions unless they represent actual issues. This keeps reviews focused and actionable.

**Technical Note:** The review agent writes its analysis directly to files (`review.json` and `summary.md`) for reliable parsing, avoiding issues with stdout parsing.

**GitHub Limitation:** The bot cannot approve its own PRs. If the review bot attempts to approve a PR it created (e.g., from issue solving mode), the approval will automatically be downgraded to a comment.

**Issue-Aware Reviews:** When reviewing PRs, the bot automatically fetches linked issues (via #123 references, closing keywords, or branch names) and validates whether the implementation meets the issue requirements.

**Codebase Validation:** The reviewer has full access to explore the repository, not just the diff. It verifies claims by checking actual files, dependencies, and implementations rather than making assumptions.

## Advanced Configuration

### Multi-Provider Configuration

You can supply keys for multiple providers simultaneously. The orchestrator can then spawn subagents using whichever provider suits the task, and `code_reviewer` can use web search to validate libraries.

```yaml
- uses: alantheprice/ledit-agent@v1
  with:
    # Primary provider (orchestrator + main solve step)
    ai-provider: 'zai'
    ai-model: 'GLM-5.0-Air'
    github-token: ${{ secrets.GITHUB_TOKEN }}

    # Provider keys — all configured providers are available to subagents
    zai-api-key: ${{ secrets.ZAI_API_KEY }}
    deepinfra-api-key: ${{ secrets.DEEPINFRA_API_KEY }}
    jina-api-key: ${{ secrets.JINA_API_KEY }}   # web search for orchestrator/code_reviewer

    # Route the coder subagent to a custom provider
    subagent-coder-provider: 'myprovider'
    subagent-coder-model: 'my-fast-coding-model'
    custom-provider-name: 'myprovider'
    custom-provider-url: 'https://api.myprovider.com/v1'
    custom-provider-api-key: ${{ secrets.MY_PROVIDER_KEY }}
```

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
- Start with cheaper models (`gpt-4o-mini`, `GLM-5.0-Air`, `qwen3-coder-30b`)
- Use OpenRouter's free tier for low-stakes testing
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
If the action installs an older version when `latest` is specified:
- Specify the exact version: `ledit-version: 'v0.11.0'`
- This can happen due to Go module proxy caching
- Minimum v0.11.0 is required for workflow, persona, and subagent features

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