# OpenClaw VPS — Infrastructure Setup Plan

> **Purpose:** A repeatable, version-controlled plan to provision a Hetzner VPS as a shared OpenClaw environment. This infrastructure supports one or more OpenClaw agents. Agent-specific configuration lives in separate repos — this repo is agent-agnostic.

---

## 1. Architecture Overview

```
┌──────────────────────────────────────────────┐
│  Hetzner VPS (CX22 — 2 vCPU, 4GB, Ubuntu)   │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  Docker                                │  │
│  │  ┌──────────────────────────────────┐  │  │
│  │  │  OpenClaw Gateway                │  │  │
│  │  │  ws://127.0.0.1:18789           │  │  │
│  │  │  ├─ Slack (Socket Mode)         │  │  │
│  │  │  ├─ Agent routing               │  │  │
│  │  │  └─ Skills + Tools              │  │  │
│  │  └──────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────┐  │  │
│  │  │  Chromium (browser automation)   │  │  │
│  │  └──────────────────────────────────┘  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  Tailscale (private mesh VPN)         │  │
│  │  ├─ Admin access (SSH, Control UI)    │  │
│  │  └─ No public ports exposed           │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  UFW Firewall                         │  │
│  │  ├─ DENY all inbound (default)        │  │
│  │  ├─ ALLOW Tailscale subnet            │  │
│  │  └─ ALLOW SSH (rate-limited)          │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  fail2ban (SSH brute-force protection) │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
  ┌──────────────┐    ┌─────────────┐
  │ Anthropic API│    │ Slack API   │
  │ (Claude)     │    │ (Socket)    │
  └──────────────┘    └─────────────┘
```

---

## 2. VPS Specification

### 2.1 Hetzner Plan

| Component       | Spec                | Notes                                              |
|-----------------|---------------------|----------------------------------------------------|
| **Plan**        | CX22                | 2 vCPU, 4GB RAM, 40GB SSD. ~€4.50/month.          |
| **OS**          | Ubuntu 24.04 LTS    | Best-tested Linux distro for OpenClaw              |
| **Location**    | Helsinki or Falkenstein | Low latency to EU                             |
| **Networking**  | IPv4 + IPv6         | Static public IPv4 included                        |

### 2.2 Software Stack

| Software           | Version    | Purpose                                       |
|--------------------|------------|-----------------------------------------------|
| **Docker**         | 27+        | Container runtime for isolation                |
| **Docker Compose** | v2+        | Multi-container orchestration                  |
| **Node.js**        | 22+        | OpenClaw runtime (inside Docker container)     |
| **Tailscale**      | Latest     | Private mesh VPN — no exposed management ports |
| **UFW**            | Default    | Firewall — deny all except Tailscale + SSH     |
| **fail2ban**       | Default    | SSH brute-force protection                     |
| **unattended-upgrades** | Default | Automatic security patches                |
| **Caddy** (optional) | Latest  | Reverse proxy + auto-TLS (needed for webhooks later) |

---

## 3. Repository Structure

```
openclaw-vps/
├── README.md                          # Overview, quickstart, and links to docs
├── .gitignore
├── .env.example                       # Gateway-level credentials template
│
├── scripts/
│   ├── bootstrap-vps.sh               # First-run VPS provisioning
│   │                                  #   - Create non-root user
│   │                                  #   - Configure SSH (key-only, no root login)
│   │                                  #   - Install Docker + Docker Compose
│   │                                  #   - Install & configure Tailscale
│   │                                  #   - Configure UFW firewall
│   │                                  #   - Install & configure fail2ban
│   │                                  #   - Enable unattended-upgrades
│   │                                  #   - Create swap file
│   │                                  #   - Create OpenClaw directories
│   │
│   ├── install-openclaw.sh            # OpenClaw installation via Docker
│   │                                  #   - Build custom Docker image
│   │                                  #   - Run docker-compose up
│   │                                  #   - Verify gateway health
│   │
│   ├── configure-slack.sh             # Slack channel setup helper
│   │                                  #   - Validate Slack tokens
│   │                                  #   - Test socket connection
│   │
│   ├── deploy-agent.sh                # Deploy an agent from a separate repo
│   │                                  #   - Copy agent files to OpenClaw workspace
│   │                                  #   - Merge agent config into gateway config
│   │                                  #   - Register cron jobs
│   │                                  #   - Restart gateway
│   │
│   ├── backup.sh                      # Backup OpenClaw state
│   │                                  #   - Encrypt ~/.openclaw directory
│   │                                  #   - Upload to specified location
│   │
│   └── restore.sh                     # Restore from backup
│
├── docker/
│   ├── docker-compose.yml             # OpenClaw gateway + Chromium
│   ├── Dockerfile                     # Custom image: Ubuntu + Node 22 + OpenClaw
│   └── .env.example                   # Docker-specific env vars
│
├── config/
│   └── openclaw-config.template.json  # Base gateway config template
│
└── docs/
    ├── SETUP.md                       # Full step-by-step deployment guide
    ├── SECURITY.md                    # Security checklist and hardening notes
    ├── ADDING-AGENTS.md               # How to deploy a new agent to this environment
    ├── TROUBLESHOOTING.md             # Common issues and fixes
    └── COSTS.md                       # Expected monthly cost breakdown
```

