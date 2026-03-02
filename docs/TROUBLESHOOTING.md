# OpenClaw VPS — Troubleshooting

Common issues and their solutions.

---

## General Debugging

### Check Docker Containers

```bash
docker compose -f ~/openclaw-vps/docker/docker-compose.yml ps
```

All containers should show `Up`. If not, check logs.

### View Logs

**OpenClaw gateway:**

```bash
docker compose -f ~/openclaw-vps/docker/docker-compose.yml logs -f openclaw
```

**Chromium:**

```bash
docker compose -f ~/openclaw-vps/docker/docker-compose.yml logs -f chromium
```

**All containers:**

```bash
docker compose -f ~/openclaw-vps/docker/docker-compose.yml logs -f
```

Press `Ctrl+C` to exit logs.

---

## Installation Issues

### Issue: `.env` file not found during `install-openclaw.sh`

**Cause:** You didn't copy `.env.example` to `.env`.

**Solution:**

```bash
cd ~/openclaw-vps
cp .env.example .env
nano .env  # Fill in your credentials
chmod 600 .env
bash scripts/install-openclaw.sh
```

---

### Issue: Docker build fails with "npm install" errors

**Cause:** Network issues or missing dependencies.

**Solution:**

1. Check internet connectivity:
   ```bash
   ping -c 3 google.com
   ```

2. Rebuild with no cache:
   ```bash
   cd ~/openclaw-vps/docker
   docker compose build --no-cache
   ```

3. If it still fails, check Docker logs:
   ```bash
   docker compose logs openclaw
   ```

---

### Issue: Swap file creation fails

**Cause:** Not enough disk space.

**Solution:**

1. Check disk usage:
   ```bash
   df -h
   ```

2. If disk is full, delete unnecessary files or resize the VPS disk in Hetzner Console.

