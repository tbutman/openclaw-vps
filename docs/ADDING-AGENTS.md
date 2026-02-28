# OpenClaw VPS — Adding Agents

This guide explains how to deploy new OpenClaw agents to your VPS environment.

---

## Overview

This VPS infrastructure is **agent-agnostic**. It provides:
- A running OpenClaw gateway
- Slack connection (Socket Mode)
- Anthropic API access (Claude)
- Docker runtime
- Browser automation (Chromium)
- Workspace directory structure

Each agent you deploy is a **separate Git repository** with its own:
- `SOUL.md` — Agent identity and instructions
- `config.json` — Agent-specific OpenClaw config
- `skills/` — Agent-specific skills (optional)
- `cron.txt` — Scheduled jobs (optional)
- `.env.agent` — Agent-specific secrets (optional)

---

## Agent Repository Structure

Your agent repository should follow this structure:

```
openclaw-<agent-name>/
├── README.md                    # Agent documentation
├── SOUL.md                      # Agent identity (REQUIRED)
├── config.json                  # OpenClaw config for this agent (REQUIRED)
├── skills/                      # Agent-specific skills (optional)
│   ├── apply-to-job.js
│   ├── send-email.js
│   └── ...
├── cron.txt                     # Cron schedule (optional)
├── .env.agent                   # Agent-specific secrets (optional)
└── .gitignore                   # Exclude .env.agent from version control
```

### Required Files

#### 1. `SOUL.md`

This file defines your agent's identity, personality, and instructions.

**Example:**

```markdown
# Job Search Agent

You are a proactive job search assistant. Your mission is to help the user find and apply to software engineering jobs that match their preferences.

## Your responsibilities:
- Monitor job boards daily for new postings
- Filter jobs based on user's criteria (location, salary, tech stack)
- Draft personalized cover letters
- Track application status
- Provide weekly summaries of job search progress

## Your personality:
- Professional but friendly
- Proactive — you initiate check-ins
- Detail-oriented — you remember user preferences
- Encouraging — you celebrate small wins

## Your tools:
- Web scraping for job boards
- Gmail API for sending applications
- Memory for tracking applications
- Calendar for scheduling follow-ups
```

#### 2. `config.json`

This file configures how the agent interacts with OpenClaw and Slack.

**Example:**

```json
{
  "agent": {
    "name": "job-search",
    "soul": "SOUL.md"
  },
  "channels": {
    "slack": {
      "allowedChannels": ["C12345678"],  // Slack channel ID for #job-search
      "dmPolicy": "pairing"
    }
  },
  "skills": [
    {
      "name": "apply-to-job",
      "path": "skills/apply-to-job.js",
      "description": "Apply to a job posting with a custom cover letter"
    },
    {
      "name": "send-email",
      "path": "skills/send-email.js",
      "description": "Send an email via Gmail"
    }
  ],
  "memory": {
    "enabled": true,
    "namespace": "job-search"  // Isolate memory from other agents
  }
}
```

**How to get Slack channel ID:**

In Slack:
1. Right-click the channel name → **View channel details**
2. Scroll to the bottom → Copy the **Channel ID** (starts with `C`)

### Optional Files

#### 3. `skills/`

Agent-specific skills are JavaScript modules that extend OpenClaw's capabilities.

**Example: `skills/apply-to-job.js`**

```javascript
module.exports = {
  name: 'apply-to-job',
  description: 'Apply to a job posting with a custom cover letter',

  async execute({ jobUrl, resumeUrl, coverLetter }, context) {
    // Use OpenClaw's browser automation to apply
    const browser = context.browser;
    const page = await browser.newPage();
    await page.goto(jobUrl);

    // Fill out application form
    // ...

    return {
      success: true,
      message: 'Application submitted successfully'
    };
  }
};
```

#### 4. `cron.txt`

Scheduled tasks for the agent (e.g., daily job board checks).

**Example:**

```cron
# Check job boards every weekday at 9 AM
0 9 * * 1-5 /usr/local/bin/openclaw run job-search check-new-jobs

# Send weekly summary every Friday at 5 PM
0 17 * * 5 /usr/local/bin/openclaw run job-search weekly-summary
```

#### 5. `.env.agent`

Agent-specific secrets (e.g., Gmail OAuth tokens, API keys).

