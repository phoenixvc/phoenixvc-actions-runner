#!/bin/bash
# Install GitHub Actions Scale Set Client for phoenixvc org
# Run on the listener VM after Terraform creates it.
set -e

APP_ID="${GITHUB_APP_ID:?Set GITHUB_APP_ID}"
INSTALLATION_ID="${GITHUB_INSTALLATION_ID:?Set GITHUB_INSTALLATION_ID}"
KEY_PATH="${GITHUB_APP_KEY_PATH:-/etc/phoenixvc-runner/key.pem}"
ORG="${GITHUB_ORG:-phoenixvc}"
SCALE_SET_NAME="${SCALE_SET_NAME:-azure-vnet}"

sudo mkdir -p /etc/phoenixvc-runner
sudo chown "$USER" /etc/phoenixvc-runner

if [ ! -f "$KEY_PATH" ]; then
  echo "Place the GitHub App private key at $KEY_PATH"
  exit 1
fi

if ! command -v go &>/dev/null; then
  echo "Installing Go..."
  curl -sL https://go.dev/dl/go1.21.0.linux-amd64.tar.gz | sudo tar -C /usr/local -xzf -
  export PATH="/usr/local/go/bin:$PATH"
fi

cd /tmp
git clone --depth 1 https://github.com/actions/scaleset.git
cd scaleset
go build -o scaleset-client .
sudo mv scaleset-client /usr/local/bin/

cat << EOF | sudo tee /etc/phoenixvc-runner/config.yaml
github:
  url: https://github.com
  org: $ORG
  app_id: $APP_ID
  installation_id: $INSTALLATION_ID
  private_key_path: $KEY_PATH

scale_set:
  name: $SCALE_SET_NAME
EOF

sudo chmod 600 /etc/phoenixvc-runner/config.yaml

cat << 'SVC' | sudo tee /etc/systemd/system/phoenixvc-scale-set.service
[Unit]
Description=phoenixvc GitHub Actions Scale Set Client
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/scaleset-client --config /etc/phoenixvc-runner/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVC

sudo systemctl daemon-reload
echo "Run: sudo systemctl enable --now phoenixvc-scale-set"
