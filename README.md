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

### 2. Add API Key

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add your API key (name depends on provider):
   - OpenAI: `OPENAI_API_KEY`
   - Groq: `GROQ_API_KEY`
   - Gemini: `GEMINI_API_KEY`
   - DeepInfra: `DEEPINFRA_API_KEY`

### 3. Use It!

1. Create an issue describing what you want
2. Comment `/ledit` to trigger the agent
3. Watch as it creates a branch, implements the solution, and opens a PR

## Supported Providers

### OpenAI
```yaml
ai-provider: 'openai'
ai-model: 'gpt-4o'          # Most capable
ai-model: 'gpt-4o-mini'     # Cost-effective
ai-api-key: ${{ secrets.OPENAI_API_KEY }}
```

### Groq (Free Tier Available!)
```yaml
ai-provider: 'groq'
ai-model: 'llama-3.1-70b-versatile'
ai-api-key: ${{ secrets.GROQ_API_KEY }}
```
Get your free API key at [console.groq.com](https://console.groq.com/keys)

### Google Gemini
```yaml
ai-provider: 'gemini'
ai-model: 'gemini-1.5-flash'    # Fast
ai-model: 'gemini-1.5-pro'      # Advanced
ai-api-key: ${{ secrets.GEMINI_API_KEY }}
```

### DeepInfra
```yaml
ai-provider: 'deepinfra'
ai-model: 'meta-llama/Llama-3.3-70B-Instruct'
ai-api-key: ${{ secrets.DEEPINFRA_API_KEY }}
```

### Local Models (Ollama)
```yaml
ai-provider: 'ollama'
ai-model: 'llama3'
# No API key needed for local models
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

## Advanced Configuration

### All Options

```yaml
- uses: alantheprice/ledit-agent@v1
  with:
    # Required
    ai-provider: 'openai'
    ai-model: 'gpt-4o'
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

## Contributing

Contributions are welcome! Please see the [ledit repository](https://github.com/alantheprice/ledit) for development guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/alantheprice/ledit-agent/issues)
- **Discussions**: [GitHub Discussions](https://github.com/alantheprice/ledit/discussions)
- **Documentation**: [Ledit Docs](https://github.com/alantheprice/ledit/wiki)