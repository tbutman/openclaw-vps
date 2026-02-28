# OpenClaw VPS — Security Guide

This document covers security hardening, best practices, and the security model for the OpenClaw VPS.

---

## Security Model Overview

The OpenClaw VPS is designed with a **zero-trust, defense-in-depth** approach:

1. **No public services exposed** — OpenClaw gateway only accessible via Tailscale
2. **Key-based SSH only** — Password authentication disabled
3. **Firewall locked down** — UFW denies all inbound except Tailscale + SSH
4. **fail2ban active** — Auto-bans brute-force SSH attempts
5. **Docker containers run as non-root** — UID 1000
6. **Consent mode enabled** — All OpenClaw commands require approval
7. **Automatic security updates** — Unattended upgrades enabled

---

## 1. SSH Hardening

### What's Configured by `bootstrap-vps.sh`

- **PermitRootLogin:** `no` — Root cannot log in via SSH
- **PasswordAuthentication:** `no` — Only SSH keys allowed
- **PubkeyAuthentication:** `yes` — SSH keys are required
- **ChallengeResponseAuthentication:** `no` — No keyboard-interactive auth

### Verify Configuration

```bash
sudo grep -E 'PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config
```

Expected output:
```
PermitRootLogin no
PasswordAuthentication no
```

### (Optional) Change SSH Port

To reduce automated brute-force attempts, change SSH from port 22 to a non-standard port:

1. Edit `/etc/ssh/sshd_config`:
   ```bash
   sudo nano /etc/ssh/sshd_config
   ```

2. Change:
   ```
   Port 22
   ```
   to:
   ```
   Port 2222
   ```

3. Update UFW to allow the new port:
   ```bash
   sudo ufw delete limit 22/tcp
   sudo ufw limit 2222/tcp
   ```

4. Restart SSH:
   ```bash
   sudo systemctl restart sshd
   ```

5. Test the new port **before closing your current session**:
   ```bash
   ssh -p 2222 openclaw@<vps-ip>
   ```

---

## 2. Firewall (UFW)

### Default Policy

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

All inbound traffic is **denied by default** unless explicitly allowed.

### Active Rules

```bash
sudo ufw status verbose
```

Expected output:

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     LIMIT       Anywhere
Anywhere on tailscale0     ALLOW       Anywhere
```

### What Each Rule Does

- **22/tcp LIMIT** — Allow SSH but rate-limit to prevent brute-force
- **Anywhere on tailscale0 ALLOW** — Allow all traffic from Tailscale VPN

**No other ports are exposed.** The OpenClaw gateway (port 18789) is only accessible via Tailscale.

### Verify OpenClaw Port is NOT Publicly Accessible

From your **local machine** (not the VPS), try:

```bash
curl http://<vps-public-ip>:18789
```

Expected result: **Connection refused or timeout.** This is correct.

Now try via Tailscale:

```bash
curl http://<tailscale-ip>:18789/health
```

Expected result: **200 OK** or health check response.

---

## 3. fail2ban

### What It Does

fail2ban monitors SSH login attempts and automatically bans IPs that fail authentication multiple times.

### Configuration

Default config (in `/etc/fail2ban/jail.local`):

```ini
[DEFAULT]
bantime = 600        # Ban for 10 minutes
findtime = 600       # Look for failures in last 10 minutes
maxretry = 5         # Max 5 failures before ban

[sshd]
enabled = true
port = 22
logpath = %(sshd_log)s
backend = systemd
```

### Check Status

```bash
sudo fail2ban-client status sshd
```

Example output:

```
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
|  `- File list:        /var/log/auth.log
`- Actions
   |- Currently banned: 0
   |- Total banned:     0
   `- Banned IP list:
```

### Unban an IP (if you accidentally locked yourself out)

From another device or the Hetzner Console:

```bash
sudo fail2ban-client set sshd unbanip <your-ip>
```

---

## 4. Tailscale

### Why Tailscale?

Tailscale provides a **zero-config VPN** that:
- Encrypts all traffic between your devices and the VPS
- Authenticates via your Tailscale account (no open ports needed)
- Prevents public access to the OpenClaw Control UI

### Verify Tailscale is Running

```bash
tailscale status
```

Expected output:

```
<vps-hostname>       openclaw@    linux   -
100.x.y.z           <your-laptop> macOS   active
```

### Access Control

By default, all devices on your Tailscale network can reach the VPS. To restrict access:

