#!/bin/bash

################################################################################
# NFS Mount Manager for macOS
# Mounts NFS shares from a YAML configuration file
# Supports auto-mounting on boot via /etc/fstab
# Compatible with Keyboard Maestro and other automation tools
################################################################################

set -euo pipefail

# Set up proper PATH for Homebrew and system tools (important for Keyboard Maestro)
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
CONFIG_DIR="${HOME}/.config/nfs-mount"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_CONFIG="${SCRIPT_DIR}/example.yaml"
LOG_FILE="${CONFIG_DIR}/nfs-mount.log"

# These will be loaded from config file (with defaults)
BASE_MOUNT_DIR=""
MAX_RETRIES=3
RETRY_DELAY=2
USE_RESVPORT=true
NFSV3_EXTRA_OPTS=""
NFSV4_EXTRA_OPTS=""

# Silent mode for automation (set via --silent flag)
SILENT_MODE=false

# Function to print colored output
print_header() {
    if [[ "$SILENT_MODE" == true ]]; then return; fi
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    local msg="$1"
    log_message "SUCCESS: $msg"
    if [[ "$SILENT_MODE" == false ]]; then
        echo -e "  ${GREEN}✓${NC} $msg"
    fi
}

print_error() {
    local msg="$1"
    log_message "ERROR: $msg"
    if [[ "$SILENT_MODE" == false ]]; then
        echo -e "  ${RED}✗${NC} $msg" >&2
    fi
}

print_warning() {
    local msg="$1"
    log_message "WARNING: $msg"
    if [[ "$SILENT_MODE" == false ]]; then
        echo -e "  ${YELLOW}⚠${NC} $msg"
    fi
}

print_info() {
    local msg="$1"
    log_message "INFO: $msg"
    if [[ "$SILENT_MODE" == false ]]; then
        echo -e "  ${BLUE}ℹ${NC} $msg"
    fi
}

print_step() {
    if [[ "$SILENT_MODE" == true ]]; then return; fi
    echo -e "  ${MAGENTA}▸${NC} $1"
}

# Log to file (always happens, even in silent mode)
log_message() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

# Initialize logging
init_logging() {
    mkdir -p "$CONFIG_DIR"
    # Keep only last 100 lines of log
    if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE") -gt 100 ]]; then
        tail -n 100 "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
    log_message "========== NFS Mount Manager Started =========="
}

# Check if passwordless sudo is configured for NFS mounts
check_passwordless_sudo() {
    # Test if we can run mount with sudo without password
    if ! sudo -n mount > /dev/null 2>&1; then
        # Informational warning only - don't block execution
        if [[ "$SILENT_MODE" == false ]]; then
            print_warning "Passwordless sudo is not configured"
            print_info "For reliable automation, run: ${BOLD}setup-sudo.sh${NC}"
            echo ""
        fi
        log_message "WARNING: Passwordless sudo not configured (recommended for automation)"
    fi
}

# Check if yq is installed
check_dependencies() {
    local yq_cmd=""
    
    # Find yq binary
    if command -v yq &> /dev/null; then
        yq_cmd="yq"
    elif [[ -f /usr/local/bin/yq ]]; then
        yq_cmd="/usr/local/bin/yq"
    elif [[ -f /opt/homebrew/bin/yq ]]; then
        yq_cmd="/opt/homebrew/bin/yq"
    fi
    
    if [[ -z "$yq_cmd" ]]; then
        print_error "yq is not installed. Installing via Homebrew..."
        
        # Check for Homebrew
        local brew_cmd=""
        if command -v brew &> /dev/null; then
            brew_cmd="brew"
        elif [[ -f /usr/local/bin/brew ]]; then
            brew_cmd="/usr/local/bin/brew"
        elif [[ -f /opt/homebrew/bin/brew ]]; then
            brew_cmd="/opt/homebrew/bin/brew"
        fi
        
        if [[ -z "$brew_cmd" ]]; then
            print_error "Homebrew is not installed. Please install Homebrew first:"
            echo -e "    ${CYAN}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
            exit 1
        fi
        
        $brew_cmd install yq
    fi
}

