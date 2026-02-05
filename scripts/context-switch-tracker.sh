#!/bin/bash
# context-switch-tracker.sh - Track Daily Context Switching
# Runs: 11 PM daily via launchd (end of day)
# Logs: ~/Library/Logs/claude-automation/context-switch/
#
# This script:
# 1. Counts how many repos you committed to today
# 2. Measures "focus score" based on commit concentration
# 3. Alerts if spreading too thin (> 3 projects/day)
# 4. Tracks deep work patterns

set -euo pipefail

# Configuration
LOGS_DIR="$HOME/Library/Logs/claude-automation/context-switch"
DEV_DIR="$HOME/Development"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOGS_DIR/tracker-$DATE.log"
REPORT_FILE="$LOGS_DIR/report-$DATE.md"
HISTORY_FILE="$LOGS_DIR/.context-history.json"

# Create directories
mkdir -p "$LOGS_DIR"

# Initialize history
if [[ ! -f "$HISTORY_FILE" ]]; then
    echo '{}' > "$HISTORY_FILE"
fi

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "Context Switch Tracker"
log "Date: $DATE"
log "========================================"
echo ""

# ===================================================================
# STEP 1: Count repos with commits today
# ===================================================================

log "Step 1: Counting commits by repo..."

PROJECTS_TODAY=0
TOTAL_COMMITS=0
PROJECT_BREAKDOWN=""
DOMINANT_PROJECT=""
DOMINANT_COMMITS=0

while IFS= read -r gitdir; do
    repo_path=$(dirname "$gitdir")
    repo_name=$(basename "$repo_path")
    cd "$repo_path" 2>/dev/null || continue
    
    # Count commits today
    COMMIT_COUNT=$(git log --oneline --since="6am" --until="now" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ $COMMIT_COUNT -gt 0 ]]; then
        PROJECTS_TODAY=$((PROJECTS_TODAY + 1))
        TOTAL_COMMITS=$((TOTAL_COMMITS + COMMIT_COUNT))
        PROJECT_BREAKDOWN+="- **$repo_name**: $COMMIT_COUNT commits\n"
        
        # Track dominant project
        if [[ $COMMIT_COUNT -gt $DOMINANT_COMMITS ]]; then
            DOMINANT_COMMITS=$COMMIT_COUNT
            DOMINANT_PROJECT=$repo_name
        fi
        
        log "  $repo_name: $COMMIT_COUNT commits"
    fi
done < <(find "$DEV_DIR" -maxdepth 3 -name ".git" -type d 2>/dev/null)

log "  Total: $PROJECTS_TODAY projects, $TOTAL_COMMITS commits"

echo ""

# ===================================================================
# STEP 2: Calculate focus score
# ===================================================================

log "Step 2: Calculating focus score..."

# Focus score = percentage of commits in dominant project
if [[ $TOTAL_COMMITS -gt 0 ]]; then
    FOCUS_PERCENTAGE=$((DOMINANT_COMMITS * 100 / TOTAL_COMMITS))
else
    FOCUS_PERCENTAGE=0
fi

# Determine focus grade
if [[ $PROJECTS_TODAY -eq 0 ]]; then
    FOCUS_GRADE="N/A"
    FOCUS_MESSAGE="No coding activity detected today"
elif [[ $PROJECTS_TODAY -eq 1 ]]; then
    FOCUS_GRADE="A+ (LASER)"
    FOCUS_MESSAGE="Perfect focus! One project, full attention."
elif [[ $PROJECTS_TODAY -eq 2 ]] && [[ $FOCUS_PERCENTAGE -ge 70 ]]; then
    FOCUS_GRADE="A (DEEP)"
    FOCUS_MESSAGE="Great focus with minor secondary work."
elif [[ $PROJECTS_TODAY -le 3 ]] && [[ $FOCUS_PERCENTAGE -ge 50 ]]; then
    FOCUS_GRADE="B (FOCUSED)"
    FOCUS_MESSAGE="Good balance, main project got attention."
elif [[ $PROJECTS_TODAY -le 4 ]]; then
    FOCUS_GRADE="C (SPLIT)"
    FOCUS_MESSAGE="Attention divided. Consider batching similar work."
else
    FOCUS_GRADE="D (SCATTERED)"
    FOCUS_MESSAGE="Too many contexts! This hurts deep work."
fi

log "  Focus grade: $FOCUS_GRADE"
log "  Dominant project: $DOMINANT_PROJECT ($FOCUS_PERCENTAGE% of commits)"

echo ""

# ===================================================================
# STEP 3: Analyze commit timing (deep work detection)
# ===================================================================

log "Step 3: Analyzing commit patterns..."

DEEP_WORK_SESSIONS=0
LONGEST_GAP=0

