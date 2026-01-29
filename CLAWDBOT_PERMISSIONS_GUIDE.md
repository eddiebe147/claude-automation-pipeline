# Clawdbot Full Disk Access Setup Guide

## Problem

Clawdbot's iMessage channel integration requires Full Disk Access to read your Messages database at:
```
/Users/eddiebelaval/Library/Messages/chat.db
```

When Clawdbot's gateway spawns the `imsg` child process, macOS checks permissions on **BOTH** the parent process (Node.js) AND the child process (imsg binary).

## Solution

Grant Full Disk Access to all components in the execution chain.

---

## Step-by-Step Instructions

### 1. Open System Settings

System Settings is already open (or run this):
```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
```

Navigate to: **Privacy & Security → Full Disk Access**

### 2. Click Lock Icon

Click the lock icon (🔒) in the bottom-left and enter your password to make changes.

### 3. Add Required Binaries

Click the **+** button and add each of these:

#### a. imsg binary (CRITICAL - this is the missing one!)

Press **Cmd+Shift+G** and paste:
```
/opt/homebrew/Cellar/imsg/0.4.0/bin/imsg
```

Select the `imsg` binary and click "Open"

#### b. Node.js binaries (likely already added, but verify)

**NVM Node.js:**
Press **Cmd+Shift+G** and paste:
```
/Users/eddiebelaval/.nvm/versions/node/v22.21.1/bin/node
```

**Homebrew Node.js:**
Press **Cmd+Shift+G** and paste:
```
/opt/homebrew/opt/node@22/bin/node
```

#### c. Your Terminal App

Add either:
- `/Applications/iTerm.app` (if using iTerm)
- `/Applications/Utilities/Terminal.app` (if using Terminal)

Navigate to Applications folder and select your terminal app.

#### d. Clawdbot GUI App (optional, only if using the GUI)

Navigate to `/Applications/` and select `Clawdbot.app`

### 4. Verify Permissions Were Added

Your Full Disk Access list should now include:
- ✓ imsg (newly added)
- ✓ node (NVM)
- ✓ node (Homebrew)
- ✓ iTerm (or Terminal)
- ✓ Clawdbot (optional)

### 5. Restart Clawdbot Gateway

**Stop the gateway:**
```bash
clawdbot gateway stop
```

**Start the gateway:**
```bash
clawdbot gateway start
```

### 6. Test the Setup

**Run the verification script:**
```bash
bash ~/Development/verify-clawdbot-permissions.sh
```

Expected output:
```
✓ PASS - imsg can read Messages database
✓ PASS - Node.js can spawn imsg with Full Disk Access
✓ PASS - Clawdbot gateway is running

✓ ALL CRITICAL TESTS PASSED
```

**Send a test message:**
1. Send yourself an iMessage
2. Clawdbot should respond
3. Check logs if there are issues: `clawdbot gateway logs`

---

## Why These Binaries Need Access

| Binary | Why It Needs Access | What Breaks Without It |
|--------|---------------------|------------------------|
| **imsg** | Reads Messages database directly | `permissionDenied(path: '.../chat.db')` |
| **node (NVM)** | Spawns imsg as child process | Child process inherits parent restrictions |
| **node (Homebrew)** | Backup if using brew-installed Node | Same as above |
| **Terminal** | Runs commands that access protected files | Commands fail with permission denied |
| **Clawdbot.app** | GUI app that manages gateway | GUI-spawned processes inherit restrictions |

---

## Troubleshooting

### Still Getting Permission Denied?

1. **Check the exact error in logs:**
   ```bash
   clawdbot gateway logs | grep -i permission
   ```

2. **Verify imsg works standalone:**
   ```bash
   /opt/homebrew/Cellar/imsg/0.4.0/bin/imsg chats --limit 1
   ```

   If this fails, imsg doesn't have Full Disk Access.

3. **Verify Node.js can spawn imsg:**
   ```bash
   node -e 'require("child_process").execFileSync("/opt/homebrew/Cellar/imsg/0.4.0/bin/imsg", ["chats", "--limit", "1"])'
   ```

   If this fails, Node.js doesn't have Full Disk Access.

4. **Check if you added the RIGHT binary:**
   ```bash
   which imsg
   readlink -f $(which imsg)
   ```

   Make sure the path in Full Disk Access matches the real binary path.

5. **Restart your Mac:**
   Sometimes macOS needs a restart for TCC permissions to fully take effect.

### Gateway Won't Start

```bash
# Check what's blocking it
clawdbot gateway logs --lines 50

# Try running in foreground to see errors
clawdbot gateway start --foreground
```

### iMessage Not Responding

1. **Check if Messages is signed in:**
   - Open Messages app
   - Ensure you're signed in to iMessage

2. **Check Clawdbot config:**
   ```bash
   clawdbot config
   ```

   Verify `channels.imessage.enabled = true`

3. **Check pairing status:**
   ```bash
   clawdbot pairing list imessage
   ```

   You may need to approve your own number/email.

---

## Quick Reference

### Verification Script
```bash
bash ~/Development/verify-clawdbot-permissions.sh
```

### Add More Binaries Later
```bash
bash ~/Development/add-imsg-to-fda.sh
```

### Test Full Disk Access
```bash
bash ~/Development/test-fda-permissions.sh
```

### Gateway Commands
```bash
clawdbot gateway start        # Start gateway
clawdbot gateway stop         # Stop gateway
clawdbot gateway restart      # Restart gateway
clawdbot gateway status       # Check status
clawdbot gateway logs         # View logs
clawdbot gateway logs --live  # Live log tail
```

---

## Security Note

**Why Full Disk Access is needed:**

The Messages database (`chat.db`) is protected by macOS because it contains sensitive personal information. Apple requires explicit Full Disk Access permission for any app that wants to read it.

Clawdbot needs this access to:
- Read incoming iMessages
- Display message history as context
- Route replies to the correct conversation

This is the same permission Messages.app itself has - Clawdbot acts as an iMessage client.

**What Clawdbot can access with these permissions:**
- Your Messages database (iMessages, SMS, attachments)
- Any other files the user explicitly authorizes via MCP servers
- Files within Clawdbot's workspace directory

**What Clawdbot CANNOT access:**
- Files outside its scope (unless explicitly configured)
- System files (requires additional permissions)
- Other users' files (sandboxed per macOS user)

---

## Next Steps

Once permissions are working:

1. **Configure iMessage channel settings:**
   - DM policy (pairing/allowlist/open)
   - Group policy (allowlist/open/disabled)
   - History limits

2. **Add allowed contacts:**
   ```bash
   clawdbot pairing approve imessage <CODE>
   ```

3. **Test with different scenarios:**
   - DM conversation
   - Group chat
   - Attachments (photos, files)
   - Long context conversations

4. **Set up other channels:**
   - Telegram
   - WhatsApp
   - Discord
   - Slack

5. **Explore Clawdbot skills:**
   ```bash
   ls ~/.nvm/versions/node/v20.18.0/lib/node_modules/clawdbot/skills/
   ```

---

## Resources

- **Clawdbot Docs:** `~/.nvm/versions/node/v20.18.0/lib/node_modules/clawdbot/docs/`
- **iMessage Channel:** `docs/channels/imessage.md`
- **Configuration:** `docs/gateway/configuration.md`
- **Official Site:** https://docs.clawd.bot

---

*Last Updated: January 25, 2026*
