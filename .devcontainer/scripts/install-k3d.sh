#!/bin/bash
set -e

echo "Installing k3d..."

K3D_VERSION="v5.7.4"
ARCH="$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')"

wget -q -O /tmp/k3d "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-${ARCH}"
chmod +x /tmp/k3d
mv /tmp/k3d /usr/local/bin/k3d

k3d version
echo "k3d installed successfully"
