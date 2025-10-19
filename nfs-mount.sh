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
BASE_MOUNT_DIR="${HOME}/External"
LOG_FILE="${CONFIG_DIR}/nfs-mount.log"

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

# Validate YAML config file
validate_config() {
    print_step "Validating configuration..."
    
    # Check if file is valid YAML
    if ! yq eval '.' "$CONFIG_FILE" > /dev/null 2>&1; then
        print_error "Configuration file is not valid YAML: $CONFIG_FILE"
        exit 1
    fi
    
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
    
    # Skip if disabled
    if [[ "$enabled" != "true" ]]; then
        print_info "Skipping disabled mount: ${mount_name}"
        return 0
    fi
    
    local mount_point="${BASE_MOUNT_DIR}/${mount_name}"
    local nfs_url="nfs://${server}${share}"
    
    print_step "Processing: ${BOLD}${mount_name}${NC}"
    
    # Create mount point if it doesn't exist
    if [[ ! -d "$mount_point" ]]; then
        mkdir -p "$mount_point"
        print_info "Created directory: $mount_point"
    fi
    
    # Check if already mounted
    if mount | grep -q "on ${mount_point} "; then
        print_warning "Already mounted: $mount_name"
        return 0
    fi
    
    # Mount options optimized for macOS and TrueNAS
    local mount_opts=""
    if [[ "$nfs_version" == "4" ]]; then
        # NFSv4 options for macOS
        mount_opts="vers=4,resvport,rw,bg,hard,intr,noatime,async"
    else
        # NFSv3 options for macOS
        mount_opts="vers=3,resvport,rw,bg,hard,intr,noatime,async,tcp,rsize=65536,wsize=65536"
    fi
    
    # Attempt to mount with retries for reliability
    local max_retries=3
    local retry=0
    local mounted=false
    
    while [[ $retry -lt $max_retries ]] && [[ "$mounted" == false ]]; do
        if [[ $retry -gt 0 ]]; then
            print_info "Retry attempt $retry of $max_retries..."
            sleep 2
        fi
        
        if mount -t nfs -o "$mount_opts" "$nfs_url" "$mount_point" 2>/dev/null; then
            mounted=true
            print_success "Mounted: ${BOLD}${mount_name}${NC} → $mount_point"
        else
            ((retry++))
        fi
    done
    
    if [[ "$mounted" == false ]]; then
        print_error "Failed to mount after $max_retries attempts: $mount_name"
        print_info "URL: $nfs_url"
        print_info "Mount point: $mount_point"
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
        
        if [[ "$enabled" != "true" ]]; then
            ((skipped++))
            continue
        fi
        
        if mount_nfs_share "$server" "$share" "$nfs_version" "$mount_name" "$enabled"; then
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
    cat << EOF
${BOLD}NFS Mount Manager for macOS${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    (no options)           Mount all NFS shares from config
    --setup-automount      Add entries to /etc/fstab for auto-mount on boot
    --remove-automount     Remove auto-mount entries from /etc/fstab
    --silent               Run in silent mode (no output, logs only)
    --help                 Show this help message

${BOLD}CONFIGURATION:${NC}
    Config file: ${CYAN}${CONFIG_FILE}${NC}
    Mount base:  ${CYAN}${BASE_MOUNT_DIR}${NC}
    Log file:    ${CYAN}${LOG_FILE}${NC}

${BOLD}EXAMPLES:${NC}
    Mount all shares:
        $0

    Mount silently (for automation/Keyboard Maestro):
        $0 --silent

    Setup auto-mount on boot:
        $0 --setup-automount

    Remove auto-mount configuration:
        $0 --remove-automount

${BOLD}KEYBOARD MAESTRO:${NC}
    For use with Keyboard Maestro, use the --silent flag:
        /bin/bash $0 --silent

EOF
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
    fi
    
    case "${1:-}" in
        --setup-automount)
            check_dependencies
            initialize_config
            validate_config
            create_base_dir
            setup_automount
            ;;
        --remove-automount)
            check_dependencies
            initialize_config
            validate_config
            remove_automount
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        --silent)
            check_dependencies
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
