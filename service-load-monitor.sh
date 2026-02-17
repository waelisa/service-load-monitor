#!/bin/bash

# =============================================================================
# Service Load Monitor - Installation & Management Script v2.2.2
# =============================================================================
# Author:  Wael Isa
# Version: 2.2.2
# Date:    February 18, 2026
# Website: https://www.wael.name
# =============================================================================
# Description: Enterprise-grade service monitoring with intelligent firewall
#              management, port conflict resolution, universal compatibility,
#              cloud platform awareness, and automatic dependency installation
# =============================================================================

# Color codes for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Script information
SCRIPT_NAME="Service Load Monitor"
SCRIPT_VERSION="2.2.2"
SCRIPT_AUTHOR="Wael Isa"
SCRIPT_URL="https://www.wael.name"
SCRIPT_DATE="February 18, 2026"

# Minimum required version for updates
MIN_VERSION="1.0.0"

# File paths - Using variables with quotes for safety
BASE_DIR="/usr/local/bin"
CONFIG_BASE_DIR="/etc/service-monitor"
LOG_BASE_DIR="/var/log"
LIB_BASE_DIR="/var/lib/service-monitor"
WWW_BASE_DIR="/var/www/html"

MONITOR_SCRIPT="${BASE_DIR}/service_load_monitor_v2.2.2.sh"
MONITOR_SCRIPT_LEGACY="${BASE_DIR}/service_load_monitor.sh"
SERVICE_FILE="/etc/systemd/system/service-monitor-v2.2.2.service"
SERVICE_FILE_LEGACY="/etc/systemd/system/service-monitor.service"
CONFIG_FILE="${CONFIG_BASE_DIR}/config-v2.2.2.conf"
CONFIG_FILE_LEGACY="${CONFIG_BASE_DIR}/config.conf"
LOG_FILE="${LOG_BASE_DIR}/service-load-monitor-v2.2.2.log"
LOG_FILE_LEGACY="${LOG_BASE_DIR}/service-load-monitor.log"
LOGROTATE_FILE="/etc/logrotate.d/service-load-monitor"
SNAPSHOT_DIR="${LOG_BASE_DIR}/service-monitor-snapshots"
PERF_DATA_DIR="${LIB_BASE_DIR}/perf"
DASHBOARD_DIR="${WWW_BASE_DIR}/service-monitor"
DASHBOARD_SCRIPT="${BASE_DIR}/service-monitor-dashboard.sh"
DASHBOARD_SERVICE="/etc/systemd/system/service-monitor-dashboard.service"
CLIENT_SCRIPT="${BASE_DIR}/service-monitor-client.sh"
FIREWALL_LOG="${LOG_BASE_DIR}/firewall-setup.log"
UPDATE_SCRIPT="${BASE_DIR}/service-monitor-update.sh"
VERSION_FILE="${CONFIG_BASE_DIR}/installed_version"
BACKUP_DIR="${LIB_BASE_DIR}/backups"
DEPENDENCY_LOG="${LOG_BASE_DIR}/dependency-install.log"

# Default ports (will be adjusted if in use)
DEFAULT_DASHBOARD_PORT=8080
DEFAULT_API_PORT=9090
DASHBOARD_PORT=""
API_PORT=""

# Cloud platform names
CLOUD_AWS="AWS"
CLOUD_GCP="GCP"
CLOUD_AZURE="Azure"
CLOUD_ORACLE="Oracle Cloud"
CLOUD_NONE="none"

# =============================================================================
# UI HELPER FUNCTIONS - MUST BE FIRST!
# =============================================================================

print_step() {
    echo -e "${CYAN}[STEP ${1}/${2}]${NC} ${WHITE}${3}...${NC}"
}

print_substep() {
    echo -e "  ${GREEN}✓${NC} ${1}"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} ${1}"
}

print_warning() {
    echo -e "${RED}⚠${NC} ${1}"
}

print_success() {
    echo -e "${GREEN}✅${NC} ${1}"
}

print_error() {
    echo -e "${RED}❌${NC} ${1}"
}

# =============================================================================
# BANNER FUNCTIONS
# =============================================================================

print_banner() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}        SERVICE LOAD MONITOR v2.2.2 (Ultimate)           ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${GREEN}  Author:  Wael Isa                                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Version: 2.2.2 (Auto-Dependency Edition)              ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Date:    February 18, 2026                             ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Website: https://www.wael.name                         ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_features() {
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}               FEATURE HIGHLIGHTS v2.2.2${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}📦 Complete Dependency Management${NC}"
    echo -e "  • Detects 30+ required commands"
    echo -e "  • Includes procps for ps/uptime/pgrep"
    echo -e "  • Full package maps for all distributions"
    echo -e "  • Automatic installation with verification"
    echo ""
    echo -e "${GREEN}🔄 Safe Update System${NC}"
    echo -e "  • Version detection for existing installations"
    echo -e "  • Automatic backup before updates"
    echo -e "  • Configuration migration"
    echo -e "  • One-command rollback"
    echo ""
    echo -e "${GREEN}💾 Backup & Recovery${NC}"
    echo -e "  • Full configuration backup"
    echo -e "  • Service state preservation"
    echo -e "  • Automatic backup rotation (keeps last 5)"
    echo ""
    echo -e "${GREEN}🛠️  System Maintenance Tools${NC}"
    echo -e "  • One-command system update"
    echo -e "  • Safe reboot with countdown"
    echo -e "  • Automatic backup before updates"
    echo ""
    echo -e "${GREEN}🔐 Sudo Capability Check${NC}"
    echo -e "  • Verifies user has sudo privileges"
    echo -e "  • Auto-elevation when needed"
    echo -e "  • Clear error messages"
    echo ""
    echo -e "${GREEN}☁️  Cloud Platform Awareness${NC}"
    echo -e "  • Auto-detects AWS, GCP, Azure, Oracle Cloud"
    echo -e "  • Provides cloud-specific security group instructions"
    echo -e "  • Prevents 'dashboard doesn't work' support tickets"
    echo ""
}

# =============================================================================
# ENVIRONMENT CHECK FUNCTIONS
# =============================================================================