**Example:**

```bash
# Gmail API credentials
GMAIL_CLIENT_ID=...
GMAIL_CLIENT_SECRET=...
GMAIL_REFRESH_TOKEN=...

# Other agent-specific secrets
LINKEDIN_API_KEY=...
```

**Important:** Add `.env.agent` to your agent repo's `.gitignore`:

```gitignore
.env.agent
```

---

## Deployment Steps

### Step 1: Create Agent Repository

1. Create a new Git repository for your agent:
   ```bash
   mkdir openclaw-job-search-agent
   cd openclaw-job-search-agent
   git init
   ```

2. Create the required files:
   ```bash
   touch SOUL.md config.json
   mkdir skills
   touch .env.agent
   ```

3. Populate the files (see examples above)

4. Commit and push to GitHub:
   ```bash
   git add .
   git commit -m "Initial agent setup"
   git remote add origin https://github.com/<you>/openclaw-job-search-agent.git
   git push -u origin main
   ```

### Step 2: Clone Agent Repository on VPS

SSH into the VPS:

```bash
ssh openclaw@<tailscale-ip>
```

Clone the agent repo:

```bash
cd ~
git clone https://github.com/<you>/openclaw-job-search-agent.git
```

### Step 3: Deploy the Agent

Run the deployment script:

```bash
cd ~/openclaw-vps
bash scripts/deploy-agent.sh ~/openclaw-job-search-agent
```

This script will:
1. Validate the agent repo structure
2. Copy agent files to `~/workspace/<agent-name>/`
3. Prompt you to manually merge `config.json` into the gateway config
4. Register cron jobs (if `cron.txt` exists)
5. Restart the OpenClaw gateway

### Step 4: Manually Merge Agent Config

The deployment script will show you where the agent's `config.json` is located. You need to manually merge it into the gateway config.

**Gateway config location:**

```
~/.openclaw/config.json
```

**What to merge:**

1. Add the agent to the `agents` array:
   ```json
   {
     "agents": [
       {
         "name": "job-search",
         "soul": "/home/openclaw/workspace/openclaw-job-search-agent/SOUL.md"
       }
     ]
   }
   ```

2. Add the agent's allowed channels:
   ```json
   {
     "channels": {
       "slack": {
         "allowedChannels": ["C12345678"]  // From agent's config.json
       }
     }
   }
   ```

3. Register the agent's skills:
   ```json
   {
     "skills": {
       "apply-to-job": "/home/openclaw/workspace/openclaw-job-search-agent/skills/apply-to-job.js"
     }
   }
   ```

**Alternative:** Use `jq` to automate the merge (advanced):

```bash
jq -s '.[0] * .[1]' ~/.openclaw/config.json ~/workspace/openclaw-job-search-agent/config.json > /tmp/merged-config.json
mv /tmp/merged-config.json ~/.openclaw/config.json
```

### Step 5: Restart Gateway

If you manually edited the config, restart the gateway:

```bash
cd ~/openclaw-vps/docker
docker compose restart openclaw
```

### Step 6: Test the Agent

1. Go to the agent's Slack channel (e.g., `#job-search`)
2. Send a test message: `@OpenClaw hello`
3. The agent should respond according to its `SOUL.md`

---

## Agent Routing

### How Routing Works

OpenClaw routes messages to agents based on the Slack channel or DM thread:

- **Channel-based routing:** Messages in `#job-search` go to the job search agent
- **DM-based routing:** DMs can be paired with a specific agent via pairing code

### Example Multi-Agent Setup

You have two agents:
1. **Job Search Agent** → `#job-search` channel
2. **Webapp Agent** → `#webapp` channel

**Gateway config:**

```json
{
  "agents": [
    {
      "name": "job-search",
      "soul": "/home/openclaw/workspace/openclaw-job-search-agent/SOUL.md"
    },
    {
      "name": "webapp",
      "soul": "/home/openclaw/workspace/openclaw-webapp-agent/SOUL.md"
    }
  ],
  "channels": {
    "slack": {
      "allowedChannels": ["C12345678", "C87654321"],
      "routing": [
        {
          "channel": "C12345678",
          "agent": "job-search"
        },
        {
          "channel": "C87654321",
          "agent": "webapp"
        }
      ]
    }
  }
}
```

