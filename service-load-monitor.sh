#!/bin/bash

# =============================================================================
# Service Load Monitor - Installation & Management Script v3.0.4
# =============================================================================
# Author:  Wael Isa
# Version: 3.0.4
# Date:    February 18, 2026
# Website: https://www.wael.name
# =============================================================================
# Description: Enterprise-grade service monitoring with DNS suite integration
#              Pi-hole, Unbound, DNSCrypt-Proxy native support
#
# CRITICAL FIXES IN v3.0.4:
# -------------------------
# 1. FIXED: Installation output no longer appears in dashboard
# 2. FIXED: All ANSI color codes completely removed from JSON
# 3. FIXED: Service status now shows correctly (active/inactive)
# 4. FIXED: Dashboard no longer shows installation messages
# 5. FIXED: JSON now contains ONLY valid data, no terminal output
# 6. FIXED: Added output redirection to prevent pollution
# 7. FIXED: Proper service detection without debug messages
# 8. FIXED: Clean JSON generation with no extra text
# 9. FIXED: Updater script now runs silently
# 10. FIXED: All echo statements in service functions are silenced
# 11. FIXED: Color codes completely stripped from all data sources
# 12. FIXED: Installation wizard output separated from monitoring data
# 13. FIXED: Added missing detect_distro function
# 14. FIXED: Added all required dependency functions
# 15. RESTORED: Pi-hole statistics in dashboard (queries, blocked, percentage)
# =============================================================================

# Color codes for better UI - ONLY used in installation wizard, never in JSON
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
SCRIPT_VERSION="3.0.4"
SCRIPT_AUTHOR="Wael Isa"
SCRIPT_URL="https://www.wael.name"
SCRIPT_DATE="February 18, 2026"

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
VERSION_FILE="${CONFIG_BASE_DIR}/installed_version"
BACKUP_DIR="${LIB_BASE_DIR}/backups"
DEPENDENCY_LOG="${LOG_BASE_DIR}/dependency-install.log"

# Pi-hole paths
PIHOLE_LOG="/var/log/pihole.log"
PIHOLE_FTL_LOG="/var/log/pihole-FTL.log"
PIHOLE_GRAVITY="/etc/pihole/gravity.db"

# DNS service names
DNS_SERVICES=(
    "pihole-FTL.service"
    "unbound.service"
    "dnscrypt-proxy.service"
    "dnsmasq.service"
    "named.service"
)

# Default ports
DEFAULT_DASHBOARD_PORT=8080

# Cloud platform names
CLOUD_AWS="AWS"
CLOUD_GCP="GCP"
CLOUD_AZURE="Azure"
CLOUD_ORACLE="Oracle Cloud"
CLOUD_NONE="none"

# =============================================================================
# UI HELPER FUNCTIONS - ONLY USED IN INSTALLATION, NEVER IN JSON
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

print_success() {
    echo -e "${GREEN}✅${NC} ${1}"
}

print_error() {
    echo -e "${RED}❌${NC} ${1}"
}

print_warning() {
    echo -e "${RED}⚠${NC} ${1}"
}

# =============================================================================
# SYSTEM DETECTION FUNCTIONS
# =============================================================================

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
# SILENT SERVICE DETECTION - NO OUTPUT, FOR JSON ONLY
# =============================================================================