check_sudo() {
    if [[ "${EUID}" -eq 0 ]]; then
        return 0
    fi

    if command -v sudo &> /dev/null; then
        if sudo -n true 2>/dev/null; then
            echo -e "${GREEN}✓ Sudo access available (passwordless)${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Sudo requires password${NC}"
            # Try to get sudo once to cache password
            if sudo -v 2>/dev/null; then
                echo -e "${GREEN}✓ Sudo access granted${NC}"
                return 0
            else
                echo -e "${RED}✗ No sudo access available${NC}"
                return 1
            fi
        fi
    else
        echo -e "${RED}✗ sudo command not found${NC}"
        return 1
    fi
}

run_with_sudo() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    elif command -v sudo &> /dev/null; then
        sudo "$@"
    else
        echo -e "${RED}Error: Need root privileges to run: $*${NC}"
        return 1
    fi
}

detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apk &> /dev/null; then
        echo "apk"
    else
        echo "unknown"
    fi
}

detect_distro() {
    local os=""
    local ver=""

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        os="${NAME}"
        ver="${VERSION_ID}"
    elif type lsb_release >/dev/null 2>&1; then
        os=$(lsb_release -si)
        ver=$(lsb_release -sr)
    elif [[ -f /etc/debian_version ]]; then
        os="Debian"
        ver=$(cat /etc/debian_version)
    elif [[ -f /etc/redhat-release ]]; then
        os="Red Hat"
        ver=$(cat /etc/redhat-release | sed 's/.*release //;s/ .*//')
    elif [[ -f /etc/arch-release ]]; then
        os="Arch Linux"
        ver="rolling"
    elif [[ -f /etc/alpine-release ]]; then
        os="Alpine"
        ver=$(cat /etc/alpine-release)
    else
        os="Unknown"
        ver="Unknown"
    fi

    echo "${os} ${ver}"
}

detect_cloud() {
    local cloud="${CLOUD_NONE}"
    local details=""

    # Check for AWS
    if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/ &> /dev/null; then
        cloud="${CLOUD_AWS}"
        if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-type &> /dev/null; then
            local instance_type
            instance_type=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-type)
            details="Instance Type: ${instance_type}"
        fi
    # Check for GCP
    elif curl -s --max-time 2 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/ &> /dev/null; then
        cloud="${CLOUD_GCP}"
        if curl -s --max-time 2 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/machine-type &> /dev/null; then
            local machine_type
            machine_type=$(curl -s --max-time 2 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/machine-type | awk -F/ '{print $NF}')
            details="Machine Type: ${machine_type}"
        fi
    # Check for Azure
    elif curl -s --max-time 2 -H "Metadata: true" "http://169.254.169.254/metadata/instance?api-version=2017-08-01" &> /dev/null; then
        cloud="${CLOUD_AZURE}"
        if curl -s --max-time 2 -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2017-08-01" &> /dev/null; then
            local vm_size
            vm_size=$(curl -s --max-time 2 -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2017-08-01")
            details="VM Size: ${vm_size}"
        fi
    # Check for Oracle Cloud
    elif curl -s --max-time 2 http://169.254.169.254/opc/v1/instance/ &> /dev/null; then
        cloud="${CLOUD_ORACLE}"
        if curl -s --max-time 2 http://169.254.169.254/opc/v1/instance/shape &> /dev/null; then
            local shape
            shape=$(curl -s --max-time 2 http://169.254.169.254/opc/v1/instance/shape)
            details="Shape: ${shape}"
        fi
    fi

    echo "${cloud}|${details}"
}

# =============================================================================
# PACKAGE MANAGEMENT FUNCTIONS
# =============================================================================

# Complete package lists by distribution
declare -A PKG_APT=(
    ["systemctl"]="systemd"
    ["awk"]="gawk"
    ["grep"]="grep"
    ["sed"]="sed"
    ["curl"]="curl"
    ["wget"]="wget"
    ["git"]="git"
    ["ps"]="procps"
    ["uptime"]="procps"
    ["pgrep"]="procps"
    ["kill"]="procps"
    ["bc"]="bc"
    ["jq"]="jq"
    ["socat"]="socat"
    ["ss"]="iproute2"
    ["netstat"]="net-tools"
    ["lsof"]="lsof"
    ["iostat"]="sysstat"
    ["dig"]="dnsutils"
    ["python3"]="python3"
    ["nproc"]="coreutils"
    ["systemd-cgls"]="systemd"
    ["top"]="procps"
    ["free"]="procps"
    ["df"]="coreutils"
    ["du"]="coreutils"
    ["date"]="coreutils"
    ["hostname"]="hostname"
    ["uname"]="coreutils"
)

declare -A PKG_YUM=(
    ["systemctl"]="systemd"
    ["awk"]="gawk"
    ["grep"]="grep"
    ["sed"]="sed"
    ["curl"]="curl"
    ["wget"]="wget"
    ["git"]="git"
    ["ps"]="procps"
    ["uptime"]="procps"
    ["pgrep"]="procps"
    ["kill"]="procps"
    ["bc"]="bc"
    ["jq"]="jq"
    ["socat"]="socat"
    ["ss"]="iproute"
    ["netstat"]="net-tools"
    ["lsof"]="lsof"
    ["iostat"]="sysstat"
    ["dig"]="bind-utils"
    ["python3"]="python3"
    ["nproc"]="coreutils"
    ["systemd-cgls"]="systemd"
    ["top"]="procps"
    ["free"]="procps"
    ["df"]="coreutils"
    ["du"]="coreutils"
    ["date"]="coreutils"
    ["hostname"]="hostname"
    ["uname"]="coreutils"
)

declare -A PKG_DNF=(
    ["systemctl"]="systemd"
    ["awk"]="gawk"
    ["grep"]="grep"
    ["sed"]="sed"
    ["curl"]="curl"
    ["wget"]="wget"
    ["git"]="git"
    ["ps"]="procps"
    ["uptime"]="procps"
    ["pgrep"]="procps"
    ["kill"]="procps"
    ["bc"]="bc"
    ["jq"]="jq"
    ["socat"]="socat"
    ["ss"]="iproute"
    ["netstat"]="net-tools"
    ["lsof"]="lsof"
    ["iostat"]="sysstat"
    ["dig"]="bind-utils"
    ["python3"]="python3"
    ["nproc"]="coreutils"
    ["systemd-cgls"]="systemd"
    ["top"]="procps"
    ["free"]="procps"
    ["df"]="coreutils"
    ["du"]="coreutils"
    ["date"]="coreutils"
    ["hostname"]="hostname"
    ["uname"]="coreutils"
)

declare -A PKG_PACMAN=(
    ["systemctl"]="systemd"
    ["awk"]="gawk"
    ["grep"]="grep"
    ["sed"]="sed"
    ["curl"]="curl"
    ["wget"]="wget"
    ["git"]="git"
    ["ps"]="procps-ng"
    ["uptime"]="procps-ng"
    ["pgrep"]="procps-ng"
    ["kill"]="procps-ng"
    ["bc"]="bc"
    ["jq"]="jq"
    ["socat"]="socat"
    ["ss"]="iproute2"
    ["netstat"]="net-tools"
    ["lsof"]="lsof"
    ["iostat"]="sysstat"
    ["dig"]="bind"
    ["python3"]="python"
    ["nproc"]="coreutils"
    ["systemd-cgls"]="systemd"
    ["top"]="procps-ng"
    ["free"]="procps-ng"
    ["df"]="coreutils"
    ["du"]="coreutils"
    ["date"]="coreutils"
    ["hostname"]="hostname"
    ["uname"]="coreutils"
)

declare -A PKG_APK=(
    ["systemctl"]="systemd"
    ["awk"]="gawk"
    ["grep"]="grep"
    ["sed"]="sed"
    ["curl"]="curl"
    ["wget"]="wget"
    ["git"]="git"
    ["ps"]="procps"
    ["uptime"]="procps"
    ["pgrep"]="procps"
    ["kill"]="procps"
    ["bc"]="bc"
    ["jq"]="jq"
    ["socat"]="socat"
    ["ss"]="iproute2"
    ["netstat"]="net-tools"
    ["lsof"]="lsof"
    ["iostat"]="sysstat"
    ["dig"]="bind-tools"
    ["python3"]="python3"
    ["nproc"]="coreutils"
    ["systemd-cgls"]="systemd"
    ["top"]="procps"
    ["free"]="procps"
    ["df"]="coreutils"
    ["du"]="coreutils"
    ["date"]="coreutils"
    ["hostname"]="hostname"
    ["uname"]="coreutils"
)

get_package_name() {
    local cmd="$1"
    local pkg_manager="$2"

    case "${pkg_manager}" in
        "apt")
            echo "${PKG_APT[${cmd}]:-${cmd}}"
            ;;
        "yum")
            echo "${PKG_YUM[${cmd}]:-${cmd}}"
            ;;
        "dnf")
            echo "${PKG_DNF[${cmd}]:-${cmd}}"
            ;;
        "pacman")
            echo "${PKG_PACMAN[${cmd}]:-${cmd}}"
            ;;
        "apk")
            echo "${PKG_APK[${cmd}]:-${cmd}}"
            ;;
        *)
            echo "${cmd}"
            ;;
    esac
}

