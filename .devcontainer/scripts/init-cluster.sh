#!/bin/bash
set -e

CLUSTER_NAME="${K3D_CLUSTER_NAME:-devcontainer}"
K3D_CONFIG="/opt/devcontainer/config/k3d-config.yaml"

# Ensure Docker daemon is ready
echo "Checking Docker daemon..."
timeout=30
elapsed=0
while ! docker info > /dev/null 2>&1; do
    if [ $elapsed -ge $timeout ]; then
        echo "ERROR: Docker daemon is not ready after ${timeout} seconds"
        exit 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done
echo "✅ Docker daemon is ready"

echo "Initializing k3d cluster: ${CLUSTER_NAME}"

# Check if cluster already exists
if k3d cluster list | grep -q "${CLUSTER_NAME}"; then
  echo "Cluster '${CLUSTER_NAME}' already exists"

  # Check if it's running
  if k3d cluster list "${CLUSTER_NAME}" 2>/dev/null | grep -q "stopped"; then
    echo "Starting existing cluster..."
    k3d cluster start "${CLUSTER_NAME}"
  else
    echo "Cluster is already running"
  fi
else
  echo "Creating new k3d cluster..."

  if [ -f "${K3D_CONFIG}" ]; then
    echo "Using configuration: ${K3D_CONFIG}"

    # Create cluster with retry logic for transient network issues
    max_attempts=3
    attempt=1
    cluster_created=false

    while [ $attempt -le $max_attempts ]; do
      echo "Attempt $attempt/$max_attempts..."

      # Use --api-port to force k3d to expose API on port 6443
      if k3d cluster create --config "${K3D_CONFIG}" --api-port 6443 2>&1; then
        cluster_created=true
        break
      fi

      echo "⚠️  Cluster creation failed (attempt $attempt/$max_attempts)"

      if [ $attempt -lt $max_attempts ]; then
        echo "Retrying in 5 seconds..."
        sleep 5
        k3d cluster delete "${CLUSTER_NAME}" 2>/dev/null || true
        attempt=$((attempt + 1))
      else
        echo "❌ Cluster creation failed after $max_attempts attempts!"
        echo "Check logs with: docker logs k3d-${CLUSTER_NAME}-server-0"
        exit 1
      fi
    done

    if [ "$cluster_created" = false ]; then
      exit 1
    fi

  else
    echo "Config file not found, using default settings..."
    k3d cluster create "${CLUSTER_NAME}" \
      --api-port 6443 \
      --port "8080:80@loadbalancer" \
      --port "8443:443@loadbalancer" \
      --agents 1 \
      --k3s-arg "--disable=traefik@server:*" \
      --wait
  fi

  echo "Cluster created successfully!"
  sleep 2
fi

# Show container status
echo ""
echo "K3D containers:"
docker ps --filter "name=k3d-${CLUSTER_NAME}" --format "table {{.Names}}\t{{.Status}}"
echo ""

# Set up kubeconfig
mkdir -p ~/.kube

# Generate kubeconfig from k3d
echo "Configuring kubeconfig..."
k3d kubeconfig get "${CLUSTER_NAME}" > ~/.kube/config.tmp

# Fix kubeconfig server address for DinD
# k3d generates kubeconfig with 0.0.0.0 which doesn't work inside the container
sed 's|server: https://0.0.0.0:[0-9]*|server: https://127.0.0.1:6443|g' ~/.kube/config.tmp > ~/.kube/config
rm ~/.kube/config.tmp
chmod 600 ~/.kube/config

# Export KUBECONFIG for current session
export KUBECONFIG=~/.kube/config

# Add KUBECONFIG to shell profile for future sessions
if ! grep -q "KUBECONFIG=~/.kube/config" /root/.bashrc 2>/dev/null; then
    echo "" >> /root/.bashrc
    echo "# Set kubeconfig for k3d cluster" >> /root/.bashrc
    echo "export KUBECONFIG=~/.kube/config" >> /root/.bashrc
fi

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo ""
echo "✅ Cluster ready!"
echo ""
kubectl get nodes
echo ""
echo "System pods:"
kubectl get pods -A
echo ""
echo "Use 'kubectl' to interact with the cluster"
echo "Use 'k9s' for a terminal UI"
echo ""
