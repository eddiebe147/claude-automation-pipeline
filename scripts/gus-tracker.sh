#!/bin/bash
# gus-tracker.sh - Track Gus's Learning Progress
# Runs: 8 AM daily via launchd
# Logs: ~/Library/Logs/claude-automation/gus-tracker/
#
# This script:
# 1. Read ~/.claude/MEMORY.md for "Gus Learning Journey"
# 2. Check recent session logs for Gus-related work
# 3. Identify what Gus has mastered vs. needs practice
# 4. Suggest today's teaching focus
# 5. Track streak of learning sessions

set -euo pipefail

# Configuration
LOGS_DIR="$HOME/Library/Logs/claude-automation/gus-tracker"
DATE=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%A)
LOG_FILE="$LOGS_DIR/tracker-$DATE.log"
REPORT_FILE="$LOGS_DIR/report-$DATE.md"
STREAK_FILE="$LOGS_DIR/.gus-learning-streak"
LEARNING_LOG="$LOGS_DIR/.gus-learning-history"
MEMORY_FILE="$HOME/.claude/MEMORY.md"

# Create directories
mkdir -p "$LOGS_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "Gus Learning Progress Tracker"
log "Date: $DAY_OF_WEEK, $DATE"
log "========================================"
echo ""

# ===================================================================
# STEP 1: Track learning streak
# ===================================================================

log "Step 1: Checking learning streak..."

if [[ ! -f "$STREAK_FILE" ]]; then
    echo "0:1970-01-01" > "$STREAK_FILE"
fi

STREAK_DATA=$(cat "$STREAK_FILE")
CURRENT_STREAK=$(echo "$STREAK_DATA" | cut -d: -f1)
LAST_LEARNING_DATE=$(echo "$STREAK_DATA" | cut -d: -f2)

YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)

if [[ "$LAST_LEARNING_DATE" == "$YESTERDAY" ]] || [[ "$LAST_LEARNING_DATE" == "$DATE" ]]; then
    STREAK_STATUS="ACTIVE"
    log "  Learning streak active: $CURRENT_STREAK days"
else
    STREAK_STATUS="NEEDS_ATTENTION"
    log "  No recent learning session detected"
fi

echo ""

# ===================================================================
# STEP 2: Check MEMORY.md for Gus Learning Journey
# ===================================================================

log "Step 2: Reading Gus Learning Journey from MEMORY.md..."

GUS_SECTION=""
SKILLS_MASTERED=""
SKILLS_IN_PROGRESS=""
NEXT_TOPICS=""

if [[ -f "$MEMORY_FILE" ]]; then
    # Look for Gus-related entries
    GUS_SECTION=$(grep -A 20 -i "gus" "$MEMORY_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$GUS_SECTION" ]]; then
        log "  Found Gus-related content in MEMORY.md"
        
        # Extract skills if they're documented
        SKILLS_MASTERED=$(echo "$GUS_SECTION" | grep -i "mastered\|learned\|completed" | head -5 || echo "")
        SKILLS_IN_PROGRESS=$(echo "$GUS_SECTION" | grep -i "learning\|practicing\|working on" | head -5 || echo "")
    else
        log "  No Gus-specific section found in MEMORY.md"
    fi
else
    log "  MEMORY.md not found"
fi

echo ""

# ===================================================================
# STEP 3: Check recent sessions for Gus work
# ===================================================================

log "Step 3: Checking recent sessions for Gus-related work..."

RECENT_GUS_SESSIONS=""
PROJECTS_DIR="$HOME/.claude/projects"

# Look for recent session files mentioning Gus
if [[ -d "$PROJECTS_DIR" ]]; then
    RECENT_GUS_SESSIONS=$(find "$PROJECTS_DIR" -name "*.jsonl" -mtime -7 -exec grep -l -i "gus" {} \; 2>/dev/null | wc -l | tr -d ' ')
    log "  Found $RECENT_GUS_SESSIONS sessions mentioning Gus in last 7 days"
else
    RECENT_GUS_SESSIONS="0"
    log "  Projects directory not found"
fi

echo ""

# ===================================================================
# STEP 4: Generate teaching suggestions
# ===================================================================

log "Step 4: Generating teaching focus suggestions..."

# Age-appropriate learning progression (Gus is learning to code)
TEACHING_TOPICS=(
    "Scratch Jr or Scratch basics - visual programming"
    "Simple HTML - making a personal webpage"
    "Basic Python - print statements and variables"
    "Roblox Studio - game creation basics"
    "Minecraft commands - logic and conditions"
    "Simple math with code - calculator project"
    "Drawing with code - turtle graphics"
    "Story games - interactive fiction"
)

# Pick based on day of week for variety
DAY_NUM=$(date +%u)
TODAY_FOCUS="${TEACHING_TOPICS[$(( (DAY_NUM - 1) % ${#TEACHING_TOPICS[@]} ))]}"

echo ""

# ===================================================================
# STEP 5: Generate report
# ===================================================================

log "Step 5: Generating report..."

cat > "$REPORT_FILE" << EOF
# Gus Learning Progress
**$DAY_OF_WEEK, $DATE**

---

## Learning Streak

$(if [[ "$STREAK_STATUS" == "ACTIVE" ]]; then
echo "Active streak: **$CURRENT_STREAK days** of learning together"
else
echo "Time for a learning session! Start a new streak today."
fi)

---

## Recent Activity

- Sessions with Gus content (last 7 days): $RECENT_GUS_SESSIONS

---

## Skills Tracking

### Mastered
$(if [[ -n "$SKILLS_MASTERED" ]]; then echo "$SKILLS_MASTERED"; else echo "- (Track progress in MEMORY.md under 'Gus Learning Journey')"; fi)

### In Progress
$(if [[ -n "$SKILLS_IN_PROGRESS" ]]; then echo "$SKILLS_IN_PROGRESS"; else echo "- Start tracking what Gus is currently learning"; fi)

---

## Today's Teaching Focus

**Suggested Topic:** $TODAY_FOCUS

### Quick 15-Minute Session Ideas:
1. Code a simple animation together
2. Debug a "broken" program (teach problem-solving)
3. Build something Gus chooses, guide the process
4. Play a coding game (Code.org, Scratch challenges)

---

## Age-Appropriate Platforms

- **Scratch** (scratch.mit.edu) - Visual block coding
- **Code.org** - Hour of Code activities
- **Tynker** - Game-based learning
- **Roblox Studio** - Game creation
- **Minecraft Education** - Learning through play

---

## Log a Learning Session

\`\`\`bash
~/Development/scripts/gus-tracker.sh --log "Topic: [what you covered]"
\`\`\`

---
*Generated by gus-tracker.sh*
*Keep the learning fun!*
EOF

# Handle --log flag
if [[ "${1:-}" == "--log" ]] && [[ -n "${2:-}" ]]; then
    echo "$DATE: $2" >> "$LEARNING_LOG"
    NEW_STREAK=$((CURRENT_STREAK + 1))
    echo "$NEW_STREAK:$DATE" > "$STREAK_FILE"
    log "Logged learning session! Streak: $NEW_STREAK days"
    terminal-notifier -title "Gus Learning Logged!" \
        -message "Day $NEW_STREAK! Great work teaching together." \
        -sound default 2>/dev/null || true
    exit 0
fi

log "========================================"
log "Gus Tracker Complete"
log "Report: $REPORT_FILE"
log "========================================"

# Notification
if command -v terminal-notifier &> /dev/null; then
    terminal-notifier -title "Gus Learning Tracker" \
        -message "Teaching idea ready: $TODAY_FOCUS" \
        -sound default
fi

exit 0
