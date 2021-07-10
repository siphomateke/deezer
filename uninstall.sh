#!/bin/bash

printf "\nPlease enter with your root password to proceed.\n"
sudo true

printf "\nUninstalling Deezer... "
sudo rm -rf /usr/share/deezer &> /dev/null || true
sudo rm /usr/share/applications/deezer.desktop &> /dev/null || true
sudo rm /usr/bin/deezer &> /dev/null || true

for size in 16 32 48 64 128 256; do
    sudo rm /usr/share/icons/hicolor/${size}x${size}/apps/deezer.png &> /dev/null || true
done

sudo update-desktop-database --quiet

printf "OK.\nDeezer has been uninstalled.\n\n"
