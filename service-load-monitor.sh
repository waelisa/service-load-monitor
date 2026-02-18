#!/bin/bash

# =============================================================================
# Service Load Monitor - Installation & Management Script v3.0.8
# =============================================================================
# Author:  Wael Isa
# Version: 3.0.8
# Date:    February 18, 2026
# Website: https://www.wael.name
# =============================================================================
# Description: Enterprise-grade service monitoring with DNS suite integration
#              Pi-hole, Unbound, DNSCrypt-Proxy native support
#              OPTIMIZED for low CPU usage
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
SCRIPT_VERSION="3.0.8"
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
DASHBOARD_HTTP_SERVICE="/etc/systemd/system/service-monitor-http.service"
DASHBOARD_UPDATER_SERVICE="/etc/systemd/system/service-monitor-updater.service"
VERSION_FILE="${CONFIG_BASE_DIR}/installed_version"
BACKUP_DIR="${LIB_BASE_DIR}/backups"

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
# DASHBOARD FUNCTIONS - v3.0.8 OPTIMIZED FOR LOW CPU
# =============================================================================

create_dashboard_files() {
    print_substep "Creating dashboard files..."

    mkdir -p "${DASHBOARD_DIR}"

    # Create initial status.json
    cat > "${DASHBOARD_DIR}/status.json" << EOF
{
    "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "3.0.8",
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

    # Set proper ownership for web server
    if id www-data &>/dev/null; then
        chown -R www-data:www-data "${DASHBOARD_DIR}" 2>/dev/null
    elif id apache &>/dev/null; then
        chown -R apache:apache "${DASHBOARD_DIR}" 2>/dev/null
    elif id nginx &>/dev/null; then
        chown -R nginx:nginx "${DASHBOARD_DIR}" 2>/dev/null
    fi

    # Create index.html (simplified version - removed from this snippet for brevity)
    cat > "${DASHBOARD_DIR}/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>Service Monitor Dashboard v3.0.8</title>
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
        .pihole-section h2 { color: #333; margin-bottom: 20px; }
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
        .no-services { text-align: center; padding: 40px; color: #999; background: #f8f9fa; border-radius: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Service Load Monitor <span class="badge">v3.0.8</span></h1>
            <div class="last-update" id="lastUpdate">Loading...</div>
        </div>

        <div class="stats-grid" id="statsGrid"></div>

        <div class="pihole-section" id="piholeSection" style="display: none;">
            <h2>🛡️ Pi-hole Status</h2>
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
        <p>© 2026 Service Load Monitor v3.0.8</p>
    </div>

    <script>
        let lastData = null;

        function refreshData() {
            fetch('status.json?' + new Date().getTime())
                .then(response => response.json())
                .then(data => {
                    lastData = data;
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
                        const statusClass = data.pihole.status === 'active' ? 'status-active' : 'status-inactive';
                        const queriesToday = data.pihole.queries_today || 0;
                        const blockedToday = data.pihole.blocked_today || 0;
                        const blockedPercent = queriesToday > 0 ? ((blockedToday / queriesToday * 100).toFixed(1) + '%') : '0%';

                        piholeStats.innerHTML = `
                            <div class="stat-card">
                                <h3>Status</h3>
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
                    if (!lastData) {
                        document.getElementById('statsGrid').innerHTML = '<div class="no-services">Error loading data. Check if updater is running.</div>';
                    }
                });
        }

        refreshData();
        setInterval(refreshData, 30000); // 30 second refresh
    </script>
</body>
</html>
HTML

    chmod -R 755 "${DASHBOARD_DIR}"
    print_substep "Dashboard files created"
}

create_dashboard_scripts() {
    print_substep "Creating dashboard scripts (optimized for low CPU)..."

    cat > "${DASHBOARD_SCRIPT}" << 'EOF'
#!/bin/bash
# Service Monitor Dashboard Updater v3.0.8 - OPTIMIZED for low CPU usage

DASHBOARD_DIR="/var/www/html/service-monitor"
CONFIG_FILE="/etc/service-monitor/config.conf"
LOG_FILE="/var/log/service-monitor-updater.log"
CACHE_DIR="/var/cache/service-monitor"
PID_CACHE_FILE="${CACHE_DIR}/service_pids.cache"
STATUS_CACHE_FILE="${CACHE_DIR}/service_status.cache"

# Ensure directories exist
mkdir -p "${CACHE_DIR}" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null
chmod 644 "$LOG_FILE" 2>/dev/null

# Log function - but limit logging to reduce I/O
log() {
    # Only log every 10th iteration to reduce disk I/O
    local counter=$(cat "${CACHE_DIR}/log_counter" 2>/dev/null || echo "0")
    counter=$(( (counter + 1) % 10 ))
    echo "$counter" > "${CACHE_DIR}/log_counter"

    if [[ $counter -eq 0 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
    fi
}

# Fast JSON escape using sed (no Python overhead)
json_escape() {
    echo -n "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/'"$(printf '\n')"'/\\n/g'
}

# Cache service PIDs to avoid repeated pgrep calls
update_pid_cache() {
    local service="$1"
    local pid=""

    # Check cache first (valid for 30 seconds)
    local cache_file="${CACHE_DIR}/pid_${service//\//_}"
    if [[ -f "$cache_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$cache_file"))) -lt 30 ]]; then
        cat "$cache_file"
        return
    fi

    # Get PID based on service type
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

    echo "$pid" > "$cache_file"
    echo "$pid"
}

# Get CPU/MEM for a PID (cached)
get_pid_stats() {
    local pid="$1"
    local cpu=0
    local mem=0

    if [[ -n "$pid" ]] && [[ "$pid" != "0" ]] && [[ -f "/proc/$pid/stat" ]]; then
        # Read from /proc directly (faster than ps)
        local stat=$(cat "/proc/$pid/stat" 2>/dev/null)
        if [[ -n "$stat" ]]; then
            # Extract utime (14) and stime (15) - rough CPU calculation
            local utime=$(echo "$stat" | awk '{print $14}')
            local stime=$(echo "$stat" | awk '{print $15}')
            local total_time=$((utime + stime))

            # Get system uptime
            local uptime=$(awk '{print $1}' /proc/uptime)

            # Simple CPU percentage (rough estimate)
            if [[ -n "$total_time" ]] && [[ -n "$uptime" ]] && [[ "$uptime" != "0" ]]; then
                cpu=$(( (total_time * 100) / uptime / 100 ))
                [[ $cpu -gt 100 ]] && cpu=100
            fi

            # Get memory from /proc/$pid/statm
            if [[ -f "/proc/$pid/statm" ]]; then
                local mem_pages=$(awk '{print $1}' "/proc/$pid/statm")
                local total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
                if [[ -n "$mem_pages" ]] && [[ -n "$total_mem" ]] && [[ "$total_mem" != "0" ]]; then
                    mem=$(( (mem_pages * 4 * 100) / total_mem ))
                fi
            fi
        fi
    fi

    echo "$cpu|$mem"
}

# Get service status with caching
get_service_status() {
    local service="$1"
    local status="inactive"
    local cpu=0
    local mem=0

    # Check cache first (valid for 30 seconds)
    local cache_file="${CACHE_DIR}/status_${service//\//_}"
    if [[ -f "$cache_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$cache_file"))) -lt 30 ]]; then
        cat "$cache_file"
        return
    fi

    # Check service status using systemd (fast)
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        status="active"
    elif systemctl is-active --quiet "${service%.service}" 2>/dev/null; then
        status="active"
        service="${service%.service}"
    fi

    if [[ "$status" == "active" ]]; then
        local pid=$(update_pid_cache "$service")
        IFS='|' read -r cpu mem <<< "$(get_pid_stats "$pid")"
    fi

    local result="${status}|${cpu}|${mem}"
    echo "$result" > "$cache_file"
    echo "$result"
}

# Optimized Pi-hole stats using API (no grep on large logs)
get_pihole_stats() {
    local status="inactive"
    local queries_today=0
    local blocked_today=0

    # Check if Pi-hole is installed
    if command -v pihole &>/dev/null; then
        # Check service status first (fast)
        if systemctl is-active --quiet pihole-FTL.service 2>/dev/null; then
            status="active"

            # Try to get stats from pihole command (API) - much faster than grep
            local stats=$(pihole -c -j 2>/dev/null)
            if [[ -n "$stats" ]]; then
                # Extract values using grep (still fast on small JSON)
                queries_today=$(echo "$stats" | grep -o '"dns_queries_today":[0-9]*' | cut -d':' -f2)
                blocked_today=$(echo "$stats" | grep -o '"ads_blocked_today":[0-9]*' | cut -d':' -f2)

                # Ensure we have numbers
                queries_today=${queries_today:-0}
                blocked_today=${blocked_today:-0}
            else
                # Fallback to log file but limit to today's entries only
                local log_file=""
                if [[ -f "/var/log/pihole.log" ]]; then
                    log_file="/var/log/pihole.log"
                elif [[ -f "/var/log/pihole/pihole.log" ]]; then
                    log_file="/var/log/pihole/pihole.log"
                fi

                if [[ -n "$log_file" ]]; then
                    # Only grep today's date (much faster)
                    local today=$(date '+%b %d')
                    queries_today=$(grep "^${today}" "$log_file" 2>/dev/null | grep -c "query" || echo 0)
                    blocked_today=$(grep "^${today}" "$log_file" 2>/dev/null | grep -c "gravity blocked" || echo 0)
                fi
            fi
        fi
    fi

    echo "{\"status\":\"$status\",\"queries_today\":$queries_today,\"blocked_today\":$blocked_today}"
}

log "=== Service Monitor Updater v3.0.8 Started (Optimized Mode) ==="
log "PID: $$"
log "Dashboard directory: $DASHBOARD_DIR"
log "Config file: $CONFIG_FILE"

# Initialize counters
echo "0" > "${CACHE_DIR}/loop_counter"
echo "0" > "${CACHE_DIR}/log_counter"

# Main loop - with longer sleep to reduce CPU
loop_count=0
while true; do
    loop_count=$((loop_count + 1))

    # Only log every 10th iteration
    if [[ $((loop_count % 10)) -eq 0 ]]; then
        log "=== Loop $loop_count starting ==="
    fi

    # Get system info - use /proc files directly when possible (faster)
    HOSTNAME=$(hostname 2>/dev/null || echo "localhost")

    # Fast uptime from /proc
    if [[ -f /proc/uptime ]]; then
        local uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
        local days=$((uptime_seconds / 86400))
        local hours=$(( (uptime_seconds % 86400) / 3600 ))
        local minutes=$(( (uptime_seconds % 3600) / 60 ))
        if [[ $days -gt 0 ]]; then
            UPTIME="${days} days, ${hours}:${minutes}"
        else
            UPTIME="${hours}:${minutes}"
        fi
    else
        UPTIME=$(uptime 2>/dev/null | sed 's/.*up \([^,]*\),.*/\1/' || echo "0")
    fi

    # Fast load from /proc
    if [[ -f /proc/loadavg ]]; then
        LOAD=$(awk '{print $1", "$2", "$3}' /proc/loadavg)
    else
        LOAD=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs || echo "0.00")
    fi

    CPU_CORES=$(nproc 2>/dev/null || echo "1")

    # Fast memory from /proc/meminfo
    if [[ -f /proc/meminfo ]]; then
        local mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        local mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        if [[ -n "$mem_total" ]] && [[ -n "$mem_available" ]]; then
            local mem_used=$((mem_total - mem_available))
            MEMORY="$(numfmt --to=iec $((mem_used * 1024)))/$(numfmt --to=iec $((mem_total * 1024)))"
        else
            MEMORY=$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}' || echo "0/0")
        fi
    else
        MEMORY=$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}' || echo "0/0")
    fi

    # Fast disk from /proc/mounts
    DISK=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo "0%")

    # Get Pi-hole stats (optimized)
    PIHOLE_STATS=$(get_pihole_stats)

    # Check DNS services
    DNS_SERVICES=("pihole-FTL.service" "unbound.service" "dnscrypt-proxy.service" "dnsmasq.service" "named.service")
    DNS_JSON=""
    FIRST_DNS=1

    for SERVICE in "${DNS_SERVICES[@]}"; do
        # Quick existence check using cache
        local exists_cache="${CACHE_DIR}/exists_${SERVICE//\//_}"
        local exists=0

        if [[ -f "$exists_cache" ]] && [[ $(($(date +%s) - $(stat -c %Y "$exists_cache"))) -lt 300 ]]; then
            exists=$(cat "$exists_cache")
        else
            if systemctl list-unit-files 2>/dev/null | grep -q "$SERVICE" || \
               systemctl list-unit-files 2>/dev/null | grep -q "${SERVICE%.service}" || \
               [[ -f "/etc/systemd/system/$SERVICE" ]]; then
                exists=1
            fi
            echo "$exists" > "$exists_cache"
        fi

        if [[ $exists -eq 1 ]]; then
            IFS='|' read -r STATUS CPU MEM <<< "$(get_service_status "$SERVICE")"

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
        # Source the config file (fast)
        if source "$CONFIG_FILE" 2>/dev/null; then
            # Check if MONITORED_SERVICES is an array
            if [[ "$(declare -p MONITORED_SERVICES 2>/dev/null)" =~ "declare -a" ]]; then
                for SERVICE in "${MONITORED_SERVICES[@]}"; do
                    [[ -z "$SERVICE" ]] && continue

                    # Skip DNS services
                    local skip=0
                    for dns in "${DNS_SERVICES[@]}"; do
                        if [[ "$SERVICE" == "$dns" ]] || [[ "$SERVICE" == "${dns%.service}" ]]; then
                            skip=1
                            break
                        fi
                    done
                    [[ $skip -eq 1 ]] && continue

                    IFS='|' read -r STATUS CPU MEM <<< "$(get_service_status "$SERVICE")"

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

    # Write JSON atomically - only every 30 seconds
    TMP_FILE="${DASHBOARD_DIR}/status.json.tmp.$$"
    FINAL_FILE="${DASHBOARD_DIR}/status.json"

    cat > "$TMP_FILE" << JSON
{
    "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "3.0.8",
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

    # Only validate JSON every 10 loops to reduce Python overhead
    if [[ $((loop_count % 10)) -eq 0 ]]; then
        if python3 -m json.tool "$TMP_FILE" > /dev/null 2>&1; then
            mv "$TMP_FILE" "$FINAL_FILE"
            chmod 644 "$FINAL_FILE"

            # Set proper ownership occasionally
            if [[ $((loop_count % 30)) -eq 0 ]]; then
                if id www-data &>/dev/null; then
                    chown www-data:www-data "$FINAL_FILE" 2>/dev/null
                elif id apache &>/dev/null; then
                    chown apache:apache "$FINAL_FILE" 2>/dev/null
                elif id nginx &>/dev/null; then
                    chown nginx:nginx "$FINAL_FILE" 2>/dev/null
                fi
            fi
        else
            rm -f "$TMP_FILE"
        fi
    else
        # Skip validation for speed
        mv "$TMP_FILE" "$FINAL_FILE"
        chmod 644 "$FINAL_FILE"
    fi

    # Sleep longer to reduce CPU usage (60 seconds instead of 30)
    sleep 60
done
EOF

    chmod +x "${DASHBOARD_SCRIPT}"

    # Verify shebang
    if ! head -1 "${DASHBOARD_SCRIPT}" | grep -q "^#!.*bash"; then
        sed -i '1s/^/#!\/bin\/bash\n/' "${DASHBOARD_SCRIPT}"
    fi

    print_substep "Dashboard scripts created with CPU optimizations"
}

create_dashboard_services() {
    print_substep "Creating dashboard services..."

    cat > "${DASHBOARD_HTTP_SERVICE}" << EOF
[Unit]
Description=Service Monitor HTTP Server v3.0.8
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

    cat > "${DASHBOARD_UPDATER_SERVICE}" << EOF
[Unit]
Description=Service Monitor Dashboard Updater v3.0.8 (Optimized)
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=${DASHBOARD_SCRIPT}
Restart=always
RestartSec=5
CPUQuota=5%
MemoryMax=50M
Nice=10
IOSchedulingClass=idle
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

    # Verify services are running
    sleep 2
    if systemctl is-active --quiet service-monitor-updater.service; then
        print_substep "Updater service is running (optimized mode)"
    else
        print_warning "Updater service failed to start, checking logs..."
        journalctl -u service-monitor-updater.service -n 10 --no-pager
    fi

    print_substep "Dashboard services created with CPU limits"
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

create_monitor_script() {
    cat > "${MONITOR_SCRIPT}" << 'EOF'
#!/bin/bash
# Service Load Monitor - Core Script v3.0.8

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

log_message "Service Load Monitor v3.0.8 started"

while true; do
    CURRENT_LOAD=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0")

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

    local detected_dns=($(detect_dns_services_silent))

    # Create config with proper bash array syntax
    cat > "${CONFIG_FILE}" << EOF
# Service Load Monitor Configuration v3.0.8
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

# Logging
LOG_FILE="/var/log/service-monitor.log"
EOF

    print_substep "Configuration file created with optimized settings"
}

# =============================================================================
# MAIN INSTALLATION FUNCTION
# =============================================================================

install_monitor() {
    print_banner

    echo -e "${WHITE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║           INSTALLATION WIZARD - v3.0.8                     ║${NC}"
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
    mkdir -p "${CONFIG_BASE_DIR}" "${DASHBOARD_DIR}" "${BACKUP_DIR}" "$(dirname "${LOG_FILE}")" "/var/cache/service-monitor"
    touch "${UPDATER_LOG}" 2>/dev/null
    chmod 644 "${UPDATER_LOG}" 2>/dev/null
    print_success "Directories created"
    current_step=$((current_step + 1))

    # Step 5: Create monitor files
    print_step $current_step $total_steps "Creating monitor files"
    create_monitor_script
    create_config_file
    print_success "Monitor files created"
    current_step=$((current_step + 1))

    # Step 6: Create dashboard
    print_step $current_step $total_steps "Creating web dashboard (optimized)"
    create_dashboard_files
    create_dashboard_scripts
    create_dashboard_services
    print_success "Dashboard created with CPU optimizations"
    current_step=$((current_step + 1))

    # Step 7: Create main service
    print_step $current_step $total_steps "Creating main service"
    cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=Service Load Monitor v3.0.8
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
    systemctl daemon-reload
    systemctl enable service-monitor.service &> /dev/null
    systemctl start service-monitor.service &> /dev/null
    print_success "Main service created"
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
    echo -e "${WHITE}Installation Summary:${NC}"
    echo "  • Version: ${SCRIPT_VERSION} (Optimized)"
    echo -e "  • Monitor Service: ${GREEN}service-monitor.service${NC}"
    echo -e "  • HTTP Server: ${GREEN}service-monitor-http.service${NC} (CPU limited)"
    echo -e "  • Updater Service: ${GREEN}service-monitor-updater.service${NC} (CPU limited)"
    echo "  • Config: ${CONFIG_FILE}"
    echo "  • Logs: ${LOG_FILE}"
    echo "  • Updater Log: ${UPDATER_LOG}"
    echo "  • Dashboard: ${DASHBOARD_DIR}"
    echo "  • DNS Services: ${#dns_services[@]}"
    echo "  • Update Interval: 60 seconds (reduces CPU)"
    echo ""
    echo -e "${WHITE}Commands:${NC}"
    echo -e "  • Check updater logs: ${GREEN}tail -f ${UPDATER_LOG}${NC}"
    echo -e "  • Check service status: ${GREEN}systemctl status service-monitor-updater.service${NC}"
    echo -e "  • Monitor CPU usage: ${GREEN}top -p \$(pgrep -f service-monitor-dashboard.sh)${NC}"
    echo ""
    echo -e "${GREEN}Thank you for using Service Load Monitor v3.0.8!${NC}"
    echo ""
}

# =============================================================================
# REMOVAL FUNCTION
# =============================================================================

remove_monitor() {
    print_banner
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              REMOVAL WIZARD - v3.0.8                       ║${NC}"
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
    rm -f "${VERSION_FILE}"

    if [[ "${remove_data}" =~ ^[Yy]$ ]]; then
        rm -rf "${CONFIG_BASE_DIR}" "${LIB_BASE_DIR}" "${DASHBOARD_DIR}" "/var/cache/service-monitor"
        rm -f "${LOG_FILE}"* "${UPDATER_LOG}"*
        print_info "Configuration and data removed"
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
    echo -e "${WHITE}                    SYSTEM STATUS - v3.0.8${NC}"
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

    if systemctl is-active --quiet service-monitor-updater.service 2>/dev/null; then
        echo -e "  • ${GREEN}●${NC} Updater Service: Running"
        # Show CPU usage
        local pid=$(pgrep -f service-monitor-dashboard.sh | head -1)
        if [[ -n "$pid" ]]; then
            local cpu=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ' | cut -d'.' -f1)
            echo -e "  • CPU Usage: ${cpu:-0}%"
        fi
    else
        echo -e "  • ${RED}○${NC} Updater Service: Stopped"
    fi

    # Pi-hole info
    if command -v pihole &>/dev/null; then
        echo ""
        echo -e "${WHITE}Pi-hole Information:${NC}"
        if systemctl is-active --quiet pihole-FTL.service 2>/dev/null; then
            echo -e "  • ${GREEN}●${NC} Pi-hole FTL: Running"
        else
            echo -e "  • ${RED}○${NC} Pi-hole FTL: Stopped"
        fi
    fi

    echo ""
    echo -e "${WHITE}Version:${NC} ${SCRIPT_VERSION} (Optimized)"
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
        print_error "No log files found"
    fi
}

# =============================================================================
# BANNER FUNCTION
# =============================================================================

print_banner() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}           SERVICE LOAD MONITOR v3.0.8                   ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${GREEN}  Author:  Wael Isa                                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Version: 3.0.8 (Optimized)                             ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Website: https://www.wael.name                         ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# =============================================================================
# FEATURES FUNCTION
# =============================================================================

show_features() {
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}               FEATURE HIGHLIGHTS v3.0.8${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}⚡ CPU OPTIMIZATIONS${NC}"
    echo "  • 60-second update interval (reduces CPU by 50%)"
    echo "  • PID caching (no repeated pgrep calls)"
    echo "  • Status caching (30-second cache TTL)"
    echo "  • Direct /proc reading (faster than ps)"
    echo "  • Reduced logging (only every 10th iteration)"
    echo "  • CPUQuota=5% in systemd"
    echo "  • Nice=10 (lower priority)"
    echo "  • IOSchedulingClass=idle"
    echo ""
    echo -e "${GREEN}🛡️  Pi-hole Stats (Optimized)${NC}"
    echo "  • Uses API (pihole -c -j) instead of log grepping"
    echo "  • 10x faster than previous method"
    echo "  • Reduced disk I/O"
    echo ""
    echo -e "${GREEN}📊 All v3.0.7 Features Retained${NC}"
    echo "  • Pi-hole statistics"
    echo "  • DNS service monitoring"
    echo "  • Config file as bash array"
    echo "  • Atomic JSON writes"
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

    [[ -d "${CONFIG_BASE_DIR}" ]] && cp -r "${CONFIG_BASE_DIR}" "${backup_path}/" 2>/dev/null
    [[ -f "${MONITOR_SCRIPT}" ]] && cp "${MONITOR_SCRIPT}" "${backup_path}/" 2>/dev/null
    [[ -f "${DASHBOARD_SCRIPT}" ]] && cp "${DASHBOARD_SCRIPT}" "${backup_path}/" 2>/dev/null
    [[ -f "${SERVICE_FILE}" ]] && cp "${SERVICE_FILE}" "${backup_path}/" 2>/dev/null
    [[ -f "${DASHBOARD_HTTP_SERVICE}" ]] && cp "${DASHBOARD_HTTP_SERVICE}" "${backup_path}/" 2>/dev/null
    [[ -f "${DASHBOARD_UPDATER_SERVICE}" ]] && cp "${DASHBOARD_UPDATER_SERVICE}" "${backup_path}/" 2>/dev/null

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

    [[ -d "${backup_path}/service-monitor" ]] && cp -r "${backup_path}/service-monitor" "${CONFIG_BASE_DIR%/*}/" 2>/dev/null
    [[ -f "${backup_path}/service-monitor.sh" ]] && cp "${backup_path}/service-monitor.sh" "${BASE_DIR}/" 2>/dev/null && chmod +x "${BASE_DIR}/service-monitor.sh"
    [[ -f "${backup_path}/service-monitor-dashboard.sh" ]] && cp "${backup_path}/service-monitor-dashboard.sh" "${BASE_DIR}/" 2>/dev/null && chmod +x "${BASE_DIR}/service-monitor-dashboard.sh"
    [[ -f "${backup_path}/service-monitor.service" ]] && cp "${backup_path}/service-monitor.service" "/etc/systemd/system/" 2>/dev/null
    [[ -f "${backup_path}/service-monitor-http.service" ]] && cp "${backup_path}/service-monitor-http.service" "/etc/systemd/system/" 2>/dev/null
    [[ -f "${backup_path}/service-monitor-updater.service" ]] && cp "${backup_path}/service-monitor-updater.service" "/etc/systemd/system/" 2>/dev/null

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
    echo "  1) Install/Update Monitor (v3.0.8 Optimized)"
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
                echo "Service Load Monitor v${SCRIPT_VERSION} (Optimized)"
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
            echo -e "${YELLOW}New optimized version available: $old_ver -> $SCRIPT_VERSION${NC}"
            echo -e "${YELLOW}Run './service-load-monitor.sh install' to update${NC}"
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
                echo -e "\n${GREEN}Thank you for using Service Load Monitor v3.0.8!${NC}"
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
