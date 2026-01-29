# LobeHub Local - Multi-Agent AI Platform

Visual agent designer integrated with Clawdbot's 30+ tools for Eddie's AI workforce.

## Architecture

```
LobeHub (localhost:3210) - Visual Agent Designer
    |
    v [MCP Protocol - stdio]
MCP Bridge (clawdbot-mcp-bridge)
    |
    v [WebSocket]
Clawdbot Gateway (localhost:18789) - 30+ tools
    |
    v [Channels]
Telegram/Email (User Interface)
```

## Quick Start

### 1. Download Casdoor Config

```bash
cd /Users/eddiebelaval/Development/lobehub-local
curl -sLO https://raw.githubusercontent.com/lobehub/lobe-chat/HEAD/docker-compose/local/init_data.json
```

### 2. Start Services

```bash
docker compose up -d
```

### 2. Access LobeHub

Open http://localhost:3210

Default login: `admin` / `123` (via Casdoor SSO at http://localhost:8000)

### 3. Configure MCP Bridge

In LobeHub Settings > Plugins > MCP, add:

```json
{
  "mcpServers": {
    "clawdbot": {
      "command": "node",
      "args": ["/Users/eddiebelaval/Development/lobehub-local/mcp-bridge/dist/index.js"],
      "env": {
        "CLAWDBOT_GATEWAY_URL": "ws://127.0.0.1:18789",
        "CLAWDBOT_AUTH_TOKEN": "eca2cfbff0223b4396f0a2223b74c712488ecf29eed7ef81"
      }
    }
  }
}
```

### 4. Ingest Knowledge Base

```bash
cd knowledge
pip install -r requirements.txt
python ingest.py
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| LobeHub | 3210 | Main UI |
| Casdoor | 8000 | SSO Authentication |
| RustFS | 9000 | S3 Storage |
| RustFS Console | 9001 | Storage UI |
| PostgreSQL | 5433 | Database with pgvector |
| Redis | 6379 | Cache |
| SearXNG | 8080 | Private Search |

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| Milo | qwen2.5:32b | Primary coordinator |
| Research | qwen2.5:32b | Web research |
| Code | claude-sonnet-4 | Development |
| Ops | qwen3:8b | Automation |
| Memory | qwen2.5:32b | Knowledge |

## MCP Tools Available

- `clawdbot_agent` - Execute AI agent
- `clawdbot_chat_send` - Send messages
- `clawdbot_chat_history` - Get chat history
- `clawdbot_memory_search` - Search knowledge
- `clawdbot_cron_add/remove/list` - Scheduling
- `clawdbot_status/health` - System status
- And more...

## Directory Structure

```
lobehub-local/
├── docker-compose.yml      # Service stack
├── .env                    # Configuration
├── mcp-bridge/            # Clawdbot MCP bridge
│   ├── src/index.ts
│   └── dist/              # Built bridge
├── knowledge/             # Knowledge base
│   ├── schema.sql         # pgvector schema
│   └── ingest.py          # Ingestion script
├── agents/                # Agent templates
│   ├── milo-coordinator.json
│   ├── research-agent.json
│   ├── code-agent.json
│   ├── ops-agent.json
│   └── memory-agent.json
└── data/                  # Persistent data
    └── postgres/
```

## Commands

```bash
# Check status
docker compose ps

# View logs
docker compose logs -f lobehub

# Stop services
docker compose down

# Full reset (removes data)
docker compose down -v
```

## Cost Optimization

- Quick queries: qwen3:8b (free)
- Research/bulk: qwen2.5:32b (free)
- Reasoning: deepseek-r1 (free)
- Code/architecture: claude-sonnet-4 (~$0.003/K tokens)

Target: 70%+ requests handled by local models.
