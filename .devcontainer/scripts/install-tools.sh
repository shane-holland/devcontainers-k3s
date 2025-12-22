#!/bin/bash
set -e

echo "Installing Kubernetes tools..."

ARCH="$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')"

# Install kubectl
echo "Installing kubectl..."
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
kubectl version --client

# Install Helm
echo "Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Install k9s
echo "Installing k9s..."
K9S_VERSION="v0.32.4"
wget -q "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz"
tar -xzf k9s_Linux_${ARCH}.tar.gz -C /usr/local/bin
rm k9s_Linux_${ARCH}.tar.gz
k9s version

# Install kubectx and kubens
echo "Installing kubectx and kubens..."
git clone --depth 1 https://github.com/ahmetb/kubectx /opt/kubectx
ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
ln -s /opt/kubectx/kubens /usr/local/bin/kubens

echo "All tools installed successfully"
