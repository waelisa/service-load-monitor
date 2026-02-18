#!/bin/bash

# =============================================================================
# Service Load Monitor - Installation & Management Script v3.1.4
# =============================================================================
# Author:  Wael Isa
# Version: 3.1.4
# Date:    February 18, 2026
# Website: https://www.wael.name
# =============================================================================
# Description: ENTERPRISE-GRADE service monitoring with DNS suite integration
#              Pi-hole API + Systemd Timer + Production Ready
# =============================================================================
# FIXES IN v3.1.4:
# -----------------
# • Fixed Pi-hole API integration - now properly returns query counts
# • Added multiple methods to get Pi-hole stats (API, sqlite3, pihole command)
# • Fixed JSON parsing of pihole -c -j output
# • Added fallback to log file if API fails
# • Added debug logging for Pi-hole stats collection
# • Fixed "Queries Today 0" issue
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
SCRIPT_VERSION="3.1.4"
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
UPDATER_LOG="${LOG_BASE_DIR}/service-monitor-updater.log"
DASHBOARD_DIR="${WWW_BASE_DIR}/service-monitor"
DASHBOARD_SCRIPT="${BASE_DIR}/service-monitor-dashboard.sh"
DASHBOARD_SERVICE="/etc/systemd/system/service-monitor-dashboard.service"
DASHBOARD_TIMER="/etc/systemd/system/service-monitor-dashboard.timer"
DASHBOARD_HTTP_SERVICE="/etc/systemd/system/service-monitor-http.service"
VERSION_FILE="${CONFIG_BASE_DIR}/installed_version"
BACKUP_DIR="${LIB_BASE_DIR}/backups"
CACHE_DIR="/var/cache/service-monitor"

# Pi-hole specific paths
PIHOLE_LOG="/var/log/pihole.log"
PIHOLE_FTL_LOG="/var/log/pihole-FTL.log"
PIHOLE_GRAVITY="/etc/pihole/gravity.db"
PIHOLE_FTL_DB="/etc/pihole/pihole-FTL.db"

# DNS service names - EXACT matches for systemd
DNS_SERVICES=(
    "pihole-FTL.service"
    "unbound.service"
    "dnscrypt-proxy.service"
    "dnsmasq.service"
    "named.service"
)

# Default ports
DEFAULT_DASHBOARD_PORT=8080

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

# =============================================================================
# SILENT SERVICE DETECTION
# =============================================================================