1. Go to [login.tailscale.com/admin/acls](https://login.tailscale.com/admin/acls)
2. Configure ACLs to limit which devices can reach the VPS

Example ACL:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:admins"],
      "dst": ["tag:openclaw:*"]
    }
  ],
  "groups": {
    "group:admins": ["you@example.com"]
  },
  "tagOwners": {
    "tag:openclaw": ["you@example.com"]
  }
}
```

---

## 5. Docker Security

### Non-Root Containers

The OpenClaw container runs as UID 1000 (`openclaw` user), **not root**.

Verify:

```bash
docker compose -f docker/docker-compose.yml exec openclaw id
```

Expected output:

```
uid=1000(openclaw) gid=1000(openclaw) groups=1000(openclaw)
```

### No Privileged Containers

Verify no containers are running with `--privileged`:

```bash
docker inspect openclaw-gateway | grep Privileged
docker inspect openclaw-chromium | grep Privileged
```

Expected output for both: `"Privileged": false`

### Volume Permissions

The `.env` file and OpenClaw state directory must be **readable only by the owner**:

```bash
ls -l .env
ls -ld ~/.openclaw
```

Expected output:

```
-rw------- 1 openclaw openclaw  .env
drwx------ 2 openclaw openclaw  .openclaw
```

If permissions are wrong, fix them:

```bash
chmod 600 .env
chmod 700 ~/.openclaw
```

---

## 6. OpenClaw Gateway Security

### Consent Mode

OpenClaw is configured with **consent mode** enabled (`"ask": "on"`). This means:
- All commands that execute code, run scripts, or access sensitive data require **approval**
- You approve commands via the Control UI or CLI pairing

Verify in `config/openclaw-config.template.json`:

```json
{
  "exec": {
    "ask": "on"
  }
}
```

### Pairing Required for DMs

New Slack DMs require a **pairing code** before the agent will respond.

Verify:

```json
{
  "channels": {
    "slack": {
      "dmPolicy": "pairing"
    }
  }
}
```

### Rate Limiting

API requests to OpenClaw are rate-limited to **30 requests per minute** per user.

Verify:

```json
{
  "security": {
    "rateLimit": {
      "enabled": true,
      "maxRequests": 30,
      "windowMs": 60000
    }
  }
}
```

---

## 7. Automatic Updates

### Unattended Upgrades

The VPS is configured to automatically install **security updates** via `unattended-upgrades`.

Verify it's enabled:

```bash
sudo systemctl status unattended-upgrades
```

Expected output: `active (running)`

Logs:

```bash
sudo journalctl -u unattended-upgrades -f
```

### Manual Updates

To manually update all packages:

```bash
sudo apt update
sudo apt upgrade -y
```

---

## 8. Secrets Management

### Where Secrets Live

| Secret                  | Location                  | Permissions |
|-------------------------|---------------------------|-------------|
| `.env` (gateway creds)  | `~/openclaw-vps/.env`     | `600`       |
| Agent-specific `.env`   | `~/workspace/<agent>/.env`| `600`       |
| OpenClaw state          | `~/.openclaw/`            | `700`       |

### Never Commit Secrets to Git

The `.gitignore` file excludes:
- `.env`
- `.env.*` (except `.env.example`)
- `.openclaw/`
- `workspace/`
- `*.tar.gz.enc` (backups)

Always verify before committing:

```bash
git status
```

If `.env` appears, **do not commit it.**

---

## 9. Backup Security

### Encrypted Backups

All backups created by `backup.sh` are **encrypted with AES-256-CBC** via OpenSSL.

When you run:

```bash
bash scripts/backup.sh
```

You'll be prompted for a **password**. This password is **required to restore** the backup. **Do not lose it.**

### Backup Storage

- **Local backups:** Stored in `~/backups/` on the VPS (encrypted)
- **Off-site backups:** You should copy backups to a secure location (e.g., encrypted cloud storage, external drive)

**Do not store unencrypted backups.**

---

## 10. Monitoring & Alerts

### Basic Health Checks

Check if OpenClaw is running:

```bash
docker compose -f docker/docker-compose.yml ps
```

Check container health:

```bash
docker inspect openclaw-gateway | grep Health -A 10
```

### (Optional) Set Up Uptime Monitoring

Use a free uptime monitor like:
- [Uptime Robot](https://uptimerobot.com) — Free tier monitors HTTP endpoints
- [Healthchecks.io](https://healthchecks.io) — Free tier for cron job monitoring

Monitor the OpenClaw health endpoint:

```
http://<tailscale-ip>:18789/health
```

---

## 11. Incident Response

### If You Suspect a Breach

1. **Immediately revoke API keys:**
   - Anthropic: [console.anthropic.com](https://console.anthropic.com)
   - Slack: [api.slack.com/apps](https://api.slack.com/apps) → Your App → Revoke tokens

2. **Rotate Tailscale auth key:**
   - [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)

3. **Check Docker logs for anomalies:**
   ```bash
   docker compose -f docker/docker-compose.yml logs --tail=500
   ```

4. **Check SSH auth logs:**
   ```bash
   sudo journalctl -u ssh -n 100
   ```

5. **Destroy and rebuild the VPS:**
   - Create a new backup (if safe)
   - Delete the Hetzner server
   - Re-provision from scratch

---

## 12. Security Checklist

Use this checklist to verify your deployment is secure:

- [ ] SSH key-only authentication enabled
- [ ] Root login via SSH disabled
- [ ] UFW firewall active and configured
- [ ] fail2ban active and monitoring SSH
- [ ] Tailscale connected and authenticated
- [ ] OpenClaw Control UI only accessible via Tailscale
- [ ] `.env` file has permissions `600`
- [ ] `.openclaw/` directory has permissions `700`
- [ ] Docker containers run as non-root (UID 1000)
- [ ] No `--privileged` containers
- [ ] OpenClaw consent mode enabled (`"ask": "on"`)
- [ ] OpenClaw DM pairing required (`"pairing"`)
- [ ] OpenClaw rate limiting enabled
- [ ] Unattended upgrades enabled
- [ ] Backups encrypted and stored off-site
- [ ] Secrets never committed to Git

---

## Questions or Issues?

If you discover a security issue, please **do not open a public GitHub issue.** Instead, email `security@yourdomain.com` (replace with your contact).

For general questions, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
