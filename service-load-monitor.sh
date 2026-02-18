#!/bin/bash

# =============================================================================
# Service Load Monitor - Installation & Management Script v3.0.3
# =============================================================================
# Author:  Wael Isa
# Version: 3.0.3
# Date:    February 18, 2026
# Website: https://www.wael.name
# =============================================================================
# Description: Enterprise-grade service monitoring with DNS suite integration
#              Pi-hole, Unbound, DNSCrypt-Proxy native support
#              Complete DNS security and privacy monitoring suite
#
# FIXES IN v3.0.3:
# -----------------
# 1. Fixed dashboard display showing raw ANSI color codes
# 2. Fixed JSON parsing errors with proper string escaping
# 3. Added ANSI code stripping in JavaScript
# 4. Fixed service status display showing "unknown" incorrectly
# 5. Added debug mode toggle for troubleshooting
# 6. Improved error handling with fallback JSON
# 7. Fixed CPU/MEM percentage display for all services
# 8. Enhanced service detection for all DNS services
# 9. Added proper status colors (green for active, red for inactive)
# 10. Fixed Pi-hole statistics display
# 11. Added real-time updates every 10 seconds
# 12. Improved logging with debug information
# 13. Fixed installation summary color codes
# 14. Added JSON validation before writing
# 15. Fixed service name display formatting
# 16. REMOVED Cloudflared service monitoring
# 17. Fixed DNSCrypt-Proxy display (now shows correctly in both sections)
# 18. Fixed duplicate service entries in dashboard
# 19. Improved service status detection for DNSCrypt-Proxy
# 20. Better handling of service names with hyphens
#
# UPDATES IN v3.0.3:
# ------------------
# • Complete dashboard UI overhaul with better responsiveness
# • Enhanced error messages with troubleshooting tips
# • Added service count indicators
# • Improved mobile responsiveness
# • Better handling of special characters in service names
# • Automatic recovery from corrupted JSON files
# • Detailed debug logging option
# • Service status badges with proper colors
# • CPU and memory usage now show correctly for all services
# • Pi-hole statistics with percentage calculations
# • Version information for all DNS services
# • REMOVED Cloudflared (no longer monitored)
# • Fixed DNSCrypt-Proxy detection and display
# • Eliminated duplicate service entries
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
SCRIPT_VERSION="3.0.3"
SCRIPT_AUTHOR="Wael Isa"
SCRIPT_URL="https://www.wael.name"
SCRIPT_DATE="February 18, 2026"

# Minimum required version for updates
MIN_VERSION="1.0.0"

# File paths
BASE_DIR="/usr/local/bin"
CONFIG_BASE_DIR="/etc/service-monitor"
LOG_BASE_DIR="/var/log"
LIB_BASE_DIR="/var/lib/service-monitor"
WWW_BASE_DIR="/var/www/html"

MONITOR_SCRIPT="${BASE_DIR}/service-monitor.sh"
SERVICE_FILE="/etc/systemd/system/service-monitor.service"
CONFIG_FILE="${CONFIG_BASE_DIR}/config.conf"
LOG_FILE="${LOG_BASE_DIR}/service-monitor.log"
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

# Pi-hole specific paths
PIHOLE_DIR="/etc/pihole"
PIHOLE_LOG="/var/log/pihole.log"
PIHOLE_FTL_LOG="/var/log/pihole-FTL.log"
PIHOLE_GRAVITY="${PIHOLE_DIR}/gravity.db"
PIHOLE_WEB_DIR="/var/www/html/admin"
PIHOLE_SERVICE="pihole-FTL.service"

# DNS service names - CLOUDFLARED REMOVED
DNS_SERVICES=(
    "pihole-FTL.service"
    "unbound.service"
    "dnscrypt-proxy.service"
    "dnsmasq.service"
    "named.service"  # BIND9
)

# Default ports
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
# UI HELPER FUNCTIONS
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
# DNS SERVICE DETECTION FUNCTIONS - CLOUDFLARED REMOVED
# =============================================================================