# Create initial config if it doesn't exist
initialize_config() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        print_step "Creating config directory: $CONFIG_DIR"
        mkdir -p "$CONFIG_DIR"
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "Configuration file not found!"
        print_info "Creating default configuration at: $CONFIG_FILE"
        
        # Create default config with example placeholders
        cat > "$CONFIG_FILE" << 'EOF'
# NFS Mount Configuration
# Please replace the example values with your actual NFS server details

mounts:
  - server: "example.local"
    share: "/mnt/tank/example"
    nfs_version: "4"
    mount_name: "example-share"
    enabled: true
EOF
        
        print_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_error "  CONFIGURATION REQUIRED"
        print_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        print_error "A default configuration has been created at:"
        echo -e "    ${CYAN}${CONFIG_FILE}${NC}"
        echo ""
        print_error "Please edit this file and replace the example values with your actual NFS server details."
        echo ""
        if [[ -f "$EXAMPLE_CONFIG" ]]; then
            print_info "You can reference the example configuration at:"
            echo -e "    ${CYAN}${EXAMPLE_CONFIG}${NC}"
            echo ""
        fi
        print_info "Example configuration format:"
        echo ""
        echo "    mounts:"
        echo "      - server: \"192.168.1.100\""
        echo "        share: \"/mnt/pool/myshare\""
        echo "        nfs_version: \"4\""
        echo "        mount_name: \"my-nas-share\""
        echo "        enabled: true"
        echo ""
        exit 1
    fi
}

# Load settings from config file
load_settings() {
    # Load base_mount_dir (with default)
    local config_base_dir=$(yq eval '.settings.base_mount_dir // ""' "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$config_base_dir" ]]; then
        # Expand ${HOME} if present
        BASE_MOUNT_DIR="${config_base_dir//\$\{HOME\}/${HOME}}"
    else
        BASE_MOUNT_DIR="${HOME}/External"
    fi
    
    # Load max_retries (with default)
    local config_retries=$(yq eval '.settings.max_retries // ""' "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$config_retries" ]] && [[ "$config_retries" =~ ^[0-9]+$ ]]; then
        MAX_RETRIES="$config_retries"
    fi
    
    # Load retry_delay (with default)
    local config_delay=$(yq eval '.settings.retry_delay // ""' "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$config_delay" ]] && [[ "$config_delay" =~ ^[0-9]+$ ]]; then
        RETRY_DELAY="$config_delay"
    fi
    
    # Load mount options
    local config_resvport=$(yq eval '.settings.mount_options.use_resvport // ""' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$config_resvport" == "false" ]]; then
        USE_RESVPORT=false
    else
        USE_RESVPORT=true
    fi
    
    # Load extra mount options
    NFSV3_EXTRA_OPTS=$(yq eval '.settings.mount_options.nfsv3_extra_opts // ""' "$CONFIG_FILE" 2>/dev/null)
    NFSV4_EXTRA_OPTS=$(yq eval '.settings.mount_options.nfsv4_extra_opts // ""' "$CONFIG_FILE" 2>/dev/null)
}