---

## 4. Credentials & Environment Variables

### 4.1 Gateway-Level Credentials (this repo)

These are shared across all agents running on the instance.

| Variable              | Where to Get It                        | Purpose                         |
|-----------------------|----------------------------------------|---------------------------------|
| `ANTHROPIC_API_KEY`   | console.anthropic.com → API Keys       | LLM provider for all agents     |
| `SLACK_APP_TOKEN`     | api.slack.com → Your App → App-Level Tokens | Slack Socket Mode connection |
| `SLACK_BOT_TOKEN`     | api.slack.com → Your App → OAuth & Permissions | Slack bot actions          |
| `TAILSCALE_AUTHKEY`   | login.tailscale.com → Settings → Keys  | VPS joins Tailscale network     |

### 4.2 .env.example

```bash
# ============================================
# OpenClaw VPS — Gateway-Level Environment
# ============================================
# Copy to .env and fill in real values.
# NEVER commit .env to version control.
# chmod 600 .env after creating.

# --- LLM Provider ---
ANTHROPIC_API_KEY=sk-ant-...

# --- Slack (shared across all agents) ---
SLACK_APP_TOKEN=xapp-...
SLACK_BOT_TOKEN=xoxb-...

# --- Tailscale ---
TAILSCALE_AUTHKEY=tskey-auth-...

# --- VPS User (created by bootstrap-vps.sh) ---
OPENCLAW_USER=openclaw

# --- OpenClaw Paths ---
OPENCLAW_STATE_DIR=/home/openclaw/.openclaw
OPENCLAW_WORKSPACE_DIR=/home/openclaw/workspace
```

### 4.3 What Agent Repos Need from This Environment

When agents are deployed to this VPS, they need to know or receive the following from the running environment:

| Provided by VPS                    | Agent Needs to Supply               |
|------------------------------------|--------------------------------------|
| Running OpenClaw gateway           | Agent-specific SOUL.md               |
| Slack connection (Socket Mode)     | Slack channel/DM routing config      |
| Anthropic API key                  | Agent-specific skills + cron jobs    |
| Docker container with Node 22      | Agent-specific `.env` (e.g., Gmail OAuth) |
| Browser/Chromium availability      | Agent-specific memory + preferences  |
| Workspace directory structure      | Agent files copied to workspace      |

This contract is documented in `docs/ADDING-AGENTS.md` so future agents know exactly what to expect.

---

## 5. Security Hardening

### 5.1 SSH

- **Key-only authentication** — password auth disabled
- **Root login disabled** — use the `openclaw` user with sudo
- **Port** — consider changing from 22 to a non-standard port (optional)
- **fail2ban** — bans IPs after 5 failed attempts for 10 minutes

### 5.2 Firewall (UFW)

```bash
# Default policy
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (rate-limited)
ufw limit 22/tcp

# Allow Tailscale subnet (for Control UI, admin access)
ufw allow in on tailscale0

# Everything else is denied
ufw enable
```

**No public ports exposed.** The OpenClaw gateway (18789) and Control UI are only accessible via Tailscale.

### 5.3 Tailscale

- VPS joins your private Tailscale network on first boot
- You access the VPS via its Tailscale IP (e.g., `100.x.y.z`), never the public IP
- OpenClaw Control UI available at `http://<tailscale-ip>:18789`
- All traffic between your devices and the VPS is encrypted and authenticated

### 5.4 Docker

- No `--privileged` flag on any container
- OpenClaw container runs as non-root user (UID 1000)
- Volumes mounted with minimal permissions
- Credentials injected via `.env` file, not baked into images
- `.env` file has `chmod 600` — readable only by owner

