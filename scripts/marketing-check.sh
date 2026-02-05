#!/bin/bash
# marketing-check.sh - Daily Marketing Accountability
# Runs: 11 AM daily via launchd
# Logs: ~/Library/Logs/claude-automation/marketing-check/
#
# This script:
# 1. Check if any marketing tasks done today
# 2. Generate 3 quick-win marketing suggestions
# 3. Reference X-Place content calendar
# 4. Track streak of consecutive marketing days
# 5. Send summary to logs

set -euo pipefail

# Configuration
LOGS_DIR="$HOME/Library/Logs/claude-automation/marketing-check"
DATE=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%A)
LOG_FILE="$LOGS_DIR/check-$DATE.log"
REPORT_FILE="$LOGS_DIR/report-$DATE.md"
STREAK_FILE="$LOGS_DIR/.marketing-streak"
MARKETING_LOG="$LOGS_DIR/.marketing-history"

# Create directories
mkdir -p "$LOGS_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "Marketing Accountability Check"
log "Date: $DAY_OF_WEEK, $DATE"
log "========================================"
echo ""

# ===================================================================
# STEP 1: Track streak
# ===================================================================

log "Step 1: Checking marketing streak..."

# Initialize streak file if it doesn't exist
if [[ ! -f "$STREAK_FILE" ]]; then
    echo "0:1970-01-01" > "$STREAK_FILE"
fi

# Read current streak
STREAK_DATA=$(cat "$STREAK_FILE")
CURRENT_STREAK=$(echo "$STREAK_DATA" | cut -d: -f1)
LAST_MARKETING_DATE=$(echo "$STREAK_DATA" | cut -d: -f2)

# Calculate yesterday's date
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)

# Check if streak is still active
if [[ "$LAST_MARKETING_DATE" == "$YESTERDAY" ]] || [[ "$LAST_MARKETING_DATE" == "$DATE" ]]; then
    STREAK_STATUS="ACTIVE"
    log "  Streak is active: $CURRENT_STREAK days"
elif [[ "$LAST_MARKETING_DATE" == "$(date -v-2d +%Y-%m-%d 2>/dev/null || date -d '2 days ago' +%Y-%m-%d)" ]]; then
    STREAK_STATUS="AT_RISK"
    log "  Streak at risk! Last marketing: $LAST_MARKETING_DATE"
else
    STREAK_STATUS="BROKEN"
    CURRENT_STREAK=0
    log "  Streak broken. Starting fresh."
fi

echo ""

# ===================================================================
# STEP 2: Generate quick-win suggestions
# ===================================================================

log "Step 2: Generating marketing suggestions..."

# Day-specific suggestions
case "$DAY_OF_WEEK" in
    Monday)
        SUGGESTIONS=(
            "Share a Week Ahead preview post on X about your current project"
            "Schedule 3 LinkedIn posts for this week using Buffer or native scheduler"
            "Reply to 5 comments on posts in your niche (build relationships)"
        )
        ;;
    Tuesday)
        SUGGESTIONS=(
            "Write and publish a LinkedIn article about a recent learning"
            "Share a code snippet or technical tip on X"
            "Engage with 3 potential customers in relevant communities"
        )
        ;;
    Wednesday)
        SUGGESTIONS=(
            "Create a short video or Loom explaining a feature"
            "Post a behind the scenes look at development"
            "Share a customer win or testimonial"
        )
        ;;
    Thursday)
        SUGGESTIONS=(
            "Write a thread on X about a problem you have solved"
            "Cross-post your best content from earlier this week"
            "Engage in 2 relevant Discord/Slack communities"
        )
        ;;
    Friday)
        SUGGESTIONS=(
            "Share a Shipped This Week recap post"
            "Celebrate a small win publicly"
            "Set up content for weekend posting"
        )
        ;;
    Saturday|Sunday)
        SUGGESTIONS=(
            "Light day - share something casual/personal"
            "Queue up content for Monday"
            "Batch create 3-5 posts for next week"
        )
        ;;
esac

echo ""

# ===================================================================
# STEP 3: Check X-Place content calendar
# ===================================================================

log "Step 3: Checking content calendar..."

CALENDAR_CONTENT=""
CALENDAR_FILE="$HOME/Development/x-place/CONTENT_CALENDAR.md"

if [[ -f "$CALENDAR_FILE" ]]; then
    TODAY_CONTENT=$(grep -A 5 "## $DATE" "$CALENDAR_FILE" 2>/dev/null || echo "")
    if [[ -n "$TODAY_CONTENT" ]]; then
        CALENDAR_CONTENT="$TODAY_CONTENT"
        log "  Found scheduled content for today"
    else
        CALENDAR_CONTENT="No content scheduled for today."
        log "  No content scheduled for today"
    fi
else
    CALENDAR_CONTENT="No content calendar found at $CALENDAR_FILE"
    log "  Content calendar not found"
fi

echo ""

# ===================================================================
# GENERATE REPORT
# ===================================================================

log "Generating report..."

case "$STREAK_STATUS" in
    ACTIVE)
        STREAK_MESSAGE="Your streak is ACTIVE at $CURRENT_STREAK days. Keep it going!"
        STREAK_EMOJI="[STREAK: $CURRENT_STREAK days]"
        ;;
    AT_RISK)
        STREAK_MESSAGE="WARNING: Your streak is at risk! Do something today to keep your $CURRENT_STREAK-day streak."
        STREAK_EMOJI="[AT RISK!]"
        ;;
    BROKEN)
        STREAK_MESSAGE="Your streak was broken. Today is day 1 of a new streak!"
        STREAK_EMOJI="[New Streak: Day 1]"
        ;;
esac

cat > "$REPORT_FILE" << EOF
# Marketing Accountability Check
**$DAY_OF_WEEK, $DATE** | $STREAK_EMOJI

---

## Streak Status

$STREAK_MESSAGE

---

## Today's Quick Wins

Pick ONE of these to maintain your streak:

1. ${SUGGESTIONS[0]}
2. ${SUGGESTIONS[1]}
3. ${SUGGESTIONS[2]}

---

## Content Calendar

$CALENDAR_CONTENT

---

## How to Log Marketing Activity

When you complete a marketing task, run:
\`\`\`bash
~/Development/scripts/marketing-check.sh --mark-done
\`\`\`

---
*Generated by marketing-check.sh*
EOF

# Handle --mark-done flag
if [[ "${1:-}" == "--mark-done" ]]; then
    echo "$DATE: Marketing task completed" >> "$MARKETING_LOG"
    NEW_STREAK=$((CURRENT_STREAK + 1))
    echo "$NEW_STREAK:$DATE" > "$STREAK_FILE"
    log "Marked marketing as done! Streak updated to $NEW_STREAK days."
    terminal-notifier -title "Marketing Streak!" \
        -message "Day $NEW_STREAK streak! Keep it up!" \
        -sound default 2>/dev/null || true
    exit 0
fi

log "========================================"
log "Marketing Check Complete"
log "Report: $REPORT_FILE"
log "========================================"

# Send notification
if command -v terminal-notifier &> /dev/null; then
    if [[ "$STREAK_STATUS" == "AT_RISK" ]]; then
        terminal-notifier -title "Marketing Streak at Risk!" \
            -message "Do one marketing task today to save your streak!" \
            -sound Basso
    else
        terminal-notifier -title "Marketing Check" \
            -message "Quick wins ready. Streak: $CURRENT_STREAK days" \
            -sound default
    fi
fi

exit 0