detect_dns_services_silent() {
    local detected=()

    # Check Pi-hole - completely silent, no output
    if systemctl list-unit-files 2>/dev/null | grep -q "pihole-FTL.service" 2>/dev/null; then
        detected+=("pihole-FTL.service")
    elif [[ -f "/etc/systemd/system/pihole-FTL.service" ]]; then
        detected+=("pihole-FTL.service")
    fi

    # Check Unbound
    if systemctl list-unit-files 2>/dev/null | grep -q "unbound.service" 2>/dev/null; then
        detected+=("unbound.service")
    elif [[ -f "/etc/systemd/system/unbound.service" ]]; then
        detected+=("unbound.service")
    fi

    # Check DNSCrypt-Proxy
    if systemctl list-unit-files 2>/dev/null | grep -q "dnscrypt-proxy.service" 2>/dev/null; then
        detected+=("dnscrypt-proxy.service")
    elif [[ -f "/etc/systemd/system/dnscrypt-proxy.service" ]]; then
        detected+=("dnscrypt-proxy.service")
    fi

    # Check dnsmasq
    if systemctl list-unit-files 2>/dev/null | grep -q "dnsmasq.service" 2>/dev/null; then
        detected+=("dnsmasq.service")
    fi

    # Check BIND9
    if systemctl list-unit-files 2>/dev/null | grep -q "named.service" 2>/dev/null; then
        detected+=("named.service")
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

command_exists() {
    command -v "$1" &> /dev/null
}

# =============================================================================
# DASHBOARD FUNCTIONS - COMPLETELY SILENT, WITH PI-HOLE STATS
# =============================================================================

create_dashboard_files() {
    print_substep "Creating dashboard files..."

    mkdir -p "${DASHBOARD_DIR}"

    # Create initial status.json with minimal data - NO COLORS, NO EXTRAS
    cat > "${DASHBOARD_DIR}/status.json" << EOF
{
    "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "3.0.4",
    "servers": [
        {
            "id": "local",
            "hostname": "$(hostname 2>/dev/null | sed 's/["\\]/\\\\&/g' || echo "localhost")",
            "uptime": "0",
            "load": "0.00",
            "cpu_cores": $(nproc 2>/dev/null || echo "1"),
            "memory": "0/0",
            "disk_usage": "0%",
            "services": [],
            "dns_services": []
        }
    ],
    "pihole": null
}
EOF

    # Create index.html with fixed JavaScript - INCLUDING PI-HOLE SECTION
    cat > "${DASHBOARD_DIR}/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>Service Monitor Dashboard v3.0.4 - Wael Isa</title>
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
        }
        .stat-card h3 { color: #666; font-size: 0.9em; margin-bottom: 10px; }
        .stat-card .value { color: #333; font-size: 1.8em; font-weight: bold; }

        .pihole-section {
            background: white;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            border-left: 4px solid #f0ad4e;
        }
        .pihole-section h2 {
            color: #333;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .pihole-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }

        .dns-section {
            background: white;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .dns-section h2 { color: #333; margin-bottom: 20px; }
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
        }
        .dns-card h3 {
            color: #333;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .status {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 12px;
            font-size: 0.8em;
            margin-left: 8px;
        }
        .status-active { background: #d4edda; color: #155724; }
        .status-inactive { background: #f8d7da; color: #721c24; }

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
            padding: 15px;
            background: #f8f9fa;
            border-radius: 10px;
        }
        .status-badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.9em;
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: white;
        }
        .footer a { color: white; text-decoration: none; }
        .last-update { color: #999; font-size: 0.9em; margin-top: 10px; }
        .loading { text-align: center; padding: 40px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Service Load Monitor <span class="badge">v3.0.4</span></h1>
            <div class="author">by <a href="https://www.wael.name" target="_blank">Wael Isa</a></div>
            <div class="last-update" id="lastUpdate">Loading...</div>
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
            <h2>🌐 DNS Services</h2>
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
        <p>© 2026 <a href="https://www.wael.name" target="_blank">Wael Isa</a> - Service Load Monitor v3.0.4</p>
    </div>

    <script>
        function refreshData() {
            fetch('status.json?' + new Date().getTime())
                .then(response => response.text())
                .then(text => {
                    // Strip any ANSI codes that might have snuck in
                    const cleanText = text.replace(/\u001b\[.*?m/g, '');
                    try {
                        return JSON.parse(cleanText);
                    } catch (e) {
                        console.error('JSON parse error:', e);
                        return null;
                    }
                })
                .then(data => {
                    if (!data) return;

                    document.getElementById('lastUpdate').textContent = 'Last updated: ' + (data.last_update || 'Unknown');

                    // Update stats
                    if (data.servers && data.servers[0]) {
                        const s = data.servers[0];
                        document.getElementById('statsGrid').innerHTML = `
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
                        const statusClass = status === 'active' ? 'status-active' : 'status-inactive';
                        const queriesToday = data.pihole.queries_today || 0;
                        const blockedToday = data.pihole.blocked_today || 0;
                        const blockedPercent = queriesToday > 0 ? ((blockedToday / queriesToday * 100).toFixed(1) + '%') : '0%';

                        piholeStats.innerHTML = `
                            <div class="stat-card">
                                <h3>Status</h3>
                                <div class="value"><span class="status-badge ${statusClass}">${status}</span></div>
                            </div>
                            <div class="stat-card">
                                <h3>Queries Today</h3>
                                <div class="value">${queriesToday}</div>
                            </div>
                            <div class="stat-card">
                                <h3>Blocked Today</h3>
                                <div class="value">${blockedToday}</div>
                            </div>
                            <div class="stat-card">
                                <h3>Blocked %</h3>
                                <div class="value">${blockedPercent}</div>
                            </div>
                        `;
                    } else {
                        piholeSection.style.display = 'none';
                    }

                    // Update DNS services
                    if (data.servers && data.servers[0] && data.servers[0].dns_services) {
                        const dnsServices = data.servers[0].dns_services;
                        if (dnsServices.length > 0) {
                            document.getElementById('dnsGrid').innerHTML = dnsServices.map(s => {
                                const statusClass = s.status === 'active' ? 'status-active' : 'status-inactive';
                                return `
                                    <div class="dns-card">
                                        <h3>${s.name.replace('.service', '')} <span class="status ${statusClass}">${s.status}</span></h3>
                                        <div>CPU: ${s.cpu || 0}% | MEM: ${s.mem || 0}%</div>
                                    </div>
                                `;
                            }).join('');
                        } else {
                            document.getElementById('dnsGrid').innerHTML = '<div class="loading">No DNS services detected</div>';
                        }
                    }

                    // Update regular services
                    if (data.servers && data.servers[0] && data.servers[0].services) {
                        const services = data.servers[0].services.filter(s =>
                            !['pihole-FTL.service', 'unbound.service', 'dnscrypt-proxy.service', 'dnsmasq.service', 'named.service'].includes(s.name)
                        );

                        if (services.length > 0) {
                            document.getElementById('serviceList').innerHTML = services.map(s => {
                                const statusClass = s.status === 'active' ? 'status-active' : 'status-inactive';
                                return `
                                    <div class="service-item">
                                        <div class="service-name">${s.name}</div>
                                        <div class="service-status">
                                            <span class="status-badge ${statusClass}">${s.status}</span>
                                        </div>
                                        <div>${s.cpu || 0}% CPU</div>
                                        <div>${s.mem || 0}% MEM</div>
                                    </div>
                                `;
                            }).join('');
                        } else {
                            document.getElementById('serviceList').innerHTML = '<div class="loading">No additional services</div>';
                        }
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                });
        }

        refreshData();
        setInterval(refreshData, 10000);
    </script>
</body>
</html>
HTML

    chmod -R 755 "${DASHBOARD_DIR}"
    print_substep "Dashboard files created with Pi-hole stats restored"
}

create_dashboard_scripts() {
    print_substep "Creating dashboard scripts..."

    cat > "${DASHBOARD_SCRIPT}" << 'EOF'
#!/bin/bash

# =============================================================================
# Service Monitor Dashboard Updater v3.0.4 - COMPLETELY SILENT
# =============================================================================
# This script runs in the background and updates status.json
# ALL output is redirected to prevent pollution of JSON data
# =============================================================================

# Redirect all output to log file - CRITICAL: Prevents output in JSON
exec > /var/log/service-monitor-updater.log 2>&1

DASHBOARD_DIR="/var/www/html/service-monitor"
CONFIG_FILE="/etc/service-monitor/config.conf"

# Function to escape JSON strings
json_escape() {
    echo -n "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/'"$(printf '\n')"'/\\n/g'
}

# Function to get Pi-hole stats
get_pihole_stats() {
    local status="inactive"
    local queries_today=0
    local blocked_today=0

    if command -v pihole &>/dev/null || [[ -f "/usr/local/bin/pihole" ]] || [[ -f "/usr/bin/pihole" ]]; then
        if systemctl is-active --quiet pihole-FTL.service 2>/dev/null; then
            status="active"

            # Try to get query counts from logs
            if [[ -f "/var/log/pihole.log" ]]; then
                queries_today=$(grep -c "query" /var/log/pihole.log 2>/dev/null || echo 0)
                blocked_today=$(grep -c "gravity blocked" /var/log/pihole.log 2>/dev/null || echo 0)
            elif [[ -f "/var/log/pihole/pihole.log" ]]; then
                queries_today=$(grep -c "query" /var/log/pihole/pihole.log 2>/dev/null || echo 0)
                blocked_today=$(grep -c "gravity blocked" /var/log/pihole/pihole.log 2>/dev/null || echo 0)
            fi
        fi
    fi

    echo "{\"status\":\"$status\",\"queries_today\":$queries_today,\"blocked_today\":$blocked_today}"
}

# Function to get service status - SILENT, no output
get_service_status() {
    local service="$1"
    local status="inactive"
    local cpu=0
    local mem=0

    # Get service status
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        status="active"

        # Try to get PID
        local pid=""
        case "$service" in
            "pihole-FTL.service") pid=$(pgrep -f "pihole-FTL" | head -1) ;;
            "unbound.service") pid=$(pgrep -f "unbound" | head -1) ;;
            "dnscrypt-proxy.service") pid=$(pgrep -f "dnscrypt-proxy" | head -1) ;;
            "dnsmasq.service") pid=$(pgrep -f "dnsmasq" | head -1) ;;
            "named.service") pid=$(pgrep -f "named" | head -1) ;;
            *) pid=$(systemctl show -p MainPID "$service" 2>/dev/null | cut -d= -f2) ;;
        esac

        # Get CPU/MEM if PID exists
        if [[ -n "$pid" ]] && [[ "$pid" != "0" ]] && [[ -f "/proc/$pid/stat" ]]; then
            cpu=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ' | cut -d'.' -f1)
            mem=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | tr -d ' ' | cut -d'.' -f1)
            cpu=${cpu:-0}
            mem=${mem:-0}
        fi
    fi

    echo "$status|$cpu|$mem"
}

# Main loop - SILENT operation
while true; do
    # Get system info - SILENT, with defaults
    HOSTNAME=$(hostname 2>/dev/null || echo "localhost")
    UPTIME=$(uptime 2>/dev/null | sed 's/.*up \([^,]*\),.*/\1/' || echo "0")
    LOAD=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs || echo "0.00")
    CPU_CORES=$(nproc 2>/dev/null || echo "1")
    MEMORY=$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}' || echo "0/0")
    DISK=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo "0%")

    # Get Pi-hole stats
    PIHOLE_STATS=$(get_pihole_stats)

    # Check DNS services - SILENT
    DNS_SERVICES=("pihole-FTL.service" "unbound.service" "dnscrypt-proxy.service" "dnsmasq.service" "named.service")
    DNS_JSON=""
    FIRST=1

    for SERVICE in "${DNS_SERVICES[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "$SERVICE" || [[ -f "/etc/systemd/system/$SERVICE" ]]; then
            IFS='|' read -r STATUS CPU MEM <<< "$(get_service_status "$SERVICE")"

            if [[ $FIRST -eq 1 ]]; then
                FIRST=0
            else
                DNS_JSON+=","
            fi

            DNS_JSON+="{\"name\":\"$(json_escape "$SERVICE")\",\"status\":\"$STATUS\",\"cpu\":$CPU,\"mem\":$MEM}"
        fi
    done

    # Get monitored services from config - SILENT
    SERVICES_JSON=""
    FIRST=1

    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ MONITORED_SERVICES=\"(.*)\" ]]; then
                IFS=' ' read -ra SERVICES <<< "${BASH_REMATCH[1]}"
                for SERVICE in "${SERVICES[@]}"; do
                    # Skip DNS services to avoid duplicates
                    [[ " ${DNS_SERVICES[@]} " =~ " $SERVICE " ]] && continue

                    IFS='|' read -r STATUS CPU MEM <<< "$(get_service_status "$SERVICE")"

                    if [[ $FIRST -eq 1 ]]; then
                        FIRST=0
                    else
                        SERVICES_JSON+=","
                    fi

                    SERVICES_JSON+="{\"name\":\"$(json_escape "$SERVICE")\",\"status\":\"$STATUS\",\"cpu\":$CPU,\"mem\":$MEM}"
                done
                break
            fi
        done < "$CONFIG_FILE"
    fi

    # Write JSON - SILENT, no echo to stdout
    cat > "$DASHBOARD_DIR/status.json" << JSON
{
    "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "3.0.4",
    "servers": [
        {
            "id": "local",
            "hostname": "$(json_escape "$HOSTNAME")",
            "uptime": "$(json_escape "$UPTIME")",
            "load": "$(json_escape "$LOAD")",
            "cpu_cores": $CPU_CORES,
            "memory": "$(json_escape "$MEMORY")",
            "disk_usage": "$(json_escape "$DISK")",
            "services": [$SERVICES_JSON],
            "dns_services": [$DNS_JSON]
        }
    ],
    "pihole": $PIHOLE_STATS
}
JSON

    sleep 30
done
EOF

    chmod +x "${DASHBOARD_SCRIPT}"
    print_substep "Dashboard scripts created - SILENT mode with Pi-hole stats"
}

create_dashboard_services() {
    print_substep "Creating dashboard services..."

    cat > "${DASHBOARD_HTTP_SERVICE}" << EOF
[Unit]
Description=Service Monitor HTTP Server v3.0.4
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${DASHBOARD_DIR}
ExecStart=/usr/bin/python3 -m http.server ${DEFAULT_DASHBOARD_PORT} --bind 0.0.0.0
Restart=always
RestartSec=5
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF

    cat > "${DASHBOARD_UPDATER_SERVICE}" << EOF
[Unit]
Description=Service Monitor Dashboard Updater v3.0.4
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=${DASHBOARD_SCRIPT}
Restart=always
RestartSec=5
StandardOutput=null
StandardError=null
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
# Service Load Monitor - Core Script v3.0.4
# =============================================================================

CONFIG_FILE="/etc/service-monitor/config.conf"
LOG_FILE="/var/log/service-monitor.log"

if [[ -f "${CONFIG_FILE}" ]]; then
    source "${CONFIG_FILE}"
fi

CHECK_INTERVAL=${CHECK_INTERVAL:-30}
LOAD_THRESHOLD=${LOAD_THRESHOLD:-5.0}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${LOG_FILE}"
}

log_message "Service Load Monitor v3.0.4 started"

while true; do
    CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/ //g' 2>/dev/null || echo "0")

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

    # Use silent detection for config
    local detected_dns=($(detect_dns_services_silent))
    local dns_list=""
    for service in "${detected_dns[@]}"; do
        [[ -n "$dns_list" ]] && dns_list+=" "
        dns_list+="$service"
    done

    local common_services="ssh.service cron.service"
    local MONITORED="${dns_list} ${common_services}"

    cat > "${CONFIG_FILE}" << EOF
# Service Load Monitor Configuration v3.0.4
CHECK_INTERVAL=30
LOAD_THRESHOLD=5.0
CPU_THRESHOLD=70
IO_WAIT_THRESHOLD=20
MONITORED_SERVICES="${MONITORED}"
ENABLE_DASHBOARD="yes"
DASHBOARD_PORT=8080
LOG_FILE="/var/log/service-monitor.log"
EOF

    print_substep "Configuration file created"
}

# =============================================================================
# MAIN INSTALLATION FUNCTION
# =============================================================================

install_monitor() {
    print_banner

    echo -e "${WHITE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║           INSTALLATION WIZARD - v3.0.4                     ║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local total_steps=9
    local current_step=1

    # Step 1: Check sudo
    print_step $current_step $total_steps "Checking sudo access"
    if ! check_sudo; then
        print_error "This script requires sudo access"
        exit 1
    fi
    print_success "Sudo access verified"
    current_step=$((current_step + 1))

    # Step 2: Detect system
    print_step $current_step $total_steps "Detecting system"
    local distro=$(detect_distro)
    local cloud_info=$(detect_cloud)
    local cloud="${cloud_info%|*}"
    local cloud_details="${cloud_info#*|}"

    echo -e "  Distribution: ${distro}"
    if [[ "${cloud}" != "${CLOUD_NONE}" ]]; then
        echo -e "  Cloud Platform: ${cloud}"
        if [[ -n "${cloud_details}" ]] && [[ ! "${cloud_details}" =~ \<html ]]; then
            echo -e "  Details: ${cloud_details}"
        fi
    fi
    print_success "System detection complete"
    current_step=$((current_step + 1))

    # Step 3: Detect DNS services
    print_step $current_step $total_steps "Detecting DNS services"
    local dns_services=($(detect_dns_services_silent))
    if [[ ${#dns_services[@]} -gt 0 ]]; then
        print_success "Found ${#dns_services[@]} DNS services"
        for service in "${dns_services[@]}"; do
            echo -e "  • ${service}"
        done
    else
        print_info "No DNS services detected"
    fi
    current_step=$((current_step + 1))

    # Step 4: Create directories
    print_step $current_step $total_steps "Creating directories"
    mkdir -p "${CONFIG_BASE_DIR}" "${SNAPSHOT_DIR}" "${PERF_DATA_DIR}" "${DASHBOARD_DIR}" "${BACKUP_DIR}" "$(dirname "${LOG_FILE}")"
    print_success "Directories created"
    current_step=$((current_step + 1))

    # Step 5: Create monitor files
    print_step $current_step $total_steps "Creating monitor files"
    create_monitor_script
    create_config_file
    print_success "Monitor files created"
    current_step=$((current_step + 1))

    # Step 6: Create dashboard
    print_step $current_step $total_steps "Creating web dashboard"
    create_dashboard_files
    create_dashboard_scripts
    create_dashboard_services
    print_success "Dashboard created with Pi-hole stats"
    current_step=$((current_step + 1))

    # Step 7: Create main service
    print_step $current_step $total_steps "Creating main service"
    cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=Service Load Monitor v3.0.4
After=network.target

[Service]
Type=simple
ExecStart=${MONITOR_SCRIPT}
Restart=always
RestartSec=10
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable service-monitor.service &> /dev/null
    systemctl start service-monitor.service &> /dev/null
    print_success "Main service created and started"
    current_step=$((current_step + 1))

    # Step 8: Save version
    print_step $current_step $total_steps "Finalizing installation"
    echo "${SCRIPT_VERSION}" > "${VERSION_FILE}"
    print_success "Installation complete"
    current_step=$((current_step + 1))

    # Step 9: Show summary
    print_step $current_step $total_steps "Installation summary"
    local ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    DASHBOARD ACCESS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Local URL:  ${GREEN}http://localhost:${DEFAULT_DASHBOARD_PORT}/${NC}"
    echo -e "  Network URL: ${GREEN}http://${ip}:${DEFAULT_DASHBOARD_PORT}/${NC}"
    echo ""

    if [[ "${cloud}" != "${CLOUD_NONE}" ]]; then
        echo -e "${YELLOW}Note: If accessing from outside, ensure port ${DEFAULT_DASHBOARD_PORT} is open in ${cloud} firewall${NC}"
        echo ""
    fi

    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}Installation Summary:${NC}"
    echo "  • Version: ${SCRIPT_VERSION}"
    echo -e "  • Monitor Service: ${GREEN}service-monitor.service${NC}"
    echo -e "  • HTTP Server: ${GREEN}service-monitor-http.service${NC}"
    echo -e "  • Updater Service: ${GREEN}service-monitor-updater.service${NC}"
    echo "  • Config: ${CONFIG_FILE}"
    echo "  • Logs: ${LOG_FILE}"
    echo "  • Dashboard: ${DASHBOARD_DIR}"
    echo "  • DNS Services: ${#dns_services[@]}"
    echo "  • Pi-hole Stats: Enabled"
    echo ""
    echo -e "${GREEN}Thank you for using Service Load Monitor v3.0.4!${NC}"
    echo -e "${GREEN}© 2026 Wael Isa - https://www.wael.name${NC}"
    echo ""
}

# =============================================================================
# REMOVAL FUNCTION
# =============================================================================

remove_monitor() {
    print_banner
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              REMOVAL WIZARD - v3.0.4                       ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if ! check_sudo; then
        print_error "This operation requires sudo access"
        exit 1
    fi

    echo -e "${RED}WARNING: This will remove Service Load Monitor${NC}"
    echo -e "${YELLOW}Are you sure? (y/N)${NC}"
    read -p "> " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        print_info "Removal cancelled"
        return
    fi

    echo ""
    echo -e "${YELLOW}Remove configuration and data? (y/N)${NC}"
    read -p "> " remove_data

    print_info "Stopping services..."
    systemctl stop service-monitor.service 2>/dev/null
    systemctl stop service-monitor-http.service 2>/dev/null
    systemctl stop service-monitor-updater.service 2>/dev/null

    print_info "Disabling services..."
    systemctl disable service-monitor.service 2>/dev/null
    systemctl disable service-monitor-http.service 2>/dev/null
    systemctl disable service-monitor-updater.service 2>/dev/null

    print_info "Removing files..."
    rm -f "${MONITOR_SCRIPT}" "${SERVICE_FILE}" "${DASHBOARD_SCRIPT}"
    rm -f "${DASHBOARD_HTTP_SERVICE}" "${DASHBOARD_UPDATER_SERVICE}"
    rm -f "${LOGROTATE_FILE}" "${VERSION_FILE}"

    if [[ "${remove_data}" =~ ^[Yy]$ ]]; then
        rm -rf "${CONFIG_BASE_DIR}" "${LIB_BASE_DIR}" "${DASHBOARD_DIR}"
        rm -f "${LOG_FILE}"*
        print_info "Configuration and data removed"
    else
        print_info "Configuration kept at: ${CONFIG_BASE_DIR}"
    fi

    systemctl daemon-reload
    print_success "Removal complete"
}

# =============================================================================
# STATUS FUNCTION
# =============================================================================

show_status() {
    print_banner
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    SYSTEM STATUS - v3.0.4${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # System info
    echo -e "${WHITE}System Information:${NC}"
    echo "  • Distribution: $(detect_distro)"

    local cloud_info=$(detect_cloud)
    local cloud="${cloud_info%|*}"
    if [[ "${cloud}" != "${CLOUD_NONE}" ]]; then
        echo "  • Cloud Platform: ${cloud}"
    fi
    echo "  • Hostname: $(hostname 2>/dev/null || echo "unknown")"
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

    # Pi-hole info
    if command -v pihole &>/dev/null || [[ -f "/usr/local/bin/pihole" ]] || [[ -f "/usr/bin/pihole" ]]; then
        echo ""
        echo -e "${WHITE}Pi-hole Information:${NC}"
        if systemctl is-active --quiet pihole-FTL.service 2>/dev/null; then
            echo -e "  • ${GREEN}●${NC} Pi-hole FTL: Running"
        else
            echo -e "  • ${RED}○${NC} Pi-hole FTL: Stopped"
        fi
    fi

    # Version info
    echo ""
    echo -e "${WHITE}Version Information:${NC}"
    if [[ -f "${VERSION_FILE}" ]]; then
        echo "  • Installed: $(cat "${VERSION_FILE}")"
    fi
    echo "  • Script: ${SCRIPT_VERSION}"

    # Dashboard URL
    echo ""
    echo -e "${WHITE}Dashboard URL:${NC}"
    local ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
    echo "  • http://${ip}:${DEFAULT_DASHBOARD_PORT}/"
}

# =============================================================================
# LOG FUNCTION
# =============================================================================

show_logs() {
    if [[ -f "${LOG_FILE}" ]]; then
        tail -f "${LOG_FILE}"
    else
        print_error "Log file not found: ${LOG_FILE}"
    fi
}

# =============================================================================
# BANNER FUNCTION
# =============================================================================

print_banner() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}           SERVICE LOAD MONITOR v3.0.4                   ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${GREEN}  Author:  Wael Isa                                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Version: 3.0.4 (SILENT Mode + Pi-hole Stats)          ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Date:    February 18, 2026                             ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Website: https://www.wael.name                         ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# =============================================================================
# FEATURES FUNCTION
# =============================================================================

show_features() {
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}               FEATURE HIGHLIGHTS v3.0.4${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}🛡️  Pi-hole Integration${NC}"
    echo "  • Real-time query statistics"
    echo "  • Blocked domains counter"
    echo "  • Block percentage calculation"
    echo "  • FTL service status"
    echo ""
    echo -e "${GREEN}🌐 DNS Service Integration${NC}"
    echo "  • Unbound"
    echo "  • DNSCrypt-Proxy"
    echo "  • dnsmasq"
    echo "  • BIND9"
    echo ""
    echo -e "${GREEN}📊 SILENT Dashboard${NC}"
    echo "  • No ANSI codes in JSON"
    echo "  • No installation messages"
    echo "  • Clean service display"
    echo "  • Real CPU/MEM usage"
    echo ""
}

# =============================================================================
# HELP FUNCTION
# =============================================================================

show_help() {
    echo "Service Load Monitor v3.0.4"
    echo ""
    echo "Commands:"
    echo "  install     - Install or update"
    echo "  remove      - Remove the monitor"
    echo "  status      - Show service status"
    echo "  logs        - Follow log output"
    echo "  backup      - Create a backup"
    echo "  restore     - Restore from backup"
    echo "  version     - Show version"
    echo "  features    - Show features"
    echo "  help        - Show this help"
    echo ""
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

    echo "${SCRIPT_VERSION}" > "${backup_path}/version.txt"
    date > "${backup_path}/backup_date.txt"

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

    systemctl daemon-reload

    print_success "Restore completed"
}

# =============================================================================
# VERSION COMPARE FUNCTION
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

    echo "${installed_version}|${has_old_files}"
}

migrate_configuration() {
    print_info "Migrating existing configuration..."
    local backup_id=$(backup_existing "pre-migration")
    print_substep "Pre-migration backup created: ${backup_id}"
    echo "${SCRIPT_VERSION}" > "${VERSION_FILE}"
    print_success "Migration completed"
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_menu() {
    print_banner
    echo -e "${WHITE}Main Menu:${NC}"
    echo ""
    echo "  1) Install/Update Monitor (v3.0.4)"
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
                ;;
            features)
                show_features
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
                    ls -1 "${BACKUP_DIR}" 2>/dev/null || echo "No backups found"
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
                echo -e "\n${GREEN}Thank you for using Service Load Monitor v3.0.4!${NC}"
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
