#!/bin/bash
set -e

echo "Configuring ledit..."

mkdir -p ~/.ledit

# Build api_keys.json from every provider key that is set in the environment.
# Ledit also reads these env vars natively, but writing them here ensures they
# are available even in subagent subprocess environments.
KEYS_JSON="{"
FIRST=1
add_key() {
    local provider="$1"
    local value="$2"
    if [ -n "$value" ]; then
        [ $FIRST -eq 0 ] && KEYS_JSON+=","
        KEYS_JSON+="\"$provider\": \"$value\""
        FIRST=0
        echo "  $provider: configured"
    fi
}

add_key "openai"       "$OPENAI_API_KEY"
add_key "openrouter"   "$OPENROUTER_API_KEY"
add_key "deepinfra"    "$DEEPINFRA_API_KEY"
add_key "zai"          "$ZAI_API_KEY"
add_key "chutes"       "$CHUTES_API_KEY"
add_key "mistral"      "$MISTRAL_API_KEY"
add_key "jinaai"       "$JINA_API_KEY"

KEYS_JSON+="}"
echo "$KEYS_JSON" > ~/.ledit/api_keys.json

if [ $FIRST -eq 1 ]; then
    echo "WARNING: No provider API keys found. Set at least one of: OPENAI_API_KEY, OPENROUTER_API_KEY, DEEPINFRA_API_KEY, ZAI_API_KEY, etc."
fi

# Create configuration file
CONFIG_JSON=$(jq -n \
  --arg provider "$AI_PROVIDER" \
  --arg model    "$AI_MODEL" \
  '{
    version: "2.0",
    last_used_provider: $provider,
    provider_models: { ($provider): $model },
    provider_priority: [$provider]
  }')

# Add custom provider block when a URL is supplied
if [ -n "$CUSTOM_PROVIDER_URL" ]; then
  CUSTOM_NAME="${CUSTOM_PROVIDER_NAME:-custom}"
  CUSTOM_MODEL="${CUSTOM_PROVIDER_MODEL:-$AI_MODEL}"
  REQUIRES_KEY="false"
  [ -n "$CUSTOM_PROVIDER_API_KEY" ] && REQUIRES_KEY="true"

  CONFIG_JSON=$(echo "$CONFIG_JSON" | jq \
    --arg  cname        "$CUSTOM_NAME" \
    --arg  cendpoint    "$CUSTOM_PROVIDER_URL" \
    --arg  cmodel       "$CUSTOM_MODEL" \
    --argjson req_key   "$REQUIRES_KEY" \
    --arg  env_var      "CUSTOM_PROVIDER_API_KEY" \
    '.custom_providers[$cname] = {
      name:            $cname,
      endpoint:        $cendpoint,
      model_name:      $cmodel,
      requires_api_key: $req_key,
      env_var:         $env_var
    }')

  echo "  custom provider: $CUSTOM_NAME → $CUSTOM_PROVIDER_URL"
fi

# Add subagent_types overrides for coder and/or vision personas
if [ -n "$SUBAGENT_CODER_PROVIDER" ]; then
  CODER_MDL="${SUBAGENT_CODER_MODEL:-$AI_MODEL}"
  CONFIG_JSON=$(echo "$CONFIG_JSON" | jq \
    --arg p "$SUBAGENT_CODER_PROVIDER" \
    --arg m "$CODER_MDL" \
    '.subagent_types.coder.provider = $p | .subagent_types.coder.model = $m')
  echo "  coder subagent: $SUBAGENT_CODER_PROVIDER / $CODER_MDL"
fi

echo "$CONFIG_JSON" > ~/.ledit/config.json

echo "Ledit configured with:"
echo "  Primary provider: $AI_PROVIDER"
echo "  Model: $AI_MODEL"
echo "  Max iterations: $MAX_ITERATIONS"