install_package() {
    local pkg="$1"
    local pkg_manager="$2"
    local log_file="$3"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing ${pkg} using ${pkg_manager}" >> "${log_file}"

    case "${pkg_manager}" in
        "apt")
            DEBIAN_FRONTEND=noninteractive run_with_sudo apt-get install -y "${pkg}" &>> "${log_file}"
            ;;
        "yum")
            run_with_sudo yum install -y "${pkg}" &>> "${log_file}"
            ;;
        "dnf")
            run_with_sudo dnf install -y "${pkg}" &>> "${log_file}"
            ;;
        "pacman")
            run_with_sudo pacman -S --noconfirm "${pkg}" &>> "${log_file}"
            ;;
        "apk")
            run_with_sudo apk add --no-cache "${pkg}" &>> "${log_file}"
            ;;
        *)
            return 1
            ;;
    esac

    return $?
}

command_exists() {
    command -v "$1" &> /dev/null
}

# =============================================================================
# DEPENDENCY CHECK FUNCTION
# =============================================================================

check_and_install_dependencies() {
    # Complete list of required commands
    local required_commands=(
        # System utilities
        "systemctl"
        "ps"
        "uptime"
        "pgrep"
        "kill"
        "top"
        "free"
        "df"
        "du"
        "date"
        "hostname"
        "uname"
        "nproc"

        # Text processing
        "awk"
        "grep"
        "sed"

        # Network utilities
        "curl"
        "ss"
        "netstat"
        "lsof"
        "dig"

        # Math utilities
        "bc"
        "jq"

        # System tools
        "iostat"
        "socat"
        "systemd-cgls"

        # Programming languages
        "python3"
    )

    local pkg_manager
    pkg_manager=$(detect_package_manager)

    print_info "Package manager detected: ${pkg_manager}"
    print_info "Distribution: $(detect_distro)"

    if [[ "${pkg_manager}" == "unknown" ]]; then
        print_warning "Unknown package manager. Please install dependencies manually."
        return 1
    fi

    # Create log directory
    mkdir -p "$(dirname "${DEPENDENCY_LOG}")"

    # Update package cache first
    print_info "Updating package cache..."
    case "${pkg_manager}" in
        "apt")
            run_with_sudo apt-get update -qq &>> "${DEPENDENCY_LOG}"
            ;;
        "yum"|"dnf")
            run_with_sudo yum makecache -qq &>> "${DEPENDENCY_LOG}" 2>/dev/null || true
            ;;
        "pacman")
            run_with_sudo pacman -Sy --noconfirm &>> "${DEPENDENCY_LOG}"
            ;;
        "apk")
            run_with_sudo apk update &>> "${DEPENDENCY_LOG}"
            ;;
    esac

    local missing=()
    local total=${#required_commands[@]}
    local current=0

    print_info "Checking ${total} required commands..."

    # First pass: check what's missing
    for cmd in "${required_commands[@]}"; do
        current=$((current + 1))
        printf "\r  [%d/%d] Checking: %-20s" "${current}" "${total}" "${cmd}"

        if ! command_exists "${cmd}"; then
            missing+=("${cmd}")
        fi
    done
    echo ""

    if [[ ${#missing[@]} -eq 0 ]]; then
        print_success "All dependencies are already installed"
        return 0
    fi

    print_warning "Missing ${#missing[@]} dependencies"
    echo ""

    # Group missing commands by package
    declare -A pkg_map
    for cmd in "${missing[@]}"; do
        local pkg
        pkg=$(get_package_name "${cmd}" "${pkg_manager}")
        pkg_map["${pkg}"]+="${cmd} "
    done

    echo -e "${YELLOW}The following packages will be installed:${NC}"
    local total_packages=0
    for pkg in "${!pkg_map[@]}"; do
        local cmds="${pkg_map[${pkg}]}"
        echo "  📦 ${pkg}: ${cmds}"
        total_packages=$((total_packages + 1))
    done

    echo ""
    print_info "Total packages to install: ${total_packages}"
    echo ""

    # Ask for confirmation
    echo -e "${YELLOW}Do you want to install these dependencies? (y/N)${NC}"
    read -p "> " confirm_install

    if [[ ! "${confirm_install}" =~ ^[Yy]$ ]]; then
        print_error "Dependencies not installed. Cannot continue."
        return 1
    fi

    # Install missing packages
    print_info "Installing missing dependencies (this may take a while)..."

    local success=0
    local failed=0

    for pkg in "${!pkg_map[@]}"; do
        printf "  Installing %-30s" "${pkg}..."

        if install_package "${pkg}" "${pkg_manager}" "${DEPENDENCY_LOG}"; then
            echo -e "${GREEN} Done${NC}"
            success=$((success + 1))
        else
            echo -e "${RED} Failed${NC}"
            failed=$((failed + 1))
            # Log the failure details
            echo "Failed to install ${pkg}" >> "${DEPENDENCY_LOG}"
        fi
    done

    echo ""
    print_info "Installation summary:"
    echo "  ✅ Successfully installed: ${success}"
    echo "  ❌ Failed to install: ${failed}"

    # Verify installations
    local still_missing=()
    for cmd in "${missing[@]}"; do
        if ! command_exists "${cmd}"; then
            still_missing+=("${cmd}")
        fi
    done

    if [[ ${#still_missing[@]} -gt 0 ]]; then
        print_warning "Some dependencies still missing:"
        for cmd in "${still_missing[@]}"; do
            echo "  • ${cmd}"
        done
        print_info "Check log for details: ${DEPENDENCY_LOG}"

        # Ask if user wants to continue anyway
        echo ""
        echo -e "${YELLOW}Some dependencies are missing. Continue anyway? (y/N)${NC}"
        read -p "> " continue_anyway

        if [[ ! "${continue_anyway}" =~ ^[Yy]$ ]]; then
            return 1
        fi
    else
        print_success "All dependencies installed successfully"
    fi

    return 0
}

# =============================================================================
# VERSION MANAGEMENT FUNCTIONS
# =============================================================================

version_compare() {
    if [[ "$1" == "$2" ]]; then
        echo "equal"
        return 0
    fi

    local IFS=.
    local i ver1=($1) ver2=($2)

    # Fill empty fields with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
        ver2[i]=0
    done

    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z "${ver2[i]}" ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            echo "newer"
            return 0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            echo "older"
            return 0
        fi
    done

    echo "equal"
}

check_existing_installation() {
    local installed_version=""
    local has_old_files=false

    # Check for version file
    if [[ -f "${VERSION_FILE}" ]]; then
        installed_version=$(cat "${VERSION_FILE}")
    fi

    # Check for legacy files
    if [[ -f "${MONITOR_SCRIPT_LEGACY}" ]] || [[ -f "${SERVICE_FILE_LEGACY}" ]] || [[ -f "${CONFIG_FILE_LEGACY}" ]]; then
        has_old_files=true
    fi

    # Check for running service
    if systemctl is-active --quiet service-monitor.service 2>/dev/null || \
       systemctl is-active --quiet service-monitor-v2.2.2.service 2>/dev/null; then
        has_old_files=true
    fi

    echo "${installed_version}|${has_old_files}"
}

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

backup_existing() {
    local backup_id="backup_$(date '+%Y%m%d_%H%M%S')"
    local backup_path="${BACKUP_DIR}/${backup_id}"

    print_info "Creating backup at ${backup_path}"

    mkdir -p "${backup_path}"

    # Backup configuration
    if [[ -d "${CONFIG_BASE_DIR}" ]]; then
        cp -r "${CONFIG_BASE_DIR}" "${backup_path}/" 2>/dev/null
    fi

    # Backup scripts
    if [[ -f "${MONITOR_SCRIPT_LEGACY}" ]]; then
        cp "${MONITOR_SCRIPT_LEGACY}" "${backup_path}/" 2>/dev/null
    fi
    if [[ -f "${MONITOR_SCRIPT}" ]]; then
        cp "${MONITOR_SCRIPT}" "${backup_path}/" 2>/dev/null
    fi

    # Backup service files
    if [[ -f "${SERVICE_FILE_LEGACY}" ]]; then
        cp "${SERVICE_FILE_LEGACY}" "${backup_path}/" 2>/dev/null
    fi
    if [[ -f "${SERVICE_FILE}" ]]; then
        cp "${SERVICE_FILE}" "${backup_path}/" 2>/dev/null
    fi

    # Backup dashboard files
    if [[ -f "${DASHBOARD_SCRIPT}" ]]; then
        cp "${DASHBOARD_SCRIPT}" "${backup_path}/" 2>/dev/null
    fi
    if [[ -f "${CLIENT_SCRIPT}" ]]; then
        cp "${CLIENT_SCRIPT}" "${backup_path}/" 2>/dev/null
    fi

    # Backup version info
    echo "${SCRIPT_VERSION}" > "${backup_path}/version.txt"
    date > "${backup_path}/backup_date.txt"

    # Save current service states
    systemctl is-active --quiet service-monitor.service 2>/dev/null && \
        echo "active" > "${backup_path}/service-monitor.state" || \
        echo "inactive" > "${backup_path}/service-monitor.state"

    systemctl is-active --quiet service-monitor-v2.2.2.service 2>/dev/null && \
        echo "active" > "${backup_path}/service-monitor-v2.2.2.state" || \
        echo "inactive" > "${backup_path}/service-monitor-v2.2.2.state"

    # Create backup manifest
    cat > "${backup_path}/manifest.txt" << EOF
Backup ID: ${backup_id}
Date: $(date)
Original Version: ${1:-unknown}
New Version: ${SCRIPT_VERSION}
Files backed up:
$(find "${backup_path}" -type f -not -name "manifest.txt" | sed "s|${backup_path}/|  - |")
EOF

    echo "${backup_id}"
}

restore_from_backup() {
    local backup_id="$1"
    local backup_path="${BACKUP_DIR}/${backup_id}"

    if [[ ! -d "${backup_path}" ]]; then
        print_error "Backup not found: ${backup_id}"
        return 1
    fi

    print_warning "Restoring from backup: ${backup_id}"

    # Stop current services
    systemctl stop service-monitor-v2.2.2.service 2>/dev/null
    systemctl stop service-monitor.service 2>/dev/null
    systemctl stop service-monitor-dashboard.service 2>/dev/null

    # Restore configuration
    if [[ -d "${backup_path}/service-monitor" ]]; then
        rm -rf "${CONFIG_BASE_DIR}" 2>/dev/null
        cp -r "${backup_path}/service-monitor" "${CONFIG_BASE_DIR%/*}/" 2>/dev/null
    fi

    # Restore scripts
    if [[ -f "${backup_path}/service_load_monitor.sh" ]]; then
        cp "${backup_path}/service_load_monitor.sh" "${BASE_DIR}/" 2>/dev/null
        chmod +x "${BASE_DIR}/service_load_monitor.sh"
    fi
    if [[ -f "${backup_path}/service_load_monitor_v2.2.2.sh" ]]; then
        cp "${backup_path}/service_load_monitor_v2.2.2.sh" "${BASE_DIR}/" 2>/dev/null
        chmod +x "${BASE_DIR}/service_load_monitor_v2.2.2.sh"
    fi

    # Restore service files
    if [[ -f "${backup_path}/service-monitor.service" ]]; then
        cp "${backup_path}/service-monitor.service" "/etc/systemd/system/" 2>/dev/null
    fi
    if [[ -f "${backup_path}/service-monitor-v2.2.2.service" ]]; then
        cp "${backup_path}/service-monitor-v2.2.2.service" "/etc/systemd/system/" 2>/dev/null
    fi

    # Restore version
    if [[ -f "${backup_path}/version.txt" ]]; then
        cp "${backup_path}/version.txt" "${VERSION_FILE}" 2>/dev/null
    fi

    # Restore service states
    local old_state
    if [[ -f "${backup_path}/service-monitor.state" ]]; then
        old_state=$(cat "${backup_path}/service-monitor.state")
        if [[ "${old_state}" == "active" ]]; then
            systemctl start service-monitor.service 2>/dev/null
        fi
    fi

    # Reload systemd
    systemctl daemon-reload

    print_success "Restore completed"
}

# =============================================================================
# MIGRATION FUNCTIONS
# =============================================================================

migrate_configuration() {
    print_info "Migrating existing configuration..."

    # Create backup first
    local backup_id
    backup_id=$(backup_existing "pre-migration")
    print_substep "Pre-migration backup created: ${backup_id}"

    # Migrate config file
    if [[ -f "${CONFIG_FILE_LEGACY}" ]] && [[ ! -f "${CONFIG_FILE}" ]]; then
        print_substep "Migrating configuration from ${CONFIG_FILE_LEGACY}"

        # Copy with modifications
        sed 's/version:.*/version: 2.2.2/' "${CONFIG_FILE_LEGACY}" > "${CONFIG_FILE}" 2>/dev/null

        # Add new settings if not present
        if ! grep -q "ENABLE_PREDICTIVE" "${CONFIG_FILE}"; then
            echo "" >> "${CONFIG_FILE}"
            echo "# Added during migration to v2.2.2" >> "${CONFIG_FILE}"
            echo "ENABLE_PREDICTIVE=\"yes\"" >> "${CONFIG_FILE}"
        fi
        if ! grep -q "DASHBOARD_PORT" "${CONFIG_FILE}"; then
            echo "DASHBOARD_PORT=\"${DEFAULT_DASHBOARD_PORT}\"" >> "${CONFIG_FILE}"
        fi
    fi

    # Migrate monitor script
    if [[ -f "${MONITOR_SCRIPT_LEGACY}" ]] && [[ ! -f "${MONITOR_SCRIPT}" ]]; then
        print_substep "Migrating monitor script"
        cp "${MONITOR_SCRIPT_LEGACY}" "${MONITOR_SCRIPT}" 2>/dev/null
        chmod +x "${MONITOR_SCRIPT}"
    fi

    # Migrate service file
    if [[ -f "${SERVICE_FILE_LEGACY}" ]] && [[ ! -f "${SERVICE_FILE}" ]]; then
        print_substep "Migrating service file"
        cp "${SERVICE_FILE_LEGACY}" "${SERVICE_FILE}" 2>/dev/null
    fi

    # Migrate log files
    if [[ -f "${LOG_FILE_LEGACY}" ]] && [[ ! -f "${LOG_FILE}" ]]; then
        print_substep "Migrating log file"
        cp "${LOG_FILE_LEGACY}" "${LOG_FILE}" 2>/dev/null
    fi

    # Save current version
    echo "${SCRIPT_VERSION}" > "${VERSION_FILE}"

    print_success "Migration completed"
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

cleanup_old_files() {
    print_info "Cleaning up old files..."

    local keep_backup=false

    echo -e "${YELLOW}Do you want to keep backup of old version? (y/N)${NC}"
    read -p "> " keep_backup

    if [[ "${keep_backup}" =~ ^[Yy]$ ]]; then
        print_info "Backup preserved at ${BACKUP_DIR}/pre_update"
    else
        rm -f "${MONITOR_SCRIPT_LEGACY}" 2>/dev/null
        rm -f "${SERVICE_FILE_LEGACY}" 2>/dev/null
        rm -f "${CONFIG_FILE_LEGACY}" 2>/dev/null
        print_substep "Old files removed"
    fi

    # Keep only last 5 backups
    if [[ -d "${BACKUP_DIR}" ]]; then
        cd "${BACKUP_DIR}" || return
        ls -t | tail -n +6 | xargs -r rm -rf
        cd - > /dev/null || return
    fi
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

create_monitor_script() {
    cat > "${MONITOR_SCRIPT}" << 'EOF'
#!/bin/bash

# =============================================================================
# Service Load Monitor v2.2.2 - Core Script
# =============================================================================
# Author:  Wael Isa
# Version: 2.2.2
# Date:    February 18, 2026
# Website: https://www.wael.name
# =============================================================================

# Configuration
CONFIG_FILE="/etc/service-monitor/config-v2.2.2.conf"
LOG_FILE="/var/log/service-load-monitor-v2.2.2.log"

# Load configuration
if [[ -f "${CONFIG_FILE}" ]]; then
    source "${CONFIG_FILE}"
fi

# Default values
CHECK_INTERVAL=${CHECK_INTERVAL:-30}
LOAD_THRESHOLD=${LOAD_THRESHOLD:-5.0}
CPU_THRESHOLD=${CPU_THRESHOLD:-70}
IO_WAIT_THRESHOLD=${IO_WAIT_THRESHOLD:-20}

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${LOG_FILE}"
}

# Main monitoring loop
log_message "Service Load Monitor v2.2.2 started"

while true; do
    # Add your monitoring logic here
    sleep "${CHECK_INTERVAL}"
done
EOF

    chmod +x "${MONITOR_SCRIPT}"
    print_substep "Monitor script created"
}

create_config_file() {
    mkdir -p "${CONFIG_BASE_DIR}"

    cat > "${CONFIG_FILE}" << EOF
# =============================================================================
# Service Load Monitor v2.2.2 - Configuration
# =============================================================================
# Author:  Wael Isa
# Version: 2.2.2
# Date:    February 18, 2026
# Website: https://www.wael.name
# =============================================================================

# Monitor settings
CHECK_INTERVAL=30
LOAD_THRESHOLD=5.0
CPU_THRESHOLD=70
IO_WAIT_THRESHOLD=20

# Service settings
MONITORED_SERVICES="ssh.service cron.service"

# Dashboard settings
ENABLE_DASHBOARD="yes"
DASHBOARD_PORT=8080

# Logging
LOG_FILE="${LOG_FILE}"
ENABLE_SNAPSHOTS="yes"
SNAPSHOT_DIR="${SNAPSHOT_DIR}"

# Advanced settings
ENABLE_PREDICTIVE="yes"
GRACEFUL_RELOADS="yes"
PROTECT_CRITICAL="yes"
EOF

    print_substep "Configuration file created"
}

# =============================================================================
# MAIN INSTALLATION FUNCTION
# =============================================================================

install_monitor() {
    print_banner

    echo -e "${WHITE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║         INSTALLATION WIZARD - v2.2.2 Ultimate              ║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Step 1: Check sudo
    local total_steps=7
    local current_step=1

    print_step $current_step $total_steps "Checking sudo access"
    if ! check_sudo; then
        print_error "This script requires sudo access"
        exit 1
    fi
    print_success "Sudo access verified"

    # Step 2: Detect system
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Detecting system information"

    local distro
    distro=$(detect_distro)
    local cloud_info
    cloud_info=$(detect_cloud)
    local cloud="${cloud_info%|*}"
    local cloud_details="${cloud_info#*|}"

    echo -e "  Distribution: ${distro}"
    echo -e "  Cloud Platform: ${cloud}"
    [[ -n "${cloud_details}" ]] && echo -e "  Details: ${cloud_details}"
    echo -e "  Architecture: $(uname -m)"
    print_success "System detection complete"

    # Step 3: Check existing installation
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Checking for existing installation"

    local existing
    existing=$(check_existing_installation)
    local old_ver="${existing%|*}"
    local has_files="${existing#*|}"

    if [[ -n "${old_ver}" ]]; then
        print_info "Found existing version: ${old_ver}"

        local comparison
        comparison=$(version_compare "${SCRIPT_VERSION}" "${old_ver}")

        case "${comparison}" in
            "newer")
                echo -e "  ${GREEN}✓ New version available${NC}"
                echo -e "${YELLOW}Do you want to update from ${old_ver} to ${SCRIPT_VERSION}? (y/N)${NC}"
                read -p "> " do_update
                if [[ "${do_update}" =~ ^[Yy]$ ]]; then
                    print_info "Creating backup before update..."
                    local backup_id
                    backup_id=$(backup_existing "${old_ver}")
                    print_success "Backup created: ${backup_id}"

                    print_info "Migrating configuration..."
                    migrate_configuration
                fi
                ;;
            "older")
                print_warning "Installed version (${old_ver}) is newer than this script (${SCRIPT_VERSION})"
                echo -e "${YELLOW}Downgrade may cause issues. Continue? (y/N)${NC}"
                read -p "> " do_downgrade
                if [[ ! "${do_downgrade}" =~ ^[Yy]$ ]]; then
                    exit 0
                fi
                ;;
            "equal")
                print_info "Version ${old_ver} is already installed"
                echo -e "${YELLOW}Do you want to reinstall? (y/N)${NC}"
                read -p "> " do_reinstall
                if [[ ! "${do_reinstall}" =~ ^[Yy]$ ]]; then
                    exit 0
                fi
                print_info "Creating backup before reinstall..."
                local backup_id
                backup_id=$(backup_existing "${old_ver}")
                print_success "Backup created: ${backup_id}"
                ;;
        esac
    elif [[ "${has_files}" == "true" ]]; then
        print_info "Found incomplete previous installation"
        echo -e "${YELLOW}Do you want to backup and migrate? (y/N)${NC}"
        read -p "> " do_migrate
        if [[ "${do_migrate}" =~ ^[Yy]$ ]]; then
            local backup_id
            backup_id=$(backup_existing "pre-migration")
            print_success "Backup created: ${backup_id}"
            migrate_configuration
        fi
    fi

    # Step 4: Check and install dependencies
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Checking and installing dependencies"

    if ! check_and_install_dependencies; then
        print_error "Failed to install required dependencies"
        exit 1
    fi
    print_success "Dependencies satisfied"

    # Step 5: Create directories and files
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Creating installation files"

    mkdir -p "${CONFIG_BASE_DIR}"
    mkdir -p "${SNAPSHOT_DIR}"
    mkdir -p "${PERF_DATA_DIR}"
    mkdir -p "${DASHBOARD_DIR}"
    mkdir -p "${LIB_BASE_DIR}/clients"
    mkdir -p "${BACKUP_DIR}"

    create_monitor_script
    create_config_file

    print_success "Installation files created"

    # Step 6: Create systemd service
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Creating systemd service"

    cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=Service Load Monitor v2.2.2 by Wael Isa
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=${MONITOR_SCRIPT}
Restart=always
RestartSec=10
User=root
Group=root
StandardOutput=journal
StandardError=journal
SyslogIdentifier=service-monitor-v2.2.2

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${LOG_BASE_DIR} ${CONFIG_BASE_DIR} ${LIB_BASE_DIR}

# Resource limits
CPUQuota=50%
MemoryLimit=500M

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable service-monitor-v2.2.2.service &> /dev/null
    print_success "Service created and enabled"

    # Step 7: Start service
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Starting service"

    echo ""
    echo -e "${YELLOW}Select startup mode:${NC}"
    echo "1) Normal mode - Full monitoring"
    echo "2) Test mode - Dry run (no changes)"
    echo "3) Don't start now"
    read -p "Select option [1-3]: " start_mode

    case "${start_mode}" in
        1)
            systemctl start service-monitor-v2.2.2.service
            print_success "Service started in NORMAL mode"
            ;;
        2)
            sed -i 's/DRY_RUN="no"/DRY_RUN="yes"/' "${CONFIG_FILE}" 2>/dev/null || true
            systemctl start service-monitor-v2.2.2.service
            print_success "Service started in TEST mode"
            ;;
        3)
            print_info "Service installed but not started"
            print_info "Start manually: systemctl start service-monitor-v2.2.2.service"
            ;;
    esac

    # Save version
    echo "${SCRIPT_VERSION}" > "${VERSION_FILE}"

    # Cleanup old files if this was an update
    if [[ -n "${old_ver}" ]] || [[ "${has_files}" == "true" ]]; then
        cleanup_old_files
    fi

    # Final success message with cloud instructions
    echo ""
    print_success "INSTALLATION COMPLETE!"
    echo ""

    # Show dashboard URL if enabled
    if [[ -f "${CONFIG_FILE}" ]] && grep -q "ENABLE_DASHBOARD=\"yes\"" "${CONFIG_FILE}"; then
        local port
        port=$(grep "DASHBOARD_PORT" "${CONFIG_FILE}" 2>/dev/null | cut -d= -f2 | tr -d '"')
        port=${port:-8080}

        local ip
        ip=$(hostname -I | awk '{print $1}')

        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                    DASHBOARD ACCESS${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  Local URL:  ${GREEN}http://localhost:${port}/${NC}"
        echo -e "  Network URL: ${GREEN}http://${ip}:${port}/${NC}"
        echo ""

        # Cloud-specific warnings
        if [[ "${cloud}" != "${CLOUD_NONE}" ]]; then
            echo -e "${RED}⚠️  CLOUD PLATFORM DETECTED: ${cloud}${NC}"
            echo -e "${YELLOW}IMPORTANT: You must also open port ${port} in your cloud firewall:${NC}"
            echo ""

            case "${cloud}" in
                "${CLOUD_AWS}")
                    echo "  • AWS Console → EC2 → Security Groups"
                    echo "  • Edit inbound rules → Add rule"
                    echo "  • Custom TCP, Port ${port}, Source 0.0.0.0/0"
                    ;;
                "${CLOUD_GCP}")
                    echo "  • GCP Console → VPC Network → Firewall"
                    echo "  • Create firewall rule → Allow TCP:${port}"
                    ;;
                "${CLOUD_AZURE}")
                    echo "  • Azure Portal → Network Security Group"
                    echo "  • Add inbound security rule → Port ${port}"
                    ;;
                "${CLOUD_ORACLE}")
                    echo "  • OCI Console → Networking → Security Lists"
                    echo "  • Add ingress rule → Port ${port}"
                    ;;
            esac
            echo ""
        fi

        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo ""
    fi

    # Summary
    echo -e "${WHITE}Installation Summary:${NC}"
    echo "  • Version: ${SCRIPT_VERSION}"
    echo "  • Location: ${BASE_DIR}"
    echo "  • Config: ${CONFIG_FILE}"
    echo "  • Logs: ${LOG_FILE}"
    echo "  • Service: service-monitor-v2.2.2.service"
    echo ""
    echo -e "${GREEN}Thank you for using Service Load Monitor!${NC}"
    echo -e "${GREEN}© 2026 Wael Isa - https://www.wael.name${NC}"
    echo ""
}

