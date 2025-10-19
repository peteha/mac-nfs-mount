# Quick Start Guide

## ✅ Your Setup is Complete!

All 4 NFS shares are mounted and working:
- ✓ Backup
- ✓ Data  
- ✓ Homes
- ✓ Images

## Current Configuration

**Location**: `~/.config/nfs-mount/config.yaml`

```yaml
mounts:
  - server: "10.200.1.110"
    share: "/mnt/bulk/pgData/backup"
    nfs_version: "3"
    mount_name: "Backup"
    enabled: true

  - server: "10.200.1.110"
    share: "/mnt/bulk/pgData/data"
    nfs_version: "3"
    mount_name: "Data"
    enabled: true

  - server: "10.200.1.110"
    share: "/mnt/bulk/pgData/homes"
    nfs_version: "3"
    mount_name: "Homes"
    enabled: true

  - server: "10.200.1.110"
    share: "/mnt/bulk/pgData/images"
    nfs_version: "3"
    mount_name: "Images"
    enabled: true
```

**Mount Points**: `~/External/Backup`, `~/External/Data`, `~/External/Homes`, `~/External/Images`

## Daily Usage

### Mount All Shares
```bash
cd ~/GitHub/mac-nfs-mount
./nfs-mount.sh
```

### Check What's Mounted
```bash
mount | grep nfs
```

### Unmount a Share
```bash
sudo umount ~/External/Backup
```

### Unmount All Shares
```bash
sudo umount ~/External/Backup ~/External/Data ~/External/Homes ~/External/Images
```

## Keyboard Maestro Setup

### Step 1: Create a New Macro
1. Open Keyboard Maestro Editor
2. Click **New Macro**
3. Name it "Mount NFS Shares"

### Step 2: Set a Trigger
Choose one:
- **At Login**: Trigger → Login
- **Hotkey**: Trigger → Hot Key Trigger (e.g., ⌃⌥⌘N)
- **Time-based**: Trigger → Time of Day (e.g., 8:00 AM)
- **Network Change**: Trigger → Network Change

### Step 3: Add Shell Script Action
1. Click **New Action**
2. Search for "Execute Shell Script"
3. Paste this command:
   ```bash
   /bin/bash /Users/peteha/GitHub/mac-nfs-mount/nfs-mount.sh --silent
   ```
4. Optional: Check "Notify on Failure"

### Step 4: Test It!
Click "Try" to test your macro. Your shares should mount silently!

## Automation Examples

### Run at Login
Best for: Mounting shares every time you log in
- Trigger: **Login**
- Command: `/bin/bash /Users/peteha/GitHub/mac-nfs-mount/nfs-mount.sh --silent`

### Run on Network Connection
Best for: Mounting shares when you connect to your home network
- Trigger: **Network Change** → Connected to "Your WiFi Name"
- Command: `/bin/bash /Users/peteha/GitHub/mac-nfs-mount/nfs-mount.sh --silent`

### Run on Schedule
Best for: Ensuring shares stay mounted
- Trigger: **Time of Day** → Every 30 minutes
- Conditions: If not already mounted (script handles this automatically)
- Command: `/bin/bash /Users/peteha/GitHub/mac-nfs-mount/nfs-mount.sh --silent`

## Managing Shares

### Disable a Share Temporarily
Edit `~/.config/nfs-mount/config.yaml` and set:
```yaml
- server: "10.200.1.110"
  share: "/mnt/bulk/pgData/backup"
  nfs_version: "3"
  mount_name: "Backup"
  enabled: false    # ← Changed to false
```

### Add a New Share
1. Edit `~/.config/nfs-mount/config.yaml`
2. Add a new entry:
```yaml
- server: "10.200.1.110"
  share: "/mnt/bulk/pgData/new-share"
  nfs_version: "3"
  mount_name: "NewShare"
  enabled: true
```
3. Make sure the share is exported in TrueNAS

### Edit Configuration
```bash
nano ~/.config/nfs-mount/config.yaml
```

## Troubleshooting

### Shares Won't Mount
1. Check TrueNAS is running:
   ```bash
   ping 10.200.1.110
   ```

2. Verify NFS service is running in TrueNAS:
   - Services → NFS → Should show "Running"

3. Check the logs:
   ```bash
   cat ~/.config/nfs-mount/nfs-mount.log
   ```

### "Operation not permitted"
- Make sure the share is enabled in TrueNAS
- Verify your network (10.0.0.0/8) is authorized in the share settings
- Check NFS service is running

### Keyboard Maestro Not Working
1. Make sure passwordless sudo is configured:
   ```bash
   sudo -n mount
   ```
   Should NOT ask for password

2. Check Keyboard Maestro has permissions:
   - System Settings → Privacy & Security → Automation → Keyboard Maestro

3. Check the macro log in Keyboard Maestro for errors

## Files and Locations

- **Script**: `~/GitHub/mac-nfs-mount/nfs-mount.sh`
- **Config**: `~/.config/nfs-mount/config.yaml`
- **Logs**: `~/.config/nfs-mount/nfs-mount.log`
- **Mounts**: `~/External/[mount_name]`
- **Sudo Config**: `/etc/sudoers.d/nfs-mount`

## Key Features

✓ **YAML Configuration** - Easy to read and edit  
✓ **Automatic Validation** - Catches config errors before mounting  
✓ **Example Detection** - Warns if you haven't customized the config  
✓ **Silent Mode** - Perfect for automation  
✓ **Logging** - All operations logged to `~/.config/nfs-mount/nfs-mount.log`  
✓ **Retry Logic** - Automatically retries failed mounts  
✓ **Enable/Disable** - Toggle mounts without deleting config  
✓ **Passwordless Sudo** - Configured for automation  

## Next Steps

1. **Set up Keyboard Maestro** (see above)
2. **Test automation** by triggering your macro
3. **Customize triggers** based on your workflow
4. **Add more shares** as needed

Enjoy your automated NFS mounts! 🎉

