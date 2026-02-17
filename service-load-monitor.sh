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
#              cloud platform awareness, and COMPLETE automatic installation
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

# Script information (version only in header)
SCRIPT_NAME="Service Load Monitor"
SCRIPT_VERSION="2.2.2"
SCRIPT_AUTHOR="Wael Isa"
SCRIPT_URL="https://www.wael.name"
SCRIPT_DATE="February 18, 2026"

# Minimum required version for updates
MIN_VERSION="1.0.0"

# File paths - SIMPLE NAMES (no version numbers)
BASE_DIR="/usr/local/bin"
CONFIG_BASE_DIR="/etc/service-monitor"
LOG_BASE_DIR="/var/log"
LIB_BASE_DIR="/var/lib/service-monitor"
WWW_BASE_DIR="/var/www/html"

MONITOR_SCRIPT="${BASE_DIR}/service-monitor.sh"
MONITOR_SCRIPT_LEGACY="${BASE_DIR}/service_load_monitor.sh"
SERVICE_FILE="/etc/systemd/system/service-monitor.service"
SERVICE_FILE_LEGACY="/etc/systemd/system/service-monitor-v2.2.2.service"
SERVICE_FILE_OLD="/etc/systemd/system/service-monitor.service.old"
CONFIG_FILE="${CONFIG_BASE_DIR}/config.conf"
CONFIG_FILE_LEGACY="${CONFIG_BASE_DIR}/config-v2.2.2.conf"
LOG_FILE="${LOG_BASE_DIR}/service-monitor.log"
LOG_FILE_LEGACY="${LOG_BASE_DIR}/service-load-monitor-v2.2.2.log"
LOGROTATE_FILE="/etc/logrotate.d/service-monitor"
SNAPSHOT_DIR="${LOG_BASE_DIR}/service-monitor-snapshots"
PERF_DATA_DIR="${LIB_BASE_DIR}/perf"
DASHBOARD_DIR="${WWW_BASE_DIR}/service-monitor"
DASHBOARD_SCRIPT="${BASE_DIR}/service-monitor-dashboard.sh"
DASHBOARD_HTTP_SERVICE="/etc/systemd/system/service-monitor-http.service"
DASHBOARD_UPDATER_SERVICE="/etc/systemd/system/service-monitor-updater.service"
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
# CLEANUP OLD VERSIONED FILES
# =============================================================================