# Validate YAML config file
validate_config() {
    print_step "Validating configuration..."
    
    # Check if file is valid YAML
    if ! yq eval '.' "$CONFIG_FILE" > /dev/null 2>&1; then
        print_error "Configuration file is not valid YAML: $CONFIG_FILE"
        exit 1
    fi
    
    # Load settings from config
    load_settings
    
    # Check if mounts array exists
    if ! yq eval '.mounts' "$CONFIG_FILE" > /dev/null 2>&1; then
        print_error "Configuration file missing 'mounts' section"
        exit 1
    fi
    
    # Get mount count
    local count=$(yq eval '.mounts | length' "$CONFIG_FILE")
    
    if [[ "$count" -eq 0 ]]; then
        print_error "No mounts defined in configuration"
        exit 1
    fi
    
    # Check if config still has example/placeholder values
    local has_example=false
    for i in $(seq 0 $((count - 1))); do
        local server=$(yq eval ".mounts[$i].server" "$CONFIG_FILE")
        local share=$(yq eval ".mounts[$i].share" "$CONFIG_FILE")
        local mount_name=$(yq eval ".mounts[$i].mount_name" "$CONFIG_FILE")
        
        if [[ "$server" == "example.local" ]] || \
           [[ "$share" == *"example"* && "$mount_name" == "example-share" ]] || \
           [[ "$server" == "{nfs_server}" ]] || \
           [[ "$share" == "{nfs_share}" ]] || \
           [[ "$mount_name" == "{mount_name}" ]]; then
            has_example=true
            break
        fi
    done
    
    if [[ "$has_example" == true ]]; then
        print_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_error "  EXAMPLE DATA DETECTED"
        print_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        print_error "Your configuration file still contains example/placeholder values!"
        echo ""
        print_error "Please edit the configuration file and replace with actual values:"
        echo -e "    ${CYAN}${CONFIG_FILE}${NC}"
        echo ""
        exit 1
    fi
    
    # Validate each mount entry
    local errors=0
    for i in $(seq 0 $((count - 1))); do
        local server=$(yq eval ".mounts[$i].server" "$CONFIG_FILE")
        local share=$(yq eval ".mounts[$i].share" "$CONFIG_FILE")
        local nfs_version=$(yq eval ".mounts[$i].nfs_version" "$CONFIG_FILE")
        local mount_name=$(yq eval ".mounts[$i].mount_name" "$CONFIG_FILE")
        
        # Check for required fields
        if [[ "$server" == "null" ]] || [[ -z "$server" ]]; then
            print_error "Mount entry $i: missing 'server' field"
            ((errors++))
        fi
        
        if [[ "$share" == "null" ]] || [[ -z "$share" ]]; then
            print_error "Mount entry $i: missing 'share' field"
            ((errors++))
        fi
        
        if [[ "$nfs_version" == "null" ]] || [[ -z "$nfs_version" ]]; then
            print_error "Mount entry $i: missing 'nfs_version' field"
            ((errors++))
        fi
        
        if [[ "$mount_name" == "null" ]] || [[ -z "$mount_name" ]]; then
            print_error "Mount entry $i: missing 'mount_name' field"
            ((errors++))
        fi
        
        # Validate NFS version
        if [[ "$nfs_version" != "3" ]] && [[ "$nfs_version" != "4" ]]; then
            print_error "Mount entry $i: nfs_version must be '3' or '4', got: $nfs_version"
            ((errors++))
        fi
        
        # Validate mount name (no spaces or special chars)
        if [[ "$mount_name" =~ [[:space:]] ]] || [[ "$mount_name" =~ [^a-zA-Z0-9_-] ]]; then
            print_error "Mount entry $i: mount_name contains invalid characters: $mount_name"
            print_info "Mount names should only contain letters, numbers, hyphens, and underscores"
            ((errors++))
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        print_error "Configuration validation failed with $errors error(s)"
        exit 1
    fi
    
    print_success "Configuration validated successfully"
}

# Create base mount directory if it doesn't exist
create_base_dir() {
    if [[ ! -d "$BASE_MOUNT_DIR" ]]; then
        print_step "Creating base directory: $BASE_MOUNT_DIR"
        mkdir -p "$BASE_MOUNT_DIR"
        print_success "Base directory created"
    fi
}

