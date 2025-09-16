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
    exit 1
fi

INSTALLED_VERSION=$(ledit --version 2>/dev/null || echo "unknown")
echo "Ledit installed successfully: $INSTALLED_VERSION"
echo "Installation path: $(which ledit)"

# Check minimum version requirement (v0.5.10 for max-iterations support)
REQUIRED_VERSION="v0.5.10"
if [ "$INSTALLED_VERSION" != "unknown" ] && [ "$INSTALLED_VERSION" != "$REQUIRED_VERSION" ]; then
    # Simple version comparison - remove 'v' prefix and compare
    INSTALLED_NUM=$(echo "$INSTALLED_VERSION" | sed 's/v//' | tr -d '.')
    REQUIRED_NUM=$(echo "$REQUIRED_VERSION" | sed 's/v//' | tr -d '.')
    
    if [ "$INSTALLED_NUM" -lt "$REQUIRED_NUM" ]; then
        echo "WARNING: Installed version $INSTALLED_VERSION is older than required version $REQUIRED_VERSION"
        echo "The --max-iterations flag requires ledit $REQUIRED_VERSION or newer"
    fi
fi

# Make sure ledit is accessible
echo "PATH=$PATH" >> $GITHUB_ENV