cleanup_old_versioned_files() {
    print_info "Checking for old versioned files..."

    local old_files_removed=0

    # Stop and disable old versioned services
    if systemctl list-units --full -all | grep -q "service-monitor-v2.2.2.service"; then
        print_substep "Stopping old versioned service..."
        systemctl stop service-monitor-v2.2.2.service 2>/dev/null
        systemctl disable service-monitor-v2.2.2.service 2>/dev/null
        old_files_removed=1
    fi

    # Remove old versioned service file
    if [[ -f "${SERVICE_FILE_LEGACY}" ]]; then
        print_substep "Removing old versioned service file..."
        rm -f "${SERVICE_FILE_LEGACY}"
        old_files_removed=1
    fi

    # Remove old versioned config file
    if [[ -f "${CONFIG_FILE_LEGACY}" ]]; then
        print_substep "Removing old versioned config file..."
        # Backup config if it exists
        if [[ -f "${CONFIG_FILE_LEGACY}" ]] && [[ ! -f "${CONFIG_FILE}" ]]; then
            cp "${CONFIG_FILE_LEGACY}" "${CONFIG_FILE}" 2>/dev/null
            print_substep "Migrated config from old version"
        fi
        rm -f "${CONFIG_FILE_LEGACY}"
        old_files_removed=1
    fi

    # Remove old versioned log file (don't remove, just note)
    if [[ -f "${LOG_FILE_LEGACY}" ]]; then
        print_substep "Old log file found: ${LOG_FILE_LEGACY} (will be kept)"
        old_files_removed=1
    fi

    # Remove old versioned monitor script
    if [[ -f "${MONITOR_SCRIPT_LEGACY}" ]] && [[ "${MONITOR_SCRIPT_LEGACY}" != "${MONITOR_SCRIPT}" ]]; then
        print_substep "Removing old versioned monitor script..."
        rm -f "${MONITOR_SCRIPT_LEGACY}"
        old_files_removed=1
    fi

    if [[ ${old_files_removed} -eq 1 ]]; then
        print_success "Cleaned up old versioned files"
        systemctl daemon-reload
    else
        print_substep "No old versioned files found"
    fi
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
    echo -e "${BLUE}║${GREEN}  Version: 2.2.2 (Complete Edition)                     ${BLUE}║${NC}"
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
    echo -e "${GREEN}🌐 Complete Web Dashboard${NC}"
    echo -e "  • Auto-starting HTTP server on port 8080"
    echo -e "  • Real-time system metrics"
    echo -e "  • Service status monitoring"
    echo -e "  • Automatic updates every 30 seconds"
    echo ""
    echo -e "${GREEN}🧹 Automatic Cleanup${NC}"
    echo -e "  • Removes old versioned files on update"
    echo -e "  • Migrates configuration automatically"
    echo -e "  • Simple service names (no version numbers)"
    echo ""
    echo -e "${GREEN}🔐 Sudo Capability Check${NC}"
    echo -e "  • Verifies user has sudo privileges"
    echo -e "  • Auto-elevation when needed"
    echo -e "  • Clear error messages"
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

# Function to detect cloud environment (completely silent, HTML-free)
detect_cloud() {
    local cloud="${CLOUD_NONE}"
    local details=""
    local response

    # Check for AWS - suppress all output and filter HTML
    response=$(curl -s --max-time 2 -f http://169.254.169.254/latest/meta-data/ 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ ! "${response}" =~ \<html ]]; then
        cloud="${CLOUD_AWS}"
        # Try to get instance type silently
        local instance_type
        instance_type=$(curl -s --max-time 2 -f http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null)
        if [[ -n "${instance_type}" ]] && [[ ! "${instance_type}" =~ \<html ]]; then
            details="Instance Type: ${instance_type}"
        fi
        echo "${cloud}|${details}"
        return
    fi

    # Check for GCP
    response=$(curl -s --max-time 2 -f -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/ 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ ! "${response}" =~ \<html ]]; then
        cloud="${CLOUD_GCP}"
        local machine_type
        machine_type=$(curl -s --max-time 2 -f -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/machine-type 2>/dev/null | awk -F/ '{print $NF}')
        if [[ -n "${machine_type}" ]] && [[ ! "${machine_type}" =~ \<html ]]; then
            details="Machine Type: ${machine_type}"
        fi
        echo "${cloud}|${details}"
        return
    fi

    # Check for Azure - with HTML filtering
    response=$(curl -s --max-time 2 -f -H "Metadata: true" "http://169.254.169.254/metadata/instance?api-version=2017-08-01" 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ ! "${response}" =~ \<html ]]; then
        cloud="${CLOUD_AZURE}"
        # Try different API versions for Azure
        local vm_size
        # Try newer API first
        vm_size=$(curl -s --max-time 2 -f -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2021-02-01" 2>/dev/null)
        if [[ -z "${vm_size}" ]] || [[ "${vm_size}" =~ \<html ]]; then
            # Fall back to older API
            vm_size=$(curl -s --max-time 2 -f -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2017-08-01" 2>/dev/null)
        fi
        if [[ -n "${vm_size}" ]] && [[ ! "${vm_size}" =~ \<html ]]; then
            details="VM Size: ${vm_size}"
        fi
        echo "${cloud}|${details}"
        return
    fi

    # Check for Oracle Cloud
    response=$(curl -s --max-time 2 -f http://169.254.169.254/opc/v1/instance/ 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ ! "${response}" =~ \<html ]]; then
        cloud="${CLOUD_ORACLE}"
        local shape
        shape=$(curl -s --max-time 2 -f http://169.254.169.254/opc/v1/instance/shape 2>/dev/null)
        if [[ -n "${shape}" ]] && [[ ! "${shape}" =~ \<html ]]; then
            details="Shape: ${shape}"
        fi
        echo "${cloud}|${details}"
        return
    fi

    # No cloud detected
    echo "${CLOUD_NONE}|"
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

    # Check for any existing service files
    if [[ -f "${SERVICE_FILE}" ]] || [[ -f "${SERVICE_FILE_LEGACY}" ]]; then
        has_old_files=true
    fi

    # Check for running service
    if systemctl is-active --quiet service-monitor.service 2>/dev/null; then
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
    if [[ -f "${MONITOR_SCRIPT}" ]]; then
        cp "${MONITOR_SCRIPT}" "${backup_path}/" 2>/dev/null
    fi
    if [[ -f "${DASHBOARD_SCRIPT}" ]]; then
        cp "${DASHBOARD_SCRIPT}" "${backup_path}/" 2>/dev/null
    fi

    # Backup service files
    if [[ -f "${SERVICE_FILE}" ]]; then
        cp "${SERVICE_FILE}" "${backup_path}/" 2>/dev/null
    fi
    if [[ -f "${DASHBOARD_HTTP_SERVICE}" ]]; then
        cp "${DASHBOARD_HTTP_SERVICE}" "${backup_path}/" 2>/dev/null
    fi
    if [[ -f "${DASHBOARD_UPDATER_SERVICE}" ]]; then
        cp "${DASHBOARD_UPDATER_SERVICE}" "${backup_path}/" 2>/dev/null
    fi

    # Backup version info
    echo "${SCRIPT_VERSION}" > "${backup_path}/version.txt"
    date > "${backup_path}/backup_date.txt"

    # Save current service states
    systemctl is-active --quiet service-monitor.service 2>/dev/null && \
        echo "active" > "${backup_path}/service-monitor.state" || \
        echo "inactive" > "${backup_path}/service-monitor.state"

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
    systemctl stop service-monitor.service 2>/dev/null
    systemctl stop service-monitor-http.service 2>/dev/null
    systemctl stop service-monitor-updater.service 2>/dev/null

    # Restore configuration
    if [[ -d "${backup_path}/service-monitor" ]]; then
        rm -rf "${CONFIG_BASE_DIR}" 2>/dev/null
        cp -r "${backup_path}/service-monitor" "${CONFIG_BASE_DIR%/*}/" 2>/dev/null
    fi

    # Restore scripts
    if [[ -f "${backup_path}/service-monitor.sh" ]]; then
        cp "${backup_path}/service-monitor.sh" "${BASE_DIR}/" 2>/dev/null
        chmod +x "${BASE_DIR}/service-monitor.sh"
    fi
    if [[ -f "${backup_path}/service-monitor-dashboard.sh" ]]; then
        cp "${backup_path}/service-monitor-dashboard.sh" "${BASE_DIR}/" 2>/dev/null
        chmod +x "${BASE_DIR}/service-monitor-dashboard.sh"
    fi

    # Restore service files
    if [[ -f "${backup_path}/service-monitor.service" ]]; then
        cp "${backup_path}/service-monitor.service" "/etc/systemd/system/" 2>/dev/null
    fi
    if [[ -f "${backup_path}/service-monitor-http.service" ]]; then
        cp "${backup_path}/service-monitor-http.service" "/etc/systemd/system/" 2>/dev/null
    fi
    if [[ -f "${backup_path}/service-monitor-updater.service" ]]; then
        cp "${backup_path}/service-monitor-updater.service" "/etc/systemd/system/" 2>/dev/null
    fi

    # Restore version
    if [[ -f "${backup_path}/version.txt" ]]; then
        cp "${backup_path}/version.txt" "${VERSION_FILE}" 2>/dev/null
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
        print_substep "Migrating configuration from old version"
        cp "${CONFIG_FILE_LEGACY}" "${CONFIG_FILE}" 2>/dev/null
    fi

    # Save current version
    echo "${SCRIPT_VERSION}" > "${VERSION_FILE}"

    print_success "Migration completed"
}

# =============================================================================
# DASHBOARD FUNCTIONS
# =============================================================================

create_dashboard_files() {
    print_substep "Creating dashboard files..."

    # Create dashboard directory
    mkdir -p "${DASHBOARD_DIR}"

    # Create initial status.json
    cat > "${DASHBOARD_DIR}/status.json" << EOF
{
    "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "${SCRIPT_VERSION}",
    "author": "${SCRIPT_AUTHOR}",
    "website": "${SCRIPT_URL}",
    "servers": [
        {
            "id": "local",
            "hostname": "$(hostname)",
            "uptime": "$(uptime | sed 's/.*up \([^,]*\),.*/\1/')",
            "load": "$(uptime | awk -F'load average:' '{print $2}' | xargs)",
            "cpu_cores": $(nproc),
            "memory": "$(free -h | grep Mem | awk '{print $3"/"$2}')",
            "iowait": "0%",
            "disk_usage": "$(df -h / | awk 'NR==2 {print $5}')",
            "services": []
        }
    ],
    "alerts": []
}
EOF

    # Create index.html
    cat > "${DASHBOARD_DIR}/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>Service Monitor Dashboard - Wael Isa</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        .header {
            background: white;
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        .header h1 { color: #333; font-size: 2.5em; margin-bottom: 10px; }
        .header .author { color: #666; font-size: 1.1em; }
        .header .author a { color: #667eea; text-decoration: none; }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: white;
            border-radius: 15px;
            padding: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .stat-card h3 { color: #666; font-size: 0.9em; margin-bottom: 10px; }
        .stat-card .value { color: #333; font-size: 1.8em; font-weight: bold; }
        .services-section {
            background: white;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .services-section h2 { color: #333; margin-bottom: 20px; }
        .service-list { display: grid; gap: 10px; }
        .service-item {
            display: grid;
            grid-template-columns: 2fr 1fr 1fr 1fr;
            align-items: center;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 10px;
        }
        .service-name { font-weight: 600; color: #333; }
        .service-status { text-align: center; }
        .status-badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: 500;
        }
        .status-active { background: #d4edda; color: #155724; }
        .status-inactive { background: #f8d7da; color: #721c24; }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: white;
        }
        .footer a { color: white; text-decoration: none; }
        .last-update { color: #999; font-size: 0.9em; margin-top: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Service Load Monitor</h1>
            <div class="author">by <a href="https://www.wael.name" target="_blank">Wael Isa</a> | v2.2.2</div>
            <div class="last-update" id="lastUpdate">Loading...</div>
        </div>

        <div class="stats-grid" id="statsGrid"></div>

        <div class="services-section">
            <h2>📊 Monitored Services</h2>
            <div class="service-list" id="serviceList"></div>
        </div>
    </div>

    <div class="footer">
        <p>© 2026 <a href="https://www.wael.name" target="_blank">Wael Isa</a> - Service Load Monitor</p>
    </div>

    <script>
        function refreshData() {
            fetch('status.json?' + new Date().getTime())
                .then(response => response.json())
                .then(data => {
                    document.getElementById('lastUpdate').textContent = 'Last updated: ' + data.last_update;

                    // Update stats
                    const statsGrid = document.getElementById('statsGrid');
                    if (data.servers && data.servers[0]) {
                        const s = data.servers[0];
                        statsGrid.innerHTML = `
                            <div class="stat-card"><h3>System Load</h3><div class="value">${s.load}</div></div>
                            <div class="stat-card"><h3>Uptime</h3><div class="value">${s.uptime}</div></div>
                            <div class="stat-card"><h3>Memory</h3><div class="value">${s.memory}</div></div>
                            <div class="stat-card"><h3>Disk Usage</h3><div class="value">${s.disk_usage}</div></div>
                        `;
                    }

                    // Update services
                    const serviceList = document.getElementById('serviceList');
                    if (data.servers && data.servers[0] && data.servers[0].services) {
                        if (data.servers[0].services.length > 0) {
                            serviceList.innerHTML = data.servers[0].services.map(s => `
                                <div class="service-item">
                                    <div class="service-name">${s.name}</div>
                                    <div class="service-status">
                                        <span class="status-badge ${s.status === 'active' ? 'status-active' : 'status-inactive'}">${s.status}</span>
                                    </div>
                                    <div class="service-cpu">${s.cpu}% CPU</div>
                                    <div class="service-mem">${s.mem}% MEM</div>
                                </div>
                            `).join('');
                        } else {
                            serviceList.innerHTML = '<div style="text-align: center; padding: 20px;">No services configured</div>';
                        }
                    }
                })
                .catch(error => {
                    console.error('Error loading data:', error);
                });
        }
        setInterval(refreshData, 10000);
        refreshData();
    </script>
</body>
</html>
HTML

    chmod -R 755 "${DASHBOARD_DIR}"
    print_substep "Dashboard files created"
}

create_dashboard_scripts() {
    print_substep "Creating dashboard scripts..."

    # Create dashboard updater script
    cat > "${DASHBOARD_SCRIPT}" << EOF
#!/bin/bash

# =============================================================================
# Service Monitor Dashboard Updater
# =============================================================================
# Author: Wael Isa
# Website: https://www.wael.name
# =============================================================================

DASHBOARD_DIR="${DASHBOARD_DIR}"
LOG_FILE="${LOG_FILE}"
CONFIG_FILE="${CONFIG_FILE}"

while true; do
    # Get system info
    HOSTNAME=\$(hostname)
    UPTIME=\$(uptime | sed 's/.*up \([^,]*\),.*/\1/')
    LOAD=\$(uptime | awk -F'load average:' '{print \$2}' | xargs)
    CPU_CORES=\$(nproc)
    MEMORY=\$(free -h | grep Mem | awk '{print \$3"/"\$2}')
    DISK=\$(df -h / | awk 'NR==2 {print \$5}')
    IOWAIT=\$(top -bn1 | grep "Cpu(s)" | awk '{print \$8}' | cut -d',' -f1)
    IOWAIT=\${IOWAIT:-0}

    # Get service status from config
    SERVICES_JSON=""
    FIRST=1

    if [[ -f "\${CONFIG_FILE}" ]]; then
        while IFS= read -r line; do
            if [[ "\${line}" =~ MONITORED_SERVICES=\"(.*)\" ]]; then
                IFS=' ' read -ra SERVICES <<< "\${BASH_REMATCH[1]}"
                for SERVICE in "\${SERVICES[@]}"; do
                    if [[ \${FIRST} -eq 1 ]]; then
                        FIRST=0
                    else
                        SERVICES_JSON+=","
                    fi

                    STATUS=\$(systemctl is-active "\${SERVICE}" 2>/dev/null || echo "unknown")
                    SERVICES_JSON+="{\"name\":\"\${SERVICE}\",\"status\":\"\${STATUS}\",\"cpu\":0,\"mem\":0}"
                done
                break
            fi
        done < "\${CONFIG_FILE}"
    fi

    # Create JSON
    cat > "\${DASHBOARD_DIR}/status.json" << JSON
{
    "last_update": "\$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "${SCRIPT_VERSION}",
    "author": "${SCRIPT_AUTHOR}",
    "website": "${SCRIPT_URL}",
    "servers": [
        {
            "id": "local",
            "hostname": "\${HOSTNAME}",
            "uptime": "\${UPTIME}",
            "load": "\${LOAD}",
            "cpu_cores": \${CPU_CORES},
            "memory": "\${MEMORY}",
            "iowait": "\${IOWAIT}%",
            "disk_usage": "\${DISK}",
            "services": [\${SERVICES_JSON}]
        }
    ],
    "alerts": []
}
JSON

    sleep 30
done
EOF

    chmod +x "${DASHBOARD_SCRIPT}"
    print_substep "Dashboard scripts created"
}

create_dashboard_services() {
    print_substep "Creating dashboard services..."

    # Create HTTP server service
    cat > "${DASHBOARD_HTTP_SERVICE}" << EOF
[Unit]
Description=Service Monitor HTTP Server
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${DASHBOARD_DIR}
ExecStart=/usr/bin/python3 -m http.server ${DEFAULT_DASHBOARD_PORT} --bind 0.0.0.0
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Create updater service
    cat > "${DASHBOARD_UPDATER_SERVICE}" << EOF
[Unit]
Description=Service Monitor Dashboard Updater
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=${DASHBOARD_SCRIPT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start services
    systemctl daemon-reload
    systemctl enable service-monitor-http.service &> /dev/null
    systemctl enable service-monitor-updater.service &> /dev/null
    systemctl start service-monitor-http.service &> /dev/null
    systemctl start service-monitor-updater.service &> /dev/null

    print_substep "Dashboard services created and started"
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

create_monitor_script() {
    cat > "${MONITOR_SCRIPT}" << 'EOF'
#!/bin/bash

# =============================================================================
# Service Load Monitor - Core Script
# =============================================================================
# Author:  Wael Isa
# Website: https://www.wael.name
# =============================================================================

# Configuration
CONFIG_FILE="/etc/service-monitor/config.conf"
LOG_FILE="/var/log/service-monitor.log"

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
log_message "Service Load Monitor started"

while true; do
    CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/ //g')

    if (( $(echo "$CURRENT_LOAD > $LOAD_THRESHOLD" | bc -l 2>/dev/null) )); then
        log_message "High load detected: $CURRENT_LOAD"
    fi

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
# Service Load Monitor - Configuration
# =============================================================================
# Author:  Wael Isa
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
DASHBOARD_PORT=${DEFAULT_DASHBOARD_PORT}

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
    echo -e "${WHITE}║         INSTALLATION WIZARD - v2.2.2 Complete              ║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Step 1: Check sudo
    local total_steps=9
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

    if [[ "${cloud}" != "${CLOUD_NONE}" ]]; then
        echo -e "  Cloud Platform: ${cloud}"
        if [[ -n "${cloud_details}" ]] && [[ ! "${cloud_details}" =~ \<html ]]; then
            echo -e "  Details: ${cloud_details}"
        fi
    else
        echo -e "  Cloud Platform: None detected"
    fi

    echo -e "  Architecture: $(uname -m)"
    print_success "System detection complete"

    # Step 3: Clean up old versioned files
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Cleaning up old versioned files"
    cleanup_old_versioned_files
    print_success "Cleanup complete"

    # Step 4: Check existing installation
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
        print_info "Found existing installation files"
        echo -e "${YELLOW}Do you want to backup and proceed? (y/N)${NC}"
        read -p "> " do_migrate
        if [[ "${do_migrate}" =~ ^[Yy]$ ]]; then
            local backup_id
            backup_id=$(backup_existing "pre-install")
            print_success "Backup created: ${backup_id}"
        fi
    fi

    # Step 5: Check and install dependencies
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Checking and installing dependencies"

    if ! check_and_install_dependencies; then
        print_error "Failed to install required dependencies"
        exit 1
    fi
    print_success "Dependencies satisfied"

    # Step 6: Create directories
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Creating directories"

    mkdir -p "${CONFIG_BASE_DIR}"
    mkdir -p "${SNAPSHOT_DIR}"
    mkdir -p "${PERF_DATA_DIR}"
    mkdir -p "${DASHBOARD_DIR}"
    mkdir -p "${LIB_BASE_DIR}/clients"
    mkdir -p "${BACKUP_DIR}"

    print_success "Directories created"

    # Step 7: Create monitor files
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Creating monitor files"

    create_monitor_script
    create_config_file

    print_success "Monitor files created"

    # Step 8: Create dashboard
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Creating web dashboard"

    create_dashboard_files
    create_dashboard_scripts
    create_dashboard_services

    print_success "Dashboard created and started"

    # Step 9: Create main service
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Creating main service"

    cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=Service Load Monitor by Wael Isa
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
SyslogIdentifier=service-monitor

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${LOG_BASE_DIR} ${CONFIG_BASE_DIR} ${LIB_BASE_DIR}

# Resource limits - modern syntax
CPUQuota=50%
MemoryMax=500M
MemoryHigh=400M
TasksMax=100

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable service-monitor.service &> /dev/null

    echo ""
    echo -e "${YELLOW}Select startup mode for main monitor:${NC}"
    echo "1) Start now"
    echo "2) Don't start now"
    read -p "Select option [1-2]: " start_mode

    if [[ "${start_mode}" == "1" ]]; then
        systemctl start service-monitor.service
        print_success "Main service started"
    else
        print_info "Main service installed but not started"
        print_info "Start manually: systemctl start service-monitor.service"
    fi

    # Save version
    echo "${SCRIPT_VERSION}" > "${VERSION_FILE}"

    # Final success message
    echo ""
    print_success "INSTALLATION COMPLETE!"
    echo ""

    # Show dashboard URL
    local ip
    ip=$(hostname -I | awk '{print $1}')

    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    DASHBOARD ACCESS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Local URL:  ${GREEN}http://localhost:${DEFAULT_DASHBOARD_PORT}/${NC}"
    echo -e "  Network URL: ${GREEN}http://${ip}:${DEFAULT_DASHBOARD_PORT}/${NC}"
    echo ""

    # Cloud-specific warnings
    if [[ "${cloud}" != "${CLOUD_NONE}" ]]; then
        echo -e "${RED}⚠️  CLOUD PLATFORM DETECTED: ${cloud}${NC}"
        echo -e "${YELLOW}IMPORTANT: You must also open port ${DEFAULT_DASHBOARD_PORT} in your cloud firewall:${NC}"
        echo ""

        case "${cloud}" in
            "${CLOUD_AWS}")
                echo "  • AWS Console → EC2 → Security Groups"
                echo "  • Edit inbound rules → Add rule"
                echo "  • Custom TCP, Port ${DEFAULT_DASHBOARD_PORT}, Source 0.0.0.0/0"
                ;;
            "${CLOUD_GCP}")
                echo "  • GCP Console → VPC Network → Firewall"
                echo "  • Create firewall rule → Allow TCP:${DEFAULT_DASHBOARD_PORT}"
                ;;
            "${CLOUD_AZURE}")
                echo "  • Azure Portal → Network Security Group"
                echo "  • Add inbound security rule → Port ${DEFAULT_DASHBOARD_PORT}"
                ;;
            "${CLOUD_ORACLE}")
                echo "  • OCI Console → Networking → Security Lists"
                echo "  • Add ingress rule → Port ${DEFAULT_DASHBOARD_PORT}"
                ;;
        esac
        echo ""
    fi

    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Summary
    echo -e "${WHITE}Installation Summary:${NC}"
    echo "  • Version: ${SCRIPT_VERSION} (only in header)"
    echo "  • Monitor Service: ${GREEN}service-monitor.service${NC}"
    echo "  • HTTP Server: ${GREEN}service-monitor-http.service${NC} (port ${DEFAULT_DASHBOARD_PORT})"
    echo "  • Updater Service: ${GREEN}service-monitor-updater.service${NC}"
    echo "  • Config: ${CONFIG_FILE}"
    echo "  • Logs: ${LOG_FILE}"
    echo "  • Dashboard: ${DASHBOARD_DIR}"
    echo ""
    echo -e "${WHITE}Commands:${NC}"
    echo "  • Check status: ${GREEN}systemctl status service-monitor.service${NC}"
    echo "  • View logs: ${GREEN}tail -f ${LOG_FILE}${NC}"
    echo "  • Edit config: ${GREEN}nano ${CONFIG_FILE}${NC}"
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
    echo -e "${RED}║              REMOVAL WIZARD                                ║${NC}"
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

    # Stop and disable all services
    print_info "Stopping services..."
    systemctl stop service-monitor.service 2>/dev/null
    systemctl stop service-monitor-http.service 2>/dev/null
    systemctl stop service-monitor-updater.service 2>/dev/null

    print_info "Disabling services..."
    systemctl disable service-monitor.service 2>/dev/null
    systemctl disable service-monitor-http.service 2>/dev/null
    systemctl disable service-monitor-updater.service 2>/dev/null

    # Remove files
    print_info "Removing files..."
    rm -f "${MONITOR_SCRIPT}"
    rm -f "${SERVICE_FILE}"
    rm -f "${DASHBOARD_SCRIPT}"
    rm -f "${CLIENT_SCRIPT}"
    rm -f "${UPDATE_SCRIPT}"
    rm -f "${LOGROTATE_FILE}"
    rm -f "${DASHBOARD_HTTP_SERVICE}"
    rm -f "${DASHBOARD_UPDATER_SERVICE}"

    # Ask about configuration and data
    echo ""
    echo -e "${YELLOW}Do you want to remove configuration and data? (y/N)${NC}"
    read -p "> " remove_data

    if [[ "${remove_data}" =~ ^[Yy]$ ]]; then
        rm -rf "${CONFIG_BASE_DIR}"
        rm -rf "${LIB_BASE_DIR}"
        rm -rf "${DASHBOARD_DIR}"
        rm -f "${LOG_FILE}"*
        rm -rf "${SNAPSHOT_DIR}"
        rm -f "${VERSION_FILE}"
        print_info "Configuration and data removed"
    else
        print_info "Configuration kept at: ${CONFIG_BASE_DIR}"
        print_info "Logs kept at: ${LOG_FILE}"
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

    # Get cloud info without HTML
    local cloud_info
    cloud_info=$(detect_cloud)
    local cloud="${cloud_info%|*}"
    local cloud_details="${cloud_info#*|}"

    if [[ "${cloud}" != "${CLOUD_NONE}" ]]; then
        echo "  • Cloud Platform: ${cloud}"
        if [[ -n "${cloud_details}" ]] && [[ ! "${cloud_details}" =~ \<html ]]; then
            echo "  • ${cloud_details}"
        fi
    else
        echo "  • Cloud Platform: None detected"
    fi

    echo "  • Hostname: $(hostname)"
    echo "  • Kernel: $(uname -r)"
    echo "  • Uptime: $(uptime | sed 's/.*up \([^,]*\),.*/\1/')"
    echo ""

    # Service status
    echo -e "${WHITE}Service Status:${NC}"

    if systemctl is-active --quiet service-monitor.service; then
        echo -e "  • ${GREEN}●${NC} Monitor Service: Running"
    else
        echo -e "  • ${RED}○${NC} Monitor Service: Stopped"
    fi

    if systemctl is-active --quiet service-monitor-http.service 2>/dev/null; then
        echo -e "  • ${GREEN}●${NC} HTTP Server: Running"
    else
        echo -e "  • ${RED}○${NC} HTTP Server: Stopped"
    fi

    if systemctl is-active --quiet service-monitor-updater.service 2>/dev/null; then
        echo -e "  • ${GREEN}●${NC} Updater Service: Running"
    else
        echo -e "  • ${RED}○${NC} Updater Service: Stopped"
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
