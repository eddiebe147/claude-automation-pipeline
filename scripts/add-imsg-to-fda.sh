#!/bin/bash
# Add imsg binary to Full Disk Access for Clawdbot iMessage channel

echo "════════════════════════════════════════════════════════════════"
echo "  Adding imsg to Full Disk Access"
echo "════════════════════════════════════════════════════════════════"
echo ""

IMSG_PATH=$(which imsg)

if [ -z "$IMSG_PATH" ]; then
  echo "✗ imsg not found in PATH"
  echo ""
  echo "Install it with: brew install steipete/tap/imsg"
  exit 1
fi

echo "✓ Found imsg at: $IMSG_PATH"
echo ""

# Resolve any symlinks to get the actual binary
IMSG_REAL=$(readlink -f "$IMSG_PATH" 2>/dev/null || realpath "$IMSG_PATH" 2>/dev/null || echo "$IMSG_PATH")

echo "  Real path: $IMSG_REAL"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo ""
echo "INSTRUCTIONS:"
echo ""
echo "1. I'll open System Settings → Privacy & Security → Full Disk Access"
echo ""
echo "2. Click the lock icon (🔒) and enter your password"
echo ""
echo "3. Click the '+' button"
echo ""
echo "4. Press Cmd+Shift+G and paste this path:"
echo ""
echo "   $IMSG_REAL"
echo ""
echo "5. Select the 'imsg' binary and click 'Open'"
echo ""
echo "6. After adding, restart Clawdbot gateway:"
echo ""
echo "   clawdbot gateway stop"
echo "   clawdbot gateway start"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
read -p "Press ENTER to open System Settings..."

# Open System Settings to Full Disk Access
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"

echo ""
echo "✓ System Settings opened"
echo ""
echo "After adding imsg, test it by:"
echo ""
echo "1. Restart gateway: clawdbot gateway stop && clawdbot gateway start"
echo "2. Send a test iMessage to yourself"
echo "3. Check gateway logs: clawdbot gateway logs"
echo ""
