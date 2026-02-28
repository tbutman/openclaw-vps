#!/usr/bin/env bash
set -euo pipefail

# ============================================
# OpenClaw VPS — Backup Script
# ============================================
# Creates an encrypted backup of the OpenClaw state and configuration.
#
# This script backs up:
#   - ~/.openclaw/ (config, credentials, memory, conversation history)
#   - Agent workspace files
#   - Docker Compose configuration and .env files (encrypted)
#
# Usage:
#   bash scripts/backup.sh [output-path]
#
# If no output path is provided, backups are saved to ~/backups/
# ============================================

echo "======================================"
echo "OpenClaw VPS — Backup"
echo "======================================"
echo ""

# Load environment
if [ ! -f .env ]; then
  echo "ERROR: .env file not found."
  exit 1
fi

set -a
source .env
set +a

# Determine backup output path
BACKUP_DIR="${1:-$HOME/backups}"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="openclaw-backup-$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME.tar.gz"
ENCRYPTED_BACKUP_PATH="$BACKUP_PATH.enc"

echo "[1/4] Creating backup directory..."
TEMP_BACKUP_DIR="/tmp/$BACKUP_NAME"
mkdir -p "$TEMP_BACKUP_DIR"

echo ""
echo "[2/4] Copying files to backup..."

# Backup OpenClaw state directory
if [ -d "$OPENCLAW_STATE_DIR" ]; then
  echo "  ✓ Copying $OPENCLAW_STATE_DIR..."
  cp -r "$OPENCLAW_STATE_DIR" "$TEMP_BACKUP_DIR/openclaw-state"
else
  echo "  ⚠ OpenClaw state directory not found: $OPENCLAW_STATE_DIR"
fi

# Backup workspace directory
if [ -d "$OPENCLAW_WORKSPACE_DIR" ]; then
  echo "  ✓ Copying $OPENCLAW_WORKSPACE_DIR..."
  cp -r "$OPENCLAW_WORKSPACE_DIR" "$TEMP_BACKUP_DIR/workspace"
else
  echo "  ⚠ Workspace directory not found: $OPENCLAW_WORKSPACE_DIR"
fi

# Backup Docker configuration
if [ -d "docker" ]; then
  echo "  ✓ Copying docker/ configuration..."
  mkdir -p "$TEMP_BACKUP_DIR/docker"
  cp docker/docker-compose.yml "$TEMP_BACKUP_DIR/docker/" 2>/dev/null || true
  cp docker/Dockerfile "$TEMP_BACKUP_DIR/docker/" 2>/dev/null || true
  # Do NOT copy .env directly — it will be encrypted separately
fi

# Backup .env files (encrypted)
if [ -f .env ]; then
  echo "  ✓ Copying .env (will be encrypted)..."
  cp .env "$TEMP_BACKUP_DIR/env"
fi

echo ""
echo "[3/4] Creating compressed archive..."
tar -czf "$BACKUP_PATH" -C /tmp "$BACKUP_NAME"
echo "  ✓ Archive created: $BACKUP_PATH"

echo ""
echo "[4/4] Encrypting backup..."
# Encrypt using OpenSSL
# User will be prompted for a password
openssl enc -aes-256-cbc -salt -pbkdf2 -in "$BACKUP_PATH" -out "$ENCRYPTED_BACKUP_PATH"

if [ -f "$ENCRYPTED_BACKUP_PATH" ]; then
  echo "  ✓ Backup encrypted: $ENCRYPTED_BACKUP_PATH"
  # Remove unencrypted tar.gz
  rm "$BACKUP_PATH"
else
  echo "  ✗ Encryption failed."
  exit 1
fi

# Clean up temp directory
rm -rf "$TEMP_BACKUP_DIR"

BACKUP_SIZE=$(du -h "$ENCRYPTED_BACKUP_PATH" | cut -f1)

echo ""
echo "======================================"
echo "Backup Complete!"
echo "======================================"
echo ""
echo "Encrypted backup saved to:"
echo "  $ENCRYPTED_BACKUP_PATH"
echo "  Size: $BACKUP_SIZE"
echo ""
echo "To restore this backup on a new VPS:"
echo "  bash scripts/restore.sh $ENCRYPTED_BACKUP_PATH"
echo ""
echo "Keep this backup secure and remember your encryption password!"
echo "======================================"