# Mount a single NFS share
mount_nfs_share() {
    local server="$1"
    local share="$2"
    local nfs_version="$3"
    local mount_name="$4"
    local enabled="${5:-true}"
    local mount_use_resvport="${6:-}"  # Per-mount resvport override (optional)
    
    # Skip if disabled
    if [[ "$enabled" != "true" ]]; then
        print_info "Skipping disabled mount: ${mount_name}"
        return 0
    fi
    
    local mount_point="${BASE_MOUNT_DIR}/${mount_name}"
    local nfs_url="${server}:${share}"
    
    print_step "Processing: ${BOLD}${mount_name}${NC}"
    
    # Create mount point if it doesn't exist
    if [[ ! -d "$mount_point" ]]; then
        mkdir -p "$mount_point"
        print_info "Created directory: $mount_point"
    fi
    
    # Check if already mounted, and remount to ensure fresh options
    if mount | grep -q "on ${mount_point} "; then
        print_warning "Already mounted: ${mount_name} (will remount to refresh options)"
        if ! unmount_nfs_share "$mount_name"; then
            print_error "Unable to unmount existing mount: ${mount_name}"
            return 1
        fi
        print_info "Remounting ${mount_name}..."
    fi
    
    # Determine resvport setting (per-mount override or global default)
    local use_resvport_for_mount="$USE_RESVPORT"
    if [[ -n "$mount_use_resvport" ]]; then
        use_resvport_for_mount="$mount_use_resvport"
    fi
    
    # Build mount options from config settings
    local mount_opts=""
    if [[ "$nfs_version" == "4" ]]; then
        # NFSv4 base options
        if [[ "$use_resvport_for_mount" == "true" ]]; then
            mount_opts="resvport,nfsvers=4"
        else
            mount_opts="nfsvers=4"
        fi
        # Add extra options if specified
        if [[ -n "$NFSV4_EXTRA_OPTS" ]]; then
            mount_opts="${mount_opts},${NFSV4_EXTRA_OPTS}"
        fi
    else
        # NFSv3 base options
        if [[ "$use_resvport_for_mount" == "true" ]]; then
            mount_opts="resvport,nfsvers=3"
        else
            mount_opts="nfsvers=3"
        fi
        # Add extra options if specified
        if [[ -n "$NFSV3_EXTRA_OPTS" ]]; then
            mount_opts="${mount_opts},${NFSV3_EXTRA_OPTS}"
        fi
    fi
    
    # macOS-specific options to prevent AppleDouble files and hide mount points
    mount_opts="${mount_opts},rw,noappledouble,nobrowse"
    
    # Attempt to mount with retries for reliability
    local retry=0
    local mounted=false
    local mount_error=""
    
    while [[ $retry -lt $MAX_RETRIES ]] && [[ "$mounted" == false ]]; do
        if [[ $retry -gt 0 ]]; then
            print_info "Retry attempt $retry of $MAX_RETRIES..."
            sleep "$RETRY_DELAY"
        fi
        
        # Try mount without sudo first (works on macOS for user-owned directories)
        # If that fails and EUID is not 0, try with sudo
        mount_error=$(mount -t nfs -o "$mount_opts" "$nfs_url" "$mount_point" 2>&1)
        local mount_status=$?
        
        if [[ $mount_status -ne 0 ]] && [[ $EUID -ne 0 ]]; then
            # Try with sudo if available and we're not already root
            mount_error=$(sudo -n mount -t nfs -o "$mount_opts" "$nfs_url" "$mount_point" 2>&1)
            mount_status=$?
        fi
        
        if [[ $mount_status -eq 0 ]]; then
            # Verify mount actually succeeded by checking if it shows in mount output
            if mount | grep -q "on ${mount_point} (nfs"; then
                mounted=true
                print_success "Mounted: ${BOLD}${mount_name}${NC} → $mount_point"
            else
                ((retry++))
            fi
        else
            ((retry++))
        fi
    done
    
    if [[ "$mounted" == false ]]; then
        print_error "Failed to mount after $MAX_RETRIES attempts: $mount_name"
        print_info "URL: $nfs_url"
        print_info "Mount point: $mount_point"
        if [[ -n "$mount_error" ]]; then
            print_error "Error: $mount_error"
        fi
        return 1
    fi
    
    return 0
}

