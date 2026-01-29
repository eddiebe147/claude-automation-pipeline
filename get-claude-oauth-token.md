# Get Fresh OAuth Token from Claude.ai

## Steps to Extract OAuth Token from Browser

1. **Open claude.ai** (should already be open)
2. **Log in** if you're not already
3. **Open Developer Tools:**
   - Press `Cmd + Option + I` (Chrome/Safari)
   - Or right-click → Inspect

4. **Go to Application Tab** (Chrome) or **Storage Tab** (Safari/Firefox)

5. **Find Cookies** → `claude.ai` → Look for:
   - `sessionKey` or `auth_token` or similar

6. **OR go to Network Tab:**
   - Refresh the page
   - Look for a request to `api.anthropic.com`
   - Click on it
   - Go to "Headers"
   - Look for `Authorization: Bearer sk-ant-...`

7. **Copy the token** that starts with `sk-ant-oat01-...` (OAuth access token)

8. **Paste it here in the chat** and I'll update your config

---

## Alternative: Use Session Storage

1. In Developer Tools, go to **Console tab**
2. Run this command:
   ```javascript
   console.log(localStorage)
   console.log(sessionStorage)
   ```
3. Look for any keys containing "auth", "token", "session"
4. Copy the value and send it to me

---

**I'll wait for you to paste the token!**
