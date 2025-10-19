# NFS Mount Manager for macOS

A robust NFS mount manager for macOS with YAML configuration, automatic validation, and Keyboard Maestro support. Perfect for mounting TrueNAS or other NFS shares on your Mac.

## Features

- 🔧 **YAML Configuration**: Easy-to-read and edit configuration format
- ✅ **Automatic Validation**: Validates config before mounting and detects example data
- 🔄 **Retry Logic**: Automatic retries for reliable mounting
- 📝 **Logging**: Maintains logs at `~/.config/nfs-mount/nfs-mount.log`
- 🤖 **Automation Ready**: Silent mode for Keyboard Maestro and other automation tools
- 🍎 **macOS Optimized**: Tuned mount options for best performance on macOS
- 🚀 **Auto-mount Support**: Optional `/etc/fstab` integration for boot-time mounting

## Installation

### Option 1: Homebrew (Recommended)

```bash
# Add the tap
brew tap peteha/tap

# Install
brew install nfs-mount

# Set up passwordless sudo (required for automation)
setup-sudo.sh
```

### Option 2: Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/peteha/mac-nfs-mount.git
   cd mac-nfs-mount
   chmod +x nfs-mount.sh
   ```

2. Install dependencies (yq for YAML parsing):
   ```bash
   brew install yq
   ```
   Or the script will install it automatically on first run.

3. Optionally, add to your PATH:
   ```bash
   sudo ln -s "$(pwd)/nfs-mount.sh" /usr/local/bin/nfs-mount
   ```

## Configuration

1. On first run, the script will create a default config at `~/.config/nfs-mount/config.yaml`

2. Edit the configuration file:
   ```bash
   nano ~/.config/nfs-mount/config.yaml
   ```

3. Example configuration:
   ```yaml
   mounts:
     - server: "192.168.1.100"     # Use IP address (more reliable than hostname)
       share: "/mnt/tank/media"
       nfs_version: "3"             # Use "3" for TrueNAS compatibility
       mount_name: "nas-media"
       enabled: true
     
     - server: "192.168.1.100"
       share: "/mnt/pool/backups"
       nfs_version: "3"
       mount_name: "nas-backups"
       enabled: true
   ```

4. See `example.yaml` for more configuration examples

### Configuration Fields

- **server**: IP address of your NFS server (recommended) or hostname
  - Example: `"192.168.1.100"` or `"truenas.local"`
  - **Tip**: IP addresses are more reliable than hostnames
- **share**: The exported path on the NFS server (e.g., `/mnt/tank/media`)
- **nfs_version**: NFS protocol version - use `"3"` (recommended for TrueNAS) or `"4"`
- **mount_name**: Local name for the mount point (letters, numbers, hyphens, underscores only)
- **enabled**: Set to `false` to temporarily disable a mount

All mounts are created under `~/External/[mount_name]`

## Usage

### Mount all NFS shares:
```bash
nfs-mount
```

### Silent mode (for automation):
```bash
nfs-mount --silent
```

### Setup auto-mount on boot:
```bash
nfs-mount --setup-automount
```

### Remove auto-mount configuration:
```bash
nfs-mount --remove-automount
```

### Show help:
```bash
nfs-mount --help
```

**Note**: If installed manually (not via Homebrew), use `./nfs-mount.sh` instead of `nfs-mount`

## Keyboard Maestro Integration

To use with Keyboard Maestro:

1. Create a new macro
2. Add an "Execute Shell Script" action
3. Use this command:
   ```bash
   nfs-mount --silent
   ```
   Or if installed manually:
   ```bash
   /bin/bash /Users/[your-username]/path/to/nfs-mount.sh --silent
   ```
4. Set the trigger (e.g., login, hotkey, time-based)

The `--silent` flag ensures clean execution without interactive output while maintaining detailed logs.

## Logging

Logs are automatically maintained at:
```
~/.config/nfs-mount/nfs-mount.log
```

The log file is automatically rotated to keep only the last 100 lines.

## Troubleshooting

### "Example data detected" error
This means you haven't customized the config file yet. Edit `~/.config/nfs-mount/config.yaml` and replace the example values with your actual NFS server details.

### "Failed to mount" errors
1. Verify your NFS server is accessible: `ping your-server-ip`
2. Check that the NFS share is exported and accessible
3. Ensure NFS is enabled on your server
4. Check the logs: `cat ~/.config/nfs-mount/nfs-mount.log`
5. Try mounting manually to debug:
   ```bash
   sudo mount -t nfs -o vers=4,resvport nfs://server-ip/share/path ~/External/test
   ```

### Mount options
The script uses optimized mount options for macOS:
- **NFSv4**: `resvport,nfsvers=4`
- **NFSv3**: `resvport,nfsvers=3` (recommended for TrueNAS)

## TrueNAS Configuration

For TrueNAS servers:

1. Create your share in TrueNAS (Storage → Pools → Add Dataset)
2. Configure NFS export (Sharing → Unix Shares (NFS))
3. Add your Mac's IP to the authorized networks
4. Use NFSv4 for better performance and security

## License

See LICENSE file for details.
