#!/bin/bash
# Comprehensive verification of Clawdbot Full Disk Access permissions

echo "════════════════════════════════════════════════════════════════"
echo "  Clawdbot iMessage Channel Permission Verification"
echo "════════════════════════════════════════════════════════════════"
echo ""

MESSAGES_DB="/Users/eddiebelaval/Library/Messages/chat.db"
IMSG_BIN="/opt/homebrew/Cellar/imsg/0.4.0/bin/imsg"

# Test 1: imsg binary direct access
echo "Test 1: imsg binary can read Messages database"
if "$IMSG_BIN" chats --limit 1 >/dev/null 2>&1; then
  echo "✓ PASS - imsg can read Messages database"
  TEST1=0
else
  echo "✗ FAIL - imsg cannot read Messages database"
  echo "  Action: Add $IMSG_BIN to Full Disk Access"
  TEST1=1
fi
echo ""

# Test 2: NVM Node.js can spawn imsg and read database
echo "Test 2: Node.js can spawn child processes with Full Disk Access"
/Users/eddiebelaval/.nvm/versions/node/v22.21.1/bin/node -e '
const { execFileSync } = require("child_process");
try {
  execFileSync("/opt/homebrew/Cellar/imsg/0.4.0/bin/imsg", ["chats", "--limit", "1"], { stdio: "pipe" });
  console.log("✓ PASS - Node.js can spawn imsg with Full Disk Access");
  process.exit(0);
} catch (err) {
  console.log("✗ FAIL - Node.js cannot spawn imsg with Full Disk Access");
  console.log("  Action: Ensure both Node.js AND imsg have Full Disk Access");
  process.exit(1);
}
' 2>&1
TEST2=$?
echo ""

# Test 3: Check if Clawdbot gateway is running
echo "Test 3: Clawdbot gateway status"
if ps aux | grep -v grep | grep "clawdbot-gateway" >/dev/null; then
  echo "✓ PASS - Clawdbot gateway is running"
  TEST3=0
else
  echo "⚠ WARNING - Clawdbot gateway is not running"
  echo "  Action: Start with 'clawdbot gateway start'"
  TEST3=1
fi
echo ""

# Summary
echo "════════════════════════════════════════════════════════════════"
echo "  Summary"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ $TEST1 -eq 0 ] && [ $TEST2 -eq 0 ]; then
  echo "✓ ALL CRITICAL TESTS PASSED"
  echo ""
  echo "Clawdbot iMessage channel should work correctly!"
  echo ""
  if [ $TEST3 -ne 0 ]; then
    echo "Next step: Start the gateway"
    echo "  clawdbot gateway start"
  else
    echo "Gateway is running. Test by:"
    echo "  1. Send an iMessage to yourself"
    echo "  2. Check if Clawdbot responds"
    echo "  3. View logs: clawdbot gateway logs"
  fi
else
  echo "✗ SOME TESTS FAILED"
  echo ""
  echo "Required actions:"
  echo ""
  echo "1. Open: System Settings → Privacy & Security → Full Disk Access"
  echo "2. Click lock icon and authenticate"
  echo "3. Click '+' and add these if missing:"

  if [ $TEST1 -ne 0 ]; then
    echo "   - $IMSG_BIN"
  fi

  if [ $TEST2 -ne 0 ]; then
    echo "   - /Users/eddiebelaval/.nvm/versions/node/v22.21.1/bin/node"
  fi

  echo ""
  echo "4. After adding, restart gateway:"
  echo "   clawdbot gateway stop"
  echo "   clawdbot gateway start"
  echo ""
  echo "5. Run this test again:"
  echo "   bash ~/Development/verify-clawdbot-permissions.sh"
fi
echo ""
