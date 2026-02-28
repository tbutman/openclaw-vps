# OpenClaw VPS — Full Setup Guide

This document provides step-by-step instructions for deploying OpenClaw on a Hetzner VPS.

---

## Prerequisites

Before you begin, ensure you have:

### Accounts
- [ ] **Hetzner Cloud account** — [hetzner.com](https://hetzner.com) with payment method
- [ ] **Anthropic API account** — [console.anthropic.com](https://console.anthropic.com) with API key and billing
- [ ] **Tailscale account** — [login.tailscale.com](https://login.tailscale.com) (free tier)
- [ ] **Slack workspace** — Free or paid workspace
- [ ] **GitHub account** — For version control (optional but recommended)

### Local Machine
- [ ] **SSH key pair** — Generate with `ssh-keygen -t ed25519` if needed
- [ ] **Tailscale installed** — On your laptop/phone for VPN access
- [ ] **Slack installed** — On your laptop/phone for testing
- [ ] **Git installed** — For cloning repositories

### Credentials Ready
- [ ] Anthropic API key (`sk-ant-...`)
- [ ] Slack App-Level Token (`xapp-...`) — See Phase 0 below
- [ ] Slack Bot Token (`xoxb-...`) — See Phase 0 below
- [ ] Tailscale auth key (`tskey-auth-...`) — Generate a reusable key

---

## Phase 0: Create Slack App

**Do this BEFORE provisioning the VPS.**

### Step 1: Create Slack App

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App** → **From scratch**
3. Name: `OpenClaw Assistant` (or your preference)
4. Select your workspace
5. Click **Create App**

### Step 2: Enable Socket Mode

1. In the sidebar, click **Socket Mode**
2. Toggle **Enable Socket Mode** to ON
3. Click **Generate an app-level token to enable Socket Mode**
4. Token name: `openclaw-socket`
5. Scope: `connections:write`
6. Click **Generate**
7. **Copy the token** → This is your `SLACK_APP_TOKEN` (starts with `xapp-`)
8. Click **Done**

### Step 3: Configure Bot Permissions

1. In the sidebar, click **OAuth & Permissions**
2. Scroll to **Bot Token Scopes**
3. Click **Add an OAuth Scope** and add the following:
   - `chat:write`
   - `app_mentions:read`
   - `channels:history`
   - `channels:read`
   - `groups:history`
   - `im:history`
   - `im:read`
   - `im:write`
   - `mpim:history`
   - `reactions:read`
   - `reactions:write`
   - `files:write`
   - `users:read`

### Step 4: Install App to Workspace

1. Scroll to the top of the **OAuth & Permissions** page
2. Click **Install to Workspace**
3. Review permissions and click **Allow**
4. **Copy the Bot User OAuth Token** → This is your `SLACK_BOT_TOKEN` (starts with `xoxb-`)

### Step 5: Subscribe to Events

1. In the sidebar, click **Event Subscriptions**
2. Toggle **Enable Events** to ON
3. Under **Subscribe to bot events**, add:
   - `message.im`
   - `message.channels`
   - `message.groups`
   - `app_mention`
4. Click **Save Changes**

**You're done!** Keep your `SLACK_APP_TOKEN` and `SLACK_BOT_TOKEN` handy for Phase 2.

---

## Phase 1: Provision VPS

### Step 1: Create Hetzner Server

1. Log in to [console.hetzner.cloud](https://console.hetzner.cloud)
2. Click **New Project** → Name it (e.g., `openclaw-vps`)
3. Click **Add Server**
4. Configure:
   - **Location:** Helsinki or Falkenstein
   - **Image:** Ubuntu 24.04
   - **Type:** CX22 (2 vCPU, 4GB RAM, 40GB SSD)
   - **Networking:** IPv4 + IPv6 (default)
   - **SSH Keys:** Add your public SSH key (or create one now)
   - **Volume:** None
   - **Firewall:** None (we'll configure UFW instead)
   - **Backups:** Optional (not needed if you use `backup.sh`)
   - **Name:** `openclaw-vps`
5. Click **Create & Buy Now**

Wait 1-2 minutes for the server to provision. Note the public IPv4 address.

### Step 2: SSH into VPS as Root

```bash
ssh root@<vps-public-ip>
```

If prompted about host authenticity, type `yes`.

### Step 3: Clone This Repository

```bash
git clone https://github.com/<your-username>/openclaw-vps.git
cd openclaw-vps
```

If the repo is private, you may need to set up a personal access token or SSH key for GitHub.

### Step 4: Run Bootstrap Script

```bash
bash scripts/bootstrap-vps.sh
```

This script will:
- Update system packages
- Create the `openclaw` user
- Harden SSH (key-only, no root login)
- Install Docker + Docker Compose
- Install Tailscale
- Configure UFW firewall
- Install fail2ban
- Enable unattended-upgrades
- Create a 4GB swap file
- Create OpenClaw directories

**This takes ~5 minutes.** Watch for any errors.

### Step 5: Authenticate Tailscale

After bootstrap completes:

```bash
sudo tailscale up --authkey=<your-tailscale-auth-key>
```

Get your auth key from [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys).

Check that Tailscale is connected:

```bash
tailscale status
tailscale ip -4
```

Note the Tailscale IP (e.g., `100.x.y.z`). You'll use this to access the Control UI.

---

## Phase 2: Install OpenClaw

### Step 1: Switch to openclaw User

```bash
exit  # Log out from root
ssh openclaw@<vps-public-ip>
```

Or use Tailscale (more secure):

```bash
ssh openclaw@<tailscale-ip>
```

### Step 2: Navigate to Repository

```bash
cd openclaw-vps
```

If the repo isn't there, clone it as the `openclaw` user:

```bash
git clone https://github.com/<your-username>/openclaw-vps.git
cd openclaw-vps
```

### Step 3: Configure Credentials

```bash
cp .env.example .env
nano .env  # Or use vim/vi
```

Fill in:

```bash
ANTHROPIC_API_KEY=sk-ant-...
SLACK_APP_TOKEN=xapp-...
SLACK_BOT_TOKEN=xoxb-...
TAILSCALE_AUTHKEY=tskey-auth-...  # Optional if already authenticated
OPENCLAW_USER=openclaw
OPENCLAW_STATE_DIR=/home/openclaw/.openclaw
OPENCLAW_WORKSPACE_DIR=/home/openclaw/workspace
```

Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X` in nano).

**Secure the .env file:**

```bash
chmod 600 .env
```

### Step 4: Install OpenClaw

```bash
bash scripts/install-openclaw.sh
```

This script will:
- Validate `.env` file
- Create OpenClaw directories
- Build the Docker image
- Start the OpenClaw gateway + Chromium containers
- Verify health

**This takes ~3-5 minutes** (Docker image build + npm installs).

### Step 5: Verify Installation

Check that containers are running:

```bash
docker compose -f docker/docker-compose.yml ps
```

You should see:
- `openclaw-gateway` → `Up`
- `openclaw-chromium` → `Up`

View logs:

```bash
docker compose -f docker/docker-compose.yml logs -f openclaw
```

Press `Ctrl+C` to exit logs.

---

## Phase 3: Configure Slack

### Step 1: Run Slack Configuration Script

```bash
bash scripts/configure-slack.sh
```

This script validates your Slack tokens and checks the connection.

### Step 2: Test Pairing

1. Open Slack on your laptop/phone
2. Find the OpenClaw bot in the **Apps** section
3. Send a DM: `hello`

The bot will respond with a **pairing code** (e.g., `ABC123`).

### Step 3: Approve Pairing

Open the OpenClaw Control UI in your browser (via Tailscale):

```
http://<tailscale-ip>:18789
```

Or approve via CLI:

```bash
docker compose -f docker/docker-compose.yml exec openclaw openclaw pairing approve slack ABC123
```

Replace `ABC123` with your actual pairing code.

### Step 4: Test Conversation

Send another message in Slack:

```
What's the weather today?
```

The bot should respond (though it may ask for location or indicate it doesn't have weather tools yet).

---

## Phase 4: Deploy an Agent (Optional)

If you have an agent repository ready (e.g., `openclaw-job-search-agent`):

### Step 1: Clone the Agent Repository

```bash
cd ~
git clone https://github.com/<your-username>/openclaw-job-search-agent.git
```

### Step 2: Deploy the Agent

```bash
cd ~/openclaw-vps
bash scripts/deploy-agent.sh ~/openclaw-job-search-agent
```

This script will:
- Copy agent files to the workspace
- Merge agent config (you may need to manually merge `config.json`)
- Register cron jobs
- Restart the gateway

### Step 3: Test the Agent

In Slack, go to the channel configured for the agent (e.g., `#job-search`) and send a test message.

See [ADDING-AGENTS.md](ADDING-AGENTS.md) for more details.

---

## What's Next?

- **Monitor logs:** `cd docker && docker compose logs -f`
- **Backup state:** `bash scripts/backup.sh`
- **Add more agents:** See [ADDING-AGENTS.md](ADDING-AGENTS.md)
- **Security review:** See [SECURITY.md](SECURITY.md)
- **Troubleshooting:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## Summary Checklist

- [ ] Phase 0: Slack App created and tokens saved
- [ ] Phase 1: VPS provisioned and bootstrapped
- [ ] Phase 1: Tailscale authenticated
- [ ] Phase 2: OpenClaw installed and running
- [ ] Phase 3: Slack pairing successful
- [ ] Phase 3: Test conversation working
- [ ] Phase 4: Agent deployed (if applicable)

**Congratulations!** Your OpenClaw VPS is live.
