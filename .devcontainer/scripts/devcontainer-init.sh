#!/bin/bash
set -e

LOG_FILE="/var/log/devcontainer-init.log"
INIT_FLAG="/var/lib/devcontainer-initialized"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Starting devcontainer initialization..."
log "=========================================="

# Check if already initialized
if [ -f "$INIT_FLAG" ]; then
    log "Container already initialized (flag file exists at $INIT_FLAG)"
    log "Skipping initialization scripts."
    log "To re-run initialization, delete $INIT_FLAG and restart the container."
    exit 0
fi

log "First-time initialization detected."

# Run start-docker.sh
if [ -f /opt/devcontainer/scripts/start-docker.sh ]; then
    log "Running start-docker.sh..."
    if bash /opt/devcontainer/scripts/start-docker.sh 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ start-docker.sh completed successfully"
    else
        log "❌ start-docker.sh failed with exit code $?"
        exit 1
    fi
else
    log "⚠️  start-docker.sh not found, skipping..."
fi

# Run init-cluster.sh
if [ -f /opt/devcontainer/scripts/init-cluster.sh ]; then
    log "Running init-cluster.sh..."
    if bash /opt/devcontainer/scripts/init-cluster.sh 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ init-cluster.sh completed successfully"
    else
        log "❌ init-cluster.sh failed with exit code $?"
        exit 1
    fi
else
    log "⚠️  init-cluster.sh not found, skipping..."
fi

# Mark as initialized
touch "$INIT_FLAG"
log "=========================================="
log "✅ Devcontainer initialization complete!"
log "=========================================="
log "Logs available at: $LOG_FILE"
