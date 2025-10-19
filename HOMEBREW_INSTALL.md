# Homebrew Installation Guide

## Option 1: Install from Your Tap (Recommended for Distribution)

### Step 1: Create a Homebrew Tap Repository

1. Create a new GitHub repository named `homebrew-tap` (or `homebrew-tools`)
   - Repository URL will be: `https://github.com/peteha/homebrew-tap`

2. Add the formula to your tap:
   ```bash
   # Clone your tap repository
   git clone https://github.com/peteha/homebrew-tap.git
   cd homebrew-tap
   
   # Copy the formula
   cp /path/to/mac-nfs-mount/nfs-mount.rb Formula/nfs-mount.rb
   
   # Commit and push
   git add Formula/nfs-mount.rb
   git commit -m "Add nfs-mount formula"
   git push
   ```

3. Users can then install with:
   ```bash
   brew tap peteha/tap
   brew install nfs-mount
   ```

### Step 2: Create a Release of mac-nfs-mount

1. Tag your mac-nfs-mount repository:
   ```bash
   cd /path/to/mac-nfs-mount
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

2. Create a GitHub release at:
   ```
   https://github.com/peteha/mac-nfs-mount/releases/new
   ```
   - Tag: `v1.0.0`
   - Title: `v1.0.0 - Initial Release`
   - Description: Add release notes

3. GitHub will automatically create a tarball at:
   ```
   https://github.com/peteha/mac-nfs-mount/archive/refs/tags/v1.0.0.tar.gz
   ```

4. Update the formula's SHA256:
   ```bash
   # Download and calculate SHA256
   wget https://github.com/peteha/mac-nfs-mount/archive/refs/tags/v1.0.0.tar.gz
   shasum -a 256 v1.0.0.tar.gz
   ```
   
   Update `nfs-mount.rb`:
   ```ruby
   sha256 "paste-the-sha256-here"
   ```

---

## Option 2: Install Directly (For Personal Use)

You can install directly from the local formula without creating a tap:

```bash
brew install --formula /Users/peteha/GitHub/mac-nfs-mount/nfs-mount.rb
```

Or from the GitHub repository directly (after creating a release):

```bash
brew install https://raw.githubusercontent.com/peteha/mac-nfs-mount/main/nfs-mount.rb
```

---

## Option 3: Development/Testing Installation

For testing during development:

```bash
cd /Users/peteha/GitHub/mac-nfs-mount
brew install --build-from-source --formula ./nfs-mount.rb
```

---

## Post-Installation

After installation via any method:

1. **Edit the configuration**:
   ```bash
   nano ~/.config/nfs-mount/config.yaml
   ```

2. **Set up passwordless sudo** (required for automation):
   ```bash
   setup-sudo.sh
   ```

3. **Test mounting**:
   ```bash
   nfs-mount
   ```

4. **For Keyboard Maestro**:
   ```bash
   nfs-mount --silent
   ```

---

## Updating

### If installed from a tap:
```bash
brew update
brew upgrade nfs-mount
```

### If installed from local formula:
```bash
brew reinstall --formula /Users/peteha/GitHub/mac-nfs-mount/nfs-mount.rb
```

---

## Uninstalling

```bash
brew uninstall nfs-mount
```

Note: This will NOT remove your configuration file at `~/.config/nfs-mount/config.yaml`

---

## Quick Setup: Create Your Own Tap

Here's a complete setup script to create your own Homebrew tap:

```bash
#!/bin/bash

# Configuration
GITHUB_USERNAME="peteha"
TAP_NAME="homebrew-tap"

# Create tap repository
mkdir -p ~/homebrew-$TAP_NAME
cd ~/homebrew-$TAP_NAME

# Initialize git
git init
mkdir -p Formula

# Copy formula
cp /Users/peteha/GitHub/mac-nfs-mount/nfs-mount.rb Formula/

# Create README
cat > README.md << EOF
# Homebrew Tap

Personal Homebrew formulas.

## Installation

\`\`\`bash
brew tap $GITHUB_USERNAME/tap
brew install nfs-mount
\`\`\`

## Available Formulas

- **nfs-mount**: NFS mount manager for macOS
EOF

# Initial commit
git add .
git commit -m "Initial tap setup with nfs-mount formula"

echo "Now:"
echo "1. Create GitHub repo: https://github.com/new"
echo "   Name it: $TAP_NAME"
echo ""
echo "2. Push to GitHub:"
echo "   git remote add origin https://github.com/$GITHUB_USERNAME/$TAP_NAME.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. Install with:"
echo "   brew tap $GITHUB_USERNAME/tap"
echo "   brew install nfs-mount"
```

---

## Formula Maintenance

### Update the formula for a new version:

1. Create new release:
   ```bash
   cd /Users/peteha/GitHub/mac-nfs-mount
   git tag -a v1.1.0 -m "Version 1.1.0"
   git push origin v1.1.0
   ```

2. Download and get SHA256:
   ```bash
   wget https://github.com/peteha/mac-nfs-mount/archive/refs/tags/v1.1.0.tar.gz
   shasum -a 256 v1.1.0.tar.gz
   ```

3. Update formula in your tap:
   ```ruby
   url "https://github.com/peteha/mac-nfs-mount/archive/refs/tags/v1.1.0.tar.gz"
   sha256 "new-sha256-here"
   ```

4. Commit and push:
   ```bash
   cd ~/homebrew-tap
   git add Formula/nfs-mount.rb
   git commit -m "Update nfs-mount to v1.1.0"
   git push
   ```

5. Users update with:
   ```bash
   brew update
   brew upgrade nfs-mount
   ```

---

## Testing the Formula

```bash
# Test installation
brew install --formula /Users/peteha/GitHub/mac-nfs-mount/nfs-mount.rb

# Test the command
nfs-mount --help

# Run formula tests
brew test nfs-mount

# Audit formula for issues
brew audit --strict nfs-mount.rb
```

---

## Troubleshooting

### Formula not found
Make sure your tap is added:
```bash
brew tap peteha/tap
```

### Permission issues
The formula handles config creation in the user's home directory, which should work without sudo.

### Dependencies not installing
Make sure Homebrew is up to date:
```bash
brew update
```

### Configuration not created
Run the post-install manually:
```bash
brew postinstall nfs-mount
```

