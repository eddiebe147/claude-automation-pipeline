#!/bin/bash
# evening-kickoff.sh - Prepare for evening coding sessions
# Runs: 6 PM daily via launchd
# Logs: ~/Library/Logs/claude-automation/evening-kickoff/
#
# This script:
# 1. Scans PIPELINE_STATUS.md across all projects
# 2. Identifies "next checkpoint" for each active project
# 3. Lists open PRs needing attention
# 4. Shows upcoming deadlines from todo lists
# 5. Generates evening kickoff report

set -euo pipefail

# Configuration
LOGS_DIR="$HOME/Library/Logs/claude-automation/evening-kickoff"
DEV_DIR="$HOME/Development"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOGS_DIR/kickoff-$DATE.log"
REPORT_FILE="$LOGS_DIR/report-$DATE.md"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "Evening Kickoff Report"
log "Started: $(date)"
log "========================================"
echo ""

# Initialize report content
PROJECTS_SECTION=""
PR_SECTION=""
DEADLINES_SECTION=""
PRIORITY_TASKS=""

# ═══════════════════════════════════════════════════════════════
# STEP 1: Scan PIPELINE_STATUS.md across all projects
# ═══════════════════════════════════════════════════════════════

log "Step 1: Scanning project pipelines..."

find_pipeline_status() {
    local dir="$1"
    local name="$2"

    local pipeline_file="$dir/PIPELINE_STATUS.md"
    if [[ -f "$pipeline_file" ]]; then
        # Extract current stage
        local current_stage=$(grep -E "^## Current Stage" "$pipeline_file" -A 2 | tail -1 | sed 's/^[[:space:]]*//' || echo "Unknown")

        # Extract next checkpoint
        local next_checkpoint=$(grep -E "^### Next Checkpoint" "$pipeline_file" -A 1 | tail -1 | sed 's/^[[:space:]]*//' || echo "Unknown")

        # Extract blockers if any
        local blockers=$(grep -E "^### Blockers" "$pipeline_file" -A 3 | grep "^-" | head -2 | sed 's/^/  /' || echo "")

        PROJECTS_SECTION+="### $name\n"
        PROJECTS_SECTION+="- **Stage:** $current_stage\n"
        PROJECTS_SECTION+="- **Next Checkpoint:** $next_checkpoint\n"
        if [[ -n "$blockers" ]]; then
            PROJECTS_SECTION+="- **Blockers:**\n$blockers\n"
        fi
        PROJECTS_SECTION+="\n"

        log "  Found pipeline status for $name: $current_stage"
    fi
}

# Scan Development directory for PIPELINE_STATUS.md files
while IFS= read -r pipeline_file; do
    project_dir=$(dirname "$pipeline_file")
    project_name=$(basename "$project_dir")
    find_pipeline_status "$project_dir" "$project_name"
done < <(find "$DEV_DIR" -maxdepth 3 -name "PIPELINE_STATUS.md" -type f 2>/dev/null)

if [[ -z "$PROJECTS_SECTION" ]]; then
    PROJECTS_SECTION="No projects with PIPELINE_STATUS.md found.\n"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
# STEP 2: Check for open PRs needing attention
# ═══════════════════════════════════════════════════════════════

log "Step 2: Checking open PRs..."

if command -v gh &> /dev/null; then
    # Get PRs for known repos
    REPOS=("id8labs/homer" "id8labs/x-place" "id8labs/ai-agents")

    for repo in "${REPOS[@]}"; do
        log "  Checking $repo..."

        # Get open PRs with age info
        prs=$(gh pr list --repo "$repo" --state open --json number,title,createdAt,author --limit 10 2>/dev/null || echo "[]")

        if [[ "$prs" != "[]" ]] && [[ -n "$prs" ]]; then
            while IFS= read -r pr; do
                pr_num=$(echo "$pr" | jq -r '.number')
                pr_title=$(echo "$pr" | jq -r '.title')
                pr_age=$(echo "$pr" | jq -r '.createdAt')

                # Calculate days since creation
                pr_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$pr_age" "+%s" 2>/dev/null || date -d "$pr_age" "+%s")
                now_timestamp=$(date "+%s")
                days_old=$(( (now_timestamp - pr_timestamp) / 86400 ))

                PR_SECTION+="- **[$repo #$pr_num]** $pr_title (${days_old}d old)\n"

                # Flag PRs older than 5 days as priority
                if [[ $days_old -gt 5 ]]; then
                    PRIORITY_TASKS+="- STALE PR: $repo #$pr_num - $pr_title (${days_old} days)\n"
                fi

            done < <(echo "$prs" | jq -c '.[]')
        fi
    done
