#!/bin/bash
# Integration Test Script for LobeHub + Clawdbot

echo "=========================================="
echo "LobeHub Integration Test Suite"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; }
warn() { echo -e "${YELLOW}WARN${NC}: $1"; }

# Test 1: Docker containers
echo "1. Docker Container Status"
echo "-------------------------------------------"
for container in lobe-postgres lobe-redis lobe-rustfs lobehub lobe-casdoor lobe-network; do
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        status=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-health")
        if [ "$status" = "healthy" ] || [ "$status" = "no-health" ]; then
            pass "$container is running"
        else
            warn "$container is running but unhealthy"
        fi
    else
        fail "$container is not running"
    fi
done
echo ""

# Test 2: Service endpoints
echo "2. Service Endpoints"
echo "-------------------------------------------"

# LobeHub
if curl -s http://localhost:3210 | grep -q "localhost:3210"; then
    pass "LobeHub (localhost:3210)"
else
    fail "LobeHub (localhost:3210)"
fi

# Casdoor OIDC
if curl -s http://localhost:8000/.well-known/openid-configuration | grep -q "issuer"; then
    pass "Casdoor OIDC (localhost:8000)"
else
    fail "Casdoor OIDC (localhost:8000)"
fi

# RustFS
if curl -s http://localhost:9000/health | grep -q "ok"; then
    pass "RustFS Storage (localhost:9000)"
else
    fail "RustFS Storage (localhost:9000)"
fi

# Clawdbot Gateway
if curl -s http://127.0.0.1:18789 | grep -q "Clawdbot"; then
    pass "Clawdbot Gateway (localhost:18789)"
else
    fail "Clawdbot Gateway (localhost:18789)"
fi

# Ollama
if curl -s http://localhost:11434/api/tags | grep -q "models"; then
    pass "Ollama API (localhost:11434)"
else
    fail "Ollama API (localhost:11434)"
fi
echo ""

# Test 3: Database
echo "3. Database Connectivity"
echo "-------------------------------------------"
if docker exec lobe-postgres psql -U postgres -d lobechat -c "SELECT 1" >/dev/null 2>&1; then
    pass "PostgreSQL connection"
else
    fail "PostgreSQL connection"
fi

if docker exec lobe-postgres psql -U postgres -d lobechat -c "SELECT extversion FROM pg_extension WHERE extname='vector'" 2>/dev/null | grep -q "0.8"; then
    pass "pgvector extension"
else
    fail "pgvector extension"
fi

kb_count=$(docker exec lobe-postgres psql -U postgres -d lobechat -t -c "SELECT COUNT(*) FROM knowledge_documents" 2>/dev/null | tr -d ' ')
if [ "$kb_count" = "0" ]; then
    warn "Knowledge base is empty (run: cd knowledge && python ingest.py)"
else
    pass "Knowledge base has $kb_count documents"
fi
echo ""

# Test 4: MCP Bridge
echo "4. MCP Bridge"
echo "-------------------------------------------"
if [ -f "/Users/eddiebelaval/Development/lobehub-local/mcp-bridge/dist/index.js" ]; then
    pass "MCP Bridge built"
else
    fail "MCP Bridge not built (run: cd mcp-bridge && npm run build)"
fi
echo ""

# Test 5: Ollama Models
echo "5. Ollama Models"
echo "-------------------------------------------"
models=$(curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null)
for model in "qwen2.5:32b" "qwen3:8b" "nomic-embed-text"; do
    if echo "$models" | grep -q "$model"; then
        pass "$model available"
    else
        fail "$model not installed"
    fi
done
echo ""

# Summary
echo "=========================================="
echo "Integration Test Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Open http://localhost:3210 in browser"
echo "  2. Login with admin/123 via Casdoor"
echo "  3. Add MCP server in Settings > Plugins > MCP"
echo "  4. Import agent templates from agents/ directory"
echo "  5. Run: cd knowledge && python ingest.py"
echo ""
