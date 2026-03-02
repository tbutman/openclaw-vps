#!/bin/bash
set -e

# Start Tailscale daemon in background
echo "Starting Tailscale daemon..."
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &
TAILSCALED_PID=$!

# Wait for tailscaled to be ready
sleep 2

# Authenticate with Tailscale if not already authenticated
if [ -n "$TAILSCALE_AUTHKEY" ]; then
  echo "Authenticating with Tailscale..."
  tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="${TAILSCALE_HOSTNAME:-openclaw-gateway}" --operator=openclaw || true
  echo "Tailscale authenticated"
else
  echo "WARNING: TAILSCALE_AUTHKEY not set, skipping Tailscale authentication"
fi

# Show Tailscale status
tailscale status || true

# Fix ownership of state directory to ensure openclaw user can write credentials
echo "Fixing permissions for OpenClaw state directory..."
chown -R openclaw:openclaw /home/openclaw/.openclaw /home/openclaw/workspace 2>/dev/null || true

# Drop to openclaw user and run gateway
echo "Starting OpenClaw gateway as openclaw user..."
exec gosu openclaw "$@"
