# OpenClaw VPS

> **A repeatable, version-controlled infrastructure setup for running OpenClaw agents on a shared Hetzner VPS.**

This repository provides everything you need to provision a secure, agent-agnostic OpenClaw environment. Agent-specific configuration lives in separate repositories—this is pure infrastructure.

---

## Quick Links

- **[Full Setup Guide](docs/SETUP.md)** — Step-by-step deployment instructions
- **[Security Checklist](docs/SECURITY.md)** — Hardening and best practices
- **[Adding Agents](docs/ADDING-AGENTS.md)** — How to deploy new agents to this environment
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** — Common issues and fixes
- **[Cost Breakdown](docs/COSTS.md)** — Expected monthly expenses
- **[Full Plan](OPENCLAW-VPS-PLAN.md)** — Complete architecture and design doc

---

## What's Included

### Infrastructure
- **Hetzner CX22 VPS** — 2 vCPU, 4GB RAM, Ubuntu 24.04
- **Docker + Docker Compose** — Container runtime for OpenClaw gateway
- **Tailscale VPN** — Private mesh network for secure admin access
- **UFW Firewall** — No public ports exposed except SSH
- **fail2ban** — SSH brute-force protection
- **Automatic security updates** — Unattended upgrades enabled

### OpenClaw Gateway
- Runs via Docker with Node.js 22
- WebSocket gateway on `ws://127.0.0.1:18789` (Tailscale only)
- Slack integration via Socket Mode (no webhooks needed)
- Chromium container for browser automation
- Consent mode enabled — all commands require approval

### Shared Credentials
- Anthropic API key (Claude)
- Slack App tokens (Bot + App-Level)
- Tailscale auth key

---

## Repository Structure

```
openclaw-vps/
├── README.md                          # This file
├── OPENCLAW-VPS-PLAN.md               # Full architecture doc
├── .gitignore
├── .env.example                       # Credential template
│
├── scripts/
│   ├── bootstrap-vps.sh               # First-run VPS provisioning
│   ├── install-openclaw.sh            # OpenClaw installation via Docker
│   ├── configure-slack.sh             # Slack connection validation
│   ├── deploy-agent.sh                # Deploy agent from separate repo
│   ├── backup.sh                      # Backup OpenClaw state
│   └── restore.sh                     # Restore from backup
│
├── docker/
│   ├── docker-compose.yml             # OpenClaw gateway + Chromium
│   ├── Dockerfile                     # Custom Node 22 + OpenClaw image
│   └── .env.example                   # Docker-specific env vars
│
├── config/
│   └── openclaw-config.template.json  # Base gateway config
│
└── docs/
    ├── SETUP.md                       # Step-by-step deployment
    ├── SECURITY.md                    # Security hardening guide
    ├── ADDING-AGENTS.md               # Agent deployment process
    ├── TROUBLESHOOTING.md             # Common issues
    └── COSTS.md                       # Monthly cost breakdown
```

---

## Quick Start

### Prerequisites
- Hetzner Cloud account (payment method added)
- Anthropic API key (`sk-ant-...`)
- Tailscale account (free tier)
- Slack workspace + app configured (see [SETUP.md](docs/SETUP.md))
- SSH key pair ready

### Deploy in 4 Steps

```bash
# 1. Create Hetzner VPS (Ubuntu 24.04, CX22)
# Add your SSH public key during creation
# SSH in as root

# 2. Clone this repo and run bootstrap
git clone https://github.com/<your-username>/openclaw-vps.git
cd openclaw-vps
bash scripts/bootstrap-vps.sh

# 3. Switch to openclaw user, configure credentials
su - openclaw
cd openclaw-vps
cp .env.example .env
# Edit .env with your credentials
chmod 600 .env

# 4. Install OpenClaw
bash scripts/install-openclaw.sh
```

Access the Control UI via Tailscale at `http://<tailscale-ip>:18789`

For detailed instructions, see [docs/SETUP.md](docs/SETUP.md).

---

## Security Model

- **No public ports exposed** — OpenClaw gateway only accessible via Tailscale
- **SSH key-only authentication** — Password auth disabled, root login disabled
- **fail2ban enabled** — Auto-bans brute-force attempts
- **Firewall locked down** — UFW denies all inbound except Tailscale + SSH
- **Docker containers run as non-root** — UID 1000
- **Consent mode enabled** — All commands require approval via OpenClaw pairing

See [docs/SECURITY.md](docs/SECURITY.md) for full security checklist.

---

## Adding Agents

Each agent is a separate Git repository. To deploy an agent to this environment:

```bash
# Clone the agent repo
git clone https://github.com/<you>/openclaw-some-agent.git

# Deploy it
bash scripts/deploy-agent.sh openclaw-some-agent/

# Agent is now live and routed to its configured Slack channel
```

See [docs/ADDING-AGENTS.md](docs/ADDING-AGENTS.md) for details.

---

## Backup & Recovery

```bash
# Manual backup
bash scripts/backup.sh

# Restore on a new VPS
bash scripts/restore.sh /path/to/backup.tar.gz.enc
```

Backups include:
- OpenClaw config, credentials, memory, conversation history
- Agent workspace files
- Docker Compose configuration and environment variables (encrypted)

---

## Estimated Costs

| Item                   | Cost (approx.)       |
|------------------------|----------------------|
| Hetzner CX22 VPS       | €4.50/month          |
| Anthropic API (Claude) | $20–50/month (usage) |
| Tailscale              | Free (personal tier) |
| Slack                  | Free (free tier)     |
| **Total**              | **~€25–55/month**    |

See [docs/COSTS.md](docs/COSTS.md) for detailed breakdown.

---

## Support

- **Issues & Questions:** Open an issue on this repo
- **OpenClaw Docs:** [openclaw.ai/docs](https://openclaw.ai/docs) *(placeholder)*
- **Slack Community:** *(if available)*

---

## License

MIT — See LICENSE file for details.

---

*Generated: February 2026. Designed for Hetzner CX22 but repeatable on any Ubuntu 24.04 system with 4GB+ RAM.*
