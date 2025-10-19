# Configuration Reference

Complete reference for `~/.config/nfs-mount/config.yaml`

## Configuration Structure

```yaml
# Global settings
settings:
  base_mount_dir: "/Users/username/External"
  max_retries: 3
  retry_delay: 2
  
  mount_options:
    use_resvport: true
    nfsv3_extra_opts: ""
    nfsv4_extra_opts: ""

# NFS mounts
mounts:
  - server: "hostname.or.ip"
    share: "/path/to/share"
    nfs_version: "3"
    mount_name: "mount-name"
    enabled: true
```

## Settings Section

All settings are **optional** - defaults will be used if not specified.

### `base_mount_dir`

**Type**: String  
**Default**: `${HOME}/External`  
**Description**: Base directory where all mount points will be created.

**Examples**:
```yaml
base_mount_dir: "/Users/peteha/External"
base_mount_dir: "${HOME}/NAS"
base_mount_dir: "/Volumes/NFS"
```

**Notes**:
- Supports `${HOME}` variable expansion
- Directory will be created automatically if it doesn't exist
- Individual mounts created at: `{base_mount_dir}/{mount_name}`

---

### `max_retries`

**Type**: Integer  
**Default**: `3`  
**Description**: Number of times to retry mounting if it fails.

**Examples**:
```yaml
max_retries: 3    # Try 3 times before giving up
max_retries: 5    # More retries for unreliable networks
max_retries: 1    # Fail fast, don't retry
```

---

### `retry_delay`

**Type**: Integer (seconds)  
**Default**: `2`  
**Description**: Seconds to wait between retry attempts.

**Examples**:
```yaml
retry_delay: 2     # Wait 2 seconds between retries
retry_delay: 5     # Longer delay for slow servers
retry_delay: 0     # No delay, retry immediately
```

---

## Mount Options Section

### `use_resvport`

**Type**: Boolean  
**Default**: `true`  
**Description**: Use a reserved/privileged port (< 1024) when mounting.

**When to use `true`**:
- Most NFS servers (including TrueNAS in default config)
- Enterprise NFS servers
- When server requires secure ports

**When to use `false`**:
- TrueNAS with "mapall nobody:nogroup" (might work either way)
- Testing/development NFS servers
- Non-privileged NFS setups

**Examples**:
```yaml
mount_options:
  use_resvport: true   # Most common (TrueNAS default)
  use_resvport: false  # Some special configurations
```

---

### `nfsv3_extra_opts`

**Type**: String  
**Default**: `""`  
**Description**: Additional mount options for NFSv3 mounts (comma-separated).

**Common Options**:
- `tcp` - Use TCP instead of UDP
- `soft` - Return error after timeout (vs `hard` which retries forever)
- `hard` - Retry forever (safer but can hang)
- `intr` - Allow interruption of hung mounts
- `timeo=N` - Timeout in deciseconds (10 = 1 second)
- `retrans=N` - Number of retransmissions
- `rsize=N` - Read buffer size (bytes)
- `wsize=N` - Write buffer size (bytes)

**Examples**:
```yaml
# Basic performance tuning
nfsv3_extra_opts: "tcp,rsize=65536,wsize=65536"

# Soft mount with timeout
nfsv3_extra_opts: "soft,intr,timeo=900,retrans=3"

# Optimized for TrueNAS
nfsv3_extra_opts: "tcp,rw,soft,intr,rsize=65536,wsize=65536"

# Leave empty for minimal options
nfsv3_extra_opts: ""
```

---

### `nfsv4_extra_opts`

**Type**: String  
**Default**: `""`  
**Description**: Additional mount options for NFSv4 mounts (comma-separated).

**Common Options**:
- `soft` - Return error after timeout
- `hard` - Retry forever
- `intr` - Allow interruption
- `timeo=N` - Timeout in deciseconds
- `retrans=N` - Number of retransmissions

**Examples**:
```yaml
# Soft mount with timeout
nfsv4_extra_opts: "soft,intr,timeo=900"

# Hard mount (safer)
nfsv4_extra_opts: "hard,intr"

# Leave empty for minimal options
nfsv4_extra_opts: ""
```

---

## Mounts Section

Each mount entry has the following fields:

### `server`

**Type**: String  
**Required**: Yes  
**Description**: IP address or hostname of the NFS server.

**Examples**:
```yaml
server: "192.168.1.100"      # IP address (recommended)
server: "truenas.local"      # Hostname
server: "nas.example.com"    # FQDN
server: "10.0.1.50"          # Private network IP
```

**Recommendation**: Use IP addresses for reliability. Hostnames require DNS resolution which can fail.

---

### `share`

**Type**: String  
**Required**: Yes  
**Description**: Full path to the NFS export on the server.

**Examples**:
```yaml
share: "/mnt/tank/media"
share: "/export/backups"
share: "/mnt/bulk/pgData/homes"
```

**Notes**:
- Must match exactly what's exported on the NFS server (case-sensitive)
- Should start with `/`
- Check server's NFS exports with: `showmount -e server-ip`

---