Messages in `#job-search` → Job Search Agent
Messages in `#webapp` → Webapp Agent

---

## Updating an Agent

### Step 1: Update Agent Repository

Make changes in your local agent repo:

```bash
cd openclaw-job-search-agent
# Edit SOUL.md, skills, etc.
git add .
git commit -m "Update agent instructions"
git push
```

### Step 2: Pull Changes on VPS

SSH into the VPS:

```bash
ssh openclaw@<tailscale-ip>
cd ~/openclaw-job-search-agent
git pull
```

### Step 3: Redeploy

```bash
cd ~/openclaw-vps
bash scripts/deploy-agent.sh ~/openclaw-job-search-agent
```

The script will overwrite the existing agent files in the workspace.

### Step 4: Restart Gateway

```bash
cd ~/openclaw-vps/docker
docker compose restart openclaw
```

---

## Removing an Agent

### Step 1: Stop the Gateway

```bash
cd ~/openclaw-vps/docker
docker compose down
```

### Step 2: Remove Agent Files

```bash
rm -rf ~/workspace/openclaw-job-search-agent
```

### Step 3: Remove Agent from Gateway Config

Edit `~/.openclaw/config.json` and remove:
- The agent from the `agents` array
- The agent's channel from `allowedChannels`
- The agent's skills from `skills`

### Step 4: Remove Cron Jobs (if any)

```bash
crontab -e
# Delete lines related to the agent
```

### Step 5: Restart Gateway

```bash
docker compose up -d
```

---

## Best Practices

### 1. One Agent Per Repository

Don't mix multiple agents in one repo. Keep them separate for easier version control and deployment.

### 2. Use Namespaces for Memory

Each agent should have its own memory namespace to avoid conflicts:

```json
{
  "memory": {
    "enabled": true,
    "namespace": "job-search"
  }
}
```

### 3. Document Agent Capabilities

Keep your agent's `README.md` up to date with:
- What the agent does
- How to configure it
- What secrets it needs (`.env.agent`)
- Example interactions

### 4. Test Locally First

Before deploying to the VPS, test your agent locally:

```bash
openclaw run job-search --local
```

### 5. Use Version Tags

Tag releases of your agent repo:

```bash
git tag -a v1.0.0 -m "Initial release"
git push --tags
```

This makes it easier to roll back if something breaks.

---

## Troubleshooting

### Agent Not Responding in Slack

1. **Check channel ID:** Ensure the channel ID in `config.json` matches the Slack channel
2. **Check allowedChannels:** Ensure the channel is in the gateway's `allowedChannels` array
3. **Check logs:**
   ```bash
   docker compose -f ~/openclaw-vps/docker/docker-compose.yml logs -f openclaw
   ```

### Skills Not Working

1. **Check file paths:** Skill paths in `config.json` must be absolute or relative to the workspace
2. **Check syntax:** Run `node skills/apply-to-job.js` to check for errors
3. **Check logs:**
   ```bash
   docker compose logs openclaw | grep ERROR
   ```

### Cron Jobs Not Running

1. **Check crontab:**
   ```bash
   crontab -l
   ```
2. **Check cron logs:**
   ```bash
   sudo journalctl -u cron -n 50
   ```
3. **Test cron command manually:**
   ```bash
   /usr/local/bin/openclaw run job-search check-new-jobs
   ```

---

## Example Agents

Here are some example agent ideas:

### 1. Job Search Agent
- **Purpose:** Find and apply to jobs
- **Skills:** Web scraping, email automation, calendar scheduling
- **Cron:** Daily job board checks, weekly summaries

### 2. Webapp Development Agent
- **Purpose:** Build and deploy web applications
- **Skills:** Code generation, git operations, deployment scripts
- **Cron:** None (on-demand only)

### 3. Personal Assistant Agent
- **Purpose:** Manage calendar, reminders, and tasks
- **Skills:** Google Calendar API, task management
- **Cron:** Morning briefings, evening summaries

### 4. Research Agent
- **Purpose:** Gather information on topics
- **Skills:** Web search, PDF extraction, summarization
- **Cron:** Weekly research reports

---

## Questions?

If you run into issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) or open an issue on the `openclaw-vps` repository.
