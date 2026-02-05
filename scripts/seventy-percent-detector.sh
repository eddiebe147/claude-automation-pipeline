#!/bin/bash
# seventy-percent-detector.sh - Catch Features Stuck at 70%
# Runs: Sunday 8 AM via launchd
# Logs: ~/Library/Logs/claude-automation/seventy-percent-detector/
#
# This script catches the "70% completion" pattern by detecting:
# 1. Branches with no commits in 7+ days
# 2. PIPELINE_STATUS.md stages stuck > 1 week
# 3. TODO/FIXME comments in recent code
# 4. PRs open > 5 days without merge
# 5. Generates "finish these first" priority list

set -euo pipefail

# Configuration
LOGS_DIR="$HOME/Library/Logs/claude-automation/seventy-percent-detector"
DEV_DIR="$HOME/Development"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOGS_DIR/detector-$DATE.log"
REPORT_FILE="$LOGS_DIR/report-$DATE.md"

# Create directories
mkdir -p "$LOGS_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "70% Detector - Weekly Analysis"
log "Date: $DATE"
log "========================================"
echo ""

# Initialize collections
STALE_BRANCHES=""
STUCK_PIPELINES=""
STALE_PRS=""
TODO_FIXMES=""
PRIORITY_LIST=""

# ===================================================================
# STEP 1: Find stale branches (no commits in 7+ days)
# ===================================================================

log "Step 1: Scanning for stale branches..."

SEVEN_DAYS_AGO=$(date -v-7d +%s 2>/dev/null || date -d "7 days ago" +%s)

while IFS= read -r gitdir; do
    repo_path=$(dirname "$gitdir")
    repo_name=$(basename "$repo_path")
    cd "$repo_path" 2>/dev/null || continue
    
    # Get all remote branches
    for branch in $(git branch -r 2>/dev/null | grep -v HEAD | sed 's/origin\///' | tr -d ' '); do
        # Skip protected branches
        if [[ "$branch" =~ ^(main|master|develop|dev)$ ]]; then
            continue
        fi
        
        # Get last commit timestamp
        LAST_COMMIT=$(git log -1 --format="%ct" "origin/$branch" 2>/dev/null || echo "0")
        
        if [[ "$LAST_COMMIT" != "0" ]] && [[ "$LAST_COMMIT" -lt "$SEVEN_DAYS_AGO" ]]; then
            DAYS_AGO=$(( ($(date +%s) - LAST_COMMIT) / 86400 ))
            LAST_MESSAGE=$(git log -1 --format="%s" "origin/$branch" 2>/dev/null | head -c 50)
            STALE_BRANCHES+="- **[$repo_name]** \`$branch\` - ${DAYS_AGO}d stale - \"$LAST_MESSAGE...\"\n"
            
            if [[ $DAYS_AGO -gt 14 ]]; then
                PRIORITY_LIST+="- ABANDON OR FINISH: $repo_name/$branch (${DAYS_AGO} days stale)\n"
            fi
        fi
    done
done < <(find "$DEV_DIR" -maxdepth 3 -name ".git" -type d 2>/dev/null)

log "  Found stale branches"
echo ""

# ===================================================================
# STEP 2: Check for stuck pipeline stages
# ===================================================================

log "Step 2: Checking for stuck pipeline stages..."

ONE_WEEK_AGO=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d)

while IFS= read -r pipeline_file; do
    project_dir=$(dirname "$pipeline_file")
    project_name=$(basename "$project_dir")
    
    # Get last modified date of pipeline file
    LAST_MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d" "$pipeline_file" 2>/dev/null || stat --format="%y" "$pipeline_file" 2>/dev/null | cut -d' ' -f1)
    
    if [[ "$LAST_MODIFIED" < "$ONE_WEEK_AGO" ]]; then
        # Extract current stage
        CURRENT_STAGE=$(grep -E "^## Current Stage" "$pipeline_file" -A 2 | tail -1 | sed 's/^[[:space:]]*//' | head -c 50)
        STUCK_PIPELINES+="- **$project_name**: Stuck at \"$CURRENT_STAGE\" (since $LAST_MODIFIED)\n"
        PRIORITY_LIST+="- ADVANCE PIPELINE: $project_name - stuck at $CURRENT_STAGE\n"
    fi
done < <(find "$DEV_DIR" -maxdepth 3 -name "PIPELINE_STATUS.md" -type f 2>/dev/null)

log "  Checked pipeline statuses"
echo ""

# ===================================================================
# STEP 3: Find TODO/FIXME in recent code
# ===================================================================

log "Step 3: Scanning for unresolved TODOs..."