# Mount all shares from config
mount_all() {
    local count
    count=$(yq eval '.mounts | length' "$CONFIG_FILE")
    
    print_info "Found ${BOLD}${count}${NC} mount(s) in configuration"
    if [[ "$SILENT_MODE" == false ]]; then
        echo ""
    fi
    
    local mounted=0
    local failed=0
    local skipped=0
    
    for i in $(seq 0 $((count - 1))); do
        local server=$(yq eval ".mounts[$i].server" "$CONFIG_FILE")
        local share=$(yq eval ".mounts[$i].share" "$CONFIG_FILE")
        local nfs_version=$(yq eval ".mounts[$i].nfs_version" "$CONFIG_FILE")
        local mount_name=$(yq eval ".mounts[$i].mount_name" "$CONFIG_FILE")
        local enabled=$(yq eval ".mounts[$i].enabled // true" "$CONFIG_FILE")
        local mount_use_resvport=$(yq eval ".mounts[$i].use_resvport // \"\"" "$CONFIG_FILE")
        
        if [[ "$enabled" != "true" ]]; then
            ((skipped++))
            continue
        fi
        
        if mount_nfs_share "$server" "$share" "$nfs_version" "$mount_name" "$enabled" "$mount_use_resvport"; then
            ((mounted++))
        else
            ((failed++))
        fi
        
        if [[ "$SILENT_MODE" == false ]]; then
            echo ""
        fi
    done
    
    if [[ "$SILENT_MODE" == false ]]; then
        echo -e "${BOLD}Summary:${NC}"
    fi
    print_success "Successfully mounted: ${BOLD}${mounted}${NC}"
    if [[ $skipped -gt 0 ]]; then
        print_info "Skipped (disabled): ${BOLD}${skipped}${NC}"
    fi
    if [[ $failed -gt 0 ]]; then
        print_error "Failed to mount: ${BOLD}${failed}${NC}"
        return 1
    fi
    return 0
}

# Unmount a single NFS share
unmount_nfs_share() {
    local mount_name="$1"
    local mount_point="${BASE_MOUNT_DIR}/${mount_name}"
    
    print_step "Processing: ${BOLD}${mount_name}${NC}"
    
    # Check if mount point exists
    if [[ ! -d "$mount_point" ]]; then
        print_info "Mount point does not exist: $mount_name"
        return 0
    fi
    
    # Check if currently mounted
    if ! mount | grep -q "on ${mount_point} "; then
        print_info "Not mounted: $mount_name"
        return 0
    fi
    
    # Attempt to unmount
    local unmount_error=""
    local unmount_status=0
    
    # Try unmount without sudo first
    unmount_error=$(umount "$mount_point" 2>&1)
    unmount_status=$?
    
    # If that fails and we're not root, try with sudo
    if [[ $unmount_status -ne 0 ]] && [[ $EUID -ne 0 ]]; then
        unmount_error=$(sudo -n umount "$mount_point" 2>&1)
        unmount_status=$?
    fi
    
    # If still failing, try force unmount
    if [[ $unmount_status -ne 0 ]] && [[ $EUID -ne 0 ]]; then
        print_info "Attempting force unmount..."
        unmount_error=$(sudo -n umount -f "$mount_point" 2>&1)
        unmount_status=$?
    fi
    
    if [[ $unmount_status -eq 0 ]]; then
        # Verify unmount actually succeeded
        if ! mount | grep -q "on ${mount_point} "; then
            print_success "Unmounted: ${BOLD}${mount_name}${NC} → $mount_point"
            return 0
        else
            print_error "Unmount reported success but mount still exists: $mount_name"
            return 1
        fi
    else
        print_error "Failed to unmount: $mount_name"
        print_info "Mount point: $mount_point"
        if [[ -n "$unmount_error" ]]; then
            print_error "Error: $unmount_error"
        fi
        return 1
    fi
}

# Unmount all shares from config
unmount_all() {
    print_header "Unmounting All NFS Shares"
    
    local count
    count=$(yq eval '.mounts | length' "$CONFIG_FILE")
    
    print_info "Found ${BOLD}${count}${NC} mount(s) in configuration"
    if [[ "$SILENT_MODE" == false ]]; then
        echo ""
    fi
    
    local unmounted=0
    local failed=0
    
    for i in $(seq 0 $((count - 1))); do
        local mount_name=$(yq eval ".mounts[$i].mount_name" "$CONFIG_FILE")
        
        if unmount_nfs_share "$mount_name"; then
            ((unmounted++))
        else
            ((failed++))
        fi
        
        if [[ "$SILENT_MODE" == false ]]; then
            echo ""
        fi
    done
    
    if [[ "$SILENT_MODE" == false ]]; then
        echo -e "${BOLD}Summary:${NC}"
    fi
    print_success "Successfully processed: ${BOLD}${unmounted}${NC}"
    if [[ $failed -gt 0 ]]; then
        print_error "Failed to unmount: ${BOLD}${failed}${NC}"
        return 1
    fi
    return 0
}

