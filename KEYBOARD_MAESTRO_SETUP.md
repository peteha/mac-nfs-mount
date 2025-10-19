# Keyboard Maestro Setup Guide

This guide will help you configure your Mac to automatically mount NFS shares with Keyboard Maestro without requiring password prompts.

## Quick Setup

### Step 1: Configure Passwordless Sudo for NFS Mounts

For Keyboard Maestro to work properly, you need to allow your user to run `mount` and `umount` commands without a password.

1. Open Terminal and edit the sudoers file:
   ```bash
   sudo visudo
   ```

2. Add the following line at the **end** of the file (replace `yourusername` with your actual macOS username):
   ```
   yourusername ALL=(ALL) NOPASSWD: /sbin/mount, /sbin/umount, /sbin/mount_nfs
   ```

   To find your username, run:
   ```bash
   whoami
   ```

3. Save and exit:
   - Press `Ctrl+O` to write
   - Press `Enter` to confirm
   - Press `Ctrl+X` to exit

4. Test it works (should NOT ask for password):
   ```bash
   sudo -n mount
   ```
   If it shows mount usage without asking for a password, you're all set!

### Step 2: Test the Script

Run the script manually to make sure it works:
```bash
cd ~/GitHub/mac-nfs-mount
./nfs-mount.sh
```

All mounts should succeed without asking for a password.

### Step 3: Configure Keyboard Maestro

1. Open Keyboard Maestro Editor
2. Create a new Macro
3. Set your trigger (e.g., "At login", "At time", or a hotkey)
4. Add action: **Execute Shell Script**
5. Paste this command:
   ```bash
   /bin/bash /Users/$(whoami)/GitHub/mac-nfs-mount/nfs-mount.sh --silent
   ```
6. **Optional**: Check "Notify on failure" to get alerts if mounting fails

### Step 4: Test Keyboard Maestro

Trigger your macro manually to verify it works!

## Alternative: Login Item Approach

Instead of Keyboard Maestro, you can use macOS Login Items:

1. Open **System Settings** → **General** → **Login Items**
2. Click the **+** button under "Open at Login"
3. Navigate to and select your `nfs-mount.sh` script
4. Or create a LaunchAgent (more reliable)

### LaunchAgent Setup

Create a LaunchAgent that runs at login:

```bash
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/com.user.nfs-mount.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.nfs-mount</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/YOUR_USERNAME/GitHub/mac-nfs-mount/nfs-mount.sh</string>
        <string>--silent</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/nfs-mount.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/nfs-mount.err</string>
</dict>
</plist>
EOF
```

Replace `YOUR_USERNAME` with your username, then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.user.nfs-mount.plist
```

## Troubleshooting

### "Operation not permitted" error
- Make sure you've configured passwordless sudo (see Step 1)
- Check that your user account is in the admin group: `groups`

### Mounts don't show up
- Check the logs: `cat ~/.config/nfs-mount/nfs-mount.log`
- Verify NFS server is reachable: `ping pgnas.pgnet.io`
- Test manual mount:
  ```bash
  sudo mount -t nfs -o vers=4 pgnas.pgnet.io:/mnt/bulk/pgData/backup ~/External/Backup
  ```

### "sudo: a password is required"
- Your passwordless sudo setup isn't working
- Double-check you edited sudoers correctly with `sudo visudo`
- Make sure the line is at the END of the file

### Keyboard Maestro macro doesn't run
- Check Keyboard Maestro has proper permissions in System Settings → Privacy & Security
- Try adding a "Display Text" action before the script to verify the macro triggers
- Check Keyboard Maestro's log

## Security Note

Allowing passwordless sudo for mount commands is generally safe since:
- It only affects the specific `mount`, `umount`, and `mount_nfs` commands
- Your user already has permission to mount NFS shares to their own directories
- It enables automation while maintaining system security

However, if you're concerned, consider using the `autofs` / automount approach instead, which doesn't require sudo.