else
    log "  GitHub CLI not available, skipping PR check"
    PR_SECTION="GitHub CLI (gh) not installed.\n"
fi

if [[ -z "$PR_SECTION" ]]; then
    PR_SECTION="No open PRs found.\n"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
# STEP 3: Check for TODOs and deadlines
# ═══════════════════════════════════════════════════════════════

log "Step 3: Scanning for TODOs and deadlines..."

# Check for TODO files or deadline markers
find "$DEV_DIR" -maxdepth 3 -name "TODO.md" -type f 2>/dev/null | while read -r todo_file; do
    project_name=$(basename $(dirname "$todo_file"))

    # Look for lines with dates in the next 7 days
    while IFS= read -r line; do
        DEADLINES_SECTION+="- [$project_name] $line\n"
    done < <(grep -E "\b($(date +%Y-%m)|deadline|due|by [0-9]{4}-[0-9]{2})" "$todo_file" 2>/dev/null | head -5)
done

if [[ -z "$DEADLINES_SECTION" ]]; then
    DEADLINES_SECTION="No upcoming deadlines found in TODO.md files.\n"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
# STEP 4: Check recent session context
# ═══════════════════════════════════════════════════════════════

log "Step 4: Checking session memory..."

MEMORY_SECTION=""
MEMORY_FILE="$HOME/.claude/MEMORY.md"

if [[ -f "$MEMORY_FILE" ]]; then
    # Get today's learnings if they exist
    today_section=$(grep -A 10 "### $DATE" "$MEMORY_FILE" 2>/dev/null || echo "")

    if [[ -n "$today_section" ]]; then
        MEMORY_SECTION="### Today's Progress\n$today_section\n"
    fi

    # Get last non-empty session entry
    last_session=$(grep -E "^### [0-9]{4}-[0-9]{2}-[0-9]{2}" "$MEMORY_FILE" | head -1 || echo "")
    if [[ -n "$last_session" ]]; then
        MEMORY_SECTION+="Last session: $last_session\n"
    fi
fi

if [[ -z "$MEMORY_SECTION" ]]; then
    MEMORY_SECTION="No recent session context found.\n"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
# GENERATE REPORT
# ═══════════════════════════════════════════════════════════════

log "Generating evening kickoff report..."

cat > "$REPORT_FILE" << EOF
# Evening Kickoff Report
**Date:** $(date '+%A, %B %d, %Y')
**Generated:** $(date '+%H:%M %Z')

---

## Priority Actions

$(if [[ -n "$PRIORITY_TASKS" ]]; then echo -e "$PRIORITY_TASKS"; else echo "No priority actions identified."; fi)

---

## Project Status

$(echo -e "$PROJECTS_SECTION")

---

## Open Pull Requests

$(echo -e "$PR_SECTION")

---

## Upcoming Deadlines

$(echo -e "$DEADLINES_SECTION")

---

## Session Context

$(echo -e "$MEMORY_SECTION")

---

## Quick Actions

1. Review any stale PRs (> 5 days)
2. Check blockers on active projects
3. Pick one project to advance tonight

---
*Generated by evening-kickoff.sh*
*Log: $LOG_FILE*
EOF

log "========================================"
log "Evening Kickoff Complete"
log "Finished: $(date)"
log "Report: $REPORT_FILE"
log "========================================"

# Optional: Open the report
if command -v terminal-notifier &> /dev/null; then
    terminal-notifier -title "Evening Kickoff Ready" \
        -message "Tonight's prep report is ready. Check $REPORT_FILE" \
        -sound default
fi

exit 0
