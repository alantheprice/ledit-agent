#!/bin/bash
set -e

LEDIT_VERSION="$1"

echo "Installing ledit version: $LEDIT_VERSION"

# Ensure Go environment is set up
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

# Install ledit
if [ "$LEDIT_VERSION" == "latest" ]; then
    echo "Installing latest version of ledit..."
    # Clear Go module cache for this module to ensure we get the actual latest
    go clean -modcache github.com/alantheprice/ledit 2>/dev/null || true
    # Force Go to check for the latest version
    LATEST_VERSION=$(go list -m -versions github.com/alantheprice/ledit | awk '{print $NF}')
    if [ -n "$LATEST_VERSION" ]; then
        echo "Found latest version: $LATEST_VERSION"
        go install github.com/alantheprice/ledit@$LATEST_VERSION
    else
        echo "Could not determine latest version, using @latest"
        go install github.com/alantheprice/ledit@latest
    fi
else
    echo "Installing ledit version $LEDIT_VERSION..."
    go install github.com/alantheprice/ledit@$LEDIT_VERSION
fi

# Verify installation
if ! command -v ledit &> /dev/null; then
    echo "ERROR: ledit installation failed"
    echo "PATH: $PATH"
    echo "Go binary location: $(which go)"
    echo "Go version: $(go version)"
    echo "Go modules cache: $(go env GOMODCACHE)"
    exit 1
fi

# Test ledit command with error capture
INSTALLED_VERSION="unknown"
if LEDIT_OUTPUT=$(ledit --version 2>&1); then
    # Extract just the module version from the multi-line output
    INSTALLED_VERSION=$(echo "$LEDIT_OUTPUT" | grep "Module version:" | sed 's/Module version: //' | tr -d ' ')
    if [ -z "$INSTALLED_VERSION" ]; then
        # Fallback: try to extract version from first line
        INSTALLED_VERSION=$(echo "$LEDIT_OUTPUT" | head -1 | sed 's/ledit version //')
    fi
    echo "Full ledit version output:"
    echo "$LEDIT_OUTPUT"
else
    echo "WARNING: ledit --version failed with output: $LEDIT_OUTPUT"
    echo "Attempting to run ledit with --help to diagnose..."
    if LEDIT_HELP=$(ledit --help 2>&1); then
        echo "ledit --help succeeded"
    else
        echo "ledit --help failed: $LEDIT_HELP"
    fi
fi

echo "Ledit installed successfully: $INSTALLED_VERSION"
echo "Installation path: $(which ledit)"

# Check if the binary is executable
if [ -x "$(which ledit)" ]; then
    echo "✅ Ledit binary is executable"
else
    echo "❌ Ledit binary is not executable"
    chmod +x "$(which ledit)" 2>/dev/null || echo "Failed to make ledit executable"
fi

# Check minimum version requirement (v0.5.10 for max-iterations support)
REQUIRED_VERSION="v0.5.10"
if [ "$INSTALLED_VERSION" != "unknown" ] && [ "$INSTALLED_VERSION" != "$REQUIRED_VERSION" ]; then
    # Skip version check if installed version is "dev" (development build)
    if [ "$INSTALLED_VERSION" = "dev" ]; then
        echo "✅ Using development version of ledit (assuming latest features)"
    else
        # Simple version comparison - remove 'v' prefix and compare
        INSTALLED_NUM=$(echo "$INSTALLED_VERSION" | sed 's/v//' | tr -d '.' | grep -E '^[0-9]+$' || echo "0")
        REQUIRED_NUM=$(echo "$REQUIRED_VERSION" | sed 's/v//' | tr -d '.')
        
        if [ "$INSTALLED_NUM" -gt 0 ] && [ "$INSTALLED_NUM" -lt "$REQUIRED_NUM" ]; then
            echo "WARNING: Installed version $INSTALLED_VERSION is older than required version $REQUIRED_VERSION"
            echo "The --max-iterations flag requires ledit $REQUIRED_VERSION or newer"
        fi
    fi
fi

# Make sure ledit is accessible
echo "PATH=$PATH" >> $GITHUB_ENV