#!/bin/bash
# Setup network allowlist for Ralph Wiggum sandbox container
# Linux: uses iptables for packet filtering
# macOS: creates network only (no packet filtering - use proxy alternative)
# Usage: sudo ./setup-network.sh [--teardown]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALLOWLIST_FILE="$SCRIPT_DIR/network-allowlist.conf"
NETWORK_NAME="ralph-net"
CHAIN_NAME="RALPH-ALLOWLIST"
OS_TYPE="$(uname -s)"

# Check root (only required on Linux for iptables)
if [[ "$OS_TYPE" == "Linux" && $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo) on Linux"
  exit 1
fi

# Teardown mode
if [[ "${1:-}" == "--teardown" ]]; then
  echo "Tearing down Ralph network allowlist..."

  if [[ "$OS_TYPE" == "Linux" ]]; then
    if [[ $EUID -ne 0 ]]; then
      echo "Error: Teardown requires root (sudo) on Linux"
      exit 1
    fi
    # Remove rules from DOCKER-USER chain
    iptables -D DOCKER-USER -j "$CHAIN_NAME" 2>/dev/null || true

    # Flush and delete custom chain
    iptables -F "$CHAIN_NAME" 2>/dev/null || true
    iptables -X "$CHAIN_NAME" 2>/dev/null || true
  fi

  # Remove Docker network
  docker network rm "$NETWORK_NAME" 2>/dev/null || true

  echo "Teardown complete"
  exit 0
fi

# Check allowlist exists
if [[ ! -f "$ALLOWLIST_FILE" ]]; then
  echo "Error: Allowlist file not found: $ALLOWLIST_FILE"
  exit 1
fi

echo "Setting up Ralph network allowlist..."
echo "OS: $OS_TYPE"

# Create Docker network if it doesn't exist
if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
  echo "Creating Docker network: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
else
  echo "Docker network '$NETWORK_NAME' already exists"
fi

# Get network subnet
SUBNET=$(docker network inspect "$NETWORK_NAME" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
echo "Network subnet: $SUBNET"

# macOS: Docker Desktop runs in a VM, so host iptables/pf can't filter container traffic
if [[ "$OS_TYPE" == "Darwin" ]]; then
  echo ""
  echo "WARNING: macOS detected"
  echo "Docker Desktop runs containers in a Linux VM, so host-level packet"
  echo "filtering cannot restrict container network access."
  echo ""
  echo "Options for network isolation on macOS:"
  echo "  1. Use --network none (no network access - most secure)"
  echo "  2. Accept that allowlist is advisory only on macOS"
  echo "  3. Run the container on a Linux host for full enforcement"
  echo ""
  echo "Network '$NETWORK_NAME' created (no packet filtering applied)"
  exit 0
fi

# Linux: configure iptables rules
# Create custom iptables chain if it doesn't exist
if ! iptables -L "$CHAIN_NAME" -n &>/dev/null; then
  echo "Creating iptables chain: $CHAIN_NAME"
  iptables -N "$CHAIN_NAME"
fi

# Flush existing rules in our chain
iptables -F "$CHAIN_NAME"

# Add rules for each allowed domain
echo "Resolving allowed domains and adding rules..."
while IFS= read -r line; do
  # Skip comments and empty lines
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

  domain="${line%%#*}"  # Remove inline comments
  domain="${domain// /}"  # Remove whitespace

  [[ -z "$domain" ]] && continue

  # Resolve domain to IPs
  if ips=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9.]+$'); then
    for ip in $ips; do
      echo "  Allow: $domain -> $ip"
      iptables -A "$CHAIN_NAME" -s "$SUBNET" -d "$ip" -j ACCEPT
    done
  else
    echo "  Warning: Could not resolve $domain"
  fi
done < "$ALLOWLIST_FILE"

# Allow established connections (for return traffic)
iptables -A "$CHAIN_NAME" -s "$SUBNET" -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (needed for resolution inside container)
iptables -A "$CHAIN_NAME" -s "$SUBNET" -p udp --dport 53 -j ACCEPT
iptables -A "$CHAIN_NAME" -s "$SUBNET" -p tcp --dport 53 -j ACCEPT

# Drop all other traffic from the ralph network
iptables -A "$CHAIN_NAME" -s "$SUBNET" -j DROP

# Insert jump to our chain in DOCKER-USER (if not already present)
if ! iptables -C DOCKER-USER -j "$CHAIN_NAME" 2>/dev/null; then
  echo "Adding jump to $CHAIN_NAME in DOCKER-USER chain"
  iptables -I DOCKER-USER -j "$CHAIN_NAME"
fi

echo ""
echo "Network allowlist configured successfully"
echo "Containers on '$NETWORK_NAME' can only reach allowed hosts"
echo ""
echo "To use: run-container.sh <project> --network"
echo "To remove: sudo $0 --teardown"
