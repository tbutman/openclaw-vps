# OpenClaw VPS — Cost Breakdown

Detailed monthly cost estimates for running the OpenClaw VPS.

---

## Summary

| Item                   | Cost (approx.)       | Notes                              |
|------------------------|----------------------|------------------------------------|
| Hetzner CX22 VPS       | €4.50/month          | 2 vCPU, 4GB RAM, 40GB SSD         |
| Anthropic API (Claude) | $20–50/month         | Scales with number of agents/usage |
| Tailscale              | Free                 | Free for up to 100 devices         |
| Slack                  | Free                 | Free tier (90-day message history) |
| **Total (infra only)** | **~€25–55/month**    | **~$27–60/month** (at €1 = $1.10)  |

**Agent-specific costs** (e.g., Gmail API, LinkedIn API) are typically free or very low (<$5/month).

---

## Infrastructure Costs (Fixed)

### 1. Hetzner Cloud VPS

**Plan:** CX22
**Specs:** 2 vCPU, 4GB RAM, 40GB SSD, 20TB traffic
**Cost:** **€4.50/month** (~$5/month)

**Breakdown:**
- Billed hourly: €0.0067/hour
- Max monthly: €4.90 (capped at ~€4.50 in practice)
- Includes:
  - 1 public IPv4 address
  - Unlimited IPv6 addresses
  - 20TB outbound traffic (inbound is free)
  - Snapshots (manual, pay-per-GB if you use them)

**Traffic costs:**
- First 20TB/month: Included
- Additional traffic: €1/TB (unlikely to exceed unless serving public content)

**Snapshot costs (optional):**
- €0.012/GB/month
- Example: 10GB snapshot = €0.12/month
- **Not recommended** — Use `backup.sh` script instead (free, encrypted)

**Scaling options:**
- **CX32** (4 vCPU, 8GB RAM, 80GB SSD): €9.50/month — Recommended if running 3+ agents
- **CX42** (8 vCPU, 16GB RAM, 160GB SSD): €17.50/month — Overkill for most use cases

