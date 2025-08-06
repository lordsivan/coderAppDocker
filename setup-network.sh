#!/bin/bash

# Network setup script for Coder multi-user environment
# This script creates the required Docker bridge network for static IP assignment

set -euo pipefail

NETWORK_NAME="coder_net"
SUBNET="172.20.0.0/16"
GATEWAY="172.20.0.1"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Check if network already exists
if docker network ls --format "{{.Name}}" | grep -q "^$NETWORK_NAME$"; then
    log "Network '$NETWORK_NAME' already exists"
    docker network inspect "$NETWORK_NAME"
    exit 0
fi

log "Creating Docker bridge network: $NETWORK_NAME"
log "Subnet: $SUBNET"
log "Gateway: $GATEWAY"

# Create the bridge network
docker network create \
    --driver bridge \
    --subnet="$SUBNET" \
    --gateway="$GATEWAY" \
    --opt com.docker.network.bridge.name=coder-br0 \
    --opt com.docker.network.driver.mtu=1500 \
    "$NETWORK_NAME"

log "Network created successfully!"
log "You can now start Coder workspaces that will automatically connect to this network"

# Display network information
log "Network details:"
docker network inspect "$NETWORK_NAME" --format '{{json .IPAM.Config}}' | jq .

log "Available IP range for workspaces: 172.20.0.10 - 172.20.0.254"
log "Remember to update ip-map.txt with your user mappings"