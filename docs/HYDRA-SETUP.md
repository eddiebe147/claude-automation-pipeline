# HYDRA Multi-Agent System Setup

HYDRA (Hybrid Unified Dispatch and Response Architecture) is a multi-agent coordination system that combines Eddie's automation empire with Bhanu's Mission Control patterns.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    HYDRA SYSTEM                                  │
├─────────────────────────────────────────────────────────────────┤
│  AGENTS: MILO (coordinator) + FORGE + SCOUT + PULSE             │
│  DATABASE: ~/.hydra/hydra.db (SQLite)                           │
│  SYNC: hydra-sync.sh (8:30 AM daily via launchd)                │
│  NOTIFICATIONS: Telegram + macOS + MacDown                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    NOTIFICATION FLOW                             │
├─────────────────────────────────────────────────────────────────┤
│  agent-runner.sh ─┐                                             │
│  daily-briefing.sh ├──▶ notify-eddie.sh ──┬──▶ Telegram Bot API │
│  notification-check.sh                    ├──▶ macOS Alert      │
│                                           └──▶ MacDown Opens    │
└─────────────────────────────────────────────────────────────────┘
```

## Agent Roster

| Agent | Role | Model | Heartbeat | Cost |
|-------|------|-------|-----------|------|
| MILO | Coordinator | Claude Sonnet 4 | 15 min | ~$10/day |
| FORGE | Dev Specialist | DeepSeek V3.2 | 30 min | FREE |
| SCOUT | Research/Marketing | Qwen3 235B | 60 min | FREE |
| PULSE | Ops Specialist | Llama 4 Maverick | 30 min | FREE |

## Directory Structure

```
~/.hydra/
├── hydra.db              # SQLite coordination database
├── init-db.sql           # Database schema
├── config/
│   ├── agents.yaml       # Agent roster configuration
│   ├── telegram.env      # Telegram credentials (DO NOT COMMIT)
│   └── telegram.env.example  # Template for telegram setup
├── daemons/
│   ├── agent-runner.sh   # Agent heartbeat processor
│   ├── daily-briefing.sh # Morning briefing generator
│   ├── notify-eddie.sh   # Centralized notification dispatcher
│   └── notification-check.sh  # Urgent notification alerter
├── sessions/
│   ├── milo/             # Coordinator workspace
│   │   ├── SOUL.md
│   │   ├── IDENTITY.md
│   │   ├── AGENTS.md
│   │   └── HEARTBEAT.md
│   ├── forge/            # Dev specialist workspace
│   ├── scout/            # Research specialist workspace
│   └── pulse/            # Ops specialist workspace
├── briefings/            # Daily morning briefings
├── reports/              # Agent heartbeat reports
│   ├── milo/
│   ├── forge/
│   ├── scout/
│   └── pulse/
└── tools/
    └── hydra-cli.sh      # CLI tool (symlinked to ~/.local/bin/hydra)

~/Development/scripts/
├── hydra-sync.sh         # Automation → HYDRA sync
└── hydra-standup.sh      # Daily standup generator

~/Library/LaunchAgents/
├── com.hydra.sync.plist           # 8:30 AM - Sync automation signals
├── com.hydra.standup.plist        # 8:35 AM - Generate standup
├── com.hydra.briefing.plist       # 8:40 AM - Morning briefing
├── com.hydra.notification-check.plist  # Every 5 min - Check urgents
├── com.hydra.agent-milo.plist     # Every 15 min - Coordinator
├── com.hydra.agent-forge.plist    # Every 30 min - Dev specialist
├── com.hydra.agent-pulse.plist    # Every 30 min - Ops specialist
└── com.hydra.agent-scout.plist    # Every 60 min - Research specialist
```

## Installation

### 1. Initialize Database

```bash
sqlite3 ~/.hydra/hydra.db < ~/.hydra/init-db.sql
```

### 2. Load Launchd Job

```bash
launchctl load ~/Library/LaunchAgents/com.hydra.sync.plist
```

### 3. Verify Setup

```bash
# Check database
sqlite3 ~/.hydra/hydra.db "SELECT * FROM agents;"

# Check launchd
launchctl list | grep hydra