### `nfs_version`

**Type**: String (`"3"` or `"4"`)  
**Required**: Yes  
**Description**: NFS protocol version to use.

**Examples**:
```yaml
nfs_version: "3"    # NFSv3 (recommended for TrueNAS)
nfs_version: "4"    # NFSv4 (better security, may have compatibility issues)
```

**Recommendations**:
- **Use `"3"`** for TrueNAS and most home NAS devices
- **Use `"4"`** for newer enterprise NFS servers
- Test both if unsure

---

### `mount_name`

**Type**: String  
**Required**: Yes  
**Description**: Local name for the mount point (becomes a directory name).

**Rules**:
- Only letters, numbers, hyphens (`-`), and underscores (`_`)
- No spaces or special characters
- Case-sensitive

**Examples**:
```yaml
mount_name: "nas-media"       # Good
mount_name: "backup_2024"     # Good
mount_name: "Homes"           # Good
mount_name: "my nas share"    # BAD - has spaces
mount_name: "files@home"      # BAD - has @ symbol
```

**Result**: Creates mount point at `{base_mount_dir}/{mount_name}`  
Example: `~/External/nas-media`

---

### `enabled`

**Type**: Boolean  
**Required**: No  
**Default**: `true`  
**Description**: Whether to mount this share.

**Examples**:
```yaml
enabled: true     # Mount this share
enabled: false    # Skip this share (useful for temporarily disabling)
```

**Use Cases**:
- Temporarily disable a mount without deleting the config
- Keep backup/archive mounts disabled by default
- Enable/disable based on context

---

## Complete Example Configurations

### Minimal Configuration

```yaml
# Uses all defaults
mounts:
  - server: "192.168.1.100"
    share: "/mnt/tank/media"
    nfs_version: "3"
    mount_name: "media"
```

### TrueNAS Optimized

```yaml
settings:
  base_mount_dir: "${HOME}/External"
  max_retries: 3
  retry_delay: 2
  mount_options:
    use_resvport: true
    nfsv3_extra_opts: "tcp,rsize=65536,wsize=65536"
    nfsv4_extra_opts: ""

mounts:
  - server: "truenas.local"
    share: "/mnt/tank/media"
    nfs_version: "3"
    mount_name: "media"
    enabled: true
```

### High Performance Configuration

```yaml
settings:
  base_mount_dir: "/Volumes/NFS"
  max_retries: 5
  retry_delay: 3
  mount_options:
    use_resvport: true
    nfsv3_extra_opts: "tcp,rsize=131072,wsize=131072,hard,intr"
    nfsv4_extra_opts: "hard,intr"

mounts:
  - server: "10.0.1.100"
    share: "/export/high-speed"
    nfs_version: "4"
    mount_name: "fast-storage"
    enabled: true
```

### Multiple Servers

```yaml
settings:
  base_mount_dir: "${HOME}/NAS"

mounts:
  # Primary NAS
  - server: "192.168.1.100"
    share: "/mnt/tank/media"
    nfs_version: "3"
    mount_name: "primary-media"
    enabled: true
  
  # Backup NAS
  - server: "192.168.1.101"
    share: "/export/backups"
    nfs_version: "3"
    mount_name: "backup-nas"
    enabled: true
  
  # Archive (disabled by default)
  - server: "192.168.1.102"
    share: "/archive"
    nfs_version: "3"
    mount_name: "archive"
    enabled: false
```

### Development/Testing Setup

```yaml
settings:
  base_mount_dir: "${HOME}/mounts"
  max_retries: 1
  retry_delay: 0
  mount_options:
    use_resvport: false
    nfsv3_extra_opts: "soft,intr,timeo=50"

mounts:
  - server: "localhost"
    share: "/export/test"
    nfs_version: "3"
    mount_name: "local-test"
    enabled: true
```

---

## Troubleshooting Configuration

### Mount Fails with "Operation not permitted"

**Try**:
```yaml
mount_options:
  use_resvport: true  # Make sure this is true
```

Check TrueNAS:
- Share is enabled
- Network (your IP) is authorized
- NFS service is running

### Slow Performance

**Try**:
```yaml
mount_options:
  nfsv3_extra_opts: "tcp,rsize=131072,wsize=131072,hard,intr"
```

### Mounts Hang

**Try**:
```yaml
mount_options:
  nfsv3_extra_opts: "soft,intr,timeo=100,retrans=2"
```

### DNS Issues

**Use IP instead of hostname**:
```yaml
server: "192.168.1.100"  # Instead of "nas.local"
```

---

## Validation

The script validates:
- ✓ YAML syntax is correct
- ✓ Required fields are present
- ✓ NFS version is "3" or "4"
- ✓ Mount names have no invalid characters
- ✓ Example/placeholder data is not used

Run validation without mounting:
```bash
./nfs-mount.sh --help  # Shows current config values
```

---

## See Also

- `example.yaml` - Template configuration file
- `README.md` - Full documentation
- `QUICKSTART.md` - Quick reference guide
- `KEYBOARD_MAESTRO_SETUP.md` - Automation setup