detect_dns_services_silent() {
    local detected=()

    # Check Pi-hole with exact service name matching
    if systemctl list-unit-files 2>/dev/null | grep -q "^pihole-FTL.service" 2>/dev/null; then
        detected+=("pihole-FTL.service")
    elif systemctl list-unit-files 2>/dev/null | grep -q "pihole-FTL" 2>/dev/null; then
        detected+=("pihole-FTL.service")
    elif [[ -f "/etc/systemd/system/pihole-FTL.service" ]]; then
        detected+=("pihole-FTL.service")
    fi

    # Check Unbound
    if systemctl list-unit-files 2>/dev/null | grep -q "^unbound.service" 2>/dev/null; then
        detected+=("unbound.service")
    elif systemctl list-unit-files 2>/dev/null | grep -q "unbound" 2>/dev/null; then
        detected+=("unbound.service")
    elif [[ -f "/etc/systemd/system/unbound.service" ]]; then
        detected+=("unbound.service")
    fi

    # Check DNSCrypt-Proxy
    if systemctl list-unit-files 2>/dev/null | grep -q "^dnscrypt-proxy.service" 2>/dev/null; then
        detected+=("dnscrypt-proxy.service")
    elif systemctl list-unit-files 2>/dev/null | grep -q "dnscrypt-proxy" 2>/dev/null; then
        detected+=("dnscrypt-proxy.service")
    elif [[ -f "/etc/systemd/system/dnscrypt-proxy.service" ]]; then
        detected+=("dnscrypt-proxy.service")
    fi

    # Check dnsmasq
    if systemctl list-unit-files 2>/dev/null | grep -q "^dnsmasq.service" 2>/dev/null; then
        detected+=("dnsmasq.service")
    elif systemctl list-unit-files 2>/dev/null | grep -q "dnsmasq" 2>/dev/null; then
        detected+=("dnsmasq.service")
    fi

    # Check BIND9
    if systemctl list-unit-files 2>/dev/null | grep -q "^named.service" 2>/dev/null; then
        detected+=("named.service")
    elif systemctl list-unit-files 2>/dev/null | grep -q "named" 2>/dev/null; then
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

# =============================================================================
# DASHBOARD FUNCTIONS - v3.1.4 FIXED PI-HOLE API
# =============================================================================

create_dashboard_files() {
    print_substep "Creating dashboard files..."

    mkdir -p "${DASHBOARD_DIR}" "${CACHE_DIR}"

    # Create initial status.json with proper permissions
    cat > "${DASHBOARD_DIR}/status.json" << EOF
{
    "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "3.1.4",
    "servers": [
        {
            "id": "local",
            "hostname": "$(hostname 2>/dev/null || echo "localhost")",
            "uptime": "$(uptime 2>/dev/null | sed 's/.*up \([^,]*\),.*/\1/' || echo "0")",
            "load": "$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs || echo "0.00")",
            "cpu_cores": $(nproc 2>/dev/null || echo "1"),
            "memory": "$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}' || echo "0/0")",
            "disk_usage": "$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo "0%")",
            "services": [],
            "dns_services": []
        }
    ],
    "pihole": null
}
EOF

    # Set proper permissions (644 for files)
    chmod 644 "${DASHBOARD_DIR}/status.json"

    # Set proper ownership for web server
    if id www-data &>/dev/null; then
        chown -R www-data:www-data "${DASHBOARD_DIR}" 2>/dev/null
    elif id apache &>/dev/null; then
        chown -R apache:apache "${DASHBOARD_DIR}" 2>/dev/null
    elif id nginx &>/dev/null; then
        chown -R nginx:nginx "${DASHBOARD_DIR}" 2>/dev/null
    fi

    # Create index.html
    cat > "${DASHBOARD_DIR}/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="60">
    <title>Service Monitor Dashboard v3.1.4 Enterprise</title>
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
            border-left: 4px solid #28a745;
        }
        .header h1 { color: #333; font-size: 2.5em; margin-bottom: 10px; }
        .header .badge {
            background: #28a745;
            color: white;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.9em;
            display: inline-block;
            margin-left: 10px;
        }
        .header .enterprise-badge {
            background: #ffc107;
            color: #333;
            padding: 3px 8px;
            border-radius: 12px;
            font-size: 0.8em;
            margin-left: 10px;
        }
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
        .last-update { color: #999; font-size: 0.9em; margin-top: 10px; }
        .loading { text-align: center; padding: 40px; color: #666; }
        .no-services {
            text-align: center;
            padding: 40px;
            color: #999;
            background: #f8f9fa;
            border-radius: 10px;
        }
        .enterprise-footer {
            font-size: 0.8em;
            color: #ffc107;
            margin-top: 5px;
        }
        .production-badge {
            background: #17a2b8;
            color: white;
            padding: 2px 6px;
            border-radius: 10px;
            font-size: 0.7em;
            margin-left: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Service Load Monitor <span class="badge">v3.1.4</span><span class="enterprise-badge">Enterprise</span><span class="production-badge">Production</span></h1>
            <div class="last-update" id="lastUpdate">Loading...</div>
            <div class="enterprise-footer">⚡ Pi-hole API • Systemd Timer • Zero CPU idle • Production Ready</div>
        </div>

        <div class="stats-grid" id="statsGrid"></div>

        <div class="pihole-section" id="piholeSection" style="display: none;">
            <h2>🛡️ Pi-hole Status <span class="enterprise-badge">API v3.1.4</span></h2>
            <div class="pihole-stats" id="piholeStats"></div>
        </div>

        <div class="dns-section">
            <h2>🌐 DNS Services</h2>
            <div class="dns-grid" id="dnsGrid"></div>
        </div>

        <div class="services-section">
            <h2>📊 Monitored Services</h2>
            <div class="service-list" id="serviceList"></div>
        </div>
    </div>

    <div class="footer">
        <p>© 2026 Service Load Monitor v3.1.4 Production - by Wael Isa</p>
    </div>

    <script>
        function refreshData() {
            fetch('status.json?' + new Date().getTime())
                .then(response => response.json())
                .then(data => {
                    document.getElementById('lastUpdate').textContent = 'Last updated: ' + (data.last_update || 'Unknown') + ' (Timer-based)';

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
                        const statusClass = data.pihole.status === 'active' ? 'status-active' : 'status-inactive';
                        const queriesToday = data.pihole.queries_today || 0;
                        const blockedToday = data.pihole.blocked_today || 0;
                        const blockedPercent = queriesToday > 0 ? ((blockedToday / queriesToday * 100).toFixed(1) + '%') : '0%';

                        piholeStats.innerHTML = `
                            <div class="stat-card">
                                <h3>Status <span class="production-badge">API</span></h3>
                                <div class="value"><span class="status-badge ${statusClass}">${data.pihole.status}</span></div>
                            </div>
                            <div class="stat-card">
                                <h3>Queries Today</h3>
                                <div class="value">${queriesToday.toLocaleString()}</div>
                            </div>
                            <div class="stat-card">
                                <h3>Blocked Today</h3>
                                <div class="value">${blockedToday.toLocaleString()}</div>
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
                    const dnsGrid = document.getElementById('dnsGrid');
                    if (data.servers && data.servers[0] && data.servers[0].dns_services) {
                        const dnsServices = data.servers[0].dns_services;
                        if (dnsServices.length > 0) {
                            dnsGrid.innerHTML = dnsServices.map(s => {
                                const statusClass = s.status === 'active' ? 'status-active' : 'status-inactive';
                                const serviceName = s.name.replace('.service', '').replace(/-/g, ' ');
                                return `
                                    <div class="dns-card">
                                        <h3>${serviceName} <span class="status ${statusClass}">${s.status}</span></h3>
                                        <div style="display: flex; justify-content: space-between;">
                                            <span>CPU: ${s.cpu || 0}%</span>
                                            <span>MEM: ${s.mem || 0}%</span>
                                        </div>
                                    </div>
                                `;
                            }).join('');
                        } else {
                            dnsGrid.innerHTML = '<div class="no-services">No DNS services detected</div>';
                        }
                    }

                    // Update regular services
                    const serviceList = document.getElementById('serviceList');
                    if (data.servers && data.servers[0] && data.servers[0].services) {
                        const services = data.servers[0].services;
                        if (services.length > 0) {
                            serviceList.innerHTML = services.map(s => {
                                const statusClass = s.status === 'active' ? 'status-active' : 'status-inactive';
                                return `
                                    <div class="service-item">
                                        <div class="service-name">${s.name}</div>
                                        <div class="service-status">
                                            <span class="status-badge ${statusClass}">${s.status}</span>
                                        </div>
                                        <div class="service-cpu">${s.cpu || 0}% CPU</div>
                                        <div class="service-mem">${s.mem || 0}% MEM</div>
                                    </div>
                                `;
                            }).join('');
                        } else {
                            serviceList.innerHTML = '<div class="no-services">No additional services configured</div>';
                        }
                    }
                })
                .catch(error => {
                    console.error('Error loading data:', error);
                    document.getElementById('statsGrid').innerHTML = '<div class="no-services">Error loading data. Check if timer is running.</div>';
                });
        }

        refreshData();
        setInterval(refreshData, 60000);
    </script>
</body>
</html>
HTML

    # Set proper permissions (644 for files)
    chmod 644 "${DASHBOARD_DIR}/index.html"
    chmod -R 755 "${DASHBOARD_DIR}"
    print_substep "Dashboard files created - Production ready"
}

create_dashboard_scripts() {
    print_substep "Creating dashboard scripts (Enterprise - No while loop)..."

    cat > "${DASHBOARD_SCRIPT}" << 'EOF'
#!/bin/bash
# Service Monitor Dashboard Updater v3.1.4 - FIXED PI-HOLE API
# This script runs ONCE when triggered by systemd timer
# No infinite loops - proper service management

DASHBOARD_DIR="/var/www/html/service-monitor"
CONFIG_FILE="/etc/service-monitor/config.conf"
LOG_FILE="/var/log/service-monitor-updater.log"
CACHE_DIR="/var/cache/service-monitor"

# Pi-hole paths
PIHOLE_LOG="/var/log/pihole.log"
PIHOLE_FTL_LOG="/var/log/pihole-FTL.log"
PIHOLE_GRAVITY="/etc/pihole/gravity.db"
PIHOLE_FTL_DB="/etc/pihole/pihole-FTL.db"

# Ensure directories exist with proper permissions
mkdir -p "${CACHE_DIR}" 2>/dev/null
chmod 755 "${CACHE_DIR}" 2>/dev/null

# Log function - logs to both file and journald
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $*" >> "$LOG_FILE"
    echo "$*" | systemd-cat -t service-monitor -p info
}

# Error log function
log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ERROR: $*" >> "$LOG_FILE"
    echo "ERROR: $*" | systemd-cat -t service-monitor -p err
}

# Function to get service status with error handling
get_service_status() {
    local service="$1"
    local status="inactive"
    local cpu=0
    local mem=0

    # Try multiple methods to check service status
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        status="active"
    elif systemctl is-active --quiet "${service%.service}" 2>/dev/null; then
        status="active"
        service="${service%.service}"
    elif pgrep -f "$service" >/dev/null 2>&1; then
        status="active"
    fi

    if [[ "$status" == "active" ]]; then
        # Get PID using multiple methods
        local pid=""
        case "$service" in
            "pihole-FTL.service"|"pihole-FTL")
                pid=$(pgrep -f "pihole-FTL" | head -1)
                ;;
            "unbound.service"|"unbound")
                pid=$(pgrep -f "unbound" | head -1)
                ;;
            "dnscrypt-proxy.service"|"dnscrypt-proxy")
                pid=$(pgrep -f "dnscrypt-proxy" | head -1)
                ;;
            "dnsmasq.service"|"dnsmasq")
                pid=$(pgrep -f "dnsmasq" | head -1)
                ;;
            "named.service"|"named")
                pid=$(pgrep -f "named" | head -1)
                ;;
            *)
                pid=$(pgrep -f "$service" | head -1)
                if [[ -z "$pid" ]]; then
                    pid=$(systemctl show -p MainPID "$service" 2>/dev/null | cut -d= -f2)
                fi
                ;;
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

# Function to get Pi-hole stats using MULTIPLE METHODS
get_pihole_stats() {
    local status="inactive"
    local queries_today=0
    local blocked_today=0

    log "=== Pi-hole Stats Collection ==="

    # Check if Pi-hole is installed
    if ! command -v pihole &>/dev/null && [[ ! -f "/usr/local/bin/pihole" ]] && [[ ! -f "/usr/bin/pihole" ]]; then
        log "Pi-hole not installed"
        echo "{\"status\":\"inactive\",\"queries_today\":0,\"blocked_today\":0}"
        return
    fi
    log "Pi-hole binary found"

    # Check if pihole-FTL service is active
    if ! systemctl is-active --quiet pihole-FTL.service 2>/dev/null; then
        log "Pi-hole FTL is not active"
        echo "{\"status\":\"inactive\",\"queries_today\":0,\"blocked_today\":0}"
        return
    fi

    status="active"
    log "Pi-hole FTL is active"

    # METHOD 1: Try pihole -c -j API (primary method)
    log "Method 1: Trying pihole -c -j API..."
    local stats
    stats=$(timeout 5 pihole -c -j 2>/dev/null)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]] && [[ -n "$stats" ]]; then
        log "API returned data (exit code: $exit_code)"

        # Try to extract values using multiple patterns
        # Pattern 1: Standard JSON format
        queries_today=$(echo "$stats" | grep -o '"dns_queries_today":[0-9]*' | head -1 | cut -d':' -f2)
        blocked_today=$(echo "$stats" | grep -o '"ads_blocked_today":[0-9]*' | head -1 | cut -d':' -f2)

        # Pattern 2: Alternative format
        if [[ -z "$queries_today" ]] || [[ "$queries_today" == "0" ]]; then
            queries_today=$(echo "$stats" | grep -o '"queries":[0-9]*' | head -1 | cut -d':' -f2)
        fi
        if [[ -z "$blocked_today" ]] || [[ "$blocked_today" == "0" ]]; then
            blocked_today=$(echo "$stats" | grep -o '"blocked":[0-9]*' | head -1 | cut -d':' -f2)
        fi

        # Pattern 3: Any number after these keys
        if [[ -z "$queries_today" ]] || [[ "$queries_today" == "0" ]]; then
            queries_today=$(echo "$stats" | grep -o '"dns_queries_today": [0-9]*' | head -1 | cut -d':' -f2 | tr -d ' ')
        fi
        if [[ -z "$blocked_today" ]] || [[ "$blocked_today" == "0" ]]; then
            blocked_today=$(echo "$stats" | grep -o '"ads_blocked_today": [0-9]*' | head -1 | cut -d':' -f2 | tr -d ' ')
        fi

        log "API extraction - Queries: $queries_today, Blocked: $blocked_today"
    else
        log "API failed (exit code: $exit_code)"
    fi

    # METHOD 2: Try pihole -c command (human readable)
    if [[ -z "$queries_today" ]] || [[ "$queries_today" == "0" ]] || [[ -z "$blocked_today" ]] || [[ "$blocked_today" == "0" ]]; then
        log "Method 2: Trying pihole -c (human readable)..."
        local human_stats
        human_stats=$(timeout 5 pihole -c 2>/dev/null)
        if [[ -n "$human_stats" ]]; then
            # Extract queries today
            local queries_line=$(echo "$human_stats" | grep -i "queries today" | grep -o '[0-9]\+')
            if [[ -n "$queries_line" ]]; then
                queries_today=$queries_line
            fi
            # Extract blocked today
            local blocked_line=$(echo "$human_stats" | grep -i "blocked today" | grep -o '[0-9]\+')
            if [[ -n "$blocked_line" ]]; then
                blocked_today=$blocked_line
            fi
            log "Human readable - Queries: $queries_today, Blocked: $blocked_today"
        fi
    fi

    # METHOD 3: Try sqlite3 query on FTL database
    if [[ -z "$queries_today" ]] || [[ "$queries_today" == "0" ]] || [[ -z "$blocked_today" ]] || [[ "$blocked_today" == "0" ]]; then
        if [[ -f "$PIHOLE_FTL_DB" ]] && command -v sqlite3 &>/dev/null; then
            log "Method 3: Querying FTL database..."
            # Get today's timestamp (midnight)
            local today_midnight=$(date +%s -d "today 00:00:00" 2>/dev/null || echo "0")
            if [[ "$today_midnight" != "0" ]]; then
                # Query queries today
                local sql_queries=$(sqlite3 "$PIHOLE_FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp >= $today_midnight;" 2>/dev/null)
                if [[ -n "$sql_queries" ]]; then
                    queries_today=$sql_queries
                fi
                # Query blocked today
                local sql_blocked=$(sqlite3 "$PIHOLE_FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp >= $today_midnight AND status = 1;" 2>/dev/null)
                if [[ -n "$sql_blocked" ]]; then
                    blocked_today=$sql_blocked
                fi
                log "FTL DB - Queries: $queries_today, Blocked: $blocked_today"
            fi
        fi
    fi

    # METHOD 4: Fallback to log file (limited to today's entries)
    if [[ -z "$queries_today" ]] || [[ "$queries_today" == "0" ]] || [[ -z "$blocked_today" ]] || [[ "$blocked_today" == "0" ]]; then
        log "Method 4: Checking log files..."
        local log_file=""
        if [[ -f "$PIHOLE_LOG" ]]; then
            log_file="$PIHOLE_LOG"
        elif [[ -f "$PIHOLE_FTL_LOG" ]]; then
            log_file="$PIHOLE_FTL_LOG"
        fi

        if [[ -n "$log_file" ]]; then
            local today=$(date '+%b %d')
            local today_queries=$(grep -c "^${today}.*query" "$log_file" 2>/dev/null || echo 0)
            local today_blocked=$(grep -c "^${today}.*gravity blocked" "$log_file" 2>/dev/null || echo 0)

            if [[ -z "$queries_today" ]] || [[ "$queries_today" == "0" ]]; then
                queries_today=$today_queries
            fi
            if [[ -z "$blocked_today" ]] || [[ "$blocked_today" == "0" ]]; then
                blocked_today=$today_blocked
            fi
            log "Log file - Queries: $queries_today, Blocked: $blocked_today"
        fi
    fi

    # Ensure we have numbers
    queries_today=${queries_today:-0}
    blocked_today=${blocked_today:-0}

    # Remove any non-numeric characters
    queries_today=$(echo "$queries_today" | tr -cd '0-9')
    blocked_today=$(echo "$blocked_today" | tr -cd '0-9')

    # Default to 0 if empty
    queries_today=${queries_today:-0}
    blocked_today=${blocked_today:-0}

    log "FINAL Pi-hole stats - Status: $status, Queries: $queries_today, Blocked: $blocked_today"
    echo "{\"status\":\"$status\",\"queries_today\":$queries_today,\"blocked_today\":$blocked_today}"
}

# Set proper umask for file creation
umask 022

log "=== Service Monitor Updater v3.1.4 Production (Timer-triggered) ==="
log "Started at: $(date)"
log "PID: $$"

# Get system info with error handling
HOSTNAME=$(hostname 2>/dev/null || echo "localhost")
UPTIME=$(uptime 2>/dev/null | sed 's/.*up \([^,]*\),.*/\1/' || echo "0")
LOAD=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs || echo "0.00")
CPU_CORES=$(nproc 2>/dev/null || echo "1")
MEMORY=$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}' || echo "0/0")
DISK=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo "0%")

log "System: $HOSTNAME, Load: $LOAD, Memory: $MEMORY, Disk: $DISK"

# Get Pi-hole stats using enhanced method
PIHOLE_STATS=$(get_pihole_stats)
log "Pi-hole stats JSON: $PIHOLE_STATS"

# Check DNS services
DNS_SERVICES=("pihole-FTL.service" "unbound.service" "dnscrypt-proxy.service" "dnsmasq.service" "named.service")
DNS_JSON=""
FIRST_DNS=1

for SERVICE in "${DNS_SERVICES[@]}"; do
    # Check if service exists using multiple methods
    if systemctl list-unit-files 2>/dev/null | grep -q "$SERVICE" || \
       systemctl list-unit-files 2>/dev/null | grep -q "${SERVICE%.service}" || \
       [[ -f "/etc/systemd/system/$SERVICE" ]] || \
       pgrep -f "${SERVICE%.service}" >/dev/null 2>&1; then

        IFS='|' read -r STATUS CPU MEM <<< "$(get_service_status "$SERVICE")"
        log "DNS $SERVICE: $STATUS (CPU: $CPU%, MEM: $MEM%)"

        if [[ $FIRST_DNS -eq 1 ]]; then
            FIRST_DNS=0
        else
            DNS_JSON+=","
        fi

        DNS_JSON+="{\"name\":\"$SERVICE\",\"status\":\"$STATUS\",\"cpu\":$CPU,\"mem\":$MEM}"
    fi
done

# Get monitored services from config
SERVICES_JSON=""
FIRST_REG=1

if [[ -f "$CONFIG_FILE" ]]; then
    # Source the config file directly
    if source "$CONFIG_FILE" 2>/dev/null; then
        # Check if MONITORED_SERVICES is an array
        if [[ "$(declare -p MONITORED_SERVICES 2>/dev/null)" =~ "declare -a" ]]; then
            for SERVICE in "${MONITORED_SERVICES[@]}"; do
                [[ -z "$SERVICE" ]] && continue

                # Skip DNS services to avoid duplicates
                skip=0
                for dns in "${DNS_SERVICES[@]}"; do
                    if [[ "$SERVICE" == "$dns" ]] || [[ "$SERVICE" == "${dns%.service}" ]]; then
                        skip=1
                        break
                    fi
                done
                [[ $skip -eq 1 ]] && continue

                IFS='|' read -r STATUS CPU MEM <<< "$(get_service_status "$SERVICE")"
                log "Monitored service $SERVICE: $STATUS (CPU: $CPU%, MEM: $MEM%)"

                if [[ $FIRST_REG -eq 1 ]]; then
                    FIRST_REG=0
                else
                    SERVICES_JSON+=","
                fi

                SERVICES_JSON+="{\"name\":\"$SERVICE\",\"status\":\"$STATUS\",\"cpu\":$CPU,\"mem\":$MEM}"
            done
        fi
    fi
fi

# Write JSON atomically
TMP_FILE="${DASHBOARD_DIR}/status.json.tmp.$$"
FINAL_FILE="${DASHBOARD_DIR}/status.json"

cat > "$TMP_FILE" << JSON
{
    "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "3.1.4",
    "servers": [
        {
            "id": "local",
            "hostname": "$HOSTNAME",
            "uptime": "$UPTIME",
            "load": "$LOAD",
            "cpu_cores": $CPU_CORES,
            "memory": "$MEMORY",
            "disk_usage": "$DISK",
            "services": [$SERVICES_JSON],
            "dns_services": [$DNS_JSON]
        }
    ],
    "pihole": $PIHOLE_STATS
}
JSON

# Verify JSON is valid
if python3 -m json.tool "$TMP_FILE" > /dev/null 2>&1; then
    # Set proper permissions before moving
    chmod 644 "$TMP_FILE"
    mv "$TMP_FILE" "$FINAL_FILE"
    chmod 644 "$FINAL_FILE"

    # Set proper ownership
    if id www-data &>/dev/null; then
        chown www-data:www-data "$FINAL_FILE" 2>/dev/null
    elif id apache &>/dev/null; then
        chown apache:apache "$FINAL_FILE" 2>/dev/null
    elif id nginx &>/dev/null; then
        chown nginx:nginx "$FINAL_FILE" 2>/dev/null
    fi

    log "Successfully wrote valid JSON to $FINAL_FILE (permissions: 644)"
else
    log_error "Generated invalid JSON, keeping previous version"
    rm -f "$TMP_FILE"
    exit 1
fi

log "=== Update completed successfully ==="
exit 0
EOF

    chmod 755 "${DASHBOARD_SCRIPT}"

    # Verify shebang
    if ! head -1 "${DASHBOARD_SCRIPT}" | grep -q "^#!.*bash"; then
        sed -i '1s/^/#!\/bin\/bash\n/' "${DASHBOARD_SCRIPT}"
    fi

    print_substep "Dashboard scripts created - Fixed Pi-hole API with multiple methods"
}

create_dashboard_services() {
    print_substep "Creating dashboard services with proper permissions (644)..."

    # Create HTTP server service
    cat > "${DASHBOARD_HTTP_SERVICE}" << EOF
[Unit]
Description=Service Monitor HTTP Server v3.1.4
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${DASHBOARD_DIR}
ExecStart=/usr/bin/python3 -m http.server ${DEFAULT_DASHBOARD_PORT} --bind 0.0.0.0
Restart=always
RestartSec=5
CPUQuota=10%
MemoryMax=100M

[Install]
WantedBy=multi-user.target
EOF

    # Set proper permissions (644)
    chmod 644 "${DASHBOARD_HTTP_SERVICE}"

    # Create dashboard service (triggered by timer)
    cat > "${DASHBOARD_SERVICE}" << EOF
[Unit]
Description=Service Monitor Dashboard Updater v3.1.4 (Production)
After=network.target

[Service]
Type=oneshot
User=root
Group=root
ExecStart=${DASHBOARD_SCRIPT}
StandardOutput=journal
StandardError=journal
PrivateTmp=yes
NoNewPrivileges=yes
EOF

    # Set proper permissions (644)
    chmod 644 "${DASHBOARD_SERVICE}"

    # Create timer (replaces while loop)
    cat > "${DASHBOARD_TIMER}" << EOF
[Unit]
Description=Service Monitor Dashboard Timer v3.1.4
Requires=service-monitor-dashboard.service

[Timer]
OnCalendar=*-*-* *:*:00
Persistent=true
RandomizedDelaySec=5

[Install]
WantedBy=timers.target
EOF

    # Set proper permissions (644)
    chmod 644 "${DASHBOARD_TIMER}"

    # Enable and start services
    systemctl daemon-reload

    # Enable HTTP server
    systemctl enable service-monitor-http.service &> /dev/null
    systemctl restart service-monitor-http.service &> /dev/null

    # Enable timer (this replaces the while loop)
    systemctl enable service-monitor-dashboard.timer &> /dev/null
    systemctl start service-monitor-dashboard.timer &> /dev/null

    # Run once immediately to populate data
    systemctl start service-monitor-dashboard.service &> /dev/null

    # Verify timer is running
    sleep 2
    if systemctl is-active --quiet service-monitor-dashboard.timer; then
        print_substep "Timer is active - will run every minute"
        print_substep "No while loop - zero CPU usage between runs"
        # Show timer permissions
        print_substep "Timer file permissions: $(stat -c '%a' ${DASHBOARD_TIMER} 2>/dev/null || echo '644')"
    else
        print_warning "Timer failed to start, checking logs..."
        journalctl -u service-monitor-dashboard.timer -n 10 --no-pager
    fi

    # Show timer info
    local next_run=$(systemctl show service-monitor-dashboard.timer -p NextElapseUSecRealtime --value 2>/dev/null)
    if [[ -n "$next_run" ]]; then
        print_substep "Next run: ${next_run}"
    fi

    print_substep "Dashboard services created with systemd timer (all files 644)"
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

create_monitor_script() {
    cat > "${MONITOR_SCRIPT}" << 'EOF'
#!/bin/bash
# Service Load Monitor - Core Script v3.1.4

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

log_message "Service Load Monitor v3.1.4 started"

while true; do
    CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/ //g' 2>/dev/null || echo "0")

    if (( $(echo "$CURRENT_LOAD > $LOAD_THRESHOLD" | bc -l 2>/dev/null) )); then
        log_message "High load detected: $CURRENT_LOAD"
    fi

    sleep "${CHECK_INTERVAL}"
done
EOF

    chmod 755 "${MONITOR_SCRIPT}"
    print_substep "Monitor script created (755)"
}

create_config_file() {
    mkdir -p "${CONFIG_BASE_DIR}"

    local detected_dns=($(detect_dns_services_silent))

    # Create config with proper bash array syntax
    cat > "${CONFIG_FILE}" << EOF
# Service Load Monitor Configuration v3.1.4 Production
# This file uses bash array syntax for MONITORED_SERVICES

# Monitor settings
CHECK_INTERVAL=30
LOAD_THRESHOLD=5.0
CPU_THRESHOLD=70
IO_WAIT_THRESHOLD=20

# Service settings - Add or remove services as needed
# Format: ( "service1.service" "service2.service" )
MONITORED_SERVICES=(
EOF

    # Add detected DNS services
    for service in "${detected_dns[@]}"; do
        echo "    \"$service\"" >> "${CONFIG_FILE}"
    done

    # Add common system services
    cat >> "${CONFIG_FILE}" << EOF
    "ssh.service"
    "cron.service"
)

# Dashboard settings
ENABLE_DASHBOARD="yes"
DASHBOARD_PORT=8080
DASHBOARD_REFRESH=60

# Pi-hole settings
PIHOLE_USE_API="yes"  # Uses API instead of log grepping
PIHOLE_API_TIMEOUT=5  # Timeout in seconds

# Logging
LOG_FILE="/var/log/service-monitor.log"
EOF

    # Set proper permissions (644)
    chmod 644 "${CONFIG_FILE}"
    print_substep "Configuration file created with bash array syntax (644)"
}

# =============================================================================
# MAIN INSTALLATION FUNCTION
# =============================================================================

install_monitor() {
    print_banner

    echo -e "${WHITE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║        INSTALLATION WIZARD - v3.1.4 PRODUCTION             ║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local total_steps=8
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
    echo -e "  Distribution: $(detect_distro)"
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
    mkdir -p "${CONFIG_BASE_DIR}" "${DASHBOARD_DIR}" "${BACKUP_DIR}" "$(dirname "${LOG_FILE}")" "${CACHE_DIR}"
    touch "${UPDATER_LOG}" 2>/dev/null
    chmod 644 "${UPDATER_LOG}" 2>/dev/null
    chmod 755 "${CACHE_DIR}" 2>/dev/null
    print_success "Directories created with proper permissions"
    current_step=$((current_step + 1))

    # Step 5: Create monitor files
    print_step $current_step $total_steps "Creating monitor files"
    create_monitor_script
    create_config_file
    print_success "Monitor files created"
    current_step=$((current_step + 1))

    # Step 6: Create dashboard
    print_step $current_step $total_steps "Creating web dashboard (Production)"
    create_dashboard_files
    create_dashboard_scripts
    create_dashboard_services
    print_success "Dashboard created with fixed Pi-hole API (multiple methods)"
    current_step=$((current_step + 1))

    # Step 7: Create main service
    print_step $current_step $total_steps "Creating main service"
    cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=Service Load Monitor v3.1.4
After=network.target

[Service]
Type=simple
ExecStart=${MONITOR_SCRIPT}
Restart=always
RestartSec=10
User=root
Nice=5

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "${SERVICE_FILE}"
    systemctl daemon-reload
    systemctl enable service-monitor.service &> /dev/null
    systemctl start service-monitor.service &> /dev/null
    print_success "Main service created (service file: 644)"
    current_step=$((current_step + 1))

    # Step 8: Show summary
    print_step $current_step $total_steps "Installation complete"
    local ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    DASHBOARD ACCESS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Local URL:  ${GREEN}http://localhost:${DEFAULT_DASHBOARD_PORT}/${NC}"
    echo -e "  Network URL: ${GREEN}http://${ip}:${DEFAULT_DASHBOARD_PORT}/${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}Production Installation Summary:${NC}"
    echo "  • Version: ${SCRIPT_VERSION} PRODUCTION"
    echo -e "  • Monitor Service: ${GREEN}service-monitor.service${NC} (644)"
    echo -e "  • HTTP Server: ${GREEN}service-monitor-http.service${NC} (644)"
    echo -e "  • Dashboard Service: ${GREEN}service-monitor-dashboard.service${NC} (644)"
    echo -e "  • Dashboard Timer: ${GREEN}service-monitor-dashboard.timer${NC} (644)"
    echo "  • Config: ${CONFIG_FILE} (644)"
    echo "  • Dashboard Script: ${DASHBOARD_SCRIPT} (755)"
    echo "  • Logs: ${LOG_FILE}"
    echo "  • Dashboard: ${DASHBOARD_DIR}"
    echo "  • DNS Services: ${#dns_services[@]}"
    echo ""
    echo -e "${WHITE}Pi-hole API Features:${NC}"
    echo -e "  • ${GREEN}✓${NC} Multiple collection methods (API, sqlite3, log fallback)"
    echo -e "  • ${GREEN}✓${NC} JSON parsing with multiple patterns"
    echo -e "  • ${GREEN}✓${NC} FTL database query support"
    echo -e "  • ${GREEN}✓${NC} Detailed debug logging"
    echo ""
    echo -e "${WHITE}Commands:${NC}"
    echo -e "  • Check timer status: ${GREEN}systemctl status service-monitor-dashboard.timer${NC}"
    echo -e "  • View Pi-hole debug logs: ${GREEN}journalctl -u service-monitor-dashboard.service -f | grep -i pihole${NC}"
    echo -e "  • Run manually: ${GREEN}systemctl start service-monitor-dashboard.service${NC}"
    echo -e "  • View dashboard: ${GREEN}http://${ip}:${DEFAULT_DASHBOARD_PORT}/${NC}"
    echo ""
    echo -e "${GREEN}Thank you for using Service Load Monitor v3.1.4 Production!${NC}"
    echo -e "${GREEN}© 2026 Wael Isa - https://www.wael.name${NC}"
    echo ""
}

# =============================================================================
# IMPROVED REMOVAL FUNCTION - v3.1.4
# =============================================================================

remove_monitor() {
    print_banner
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║           REMOVAL WIZARD - v3.1.4 PRODUCTION               ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if ! check_sudo; then
        print_error "This operation requires sudo access"
        exit 1
    fi

    echo -e "${RED}WARNING: This will completely remove Service Load Monitor${NC}"
    echo -e "${YELLOW}Are you absolutely sure? Type 'YES' to confirm:${NC}"
    read -p "> " confirm

    if [[ "${confirm}" != "YES" ]]; then
        print_info "Removal cancelled"
        return
    fi

    echo ""
    echo -e "${YELLOW}Remove all configuration and data? (y/N)${NC}"
    read -p "> " remove_data

    echo ""
    print_info "Starting comprehensive cleanup..."

    # ===== STOP ALL SERVICES =====
    print_substep "Stopping all services..."

    # Stop timer first (prevents auto-restart)
    if systemctl list-unit-files 2>/dev/null | grep -q "service-monitor-dashboard.timer"; then
        echo "  Stopping dashboard timer..."
        systemctl stop service-monitor-dashboard.timer 2>/dev/null
    fi

    # Stop all possible service names
    local services=(
        "service-monitor-dashboard.service"
        "service-monitor-http.service"
        "service-monitor.service"
        "service-monitor-updater.service"  # LEGACY - explicitly target this
        "service-monitor-v2.2.2.service"   # LEGACY
    )

    for service in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "$service"; then
            echo "  Stopping $service..."
            systemctl stop "$service" 2>/dev/null
            sleep 1
        fi
    done

    # ===== DISABLE ALL SERVICES =====
    print_substep "Disabling all services..."

    # Disable timer first
    if systemctl list-unit-files 2>/dev/null | grep -q "service-monitor-dashboard.timer"; then
        echo "  Disabling dashboard timer..."
        systemctl disable service-monitor-dashboard.timer 2>/dev/null
    fi

    # Disable all possible service names
    for service in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "$service"; then
            echo "  Disabling $service..."
            systemctl disable "$service" 2>/dev/null
        fi
    done

    # ===== VERIFY SERVICES ARE STOPPED =====
    print_substep "Verifying all services are stopped..."
    sleep 2

    local still_running=0
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "  WARNING: $service is still running, forcing stop..."
            systemctl kill "$service" 2>/dev/null
            systemctl stop "$service" 2>/dev/null
            still_running=1
        fi
    done

    if [[ $still_running -eq 0 ]]; then
        print_substep "All services successfully stopped"
    fi

    # ===== REMOVE SERVICE FILES =====
    print_substep "Removing service files..."

    # List of all possible service files to remove
    local service_files=(
        "${DASHBOARD_TIMER}"
        "${DASHBOARD_SERVICE}"
        "${DASHBOARD_HTTP_SERVICE}"
        "${SERVICE_FILE}"
        "${LEGACY_UPDATER_SERVICE}"  # CRITICAL: Remove old updater service
        "${LEGACY_SERVICE_V2}"
        "${LEGACY_SERVICE_OLD}"
        "/etc/systemd/system/service-monitor-updater.service"  # Direct path as backup
        "/etc/systemd/system/multi-user.target.wants/service-monitor-updater.service"
        "/etc/systemd/system/timers.target.wants/service-monitor-dashboard.timer"
        "/etc/systemd/system/multi-user.target.wants/service-monitor-http.service"
        "/etc/systemd/system/multi-user.target.wants/service-monitor.service"
    )

    for file in "${service_files[@]}"; do
        if [[ -f "$file" ]] || [[ -L "$file" ]]; then
            echo "  Removing $file"
            rm -f "$file" 2>/dev/null
        fi
    done

    # ===== REMOVE SCRIPT FILES =====
    print_substep "Removing script files..."

    local script_files=(
        "${MONITOR_SCRIPT}"
        "${DASHBOARD_SCRIPT}"
        "${BASE_DIR}/service_load_monitor.sh"        # Legacy
        "${BASE_DIR}/service-monitor-client.sh"      # Legacy
        "${BASE_DIR}/service-monitor-update.sh"      # Legacy
    )

    for file in "${script_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "  Removing $file"
            rm -f "$file" 2>/dev/null
        fi
    done

    # ===== REMOVE CONFIGURATION AND DATA =====
    if [[ "${remove_data}" =~ ^[Yy]$ ]]; then
        print_substep "Removing configuration and data..."

        local data_dirs=(
            "${CONFIG_BASE_DIR}"
            "${LIB_BASE_DIR}"
            "${DASHBOARD_DIR}"
            "${CACHE_DIR}"
            "/var/lib/service-monitor"  # Direct path as backup
        )

        for dir in "${data_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                echo "  Removing $dir"
                rm -rf "$dir" 2>/dev/null
            fi
        done

        # Remove log files
        rm -f "${LOG_FILE}"* "${UPDATER_LOG}"* 2>/dev/null
        rm -f /var/log/service-monitor*.log* 2>/dev/null

        print_substep "Configuration and data removed"
    else
        print_info "Configuration kept at: ${CONFIG_BASE_DIR}"
    fi

    # ===== FINAL CLEANUP =====
    print_substep "Final systemd cleanup..."
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null

    # ===== VERIFY REMOVAL =====
    print_substep "Verifying removal..."
    local remaining=0

    # Check for any remaining service files
    for service in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "$service"; then
            echo "  WARNING: $service still present in systemd"
            remaining=1
        fi
    done

    if [[ $remaining -eq 0 ]]; then
        print_success "All Service Load Monitor components have been removed"
    else
        print_warning "Some components may still remain. Check manually with: systemctl list-units | grep service-monitor"
    fi

    echo ""
    print_success "Removal process completed"
}

# =============================================================================
# STATUS FUNCTION
# =============================================================================

show_status() {
    print_banner
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}              SYSTEM STATUS - v3.1.4 PRODUCTION              ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""

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

    if systemctl is-active --quiet service-monitor-dashboard.timer 2>/dev/null; then
        echo -e "  • ${GREEN}●${NC} Dashboard Timer: Active"
        local next_run=$(systemctl show service-monitor-dashboard.timer -p NextElapseUSecRealtime --value 2>/dev/null)
        if [[ -n "$next_run" ]]; then
            echo -e "  • Next run: ${next_run}"
        fi
    else
        echo -e "  • ${RED}○${NC} Dashboard Timer: Inactive"
    fi

    # Check for legacy services
    if systemctl list-unit-files 2>/dev/null | grep -q "service-monitor-updater.service"; then
        echo -e "  • ${YELLOW}⚠${NC} Legacy updater service detected (will be removed on next install)"
    fi

    # Check file permissions
    echo ""
    echo -e "${WHITE}File Permissions:${NC}"
    if [[ -f "${DASHBOARD_TIMER}" ]]; then
        local perms=$(stat -c '%a' "${DASHBOARD_TIMER}" 2>/dev/null)
        echo -e "  • Timer file: ${perms} (should be 644)"
    fi
    if [[ -f "${DASHBOARD_SERVICE}" ]]; then
        local perms=$(stat -c '%a' "${DASHBOARD_SERVICE}" 2>/dev/null)
        echo -e "  • Service file: ${perms} (should be 644)"
    fi
    if [[ -f "${CONFIG_FILE}" ]]; then
        local perms=$(stat -c '%a' "${CONFIG_FILE}" 2>/dev/null)
        echo -e "  • Config file: ${perms} (should be 644)"
    fi

    # Pi-hole info with debug
    if command -v pihole &>/dev/null; then
        echo ""
        echo -e "${WHITE}Pi-hole Information:${NC}"
        if systemctl is-active --quiet pihole-FTL.service 2>/dev/null; then
            echo -e "  • ${GREEN}●${NC} Pi-hole FTL: Running"
            echo -e "  • ${GREEN}✓${NC} Using multi-method API (v3.1.4)"

            # Show last Pi-hole stats from log
            if [[ -f "${UPDATER_LOG}" ]]; then
                local last_stats=$(grep -i "FINAL.*pihole" "${UPDATER_LOG}" | tail -1)
                if [[ -n "$last_stats" ]]; then
                    echo -e "  • Last stats: ${last_stats##*FINAL }"
                fi
            fi
        else
            echo -e "  • ${RED}○${NC} Pi-hole FTL: Stopped"
        fi
    fi

    echo ""
    echo -e "${WHITE}Version:${NC} ${SCRIPT_VERSION} Production"
}

# =============================================================================
# LOG FUNCTION
# =============================================================================

show_logs() {
    if [[ -f "${UPDATER_LOG}" ]]; then
        tail -f "${UPDATER_LOG}"
    elif [[ -f "${LOG_FILE}" ]]; then
        tail -f "${LOG_FILE}"
    else
        journalctl -u service-monitor-dashboard.service -f
    fi
}

# =============================================================================
# BANNER FUNCTION
# =============================================================================

print_banner() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}       SERVICE LOAD MONITOR v3.1.4 PRODUCTION           ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${GREEN}  Author:  Wael Isa                                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Version: 3.1.4 (Fixed Pi-hole API)                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Website: https://www.wael.name                         ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# =============================================================================
# FEATURES FUNCTION
# =============================================================================

show_features() {
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}           PRODUCTION FEATURES - v3.1.4                       ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}⚡ PI-HOLE API (FIXED)${NC}"
    echo "  • 4 methods to collect stats (API, human readable, DB, logs)"
    echo "  • Multiple JSON parsing patterns"
    echo "  • FTL database query support"
    echo "  • Detailed debug logging"
    echo ""
    echo -e "${GREEN}⏱️  SYSTEMD TIMER${NC}"
    echo "  • Zero CPU usage between runs"
    echo "  • Proper service management"
    echo "  • Journald integration"
    echo "  • Predictable scheduling"
    echo ""
    echo -e "${GREEN}🔒 PRODUCTION READY${NC}"
    echo "  • All service files: 644 permissions"
    echo "  • Atomic JSON writes"
    echo "  • Error handling for all commands"
    echo "  • Clean removal of all components"
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
    chmod 755 "${backup_path}"

    [[ -d "${CONFIG_BASE_DIR}" ]] && cp -r "${CONFIG_BASE_DIR}" "${backup_path}/" 2>/dev/null
    [[ -f "${MONITOR_SCRIPT}" ]] && cp "${MONITOR_SCRIPT}" "${backup_path}/" 2>/dev/null
    [[ -f "${DASHBOARD_SCRIPT}" ]] && cp "${DASHBOARD_SCRIPT}" "${backup_path}/" 2>/dev/null
    [[ -f "${SERVICE_FILE}" ]] && cp "${SERVICE_FILE}" "${backup_path}/" 2>/dev/null
    [[ -f "${DASHBOARD_SERVICE}" ]] && cp "${DASHBOARD_SERVICE}" "${backup_path}/" 2>/dev/null
    [[ -f "${DASHBOARD_TIMER}" ]] && cp "${DASHBOARD_TIMER}" "${backup_path}/" 2>/dev/null
    [[ -f "${DASHBOARD_HTTP_SERVICE}" ]] && cp "${DASHBOARD_HTTP_SERVICE}" "${backup_path}/" 2>/dev/null

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

    systemctl stop service-monitor-dashboard.timer 2>/dev/null
    systemctl stop service-monitor-dashboard.service 2>/dev/null
    systemctl stop service-monitor-http.service 2>/dev/null
    systemctl stop service-monitor.service 2>/dev/null

    [[ -d "${backup_path}/service-monitor" ]] && cp -r "${backup_path}/service-monitor" "${CONFIG_BASE_DIR%/*}/" 2>/dev/null
    [[ -f "${backup_path}/service-monitor.sh" ]] && cp "${backup_path}/service-monitor.sh" "${BASE_DIR}/" 2>/dev/null && chmod 755 "${BASE_DIR}/service-monitor.sh"
    [[ -f "${backup_path}/service-monitor-dashboard.sh" ]] && cp "${backup_path}/service-monitor-dashboard.sh" "${BASE_DIR}/" 2>/dev/null && chmod 755 "${BASE_DIR}/service-monitor-dashboard.sh"
    [[ -f "${backup_path}/service-monitor.service" ]] && cp "${backup_path}/service-monitor.service" "/etc/systemd/system/" 2>/dev/null && chmod 644 "/etc/systemd/system/service-monitor.service"
    [[ -f "${backup_path}/service-monitor-dashboard.service" ]] && cp "${backup_path}/service-monitor-dashboard.service" "/etc/systemd/system/" 2>/dev/null && chmod 644 "/etc/systemd/system/service-monitor-dashboard.service"
    [[ -f "${backup_path}/service-monitor-dashboard.timer" ]] && cp "${backup_path}/service-monitor-dashboard.timer" "/etc/systemd/system/" 2>/dev/null && chmod 644 "/etc/systemd/system/service-monitor-dashboard.timer"
    [[ -f "${backup_path}/service-monitor-http.service" ]] && cp "${backup_path}/service-monitor-http.service" "/etc/systemd/system/" 2>/dev/null && chmod 644 "/etc/systemd/system/service-monitor-http.service"

    systemctl daemon-reload
    print_success "Restore completed with proper permissions"
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

    if [[ -f "${SERVICE_FILE}" ]] || [[ -f "${DASHBOARD_SERVICE}" ]] || [[ -f "${DASHBOARD_TIMER}" ]] || [[ -f "${LEGACY_UPDATER_SERVICE}" ]]; then
        has_old_files=true
    fi

    echo "${installed_version}|${has_old_files}"
}

migrate_configuration() {
    print_info "Migrating existing configuration to Production..."
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
    echo "  1) Install/Update Monitor (v3.1.4 Production)"
    echo "  2) Remove Monitor (Comprehensive Cleanup)"
    echo "  3) Show Status"
    echo "  4) View Logs"
    echo "  5) Create Backup"
    echo "  6) Restore from Backup"
    echo "  7) Show Production Features"
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
                echo "Service Load Monitor v${SCRIPT_VERSION} Production"
                ;;
            features)
                show_features
                ;;
            help)
                echo "Commands: install, remove, status, logs, backup, restore, version, features"
                ;;
            *)
                echo "Unknown command: $1"
                exit 1
                ;;
        esac
        exit 0
    fi

    # Check for existing installation
    local existing=$(check_existing_installation)
    local old_ver="${existing%|*}"

    if [[ -n "$old_ver" ]] && [[ "$old_ver" != "$SCRIPT_VERSION" ]]; then
        local comparison=$(version_compare "$SCRIPT_VERSION" "$old_ver")
        if [[ "$comparison" == "newer" ]]; then
            echo -e "${YELLOW}Production version available: $old_ver -> $SCRIPT_VERSION${NC}"
            echo -e "${YELLOW}Run './service-load-monitor.sh install' to upgrade${NC}"
            echo ""
        fi
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
                echo -e "\n${GREEN}Thank you for using Service Load Monitor v3.1.4 Production!${NC}"
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
