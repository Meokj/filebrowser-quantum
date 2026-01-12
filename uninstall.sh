#!/bin/bash

echo "🛑 Stopping FileBrowser Quantum service..."
sudo systemctl stop filebrowser-quantum 2>/dev/null
sudo systemctl disable filebrowser-quantum 2>/dev/null

SERVICE_FILE="/etc/systemd/system/filebrowser-quantum.service"
if [ -f "$SERVICE_FILE" ]; then
    echo "Removing systemd service..."
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
fi

FB_ROOT="/opt/filebrowser_quantum"
DATA_DIR="/filebrowser_quantum_data"

echo "Removing FileBrowser files..."
sudo rm -rf "$FB_ROOT"

read -p "Do you want to remove the data directory '$DATA_DIR'? [y/N]: " REMOVE_DATA
REMOVE_DATA=${REMOVE_DATA,,} 

if [[ "$REMOVE_DATA" == "y" || "$REMOVE_DATA" == "yes" ]]; then
    echo "Removing data directory..."
    sudo rm -rf "$DATA_DIR"
else
    echo "Skipping data directory."
fi

echo "✅ FileBrowser Quantum has been uninstalled."