# Get commit times
COMMIT_TIMES=$(find "$DEV_DIR" -maxdepth 3 -name ".git" -type d -exec sh -c '
    cd "$(dirname {})" && git log --format="%at" --since="6am" 2>/dev/null
' \; | sort -n)

if [[ -n "$COMMIT_TIMES" ]]; then
    PREV_TIME=""
    CURRENT_SESSION_LENGTH=0
    
    while read timestamp; do
        if [[ -n "$PREV_TIME" ]]; then
            GAP=$((timestamp - PREV_TIME))
            GAP_MINUTES=$((GAP / 60))
            
            # If gap > 30 minutes, new session
            if [[ $GAP_MINUTES -gt 30 ]]; then
                if [[ $CURRENT_SESSION_LENGTH -gt 60 ]]; then
                    DEEP_WORK_SESSIONS=$((DEEP_WORK_SESSIONS + 1))
                fi
                CURRENT_SESSION_LENGTH=0
            else
                CURRENT_SESSION_LENGTH=$((CURRENT_SESSION_LENGTH + GAP_MINUTES))
            fi
            
            if [[ $GAP_MINUTES -gt $LONGEST_GAP ]]; then
                LONGEST_GAP=$GAP_MINUTES
            fi
        fi
        PREV_TIME=$timestamp
    done <<< "$COMMIT_TIMES"
    
    # Count final session if long enough
    if [[ $CURRENT_SESSION_LENGTH -gt 60 ]]; then
        DEEP_WORK_SESSIONS=$((DEEP_WORK_SESSIONS + 1))
    fi
fi

log "  Deep work sessions (>1hr continuous): $DEEP_WORK_SESSIONS"
log "  Longest break between commits: $LONGEST_GAP minutes"

echo ""

# ===================================================================
# STEP 4: Update history
# ===================================================================

log "Step 4: Updating history..."

jq ". + {\"$DATE\": {\"projects\": $PROJECTS_TODAY, \"commits\": $TOTAL_COMMITS, \"focus_grade\": \"$FOCUS_GRADE\", \"deep_work_sessions\": $DEEP_WORK_SESSIONS, \"dominant_project\": \"$DOMINANT_PROJECT\"}}" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

# Calculate 7-day average
SEVEN_DAY_AVG=$(jq '[to_entries | .[-7:] | .[].value.projects] | add / length | floor' "$HISTORY_FILE" 2>/dev/null || echo "0")

echo ""

# ===================================================================
# GENERATE REPORT
# ===================================================================

log "Generating report..."

cat > "$REPORT_FILE" << EOF
# Daily Context Switch Report
**$DATE** | Focus Grade: $FOCUS_GRADE

---

## Summary

| Metric | Today | 7-Day Avg |
|--------|-------|-----------|
| Projects | $PROJECTS_TODAY | $SEVEN_DAY_AVG |
| Commits | $TOTAL_COMMITS | - |
| Deep Work Sessions | $DEEP_WORK_SESSIONS | - |
| Focus Score | $FOCUS_PERCENTAGE% | - |

---

## Focus Analysis

**Grade:** $FOCUS_GRADE

$FOCUS_MESSAGE

**Dominant Project:** $DOMINANT_PROJECT ($DOMINANT_COMMITS commits, $FOCUS_PERCENTAGE% of total)

---

## Project Breakdown

$(echo -e "$PROJECT_BREAKDOWN")

---

## Recommendations

$(if [[ $PROJECTS_TODAY -gt 3 ]]; then
echo "### Context Switching Alert"
echo "You touched $PROJECTS_TODAY projects today. Consider:"
echo "- Batching similar work together"
echo "- Picking ONE main project per day"
echo "- Using \"project days\" (Monday = Homer, Tuesday = X-Place)"
fi)

$(if [[ $DEEP_WORK_SESSIONS -eq 0 ]] && [[ $TOTAL_COMMITS -gt 0 ]]; then
echo "### No Deep Work Detected"
echo "All your commits were scattered. Try:"
echo "- Block 2-hour chunks for focused work"
echo "- Turn off notifications during deep work"
echo "- Use the Pomodoro technique"
fi)

$(if [[ $FOCUS_PERCENTAGE -lt 50 ]] && [[ $PROJECTS_TODAY -gt 1 ]]; then
echo "### Split Attention"
echo "No single project got majority attention. Tomorrow:"
echo "- Pick your ONE thing in the morning commitment"
echo "- Commit to finishing before switching"
fi)

---

## Historical Pattern

See trends: \`jq -r 'to_entries | sort_by(.key) | .[-7:] | .[] | \"\\(.key): \\(.value.projects) projects (\\(.value.focus_grade))\"' $HISTORY_FILE\`

---
*Generated by context-switch-tracker.sh*
*"The ability to perform deep work is becoming increasingly rare at exactly the same time it is becoming increasingly valuable." - Cal Newport*
EOF

log "========================================"
log "Context Switch Tracker Complete"
log "Report: $REPORT_FILE"
log "========================================"

# Notification based on focus
if command -v terminal-notifier &> /dev/null; then
    if [[ $PROJECTS_TODAY -gt 4 ]]; then
        terminal-notifier -title "Context Switch Alert" \
            -message "$PROJECTS_TODAY projects today. Too scattered!" \
            -sound Basso
    elif [[ "$FOCUS_GRADE" == *"LASER"* ]] || [[ "$FOCUS_GRADE" == *"DEEP"* ]]; then
        terminal-notifier -title "Deep Work Achievement" \
            -message "Focus grade: $FOCUS_GRADE - Great job!" \
            -sound default
    else
        terminal-notifier -title "Daily Focus Report" \
            -message "$PROJECTS_TODAY projects, $TOTAL_COMMITS commits. Grade: $FOCUS_GRADE" \
            -sound default
    fi
fi

exit 0
