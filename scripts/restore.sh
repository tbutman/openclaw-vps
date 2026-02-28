#!/usr/bin/env bash
set -euo pipefail

# ============================================
# OpenClaw VPS — Restore Script
# ============================================
# Restores an encrypted backup of OpenClaw state and configuration.
# Run on a fresh VPS after bootstrap-vps.sh completes.
#
# This script:
#   - Decrypts the backup
#   - Restores OpenClaw state directory
#   - Restores workspace files
#   - Restores Docker configuration and .env
#   - Restarts the gateway
#
# Usage:
#   bash scripts/restore.sh /path/to/backup.tar.gz.enc
# ============================================

echo "======================================"
echo "OpenClaw VPS — Restore from Backup"
echo "======================================"
echo ""

# Check arguments
if [ $# -eq 0 ]; then
  echo "ERROR: No backup file provided."
  echo "Usage: bash scripts/restore.sh /path/to/backup.tar.gz.enc"
  exit 1
fi

ENCRYPTED_BACKUP_PATH="$1"

# Validate backup file
if [ ! -f "$ENCRYPTED_BACKUP_PATH" ]; then
  echo "ERROR: Backup file not found: $ENCRYPTED_BACKUP_PATH"
  exit 1
fi

DECRYPTED_BACKUP_PATH="${ENCRYPTED_BACKUP_PATH%.enc}"
BACKUP_NAME=$(basename "$DECRYPTED_BACKUP_PATH" .tar.gz)
TEMP_RESTORE_DIR="/tmp/$BACKUP_NAME"

echo "[1/5] Decrypting backup..."
# Decrypt using OpenSSL
# User will be prompted for the password
openssl enc -aes-256-cbc -d -pbkdf2 -in "$ENCRYPTED_BACKUP_PATH" -out "$DECRYPTED_BACKUP_PATH"

if [ ! -f "$DECRYPTED_BACKUP_PATH" ]; then
  echo "ERROR: Decryption failed. Check your password."
  exit 1
fi

echo "  ✓ Backup decrypted."

echo ""
echo "[2/5] Extracting backup archive..."
mkdir -p "$TEMP_RESTORE_DIR"
tar -xzf "$DECRYPTED_BACKUP_PATH" -C /tmp
echo "  ✓ Backup extracted to $TEMP_RESTORE_DIR"

echo ""
echo "[3/5] Restoring OpenClaw state..."
if [ -d "$TEMP_RESTORE_DIR/openclaw-state" ]; then
  OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
  mkdir -p "$OPENCLAW_STATE_DIR"
  cp -r "$TEMP_RESTORE_DIR/openclaw-state/"* "$OPENCLAW_STATE_DIR/"
  echo "  ✓ OpenClaw state restored to $OPENCLAW_STATE_DIR"
else
  echo "  ⚠ No OpenClaw state found in backup."
fi

echo ""
echo "[4/5] Restoring workspace..."
if [ -d "$TEMP_RESTORE_DIR/workspace" ]; then
  OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$HOME/workspace}"
  mkdir -p "$OPENCLAW_WORKSPACE_DIR"
  cp -r "$TEMP_RESTORE_DIR/workspace/"* "$OPENCLAW_WORKSPACE_DIR/"
  echo "  ✓ Workspace restored to $OPENCLAW_WORKSPACE_DIR"
else
  echo "  ⚠ No workspace found in backup."
fi

# Restore .env file
if [ -f "$TEMP_RESTORE_DIR/env" ]; then
  cp "$TEMP_RESTORE_DIR/env" .env
  chmod 600 .env
  echo "  ✓ .env restored (permissions: 600)"
fi

# Restore Docker configuration
if [ -d "$TEMP_RESTORE_DIR/docker" ]; then
  mkdir -p docker
  cp -r "$TEMP_RESTORE_DIR/docker/"* docker/
  echo "  ✓ Docker configuration restored"
fi

echo ""
echo "[5/5] Restarting OpenClaw gateway..."
if [ -d "docker" ] && [ -f "docker/docker-compose.yml" ]; then
  cd docker
  docker compose down 2>/dev/null || true
  docker compose up -d
  echo "  ✓ Gateway restarted"
else
  echo "  ⚠ Docker configuration not found. Skipping restart."
  echo "  Run: bash scripts/install-openclaw.sh to start the gateway."
fi

# Clean up
rm -rf "$TEMP_RESTORE_DIR"
rm "$DECRYPTED_BACKUP_PATH"

echo ""
echo "======================================"
echo "Restore Complete!"
echo "======================================"
echo ""
echo "OpenClaw state and configuration have been restored."
echo ""
echo "Next steps:"
echo "1. Verify the gateway is running:"
echo "   docker compose -f docker/docker-compose.yml ps"
echo ""
echo "2. Check logs:"
echo "   docker compose -f docker/docker-compose.yml logs -f"
echo ""
echo "3. Access Control UI via Tailscale:"
echo "   http://$(tailscale ip -4 2>/dev/null || echo '<tailscale-ip>'):18789"
echo ""
echo "======================================"
