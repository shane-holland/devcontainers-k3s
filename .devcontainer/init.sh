#!/bin/bash

echo "Starting initialization..."

# Install k3s binary if not already present
if ! command -v k3s &> /dev/null; then
    echo ""
    echo "Installing k3s binary..."

    K3S_VERSION="v1.31.4+k3s1"
    ARCH="$(uname -m | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')"
    K3S_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-${ARCH}"

    echo "Downloading k3s ${K3S_VERSION} for ${ARCH}..."
    echo "URL: ${K3S_URL}"

    # Download with retry logic
    if wget --retry-connrefused --waitretry=5 --read-timeout=30 --timeout=20 --tries=10 \
        --progress=bar:force \
        -O /tmp/k3s "${K3S_URL}"; then

        echo "Installing k3s binary..."
        sudo mv /tmp/k3s /usr/local/bin/k3s
        sudo chmod +x /usr/local/bin/k3s

        # Create symlinks
        sudo ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
        sudo ln -sf /usr/local/bin/k3s /usr/local/bin/crictl

        echo "k3s installed successfully:"
        k3s --version
    else
        echo "ERROR: Failed to download k3s binary"
        echo "You may be experiencing network issues or GitHub rate limiting"
        echo "You can manually download k3s from: ${K3S_URL}"
        echo "Then place it at /usr/local/bin/k3s and run: chmod +x /usr/local/bin/k3s"
        exit 1
    fi
else
    echo "k3s binary already installed: $(k3s --version | head -n1)"
fi

# Check if k3s is already running
if pgrep -x "k3s" > /dev/null; then
    echo "k3s is already running"
else
    echo ""
    echo "Starting k3s server (without systemd)..."

    # Start k3s server in the background
    # Key flags:
    #   --write-kubeconfig-mode=644: Makes kubeconfig readable by vscode user
    #   --disable=traefik: Disable traefik ingress controller (optional, reduces resource usage)
    #   --snapshotter=native: Use native snapshotter (better compatibility)
    sudo k3s server \
        --write-kubeconfig-mode=644 \
        --disable=traefik \
        --snapshotter=native \
        > /tmp/k3s.log 2>&1 &

    # Wait for k3s to be ready
    echo "Waiting for k3s to be ready..."
    MAX_WAIT=60
    COUNTER=0
    while ! sudo k3s kubectl get nodes >/dev/null 2>&1; do
        if [ $COUNTER -ge $MAX_WAIT ]; then
            echo "Error: k3s not ready within ${MAX_WAIT} seconds"
            echo "k3s logs:"
            tail -50 /tmp/k3s.log
            exit 1
        fi
        sleep 2
        COUNTER=$((COUNTER + 2))
        echo -n "."
    done
    echo ""
    echo "k3s is ready!"
fi

# Set up kubeconfig for vscode user
echo ""
echo "Setting up kubeconfig..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

# Verify kubectl is working
echo ""
echo "Verifying kubectl..."
if kubectl version --short 2>/dev/null || kubectl version 2>/dev/null; then
    echo "kubectl: OK"
else
    echo "Warning: kubectl not working"
fi

# Verify cluster connection
echo ""
echo "Verifying cluster connection..."
if kubectl cluster-info; then
    echo ""
    echo "Cluster nodes:"
    kubectl get nodes
    echo ""
    echo "System pods:"
    kubectl get pods -A
else
    echo "Warning: Cannot connect to cluster"
fi

echo ""
echo "Initialization complete!"
echo ""
echo "You can now use Kubernetes commands:"
echo "  - kubectl get nodes"
echo "  - kubectl get pods -A"
echo "  - helm list"
echo ""
echo "k3s logs are available at: /tmp/k3s.log"
echo ""