TODO_COUNT=0
while IFS= read -r gitdir; do
    repo_path=$(dirname "$gitdir")
    repo_name=$(basename "$repo_path")
    cd "$repo_path" 2>/dev/null || continue
    
    # Find TODOs in files modified in last 30 days
    RECENT_TODOS=$(git diff --name-only HEAD~50 2>/dev/null | while read file; do
        if [[ -f "$file" ]]; then
            grep -n "TODO\|FIXME" "$file" 2>/dev/null | grep -v "#[0-9]\|[A-Z]\+-[0-9]" | head -3
        fi
    done | head -5)
    
    if [[ -n "$RECENT_TODOS" ]]; then
        TODO_FIXMES+="### $repo_name\n\`\`\`\n$RECENT_TODOS\n\`\`\`\n"
        TODO_COUNT=$((TODO_COUNT + 1))
    fi
done < <(find "$DEV_DIR" -maxdepth 3 -name ".git" -type d 2>/dev/null)

log "  Found $TODO_COUNT repos with untracked TODOs"
echo ""

# ===================================================================
# STEP 4: Check for stale PRs
# ===================================================================

log "Step 4: Checking for stale PRs..."

if command -v gh &> /dev/null; then
    REPOS=("id8labs/homer" "id8labs/x-place" "id8labs/ai-agents")
    FIVE_DAYS_AGO=$(date -v-5d +%Y-%m-%d 2>/dev/null || date -d "5 days ago" +%Y-%m-%d)
    
    for repo in "${REPOS[@]}"; do
        prs=$(gh pr list --repo "$repo" --state open --json number,title,createdAt,author --limit 10 2>/dev/null || echo "[]")
        
        if [[ "$prs" != "[]" ]]; then
            while IFS= read -r pr; do
                pr_num=$(echo "$pr" | jq -r '.number')
                pr_title=$(echo "$pr" | jq -r '.title')
                pr_created=$(echo "$pr" | jq -r '.createdAt' | cut -dT -f1)
                
                if [[ "$pr_created" < "$FIVE_DAYS_AGO" ]]; then
                    DAYS_OLD=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$pr_created" "+%s" 2>/dev/null || date -d "$pr_created" "+%s")) / 86400 ))
                    STALE_PRS+="- **$repo #$pr_num**: $pr_title (${DAYS_OLD}d open)\n"
                    PRIORITY_LIST+="- MERGE OR CLOSE: $repo PR #$pr_num (${DAYS_OLD} days)\n"
                fi
            done < <(echo "$prs" | jq -c '.[]')
        fi
    done
fi

log "  Checked open PRs"
echo ""

# ===================================================================
# GENERATE REPORT
# ===================================================================

log "Step 5: Generating report..."

cat > "$REPORT_FILE" << EOF
# 70% Detector Report
**Week of:** $DATE

---

## Priority: Finish These First

These items have been languishing and need attention:

$(if [[ -n "$PRIORITY_LIST" ]]; then echo -e "$PRIORITY_LIST"; else echo "Nothing urgent - great job staying on top of things!"; fi)

---

## Stale Branches (7+ days without commits)

$(if [[ -n "$STALE_BRANCHES" ]]; then echo -e "$STALE_BRANCHES"; else echo "No stale branches found."; fi)

---

## Stuck Pipeline Stages (1+ week same stage)

$(if [[ -n "$STUCK_PIPELINES" ]]; then echo -e "$STUCK_PIPELINES"; else echo "All pipelines are progressing."; fi)

---

## Stale Pull Requests (5+ days open)

$(if [[ -n "$STALE_PRS" ]]; then echo -e "$STALE_PRS"; else echo "No stale PRs."; fi)

---

## Untracked TODOs/FIXMEs

$(if [[ -n "$TODO_FIXMES" ]]; then echo -e "$TODO_FIXMES"; else echo "No untracked TODOs found."; fi)

---

## Action Items

1. Review priority items above
2. Either finish, delegate, or explicitly abandon stale work
3. Add ticket references to any TODOs you plan to keep

---
*Generated by seventy-percent-detector.sh*
*"Almost done" is the enemy of done.*
EOF

log "========================================"
log "70% Detector Complete"
log "Report: $REPORT_FILE"
log "========================================"

# Notification
if command -v terminal-notifier &> /dev/null; then
    PRIORITY_COUNT=$(echo -e "$PRIORITY_LIST" | grep -c "^-" || echo "0")
    terminal-notifier -title "70% Detector" \
        -message "Found $PRIORITY_COUNT items needing attention" \
        -sound default
fi

exit 0
