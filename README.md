# Ledit Agent - AI-Powered GitHub Issue Solver

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automatically solve GitHub issues using AI-powered code generation with [ledit](https://github.com/alantheprice/ledit).

## Features

- 🤖 **AI-Powered Implementation** - Analyzes issues and generates complete solutions
- 🖼️ **Vision Support** - Processes mockups and screenshots to implement UIs
- 🔄 **Iterative Development** - Refine implementations with follow-up commands
- 🌿 **Smart Git Management** - Creates branches and pull requests automatically
- 🔧 **Multi-Provider Support** - Works with OpenAI, Groq, Gemini, DeepInfra, and more
- 🛡️ **Secure by Design** - All changes go through PR review process

## Quick Start

### 1. Add Workflow File

Create `.github/workflows/ledit-agent.yml` in your repository:

```yaml
name: Ledit Agent

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
          ai-provider: 'openai'
          ai-model: 'gpt-4o-mini'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          ai-api-key: ${{ secrets.OPENAI_API_KEY }}
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

## Advanced Configuration

### All Options

```yaml
- uses: alantheprice/ledit-agent@v1
  with:
    # Required
    ai-provider: 'openai'
    ai-model: 'gpt-5-mini'
    github-token: ${{ secrets.GITHUB_TOKEN }}
    ai-api-key: ${{ secrets.OPENAI_API_KEY }}
    
    # Optional
    timeout-minutes: 20              # Max runtime (default: 10)
    max-iterations: 30              # Max agent iterations (default: 20)
    ledit-version: 'latest'         # Specific ledit version
    enable-mcp: 'true'              # Enable GitHub MCP tools
    debug: 'false'                  # Enable debug logging
    workspace-dir: '.'              # Working directory
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

1. **Trigger** - User comments `/ledit` on an issue
2. **Analysis** - Agent reads issue, comments, and attached images
3. **Planning** - Breaks down the task into implementation steps
4. **Implementation** - Generates code following your project's patterns
5. **Review** - Creates PR with detailed description of changes
6. **Iteration** - Supports refinement through additional commands

## Best Practices

### For Issues
- **Be Specific** - Clear requirements lead to better implementations
- **Add Examples** - Show desired input/output
- **Attach Mockups** - Visual references for UI work
- **Use Labels** - Help categorize the type of work

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

## Contributing

Contributions are welcome! Please see the [ledit repository](https://github.com/alantheprice/ledit) for development guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/alantheprice/ledit-agent/issues)
- **Discussions**: [GitHub Discussions](https://github.com/alantheprice/ledit/discussions)