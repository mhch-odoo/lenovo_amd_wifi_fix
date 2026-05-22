# Ubuntu WiFi Fix

This script disables WiFi power management on Ubuntu to improve connectivity stability.

## Usage

### Fix power management
Run the script directly from GitHub without cloning the repository:

```bash
curl -s -o /tmp/ubuntu-wifi-power-management.sh https://raw.githubusercontent.com/mhch-odoo/lenovo_amd_wifi_fix/main/ubuntu-wifi-power-management.sh && sudo bash /tmp/ubuntu-wifi-power-management.sh
```

### install IWD

```bash
curl -s -o /tmp/iwd_install.sh https://raw.githubusercontent.com/mhch-odoo/lenovo_amd_wifi_fix/main/iwd_install.sh;
chmod +x /tmp/iwd_install.sh;
/tmp/iwd_install.sh i;
```

## Prerequisites

- Ensure `curl` is installed on your system.