### 5.5 OpenClaw Gateway

```jsonc
{
  "exec": {
    "ask": "on"              // Consent mode — approve before executing commands
  },
  "channels": {
    "defaults": {
      "groupPolicy": "allowlist"  // Only respond in explicitly allowed channels
    },
    "slack": {
      "enabled": true,
      "mode": "socket",
      "dmPolicy": "pairing"       // Require pairing code for new DMs
    }
  }
}
```

### 5.6 Swap Configuration

```bash
# Create 4GB swap file (critical for npm builds on 4GB RAM)
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

---

## 6. Slack App Setup

The Slack App is shared across all agents. Each agent can be routed to specific channels or DM threads.

### 6.1 Create the Slack App

1. Go to **api.slack.com/apps** → Create New App → From scratch
2. Name it (e.g., "OpenClaw Assistant") and select your workspace
3. Enable **Socket Mode** (sidebar → Socket Mode → toggle ON)
4. Generate an **App-Level Token** with scope `connections:write` → this is your `SLACK_APP_TOKEN` (`xapp-...`)

### 6.2 Configure Bot Permissions

Go to **OAuth & Permissions** → Bot Token Scopes. Add:

| Scope                | Purpose                        |
|----------------------|--------------------------------|
| `chat:write`         | Send messages                  |
| `app_mentions:read`  | Respond to @mentions           |
| `channels:history`   | Read channel messages          |
| `channels:read`      | List channels                  |
| `groups:history`     | Read private channel messages  |
| `im:history`         | Read DM messages               |
| `im:read`            | Access DM metadata             |
| `im:write`           | Send DMs                       |
| `mpim:history`       | Read group DM messages         |
| `reactions:read`     | Read reactions                 |
| `reactions:write`    | Add reactions                  |
| `files:write`        | Upload files (cover letters, etc.) |
| `users:read`         | Look up user info              |

### 6.3 Install to Workspace

1. Go to **Install App** → Install to Workspace → Authorize
2. Copy the **Bot User OAuth Token** → this is your `SLACK_BOT_TOKEN` (`xoxb-...`)

### 6.4 Enable Events (for Socket Mode)

Go to **Event Subscriptions** → toggle ON. Subscribe to bot events:
- `message.im` — DMs to the bot
- `message.channels` — Messages in channels the bot is in
- `message.groups` — Messages in private channels
- `app_mention` — When someone @mentions the bot

### 6.5 Agent Routing

Each agent deployed to this environment gets its own Slack channel or DM thread. Configure routing in the agent's config so messages in `#job-search` go to the job search agent, messages in `#webapp` go to the webapp agent, etc.

---

## 7. Deployment Steps (Summary)

This is the high-level flow. Detailed step-by-step instructions go in `docs/SETUP.md`.

### Phase 1: Provision VPS

1. Create a Hetzner CX22 server (Ubuntu 24.04, Helsinki/Falkenstein)
2. Add your SSH public key during creation
3. SSH in as root: `ssh root@<public-ip>`
4. Clone this repo: `git clone https://github.com/<you>/openclaw-vps.git`
5. Run bootstrap: `cd openclaw-vps && bash scripts/bootstrap-vps.sh`
6. This creates the `openclaw` user, hardens SSH, installs Docker, configures Tailscale + UFW + fail2ban, creates swap

### Phase 2: Install OpenClaw

1. SSH in as the `openclaw` user (via Tailscale from now on)
2. Copy `.env.example` to `.env` and fill in credentials
3. Run install: `bash scripts/install-openclaw.sh`
4. This builds the Docker image, starts the gateway, and verifies health
5. Access Control UI at `http://<tailscale-ip>:18789`

### Phase 3: Configure Slack

1. Run: `bash scripts/configure-slack.sh`
2. This validates your Slack tokens and tests the Socket Mode connection
3. Send a test DM to the bot in Slack
4. Approve the pairing code: `openclaw pairing approve slack <code>`

### Phase 4: Deploy an Agent

1. Clone an agent repo (e.g., `openclaw-job-search-agent`)
2. Run: `bash scripts/deploy-agent.sh /path/to/openclaw-job-search-agent`
3. This copies agent files, merges config, registers cron jobs, and restarts the gateway
4. Test the agent via Slack

---

## 8. Adding New Agents

Documented in detail in `docs/ADDING-AGENTS.md`. The process is:

1. Create a new agent repo following the agent template structure
2. Include: `SOUL.md`, skills config, cron jobs, agent-specific `.env`
3. Clone the agent repo on the VPS
4. Run `deploy-agent.sh` which handles file placement and config merging
5. The agent is live and routed to its configured Slack channel

**Key constraints:**
- All agents share the same Anthropic API key and Slack App
- Each agent gets its own Slack channel or DM thread for routing
- Each agent can have its own skills and cron schedule
- Agent-specific secrets (e.g., Gmail OAuth) live in the agent's `.env`, not the gateway `.env`
- OpenClaw's multi-agent routing handles isolation between agents

---

## 9. Backup & Recovery

### Backup

```bash
# Run manually or via cron
bash scripts/backup.sh

# Creates an encrypted tarball of:
#   - ~/.openclaw/ (config, credentials, memory, conversation history)
#   - Agent workspace files
#   - Current docker-compose.yml and .env (encrypted)
```

### Restore

```bash
# On a fresh VPS after running bootstrap-vps.sh:
bash scripts/restore.sh /path/to/backup.tar.gz.enc

# Restores state and restarts the gateway
```

### Recommended backup schedule

| Schedule         | Method                              |
|------------------|-------------------------------------|
| Daily            | Automated cron → encrypted tarball  |
| Before updates   | Manual snapshot via Hetzner Console  |
| Before new agent | Manual backup via `backup.sh`       |

---

## 10. Estimated Costs (Infrastructure Only)

| Item                   | Cost (approx.)       | Notes                              |
|------------------------|----------------------|------------------------------------|
| Hetzner CX22 VPS       | €4.50/month          | 2 vCPU, 4GB RAM, 40GB SSD         |
| Anthropic API (Claude) | $20–50/month         | Scales with number of agents/usage |
| Tailscale              | Free (personal)      | Free for up to 100 devices         |
| Slack                  | Free (free tier)     | 1 workspace, 90-day message history|
| **Total (infra only)** | **~€25–55/month**    | Agent-specific costs (e.g., Gmail API) are free |

Costs are shared across all agents running on the instance. Only the Anthropic API usage scales with the number of agents.

---

## 11. Pre-Setup Checklist

Complete all items before beginning deployment.

### Accounts

- [ ] **Hetzner Cloud** — hetzner.com (payment method added)
- [ ] **Anthropic API** — console.anthropic.com (API key generated, billing added)
- [ ] **Tailscale** — login.tailscale.com (account created, laptop/phone connected)
- [ ] **Slack workspace** — free workspace created (or using existing)
- [ ] **GitHub** — `openclaw-vps` repo created (private)

### Local Machine

- [ ] SSH key pair ready (`ssh-keygen -t ed25519` if needed)
- [ ] Tailscale installed on your laptop/phone
- [ ] Slack installed on your laptop/phone
- [ ] Git configured

### Credentials to Have Ready

- [ ] Anthropic API key (`sk-ant-...`)
- [ ] Slack App-Level Token (`xapp-...`) — see Section 6
- [ ] Slack Bot Token (`xoxb-...`) — see Section 6
- [ ] Tailscale auth key (`tskey-auth-...`) — generate a reusable key

---

## 12. Stretch Goals

These enhancements can be added after the base environment is running.

### 12.1 Caddy Reverse Proxy (for webhooks)

When agents need to receive inbound webhooks (e.g., Gmail Pub/Sub, GitHub events, contact form submissions), add Caddy to the Docker Compose stack:

- Point your domain to the VPS public IP via an A record
- Caddy handles TLS automatically via Let's Encrypt
- Open ports 80/443 in UFW for Caddy only
- Route `/webhooks/*` paths to the OpenClaw gateway
- All other paths return 404
- Rate-limit webhook endpoints (30 req/min)

This is documented in more detail in the job search agent's plan under Stretch Goals.

### 12.2 Monitoring & Alerts

- Set up basic uptime monitoring (e.g., Uptime Kuma in Docker)
- Alert via Slack if the gateway goes down
- Monitor Docker container health and auto-restart

### 12.3 Log Management

- Configure log rotation for OpenClaw and Docker logs
- Optionally ship logs to a free tier service (e.g., Grafana Cloud)

---

*Generated: February 2026. OpenClaw version at time of writing: latest stable via npm.*
*Designed for Hetzner CX22 but these steps are repeatable on any Ubuntu 24.04 Linux system with 4GB+ RAM.*
