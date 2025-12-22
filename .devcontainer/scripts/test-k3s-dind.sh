#!/bin/bash

echo "=========================================="
echo "K3S IN DOCKER-IN-DOCKER TEST SUITE"
echo "=========================================="
echo ""

cleanup() {
    echo "Cleaning up test containers..."
    docker rm -f test-k3s-1 test-k3s-2 test-k3s-3 2>/dev/null || true
}

trap cleanup EXIT

echo "Test 1: Basic privileged k3s container"
echo "----------------------------------------"
docker run -d --name test-k3s-1 \
    --privileged \
    --tmpfs /run \
    --tmpfs /var/run \
    rancher/k3s:v1.30.4-k3s1 \
    server --disable=traefik

echo "Waiting 15 seconds..."
sleep 15

echo "Status:"
docker ps -a --filter "name=test-k3s-1" --format "{{.Status}}"
echo ""
echo "Logs (last 30 lines):"
docker logs --tail 30 test-k3s-1 2>&1
echo ""
echo "=========================================="
echo ""

echo "Test 2: k3s with cgroupns=host"
echo "----------------------------------------"
docker run -d --name test-k3s-2 \
    --privileged \
    --cgroupns=host \
    --tmpfs /run \
    --tmpfs /var/run \
    rancher/k3s:v1.30.4-k3s1 \
    server --disable=traefik

echo "Waiting 15 seconds..."
sleep 15

echo "Status:"
docker ps -a --filter "name=test-k3s-2" --format "{{.Status}}"
echo ""
echo "Logs (last 30 lines):"
docker logs --tail 30 test-k3s-2 2>&1
echo ""
echo "=========================================="
echo ""

echo "Test 3: k3s with security-opt and cgroup mount"
echo "----------------------------------------"
docker run -d --name test-k3s-3 \
    --privileged \
    --cgroupns=host \
    --tmpfs /run \
    --tmpfs /var/run \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --security-opt apparmor=unconfined \
    --security-opt seccomp=unconfined \
    rancher/k3s:v1.30.4-k3s1 \
    server --disable=traefik --snapshotter=native

echo "Waiting 15 seconds..."
sleep 15

echo "Status:"
docker ps -a --filter "name=test-k3s-3" --format "{{.Status}}"
echo ""
echo "Logs (last 30 lines):"
docker logs --tail 30 test-k3s-3 2>&1
echo ""
echo "=========================================="
echo ""

echo "SUMMARY:"
echo "----------------------------------------"
docker ps -a --filter "name=test-k3s" --format "table {{.Names}}\t{{.Status}}"
echo ""

echo "Which test succeeded? (Check for 'Up' status above)"
echo "If test is 'Up', check for 'k3s is up and running' in logs:"
echo ""
for i in 1 2 3; do
    echo "Test $i:"
    if docker logs test-k3s-$i 2>&1 | grep -q "k3s is up and running"; then
        echo "  ✅ SUCCESS - k3s is running!"
    else
        echo "  ❌ FAILED - k3s not running"
        echo "  Last error:"
        docker logs --tail 5 test-k3s-$i 2>&1 | grep -i error || echo "  (no error found in logs)"
    fi
    echo ""
done

echo "=========================================="
echo "TEST COMPLETE"
echo "=========================================="
