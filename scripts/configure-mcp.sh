#!/bin/bash
set -e

echo "Configuring MCP for GitHub integration..."

# Create MCP config directory
mkdir -p ~/.ledit/mcp

# Create MCP configuration


cat > ~/.ledit/mcp_config.json << EOF
{
  "enabled": true,
  "servers": {
    "git": {
      "name": "git",
      "command": "uvx",
      "args": [
        "mcp-server-git",
        "--repository",
        "$GITHUB_REPOSITORY",
      ],
      "timeout": 30000000000,
      "auto_start": true,
      "max_restarts": 3
    },
    "github": {
      "name": "github",
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "$GITHUB_TOKEN"
      },
      "timeout": 30000000000,
      "auto_start": true,
      "max_restarts": 3
    }
  },
  "auto_start": true,
  "auto_discover": true,
  "timeout": 30000000000
}
EOF


echo "MCP configured for GitHub integration"