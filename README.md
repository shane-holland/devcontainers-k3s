# Kubernetes DevContainer

A complete Kubernetes development environment using k3d (k3s in Docker) with Docker-in-Docker support.

## What's Inside

This devcontainer provides a complete Kubernetes development environment with:

- **Docker**: Full Docker Engine for running containers
- **k3d**: k3s (lightweight Kubernetes) running in Docker containers
- **kubectl**: Kubernetes command-line tool
- **Helm**: Kubernetes package manager
- **k9s**: Terminal-based Kubernetes UI
- **kubectx/kubens**: Quick context and namespace switching

## How It Works

### k3d with Docker-in-Docker

This setup uses [k3d](https://k3d.io/) to run [k3s](https://k3s.io/) Kubernetes clusters inside Docker containers:

- **Docker-in-Docker**: Full Docker daemon running inside the devcontainer
- **k3d managed cluster**: Multi-node k3s cluster orchestrated by k3d
- **Automated setup**: Cluster created automatically on container start
- **Full-featured**: Complete Kubernetes API (certified distribution)
- **Development optimized**: Fast cluster creation/destruction for testing

## Getting Started

### Prerequisites

- **Docker Desktop** (macOS, Windows, or Linux)
  - macOS: [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
  - Windows: [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/) with WSL2
  - Linux: [Docker Engine](https://docs.docker.com/engine/install/) or Docker Desktop

- **VS Code** with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Usage

1. **Open in DevContainer**
   - Open this folder in VS Code
   - Click "Reopen in Container" when prompted
   - Or: Press `F1` → "Dev Containers: Rebuild and Reopen in Container"

2. **Wait for Initialization**
   - Docker daemon starts first (~10-20 seconds)
   - k3d cluster is created automatically (~30-60 seconds on first launch)
   - Subsequent starts reuse existing cluster (much faster)

3. **Verify Setup**
   ```bash
   # Check Docker is running
   docker ps

   # Check k3d cluster
   k3d cluster list

   # Check Kubernetes nodes
   kubectl get nodes

   # Check cluster info
   kubectl cluster-info

   # Check system pods
   kubectl get pods -A
   ```

## Configuration

### Devcontainer Settings

Key configuration in [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json):

```json
{
  "name": "Kubernetes Development (k3d)",
  "privileged": true,
  "runArgs": ["--cgroupns=host"],
  "remoteUser": "root",
  "postCreateCommand": "/opt/devcontainer/scripts/start-docker.sh",
  "postStartCommand": "/opt/devcontainer/scripts/init-cluster.sh",
  "forwardPorts": [6443, 8080, 8443]
}
```

**Why these settings?**

- `privileged: true` - Required for Docker-in-Docker to manage nested containers
- `runArgs: ["--cgroupns=host"]` - **Critical for cgroup v2 delegation** in Docker-in-Docker environments. Without this, k3s cannot access memory cgroup controllers and will fail to start
- `remoteUser: root` - Docker daemon requires root privileges
- `postCreateCommand` - Starts Docker daemon when container is first created
- `postStartCommand` - Creates/starts k3d cluster on every container start
- `forwardPorts` - Exposes Kubernetes API (6443) and LoadBalancer ports (8080, 8443)

### k3d Cluster Configuration

The cluster is configured in [.devcontainer/config/k3d-config.yaml](.devcontainer/config/k3d-config.yaml):

```yaml
apiVersion: k3d.io/v1alpha5
kind: Simple
metadata:
  name: devcontainer
servers: 1
agents: 1
ports:
  - port: 8080:80
    nodeFilters:
      - loadbalancer
  - port: 8443:443
    nodeFilters:
      - loadbalancer
  - port: 6443:6443
    nodeFilters:
      - server:0

# Mount DinD container's cgroups into k3s containers for proper cgroup v2 support
volumes:
  - volume: /sys/fs/cgroup:/sys/fs/cgroup:rw
    nodeFilters:
      - server:*
      - agent:*

options:
  k3s:
    extraArgs:
      - arg: --disable=traefik
        nodeFilters:
          - server:*
      # Use native snapshotter for DinD compatibility (overlayfs doesn't work in nested containers)
      - arg: --snapshotter=native
        nodeFilters:
          - server:*
          - agent:*
```

**Key Docker-in-Docker configurations:**

- `volumes: /sys/fs/cgroup:/sys/fs/cgroup:rw` - **Critical:** Mounts cgroup filesystem from DinD container into k3s containers for proper resource management
- `--snapshotter=native` - **Required for DinD:** The default overlayfs snapshotter doesn't work in nested containers. The native snapshotter is slower but compatible with Docker-in-Docker
- `port: 6443:6443` - Maps Kubernetes API server port to host for kubectl access
- k3s auto-detects the cgroup driver (cgroupfs) - systemd is not available in container environments

**Customization options:**

- `servers: 1` - Number of server nodes (control plane)
- `agents: 1` - Number of agent nodes (workers)
- `--disable=traefik` - Removes traefik ingress controller. Remove this to enable it.
- Add `--disable=servicelb` to disable the built-in load balancer
- Add `--disable=local-storage` to disable the built-in storage provisioner

## Common Tasks

### Managing the Cluster

```bash
# List k3d clusters
k3d cluster list

# Stop the cluster
k3d cluster stop devcontainer

# Start the cluster
k3d cluster start devcontainer

# Delete the cluster
k3d cluster delete devcontainer

# Recreate the cluster
k3d cluster delete devcontainer
/opt/devcontainer/scripts/init-cluster.sh

# View cluster nodes
kubectl get nodes

# View all resources
kubectl get all -A
```

### Managing Docker

```bash
# Check Docker status
docker info

# View running containers
docker ps

# View k3d containers
docker ps --filter "name=k3d"

# View Docker logs for k3s server
docker logs k3d-devcontainer-server-0

# View Docker logs for k3s agent
docker logs k3d-devcontainer-agent-0
```

### Deploying Applications

```bash
# Create a deployment
kubectl create deployment nginx --image=nginx

# Expose as LoadBalancer service
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check status
kubectl get all

# Access via LoadBalancer (maps to localhost:8080)
curl localhost:8080
```

### Using Helm

```bash
# Add a repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Search for charts
helm search repo redis

# Install a chart
helm install my-redis bitnami/redis

# List releases
helm list

# Uninstall
helm uninstall my-redis
```

### Using k9s

```bash
# Launch k9s
k9s

# Common shortcuts:
# :pod    - View pods
# :svc    - View services
# :deploy - View deployments
# :node   - View nodes
# /       - Filter resources
# d       - Describe resource
# l       - View logs
# s       - Shell into container
# :q      - Quit
```

## Troubleshooting

### Docker daemon not starting

1. **Check Docker daemon logs**:
   ```bash
   cat /var/log/dockerd.log
   ```

2. **Restart Docker daemon**:
   ```bash
   pkill dockerd
   /opt/devcontainer/scripts/start-docker.sh
   ```

3. **Common issues**:
   - **Permission denied**: Make sure container runs with `privileged: true`
   - **cgroup errors**: cgroups are configured automatically by the start script
   - **Storage driver issues**: We use `vfs` driver for compatibility

### k3d cluster not starting

1. **Check k3d cluster status**:
   ```bash
   k3d cluster list
   docker ps --filter "name=k3d"
   ```

2. **View k3s logs**:
   ```bash
   docker logs k3d-devcontainer-server-0
   docker logs k3d-devcontainer-agent-0
   ```

3. **Recreate cluster**:
   ```bash
   k3d cluster delete devcontainer
   /opt/devcontainer/scripts/init-cluster.sh
   ```

4. **Common issues**:
   - **Cluster creation timeout**: First startup downloads images, can take 1-2 minutes
   - **Port conflicts**: Ports 6443, 8080, 8443 must be available
   - **Docker not ready**: Ensure Docker daemon is running with `docker info`
   - **cgroup errors** (`failed to find memory cgroup`): Make sure `--cgroupns=host` is in devcontainer.json runArgs
   - **overlayfs errors**: The native snapshotter should be configured in k3d-config.yaml

### kubectl cannot connect

If you see errors like `dial tcp 0.0.0.0:xxxxx: connect: connection refused`, the kubeconfig has the wrong server address.

1. **Check kubeconfig**:
   ```bash
   echo $KUBECONFIG
   cat ~/.kube/config | grep server:
   ```

2. **Fix kubeconfig** (already automated in init-cluster.sh):
   ```bash
   # k3d generates kubeconfig with 0.0.0.0 which doesn't work inside the container
   # Fix it to use 127.0.0.1:6443
   sed -i 's|server: https://0.0.0.0:[0-9]*|server: https://127.0.0.1:6443|g' ~/.kube/config
   ```

3. **Or regenerate kubeconfig manually**:
   ```bash
   k3d kubeconfig get devcontainer > ~/.kube/config
   sed -i 's|server: https://0.0.0.0:[0-9]*|server: https://127.0.0.1:6443|g' ~/.kube/config
   chmod 600 ~/.kube/config
   ```

4. **Test connection**:
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

**Why this happens**: k3d generates kubeconfig with `0.0.0.0:<random-port>` as the server address, which is not accessible from inside the devcontainer. The init-cluster.sh script automatically fixes this to use `127.0.0.1:6443`.

### Performance issues

- **First build is slow**: Base image, Docker, and tools are downloaded (cached for future rebuilds)
- **First cluster startup is slow**: k3s images are pulled (30-60 seconds, then cached)
- **High CPU during startup**: Normal - Docker and k3s are initializing
- **Slow kubectl commands**: Wait for cluster to be fully ready (`kubectl wait --for=condition=Ready nodes --all`)

## Architecture

### Why This Setup?

This configuration provides a robust Kubernetes development environment:

1. **Docker-in-Docker with k3d**
   - Full Docker environment inside devcontainer
   - k3d orchestrates multi-node k3s clusters
   - Easy cluster lifecycle management (create/delete/restart)
   - Isolated from host Docker (if any)

2. **Multi-node cluster**
   - 1 server node (control plane)
   - 1 agent node (worker)
   - Realistic multi-node testing environment
   - Can scale up by editing k3d-config.yaml

3. **LoadBalancer support**
   - Built-in load balancer for services
   - Port 8080 (HTTP) and 8443 (HTTPS) exposed to host
   - Access services directly via localhost

4. **Automated lifecycle**
   - Docker daemon starts on container creation
   - Cluster created/started automatically
   - Kubeconfig configured automatically
   - Ready to use immediately

### Scripts

The setup uses modular scripts in [.devcontainer/scripts/](.devcontainer/scripts/):

- **install-k3d.sh**: Installs k3d binary during image build
- **install-tools.sh**: Installs kubectl, helm, k9s, kubectx/kubens during build
- **start-docker.sh**: Configures cgroups and starts Docker daemon
- **init-cluster.sh**: Creates or starts the k3d cluster and configures kubeconfig

### Platform Compatibility

| Platform | Status | Notes |
|----------|--------|-------|
| **macOS (Apple Silicon)** | ✅ Excellent | Docker Desktop required |
| **macOS (Intel)** | ✅ Excellent | Docker Desktop required |
| **Linux** | ✅ Excellent | Docker Engine or Docker Desktop |
| **Windows (WSL2)** | ✅ Excellent | Docker Desktop with WSL2 required |

**Note**: This setup requires Docker and uses Docker-in-Docker. It does not support Podman.

## References

- [k3d Documentation](https://k3d.io/)
- [k3s Documentation](https://docs.k3s.io/)
- [Docker-in-Docker](https://www.docker.com/blog/docker-can-now-run-within-docker/)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- [Helm Documentation](https://helm.sh/docs/)

## License

This devcontainer configuration is provided as-is for development purposes.
