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

# =============================================================================
# DASHBOARD FUNCTIONS - COMPLETELY SILENT, NO OUTPUT TO JSON
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

    # Create index.html with fixed JavaScript
    cat > "${DASHBOARD_DIR}/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>Service Monitor Dashboard v3.0.4</title>
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
        }
        .stat-card h3 { color: #666; font-size: 0.9em; margin-bottom: 10px; }
        .stat-card .value { color: #333; font-size: 1.8em; font-weight: bold; }

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
        .last-update { color: #999; font-size: 0.9em; margin-top: 10px; }
        .loading { text-align: center; padding: 40px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Service Load Monitor <span class="badge">v3.0.4</span></h1>
            <div class="last-update" id="lastUpdate">Loading...</div>
        </div>

        <div class="stats-grid" id="statsGrid">
            <div class="stat-card"><h3>System Load</h3><div class="value">Loading...</div></div>
            <div class="stat-card"><h3>Uptime</h3><div class="value">Loading...</div></div>
            <div class="stat-card"><h3>Memory</h3><div class="value">Loading...</div></div>
            <div class="stat-card"><h3>Disk Usage</h3><div class="value">Loading...</div></div>
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
        <p>© 2026 Service Load Monitor v3.0.4</p>
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
                        }
                    }
                });
        }

        refreshData();
        setInterval(refreshData, 10000);
    </script>
</body>
</html>
HTML

    chmod -R 755 "${DASHBOARD_DIR}"
    print_substep "Dashboard files created"
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
    PIHOLE_STATUS="inactive"
    if command -v pihole &>/dev/null; then
        if systemctl is-active --quiet pihole-FTL.service 2>/dev/null; then
            PIHOLE_STATUS="active"
        fi
    fi

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
    "pihole": {
        "status": "$PIHOLE_STATUS"
    }
}
JSON

    sleep 30
done
EOF

    chmod +x "${DASHBOARD_SCRIPT}"
    print_substep "Dashboard scripts created - SILENT mode"
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
    mkdir -p "${CONFIG_BASE_DIR}" "${DASHBOARD_DIR}" "${BACKUP_DIR}" "$(dirname "${LOG_FILE}")"
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
    print_success "Dashboard created"
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
    echo ""
    echo -e "${GREEN}Thank you for using Service Load Monitor v3.0.4!${NC}"
    echo ""
}

# =============================================================================
# REMOVAL FUNCTION
# =============================================================================

remove_monitor() {
    print_banner
    echo -e "${RED}Removing Service Load Monitor...${NC}"

    systemctl stop service-monitor.service 2>/dev/null
    systemctl stop service-monitor-http.service 2>/dev/null
    systemctl stop service-monitor-updater.service 2>/dev/null

    systemctl disable service-monitor.service 2>/dev/null
    systemctl disable service-monitor-http.service 2>/dev/null
    systemctl disable service-monitor-updater.service 2>/dev/null

    rm -f "${MONITOR_SCRIPT}" "${SERVICE_FILE}" "${DASHBOARD_SCRIPT}"
    rm -f "${DASHBOARD_HTTP_SERVICE}" "${DASHBOARD_UPDATER_SERVICE}"

    echo -e "${YELLOW}Remove configuration and data? (y/N)${NC}"
    read -p "> " remove_data
    if [[ "${remove_data}" =~ ^[Yy]$ ]]; then
        rm -rf "${CONFIG_BASE_DIR}" "${LIB_BASE_DIR}" "${DASHBOARD_DIR}"
        rm -f "${LOG_FILE}"*
    fi

    systemctl daemon-reload
    print_success "Removal complete"
}

# =============================================================================
# STATUS FUNCTION
# =============================================================================

show_status() {
    print_banner
    echo -e "${WHITE}Service Status:${NC}"
    echo ""

    systemctl is-active --quiet service-monitor.service && \
        echo -e "  • ${GREEN}●${NC} Monitor Service: Running" || \
        echo -e "  • ${RED}○${NC} Monitor Service: Stopped"

    systemctl is-active --quiet service-monitor-http.service 2>/dev/null && \
        echo -e "  • ${GREEN}●${NC} HTTP Server: Running" || \
        echo -e "  • ${RED}○${NC} HTTP Server: Stopped"

    systemctl is-active --quiet service-monitor-updater.service 2>/dev/null && \
        echo -e "  • ${GREEN}●${NC} Updater Service: Running" || \
        echo -e "  • ${RED}○${NC} Updater Service: Stopped"

    echo ""
    echo -e "${WHITE}Version:${NC} ${SCRIPT_VERSION}"
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
    echo -e "${BLUE}║${GREEN}  Version: 3.0.4 (SILENT Mode - No More Garbage)        ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Date:    February 18, 2026                             ${BLUE}║${NC}"
    echo -e "${BLUE}║${GREEN}  Website: https://www.wael.name                         ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
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
    echo "  5) Exit"
    echo ""
    echo -n -e "${YELLOW}Select option [1-5]: ${NC}"
}

show_logs() {
    if [[ -f "${LOG_FILE}" ]]; then
        tail -f "${LOG_FILE}"
    else
        print_error "Log file not found"
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    if [[ $# -gt 0 ]]; then
        case "$1" in
            install) install_monitor ;;
            remove) remove_monitor ;;
            status) show_status ;;
            logs) show_logs ;;
            version) echo "Service Load Monitor v${SCRIPT_VERSION}" ;;
            help)
                echo "Commands: install, remove, status, logs, version"
                ;;
            *) echo "Unknown command: $1"; exit 1 ;;
        esac
        exit 0
    fi

    while true; do
        show_menu
        read -r choice

        case "${choice}" in
            1) install_monitor; read -p "Press Enter to continue..." ;;
            2) remove_monitor; read -p "Press Enter to continue..." ;;
            3) show_status; read -p "Press Enter to continue..." ;;
            4) show_logs ;;
            5) echo -e "\n${GREEN}Goodbye!${NC}\n"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Run main function
main "$@"
