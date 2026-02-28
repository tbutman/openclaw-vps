#!/usr/bin/env bash
set -euo pipefail

# ============================================
# OpenClaw VPS — Install OpenClaw Script
# ============================================
# Installs and starts the OpenClaw gateway via Docker.
# Run as the openclaw user after bootstrap-vps.sh completes.
#
# This script:
#   - Validates .env file exists
#   - Builds custom Docker image
#   - Starts docker-compose stack (gateway + Chromium)
#   - Verifies gateway health
#
# Usage:
#   bash scripts/install-openclaw.sh
# ============================================

echo "======================================"
echo "OpenClaw VPS — Install OpenClaw"
echo "======================================"
echo ""

# Check if running as non-root
if [ "$EUID" -eq 0 ]; then
  echo "ERROR: Do not run this script as root."
  echo "Switch to the openclaw user: su - openclaw"
  exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
  echo "ERROR: .env file not found."
  echo "Please copy .env.example to .env and fill in your credentials."
  echo "  cp .env.example .env"
  echo "  nano .env"
  echo "  chmod 600 .env"
  exit 1
fi

echo "[1/4] Loading environment variables..."
# Source .env file
set -a
source .env
set +a

# Validate required variables
REQUIRED_VARS=(
  "ANTHROPIC_API_KEY"
  "SLACK_APP_TOKEN"
  "SLACK_BOT_TOKEN"
  "OPENCLAW_STATE_DIR"
  "OPENCLAW_WORKSPACE_DIR"
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required environment variable $var is not set in .env"
    exit 1
  fi
done

echo "Environment variables loaded and validated."

echo ""
echo "[2/4] Creating OpenClaw directories..."
mkdir -p "$OPENCLAW_STATE_DIR"
mkdir -p "$OPENCLAW_WORKSPACE_DIR"
echo "Directories ready:"
echo "  State: $OPENCLAW_STATE_DIR"
echo "  Workspace: $OPENCLAW_WORKSPACE_DIR"

echo ""
echo "[3/4] Building Docker image and starting services..."
cd docker

# Copy .env to docker directory for docker-compose
cp ../.env .env

# Build and start containers
docker compose build
docker compose up -d

echo "Docker containers started."
docker compose ps

echo ""
echo "[4/5] Configuring OpenClaw gateway..."
# Copy config template to OpenClaw state directory
cp ../config/openclaw.template.json "$OPENCLAW_STATE_DIR/openclaw.json"
echo "Config template copied to $OPENCLAW_STATE_DIR/openclaw.json"

# Restart containers to pick up config
docker compose restart openclaw
sleep 3

echo ""
echo "[5/6] Verifying gateway health..."
# Wait a few seconds for gateway to start
sleep 5

# Check if containers are running
if docker compose ps | grep -q "Up"; then
  echo "OpenClaw gateway is running!"
else
  echo "WARNING: Some containers may not be running. Check logs:"
  echo "  cd docker && docker compose logs"
  exit 1
fi

echo ""
echo "[6/6] Setting up Tailscale HTTPS proxy..."
# Set up tailscale serve to provide HTTPS access to the gateway
sudo tailscale serve --bg --https 443 http://127.0.0.1:18789

# Get Tailscale hostname
TAILSCALE_HOSTNAME=$(tailscale status --json 2>/dev/null | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4 || echo "<tailscale-hostname>")
TAILNET=$(tailscale status --json 2>/dev/null | grep -o '"MagicDNSSuffix":"[^"]*"' | cut -d'"' -f4 || echo "ts.net")

echo ""
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo ""
echo "OpenClaw gateway is running on port 18789."
echo ""
echo "Access the Control UI via Tailscale (HTTPS):"
echo "  https://${TAILSCALE_HOSTNAME}.${TAILNET}"
echo ""
echo "This provides a secure context for device authentication."
echo ""
echo "Next steps:"
echo "1. Configure Slack connection:"
echo "   bash scripts/configure-slack.sh"
echo ""
echo "2. Send a test DM to your Slack bot"
echo ""
echo "3. Approve the pairing code:"
echo "   openclaw pairing approve slack <code>"
echo ""
echo "4. Deploy an agent:"
echo "   bash scripts/deploy-agent.sh /path/to/agent-repo"
echo ""
echo "View logs:"
echo "  cd docker && docker compose logs -f"
echo ""
echo "======================================"
