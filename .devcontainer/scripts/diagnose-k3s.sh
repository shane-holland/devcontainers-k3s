#!/bin/bash
set -e

echo "=========================================="
echo "K3S DOCKER-IN-DOCKER DIAGNOSTICS"
echo "=========================================="
echo ""

echo "1. Checking Docker daemon..."
docker version
echo ""

echo "2. Checking cgroup setup..."
mount | grep cgroup
echo ""

echo "3. Checking if we can run privileged containers..."
docker run --rm --privileged alpine sh -c "echo 'Privileged mode works!'"
echo ""

echo "4. Testing k3s manually with proper command..."
echo "   Starting k3s container in background..."
CONTAINER_ID=$(docker run -d --privileged \
  --tmpfs /run \
  --tmpfs /var/run \
  --name test-k3s \
  rancher/k3s:v1.30.4-k3s1 \
  server --disable=traefik)

echo "   Container ID: $CONTAINER_ID"
echo "   Waiting 10 seconds for k3s to start..."
sleep 10

echo ""
echo "5. Container status:"
docker ps -a --filter "name=test-k3s"
echo ""

echo "6. K3S logs (last 100 lines):"
echo "=========================================="
docker logs --tail 100 test-k3s 2>&1
echo "=========================================="
echo ""

echo "7. Container inspect (key details):"
docker inspect test-k3s --format='Status: {{.State.Status}}
Restarting: {{.State.Restarting}}
ExitCode: {{.State.ExitCode}}
Error: {{.State.Error}}'
echo ""

echo "8. Checking if k3s process is running inside container..."
docker exec test-k3s ps aux | grep k3s || echo "Cannot exec into container"
echo ""

echo "Cleaning up test container..."
docker rm -f test-k3s
echo ""

echo "=========================================="
echo "9. Checking mount propagation..."
echo "=========================================="
docker run --rm --privileged \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  alpine sh -c "
    echo 'Cgroup mount inside container:'
    mount | grep cgroup
    echo ''
    echo 'Cgroup files:'
    ls -la /sys/fs/cgroup/ | head -20
  "
echo ""

echo "=========================================="
echo "DIAGNOSTICS COMPLETE"
echo "=========================================="
