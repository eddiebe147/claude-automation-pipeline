#!/bin/bash
# OpenClaw Health Check & Auto-Recovery
# Usage: openclaw-health or source this and run openclaw_health

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "========================================"
echo "   OpenClaw Health Check"
echo "========================================"
echo ""

# 0. Quick AI test
echo "Testing AI connection..."
AI_TEST=$(openclaw agent --message "Reply with only: OK" --agent main --local 2>&1 || true)
if echo "$AI_TEST" | grep -qi "ok"; then
    echo -e "${GREEN}[OK]${NC} AI responding"
elif echo "$AI_TEST" | grep -qi "No API key"; then
    echo -e "${RED}[FAIL]${NC} No Anthropic API key configured"
    echo "       Run: export ANTHROPIC_API_KEY=your_key"
    echo "       Then add to openclaw auth-profiles.json"
else
    echo -e "${YELLOW}[WARN]${NC} AI test inconclusive: ${AI_TEST:0:50}..."
fi
echo ""

# 1. Check if gateway is running
echo "Checking gateway..."
GATEWAY_STATUS=$(openclaw gateway status 2>&1)

if echo "$GATEWAY_STATUS" | grep -q "Runtime: running"; then
    echo -e "${GREEN}[OK]${NC} Gateway is running"
    GATEWAY_OK=true
else
    echo -e "${YELLOW}[WARN]${NC} Gateway not running. Starting..."
    openclaw gateway start
    sleep 3

    # Verify it started
    GATEWAY_STATUS=$(openclaw gateway status 2>&1)
    if echo "$GATEWAY_STATUS" | grep -q "Runtime: running"; then
        echo -e "${GREEN}[OK]${NC} Gateway started successfully"
        GATEWAY_OK=true
    else
        echo -e "${RED}[FAIL]${NC} Gateway failed to start. Check logs:"
        echo "  openclaw gateway logs"
        GATEWAY_OK=false
    fi
fi

echo ""

# 2. Check channels
echo "Checking channels..."
FULL_STATUS=$(openclaw status 2>&1)

# Telegram
if echo "$FULL_STATUS" | grep -q "Telegram.*ON.*OK"; then
    echo -e "${GREEN}[OK]${NC} Telegram: Connected"
elif echo "$FULL_STATUS" | grep -q "Telegram.*ON"; then
    echo -e "${YELLOW}[WARN]${NC} Telegram: Enabled but has issues"
else
    echo -e "${YELLOW}[OFF]${NC} Telegram: Disabled"
fi

# WhatsApp
if echo "$FULL_STATUS" | grep -q "WhatsApp.*ON.*OK"; then
    echo -e "${GREEN}[OK]${NC} WhatsApp: Connected"
elif echo "$FULL_STATUS" | grep -q "WhatsApp.*linked"; then
    echo -e "${YELLOW}[WARN]${NC} WhatsApp: Needs re-linking"
    echo "         Run: openclaw pair whatsapp"
elif echo "$FULL_STATUS" | grep -q "WhatsApp.*ON"; then
    echo -e "${YELLOW}[WARN]${NC} WhatsApp: Enabled but not linked"
    echo "         Run: openclaw pair whatsapp"
else
    echo -e "${YELLOW}[OFF]${NC} WhatsApp: Disabled"
fi

# iMessage
if echo "$FULL_STATUS" | grep -q "iMessage.*ON.*OK"; then
    echo -e "${GREEN}[OK]${NC} iMessage: Connected"
elif echo "$FULL_STATUS" | grep -q "iMessage.*OFF"; then
    echo -e "${YELLOW}[OFF]${NC} iMessage: Disabled"
    echo "         Enable: openclaw config set channels.imessage.enabled true"
else
    echo -e "${YELLOW}[WARN]${NC} iMessage: Has issues (check Full Disk Access)"
fi

echo ""
echo "========================================"

# Summary
if [ "$GATEWAY_OK" = true ]; then
    echo -e "${GREEN}OpenClaw is running${NC}"
    echo "Dashboard: http://127.0.0.1:18789/"
else
    echo -e "${RED}OpenClaw has issues${NC}"
    echo "Run: openclaw gateway logs"
fi

echo "========================================"