# Add entries to /etc/fstab for auto-mounting on boot
setup_automount() {
    print_header "Setting Up Auto-Mount on Boot"
    
    print_warning "This requires sudo privileges to modify /etc/fstab"
    print_info "You will be prompted for your password"
    echo ""
    
    local fstab_backup="/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Backup existing fstab if it exists
    if [[ -f /etc/fstab ]]; then
        print_step "Backing up /etc/fstab to $fstab_backup"
        sudo cp /etc/fstab "$fstab_backup"
        print_success "Backup created"
    fi
    
    print_step "Generating fstab entries..."
    echo ""
    
    local count
    count=$(yq eval '.mounts | length' "$CONFIG_FILE")
    
    local fstab_entries=""
    
    for i in $(seq 0 $((count - 1))); do
        local server=$(yq eval ".mounts[$i].server" "$CONFIG_FILE")
        local share=$(yq eval ".mounts[$i].share" "$CONFIG_FILE")
        local nfs_version=$(yq eval ".mounts[$i].nfs_version" "$CONFIG_FILE")
        local mount_name=$(yq eval ".mounts[$i].mount_name" "$CONFIG_FILE")
        local enabled=$(yq eval ".mounts[$i].enabled // true" "$CONFIG_FILE")
        local mount_point="${BASE_MOUNT_DIR}/${mount_name}"
        
        # Skip disabled mounts
        if [[ "$enabled" != "true" ]]; then
            continue
        fi
        
        # Create mount point if it doesn't exist
        mkdir -p "$mount_point"
        
        # Build fstab entry
        local nfs_url="${server}:${share}"
        local opts
        if [[ "$nfs_version" == "4" ]]; then
            opts="nfs vers=4,resvport,rw,bg,hard,intr 0 0"
        else
            opts="nfs vers=3,resvport,rw,bg,hard,intr,tcp 0 0"
        fi
        
        fstab_entries="${fstab_entries}${nfs_url} ${mount_point} ${opts}\n"
        print_info "Entry for: ${BOLD}${mount_name}${NC}"
    done
    
    echo ""
    print_step "Adding entries to /etc/fstab..."
    
    # Add header comment and entries to fstab
    {
        if [[ -f /etc/fstab ]]; then
            cat /etc/fstab
            echo ""
        fi
        echo "# NFS mounts added by nfs-mount-manager on $(date)"
        echo -e "$fstab_entries"
    } | sudo tee /etc/fstab > /dev/null
    
    print_success "Auto-mount configuration complete!"
    print_info "Mounts will be available after the next reboot"
    print_warning "To mount now, run this script without the --setup-automount flag"
}

# Remove automount entries from /etc/fstab
remove_automount() {
    print_header "Removing Auto-Mount Configuration"
    
    if [[ ! -f /etc/fstab ]]; then
        print_info "No /etc/fstab file found. Nothing to remove."
        return 0
    fi
    
    print_warning "This requires sudo privileges to modify /etc/fstab"
    echo ""
    
    local fstab_backup="/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)"
    
    print_step "Backing up /etc/fstab to $fstab_backup"
    sudo cp /etc/fstab "$fstab_backup"
    print_success "Backup created"
    
    # Remove lines containing our mount points
    local temp_fstab=$(mktemp)
    local removed=0
    
    while IFS= read -r line; do
        local should_remove=false
        
        # Check if line contains any of our mount points
        local count
        count=$(yq eval '.mounts | length' "$CONFIG_FILE")
        
        for i in $(seq 0 $((count - 1))); do
            local mount_name=$(yq eval ".mounts[$i].mount_name" "$CONFIG_FILE")
            local mount_point="${BASE_MOUNT_DIR}/${mount_name}"
            
            if [[ "$line" == *"$mount_point"* ]]; then
                should_remove=true
                ((removed++))
                break
            fi
        done
        
        if [[ "$should_remove" == false ]]; then
            echo "$line" >> "$temp_fstab"
        fi
    done < /etc/fstab
    
    sudo mv "$temp_fstab" /etc/fstab
    
    print_success "Removed ${BOLD}${removed}${NC} auto-mount entries"
    print_info "Changes will take effect after reboot"
}

