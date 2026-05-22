#!/bin/bash
action="install"
netWorkManagerConf="/etc/NetworkManager/NetworkManager.conf"
iwdConf="/etc/iwd/main.conf"

if [ -n "$1" ]
then
    action=$1
fi

case "$action" in
    install|i)
        echo "installing IWD ..."
        sudo apt update
        sudo apt upgrade -y
        sudo apt autoremove -y
        sudo apt install iwd -y

        if ! grep -q "wifi.backend=iwd" $netWorkManagerConf
        then
            echo "wifi.backend=iwd" | sudo tee -a $netWorkManagerConf
        fi

        if ! grep -q "AutoConnect=True" $iwdConf
        then
            echo "[Settings]" | sudo tee -a $iwdConf
            echo "AutoConnect=True" | sudo tee -a $iwdConf
        fi

        sudo rm -f /etc/NetworkManager/system-connections/*
        sudo rm -f /etc/netplan/*
        sudo systemctl mask --now wpa_supplicant.service
        sudo systemctl unmask --now iwd.service
        sudo systemctl enable iwd.service
        sudo systemctl start iwd.service
        sudo systemctl restart NetworkManager
        sudo reboot
      ;;

    remove|r)
        echo "Removing IWD ..."
        sudo sed -i '/wifi.backend=iwd/d' $netWorkManagerConf
        sudo sed -i '/wifi.iwd.autoconnect/d' $netWorkManagerConf
        sudo systemctl stop iwd.service
        sudo systemctl mask --now iwd.service
        sudo apt autoremove --purge -y iwd
        sudo systemctl unmask --now wpa_supplicant.service
        sudo systemctl enable wpa_supplicant.service
        sudo systemctl start wpa_supplicant.service
        sudo systemctl restart NetworkManager
        sudo reboot
      ;;

    *)
        echo -e "Usage :\n  For installing : $0 install or $0 i \n  To uninstall: $0 remove or $0 r\n  Install is the default mode"
      ;;
esac

sudo reboot
