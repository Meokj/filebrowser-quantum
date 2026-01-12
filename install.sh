#!/bin/bash

FB_ROOT="/opt/filebrowser_quantum"
FB_DB="$FB_ROOT/database"
FB_CONFIG="$FB_ROOT/config"
DATA_DIR="/filebrowser_quantum_data"  
PORT=$1
ADMINUSERNAME=$2
ADMIN_PASSWORD="StrongPassword123"   

mkdir -p "$FB_ROOT" "$FB_DB" "$FB_CONFIG"

if [ ! -d "$DATA_DIR" ]; then
    echo "Creating $DATA_DIR directory..."
    sudo mkdir -p "$DATA_DIR"
fi

echo "Setting permissions..."
sudo chown -R $(whoami):$(whoami) "$FB_ROOT"
sudo chmod -R 755 "$FB_ROOT"

sudo chown -R $(whoami):$(whoami) "$FB_DB"
sudo chmod -R 755 "$FB_DB"

sudo chown -R $(whoami):$(whoami) "$FB_CONFIG"
sudo chmod -R 755 "$FB_CONFIG"

sudo chown -R $(whoami):$(whoami) "$DATA_DIR"
sudo chmod -R 777 "$DATA_DIR"   

FB_URL="https://github.com/gtsteffaniak/filebrowser/releases/latest/download/linux-amd64-filebrowser"
FB_BIN="$FB_ROOT/filebrowser-quantum"

if [ ! -f "$FB_BIN" ]; then
    echo "Downloading FileBrowser Quantum..."
    curl -L "$FB_URL" -o "$FB_BIN"
    chmod +x "$FB_BIN"
fi

CONFIG_FILE="$FB_CONFIG/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<EOL
server:
  port: $PORT
  sources:
    - path: "$DATA_DIR"
      config:
        defaultEnabled: true

auth:
  adminUsername: ${ADMINUSERNAME}
  methods:
    password:
      enabled: true
      minLength: 8
EOL
fi

SERVICE_FILE="/etc/systemd/system/filebrowser-quantum.service"
if [ ! -f "$SERVICE_FILE" ]; then
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=FileBrowser Quantum
After=network.target

[Service]
Type=simple
Environment=FILEBROWSER_ADMIN_PASSWORD=$ADMIN_PASSWORD
ExecStart=$FB_BIN -c $CONFIG_FILE
Restart=on-failure
User=$(whoami)
WorkingDirectory=$FB_ROOT

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable filebrowser-quantum
fi

sudo systemctl start filebrowser-quantum
echo "Waiting for service to start..."
sleep 5

sudo sed -i '/Environment=FILEBROWSER_ADMIN_PASSWORD/d' /etc/systemd/system/filebrowser-quantum.service
sudo systemctl daemon-reload
sudo systemctl restart filebrowser-quantum

echo "✅ FileBrowser Quantum has been deployed!"
echo "Admin username: $ADMINUSERNAME"
echo "Admin password: $ADMIN_PASSWORD (can be changed in Web UI)"
echo "Access URL: http://$(hostname -I | awk '{print $1}'):$PORT"
