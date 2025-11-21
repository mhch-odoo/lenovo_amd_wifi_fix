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
if [ "$WIFI_DRIVER" != "ath11k_pci" ]; then
    log 2 "This script is intended for systems using the ath11k_pci Wi-Fi driver. If you still encounter Wi-Fi issues, please contact mhch@odoo.com with the following info."
    log 1 "Detected Wi-Fi driver: $WIFI_DRIVER \n$DRIVER_VERSION."
    exit 0
fi

# Install necessary packages
apt install -y iw wireless-tools

# Disable Wi-Fi power management
WIFI_INTERFACE=$(iw dev | awk '$1=="Interface"{print $2}' | head -n 1)
if [ -z "$WIFI_INTERFACE" ]; then
    log 3 "No Wi-Fi interface found. Exiting."
    exit 1
fi

log 1 "Disabling power management for Wi-Fi interface: $WIFI_INTERFACE"
sed -i 's/wifi.powersave = 3/wifi.powersave = 2/' /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
iwconfig $WIFI_INTERFACE power off

# Restart nm to apply changes
log 1 "Restarting NetworkManager..."
systemctl restart NetworkManager
log 2 "Wi-Fi power management has been disabled."

# Clone the to reset the ath11k_pci module on suspend/resume
log 1 "Cloning reset-wifi-module.sh script..."
TEMP_DIR=$(mktemp -d)
curl -fsSL -o $TEMP_DIR/reset-wifi-module.sh https://raw.githubusercontent.com/s-damian/thinkpad-t14-gen-5-amd-linux/main/sh/reset-wifi-module.sh
if [ $? -ne 0 ]; then
    log 3 "Failed to download reset-wifi-module.sh. Exiting..."
    rm -rf $TEMP_DIR
    exit 1
fi
mv $TEMP_DIR/reset-wifi-module.sh /lib/systemd/system-sleep/reset-wifi-module.sh
rm -rf $TEMP_DIR

chmod +x /lib/systemd/system-sleep/reset-wifi-module.sh
chown root:root /lib/systemd/system-sleep/reset-wifi-module.sh

sudo modprobe -r ath11k_pci && sudo modprobe ath11k_pci
log 2 "ath11k_pci module reloaded."

log 2 "Please reboot your system, and if you still experience Wi-Fi issues please contact mhch@odoo.com"
