#!/bin/bash
# morning-commitment.sh - Lock in the ONE Thing for Today
# Runs: 7 AM daily via launchd
# Logs: ~/Library/Logs/claude-automation/morning-commitment/
#
# This script:
# 1. Pulls signal queue from MILO (top priority tasks)
# 2. Shows yesterday's commitments - did you finish?
# 3. Prompts for TODAY's ONE thing
# 4. Creates accountability record
# 5. Integrates with evening kickoff

set -euo pipefail

# Configuration
LOGS_DIR="$HOME/Library/Logs/claude-automation/morning-commitment"
DATE=$(date +%Y-%m-%d)
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
DAY_OF_WEEK=$(date +%A)
LOG_FILE="$LOGS_DIR/morning-$DATE.log"
REPORT_FILE="$LOGS_DIR/report-$DATE.md"
COMMITMENT_FILE="$LOGS_DIR/.commitments.json"
MILO_DB="$HOME/.milo/milo.db"

# Create directories
mkdir -p "$LOGS_DIR"

# Initialize commitment file
if [[ ! -f "$COMMITMENT_FILE" ]]; then
    echo '{}' > "$COMMITMENT_FILE"
fi

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "Morning Commitment - $DAY_OF_WEEK"
log "Date: $DATE"
log "========================================"
echo ""

# ===================================================================
# STEP 1: Check yesterday's commitment
# ===================================================================

log "Step 1: Reviewing yesterday's commitment..."

YESTERDAY_COMMITMENT=$(jq -r ".[\"$YESTERDAY\"].commitment // \"No commitment recorded\"" "$COMMITMENT_FILE")
YESTERDAY_COMPLETED=$(jq -r ".[\"$YESTERDAY\"].completed // false" "$COMMITMENT_FILE")

if [[ "$YESTERDAY_COMMITMENT" != "No commitment recorded" ]]; then
    log "  Yesterday's commitment: $YESTERDAY_COMMITMENT"
    log "  Completed: $YESTERDAY_COMPLETED"
else
    log "  No commitment was recorded for yesterday"
fi

echo ""

# ===================================================================
# STEP 2: Get MILO signal queue (if database exists)
# ===================================================================

log "Step 2: Pulling MILO signal queue..."

SIGNAL_TASKS=""
if [[ -f "$MILO_DB" ]]; then
    # Query MILO SQLite database directly for signal tasks
    SIGNAL_TASKS=$(sqlite3 "$MILO_DB" "
        SELECT title, priority, status 
        FROM tasks 
        WHERE status IN ('in_progress', 'todo') 
        ORDER BY 
            CASE status WHEN 'in_progress' THEN 0 ELSE 1 END,
            priority ASC,
            created_at ASC
        LIMIT 5;
    " 2>/dev/null | while IFS='|' read title priority status; do
        echo "- [$priority] $title ($status)"
    done)
    
    if [[ -n "$SIGNAL_TASKS" ]]; then
        log "  Found signal tasks from MILO"
    else
        log "  No active tasks in MILO"
        SIGNAL_TASKS="No tasks in MILO signal queue"
    fi
else
    log "  MILO database not found at $MILO_DB"
    SIGNAL_TASKS="MILO not configured - add tasks at https://milo.id8labs.com"
fi

echo ""

# ===================================================================
# STEP 3: Get today's calendar context
# ===================================================================

log "Step 3: Checking calendar..."