**Source:** [Hetzner Pricing](https://www.hetzner.com/cloud)

---

### 2. Tailscale VPN

**Plan:** Free (Personal)
**Cost:** **$0/month**

**Included:**
- Up to 100 devices
- Unlimited bandwidth
- End-to-end encryption
- Access controls (ACLs)

**Paid plans (not needed for this setup):**
- **Personal Pro:** $5/user/month — More advanced ACLs
- **Teams:** $6/user/month — Team management

**Source:** [Tailscale Pricing](https://tailscale.com/pricing)

---

### 3. Slack

**Plan:** Free
**Cost:** **$0/month**

**Included:**
- 1 workspace
- 10,000 most recent messages searchable (90-day history)
- 10 integrations (apps)
- 1-on-1 voice/video calls
- 5GB file storage

**Paid plans (not needed for this setup):**
- **Pro:** $7.25/user/month — Unlimited message history
- **Business+:** $12.50/user/month — Advanced security

**Note:** OpenClaw uses Socket Mode, which counts as 1 integration. You have 9 more slots for other apps.

**Source:** [Slack Pricing](https://slack.com/pricing)

---

## API Costs (Variable)

### 4. Anthropic API (Claude)

**Plan:** Pay-as-you-go
**Cost:** **$20–50/month** (estimated)

**Pricing (as of Feb 2026):**

| Model                | Input (per 1M tokens) | Output (per 1M tokens) |
|----------------------|-----------------------|------------------------|
| Claude 3.5 Sonnet    | $3.00                 | $15.00                 |
| Claude 3.5 Haiku     | $0.80                 | $4.00                  |
| Claude 3 Opus        | $15.00                | $75.00                 |

**Estimated usage for 1 agent (job search example):**

Assuming:
- 50 conversations/month (user-initiated)
- 30 cron jobs/month (daily checks)
- Average 1,000 input tokens + 500 output tokens per interaction

**Total tokens:**
- Input: 80 interactions × 1,000 tokens = 80,000 tokens
- Output: 80 interactions × 500 tokens = 40,000 tokens

**Cost (Claude 3.5 Sonnet):**
- Input: 0.08M tokens × $3.00 = $0.24
- Output: 0.04M tokens × $15.00 = $0.60
- **Total: $0.84/month** for 1 agent (light usage)

**Scaling:**
- **2 agents:** ~$2/month
- **5 agents (moderate usage):** ~$10/month
- **Heavy usage (100+ interactions/day):** $30–50/month

**Ways to reduce costs:**
- Use Claude 3.5 Haiku for simple tasks (75% cheaper)
- Optimize prompts to reduce token usage
- Cache frequently used context (if OpenClaw supports it)

**Source:** [Anthropic Pricing](https://www.anthropic.com/pricing)

---

## Agent-Specific Costs (Optional)

These vary by agent but are typically free or very low:

### Gmail API
- **Cost:** Free
- **Limits:** 1 billion API requests/day (you'll never hit this)

### Google Calendar API
- **Cost:** Free
- **Limits:** 1 million requests/day

### LinkedIn API
- **Cost:** Free for personal use
- **Limits:** Rate-limited (depends on your LinkedIn account tier)

### GitHub API
- **Cost:** Free
- **Limits:** 5,000 requests/hour (authenticated)

### Twilio (SMS/calls, if needed)
- **Cost:** $1–5/month (pay-as-you-go)
- **Example:** $0.0079/SMS in the US

### SendGrid (email, if not using Gmail)
- **Cost:** Free up to 100 emails/day
- **Paid:** $19.95/month for 50,000 emails

---

## Total Monthly Cost Examples

### Scenario 1: Solo Developer, 1 Agent (Job Search)

| Item                   | Cost       |
|------------------------|------------|
| Hetzner CX22           | €4.50      |
| Anthropic API          | $5         |
| Tailscale              | $0         |
| Slack                  | $0         |
| Gmail API              | $0         |
| **Total**              | **~$10/month** |

---

### Scenario 2: Power User, 3 Agents (Job Search + Webapp + Research)

| Item                   | Cost       |
|------------------------|------------|
| Hetzner CX22           | €4.50      |
| Anthropic API          | $25        |
| Tailscale              | $0         |
| Slack                  | $0         |
| Gmail API              | $0         |
| SendGrid (optional)    | $0         |
| **Total**              | **~$30/month** |

---

### Scenario 3: Heavy User, 5 Agents (CX32 VPS for more RAM)

| Item                   | Cost       |
|------------------------|------------|
| Hetzner CX32           | €9.50      |
| Anthropic API          | $50        |
| Tailscale              | $0         |
| Slack                  | $0         |
| Gmail API              | $0         |
| Twilio (SMS)           | $5         |
| **Total**              | **~$65/month** |

---

## Cost Optimization Tips

### 1. Use Claude 3.5 Haiku for Simple Tasks

Claude 3.5 Haiku is **75% cheaper** than Sonnet for input and output. Use it for:
- Simple Q&A
- Cron job summaries
- Memory lookups

Reserve Claude 3.5 Sonnet for:
- Complex reasoning
- Cover letter generation
- Code generation

**How to configure:**

In your agent's `config.json`:

```json
{
  "model": {
    "default": "claude-3-5-haiku-20241022",
    "fallback": "claude-3-5-sonnet-20241022"
  }
}
```

**Savings:** ~50% on Anthropic costs.

---

### 2. Optimize Prompts

- **Be concise:** Shorter prompts = fewer input tokens
- **Avoid repeating context:** Use OpenClaw's memory feature
- **Limit output:** Ask for summaries instead of full responses when possible

**Example:**

Instead of:
```
Generate a detailed, comprehensive cover letter for this job posting...
```

Use:
```
Draft a cover letter for this job. Keep it under 300 words.
```

**Savings:** ~30% on output tokens.

---

### 3. Use Hetzner Snapshots Sparingly

Snapshots cost €0.012/GB/month. Instead:
- Use the `backup.sh` script (free, encrypted, stored locally)
- Download backups to your laptop or cloud storage (e.g., Google Drive, Dropbox)

**Savings:** ~€0.50/month (vs. manual snapshots).

---

### 4. Monitor Anthropic Usage

Check your usage dashboard at [console.anthropic.com](https://console.anthropic.com):
- Set up billing alerts
- Review usage by model
- Identify which agents are using the most tokens

**Savings:** Avoid surprise bills.

---

### 5. Avoid Paid Slack Plan

The free Slack tier is sufficient for this use case. You don't need:
- Unlimited message history (OpenClaw stores conversations locally)
- More than 10 integrations (OpenClaw is 1 integration)

**Savings:** $87/year (vs. Slack Pro).

---

## One-Time Costs

| Item                   | Cost       | Notes                              |
|------------------------|------------|------------------------------------|
| Domain name (optional) | $10–15/year| Only needed for webhooks (stretch goal) |
| SSL certificate       | Free       | Caddy auto-generates via Let's Encrypt |

---

## Cost Comparison: VPS vs. Cloud Alternatives

### AWS EC2 (t3.medium — 2 vCPU, 4GB)

- **On-Demand:** ~$30/month (us-east-1)
- **Reserved (1-year):** ~$20/month
- **Plus data transfer:** $0.09/GB (after first 1GB free)

**Verdict:** Hetzner is **85% cheaper**.

---

### DigitalOcean (Basic Droplet — 2 vCPU, 4GB)

- **Cost:** $24/month
- **Includes:** 4TB transfer

**Verdict:** Hetzner is **80% cheaper**.

---

### Google Cloud (e2-medium — 2 vCPU, 4GB)

- **On-Demand:** ~$35/month
- **Sustained Use Discount:** ~$25/month
- **Plus data transfer:** $0.12/GB

**Verdict:** Hetzner is **82% cheaper**.

---

## Summary: Why Hetzner?

- **Cheapest VPS in EU** — €4.50/month for 2 vCPU, 4GB RAM
- **Generous traffic allowance** — 20TB/month included
- **No hidden fees** — Snapshots optional, backups free (via scripts)
- **Fast network** — Excellent latency to Anthropic API (US East Coast)

**Total cost:** $10–30/month for most use cases, vs. $50–100/month on AWS/GCP/Azure.

---

## Questions?

If you need help estimating costs for your specific use case, open an issue on the [openclaw-vps](https://github.com/<your-username>/openclaw-vps) repository.
