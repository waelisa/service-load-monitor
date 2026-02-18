![Service Load Monitor Dashboard](https://github.com/waelisa/service-load-monitor/blob/main/Service-Load-Monitor.png?raw=true)

# **🚀 Service Load Monitor**

An enterprise-grade, "self-healing" system monitoring agent for Linux. This script goes beyond simple alerts by intelligently identifying high-load processes and automatically recovering services to ensure maximum uptime.

## **🌟 Features**

*   **Intelligent targeted recovery:** Detects which specific service is causing a load spike and restarts _only_ that service.
*   **PC & Server awareness:** Smart enough to protect desktop applications (browsers, editors) while managing backend services.
*   **I/O Wait (D-State) detection:** Identifies processes stuck in "Uninterruptible Sleep" (disk bottlenecks) which standard load monitors often miss.
*   **Dynamic thresholds:** Automatically calculates optimal load thresholds based on your CPU core count.
*   **Web Dashboard:** Real-time HTML status dashboard with auto-refresh.
*   **Automatic firewall management:** Detects and configures UFW or Firewalld automatically.
*   **Backup & Restore:** Safety-first approach with automated configuration backups.
*   **Cloud Ready:** Built-in awareness for AWS, Oracle Cloud, and Azure security environments.

## **🛠 Installation**

You can install the Service Load Monitor with a single command:

Bash

wget -O service-load-monitor.sh https://github.com/waelisa/service-load-monitor/raw/refs/heads/main/service-load-monitor.sh && chmod +x service-load-monitor.sh && sudo ./service-load-monitor.sh

## **📋 Requirements**

The script is designed to be universal and handles its own dependency installation. It supports:

*   **Distros:** Ubuntu, Debian, CentOS, RHEL, Fedora, Arch Linux.
*   **System Manager:** Systemd.
*   **Dependencies:** curl, awk, procps, net-tools (all auto-installed if missing).

## **🚀 Usage**

Simply run the script with root privileges to access the management menu:

Bash

sudo ./service-load-monitor.sh

### **Menu Options:**

1.  **Install/Update Monitor:** Set up the background service.
2.  **Remove Monitor:** Cleanly uninstall all files and services.
3.  **Show Status:** View real-time service health and logs.
4.  **View Logs:** Tail the monitor's activity log.
5.  **Backup/Restore:** Manage your configuration safety nets.

## **🌐 Web Dashboard**

Once installed, you can monitor your server health from any browser at: http://your-server-ip:8080

_Note: If you are using a Cloud Provider (AWS/Oracle), ensure you open port 8080 in your Cloud Console Security Group._

## **🤝 Contributing**

Feel free to fork this project, report issues, or submit pull requests. For custom modifications or help, visit [https://github.com/waelisa/service-load-monitor](https://github.com/waelisa/service-load-monitor).

## **☕ Support the Project**

If this script saved your server (and your sleep!) at 3 AM, consider supporting the development:

[**Donate via PayPal**](https://www.paypal.me/WaelIsa)

**Author:** Wael Isa

**Website:** [www.wael.name](https://www.wael.name/)

**License:** MIT
