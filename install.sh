#!/bin/bash

FB_ROOT="/opt/filebrowser_quantum"
FB_DB="$FB_ROOT/database"
FB_CONFIG="$FB_ROOT/config"
ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18)
SHARED_FILES="/filebrowser_quantum_data/shared_files"
USER_FILES="/filebrowser_quantum_data/user_files"
MY_FILES="/filebrowser_quantum_data/my_files"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <PORT> <ADMIN_USERNAME>"
  exit 1
fi

PORT=$1
ADMIN_USERNAME=$2

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || ((PORT < 1 || PORT > 65535)); then
  echo "Invalid port: $PORT"
  exit 1
fi

if ss -tln | grep -q ":$PORT"; then
    echo "Port $PORT is already in use. Please choose another port."
    exit 1
fi

if [[ -d "$FB_ROOT" || -f "$SERVICE_FILE" ]]; then
    echo "⚠️  FileBrowser Quantum appears to be already installed."
    echo "Please uninstall it first before running this script."
    exit 1
fi

echo "📁 Creating directories..."
for dir in "$FB_ROOT" "$FB_DB" "$FB_CONFIG" "$SHARED_FILES" "$USER_FILES" "$MY_FILES"; do
  [[ -d "$dir" ]] || sudo mkdir -p "$dir"
done

echo "Setting permissions..."
sudo chown -R $(whoami):$(whoami) "$FB_ROOT"
sudo chmod -R 755 "$FB_ROOT"

sudo chown -R $(whoami):$(whoami) "$FB_DB"
sudo chmod -R 755 "$FB_DB"

sudo chown -R $(whoami):$(whoami) "$FB_CONFIG"
sudo chmod -R 755 "$FB_CONFIG"

sudo chown -R $(whoami):$(whoami) "$SHARED_FILES"
sudo chmod -R 775 "$SHARED_FILES"   

sudo chown -R $(whoami):$(whoami) "$USER_FILES"
sudo chmod -R 750 "$USER_FILES"   

sudo chown -R $(whoami):$(whoami) "$MY_FILES"
sudo chmod -R 750 "$MY_FILES"   

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
    - path: "$SHARED_FILES"
      name: "Shared Files"
      config:
        defaultEnabled: true
    - path: "$MY_FILES"
      name: "My Files"
      config:
        private: true
    - path: "$USER_FILES"
      name: "User Files"
      config:
        createUserDir: true

auth:
  adminUsername: ${ADMIN_USERNAME}
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
Environment="FILEBROWSER_ADMIN_PASSWORD=$ADMIN_PASSWORD"
ExecStart=$FB_BIN -c $CONFIG_FILE
Restart=on-failure
RestartSec=3
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
echo "Admin username: $ADMIN_USERNAME"
echo "Admin password: $ADMIN_PASSWORD"
echo "⚠️  SECURITY NOTICE: You must change this password immediately after first login (within 5 minutes)."
echo "Access URL: http://$(hostname -I | awk '{print $1}'):$PORT"

if ! command -v at &>/dev/null; then
    echo "⏳ 'at' not found. Installing..."
    
    if [[ -f /etc/debian_version ]]; then
        sudo apt update -qq >/dev/null 2>&1
        sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq at >/dev/null 2>&1
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum install -y -q at >/dev/null 2>&1
    else
        echo "❌ Unsupported Linux distribution. Please install 'at' manually."
        exit 1
    fi
fi

sudo systemctl enable --now atd >/dev/null 2>&1

echo "sudo sed -i '/Environment=FILEBROWSER_ADMIN_PASSWORD/d' /etc/systemd/system/filebrowser-quantum.service && sudo systemctl daemon-reload && sudo systemctl restart filebrowser-quantum" | at now + 5 minutes
