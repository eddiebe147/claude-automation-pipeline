#!/bin/bash
# Test Full Disk Access permissions for Clawdbot

echo "════════════════════════════════════════════════════════════════"
echo "  Testing Full Disk Access Permissions"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Test file that requires Full Disk Access
TEST_FILE="/Users/eddiebelaval/Library/Messages/chat.db"

echo "Test file: $TEST_FILE"
echo ""

# Test 1: NVM Node.js (your active version)
echo "Test 1: NVM Node.js"
echo "Binary: /Users/eddiebelaval/.nvm/versions/node/v22.21.1/bin/node"
/Users/eddiebelaval/.nvm/versions/node/v22.21.1/bin/node -e "
try {
  const fs = require('fs');
  const size = fs.readFileSync('$TEST_FILE').length;
  console.log('✓ SUCCESS - Can read Messages database (' + size + ' bytes)');
} catch (err) {
  console.log('✗ FAILED - ' + err.message);
  process.exit(1);
}
" 2>&1
TEST1=$?
echo ""

# Test 2: Homebrew Node.js
echo "Test 2: Homebrew Node.js"
echo "Binary: /opt/homebrew/opt/node@22/bin/node"
/opt/homebrew/opt/node@22/bin/node -e "
try {
  const fs = require('fs');
  const size = fs.readFileSync('$TEST_FILE').length;
  console.log('✓ SUCCESS - Can read Messages database (' + size + ' bytes)');
} catch (err) {
  console.log('✗ FAILED - ' + err.message);
  process.exit(1);
}
" 2>&1
TEST2=$?
echo ""

# Test 3: Direct file access from shell
echo "Test 3: Current Shell/Terminal"
if [ -r "$TEST_FILE" ]; then
  SIZE=$(stat -f%z "$TEST_FILE" 2>/dev/null)
  echo "✓ SUCCESS - Terminal has access (file size: $SIZE bytes)"
  TEST3=0
else
  echo "✗ FAILED - Terminal cannot read file"
  TEST3=1
fi
echo ""

# Summary
echo "════════════════════════════════════════════════════════════════"
echo "  Summary"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ $TEST1 -eq 0 ] && [ $TEST2 -eq 0 ] && [ $TEST3 -eq 0 ]; then
  echo "✓ ALL TESTS PASSED"
  echo ""
  echo "Full Disk Access is properly configured!"
  echo "You can now use Clawdbot with imsg and other MCP servers."
  echo ""
  echo "Next: Restart Clawdbot gateway to apply permissions:"
  echo "  clawdbot gateway stop"
  echo "  clawdbot gateway start"
else
  echo "✗ SOME TESTS FAILED"
  echo ""
  echo "Action needed:"
  echo "1. Open System Settings → Privacy & Security → Full Disk Access"
  echo "2. Click lock icon and authenticate"
  echo "3. Add these binaries using Cmd+Shift+G:"

  if [ $TEST1 -ne 0 ]; then
    echo "   - /Users/eddiebelaval/.nvm/versions/node/v22.21.1/bin/node"
  fi

  if [ $TEST2 -ne 0 ]; then
    echo "   - /opt/homebrew/opt/node@22/bin/node"
  fi

  if [ $TEST3 -ne 0 ]; then
    echo "   - Your Terminal app (iTerm.app or Terminal.app)"
  fi

  echo ""
  echo "4. After adding, run this test again:"
  echo "   bash ~/Development/test-fda-permissions.sh"
fi
echo ""
