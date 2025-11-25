#!/bin/bash

log() {
    case $1 in
        1) echo -e "\e[34m[INFO]\e[0m $2" ;;
        2) echo -e "\e[32m[SUCCESS]\e[0m $2" ;;
        3) echo -e "\e[31m[FAIL]\e[0m $2" ;;
        *) echo -e "\e[33m[UNKNOWN]\e[0m $2" ;;
    esac
}

# Require sudo privileges
if [ "$EUID" -ne 0 ]; then
    log 3 "This script must be run as root. Please use: sudo bash <script> or sudo bash <(curl -s <url>)"
    exit 1
fi

# This script is to only run on an Ubuntu system.
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "ubuntu" ]; then
        log 3 "This script is intended to run only on Ubuntu systems!"
        exit 1
    fi
else
    log 3 "Cannot determine the operating system. Exiting..."
    exit 1
fi

# Update package lists
log 1 "Updating package lists..."
apt update && apt upgrade -y
apt install -y lshw

# Check wireless interface driver
WIFI_DRIVER=$(lshw -C network | grep -A 12 "Wireless interface" | grep 'driver=' | grep -o 'driver=[^ ]*' | cut -d'=' -f2 | head -n 1)
DRIVER_VERSION=$(modinfo $WIFI_DRIVER | grep 'firmware:')

sed -i 's/wifi.powersave = 3/wifi.powersave = 2/' /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
log 2 "Disabled power saving for Wi-Fi in NetworkManager configuration."

if [ "$WIFI_DRIVER" != "ath11k_pci" ]; then
    log 2 "This script is intended for systems using the ath11k_pci Wi-Fi driver. If you still encounter Wi-Fi issues, please contact mhch@odoo.com with the following info."
    log 1 "Detected Wi-Fi driver: $WIFI_DRIVER \n$DRIVER_VERSION."
    exit 0
fi

# Install necessary packages
apt install -y iw wireless-tools

log 1 "Disabling power management for Wi-Fi interface: $WIFI_INTERFACE"
# Disable Wi-Fi power management
WIFI_INTERFACE=$(iw dev | awk '$1=="Interface"{print $2}' | head -n 1)
if [ -z "$WIFI_INTERFACE" ]; then
    log 3 "No Wi-Fi interface found. Exiting."
    exit 1
fi

iwconfig $WIFI_INTERFACE power off

# Restart nm to apply changes
log 1 "Restarting NetworkManager..."
systemctl restart NetworkManager
log 2 "Wi-Fi power management has been disabled."

# Clone the to reset the ath11k_pci module on suspend/resume
log 1 "Cloning reset-wifi-module.sh script..."

# Clones the script from https://github.com/s-damian/thinkpad-t14-gen-5-amd-linux

cat << 'EOF' > /lib/systemd/system-sleep/reset-wifi-module.sh
#!/bin/bash

# For path: /lib/systemd/system-sleep/reset-wifi-module.sh

# This script unloads and reloads the Qualcomm WiFi module around suspend

case "$1" in
    pre)
        logger "Reset-WiFi-Module-Script : ---------- [PRE-SUSPEND START] ----------"

        # Before suspend: unload the Qualcomm WiFi module
        logger "Reset-WiFi-Module-Script : [PRE-SUSPEND START] Unloading Qualcomm WiFi module:"
        modprobe -r ath11k_pci
        if [ $? -eq 0 ]; then
            logger "Reset-WiFi-Module-Script : [PRE-SUSPEND SUCCESS] Qualcomm module unloaded successfully."
        else
            logger "Reset-WiFi-Module-Script : [PRE-SUSPEND ERROR] Failed to unload Qualcomm module."
        fi

        logger "Reset-WiFi-Module-Script : ---------- [PRE-SUSPEND END] ----------"
        ;;
    post)
        logger "Reset-WiFi-Module-Script : ---------- [POST-RESUME START] ----------"

        # After resume: reload the Qualcomm WiFi module
        logger "Reset-WiFi-Module-Script : [POST-RESUME START] Reloading Qualcomm WiFi module:"
        modprobe ath11k_pci
        if [ $? -eq 0 ]; then
            logger "Reset-WiFi-Module-Script : [POST-RESUME SUCCESS] Qualcomm module reloaded successfully."
        else
            logger "Reset-WiFi-Module-Script : [POST-RESUME ERROR] Failed to reload Qualcomm module."
        fi

        logger "Reset-WiFi-Module-Script : ---------- [POST-RESUME END] ----------"
        ;;
esac
EOF

chmod +x /lib/systemd/system-sleep/reset-wifi-module.sh
chown root:root /lib/systemd/system-sleep/reset-wifi-module.sh

sudo modprobe -r ath11k_pci && sudo modprobe ath11k_pci
log 2 "ath11k_pci module reloaded."

log 2 "Please reboot your system, and if you still experience Wi-Fi issues please contact mhch@odoo.com"
