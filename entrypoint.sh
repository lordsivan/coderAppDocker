#!/bin/bash

# Custom entrypoint script for Coder workspaces with static IP assignment
# This script handles automatic network connection with predefined IP mappings

set -euo pipefail

# Configuration
NETWORK_NAME="coder_net"
IP_MAP_FILE="/etc/ip-map.txt"
LOG_FILE="/var/log/coder/network-setup.log"
CONTAINER_ID=""

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE" >&2
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Get container ID
get_container_id() {
    if [ -f "/proc/1/cpuset" ]; then
        CONTAINER_ID=$(basename "$(cat /proc/1/cpuset)" 2>/dev/null || echo "")
    fi
    
    if [ -z "$CONTAINER_ID" ] && [ -f "/proc/self/cgroup" ]; then
        CONTAINER_ID=$(grep 'docker' /proc/self/cgroup | head -1 | sed 's/.*\///' | cut -c1-12 2>/dev/null || echo "")
    fi
    
    if [ -z "$CONTAINER_ID" ]; then
        log "WARN" "Could not determine container ID, using hostname"
        CONTAINER_ID=$(hostname)
    fi
    
    log "INFO" "Container ID: $CONTAINER_ID"
}

# Determine username
get_username() {
    local username=""
    
    # Try CODER_USERNAME environment variable first
    if [ -n "${CODER_USERNAME:-}" ]; then
        username="$CODER_USERNAME"
        log "INFO" "Username from CODER_USERNAME: $username"
    # Try USER environment variable
    elif [ -n "${USER:-}" ]; then
        username="$USER"
        log "INFO" "Username from USER: $username"
    # Fall back to whoami
    else
        username=$(whoami 2>/dev/null || echo "unknown")
        log "INFO" "Username from whoami: $username"
    fi
    
    if [ "$username" = "unknown" ] || [ -z "$username" ]; then
        error_exit "Could not determine username"
    fi
    
    echo "$username"
}

# Lookup IP address for user
lookup_ip() {
    local username="$1"
    local ip=""
    
    if [ ! -f "$IP_MAP_FILE" ]; then
        error_exit "IP mapping file not found: $IP_MAP_FILE"
    fi
    
    # Look up IP in the mapping file
    ip=$(grep "^$username:" "$IP_MAP_FILE" 2>/dev/null | cut -d':' -f2 | tr -d ' ' || echo "")
    
    if [ -z "$ip" ]; then
        error_exit "No IP mapping found for user: $username"
    fi
    
    # Validate IP format
    if ! echo "$ip" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' >/dev/null; then
        error_exit "Invalid IP address format: $ip"
    fi
    
    log "INFO" "Found IP mapping: $username -> $ip"
    echo "$ip"
}

# Check if network exists
check_network() {
    if ! docker network ls --format "{{.Name}}" | grep -q "^$NETWORK_NAME$" 2>/dev/null; then
        log "WARN" "Network '$NETWORK_NAME' not found. It should be created externally."
        return 1
    fi
    log "INFO" "Network '$NETWORK_NAME' exists"
    return 0
}

# Connect container to network with static IP
connect_to_network() {
    local ip="$1"
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if docker network connect --ip "$ip" "$NETWORK_NAME" "$CONTAINER_ID" 2>/dev/null; then
            log "INFO" "Successfully connected to network '$NETWORK_NAME' with IP $ip"
            return 0
        else
            retry=$((retry + 1))
            log "WARN" "Failed to connect to network (attempt $retry/$max_retries)"
            if [ $retry -lt $max_retries ]; then
                sleep 2
            fi
        fi
    done
    
    error_exit "Failed to connect to network after $max_retries attempts"
}

# Verify network connection
verify_connection() {
    local ip="$1"
    local interface=""
    
    # Wait a moment for network interface to be ready
    sleep 2
    
    # Check if the IP is assigned to any interface
    if ip addr show | grep -q "$ip"; then
        interface=$(ip addr show | grep "$ip" | awk '{print $NF}' | head -1)
        log "INFO" "Network connection verified: IP $ip assigned to interface $interface"
        return 0
    else
        log "WARN" "IP $ip not found on any interface"
        return 1
    fi
}

# Main network setup function
setup_network() {
    log "INFO" "Starting network setup process"
    
    # Get container information
    get_container_id
    
    # Determine username
    local username
    username=$(get_username)
    
    # Lookup IP address
    local ip
    ip=$(lookup_ip "$username")
    
    # Check if we're already connected to the network
    if docker network inspect "$NETWORK_NAME" 2>/dev/null | grep -q "$CONTAINER_ID"; then
        log "INFO" "Container already connected to network '$NETWORK_NAME'"
        if verify_connection "$ip"; then
            log "INFO" "Network setup already complete"
            return 0
        else
            log "WARN" "Connected to network but IP verification failed"
        fi
    fi
    
    # Check if network exists
    if ! check_network; then
        log "WARN" "Proceeding without network connection - network may be created later"
        return 0
    fi
    
    # Connect to network
    connect_to_network "$ip"
    
    # Verify connection
    if ! verify_connection "$ip"; then
        log "WARN" "Network connection could not be verified, but continuing"
    fi
    
    log "INFO" "Network setup completed successfully"
}

# Main execution
main() {
    log "INFO" "=== Coder Workspace Entrypoint Started ==="
    log "INFO" "Arguments: $*"
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")" || true
    
    # Setup network if Docker socket is available
    if [ -S "/var/run/docker.sock" ]; then
        setup_network || {
            log "ERROR" "Network setup failed, but continuing with startup"
        }
    else
        log "INFO" "Docker socket not available, skipping network setup"
    fi
    
    log "INFO" "=== Starting Coder Process ==="
    
    # Execute the original coder entrypoint/command
    if [ $# -eq 0 ]; then
        exec coder server
    else
        exec coder "$@"
    fi
}

# Handle signals gracefully
trap 'log "INFO" "Received termination signal, shutting down"' TERM INT

# Run main function
main "$@"