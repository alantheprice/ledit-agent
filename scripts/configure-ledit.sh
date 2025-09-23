#!/bin/bash
set -e

echo "Configuring ledit..."

# Create ledit config directory
mkdir -p ~/.ledit

# Map provider names to environment variable names
case "$AI_PROVIDER" in
    openai)
        API_KEY_NAME="OPENAI_API_KEY"
        ;;
    openrouter)
        API_KEY_NAME="OPENROUTER_API_KEY"
        ;;
    groq)
        API_KEY_NAME="GROQ_API_KEY"
        ;;
    deepinfra)
        API_KEY_NAME="DEEPINFRA_API_KEY"
        ;;
    ollama)
        API_KEY_NAME="" # Ollama doesn't need API key
        ;;
    cerebras)
        API_KEY_NAME="CEREBRAS_API_KEY"
        ;;
    deepseek)
        API_KEY_NAME="DEEPSEEK_API_KEY"
        ;;
    anthropic)
        API_KEY_NAME="ANTHROPIC_API_KEY"
        ;;
    *)
        echo "ERROR: Unknown AI provider: $AI_PROVIDER"
        exit 1
        ;;
esac

# Create API keys file
cat > ~/.ledit/api_keys.json << EOF
{
  "$AI_PROVIDER": "$AI_API_KEY"
}
EOF

# Create configuration file
cat > ~/.ledit/config.json << EOF
{
  "version": "2.0",
  "last_used_provider": "$AI_PROVIDER",
  "provider_models": {
    "$AI_PROVIDER": "$AI_MODEL"
  },
  "provider_priority": ["$AI_PROVIDER"]
}
EOF

echo "Ledit configured with:"
echo "  Provider: $AI_PROVIDER"
echo "  Model: $AI_MODEL"
echo "  MCP setup for github"
echo "  Max iterations: $MAX_ITERATIONS"