detect_dns_services() {
    local detected=()

    print_info "Scanning for DNS services..."

    # Check Pi-hole
    if systemctl list-unit-files 2>/dev/null | grep -q "pihole-FTL.service"; then
        detected+=("pihole-FTL.service")
        print_substep "Pi-hole FTL detected"
    elif [[ -f "/etc/systemd/system/pihole-FTL.service" ]]; then
        detected+=("pihole-FTL.service")
        print_substep "Pi-hole FTL detected (custom install)"
    fi

    # Check Unbound
    if systemctl list-unit-files 2>/dev/null | grep -q "unbound.service"; then
        detected+=("unbound.service")
        print_substep "Unbound detected"
    elif [[ -f "/etc/systemd/system/unbound.service" ]]; then
        detected+=("unbound.service")
        print_substep "Unbound detected (custom install)"
    fi

    # Check DNSCrypt-Proxy
    if systemctl list-unit-files 2>/dev/null | grep -q "dnscrypt-proxy.service"; then
        detected+=("dnscrypt-proxy.service")
        print_substep "DNSCrypt-Proxy detected"
    elif [[ -f "/etc/systemd/system/dnscrypt-proxy.service" ]]; then
        detected+=("dnscrypt-proxy.service")
        print_substep "DNSCrypt-Proxy detected (custom install)"
    elif systemctl list-unit-files 2>/dev/null | grep -q "dnscrypt-proxy"; then
        # Fallback for different service name variations
        detected+=("dnscrypt-proxy.service")
        print_substep "DNSCrypt-Proxy detected (variation)"
    fi

    # Check dnsmasq
    if systemctl list-unit-files 2>/dev/null | grep -q "dnsmasq.service"; then
        detected+=("dnsmasq.service")
        print_substep "Dnsmasq detected"
    fi

    # Check BIND9
    if systemctl list-unit-files 2>/dev/null | grep -q "named.service"; then
        detected+=("named.service")
        print_substep "BIND9 detected"
    fi

    echo "${detected[@]}"
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
            return 0
        else
            if sudo -v 2>/dev/null; then
                return 0
            else
                return 1
            fi
        fi
    else
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
    local response

    # Check for AWS
    response=$(curl -s --max-time 2 -f http://169.254.169.254/latest/meta-data/ 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ ! "${response}" =~ \<html ]]; then
        cloud="${CLOUD_AWS}"
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

    # Check for Azure
    response=$(curl -s --max-time 2 -f -H "Metadata: true" "http://169.254.169.254/metadata/instance?api-version=2017-08-01" 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ ! "${response}" =~ \<html ]]; then
        cloud="${CLOUD_AZURE}"
        local vm_size
        vm_size=$(curl -s --max-time 2 -f -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2021-02-01" 2>/dev/null)
        if [[ -z "${vm_size}" ]] || [[ "${vm_size}" =~ \<html ]]; then
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

    echo "${CLOUD_NONE}|"
}

# =============================================================================
# PACKAGE MANAGEMENT FUNCTIONS
# =============================================================================

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
    ["sqlite3"]="sqlite3"
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
    ["sqlite3"]="sqlite"
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
    ["sqlite3"]="sqlite"
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
    ["sqlite3"]="sqlite3"
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
    ["sqlite3"]="sqlite3"
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
    local required_commands=(
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
        "awk"
        "grep"
        "sed"
        "curl"
        "ss"
        "netstat"
        "lsof"
        "dig"
        "bc"
        "jq"
        "iostat"
        "socat"
        "systemd-cgls"
        "python3"
        "sqlite3"
    )

    local pkg_manager
    pkg_manager=$(detect_package_manager)

    print_info "Package manager detected: ${pkg_manager}"
    print_info "Distribution: $(detect_distro)"

    if [[ "${pkg_manager}" == "unknown" ]]; then
        print_warning "Unknown package manager. Please install dependencies manually."
        return 1
    fi

    mkdir -p "$(dirname "${DEPENDENCY_LOG}")"

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

    echo -e "${YELLOW}Do you want to install these dependencies? (y/N)${NC}"
    read -p "> " confirm_install

    if [[ ! "${confirm_install}" =~ ^[Yy]$ ]]; then
        print_error "Dependencies not installed. Cannot continue."
        return 1
    fi

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
            echo "Failed to install ${pkg}" >> "${DEPENDENCY_LOG}"
        fi
    done

    echo ""
    print_info "Installation summary:"
    echo "  ✅ Successfully installed: ${success}"
    echo "  ❌ Failed to install: ${failed}"

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

    if [[ -f "${VERSION_FILE}" ]]; then
        installed_version=$(cat "${VERSION_FILE}")
    fi

    if [[ -f "${SERVICE_FILE}" ]]; then
        has_old_files=true
    fi

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

    if [[ -d "${CONFIG_BASE_DIR}" ]]; then
        cp -r "${CONFIG_BASE_DIR}" "${backup_path}/" 2>/dev/null
    fi

    if [[ -f "${MONITOR_SCRIPT}" ]]; then
        cp "${MONITOR_SCRIPT}" "${backup_path}/" 2>/dev/null
    fi
    if [[ -f "${DASHBOARD_SCRIPT}" ]]; then
        cp "${DASHBOARD_SCRIPT}" "${backup_path}/" 2>/dev/null
    fi

    if [[ -f "${SERVICE_FILE}" ]]; then
        cp "${SERVICE_FILE}" "${backup_path}/" 2>/dev/null
    fi
    if [[ -f "${DASHBOARD_HTTP_SERVICE}" ]]; then
        cp "${DASHBOARD_HTTP_SERVICE}" "${backup_path}/" 2>/dev/null
    fi
    if [[ -f "${DASHBOARD_UPDATER_SERVICE}" ]]; then
        cp "${DASHBOARD_UPDATER_SERVICE}" "${backup_path}/" 2>/dev/null
    fi

    echo "${SCRIPT_VERSION}" > "${backup_path}/version.txt"
    date > "${backup_path}/backup_date.txt"

    systemctl is-active --quiet service-monitor.service 2>/dev/null && \
        echo "active" > "${backup_path}/service-monitor.state" || \
        echo "inactive" > "${backup_path}/service-monitor.state"

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

    systemctl stop service-monitor.service 2>/dev/null
    systemctl stop service-monitor-http.service 2>/dev/null
    systemctl stop service-monitor-updater.service 2>/dev/null

    if [[ -d "${backup_path}/service-monitor" ]]; then
        rm -rf "${CONFIG_BASE_DIR}" 2>/dev/null
        cp -r "${backup_path}/service-monitor" "${CONFIG_BASE_DIR%/*}/" 2>/dev/null
    fi

    if [[ -f "${backup_path}/service-monitor.sh" ]]; then
        cp "${backup_path}/service-monitor.sh" "${BASE_DIR}/" 2>/dev/null
        chmod +x "${BASE_DIR}/service-monitor.sh"
    fi
    if [[ -f "${backup_path}/service-monitor-dashboard.sh" ]]; then
        cp "${backup_path}/service-monitor-dashboard.sh" "${BASE_DIR}/" 2>/dev/null
        chmod +x "${BASE_DIR}/service-monitor-dashboard.sh"
    fi

    if [[ -f "${backup_path}/service-monitor.service" ]]; then
        cp "${backup_path}/service-monitor.service" "/etc/systemd/system/" 2>/dev/null
    fi
    if [[ -f "${backup_path}/service-monitor-http.service" ]]; then
        cp "${backup_path}/service-monitor-http.service" "/etc/systemd/system/" 2>/dev/null
    fi
    if [[ -f "${backup_path}/service-monitor-updater.service" ]]; then
        cp "${backup_path}/service-monitor-updater.service" "/etc/systemd/system/" 2>/dev/null
    fi

    if [[ -f "${backup_path}/version.txt" ]]; then
        cp "${backup_path}/version.txt" "${VERSION_FILE}" 2>/dev/null
    fi

    systemctl daemon-reload

    print_success "Restore completed"
}

# =============================================================================
# MIGRATION FUNCTIONS
# =============================================================================

migrate_configuration() {
    print_info "Migrating existing configuration..."

    local backup_id
    backup_id=$(backup_existing "pre-migration")
    print_substep "Pre-migration backup created: ${backup_id}"

    echo "${SCRIPT_VERSION}" > "${VERSION_FILE}"

    print_success "Migration completed"
}

# =============================================================================
# DASHBOARD FUNCTIONS - COMPLETELY FIXED FOR JSON PARSING, CLOUDFLARED REMOVED
# =============================================================================