CALENDAR_CONTEXT=""
# Try to get calendar events using AppleScript (macOS)
if command -v osascript &> /dev/null; then
    CALENDAR_EVENTS=$(osascript -e '
        tell application "Calendar"
            set todayStart to current date
            set hours of todayStart to 0
            set minutes of todayStart to 0
            set seconds of todayStart to 0
            set todayEnd to todayStart + (1 * days)
            
            set eventList to {}
            repeat with cal in calendars
                set calEvents to (every event of cal whose start date >= todayStart and start date < todayEnd)
                repeat with ev in calEvents
                    set end of eventList to (summary of ev & " at " & time string of start date of ev)
                end repeat
            end repeat
            return eventList
        end tell
    ' 2>/dev/null | tr ',' '\n' | head -5)
    
    if [[ -n "$CALENDAR_EVENTS" ]]; then
        CALENDAR_CONTEXT="$CALENDAR_EVENTS"
        log "  Found calendar events for today"
    else
        CALENDAR_CONTEXT="No calendar events for today"
        log "  No calendar events found"
    fi
else
    CALENDAR_CONTEXT="Calendar access not available"
    log "  Calendar access not available"
fi

echo ""

# ===================================================================
# STEP 4: Calculate commitment streak
# ===================================================================

log "Step 4: Calculating streak..."

STREAK=0
CHECK_DATE="$YESTERDAY"
while true; do
    WAS_COMPLETED=$(jq -r ".[\"$CHECK_DATE\"].completed // false" "$COMMITMENT_FILE")
    if [[ "$WAS_COMPLETED" == "true" ]]; then
        STREAK=$((STREAK + 1))
        CHECK_DATE=$(date -v-1d -j -f "%Y-%m-%d" "$CHECK_DATE" +%Y-%m-%d 2>/dev/null || date -d "$CHECK_DATE -1 day" +%Y-%m-%d)
    else
        break
    fi
    # Safety limit
    if [[ $STREAK -gt 365 ]]; then break; fi
done

log "  Current commitment streak: $STREAK days"

echo ""

# ===================================================================
# GENERATE REPORT
# ===================================================================

log "Generating morning commitment report..."

cat > "$REPORT_FILE" << EOF
# Morning Commitment
**$DAY_OF_WEEK, $DATE** | Streak: $STREAK days

---

## Yesterday's Review

**Commitment:** $YESTERDAY_COMMITMENT
**Completed:** $(if [[ "$YESTERDAY_COMPLETED" == "true" ]]; then echo "Yes"; else echo "No"; fi)

---

## Today's Signal Queue (from MILO)

$SIGNAL_TASKS

---

## Calendar Today

$(echo "$CALENDAR_CONTEXT" | sed 's/^/- /')

---

## Your ONE Thing

What is the ONE thing you will complete today?

### How to Commit

\`\`\`bash
~/Development/scripts/morning-commitment.sh --commit "Your one thing here"
\`\`\`

### Mark Yesterday Complete

\`\`\`bash
~/Development/scripts/morning-commitment.sh --complete-yesterday
\`\`\`

---

## The Rule

> "If you commit to it in the morning, you must review it in the evening."

The evening-kickoff will show your commitment and ask if you completed it.

---
*Generated by morning-commitment.sh*
*"The ONE Thing" - what's the single most important task that makes everything else easier or unnecessary?*
EOF

# Handle --commit flag
if [[ "${1:-}" == "--commit" ]] && [[ -n "${2:-}" ]]; then
    jq ". + {\"$DATE\": {\"commitment\": \"$2\", \"completed\": false, \"committed_at\": \"$(date -Iseconds)\"}}" "$COMMITMENT_FILE" > "$COMMITMENT_FILE.tmp" && mv "$COMMITMENT_FILE.tmp" "$COMMITMENT_FILE"
    log "Committed: $2"
    terminal-notifier -title "Morning Commitment Locked" \
        -message "ONE THING: $2" \
        -sound default 2>/dev/null || true
    exit 0
fi

# Handle --complete-yesterday flag
if [[ "${1:-}" == "--complete-yesterday" ]]; then
    jq ".[\"$YESTERDAY\"].completed = true" "$COMMITMENT_FILE" > "$COMMITMENT_FILE.tmp" && mv "$COMMITMENT_FILE.tmp" "$COMMITMENT_FILE"
    log "Marked yesterday as complete"
    terminal-notifier -title "Commitment Complete!" \
        -message "Yesterday's task marked done. Streak: $((STREAK + 1)) days!" \
        -sound default 2>/dev/null || true
    exit 0
fi

log "========================================"
log "Morning Commitment Complete"
log "Report: $REPORT_FILE"
log "========================================"

# Notification
if command -v terminal-notifier &> /dev/null; then
    terminal-notifier -title "Morning Commitment" \
        -message "What's your ONE thing today? Streak: $STREAK days" \
        -sound default
fi

exit 0
