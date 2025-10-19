#!/bin/bash

################################################################################
# NFS Mount Manager - Development Build Script
# Quick build and install for local testing
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAP_DIR="/opt/homebrew/Library/Taps/peteha/homebrew-tap"
FORMULA_FILE="${TAP_DIR}/Formula/nfs-mount.rb"

echo -e "${BOLD}${CYAN}Building NFS Mount Manager for local testing...${NC}\n"

# Create tarball
echo -e "${BLUE}▸${NC} Creating tarball..."
cd "$SCRIPT_DIR"
tar -czf /tmp/nfs-mount-dev.tar.gz --exclude='.git' .
SHA256=$(shasum -a 256 /tmp/nfs-mount-dev.tar.gz | awk '{print $1}')
echo -e "${GREEN}✓${NC} Tarball created: ${SHA256}\n"

# Update formula
echo -e "${BLUE}▸${NC} Updating formula..."
cp "$FORMULA_FILE" "${FORMULA_FILE}.backup"

# Update to use local tarball
sed -i '' 's|url ".*"|url "file:///tmp/nfs-mount-dev.tar.gz"|g' "$FORMULA_FILE"
sed -i '' "s|sha256 \".*\"|sha256 \"${SHA256}\"|g" "$FORMULA_FILE"

echo -e "${GREEN}✓${NC} Formula updated\n"

# Reinstall
echo -e "${BLUE}▸${NC} Reinstalling..."
brew uninstall nfs-mount 2>/dev/null || true
rm -rf /Users/$(whoami)/Library/Caches/Homebrew/downloads/*nfs-mount*

if brew install peteha/tap/nfs-mount; then
    echo -e "\n${GREEN}✓${NC} ${BOLD}Build successful!${NC}\n"
    echo -e "${BLUE}ℹ${NC} Test with: nfs-mount --help\n"
else
    # Restore backup on failure
    mv "${FORMULA_FILE}.backup" "$FORMULA_FILE"
    echo -e "\n${RED}✗${NC} Build failed\n"
    exit 1
fi

# Restore original formula
mv "${FORMULA_FILE}.backup" "$FORMULA_FILE"
echo -e "${BLUE}ℹ${NC} Formula restored to original state"
echo -e "${BLUE}ℹ${NC} Note: This is a development build using local files\n"

