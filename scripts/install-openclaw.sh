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
echo "[4/4] Configuring OpenClaw gateway..."
# Always overwrite config with latest template
if [ -f "$OPENCLAW_STATE_DIR/openclaw.json" ]; then
  echo "Backing up existing config to $OPENCLAW_STATE_DIR/openclaw.json.backup"
  cp "$OPENCLAW_STATE_DIR/openclaw.json" "$OPENCLAW_STATE_DIR/openclaw.json.backup"
fi
cp ../config/openclaw.template.json "$OPENCLAW_STATE_DIR/openclaw.json"
echo "Config template copied to $OPENCLAW_STATE_DIR/openclaw.json"

# Generate secure auth token for browser control endpoints
echo "Generating browser control auth token..."
AUTH_TOKEN=$(openssl rand -hex 32)
# Use sed to inject token into gateway.auth section (after mode line)
sed -i.tmp '/"mode": "trusted-proxy"/a\
    "token": "'"$AUTH_TOKEN"'",' "$OPENCLAW_STATE_DIR/openclaw.json"
rm -f "$OPENCLAW_STATE_DIR/openclaw.json.tmp"
echo "Browser control auth token generated and added to config"

# Fix state directory permissions
echo "Securing state directory permissions..."
chmod 700 "$OPENCLAW_STATE_DIR"

# Restart containers to pick up config
docker compose restart openclaw
sleep 3

echo ""
echo "Verifying gateway health..."
# Wait for gateway and Tailscale to start
sleep 10

# Check if containers are running
if docker compose ps | grep -q "Up"; then
  echo "OpenClaw gateway is running!"
else
  echo "WARNING: Some containers may not be running. Check logs:"
  echo "  cd docker && docker compose logs"
  exit 1
fi

# Verify Tailscale connection and get hostname
echo ""
echo "Verifying Tailscale connection..."
docker compose exec -T openclaw tailscale status || echo "WARNING: Could not retrieve Tailscale status"

echo ""
echo "Retrieving Tailscale URL..."
TAILSCALE_HOSTNAME=$(docker compose exec -T openclaw tailscale status --json 2>/dev/null | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4 || echo "openclaw-gateway")
TAILNET=$(docker compose exec -T openclaw tailscale status --json 2>/dev/null | grep -o '"MagicDNSSuffix":"[^"]*"' | cut -d'"' -f4 || echo "ts.net")

echo ""
echo "Setting up OpenClaw CLI tools..."

# Install tools command-line tool
if [ ! -f /usr/local/bin/tools ]; then
  echo "Installing 'tools' CLI command..."
  sudo cp ~/openclaw-vps/scripts/openclaw-tools.sh /usr/local/bin/tools
  sudo chmod +x /usr/local/bin/tools
  echo "✅ 'tools' command installed to /usr/local/bin/tools"
else
  echo "✅ 'tools' command already installed"
fi

# Add openclaw alias to .bashrc if not already present
if ! grep -q "alias openclaw=" ~/.bashrc 2>/dev/null; then
  echo 'alias openclaw="docker compose -f ~/openclaw-vps/docker/docker-compose.yml exec openclaw openclaw"' >> ~/.bashrc
  echo "✅ OpenClaw CLI alias added to ~/.bashrc"
else
  echo "✅ OpenClaw CLI alias already exists"
fi

# Also add to current session
alias openclaw="docker compose -f ~/openclaw-vps/docker/docker-compose.yml exec openclaw openclaw"

echo ""
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo ""
echo "OpenClaw gateway is running with Tailscale Serve."
echo ""
echo "✅ Control UI URL (HTTPS, Tailscale-only):"
echo "   https://${TAILSCALE_HOSTNAME}.${TAILNET}"
echo ""
echo "✅ Tailscale identity authentication enabled"
echo "   No device pairing required when accessing from your Tailscale network!"
echo ""
echo "✅ OpenClaw CLI tools installed"
echo "   Run 'tools --help' to see all available commands"
echo "   Run 'openclaw status' for direct OpenClaw CLI access"
echo ""
echo "Next steps:"
echo "1. Configure Slack connection:"
echo "   bash scripts/configure-slack.sh"
echo ""
echo "2. Send a test DM to your Slack bot"
echo ""
echo "3. Approve the pairing code in Slack:"
echo "   tools openclaw pairing approve slack <code>"
echo ""
echo "4. Deploy an agent (optional):"
echo "   bash scripts/deploy-agent.sh /path/to/agent-repo"
echo ""
echo "Useful commands:"
echo "  tools status                 # Check overall system status"
echo "  tools openclaw status        # Check OpenClaw gateway"
echo "  tools openclaw logs          # View OpenClaw logs"
echo "  tools docker ps              # List containers"
echo "  tools tailscale status       # Check Tailscale"
echo "  tools backup                 # Create backup"
echo "  tools --help                 # Show all commands"
echo ""
echo "View logs:"
echo "  cd docker && docker compose logs -f openclaw"
echo ""
echo "======================================"
