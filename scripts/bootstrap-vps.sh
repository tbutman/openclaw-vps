#!/usr/bin/env bash
set -euo pipefail

# ============================================
# OpenClaw VPS — Bootstrap Script
# ============================================
# First-run provisioning script for a fresh Ubuntu 24.04 VPS.
# Run as root on a new Hetzner VPS.
#
# This script:
#   - Creates a non-root user (openclaw)
#   - Configures SSH (key-only, no root login)
#   - Installs Docker + Docker Compose
#   - Configures UFW firewall
#   - Installs & configures fail2ban
#   - Enables unattended-upgrades
#   - Creates swap file
#   - Creates OpenClaw directories
#
# Note: Tailscale runs inside the Docker container, not on the host
#
# Usage:
#   bash scripts/bootstrap-vps.sh
# ============================================

echo "======================================"
echo "OpenClaw VPS Bootstrap"
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root."
  echo "Usage: sudo bash scripts/bootstrap-vps.sh"
  exit 1
fi

# Configuration
OPENCLAW_USER="openclaw"
OPENCLAW_HOME="/home/$OPENCLAW_USER"
SWAP_SIZE="4G"

echo "[1/10] Updating system packages and installing utilities..."
apt-get update
apt-get upgrade -y
apt-get install -y jq curl git

echo ""
echo "[2/10] Creating non-root user: $OPENCLAW_USER..."
if id "$OPENCLAW_USER" &>/dev/null; then
  echo "User $OPENCLAW_USER already exists. Skipping creation."
else
  useradd -m -s /bin/bash "$OPENCLAW_USER"
  usermod -aG sudo "$OPENCLAW_USER"
  echo "$OPENCLAW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/openclaw
  chmod 440 /etc/sudoers.d/openclaw
  echo "User $OPENCLAW_USER created."
fi

# Copy authorized_keys from root to openclaw user
if [ -d /root/.ssh ] && [ -f /root/.ssh/authorized_keys ]; then
  echo "Copying SSH keys from root to $OPENCLAW_USER..."
  mkdir -p "$OPENCLAW_HOME/.ssh"
  cp /root/.ssh/authorized_keys "$OPENCLAW_HOME/.ssh/authorized_keys"
  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_HOME/.ssh"
  chmod 700 "$OPENCLAW_HOME/.ssh"
  chmod 600 "$OPENCLAW_HOME/.ssh/authorized_keys"
fi

echo ""
echo "[3/10] Hardening SSH configuration..."
# Backup original sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Configure SSH hardening
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# Restart SSH to apply changes
systemctl restart ssh
echo "SSH hardened: key-only auth, root login disabled."

echo ""
echo "[4/10] Installing Docker..."
# Install prerequisites
apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add openclaw user to docker group
usermod -aG docker "$OPENCLAW_USER"
echo "Docker installed. Version:"
docker --version
docker compose version

echo ""
echo "[5/10] Skipping Tailscale installation..."
echo "Tailscale will run inside the OpenClaw Docker container."

echo ""
echo "[6/10] Configuring UFW firewall..."
# Install UFW if not present
apt-get install -y ufw

# Default policies
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (rate-limited)
ufw limit 22/tcp comment 'SSH rate-limited'

# Note: Tailscale runs inside Docker container, no host firewall rule needed

# Enable UFW
ufw --force enable
echo "UFW firewall configured and enabled."
ufw status verbose

echo ""
echo "[7/10] Installing and configuring fail2ban..."
apt-get install -y fail2ban

# Create custom fail2ban config for SSH
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = %(sshd_log)s
backend = systemd
EOF

systemctl enable fail2ban
systemctl restart fail2ban
echo "fail2ban installed and configured for SSH."

echo ""
echo "[8/10] Enabling unattended-upgrades for automatic security updates..."
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
echo "Unattended upgrades enabled."

echo ""
echo "[9/10] Creating swap file ($SWAP_SIZE)..."
if [ -f /swapfile ]; then
  echo "Swap file already exists. Skipping creation."
else
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "Swap file created and enabled."
  swapon --show
fi

echo ""
echo "[10/10] Creating OpenClaw directories..."
mkdir -p "$OPENCLAW_HOME/.openclaw"
mkdir -p "$OPENCLAW_HOME/workspace"
chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_HOME/.openclaw"
chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_HOME/workspace"
echo "OpenClaw directories created."

echo ""
echo "======================================"
echo "Bootstrap Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Exit and SSH back in as the openclaw user:"
echo "   ssh $OPENCLAW_USER@<vps-ip>"
echo ""
echo "2. Clone this repo to the openclaw user's home directory:"
echo "   git clone https://github.com/<your-username>/openclaw-vps.git"
echo "   cd openclaw-vps"
echo ""
echo "3. Configure credentials:"
echo "   cp .env.example .env"
echo "   nano .env  # Fill in your API keys and tokens (including TAILSCALE_AUTHKEY)"
echo "   chmod 600 .env"
echo ""
echo "4. Install OpenClaw:"
echo "   bash scripts/install-openclaw.sh"
echo ""
echo "======================================"
