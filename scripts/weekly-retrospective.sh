#!/bin/bash
# weekly-retrospective.sh - Aggregate Weekly Reports + Trends
# Runs: Sunday 9 AM via launchd (after all other Sunday jobs)
# Logs: ~/Library/Logs/claude-automation/weekly-retrospective/
#
# This script:
# 1. Aggregates all daily reports from the week
# 2. Calculates trends (streaks, completion rates)
# 3. Identifies patterns (what worked, what didn't)
# 4. Generates retrospective prompts
# 5. Creates weekly summary

set -euo pipefail

# Configuration
LOGS_BASE="$HOME/Library/Logs/claude-automation"
LOGS_DIR="$LOGS_BASE/weekly-retrospective"
DATE=$(date +%Y-%m-%d)
WEEK_NUM=$(date +%V)
YEAR=$(date +%Y)
LOG_FILE="$LOGS_DIR/retrospective-$DATE.log"
REPORT_FILE="$LOGS_DIR/week-$YEAR-W$WEEK_NUM.md"

# Create directories
mkdir -p "$LOGS_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "Weekly Retrospective - Week $WEEK_NUM"
log "Date: $DATE"
log "========================================"
echo ""

# ===================================================================
# STEP 1: Aggregate commitment data
# ===================================================================

log "Step 1: Aggregating commitment data..."

COMMITMENT_FILE="$LOGS_BASE/morning-commitment/.commitments.json"
COMMITMENT_STATS=""
COMPLETED_COUNT=0
TOTAL_COUNT=0

if [[ -f "$COMMITMENT_FILE" ]]; then
    # Get last 7 days of commitments
    for i in {0..6}; do
        CHECK_DATE=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || date -d "$i days ago" +%Y-%m-%d)
        COMMITMENT=$(jq -r ".[\"$CHECK_DATE\"].commitment // \"none\"" "$COMMITMENT_FILE")
        COMPLETED=$(jq -r ".[\"$CHECK_DATE\"].completed // false" "$COMMITMENT_FILE")
        
        if [[ "$COMMITMENT" != "none" ]]; then
            TOTAL_COUNT=$((TOTAL_COUNT + 1))
            if [[ "$COMPLETED" == "true" ]]; then
                COMPLETED_COUNT=$((COMPLETED_COUNT + 1))
                COMMITMENT_STATS+="- [x] $CHECK_DATE: $COMMITMENT\n"
            else
                COMMITMENT_STATS+="- [ ] $CHECK_DATE: $COMMITMENT\n"
            fi
        fi
    done
fi

if [[ $TOTAL_COUNT -gt 0 ]]; then
    COMPLETION_RATE=$((COMPLETED_COUNT * 100 / TOTAL_COUNT))
else
    COMPLETION_RATE=0
fi

log "  Commitment completion rate: $COMPLETION_RATE% ($COMPLETED_COUNT/$TOTAL_COUNT)"

echo ""

# ===================================================================
# STEP 2: Aggregate marketing streak
# ===================================================================

log "Step 2: Checking marketing streak..."

MARKETING_STREAK_FILE="$LOGS_BASE/marketing-check/.marketing-streak"
MARKETING_STREAK=0
if [[ -f "$MARKETING_STREAK_FILE" ]]; then
    MARKETING_STREAK=$(cat "$MARKETING_STREAK_FILE" | cut -d: -f1)
fi
log "  Marketing streak: $MARKETING_STREAK days"

echo ""

# ===================================================================
# STEP 3: Count stale items from 70% detector
# ===================================================================

log "Step 3: Reviewing 70% detector findings..."

STALE_REPORT="$LOGS_BASE/seventy-percent-detector/report-$DATE.md"
STALE_ITEMS=""
if [[ -f "$STALE_REPORT" ]]; then
    STALE_ITEMS=$(grep -c "^-" "$STALE_REPORT" || echo "0")
    log "  Stale items found: $STALE_ITEMS"
else
    log "  No 70% detector report for today"
fi

echo ""

# ===================================================================
# STEP 4: Check security status from dependency guardian
# ===================================================================

log "Step 4: Reviewing security status..."

LAST_SECURITY_REPORT=$(ls -t "$LOGS_BASE/dependency-guardian/report-"*.md 2>/dev/null | head -1)
SECURITY_STATUS="Unknown"
if [[ -n "$LAST_SECURITY_REPORT" ]] && [[ -f "$LAST_SECURITY_REPORT" ]]; then
    SECURITY_STATUS=$(grep "Urgency Level" "$LAST_SECURITY_REPORT" | cut -d: -f2 | tr -d ' ' || echo "Unknown")
    log "  Security urgency: $SECURITY_STATUS"
fi

echo ""

# ===================================================================
# STEP 5: Count projects touched this week
# ===================================================================

log "Step 5: Analyzing context switching..."

