#!/bin/bash
set -e

echo "=========================================="
echo "Initializing Docker-in-Docker"
echo "=========================================="
echo ""

echo "1. Setting up cgroups..."

# Ensure /sys/fs/cgroup is properly set up
# This works across Docker Desktop (Mac/Windows) and native Linux
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    echo "   ✅ cgroup v2 unified hierarchy detected"
    CGROUP_VERSION=2
elif [ -d /sys/fs/cgroup/cpu ]; then
    echo "   ✅ cgroup v1 hierarchy detected"
    CGROUP_VERSION=1
else
    echo "   ⚠️  No cgroups detected, attempting to mount..."
    # Try to mount cgroup v2
    if mount -t cgroup2 none /sys/fs/cgroup 2>/dev/null; then
        echo "   ✅ Mounted cgroup v2"
        CGROUP_VERSION=2
    else
        # Fall back to cgroup v1
        echo "   Setting up cgroup v1..."
        mkdir -p /sys/fs/cgroup
        mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup

        for controller in cpu cpuacct memory devices freezer net_cls blkio perf_event net_prio hugetlb pids; do
            mkdir -p /sys/fs/cgroup/$controller
            if mount -t cgroup -o $controller cgroup /sys/fs/cgroup/$controller 2>/dev/null; then
                echo "   ✅ Mounted $controller controller"
            fi
        done
        CGROUP_VERSION=1
    fi
fi

echo ""
echo "2. Cgroup configuration:"
mount | grep cgroup | head -5
echo ""

# Enable cgroup v2 delegation if available
if [ "$CGROUP_VERSION" = "2" ]; then
    echo "3. Enabling cgroup v2 delegation..."

    # Find the current container's cgroup path
    CURRENT_CGROUP=$(cat /proc/self/cgroup | grep '^0::' | cut -d: -f3)
    echo "   Current cgroup: $CURRENT_CGROUP"

    # Check what controllers are available at the root
    if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
        AVAILABLE_CONTROLLERS=$(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null || echo "")
        echo "   Available controllers: $AVAILABLE_CONTROLLERS"

        # Enable controllers in the root cgroup for delegation
        for ctrl in $AVAILABLE_CONTROLLERS; do
            echo "+$ctrl" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true
        done

        # If we're in a sub-cgroup, also try to enable there
        if [ -n "$CURRENT_CGROUP" ] && [ "$CURRENT_CGROUP" != "/" ]; then
            CGROUP_PATH="/sys/fs/cgroup${CURRENT_CGROUP}"
            if [ -f "${CGROUP_PATH}/cgroup.subtree_control" ]; then
                echo "   Enabling in sub-cgroup: $CGROUP_PATH"
                for ctrl in $AVAILABLE_CONTROLLERS; do
                    echo "+$ctrl" > "${CGROUP_PATH}/cgroup.subtree_control" 2>/dev/null || true
                done
            fi
        fi

        echo "   Root controllers enabled: $(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || echo 'none')"
    fi
    echo ""
fi

echo "4. Starting Docker daemon..."
echo "   Storage driver: overlay2 (with fallback to vfs)"
echo "   Log file: /var/log/dockerd.log"
echo ""

# Start Docker daemon with proper settings for DinD and cgroup v2
# Try overlay2 first, fall back to vfs if it fails
nohup dockerd \
    --host=unix:///var/run/docker.sock \
    --storage-driver=overlay2 \
    --exec-opt native.cgroupdriver=cgroupfs \
    --log-level=error \
    > /var/log/dockerd.log 2>&1 &

DOCKERD_PID=$!

# Wait for Docker daemon to be ready
echo "5. Waiting for Docker daemon..."
timeout=60
elapsed=0
docker_started=false

while [ $elapsed -lt $timeout ]; do
    if docker info > /dev/null 2>&1; then
        docker_started=true
        break
    fi

    # Check if dockerd crashed
    if ! kill -0 $DOCKERD_PID 2>/dev/null; then
        echo "   ⚠️  Docker daemon crashed, checking logs..."
        if grep -q "overlay2" /var/log/dockerd.log && grep -qi "not supported" /var/log/dockerd.log; then
            echo "   Overlay2 not supported, restarting with vfs..."
            nohup dockerd \
                --host=unix:///var/run/docker.sock \
                --storage-driver=vfs \
                --exec-opt native.cgroupdriver=cgroupfs \
                --log-level=error \
                >> /var/log/dockerd.log 2>&1 &
            DOCKERD_PID=$!
            sleep 2
        else
            echo "   ERROR: Docker daemon failed to start"
            echo ""
            echo "Last 20 lines of dockerd logs:"
            tail -20 /var/log/dockerd.log
            exit 1
        fi
    fi

    sleep 1
    elapsed=$((elapsed + 1))
    if [ $((elapsed % 10)) -eq 0 ]; then
        echo "   Still waiting... (${elapsed}s)"
    fi
done

if [ "$docker_started" = false ]; then
    echo ""
    echo "ERROR: Docker daemon failed to start within ${timeout} seconds"
    echo ""
    echo "Docker daemon logs:"
    cat /var/log/dockerd.log
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Docker-in-Docker is ready!"
echo "=========================================="
echo ""
docker version --format "Docker Engine: {{.Server.Version}}"
docker info --format "Storage Driver: {{.Driver}}"
echo ""