create_dashboard_files() {
    print_substep "Creating dashboard files..."

    mkdir -p "${DASHBOARD_DIR}"

    # Create initial status.json with proper structure
    cat > "${DASHBOARD_DIR}/status.json" << EOF
{
    "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "${SCRIPT_VERSION}",
    "author": "${SCRIPT_AUTHOR}",
    "website": "${SCRIPT_URL}",
    "servers": [
        {
            "id": "local",
            "hostname": "$(hostname 2>/dev/null | sed 's/["\\]/\\\\&/g' || echo "localhost")",
            "uptime": "$(uptime 2>/dev/null | sed 's/.*up \([^,]*\),.*/\1/' | sed 's/["\\]/\\\\&/g' || echo "unknown")",
            "load": "$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs | sed 's/["\\]/\\\\&/g' || echo "0.00")",
            "cpu_cores": $(nproc 2>/dev/null || echo "1"),
            "memory": "$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}' | sed 's/["\\]/\\\\&/g' || echo "0/0")",
            "iowait": "0%",
            "disk_usage": "$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/["\\]/\\\\&/g' || echo "0%")",
            "services": [],
            "dns_services": []
        }
    ],
    "pihole": null,
    "alerts": []
}
EOF

    # Create index.html with fixed JavaScript - CLOUDFLARED REMOVED
    cat > "${DASHBOARD_DIR}/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>Service Monitor Dashboard v3.0.3 - Wael Isa</title>
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
        .header .badge {
            background: #667eea;
            color: white;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.9em;
            display: inline-block;
            margin-left: 10px;
        }
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
            transition: transform 0.2s;
        }
        .stat-card:hover { transform: translateY(-5px); }
        .stat-card h3 { color: #666; font-size: 0.9em; margin-bottom: 10px; }
        .stat-card .value { color: #333; font-size: 1.8em; font-weight: bold; }

        .dns-section {
            background: white;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .dns-section h2 {
            color: #333;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .dns-section h2 i { font-size: 1.2em; }
        .dns-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 15px;
        }
        .dns-card {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 15px;
            border-left: 4px solid #667eea;
            transition: transform 0.2s;
        }
        .dns-card:hover { transform: translateY(-3px); }
        .dns-card h3 {
            color: #333;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .dns-card .status {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 12px;
            font-size: 0.8em;
            margin-left: 8px;
        }
        .status-active { background: #d4edda; color: #155724; }
        .status-inactive { background: #f8d7da; color: #721c24; }
        .status-unknown { background: #e2e3e5; color: #383d41; }
        .dns-stats {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            margin-top: 10px;
        }
        .dns-stat-item {
            background: white;
            border-radius: 8px;
            padding: 8px;
            text-align: center;
        }
        .dns-stat-label { font-size: 0.8em; color: #666; }
        .dns-stat-value { font-weight: bold; color: #333; }

        .pihole-section {
            background: white;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            border-left: 4px solid #f0ad4e;
        }
        .pihole-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }

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
            transition: transform 0.2s;
        }
        .service-item:hover { transform: translateX(5px); }
        .service-name { font-weight: 600; color: #333; }
        .service-status { text-align: center; }
        .status-badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: 500;
        }
        .service-cpu { text-align: center; color: #667eea; }
        .service-mem { text-align: center; color: #764ba2; }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: white;
        }
        .footer a { color: white; text-decoration: none; }
        .last-update { color: #999; font-size: 0.9em; margin-top: 10px; }
        .loading {
            text-align: center;
            padding: 40px;
            color: #666;
        }
        .no-services {
            text-align: center;
            padding: 40px;
            color: #999;
            background: #f8f9fa;
            border-radius: 10px;
        }
        .error-message {
            background: #f8d7da;
            color: #721c24;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
            margin: 20px 0;
        }
        .debug-info {
            font-size: 0.8em;
            color: #999;
            margin-top: 10px;
            padding: 10px;
            background: #f5f5f5;
            border-radius: 5px;
            display: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Service Load Monitor <span class="badge">v3.0.3</span></h1>
            <div class="author">by <a href="https://www.wael.name" target="_blank">Wael Isa</a></div>
            <div class="last-update" id="lastUpdate">Loading...</div>
            <button onclick="toggleDebug()" style="margin-top: 10px; padding: 5px 10px; background: #667eea; color: white; border: none; border-radius: 5px; cursor: pointer;">Toggle Debug</button>
            <div id="debugInfo" class="debug-info"></div>
        </div>

        <div class="stats-grid" id="statsGrid">
            <div class="stat-card"><h3>System Load</h3><div class="value">Loading...</div></div>
            <div class="stat-card"><h3>Uptime</h3><div class="value">Loading...</div></div>
            <div class="stat-card"><h3>Memory</h3><div class="value">Loading...</div></div>
            <div class="stat-card"><h3>Disk Usage</h3><div class="value">Loading...</div></div>
        </div>

        <div class="pihole-section" id="piholeSection" style="display: none;">
            <h2>🛡️ Pi-hole Status</h2>
            <div class="pihole-stats" id="piholeStats"></div>
        </div>

        <div class="dns-section">
            <h2>🌐 DNS Services <span id="dnsCount"></span></h2>
            <div class="dns-grid" id="dnsGrid">
                <div class="loading">Loading DNS services...</div>
            </div>
        </div>

        <div class="services-section">
            <h2>📊 Monitored Services</h2>
            <div class="service-list" id="serviceList">
                <div class="loading">Loading services...</div>
            </div>
        </div>
    </div>

    <div class="footer">
        <p>© 2026 <a href="https://www.wael.name" target="_blank">Wael Isa</a> - Service Load Monitor v3.0.3</p>
    </div>

    <script>
        let debug = false;

        function toggleDebug() {
            debug = !debug;
            document.getElementById('debugInfo').style.display = debug ? 'block' : 'none';
        }

        function stripAnsiCodes(str) {
            if (!str) return str;
            // Remove ANSI color codes
            return str.replace(/\u001b\[.*?m/g, '');
        }

        function formatServiceName(name) {
            if (!name) return name;
            // Remove .service suffix and replace hyphens with spaces
            return name.replace('.service', '').replace(/-/g, ' ');
        }

        function refreshData() {
            fetch('status.json?' + new Date().getTime())
                .then(response => {
                    if (!response.ok) {
                        throw new Error('HTTP error ' + response.status);
                    }
                    return response.text();
                })
                .then(text => {
                    // Strip any ANSI codes from the raw text
                    const cleanText = stripAnsiCodes(text);

                    if (debug) {
                        document.getElementById('debugInfo').innerHTML = '<strong>Raw JSON:</strong><br><pre>' + cleanText.substring(0, 500) + '...</pre>';
                    }

                    try {
                        return JSON.parse(cleanText);
                    } catch (e) {
                        console.error('JSON parse error:', e);
                        console.error('Raw text:', cleanText.substring(0, 200));
                        throw new Error('Invalid JSON: ' + e.message);
                    }
                })
                .then(data => {
                    console.log('Data received:', data);

                    document.getElementById('lastUpdate').textContent = 'Last updated: ' + (data.last_update || 'Unknown');

                    // Update stats
                    const statsGrid = document.getElementById('statsGrid');
                    if (data.servers && data.servers[0]) {
                        const s = data.servers[0];
                        statsGrid.innerHTML = `
                            <div class="stat-card"><h3>System Load</h3><div class="value">${s.load || '0.00'}</div></div>
                            <div class="stat-card"><h3>Uptime</h3><div class="value">${s.uptime || '0'}</div></div>
                            <div class="stat-card"><h3>Memory</h3><div class="value">${s.memory || '0/0'}</div></div>
                            <div class="stat-card"><h3>Disk Usage</h3><div class="value">${s.disk_usage || '0%'}</div></div>
                        `;
                    }

                    // Update Pi-hole section
                    const piholeSection = document.getElementById('piholeSection');
                    if (data.pihole && data.pihole.status) {
                        piholeSection.style.display = 'block';
                        const piholeStats = document.getElementById('piholeStats');
                        const status = data.pihole.status || 'unknown';
                        const statusClass = status === 'active' ? 'status-active' : (status === 'inactive' ? 'status-inactive' : 'status-unknown');
                        const blockedPercent = data.pihole.queries_today > 0
                            ? ((data.pihole.blocked_today / data.pihole.queries_today * 100).toFixed(1) + '%')
                            : '0%';

                        piholeStats.innerHTML = `
                            <div class="stat-card">
                                <h3>Status</h3>
                                <div class="value"><span class="status-badge ${statusClass}">${status}</span></div>
                            </div>
                            <div class="stat-card">
                                <h3>Queries Today</h3>
                                <div class="value">${data.pihole.queries_today || 0}</div>
                            </div>
                            <div class="stat-card">
                                <h3>Blocked Today</h3>
                                <div class="value">${data.pihole.blocked_today || 0}</div>
                            </div>
                            <div class="stat-card">
                                <h3>Blocked %</h3>
                                <div class="value">${blockedPercent}</div>
                            </div>
                        `;
                    } else {
                        piholeSection.style.display = 'none';
                    }

                    // Update DNS services - CLOUDFLARED REMOVED
                    const dnsGrid = document.getElementById('dnsGrid');
                    const dnsCount = document.getElementById('dnsCount');

                    if (data.servers && data.servers[0] && data.servers[0].dns_services) {
                        const dnsServices = data.servers[0].dns_services;
                        dnsCount.textContent = `(${dnsServices.length})`;

                        if (dnsServices.length > 0) {
                            dnsGrid.innerHTML = dnsServices.map(s => {
                                let details = '';
                                if (s.name === 'pihole-FTL.service' && s.details) {
                                    details = `
                                        <div class="dns-stats">
                                            <div class="dns-stat-item"><span class="dns-stat-label">Queries</span><span class="dns-stat-value">${s.details.queries_today || 0}</span></div>
                                            <div class="dns-stat-item"><span class="dns-stat-label">Blocked</span><span class="dns-stat-value">${s.details.blocked_today || 0}</span></div>
                                        </div>
                                    `;
                                } else if (s.details && s.details.version) {
                                    details = `
                                        <div class="dns-stats">
                                            <div class="dns-stat-item"><span class="dns-stat-label">Version</span><span class="dns-stat-value">${(s.details.version || 'unknown').substring(0, 15)}</span></div>
                                        </div>
                                    `;
                                }

                                const statusClass = s.status === 'active' ? 'status-active' : (s.status === 'inactive' ? 'status-inactive' : 'status-unknown');
                                const serviceName = formatServiceName(s.name);

                                return `
                                    <div class="dns-card">
                                        <h3>${serviceName} <span class="status ${statusClass}">${s.status}</span></h3>
                                        <div style="display: flex; justify-content: space-between; margin-bottom: 10px;">
                                            <span>CPU: ${s.cpu || 0}%</span>
                                            <span>MEM: ${s.mem || 0}%</span>
                                        </div>
                                        ${details}
                                    </div>
                                `;
                            }).join('');
                        } else {
                            dnsGrid.innerHTML = '<div class="no-services">No DNS services detected</div>';
                        }
                    } else {
                        dnsGrid.innerHTML = '<div class="no-services">No DNS services detected</div>';
                    }

                    // Update regular services - FILTER OUT DNS SERVICES TO AVOID DUPLICATES
                    const serviceList = document.getElementById('serviceList');
                    const dnsServiceNames = ['pihole-FTL.service', 'unbound.service', 'dnscrypt-proxy.service', 'dnsmasq.service', 'named.service'];

                    if (data.servers && data.servers[0] && data.servers[0].services) {
                        // Filter out DNS services to avoid duplicates
                        const filteredServices = data.servers[0].services.filter(s => !dnsServiceNames.includes(s.name));

                        if (filteredServices.length > 0) {
                            serviceList.innerHTML = filteredServices.map(s => {
                                const statusClass = s.status === 'active' ? 'status-active' : (s.status === 'inactive' ? 'status-inactive' : 'status-unknown');
                                const displayStatus = s.status || 'unknown';

                                return `
                                    <div class="service-item">
                                        <div class="service-name">${s.name}</div>
                                        <div class="service-status">
                                            <span class="status-badge ${statusClass}">${displayStatus}</span>
                                        </div>
                                        <div class="service-cpu">${s.cpu || 0}% CPU</div>
                                        <div class="service-mem">${s.mem || 0}% MEM</div>
                                    </div>
                                `;
                            }).join('');
                        } else {
                            serviceList.innerHTML = '<div class="no-services">No additional services configured</div>';
                        }
                    } else {
                        serviceList.innerHTML = '<div class="no-services">No service data available</div>';
                    }
                })
                .catch(error => {
                    console.error('Error loading data:', error);
                    document.getElementById('lastUpdate').textContent = 'Error loading data: ' + error.message;

                    // Show error in service lists
                    document.getElementById('dnsGrid').innerHTML = '<div class="error-message">Error loading DNS services. Check if the updater is running.<br><small>' + error.message + '</small></div>';
                    document.getElementById('serviceList').innerHTML = '<div class="error-message">Error loading services. Check if the updater is running.<br><small>' + error.message + '</small></div>';
                });
        }

        // Refresh immediately and then every 10 seconds
        refreshData();
        setInterval(refreshData, 10000);
    </script>
</body>
</html>
HTML

    chmod -R 755 "${DASHBOARD_DIR}"
    print_substep "Dashboard files created - Cloudflared removed"
}

create_dashboard_scripts() {
    print_substep "Creating dashboard scripts..."

    cat > "${DASHBOARD_SCRIPT}" << 'EOF'
#!/bin/bash

# =============================================================================
# Service Monitor Dashboard Updater v3.0.3 - CLOUDFLARED REMOVED
# =============================================================================
# Author: Wael Isa
# Website: https://www.wael.name
# =============================================================================

DASHBOARD_DIR="/var/www/html/service-monitor"
LOG_FILE="/var/log/service-monitor.log"
CONFIG_FILE="/etc/service-monitor/config.conf"
DEBUG_LOG="/var/log/service-monitor-updater-debug.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${LOG_FILE}"
}

# Function to escape JSON strings properly
json_escape() {
    local str="$1"
    # Escape backslashes first
    str="${str//\\/\\\\}"
    # Escape double quotes
    str="${str//\"/\\\"}"
    # Escape control characters
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    # Remove any other control characters
    str=$(echo -n "$str" | tr -d '\000-\011\013-\037\177')
    echo -n "$str"
}

# Function to get service CPU and memory usage
get_service_stats() {
    local service="$1"
    local pid=""
    local cpu=0
    local mem=0

    # Try to get PID using pgrep
    case "${service}" in
        "pihole-FTL.service")
            pid=$(pgrep -f "pihole-FTL" | head -1)
            ;;
        "unbound.service")
            pid=$(pgrep -f "unbound" | head -1)
            ;;
        "dnscrypt-proxy.service")
            pid=$(pgrep -f "dnscrypt-proxy" | head -1)
            # Try alternative process names
            if [[ -z "${pid}" ]]; then
                pid=$(pgrep -f "dnscrypt-proxy" | head -1)
            fi
            ;;
        "dnsmasq.service")
            pid=$(pgrep -f "dnsmasq" | head -1)
            ;;
        "named.service")
            pid=$(pgrep -f "named" | head -1)
            ;;
        *)
            # Try to get PID from systemd
            pid=$(systemctl show -p MainPID "${service}" 2>/dev/null | cut -d= -f2)
            ;;
    esac

    # If we have a PID and it's not 0, get CPU and memory usage
    if [[ -n "${pid}" ]] && [[ "${pid}" != "0" ]] && [[ -f "/proc/${pid}/stat" ]]; then
        # Get CPU usage using ps (more reliable)
        cpu=$(ps -p "${pid}" -o %cpu --no-headers 2>/dev/null | tr -d ' ' | cut -d'.' -f1)
        mem=$(ps -p "${pid}" -o %mem --no-headers 2>/dev/null | tr -d ' ' | cut -d'.' -f1)

        # Ensure we have numbers
        cpu=${cpu:-0}
        mem=${mem:-0}
    fi

    echo "${cpu}|${mem}"
}

# Function to get Pi-hole stats
get_pihole_stats() {
    local stats="{}"

    if command -v pihole &> /dev/null || [[ -f "/usr/local/bin/pihole" ]] || [[ -f "/usr/bin/pihole" ]]; then
        local status=$(systemctl is-active pihole-FTL.service 2>/dev/null || echo "inactive")
        local queries_today=0
        local blocked_today=0

        if [[ -f "/var/log/pihole.log" ]]; then
            queries_today=$(grep -c "query" /var/log/pihole.log 2>/dev/null || echo 0)
            blocked_today=$(grep -c "gravity blocked" /var/log/pihole.log 2>/dev/null || echo 0)
        elif [[ -f "/var/log/pihole/pihole.log" ]]; then
            queries_today=$(grep -c "query" /var/log/pihole/pihole.log 2>/dev/null || echo 0)
            blocked_today=$(grep -c "gravity blocked" /var/log/pihole/pihole.log 2>/dev/null || echo 0)
        fi

        stats="{
            \"status\": \"$(json_escape "${status}")\",
            \"queries_today\": ${queries_today},
            \"blocked_today\": ${blocked_today}
        }"
    fi

    echo "${stats}"
}

# Function to get Unbound stats
get_unbound_stats() {
    local stats="{}"

    if command -v unbound &> /dev/null; then
        local version=$(unbound -V 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")

        stats="{
            \"version\": \"$(json_escape "${version}")\"
        }"
    fi

    echo "${stats}"
}

# Function to get DNSCrypt-Proxy stats
get_dnscrypt_stats() {
    local stats="{}"

    if command -v dnscrypt-proxy &> /dev/null; then
        local version=$(dnscrypt-proxy --version 2>/dev/null || echo "unknown")

        stats="{
            \"version\": \"$(json_escape "${version}")\"
        }"
    fi

    echo "${stats}"
}

log_message "Dashboard updater v3.0.3 started - Cloudflared removed"

while true; do
    # Get system info with error handling and JSON escaping
    HOSTNAME=$(hostname 2>/dev/null | json_escape || echo "localhost")
    UPTIME=$(uptime 2>/dev/null | sed 's/.*up \([^,]*\),.*/\1/' | json_escape || echo "unknown")
    LOAD=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs | json_escape || echo "0.00")
    CPU_CORES=$(nproc 2>/dev/null || echo "1")
    MEMORY=$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}' | json_escape || echo "0/0")
    DISK=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' | json_escape || echo "0%")
    IOWAIT=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $8}' | cut -d',' -f1 || echo "0")
    IOWAIT=${IOWAIT:-0}

    # Get Pi-hole stats
    PIHOLE_STATS=$(get_pihole_stats)

    # Check DNS services - CLOUDFLARED REMOVED
    DNS_SERVICES=(
        "pihole-FTL.service"
        "unbound.service"
        "dnscrypt-proxy.service"
        "dnsmasq.service"
        "named.service"
    )

    DNS_JSON=""
    FIRST_DNS=1

    for SERVICE in "${DNS_SERVICES[@]}"; do
        # Check if service exists (either in systemd or as a file)
        if systemctl list-unit-files 2>/dev/null | grep -q "${SERVICE}" || [[ -f "/etc/systemd/system/${SERVICE}" ]]; then
            if [[ ${FIRST_DNS} -eq 1 ]]; then
                FIRST_DNS=0
            else
                DNS_JSON+=","
            fi

            STATUS=$(systemctl is-active "${SERVICE}" 2>/dev/null || echo "inactive")
            STATUS=$(json_escape "${STATUS}")

            # Get CPU and memory stats
            STATS=$(get_service_stats "${SERVICE}")
            CPU=$(echo "${STATS}" | cut -d'|' -f1)
            MEM=$(echo "${STATS}" | cut -d'|' -f2)

            # Get service-specific details
            DETAILS="{}"
            case "${SERVICE}" in
                "pihole-FTL.service")
                    DETAILS=$(get_pihole_stats)
                    ;;
                "unbound.service")
                    DETAILS=$(get_unbound_stats)
                    ;;
                "dnscrypt-proxy.service")
                    DETAILS=$(get_dnscrypt_stats)
                    ;;
            esac

            SERVICE_NAME=$(json_escape "${SERVICE}")
            DNS_JSON+="{\"name\":\"${SERVICE_NAME}\",\"status\":\"${STATUS}\",\"cpu\":${CPU},\"mem\":${MEM},\"details\":${DETAILS}}"
            log_message "DNS Service ${SERVICE}: ${STATUS} (CPU: ${CPU}%, MEM: ${MEM}%)"
        fi
    done

    # Get regular service status from config
    SERVICES_JSON=""
    FIRST_REG=1

    if [[ -f "${CONFIG_FILE}" ]]; then
        while IFS= read -r line; do
            if [[ "${line}" =~ MONITORED_SERVICES=\"(.*)\" ]]; then
                IFS=' ' read -ra SERVICES <<< "${BASH_REMATCH[1]}"
                for SERVICE in "${SERVICES[@]}"; do
                    # Skip if it's already in DNS services (avoid duplicates)
                    if [[ " ${DNS_SERVICES[@]} " =~ " ${SERVICE} " ]]; then
                        continue
                    fi

                    if [[ ${FIRST_REG} -eq 1 ]]; then
                        FIRST_REG=0
                    else
                        SERVICES_JSON+=","
                    fi

                    STATUS=$(systemctl is-active "${SERVICE}" 2>/dev/null || echo "unknown")
                    STATUS=$(json_escape "${STATUS}")

                    # Get CPU and memory stats for regular services
                    STATS=$(get_service_stats "${SERVICE}")
                    CPU=$(echo "${STATS}" | cut -d'|' -f1)
                    MEM=$(echo "${STATS}" | cut -d'|' -f2)

                    SERVICE_NAME=$(json_escape "${SERVICE}")
                    SERVICES_JSON+="{\"name\":\"${SERVICE_NAME}\",\"status\":\"${STATUS}\",\"cpu\":${CPU},\"mem\":${MEM}}"
                    log_message "Monitored Service ${SERVICE}: ${STATUS} (CPU: ${CPU}%, MEM: ${MEM}%)"
                done
                break
            fi
        done < "${CONFIG_FILE}"
    fi

    # Create JSON with proper formatting - ensure all strings are escaped
    cat > "${DASHBOARD_DIR}/status.json" << JSON
{
    "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "3.0.3",
    "author": "Wael Isa",
    "website": "https://www.wael.name",
    "servers": [
        {
            "id": "local",
            "hostname": "${HOSTNAME}",
            "uptime": "${UPTIME}",
            "load": "${LOAD}",
            "cpu_cores": ${CPU_CORES},
            "memory": "${MEMORY}",
            "iowait": "${IOWAIT}%",
            "disk_usage": "${DISK}",
            "services": [${SERVICES_JSON}],
            "dns_services": [${DNS_JSON}]
        }
    ],
    "pihole": ${PIHOLE_STATS},
    "alerts": []
}
JSON

    # Verify JSON is valid
    if ! python3 -m json.tool "${DASHBOARD_DIR}/status.json" > /dev/null 2>&1; then
        log_message "ERROR: Generated invalid JSON, creating emergency backup"
        cp "${DASHBOARD_DIR}/status.json" "${DASHBOARD_DIR}/status.json.error"
        # Create minimal valid JSON as fallback
        cat > "${DASHBOARD_DIR}/status.json" << JSONFALLBACK
{
    "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "3.0.3",
    "author": "Wael Isa",
    "website": "https://www.wael.name",
    "servers": [
        {
            "id": "local",
            "hostname": "${HOSTNAME}",
            "uptime": "${UPTIME}",
            "load": "${LOAD}",
            "cpu_cores": ${CPU_CORES},
            "memory": "${MEMORY}",
            "iowait": "${IOWAIT}%",
            "disk_usage": "${DISK}",
            "services": [],
            "dns_services": []
        }
    ],
    "pihole": null,
    "alerts": []
}
JSONFALLBACK
        log_message "Created fallback JSON"
    else
        log_message "Dashboard updated successfully with valid JSON"
    fi

    sleep 30
done
EOF

    chmod +x "${DASHBOARD_SCRIPT}"
    print_substep "Dashboard scripts created - Cloudflared removed, DNSCrypt-Proxy fixed"
}

create_dashboard_services() {
    print_substep "Creating dashboard services..."

    cat > "${DASHBOARD_HTTP_SERVICE}" << EOF
[Unit]
Description=Service Monitor HTTP Server v3.0.3
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

    cat > "${DASHBOARD_UPDATER_SERVICE}" << EOF
[Unit]
Description=Service Monitor Dashboard Updater v3.0.3
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=${DASHBOARD_SCRIPT}
Restart=always
RestartSec=5
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable service-monitor-http.service &> /dev/null
    systemctl enable service-monitor-updater.service &> /dev/null
    systemctl restart service-monitor-http.service &> /dev/null
    systemctl restart service-monitor-updater.service &> /dev/null

    print_substep "Dashboard services created and started"
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

create_monitor_script() {
    cat > "${MONITOR_SCRIPT}" << 'EOF'
#!/bin/bash

# =============================================================================
# Service Load Monitor - Core Script v3.0.3
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

# DNS Services to monitor - CLOUDFLARED REMOVED
DNS_SERVICES=(
    "pihole-FTL.service"
    "unbound.service"
    "dnscrypt-proxy.service"
    "dnsmasq.service"
    "named.service"
)

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${LOG_FILE}"
}

# Function to check DNS services
check_dns_services() {
    for service in "${DNS_SERVICES[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "${service}" || [[ -f "/etc/systemd/system/${service}" ]]; then
            local status=$(systemctl is-active "${service}" 2>/dev/null || echo "inactive")
            log_message "DNS Service ${service}: ${status}"

            if [[ "${status}" != "active" ]] && [[ "${MONITORED_SERVICES}" =~ ${service} ]]; then
                log_message "WARNING: Critical DNS service ${service} is ${status}"
            fi
        fi
    done
}

# Function to check Pi-hole specifically
check_pihole() {
    if command -v pihole &> /dev/null || [[ -f "/usr/local/bin/pihole" ]] || [[ -f "/usr/bin/pihole" ]]; then
        local status=$(systemctl is-active pihole-FTL.service 2>/dev/null || echo "inactive")
        log_message "Pi-hole Status: ${status}"

        # Check Pi-hole logs for anomalies
        local log_file=""
        if [[ -f "/var/log/pihole.log" ]]; then
            log_file="/var/log/pihole.log"
        elif [[ -f "/var/log/pihole/pihole.log" ]]; then
            log_file="/var/log/pihole/pihole.log"
        fi

        if [[ -n "${log_file}" ]]; then
            local errors=$(tail -100 "${log_file}" 2>/dev/null | grep -i "error" | wc -l)
            if [[ ${errors} -gt 0 ]]; then
                log_message "WARNING: Found ${errors} errors in Pi-hole log"
            fi
        fi
    fi
}

# Main monitoring loop
log_message "Service Load Monitor v3.0.3 started - Cloudflared removed"

while true; do
    CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/ //g' 2>/dev/null || echo "0")

    if (( $(echo "$CURRENT_LOAD > $LOAD_THRESHOLD" | bc -l 2>/dev/null) )); then
        log_message "High load detected: $CURRENT_LOAD (threshold: $LOAD_THRESHOLD)"

        # Check DNS services during high load
        check_dns_services
    fi

    # Check Pi-hole periodically
    if [[ $(( $(date +%s) % 300 )) -lt 30 ]]; then
        check_pihole
    fi

    sleep "${CHECK_INTERVAL}"
done
EOF

    chmod +x "${MONITOR_SCRIPT}"
    print_substep "Monitor script created - Cloudflared removed"
}

create_config_file() {
    mkdir -p "${CONFIG_BASE_DIR}"

    # Auto-detect DNS services
    local detected_dns=$(detect_dns_services)
    local dns_list=""
    for service in ${detected_dns}; do
        if [[ -n "${dns_list}" ]]; then
            dns_list+=" "
        fi
        dns_list+="${service}"
    done

    # Add common system services
    local common_services="ssh.service cron.service"

    # Combine DNS services with common services
    if [[ -n "${dns_list}" ]]; then
        MONITORED="${dns_list} ${common_services}"
    else
        MONITORED="${common_services}"
    fi

    cat > "${CONFIG_FILE}" << EOF
# =============================================================================
# Service Load Monitor - Configuration v3.0.3
# =============================================================================
# Author:  Wael Isa
# Website: https://www.wael.name
# =============================================================================

# Monitor settings
CHECK_INTERVAL=30
LOAD_THRESHOLD=5.0
CPU_THRESHOLD=70
IO_WAIT_THRESHOLD=20

# Service settings - Auto-detected services
MONITORED_SERVICES="${MONITORED}"

# DNS Suite specific settings
MONITOR_PIHOLE="yes"
MONITOR_UNBOUND="yes"
MONITOR_DNSCRYPT="yes"
PIHOLE_LOG_WATCH="yes"
DNS_QUERY_THRESHOLD=1000

# Dashboard settings
ENABLE_DASHBOARD="yes"
DASHBOARD_PORT=8080
DASHBOARD_REFRESH=30

# Logging
LOG_FILE="/var/log/service-monitor.log"
ENABLE_SNAPSHOTS="yes"
SNAPSHOT_DIR="/var/log/service-monitor-snapshots"
LOG_RETENTION_DAYS=30

# Advanced settings
ENABLE_PREDICTIVE="yes"
GRACEFUL_RELOADS="yes"
PROTECT_CRITICAL="yes"
DNS_FAILOVER="yes"

# Pi-hole specific
PIHOLE_WEB_UI="http://localhost/admin"
PIHOLE_API_PORT=80
PIHOLE_DISPLAY_STATS="yes"
EOF

    print_substep "Configuration file created with services: ${MONITORED}"
}

# =============================================================================
# CLEANUP FUNCTIONS
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
    if [[ -f "/etc/systemd/system/service-monitor-v2.2.2.service" ]]; then
        print_substep "Removing old versioned service file..."
        rm -f "/etc/systemd/system/service-monitor-v2.2.2.service"
        old_files_removed=1
    fi

    # Remove old versioned config file
    if [[ -f "/etc/service-monitor/config-v2.2.2.conf" ]]; then
        print_substep "Removing old versioned config file..."
        rm -f "/etc/service-monitor/config-v2.2.2.conf"
        old_files_removed=1
    fi

    # Remove old versioned monitor script
    if [[ -f "/usr/local/bin/service_load_monitor.sh" ]]; then
        print_substep "Removing old versioned monitor script..."
        rm -f "/usr/local/bin/service_load_monitor.sh"
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
# MAIN INSTALLATION FUNCTION
# =============================================================================

install_monitor() {
    print_banner

    echo -e "${WHITE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║           INSTALLATION WIZARD - v3.0.3                     ║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Step 1: Check sudo
    local total_steps=10
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

    # Step 3: Detect DNS services
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Detecting DNS services"

    local dns_services=($(detect_dns_services))
    if [[ ${#dns_services[@]} -gt 0 ]]; then
        print_success "Found ${#dns_services[@]} DNS services:"
        for service in "${dns_services[@]}"; do
            echo -e "  • ${service}"
        done
    else
        print_info "No DNS services detected"
    fi

    # Step 4: Clean up old versioned files
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Cleaning up old files"
    cleanup_old_versioned_files

    # Step 5: Check existing installation
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

    # Step 6: Check and install dependencies
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Checking and installing dependencies"

    if ! check_and_install_dependencies; then
        print_error "Failed to install required dependencies"
        exit 1
    fi
    print_success "Dependencies satisfied"

    # Step 7: Create directories
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Creating directories"

    mkdir -p "${CONFIG_BASE_DIR}"
    mkdir -p "${SNAPSHOT_DIR}"
    mkdir -p "${PERF_DATA_DIR}"
    mkdir -p "${DASHBOARD_DIR}"
    mkdir -p "${LIB_BASE_DIR}/clients"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "$(dirname "${LOG_FILE}")"

    print_success "Directories created"

    # Step 8: Create monitor files
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Creating monitor files"

    create_monitor_script
    create_config_file

    print_success "Monitor files created"

    # Step 9: Create dashboard
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Creating web dashboard"

    create_dashboard_files
    create_dashboard_scripts
    create_dashboard_services

    print_success "Dashboard created and started"

    # Step 10: Create main service
    current_step=$((current_step + 1))
    print_step $current_step $total_steps "Creating main service"

    cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=Service Load Monitor v3.0.3 by Wael Isa
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

# Resource limits
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
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    DASHBOARD ACCESS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Local URL:  ${GREEN}http://localhost:${DEFAULT_DASHBOARD_PORT}/${NC}"
    echo -e "  Network URL: ${GREEN}http://${ip}:${DEFAULT_DASHBOARD_PORT}/${NC}"
    echo ""

    # Pi-hole specific info
    if command -v pihole &> /dev/null || [[ -f "/usr/local/bin/pihole" ]] || [[ -f "/usr/bin/pihole" ]]; then
        echo -e "${GREEN}🛡️  Pi-hole detected!${NC}"
        echo -e "  Pi-hole Admin: http://${ip}/admin"
        echo -e "  Monitor includes Pi-hole statistics"
        echo ""
    fi

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

    # Summary - FIXED WITH -e FLAGS
    echo -e "${WHITE}Installation Summary:${NC}"
    echo "  • Version: ${SCRIPT_VERSION}"
    echo -e "  • Monitor Service: ${GREEN}service-monitor.service${NC}"
    echo -e "  • HTTP Server: ${GREEN}service-monitor-http.service${NC} (port ${DEFAULT_DASHBOARD_PORT})"
    echo -e "  • Updater Service: ${GREEN}service-monitor-updater.service${NC}"
    echo "  • Config: ${CONFIG_FILE}"
    echo "  • Logs: ${LOG_FILE}"
    echo "  • Dashboard: ${DASHBOARD_DIR}"
    echo "  • DNS Services Monitored: ${#dns_services[@]}"
    echo ""
    echo -e "${WHITE}Commands:${NC}"
    echo -e "  • Check status: ${GREEN}systemctl status service-monitor.service${NC}"
    echo -e "  • View logs: ${GREEN}tail -f ${LOG_FILE}${NC}"
    echo -e "  • Edit config: ${GREEN}nano ${CONFIG_FILE}${NC}"
    echo -e "  • Restart dashboard: ${GREEN}systemctl restart service-monitor-updater.service${NC}"
    echo -e "  • Check DNS services: ${GREEN}systemctl status pihole-FTL.service unbound.service dnscrypt-proxy.service${NC}"
    echo ""
    echo -e "${GREEN}Thank you for using Service Load Monitor v3.0.3!${NC}"
    echo -e "${GREEN}© 2026 Wael Isa - https://www.wael.name${NC}"
    echo ""
}

# =============================================================================
# REMOVAL FUNCTIONS
# =============================================================================

remove_monitor() {
    print_banner

    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              REMOVAL WIZARD - v3.0.3                       ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if ! check_sudo; then
        print_error "This operation requires sudo access"
        exit 1
    fi

    if [[ ! -f "${SERVICE_FILE}" ]] && [[ ! -f "${MONITOR_SCRIPT}" ]]; then
        print_warning "Service Load Monitor does not appear to be installed"
        echo -e "${YELLOW}Continue anyway? (y/N)${NC}"
        read -p "> " force_remove
        if [[ ! "${force_remove}" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    echo -e "${RED}WARNING: This will completely remove Service Load Monitor${NC}"
    echo -e "${YELLOW}Are you absolutely sure? Type 'YES' to confirm:${NC}"
    read -p "> " confirm

    if [[ "${confirm}" != "YES" ]]; then
        print_info "Removal cancelled"
        exit 0
    fi

    echo ""
    echo -e "${YELLOW}Do you want to create a backup before removal? (y/N)${NC}"
    read -p "> " do_backup

    if [[ "${do_backup}" =~ ^[Yy]$ ]]; then
        backup_existing "pre-removal"
    fi

    print_info "Stopping services..."
    systemctl stop service-monitor.service 2>/dev/null
    systemctl stop service-monitor-http.service 2>/dev/null
    systemctl stop service-monitor-updater.service 2>/dev/null

    print_info "Disabling services..."
    systemctl disable service-monitor.service 2>/dev/null
    systemctl disable service-monitor-http.service 2>/dev/null
    systemctl disable service-monitor-updater.service 2>/dev/null

    print_info "Removing files..."
    rm -f "${MONITOR_SCRIPT}"
    rm -f "${SERVICE_FILE}"
    rm -f "${DASHBOARD_SCRIPT}"
    rm -f "${CLIENT_SCRIPT}"
    rm -f "${UPDATE_SCRIPT}"
    rm -f "${LOGROTATE_FILE}"
    rm -f "${DASHBOARD_HTTP_SERVICE}"
    rm -f "${DASHBOARD_UPDATER_SERVICE}"

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

    systemctl daemon-reload

    print_success "Service Load Monitor v3.0.3 has been removed"
}

# =============================================================================
# STATUS FUNCTIONS
# =============================================================================

show_status() {
    print_banner

    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    SYSTEM STATUS - v3.0.3${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # System info
    echo -e "${WHITE}System Information:${NC}"
    echo "  • Distribution: $(detect_distro)"

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

    echo "  • Hostname: $(hostname 2>/dev/null || echo "unknown")"
    echo "  • Kernel: $(uname -r 2>/dev/null || echo "unknown")"
    echo "  • Uptime: $(uptime | sed 's/.*up \([^,]*\),.*/\1/' 2>/dev/null || echo "unknown")"
    echo ""

    # Service status
    echo -e "${WHITE}Service Status:${NC}"

    if systemctl is-active --quiet service-monitor.service 2>/dev/null; then
        echo -e "  • ${GREEN}●${NC} Monitor Service: Running"
    else
        echo -e "  • ${RED}○${NC} Monitor Service: Stopped"
    fi

    if systemctl is-active --quiet service-monitor-http.service 2>/dev/null; then
        echo -e "  • ${GREEN}●${NC} HTTP Server: Running (port ${DEFAULT_DASHBOARD_PORT})"
    else
        echo -e "  • ${RED}○${NC} HTTP Server: Stopped"
    fi

    if systemctl is-active --quiet service-monitor-updater.service 2>/dev/null; then
        echo -e "  • ${GREEN}●${NC} Updater Service: Running"
    else
        echo -e "  • ${RED}○${NC} Updater Service: Stopped"
    fi

    # DNS Services
    echo ""
    echo -e "${WHITE}DNS Services:${NC}"

    local dns_services=($(detect_dns_services))
    if [[ ${#dns_services[@]} -gt 0 ]]; then
        for service in "${dns_services[@]}"; do
            if systemctl is-active --quiet "${service}" 2>/dev/null; then
                echo -e "  • ${GREEN}●${NC} ${service}: Running"
            else
                echo -e "  • ${RED}○${NC} ${service}: Stopped"
            fi
        done
    else
        echo "  • No DNS services detected"
    fi

    # Pi-hole specific
    if command -v pihole &> /dev/null || [[ -f "/usr/local/bin/pihole" ]] || [[ -f "/usr/bin/pihole" ]]; then
        echo ""
        echo -e "${WHITE}Pi-hole Information:${NC}"
        local pihole_version=$(pihole -v 2>/dev/null | head -1 | awk '{print $5}' || echo "unknown")
        echo "  • Version: ${pihole_version}"
        echo "  • Admin UI: http://$(hostname -I 2>/dev/null | awk '{print $1}')/admin"
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

    # Dashboard URL
    echo ""
    echo -e "${WHITE}Dashboard URL:${NC}"
    local ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
    echo "  • http://${ip}:${DEFAULT_DASHBOARD_PORT}/"
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
# BANNER FUNCTIONS
# =============================================================================

print_banner() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}           SERVICE LOAD MONITOR v3.0.3                   ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${GREEN}  Author:  Wael Isa                                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Version: 3.0.3 (DNS Suite - Cloudflared Removed)      ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Date:    February 18, 2026                             ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Website: https://www.wael.name                         ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_features() {
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}               FEATURE HIGHLIGHTS v3.0.3${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}🛡️  Complete DNS Service Integration${NC}"
    echo "  • Pi-hole FTL service monitoring with statistics"
    echo "  • Unbound resolver monitoring"
    echo "  • DNSCrypt-Proxy service tracking (FIXED display)"
    echo "  • dnsmasq and BIND9 support"
    echo "  • CLOUDFLARED REMOVED per request"
    echo ""
    echo -e "${GREEN}📊 Fixed Dashboard Display${NC}"
    echo "  • All active services now show correctly"
    echo "  • CPU and memory usage for each service"
    echo "  • Real-time status updates every 10 seconds"
    echo "  • No more ANSI color codes in dashboard"
    echo "  • DNSCrypt-Proxy now shows correct status"
    echo "  • No duplicate service entries"
    echo ""
    echo -e "${GREEN}🌐 Enhanced DNS Monitoring${NC}"
    echo "  • Automatic service detection"
    echo "  • Service-specific statistics"
    echo "  • Pi-hole query and block counts"
    echo "  • Version information for DNS services"
    echo ""
    echo -e "${GREEN}🔧 Installation Improvements${NC}"
    echo "  • Better dependency checking"
    echo "  • Automatic backup before updates"
    echo "  • Clean removal of old versions"
    echo "  • Configuration migration"
    echo "  • JSON validation and error recovery"
    echo ""
}

# =============================================================================
# HELP FUNCTION
# =============================================================================

show_help() {
    print_banner
    echo -e "${WHITE}Available Commands:${NC}"
    echo ""
    echo "  install     - Install or update the monitor (v3.0.3)"
    echo "  remove      - Remove the monitor"
    echo "  status      - Show service status (including DNS services)"
    echo "  logs        - Follow log output"
    echo "  backup      - Create a backup"
    echo "  restore     - Restore from backup"
    echo "  version     - Show version information"
    echo "  help        - Show this help"
    echo ""
    echo -e "${WHITE}DNS Services Monitored:${NC}"
    echo "  • pihole-FTL.service"
    echo "  • unbound.service"
    echo "  • dnscrypt-proxy.service"
    echo "  • dnsmasq.service"
    echo "  • named.service (BIND9)"
    echo ""
    echo -e "${YELLOW}Note: Cloudflared has been removed from monitoring${NC}"
    echo ""
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_menu() {
    print_banner

    echo -e "${WHITE}Main Menu:${NC}"
    echo ""
    echo "  1) Install/Update Monitor (v3.0.3)"
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
                echo ""
                echo "Monitored DNS Services:"
                echo "  • Pi-hole FTL"
                echo "  • Unbound"
                echo "  • DNSCrypt-Proxy"
                echo "  • dnsmasq"
                echo "  • BIND9"
                echo ""
                echo "Note: Cloudflared has been removed"
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

    # Check sudo for interactive mode
    if ! check_sudo; then
        print_warning "Some features may require sudo access"
    fi

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
                if check_sudo; then
                    backup_existing "manual"
                    echo ""
                    print_success "Backup created"
                else
                    print_error "Sudo required for backup"
                fi
                read -p "Press Enter to continue..."
                ;;
            6)
                if check_sudo; then
                    echo "Available backups:"
                    ls -1 "${BACKUP_DIR}" 2>/dv/null || echo "No backups found"
                    echo ""
                    echo -n "Enter backup ID: "
                    read -r backup_id
                    restore_from_backup "${backup_id}"
                else
                    print_error "Sudo required for restore"
                fi
                read -p "Press Enter to continue..."
                ;;
            7)
                print_banner
                show_features
                read -p "Press Enter to continue..."
                ;;
            8)
                echo -e "\n${GREEN}Thank you for using Service Load Monitor v3.0.3!${NC}"
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
