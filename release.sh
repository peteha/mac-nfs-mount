#!/bin/bash

################################################################################
# NFS Mount Manager - Release Script
# Automates versioning, GitHub releases, and Homebrew formula updates
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAP_DIR="/opt/homebrew/Library/Taps/peteha/homebrew-tap"
FORMULA_FILE="${TAP_DIR}/Formula/nfs-mount.rb"

# Print functions
print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1" >&2
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

print_step() {
    echo -e "  ${YELLOW}▸${NC} $1"
}

# Check if version is provided
if [[ -z "$1" ]]; then
    print_error "Version number required"
    echo ""
    echo "Usage: $0 <version> [--skip-git] [--skip-tap]"
    echo ""
    echo "Examples:"
    echo "  $0 1.0.1              # Full release"
    echo "  $0 1.0.1 --skip-git   # Skip git push"
    echo "  $0 1.0.1 --skip-tap   # Skip tap update"
    echo ""
    exit 1
fi

VERSION="$1"
SKIP_GIT=false
SKIP_TAP=false

# Parse arguments
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-git)
            SKIP_GIT=true
            shift
            ;;
        --skip-tap)
            SKIP_TAP=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate version format
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid version format. Use semantic versioning (e.g., 1.0.1)"
    exit 1
fi

print_header "NFS Mount Manager - Release v${VERSION}"

# Change to script directory
cd "$SCRIPT_DIR"

# Check for uncommitted changes
print_step "Checking git status..."
if [[ -n $(git status --porcelain) ]]; then
    print_error "Uncommitted changes detected"
    echo ""
    git status --short
    echo ""
    read -p "Commit these changes first? [y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add -A
        read -p "Commit message: " commit_msg
        git commit -m "$commit_msg"
        print_success "Changes committed"
    else
        print_error "Please commit or stash changes before releasing"
        exit 1
    fi
fi
print_success "Working directory clean"

# Create and push git tag
if [[ "$SKIP_GIT" == false ]]; then
    print_step "Creating git tag v${VERSION}..."
    if git tag -a "v${VERSION}" -m "Release version ${VERSION}"; then
        print_success "Tag created"
    else
        print_error "Failed to create tag (may already exist)"
        exit 1
    fi
    
    print_step "Pushing to GitHub..."
    git push origin main
    git push origin "v${VERSION}"
    print_success "Pushed to GitHub"
    
    # Wait a moment for GitHub to process
    print_info "Waiting for GitHub to process release..."
    sleep 3
else
    print_info "Skipping git push (--skip-git)"
fi

# Download and calculate SHA256
print_step "Downloading release tarball from GitHub..."
RELEASE_URL="https://github.com/peteha/mac-nfs-mount/archive/refs/tags/v${VERSION}.tar.gz"
TEMP_FILE="/tmp/nfs-mount-v${VERSION}.tar.gz"

if curl -sL "$RELEASE_URL" -o "$TEMP_FILE"; then
    print_success "Downloaded release tarball"
else
    print_error "Failed to download release from GitHub"
    print_info "Make sure the tag exists: git push origin v${VERSION}"
    exit 1
fi

print_step "Calculating SHA256..."
SHA256=$(shasum -a 256 "$TEMP_FILE" | awk '{print $1}')
print_success "SHA256: ${SHA256}"

# Update Homebrew formula
if [[ "$SKIP_TAP" == false ]]; then
    if [[ ! -f "$FORMULA_FILE" ]]; then
        print_error "Homebrew formula not found: $FORMULA_FILE"
        print_info "Make sure the tap exists: brew tap-new peteha/tap"
        exit 1
    fi
    
    print_step "Updating Homebrew formula..."
    
    # Backup formula
    cp "$FORMULA_FILE" "${FORMULA_FILE}.backup"
    
    # Update URL and SHA256
    sed -i '' "s|url \".*\"|url \"${RELEASE_URL}\"|g" "$FORMULA_FILE"
    sed -i '' "s|sha256 \".*\"|sha256 \"${SHA256}\"|g" "$FORMULA_FILE"
    sed -i '' "s|version \".*\"|version \"${VERSION}\"|g" "$FORMULA_FILE"
    
    print_success "Formula updated"
    
    # Show diff
    print_info "Changes to formula:"
    echo ""
    diff -u "${FORMULA_FILE}.backup" "$FORMULA_FILE" || true
    echo ""
    
    # Commit tap changes
    print_step "Committing tap changes..."
    cd "$TAP_DIR"
    git add Formula/nfs-mount.rb
    git commit -m "Update nfs-mount to v${VERSION}"
    print_success "Tap changes committed"
    
    # Push tap if it has a remote
    if git remote get-url origin &>/dev/null; then
        read -p "Push tap to GitHub? [Y/n]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            git push origin main
            print_success "Tap pushed to GitHub"
        fi
    else
        print_info "No remote configured for tap (local only)"
    fi
    
    cd "$SCRIPT_DIR"
else
    print_info "Skipping tap update (--skip-tap)"
fi

# Test installation
print_step "Testing installation..."
echo ""
read -p "Test install from Homebrew? [Y/n]: " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    print_info "Uninstalling current version..."
    brew uninstall nfs-mount 2>/dev/null || true
    
    print_info "Installing v${VERSION}..."
    if brew install peteha/tap/nfs-mount; then
        print_success "Installation successful!"
        
        # Verify version
        if nfs-mount --help | head -1 | grep -q "NFS Mount Manager"; then
            print_success "Command working correctly"
        else
            print_error "Command verification failed"
        fi
    else
        print_error "Installation failed"
        exit 1
    fi
fi

# Summary
print_header "Release Complete! 🎉"

print_success "Version ${VERSION} released"
echo ""
print_info "GitHub Release: https://github.com/peteha/mac-nfs-mount/releases/tag/v${VERSION}"
print_info "Installation:   brew install peteha/tap/nfs-mount"
echo ""

if [[ "$SKIP_TAP" == false ]]; then
    print_info "Homebrew formula updated and committed"
    if git -C "$TAP_DIR" remote get-url origin &>/dev/null; then
        print_info "Users can update with: brew update && brew upgrade nfs-mount"
    else
        print_info "To share your tap, push it to GitHub:"
        echo "  cd $TAP_DIR"
        echo "  git remote add origin https://github.com/peteha/homebrew-tap.git"
        echo "  git push -u origin main"
    fi
fi

echo ""
print_success "All done!"
echo ""

# Cleanup
rm -f "$TEMP_FILE"
rm -f "${FORMULA_FILE}.backup"