3. If you have enough space, manually create swap:
   ```bash
   sudo fallocate -l 4G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

---

## Slack Issues

### Issue: Pairing approval doesn't persist / Bot keeps asking for pairing code

**Cause:** Permission mismatch in the OpenClaw state directory. Some credential files are owned by root instead of the openclaw user.

**Solution:**

Fix file ownership:
```bash
cd ~/.openclaw/credentials
sudo chown -R openclaw:openclaw ~/.openclaw/
sudo chmod 600 ~/.openclaw/credentials/*
```

Restart the gateway:
```bash
docker compose -f ~/openclaw-vps/docker/docker-compose.yml restart openclaw
```

**Permanent fix:** Rebuild the Docker image to include the entrypoint permission fix:
```bash
cd ~/openclaw-vps/docker
docker compose build --no-cache openclaw
docker compose restart openclaw
```

---

### Issue: Slack bot doesn't respond to messages

**Possible causes:**

1. **Pairing not approved**
   - Send a DM to the bot
   - It will respond with a pairing code
   - Approve it:
     ```bash
     docker compose -f ~/openclaw-vps/docker/docker-compose.yml exec openclaw openclaw pairing approve slack <code>
     ```

2. **Wrong channel**
   - Check if the channel ID is in `allowedChannels` in `~/.openclaw/config.json`
   - Get channel ID: Right-click channel → View channel details → Copy ID

3. **Slack tokens invalid**
   - Verify tokens are correct in `.env`:
     ```bash
     cat ~/openclaw-vps/.env | grep SLACK
     ```
   - Regenerate tokens at [api.slack.com/apps](https://api.slack.com/apps)

4. **Socket Mode connection failed**
   - Check logs:
     ```bash
     docker compose logs openclaw | grep -i slack
     ```

---

### Issue: "Sending messages to this app has been turned off" in Slack DM

**Cause:** The Messages Tab is not enabled in the Slack app's App Home settings.

**Solution:**

1. Go to https://api.slack.com/apps → Your app
2. Click **"App Home"** in the left sidebar
3. Scroll to the **"Messages Tab"** section
4. Check the box: **"Allow users to send Slash commands and messages from the messages tab"**
5. If prompted, reinstall the app to Workspace
6. Refresh the Slack DM window or close/reopen it

The bot should now accept messages.

---

### Issue: "Invalid token" error in logs

**Cause:** Slack tokens are incorrect or expired.

**Solution:**

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → Your App
2. Regenerate:
   - **App-Level Token:** Socket Mode → Regenerate token
   - **Bot Token:** OAuth & Permissions → Reinstall to Workspace
3. Update `.env`:
   ```bash
   nano ~/openclaw-vps/.env
   # Update SLACK_APP_TOKEN and SLACK_BOT_TOKEN
   chmod 600 ~/openclaw-vps/.env
   ```
4. Restart gateway:
   ```bash
   docker compose -f ~/openclaw-vps/docker/docker-compose.yml restart openclaw
   ```

---

### Issue: "Rate limit exceeded" error

**Cause:** Too many Slack API requests in a short time.

**Solution:**

Wait a few minutes. OpenClaw has built-in rate limiting, but if you're sending hundreds of messages, Slack may throttle you.

If this happens frequently, adjust the rate limit in `~/.openclaw/config.json`:

```json
{
  "security": {
    "rateLimit": {
      "enabled": true,
      "maxRequests": 10,  // Lower this
      "windowMs": 60000
    }
  }
}
```

---

## Tailscale Issues

### Issue: Cannot access Control UI via Tailscale Serve

**Possible causes:**

1. **Tailscale not running inside container**
   ```bash
   docker compose -f ~/openclaw-vps/docker/docker-compose.yml exec openclaw tailscale status
   ```
   If error or offline, check container logs:
   ```bash
   docker compose -f ~/openclaw-vps/docker/docker-compose.yml logs openclaw | grep -i tailscale
   ```

2. **Tailscale not running on your laptop**
   - Open Tailscale app and ensure it's connected to the same tailnet

3. **Tailscale Serve not enabled for your tailnet**
   - Check container logs for a URL to enable Serve
   - Visit the URL and enable Serve
   - Restart the container:
   ```bash
   docker compose -f ~/openclaw-vps/docker/docker-compose.yml restart openclaw
   ```

4. **OpenClaw container not running**
   ```bash
   docker compose -f ~/openclaw-vps/docker/docker-compose.yml ps
   ```
   If down:
   ```bash
   docker compose -f ~/openclaw-vps/docker/docker-compose.yml up -d
   ```

5. **Wrong Tailscale URL**
   - Get the correct URL from container:
   ```bash
   docker compose -f ~/openclaw-vps/docker/docker-compose.yml exec openclaw tailscale status --json | grep -o '"HostName":"[^"]*"'
   ```
   - Access via: `https://<hostname>.<tailnet>.ts.net`

---

### Issue: Tailscale Serve "Connection refused"

**Cause:** OpenClaw may not have finished starting when Tailscale Serve was configured.

**Solution:**

Restart the container to re-trigger Tailscale Serve setup:

```bash
docker compose -f ~/openclaw-vps/docker/docker-compose.yml restart openclaw
```

Look for the VPS hostname (e.g., `openclaw-vps`), then access:

```
http://openclaw-vps:18789
```

---

### Issue: Control UI shows "pairing required" or "device identity required"

**Cause:** Gateway auth mode is not configured for Tailscale identity authentication.

**Solution:**

The config needs `trusted-proxy` mode to accept Tailscale identity headers:

```bash
nano ~/.openclaw/openclaw.json
```

Verify the `gateway.auth` section looks like this:

```json
"auth": {
  "mode": "trusted-proxy",
  "trustedProxy": {
    "userHeader": "tailscale-user-login"
  },
  "allowTailscale": true
}
```

And ensure `trustedProxies` is set:

```json
"trustedProxies": ["127.0.0.1", "::1"]
```

Then restart:

```bash
docker compose -f ~/openclaw-vps/docker/docker-compose.yml restart openclaw
```

The Control UI should now load without device pairing when accessed via Tailscale Serve.

---

## SSH Issues

### Issue: "Permission denied (publickey)" when SSH-ing

**Cause:** SSH key not authorized on the VPS.

**Solution:**

1. **From your laptop:**
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

2. **On the VPS (via Hetzner Console):**
   ```bash
   sudo su - openclaw
   mkdir -p ~/.ssh
   nano ~/.ssh/authorized_keys
   # Paste your public key
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   exit
   ```

3. Try SSH again:
   ```bash
   ssh openclaw@<vps-ip>
   ```

---

### Issue: "Connection refused" when SSH-ing

**Possible causes:**

1. **VPS is down**
   - Check Hetzner Console → Ensure VPS is running

2. **SSH port changed**
   - If you changed the SSH port from 22 to something else, use:
     ```bash
     ssh -p 2222 openclaw@<vps-ip>
     ```

3. **Firewall blocking SSH**
   - Via Hetzner Console, log in and check UFW:
     ```bash
     sudo ufw status
     ```
   - If SSH is blocked:
     ```bash
     sudo ufw allow 22/tcp
     ```

---

## Docker Issues

### Issue: "Cannot connect to the Docker daemon"

**Cause:** Docker service is not running.

**Solution:**

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

Verify:

```bash
docker ps
```

---

### Issue: "docker compose: command not found"

**Cause:** Docker Compose plugin not installed.

**Solution:**

```bash
sudo apt update
sudo apt install docker-compose-plugin
docker compose version
```

---

### Issue: Container keeps restarting

**Cause:** Error in OpenClaw or config.

**Solution:**

1. Check logs:
   ```bash
   docker compose logs openclaw
   ```

2. Look for errors like:
   - `ANTHROPIC_API_KEY is not set` → Fix `.env`
   - `config.json parse error` → Fix JSON syntax in config

3. Fix the issue and restart:
   ```bash
   docker compose restart openclaw
   ```

---

## Agent Issues

### Issue: Agent not responding in its designated channel

**Possible causes:**

1. **Channel ID mismatch**
   - Get channel ID: Right-click channel → View channel details → Copy ID
   - Check `~/.openclaw/config.json`:
     ```json
     {
       "channels": {
         "slack": {
           "allowedChannels": ["C12345678"]  // Must match
         }
       }
     }
     ```

2. **Agent not deployed**
   - Verify agent files exist:
     ```bash
     ls ~/workspace/openclaw-job-search-agent/
     ```
   - Redeploy:
     ```bash
     bash ~/openclaw-vps/scripts/deploy-agent.sh ~/openclaw-job-search-agent
     ```

3. **Agent config not merged**
   - Check `~/.openclaw/config.json` for the agent's entry in `agents` array

---

### Issue: Cron jobs not running

**Possible causes:**

1. **Cron not registered**
   ```bash
   crontab -l
   ```
   If missing, redeploy agent:
   ```bash
   bash ~/openclaw-vps/scripts/deploy-agent.sh ~/openclaw-job-search-agent
   ```

2. **Cron syntax error**
   - Validate cron syntax at [crontab.guru](https://crontab.guru)

3. **Cron command path wrong**
   - Test the command manually:
     ```bash
     /usr/local/bin/openclaw run job-search check-new-jobs
     ```

---

## Performance Issues

### Issue: VPS running out of memory

**Cause:** OpenClaw + Chromium + agents can use 3-4GB RAM.

**Solution:**

1. Check memory usage:
   ```bash
   free -h
   ```

2. If swap is full, consider upgrading to CX32 (8GB RAM):
   - [Hetzner Console](https://console.hetzner.cloud) → Resize server → CX32

3. Restart Docker to clear memory:
   ```bash
   docker compose -f ~/openclaw-vps/docker/docker-compose.yml restart
   ```

---

### Issue: OpenClaw responses are slow

**Possible causes:**

1. **Anthropic API rate limit**
   - Check Anthropic Console for rate limit errors
   - Upgrade to higher tier if needed

2. **Network latency**
   - Check ping to Anthropic API:
     ```bash
     ping -c 5 api.anthropic.com
     ```

3. **Container resource limits**
   - Remove resource limits in `docker-compose.yml` (if any)

---

## Backup & Restore Issues

### Issue: Backup encryption fails

**Cause:** OpenSSL not installed or password not provided.

**Solution:**

1. Verify OpenSSL is installed:
   ```bash
   openssl version
   ```

2. Run backup again:
   ```bash
   bash ~/openclaw-vps/scripts/backup.sh
   ```

3. Enter a strong password when prompted.

---

### Issue: Restore decryption fails

**Cause:** Wrong password or corrupted backup file.

**Solution:**

1. Verify the backup file exists and is readable:
   ```bash
   ls -lh ~/backups/*.tar.gz.enc
   ```

2. Try decrypting manually:
   ```bash
   openssl enc -aes-256-cbc -d -pbkdf2 -in ~/backups/openclaw-backup-20260228_120000.tar.gz.enc -out /tmp/test.tar.gz
   ```

3. If decryption succeeds, run restore again:
   ```bash
   bash ~/openclaw-vps/scripts/restore.sh ~/backups/openclaw-backup-20260228_120000.tar.gz.enc
   ```

---

## Still Stuck?

### 1. Check the Full Plan

The full architecture and design are documented in [OPENCLAW-VPS-PLAN.md](../OPENCLAW-VPS-PLAN.md).

### 2. Check OpenClaw Docs

Visit [openclaw.ai/docs](https://openclaw.ai/docs) *(placeholder)* for official documentation.

### 3. Open a GitHub Issue

If you believe there's a bug in the `openclaw-vps` infrastructure, open an issue at:

```
https://github.com/<your-username>/openclaw-vps/issues
```

Include:
- What you were trying to do
- What went wrong
- Relevant logs (`docker compose logs`)
- Your VPS specs (CX22, Ubuntu 24.04, etc.)

---

## Emergency: Nuclear Option

If everything is broken and you want to start fresh:

### 1. Backup State (if possible)

```bash
bash ~/openclaw-vps/scripts/backup.sh
```

### 2. Destroy VPS

- Go to [Hetzner Console](https://console.hetzner.cloud)
- Delete the VPS

### 3. Re-provision

Follow [SETUP.md](SETUP.md) from the beginning.

### 4. Restore from Backup

```bash
bash ~/openclaw-vps/scripts/restore.sh /path/to/backup.tar.gz.enc
```

---

**Remember:** Most issues can be fixed by checking logs and verifying configuration. Start with `docker compose logs` before nuking everything.
