#!/bin/bash
set -e

# Function to get k3s logs on failure
get_k3s_logs() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        echo "=========================================="
        echo "FAILURE DIAGNOSTICS"
        echo "=========================================="
        echo ""

        echo "All k3d containers:"
        docker ps -a --filter "name=k3d-devcontainer" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}" || true
        echo ""

        echo "=========================================="
        echo "K3S SERVER LOGS (last 100 lines):"
        echo "=========================================="
        docker logs --tail 100 k3d-devcontainer-server-0 2>&1 || echo "Server container not found or no logs available"
        echo ""

        echo "=========================================="
        echo "K3S AGENT LOGS (last 100 lines):"
        echo "=========================================="
        docker logs --tail 100 k3d-devcontainer-agent-0 2>&1 || echo "Agent container not found or no logs available"
        echo ""

        echo "=========================================="
        echo "Docker daemon logs (last 50 lines):"
        echo "=========================================="
        tail -50 /var/log/dockerd.log 2>&1 || echo "Docker daemon logs not available"
        echo ""
    fi
}

# Trap to get logs on error
trap get_k3s_logs EXIT

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
  echo ""

  # Check if Docker can run privileged containers
  echo "Testing Docker capabilities..."
  if docker run --rm --privileged alpine sh -c "echo 'Privileged containers work!'" > /dev/null 2>&1; then
    echo "✅ Docker can create privileged containers"
  else
    echo "❌ ERROR: Docker cannot create privileged containers"
    echo "This is required for k3s to work in DinD"
    exit 1
  fi
  echo ""

  if [ -f "${K3D_CONFIG}" ]; then
    echo "Using configuration: ${K3D_CONFIG}"
    echo "Creating cluster with k3d..."
    echo ""

    # Create cluster with retry logic for transient network issues
    max_attempts=3
    attempt=1
    cluster_created=false

    while [ $attempt -le $max_attempts ]; do
      echo "Attempt $attempt/$max_attempts..."

      # Use --api-port to force k3d to expose API on port 6443 instead of random port
      if k3d cluster create --config "${K3D_CONFIG}" --api-port 6443 --verbose; then
        cluster_created=true
        break
      fi

      echo ""
      echo "⚠️  Cluster creation failed (attempt $attempt/$max_attempts)"

      if [ $attempt -lt $max_attempts ]; then
        echo "Retrying in 5 seconds..."
        sleep 5
        # Clean up any partial resources
        k3d cluster delete "${CLUSTER_NAME}" 2>/dev/null || true
        attempt=$((attempt + 1))
      else
        echo ""
        echo "❌ Cluster creation failed after $max_attempts attempts!"
        echo ""
        echo "Attempting to get k3s container logs..."
        sleep 2

        # Try to get logs from any k3s containers that were created
        for container in $(docker ps -a --filter "name=k3d-${CLUSTER_NAME}" --format "{{.Names}}"); do
          echo "=== Logs from $container ==="
          docker logs --tail 50 "$container" 2>&1 || echo "Could not get logs"
          echo ""
        done

        exit 1
      fi
    done

    if [ "$cluster_created" = false ]; then
      exit 1
    fi

  else
    echo "Config file not found, using default settings..."
    # Default cluster creation with DinD-compatible settings
    k3d cluster create "${CLUSTER_NAME}" \
      --api-port 6443 \
      --port "8080:80@loadbalancer" \
      --port "8443:443@loadbalancer" \
      --agents 1 \
      --k3s-arg "--disable=traefik@server:*" \
      --verbose \
      --wait
  fi

  echo ""
  echo "Cluster creation completed, verifying status..."
  sleep 3
fi

# Show container status
echo ""
echo "K3D containers:"
docker ps --filter "name=k3d-${CLUSTER_NAME}" --format "table {{.Names}}\t{{.Status}}"
echo ""

# Set up kubeconfig
mkdir -p ~/.kube

# Generate kubeconfig from k3d
echo "Generating kubeconfig..."
k3d kubeconfig get "${CLUSTER_NAME}" > ~/.kube/config.tmp

# Fix kubeconfig server address for DinD
# k3d generates kubeconfig with 0.0.0.0 which doesn't work inside the container
# We need to use 127.0.0.1 with the mapped port 6443
echo "Fixing kubeconfig server address for Docker-in-Docker..."
sed 's|server: https://0.0.0.0:[0-9]*|server: https://127.0.0.1:6443|g' ~/.kube/config.tmp > ~/.kube/config
rm ~/.kube/config.tmp

chmod 600 ~/.kube/config

# Explicitly set KUBECONFIG to ensure kubectl uses our fixed config
export KUBECONFIG=~/.kube/config

# Add KUBECONFIG to shell profile so it persists in new shells
if ! grep -q "KUBECONFIG=~/.kube/config" /root/.bashrc 2>/dev/null; then
    echo "" >> /root/.bashrc
    echo "# Set kubeconfig for k3d cluster" >> /root/.bashrc
    echo "export KUBECONFIG=~/.kube/config" >> /root/.bashrc
    echo "✅ Added KUBECONFIG to /root/.bashrc"
fi

echo "Kubeconfig server address:"
grep "server:" ~/.kube/config

# Verify the kubeconfig is correct
KUBE_SERVER=$(grep "server:" ~/.kube/config | awk '{print $2}')
echo "Kubectl will connect to: ${KUBE_SERVER}"

if [[ "$KUBE_SERVER" != "https://127.0.0.1:6443" ]]; then
    echo "⚠️  Warning: Unexpected kubeconfig server address!"
    echo "Expected: https://127.0.0.1:6443"
    echo "Got: ${KUBE_SERVER}"
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
