#!/bin/bash

################################################################################
# Setup Passwordless Sudo for NFS Mounts
# This enables the nfs-mount script to work with Keyboard Maestro
################################################################################

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NFS Mount - Passwordless Sudo Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This script will configure your Mac to allow NFS mounts"
echo "without requiring a password prompt."
echo ""
echo "Required for: Keyboard Maestro, LaunchAgents, and automation"
echo ""

# Get current user
CURRENT_USER=$(whoami)

echo "Current user: $CURRENT_USER"
echo ""
echo "This will add a rule to /etc/sudoers.d/ allowing passwordless"
echo "mount/umount for NFS operations."
echo ""

read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Creating sudoers rule..."
echo "You will be prompted for your password once."
echo ""

# Create sudoers file
SUDOERS_FILE="/etc/sudoers.d/nfs-mount"

# Write the sudoers rule
sudo tee "$SUDOERS_FILE" > /dev/null << EOF
# Allow $CURRENT_USER to mount/unmount NFS shares without password
# Created by nfs-mount setup script on $(date)
$CURRENT_USER ALL=(ALL) NOPASSWD: /sbin/mount, /sbin/umount, /sbin/mount_nfs, /sbin/umount_nfs
EOF

# Set correct permissions (sudoers files must be 0440)
sudo chmod 0440 "$SUDOERS_FILE"

# Verify the sudoers file is valid
if sudo visudo -c -f "$SUDOERS_FILE"; then
    echo ""
    echo "✓ Successfully configured passwordless sudo for NFS mounts!"
    echo ""
    echo "Testing..."
    if sudo -n mount 2>&1 | grep -q "usage:"; then
        echo "✓ Test passed! You can now mount NFS shares without a password."
    else
        echo "⚠ Test failed. You may need to log out and back in."
    fi
    echo ""
    echo "You can now use the nfs-mount script with Keyboard Maestro."
    echo ""
else
    echo ""
    echo "✗ Error: Invalid sudoers configuration!"
    echo "  Removing the file for safety..."
    sudo rm -f "$SUDOERS_FILE"
    exit 1
fi