DEV_DIR="$HOME/Development"
PROJECTS_TOUCHED=0
PROJECT_LIST=""

while IFS= read -r gitdir; do
    repo_path=$(dirname "$gitdir")
    repo_name=$(basename "$repo_path")
    cd "$repo_path" 2>/dev/null || continue
    
    # Count commits in last 7 days
    COMMIT_COUNT=$(git log --oneline --since="7 days ago" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ $COMMIT_COUNT -gt 0 ]]; then
        PROJECTS_TOUCHED=$((PROJECTS_TOUCHED + 1))
        PROJECT_LIST+="- $repo_name: $COMMIT_COUNT commits\n"
    fi
done < <(find "$DEV_DIR" -maxdepth 3 -name ".git" -type d 2>/dev/null)

log "  Projects touched this week: $PROJECTS_TOUCHED"

# Determine focus score
if [[ $PROJECTS_TOUCHED -le 2 ]]; then
    FOCUS_SCORE="EXCELLENT - Deep work zone"
elif [[ $PROJECTS_TOUCHED -le 4 ]]; then
    FOCUS_SCORE="GOOD - Manageable spread"
elif [[ $PROJECTS_TOUCHED -le 6 ]]; then
    FOCUS_SCORE="FAIR - Consider consolidating"
else
    FOCUS_SCORE="SCATTERED - Too many contexts"
fi

echo ""

# ===================================================================
# GENERATE RETROSPECTIVE REPORT
# ===================================================================

log "Generating weekly retrospective..."

cat > "$REPORT_FILE" << EOF
# Weekly Retrospective
**Week $WEEK_NUM of $YEAR** | Generated: $DATE

---

## Weekly Scorecard

| Metric | Value | Status |
|--------|-------|--------|
| Commitment Completion | $COMPLETION_RATE% | $(if [[ $COMPLETION_RATE -ge 80 ]]; then echo "Excellent"; elif [[ $COMPLETION_RATE -ge 60 ]]; then echo "Good"; else echo "Needs Work"; fi) |
| Marketing Streak | $MARKETING_STREAK days | $(if [[ $MARKETING_STREAK -ge 5 ]]; then echo "On Fire!"; elif [[ $MARKETING_STREAK -ge 2 ]]; then echo "Building"; else echo "Start Fresh"; fi) |
| Projects Touched | $PROJECTS_TOUCHED | $FOCUS_SCORE |
| Security Status | $SECURITY_STATUS | $(if [[ "$SECURITY_STATUS" == "LOW" ]]; then echo "All Clear"; else echo "Review Needed"; fi) |
| Stale Items | $STALE_ITEMS | $(if [[ $STALE_ITEMS -le 3 ]]; then echo "Clean"; else echo "Attention Needed"; fi) |

---

## Daily Commitments This Week

$(if [[ -n "$COMMITMENT_STATS" ]]; then echo -e "$COMMITMENT_STATS"; else echo "No commitments tracked this week."; fi)

---

## Project Activity

$(echo -e "$PROJECT_LIST")

---

## Retrospective Questions

### What Went Well?
- [ ] What commitments did you complete?
- [ ] What momentum did you build?
- [ ] What habits are working?

### What Didn't Go Well?
- [ ] What commitments did you miss?
- [ ] Where did you get stuck?
- [ ] What patterns are hurting you?

### What Will You Change?
- [ ] ONE habit to start
- [ ] ONE habit to stop
- [ ] ONE habit to continue

---

## Focus Areas for Next Week

Based on this week's data:

$(if [[ $COMPLETION_RATE -lt 60 ]]; then echo "1. **Commitment Quality**: Make smaller, more achievable commitments"; fi)
$(if [[ $MARKETING_STREAK -lt 3 ]]; then echo "2. **Marketing Consistency**: Build the daily marketing habit"; fi)
$(if [[ $PROJECTS_TOUCHED -gt 5 ]]; then echo "3. **Context Switching**: Pick 2-3 projects max for next week"; fi)
$(if [[ "$SECURITY_STATUS" != "LOW" ]]; then echo "4. **Security**: Address dependency vulnerabilities"; fi)
$(if [[ $STALE_ITEMS -gt 5 ]]; then echo "5. **Finish What You Started**: Clear stale branches and PRs"; fi)

---

## Historical Trend

See previous weeks: \`ls $LOGS_DIR/week-*.md\`

---
*Generated by weekly-retrospective.sh*
*"We do not learn from experience... we learn from reflecting on experience." - John Dewey*
EOF

log "========================================"
log "Weekly Retrospective Complete"
log "Report: $REPORT_FILE"
log "========================================"

# Notification
if command -v terminal-notifier &> /dev/null; then
    terminal-notifier -title "Weekly Retrospective Ready" \
        -message "Commitment rate: $COMPLETION_RATE% | Projects: $PROJECTS_TOUCHED" \
        -sound default
fi

exit 0