# Manual sync test
~/Development/scripts/hydra-sync.sh
```

## Usage

### Check Agent Workload

```bash
sqlite3 ~/.hydra/hydra.db "SELECT * FROM v_agent_workload;"
```

### View Pending Tasks

```bash
sqlite3 ~/.hydra/hydra.db "SELECT id, title, assigned_to, priority FROM tasks WHERE status = 'pending';"
```

### View Notifications

```bash
sqlite3 ~/.hydra/hydra.db "SELECT * FROM v_pending_notifications;"
```

## CLI Commands

The `hydra` CLI is available after setup:

```bash
hydra status              # Show system status and agent workload
hydra agents              # List all agents
hydra tasks [agent]       # List tasks (optionally filter by agent)
hydra task create         # Interactive task creation
hydra notify @agent msg   # Send notification to agent
hydra route "message"     # Route message with @mentions
hydra standup             # Generate daily standup
hydra notifications       # Show pending notifications
hydra activity [n]        # Show recent activity
```

### Examples

```bash
# Route a message with @mentions
hydra route "Hey @forge can you fix the auth bug? It's urgent!"

# Create a task interactively
hydra task create

# Check agent workload
hydra status
```

## Notification System

HYDRA uses a centralized notification dispatcher (`notify-eddie.sh`) that routes alerts through multiple channels based on priority:

| Priority | Telegram | macOS Alert | MacDown Opens |
|----------|----------|-------------|---------------|
| urgent   | Yes      | Yes         | Yes           |
| high     | No       | Yes         | Yes           |
| normal   | No       | Yes         | No            |
| silent   | No       | No          | No (log only) |

### Setting Up Telegram Notifications

1. **Create a Telegram Bot:**
   - Message [@BotFather](https://t.me/BotFather) on Telegram
   - Send `/newbot` and follow the prompts
   - Copy your bot token (looks like `123456789:ABCdefGHIjklMNO...`)

2. **Get Your Chat ID:**
   - Message [@userinfobot](https://t.me/userinfobot) or [@getmyid_bot](https://t.me/getmyid_bot)
   - Copy your chat ID (a number like `123456789`)

3. **Configure HYDRA:**
   ```bash
   cp ~/.hydra/config/telegram.env.example ~/.hydra/config/telegram.env
   chmod 600 ~/.hydra/config/telegram.env
   # Edit telegram.env with your bot token and chat ID
   ```

4. **Test:**
   ```bash
   ~/.hydra/daemons/notify-eddie.sh urgent "Test" "Telegram working!"
   ```

### macOS Notifications

Install terminal-notifier for desktop alerts:
```bash
brew install terminal-notifier
```

## Launchd Jobs

| Job | Schedule | Purpose |
|-----|----------|---------|
| com.hydra.sync | 8:30 AM daily | Sync automation findings to tasks |
| com.hydra.standup | 8:35 AM daily | Generate daily standup |
| com.hydra.briefing | 8:40 AM daily | Morning briefing in MacDown |
| com.hydra.notification-check | Every 5 min | Alert on urgent notifications |
| com.hydra.agent-milo | Every 15 min | Coordinator heartbeat |
| com.hydra.agent-forge | Every 30 min | Dev specialist heartbeat |
| com.hydra.agent-pulse | Every 30 min | Ops specialist heartbeat |
| com.hydra.agent-scout | Every 60 min | Research specialist heartbeat |

## Related Files

- `scripts/hydra-sync.sh` - Automation sync script (this repo)
- `scripts/hydra-standup.sh` - Daily standup generator (this repo)
- `~/.hydra/` - HYDRA configuration and daemons (outside repo, private)
- `~/.hydra/tools/hydra-cli.sh` - CLI tool (symlinked to ~/.local/bin/hydra)
- `~/.hydra/config/telegram.env` - Telegram credentials (DO NOT COMMIT)

## Background

HYDRA is inspired by:
- **Eddie's Automation Empire**: 23 launchd jobs for signal detection
- **Bhanu's Mission Control**: Multi-agent coordination via shared database

The hybrid approach combines automated signal detection with intelligent agent routing.

---

## Article

For the full story of how HYDRA was designed and built, see:
[Building an AI-Human Operating System v2](./articles/building-ai-human-os-v2.md)

---

*Created: 2026-02-05*
