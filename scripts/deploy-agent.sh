#!/usr/bin/env bash
set -euo pipefail

# ============================================
# OpenClaw VPS — Deploy Agent Script
# ============================================
# Deploys an agent from a separate repository to this OpenClaw environment.
#
# This script:
#   - Validates agent repo structure
#   - Copies agent files to OpenClaw workspace
#   - Merges agent config into gateway config
#   - Registers cron jobs (if any)
#   - Restarts gateway
#
# Usage:
#   bash scripts/deploy-agent.sh /path/to/agent-repo
#
# Expected agent repo structure:
#   agent-repo/
#   ├── SOUL.md                    # Agent identity and instructions
#   ├── config.json                # Agent-specific OpenClaw config
#   ├── skills/                    # Agent-specific skills (optional)
#   ├── cron.txt                   # Cron jobs (optional)
#   └── .env.agent                 # Agent-specific secrets (optional)
# ============================================

echo "======================================"
echo "OpenClaw VPS — Deploy Agent"
echo "======================================"
echo ""

# Check arguments
if [ $# -eq 0 ]; then
  echo "ERROR: No agent repository path provided."
  echo "Usage: bash scripts/deploy-agent.sh /path/to/agent-repo"
  exit 1
fi

AGENT_REPO_PATH="$1"

# Validate agent repo path
if [ ! -d "$AGENT_REPO_PATH" ]; then
  echo "ERROR: Agent repository not found at $AGENT_REPO_PATH"
  exit 1
fi

# Load environment
if [ ! -f .env ]; then
  echo "ERROR: .env file not found."
  echo "Please ensure .env exists before deploying agents."
  exit 1
fi

set -a
source .env
set +a

echo "[1/6] Validating agent repository structure..."
# Check for required files
if [ ! -f "$AGENT_REPO_PATH/SOUL.md" ]; then
  echo "ERROR: SOUL.md not found in agent repository."
  echo "Every agent must have a SOUL.md file."
  exit 1
fi

if [ ! -f "$AGENT_REPO_PATH/config.json" ]; then
  echo "ERROR: config.json not found in agent repository."
  echo "Every agent must have a config.json file."
  exit 1
fi

AGENT_NAME=$(basename "$AGENT_REPO_PATH")
echo "Agent: $AGENT_NAME"
echo "Repository validated."

echo ""
echo "[2/6] Creating agent workspace..."
AGENT_WORKSPACE="$OPENCLAW_WORKSPACE_DIR/$AGENT_NAME"
mkdir -p "$AGENT_WORKSPACE"
echo "Workspace: $AGENT_WORKSPACE"

echo ""
echo "[3/6] Copying agent files..."
# Copy SOUL.md
cp "$AGENT_REPO_PATH/SOUL.md" "$AGENT_WORKSPACE/SOUL.md"
echo "  ✓ SOUL.md"

# Copy skills if present
if [ -d "$AGENT_REPO_PATH/skills" ]; then
  cp -r "$AGENT_REPO_PATH/skills" "$AGENT_WORKSPACE/"
  echo "  ✓ skills/"
fi

# Copy agent-specific .env if present
if [ -f "$AGENT_REPO_PATH/.env.agent" ]; then
  cp "$AGENT_REPO_PATH/.env.agent" "$AGENT_WORKSPACE/.env"
  chmod 600 "$AGENT_WORKSPACE/.env"
  echo "  ✓ .env.agent → .env (permissions: 600)"
fi

echo "Agent files copied."

echo ""
echo "[4/6] Merging agent config into gateway config..."
# This is a simplified merge — in production you'd use jq or a proper config merger
GATEWAY_CONFIG="$OPENCLAW_STATE_DIR/config.json"

if [ ! -f "$GATEWAY_CONFIG" ]; then
  echo "Gateway config not found. Creating from template..."
  cp config/openclaw-config.template.json "$GATEWAY_CONFIG"
fi

# For now, just append a note to manually merge
# In a real implementation, you'd use jq to merge JSON
echo "NOTE: Manual config merge required."
echo "Agent config location: $AGENT_REPO_PATH/config.json"
echo "Gateway config location: $GATEWAY_CONFIG"
echo ""
echo "Please manually merge the agent's channel routing and skill registration."
echo "See docs/ADDING-AGENTS.md for guidance."

echo ""
echo "[5/6] Registering cron jobs (if any)..."
if [ -f "$AGENT_REPO_PATH/cron.txt" ]; then
  echo "Cron jobs found. Adding to crontab..."
  crontab -l > /tmp/current_cron 2>/dev/null || true
  cat "$AGENT_REPO_PATH/cron.txt" >> /tmp/current_cron
  crontab /tmp/current_cron
  rm /tmp/current_cron
  echo "  ✓ Cron jobs registered"
  crontab -l
else
  echo "No cron.txt found. Skipping cron registration."
fi

echo ""
echo "[6/6] Restarting OpenClaw gateway..."
cd docker
docker compose restart openclaw
echo "Gateway restarted."

echo ""
echo "======================================"
echo "Agent Deployment Complete!"
echo "======================================"
echo ""
echo "Agent: $AGENT_NAME"
echo "Workspace: $AGENT_WORKSPACE"
echo ""
echo "Next steps:"
echo "1. Verify the agent config was merged correctly:"
echo "   cat $GATEWAY_CONFIG"
echo ""
echo "2. Test the agent via Slack in its designated channel"
echo ""
echo "3. Monitor logs:"
echo "   cd docker && docker compose logs -f openclaw"
echo ""
echo "======================================"