# Show usage information
show_usage() {
    # Load settings to show current values
    if [[ -f "$CONFIG_FILE" ]]; then
        load_settings 2>/dev/null || true
    fi
    
    echo -e "${BOLD}NFS Mount Manager for macOS${NC}"
    echo ""
    echo -e "${BOLD}USAGE:${NC}"
    echo "    $0 [OPTIONS]"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "    (no options)           Mount all NFS shares from config"
    echo "    --unmount-all          Unmount all NFS shares from config"
    echo "    --setup-automount      Add entries to /etc/fstab for auto-mount on boot"
    echo "    --remove-automount     Remove auto-mount entries from /etc/fstab"
    echo "    --silent               Run in silent mode (no output, logs only)"
    echo "    --help                 Show this help message"
    echo ""
    echo -e "${BOLD}CONFIGURATION:${NC}"
    echo -e "    Config file: ${CYAN}${CONFIG_FILE}${NC}"
    echo -e "    Mount base:  ${CYAN}${BASE_MOUNT_DIR:-${HOME}/External}${NC}"
    echo -e "    Log file:    ${CYAN}${LOG_FILE}${NC}"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "    Mount all shares:"
    echo "        $0"
    echo ""
    echo "    Mount silently (for automation/Keyboard Maestro):"
    echo "        $0 --silent"
    echo ""
    echo "    Setup auto-mount on boot:"
    echo "        $0 --setup-automount"
    echo ""
    echo "    Remove auto-mount configuration:"
    echo "        $0 --remove-automount"
    echo ""
    echo "    Unmount all shares:"
    echo "        $0 --unmount-all"
    echo ""
    echo -e "${BOLD}KEYBOARD MAESTRO:${NC}"
    echo "    For use with Keyboard Maestro, use the --silent flag:"
    echo "        /bin/bash $0 --silent"
    echo ""
}

# Main function
main() {
    # Parse arguments for silent mode first
    for arg in "$@"; do
        if [[ "$arg" == "--silent" ]]; then
            SILENT_MODE=true
            break
        fi
    done
    
    init_logging
    
    if [[ "$SILENT_MODE" == false ]]; then
        print_header "NFS Mount Manager for macOS"
        print_info "Note: Mounting NFS shares requires sudo privileges"
        echo ""
    fi
    
    case "${1:-}" in
        --setup-automount)
            check_dependencies
            check_passwordless_sudo
            initialize_config
            validate_config
            create_base_dir
            setup_automount
            ;;
        --remove-automount)
            check_dependencies
            check_passwordless_sudo
            initialize_config
            validate_config
            remove_automount
            ;;
        --unmount-all)
            check_dependencies
            check_passwordless_sudo
            initialize_config
            validate_config
            if unmount_all; then
                if [[ "$SILENT_MODE" == false ]]; then
                    echo -e "\n${BOLD}${GREEN}✓ Done!${NC}\n"
                fi
                exit 0
            else
                exit 1
            fi
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        --silent)
            check_dependencies
            check_passwordless_sudo
            initialize_config
            validate_config
            create_base_dir
            if mount_all; then
                exit 0
            else
                exit 1
            fi
            ;;
        "")
            check_dependencies
            check_passwordless_sudo
            initialize_config
            validate_config
            create_base_dir
            if mount_all; then
                if [[ "$SILENT_MODE" == false ]]; then
                    echo -e "\n${BOLD}${GREEN}✓ Done!${NC}\n"
                fi
                exit 0
            else
                exit 1
            fi
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
    
    if [[ "$SILENT_MODE" == false ]]; then
        echo -e "\n${BOLD}${GREEN}✓ Done!${NC}\n"
    fi
}

# Run main function
main "$@"
