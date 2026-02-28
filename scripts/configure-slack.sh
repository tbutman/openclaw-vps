#!/usr/bin/env bash
set -euo pipefail

# ============================================
# OpenClaw VPS — Configure Slack Script
# ============================================
# Validates Slack tokens and tests Socket Mode connection.
# Run after install-openclaw.sh completes.
#
# This script:
#   - Validates SLACK_APP_TOKEN and SLACK_BOT_TOKEN
#   - Tests Slack API connection
#   - Provides instructions for pairing
#
# Usage:
#   bash scripts/configure-slack.sh
# ============================================

echo "======================================"
echo "OpenClaw VPS — Configure Slack"
echo "======================================"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
  echo "ERROR: .env file not found."
  echo "Please ensure .env exists with SLACK_APP_TOKEN and SLACK_BOT_TOKEN."
  exit 1
fi

echo "[1/3] Loading Slack credentials..."
set -a
source .env
set +a

if [ -z "${SLACK_APP_TOKEN:-}" ] || [ -z "${SLACK_BOT_TOKEN:-}" ]; then
  echo "ERROR: SLACK_APP_TOKEN or SLACK_BOT_TOKEN not set in .env"
  exit 1
fi

echo "Slack tokens loaded."

echo ""
echo "[2/3] Testing Slack API connection..."
# Test auth.test endpoint with bot token
RESPONSE=$(curl -s -X POST https://slack.com/api/auth.test \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json")

if echo "$RESPONSE" | grep -q '"ok":true'; then
  BOT_NAME=$(echo "$RESPONSE" | grep -o '"user":"[^"]*"' | cut -d'"' -f4)
  TEAM_NAME=$(echo "$RESPONSE" | grep -o '"team":"[^"]*"' | cut -d'"' -f4)
  echo "✓ Slack bot token is valid!"
  echo "  Bot: @$BOT_NAME"
  echo "  Workspace: $TEAM_NAME"
else
  echo "✗ Slack bot token validation failed."
  echo "Response: $RESPONSE"
  exit 1
fi

echo ""
echo "[3/3] Checking OpenClaw gateway connection..."
# Check if OpenClaw container is running
if docker compose -f docker/docker-compose.yml ps | grep -q "Up"; then
  echo "✓ OpenClaw gateway is running."
  echo ""
  echo "Slack Socket Mode should connect automatically."
  echo "Check logs for connection status:"
  echo "  cd docker && docker compose logs -f openclaw"
else
  echo "✗ OpenClaw gateway is not running."
  echo "Start it with:"
  echo "  cd docker && docker compose up -d"
  exit 1
fi

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")

echo ""
echo "======================================"
echo "Slack Configuration Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Send a DM to @$BOT_NAME in Slack"
echo ""
echo "2. The bot will respond with a pairing code (e.g., ABC123)"
echo ""
echo "3. Approve the pairing code via the Control UI:"
echo "   http://$TAILSCALE_IP:18789"
echo "   OR via CLI inside the container:"
echo "   docker compose -f docker/docker-compose.yml exec openclaw openclaw pairing approve slack <code>"
echo ""
echo "4. Once paired, send another message to test the connection"
echo ""
echo "======================================"
