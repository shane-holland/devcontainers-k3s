# Kubernetes DevContainer

A cross-platform development container with Kubernetes (k3s) that works with both Docker and Podman.

## What's Inside

This devcontainer provides a complete Kubernetes development environment with:

- **k3s**: Lightweight Kubernetes distribution with built-in containerd
- **kubectl**: Kubernetes command-line tool (included with k3s)
- **Helm**: Kubernetes package manager
- **k9s**: Terminal-based Kubernetes UI
- **kubectx/kubens**: Quick context and namespace switching

## How It Works

### k3s Without Docker or systemd

This setup runs [k3s](https://k3s.io/) directly using its built-in containerd runtime:

- **No Docker required**: k3s has its own container runtime (containerd)
- **No systemd required**: k3s runs as a direct process, not a systemd service
- **Podman compatible**: Works with both Docker and Podman as the devcontainer host
- **Cross-platform**: Works on macOS, Linux, and Windows
- **Lightweight**: Minimal resource footprint (~512MB RAM)
- **Full-featured**: Complete Kubernetes API (certified Kubernetes distribution)

## Getting Started

### Prerequisites

- **Docker** or **Podman 4+**
  - macOS: Docker Desktop, Podman, or Rancher Desktop
  - Linux: Docker, Podman, or Podman Desktop
  - Windows: Docker Desktop with WSL2, or Podman with WSL2

- **VS Code** with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

**Note**: This setup works with both Docker and Podman, including in environments where Docker Desktop cannot be used due to licensing constraints.

### Usage

1. **Open in DevContainer**
   - Open this folder in VS Code
   - Click "Reopen in Container" when prompted
   - Or: Press `F1` → "Dev Containers: Rebuild and Reopen in Container"

2. **Wait for Initialization**
   - k3s server starts automatically
   - Cluster is ready in ~30-60 seconds on first launch
   - Subsequent starts are nearly instant

3. **Verify Setup**
   ```bash
   # Check k3s process
   ps aux | grep k3s

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
  "privileged": true,
  "runArgs": [
    "--cgroupns=host",
    "--tmpfs=/run",
    "--tmpfs=/var/run"
  ],
  "mounts": [
    "source=/sys/fs/cgroup,target=/sys/fs/cgroup,type=bind,readonly"
  ]
}
```

**Why these settings?**

- `privileged: true` - Required for k3s containerd to manage containers
- `--cgroupns=host` - Enables proper cgroup v2 support
- `--tmpfs=/run` and `--tmpfs=/var/run` - Provides writable runtime directories
- `/sys/fs/cgroup` mount - Allows k3s to manage cgroups for pods

### k3s Server Configuration

The k3s server is started with these flags in [.devcontainer/init.sh](.devcontainer/init.sh):

```bash
sudo k3s server \
    --write-kubeconfig-mode=644 \
    --disable=traefik \
    --snapshotter=native
```

**Customization options:**

- `--disable=traefik` - Removes traefik ingress (saves ~100MB RAM). Remove this flag to enable traefik.
- `--snapshotter=native` - Uses native snapshotter for better compatibility. Can use `overlayfs` on Linux for better performance.
- Add `--disable=servicelb` to disable the built-in load balancer
- Add `--disable=local-storage` to disable the built-in storage provisioner

## Common Tasks

### Managing k3s

```bash
# Check k3s status
ps aux | grep k3s

# View k3s logs
tail -f /tmp/k3s.log

# Stop k3s (requires sudo)
sudo pkill k3s

# Restart k3s
sudo pkill k3s
bash .devcontainer/init.sh

# Manually start k3s server
sudo k3s server \
    --write-kubeconfig-mode=644 \
    --disable=traefik \
    --snapshotter=native \
    > /tmp/k3s.log 2>&1 &
```

### Deploying Applications

```bash
# Create a deployment
kubectl create deployment nginx --image=nginx

# Expose as service
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check status
kubectl get all

# Access via port-forward
kubectl port-forward svc/nginx 8080:80
```

### Using Helm

```bash
# Add a repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Install a chart
helm install my-redis bitnami/redis

# List releases
helm list
```

### Using k9s

```bash
# Launch k9s
k9s

# Common shortcuts:
# :pod    - View pods
# :svc    - View services
# :deploy - View deployments
# /       - Filter resources
# d       - Describe resource
# l       - View logs
# :q      - Quit
```

## Troubleshooting

### k3s server not starting

1. **Check if k3s is running**:
   ```bash
   ps aux | grep k3s
   ```

2. **View k3s logs**:
   ```bash
   tail -100 /tmp/k3s.log
   ```

3. **Common issues**:
   - **Permission denied**: Make sure the container is running with `privileged: true`
   - **cgroup errors**: Verify `/sys/fs/cgroup` is mounted correctly
   - **Port conflicts**: k3s uses port 6443. Check if it's already in use with `sudo lsof -i :6443`

4. **Restart k3s**:
   ```bash
   sudo pkill k3s
   bash .devcontainer/init.sh
   ```

### kubectl cannot connect

1. **Check kubeconfig**:
   ```bash
   cat ~/.kube/config
   echo $KUBECONFIG
   ```

2. **Re-setup kubeconfig**:
   ```bash
   mkdir -p ~/.kube
   sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
   sudo chown $(id -u):$(id -g) ~/.kube/config
   export KUBECONFIG=~/.kube/config
   ```

3. **Verify k3s is responding**:
   ```bash
   sudo k3s kubectl get nodes
   ```

### Podman-specific notes

This setup is **designed for Podman compatibility**:
- No Docker-in-Docker required
- No systemd required
- Works on Podman 4+ across all platforms
- If you encounter issues, check Podman version: `podman --version`

### Performance issues

- **First build is slow**: Base image and k3s binary are downloaded (cached for future rebuilds)
- **High CPU/memory during startup**: k3s initializes its components. Normal and temporary.
- **Slow first cluster startup**: k3s pulls system images. Takes 30-60 seconds on first run.

## Architecture

### Why This Setup?

This configuration solves the key challenges of running Kubernetes in devcontainers:

1. **k3s server directly (no Docker-in-Docker)**
   - No nested containerization complexity
   - Works with both Docker and Podman hosts
   - Uses k3s built-in containerd runtime
   - No Docker daemon overhead

2. **No systemd requirement**
   - k3s runs as a direct process (not a systemd service)
   - Works on Windows (where systemd doesn't work in containers)
   - Compatible with all container runtimes
   - Simpler process management

3. **Podman-first design**
   - No dependency on Docker Desktop (licensing-friendly)
   - Microsoft devcontainer features can be incompatible with Podman
   - Direct k3s installation avoids feature compatibility issues

4. **Minimal cgroup configuration**
   - `--cgroupns=host` + `/sys/fs/cgroup` mount (read-only)
   - `--tmpfs` for /run and /var/run
   - Works across all platforms without special tuning

### Platform Compatibility

| Platform | Status | Notes |
|----------|--------|-------|
| **macOS (Apple Silicon)** | ✅ Excellent | Docker, Podman, or Rancher Desktop |
| **macOS (Intel)** | ✅ Excellent | Docker, Podman, or Rancher Desktop |
| **Linux** | ✅ Excellent | Docker or Podman |
| **Windows (WSL2)** | ✅ Excellent | Docker or Podman with WSL2 |
| **GitHub Codespaces** | ✅ Excellent | Works out of the box |

### How This Differs from Other Solutions

- **No Docker-in-Docker**: Many Kubernetes devcontainer examples use Docker-in-Docker, which doesn't work well with Podman
- **No systemd**: Many k3s examples use systemd, which doesn't work on Windows in containers
- **No devcontainer features**: Microsoft's docker-in-docker feature has Podman compatibility issues

This setup runs k3s as a direct process with its built-in containerd runtime, avoiding these pitfalls.

## References

- [k3s Documentation](https://docs.k3s.io/)
- [k3s Installation Options](https://docs.k3s.io/installation/configuration)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Podman Compatibility](https://github.com/containers/podman/blob/main/docs/tutorials/podman-for-docker-users.md)

## License

This devcontainer configuration is provided as-is for development purposes.
