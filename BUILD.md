# Build & Release Guide

This project includes two build scripts for different purposes.

## Quick Reference

```bash
# Development/testing
./build.sh

# Production release
./release.sh 1.0.1
```

---

## Development Build (`build.sh`)

**Purpose**: Quick local testing during development

**What it does**:
1. Creates a tarball from current code
2. Temporarily updates Homebrew formula
3. Installs locally for testing
4. Restores formula to original state

**Usage**:
```bash
./build.sh
```

**When to use**:
- Testing changes before committing
- Quick iteration during development
- Verifying fixes locally

**Note**: This creates a temporary build that won't be shared. The formula is restored after installation.

---

## Production Release (`release.sh`)

**Purpose**: Create official releases on GitHub and update Homebrew

**What it does**:
1. Checks for uncommitted changes
2. Creates and pushes git tag
3. Downloads release from GitHub
4. Calculates SHA256 checksum
5. Updates Homebrew formula
6. Commits and pushes tap changes
7. Tests installation

**Usage**:
```bash
# Full release
./release.sh 1.0.1

# Skip git operations (if already tagged)
./release.sh 1.0.1 --skip-git

# Skip tap update (formula only)
./release.sh 1.0.1 --skip-tap
```

**Prerequisites**:
1. All changes committed to git
2. GitHub repository exists: `https://github.com/peteha/mac-nfs-mount`
3. Homebrew tap exists: `/opt/homebrew/Library/Taps/peteha/homebrew-tap`

**Process**:

### Step 1: Make Changes
```bash
# Edit code
vim nfs-mount.sh

# Commit changes
git add -A
git commit -m "Add new feature"
```

### Step 2: Run Release Script
```bash
./release.sh 1.0.1
```

The script will:
- ✅ Validate version format
- ✅ Check for uncommitted changes
- ✅ Create git tag `v1.0.1`
- ✅ Push to GitHub
- ✅ Download release tarball
- ✅ Calculate SHA256
- ✅ Update Homebrew formula
- ✅ Commit tap changes
- ✅ Optionally push tap to GitHub
- ✅ Test installation

### Step 3: Verify
```bash
# Check GitHub release
open https://github.com/peteha/mac-nfs-mount/releases/tag/v1.0.1

# Test installation
brew uninstall nfs-mount
brew install peteha/tap/nfs-mount
nfs-mount --help
```

---

## Version Numbering

Use [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., `1.0.1`)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

Examples:
- `1.0.0` → First stable release
- `1.0.1` → Bug fix
- `1.1.0` → New feature
- `2.0.0` → Breaking change

---

## Troubleshooting

### "Tag already exists"
```bash
# Delete local tag
git tag -d v1.0.1

# Delete remote tag
git push origin :refs/tags/v1.0.1

# Re-run release
./release.sh 1.0.1
```

### "Failed to download release from GitHub"
```bash
# Wait a moment for GitHub to process
sleep 5

# Try again with --skip-git
./release.sh 1.0.1 --skip-git
```

### "Homebrew formula not found"
```bash
# Create the tap
brew tap-new peteha/tap

# Copy formula
cp nfs-mount.rb /opt/homebrew/Library/Taps/peteha/homebrew-tap/Formula/

# Try again
./release.sh 1.0.1
```

### "Installation failed"
```bash
# Check formula syntax
brew audit peteha/tap/nfs-mount

# Check for errors
brew install --verbose peteha/tap/nfs-mount

# Clear cache and retry
brew cleanup -s
rm -rf ~/Library/Caches/Homebrew/downloads/*nfs-mount*
```

---

## Workflow Examples

### Quick Fix
```bash
# 1. Fix bug
vim nfs-mount.sh

# 2. Test locally
./build.sh
nfs-mount --help

# 3. Commit and release
git add -A
git commit -m "Fix bug in mount check"
./release.sh 1.0.2
```

### New Feature
```bash
# 1. Develop feature on branch
git checkout -b feature/new-mount-option
vim nfs-mount.sh

# 2. Test with build script
./build.sh
nfs-mount --silent

# 3. Merge and release
git checkout main
git merge feature/new-mount-option
git push
./release.sh 1.1.0
```

### Hotfix
```bash
# 1. Quick fix
vim nfs-mount.sh
git add -A
git commit -m "Hotfix: Critical mount issue"

# 2. Immediate release
git push
./release.sh 1.0.3

# 3. Verify
brew upgrade nfs-mount
```

---

## CI/CD Integration (Future)

These scripts can be integrated into GitHub Actions:

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags:
      - 'v*'
jobs:
  release:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run release script
        run: ./release.sh ${GITHUB_REF#refs/tags/v} --skip-git
```

---

## Manual Release (Without Scripts)

If you prefer manual control:

```bash
# 1. Tag and push
git tag -a v1.0.1 -m "Release 1.0.1"
git push origin v1.0.1

# 2. Get SHA256
curl -sL https://github.com/peteha/mac-nfs-mount/archive/refs/tags/v1.0.1.tar.gz | shasum -a 256

# 3. Edit formula
vim /opt/homebrew/Library/Taps/peteha/homebrew-tap/Formula/nfs-mount.rb
# Update url, sha256, and version

# 4. Test
brew reinstall peteha/tap/nfs-mount
```

---

## Best Practices

1. **Always test locally first**: Use `./build.sh` before releasing
2. **Write good commit messages**: Explain what changed and why
3. **Update documentation**: Keep README.md and CHANGELOG.md current
4. **Test the release**: Actually run the newly installed version
5. **Keep versions incremental**: Don't skip version numbers

---

## Files Modified by Scripts

### `build.sh`
- Creates: `/tmp/nfs-mount-dev.tar.gz`
- Modifies (temporarily): Formula file
- Restores: Formula to original state

### `release.sh`
- Creates: Git tag `v{VERSION}`
- Downloads: Release tarball from GitHub
- Modifies: Formula with new URL and SHA256
- Commits: Tap repository changes

---

## Support

For issues with the build scripts:
1. Check you're in the project root
2. Verify Homebrew tap exists
3. Ensure git remote is configured
4. Check file permissions on scripts

For formula issues:
```bash
brew doctor
brew audit peteha/tap/nfs-mount
```