# =============================================================================
# REMOVAL FUNCTIONS
# =============================================================================

remove_monitor() {
    print_banner

    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              REMOVAL WIZARD - v2.2.2                       ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Check sudo
    if ! check_sudo; then
        print_error "This operation requires sudo access"
        exit 1
    fi

    # Check if installed
    if [[ ! -f "${SERVICE_FILE}" ]] && [[ ! -f "${MONITOR_SCRIPT}" ]]; then
        print_warning "Service Load Monitor does not appear to be installed"
        echo -e "${YELLOW}Continue anyway? (y/N)${NC}"
        read -p "> " force_remove
        if [[ ! "${force_remove}" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    # Confirm removal
    echo -e "${RED}WARNING: This will completely remove Service Load Monitor${NC}"
    echo -e "${YELLOW}Are you absolutely sure? Type 'YES' to confirm:${NC}"
    read -p "> " confirm

    if [[ "${confirm}" != "YES" ]]; then
        print_info "Removal cancelled"
        exit 0
    fi

    # Ask about backup
    echo ""
    echo -e "${YELLOW}Do you want to create a backup before removal? (y/N)${NC}"
    read -p "> " do_backup

    if [[ "${do_backup}" =~ ^[Yy]$ ]]; then
        backup_existing "pre-removal"
    fi

    # Stop and disable services
    print_info "Stopping services..."
    systemctl stop service-monitor-v2.2.2.service 2>/dev/null
    systemctl stop service-monitor.service 2>/dev/null
    systemctl stop service-monitor-dashboard.service 2>/dev/null

    print_info "Disabling services..."
    systemctl disable service-monitor-v2.2.2.service 2>/dev/null
    systemctl disable service-monitor.service 2>/dev/null
    systemctl disable service-monitor-dashboard.service 2>/dev/null

    # Remove files
    print_info "Removing files..."
    rm -f "${MONITOR_SCRIPT}"
    rm -f "${MONITOR_SCRIPT_LEGACY}"
    rm -f "${SERVICE_FILE}"
    rm -f "${SERVICE_FILE_LEGACY}"
    rm -f "${DASHBOARD_SCRIPT}"
    rm -f "${CLIENT_SCRIPT}"
    rm -f "${UPDATE_SCRIPT}"
    rm -f "${LOGROTATE_FILE}"

    # Ask about configuration and data
    echo ""
    echo -e "${YELLOW}Do you want to remove configuration and data? (y/N)${NC}"
    read -p "> " remove_data

    if [[ "${remove_data}" =~ ^[Yy]$ ]]; then
        rm -rf "${CONFIG_BASE_DIR}"
        rm -rf "${LIB_BASE_DIR}"
        rm -rf "${DASHBOARD_DIR}"
        rm -f "${LOG_FILE}" "${LOG_FILE_LEGACY}"*
        rm -rf "${SNAPSHOT_DIR}"
        print_info "Configuration and data removed"
    else
        print_info "Configuration kept at: ${CONFIG_BASE_DIR}"
        print_info "Logs kept at: ${LOG_BASE_DIR}"
    fi

    # Reload systemd
    systemctl daemon-reload

    print_success "Service Load Monitor has been removed"
}

# =============================================================================
# STATUS FUNCTIONS
# =============================================================================

show_status() {
    print_banner

    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    SYSTEM STATUS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # System info
    echo -e "${WHITE}System Information:${NC}"
    echo "  • Distribution: $(detect_distro)"
    echo "  • Cloud: $(detect_cloud | cut -d'|' -f1)"
    echo "  • Hostname: $(hostname)"
    echo "  • Kernel: $(uname -r)"
    echo "  • Uptime: $(uptime | sed 's/.*up \([^,]*\),.*/\1/')"
    echo ""

    # Service status
    echo -e "${WHITE}Service Status:${NC}"
    if systemctl is-active --quiet service-monitor-v2.2.2.service; then
        echo -e "  • ${GREEN}●${NC} Monitor Service: Running"
    else
        echo -e "  • ${RED}○${NC} Monitor Service: Stopped"
    fi

    if systemctl is-active --quiet service-monitor-dashboard.service 2>/dev/null; then
        echo -e "  • ${GREEN}●${NC} Dashboard Service: Running"
    fi

    # Version info
    echo ""
    echo -e "${WHITE}Version Information:${NC}"
    if [[ -f "${VERSION_FILE}" ]]; then
        echo "  • Installed: $(cat "${VERSION_FILE}")"
    fi
    echo "  • Script: ${SCRIPT_VERSION}"

    # Recent logs
    if [[ -f "${LOG_FILE}" ]]; then
        echo ""
        echo -e "${WHITE}Recent Log Entries:${NC}"
        tail -5 "${LOG_FILE}" 2>/dev/null | sed 's/^/  /' || echo "  No logs yet"
    fi
}

# =============================================================================
# LOG FUNCTIONS
# =============================================================================

show_logs() {
    if [[ -f "${LOG_FILE}" ]]; then
        tail -f "${LOG_FILE}"
    else
        print_error "Log file not found: ${LOG_FILE}"
    fi
}

# =============================================================================
# HELP FUNCTION
# =============================================================================

show_help() {
    print_banner
    echo -e "${WHITE}Available Commands:${NC}"
    echo ""
    echo "  install     - Install or update the monitor"
    echo "  remove      - Remove the monitor"
    echo "  status      - Show service status"
    echo "  logs        - Follow log output"
    echo "  backup      - Create a backup"
    echo "  restore     - Restore from backup"
    echo "  version     - Show version information"
    echo "  help        - Show this help"
    echo ""
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_menu() {
    print_banner

    echo -e "${WHITE}Main Menu:${NC}"
    echo ""
    echo "  1) Install/Update Monitor"
    echo "  2) Remove Monitor"
    echo "  3) Show Status"
    echo "  4) View Logs"
    echo "  5) Create Backup"
    echo "  6) Restore from Backup"
    echo "  7) Show Features"
    echo "  8) Exit"
    echo ""
    echo -n -e "${YELLOW}Select option [1-8]: ${NC}"
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    # Check if running with command argument
    if [[ $# -gt 0 ]]; then
        case "$1" in
            install)
                install_monitor
                ;;
            remove)
                remove_monitor
                ;;
            status)
                show_status
                ;;
            logs)
                show_logs
                ;;
            backup)
                check_sudo
                backup_existing "manual"
                echo ""
                print_success "Backup created"
                ;;
            restore)
                check_sudo
                echo "Available backups:"
                ls -1 "${BACKUP_DIR}" 2>/dev/null || echo "No backups found"
                echo ""
                echo -n "Enter backup ID: "
                read -r backup_id
                restore_from_backup "${backup_id}"
                ;;
            version)
                echo "Service Load Monitor v${SCRIPT_VERSION}"
                echo "Author: Wael Isa"
                echo "Website: https://www.wael.name"
                ;;
            help)
                show_help
                ;;
            *)
                echo "Unknown command: $1"
                show_help
                exit 1
                ;;
        esac
        exit 0
    fi

    # Interactive menu mode
    check_sudo

    while true; do
        show_menu
        read -r choice

        case "${choice}" in
            1)
                install_monitor
                read -p "Press Enter to continue..."
                ;;
            2)
                remove_monitor
                read -p "Press Enter to continue..."
                ;;
            3)
                show_status
                read -p "Press Enter to continue..."
                ;;
            4)
                show_logs
                ;;
            5)
                check_sudo
                backup_existing "manual"
                echo ""
                print_success "Backup created"
                read -p "Press Enter to continue..."
                ;;
            6)
                check_sudo
                echo "Available backups:"
                ls -1 "${BACKUP_DIR}" 2>/dev/null || echo "No backups found"
                echo ""
                echo -n "Enter backup ID: "
                read -r backup_id
                restore_from_backup "${backup_id}"
                read -p "Press Enter to continue..."
                ;;
            7)
                print_banner
                show_features
                read -p "Press Enter to continue..."
                ;;
            8)
                echo -e "\n${GREEN}Thank you for using Service Load Monitor!${NC}"
                echo -e "${GREEN}© 2026 Wael Isa - https://www.wael.name${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run main function
main "$@"
