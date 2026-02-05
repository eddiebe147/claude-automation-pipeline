#!/bin/bash
# git-hygiene.sh - Weekly Git Branch Cleanup
# Runs: Sunday 4 AM via launchd
# Logs: ~/Library/Logs/claude-automation/git-hygiene/
#
# This script:
# 1. Lists all branches merged to main
# 2. Deletes merged local branches (safe)
# 3. Deletes merged remote branches (with confirmation log)
# 4. Prunes orphaned worktrees
# 5. Reports branches older than 30 days (unmerged - needs attention)
# 6. Generates hygiene report

set -euo pipefail

# Configuration
LOGS_DIR="$HOME/Library/Logs/claude-automation/git-hygiene"
DEV_DIR="$HOME/Development"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOGS_DIR/hygiene-$DATE.log"
REPORT_FILE="$LOGS_DIR/report-$DATE.md"
WORKTREE_DIR="$HOME/Development/.worktrees"

# Protected branches (never delete)
PROTECTED_BRANCHES="main|master|develop|dev|staging|production"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "Weekly Git Hygiene"
log "Started: $(date)"
log "========================================"
echo ""

# Counters for report
TOTAL_LOCAL_DELETED=0
TOTAL_REMOTE_DELETED=0
TOTAL_WORKTREES_PRUNED=0
STALE_BRANCHES=""
REPOS_PROCESSED=0

# Function to clean a single git repo
clean_repo() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")

    log "Processing: $repo_name"
    cd "$repo_path"

    # Skip if not a git repo
    if [[ ! -d ".git" ]]; then
        log "  Not a git repo, skipping"
        return
    fi

    # Fetch latest from remote (quietly)
    git fetch --prune --quiet 2>/dev/null || true

    # Get default branch (main or master)
    DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

    # Make sure we're on default branch for safety
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]] && [[ -n "$CURRENT_BRANCH" ]]; then
        log "  Warning: Currently on '$CURRENT_BRANCH', not '$DEFAULT_BRANCH'"
    fi

    # ═══════════════════════════════════════════════════════════════
    # STEP 1: Delete merged LOCAL branches
    # ═══════════════════════════════════════════════════════════════

    log "  Checking for merged local branches..."

    # Get merged branches (excluding protected)
    MERGED_LOCAL=$(git branch --merged "$DEFAULT_BRANCH" 2>/dev/null | grep -vE "^\*|^  ($PROTECTED_BRANCHES)$" | sed 's/^[ \t]*//' || echo "")

    if [[ -n "$MERGED_LOCAL" ]]; then
        while IFS= read -r branch; do
            if [[ -n "$branch" ]]; then
                log "  Deleting local branch: $branch"
                git branch -d "$branch" 2>/dev/null || log "    Failed to delete $branch"
                ((TOTAL_LOCAL_DELETED++)) || true
            fi
        done <<< "$MERGED_LOCAL"
    else
        log "  No merged local branches to delete"
    fi

    # ═══════════════════════════════════════════════════════════════
    # STEP 2: Delete merged REMOTE branches
    # ═══════════════════════════════════════════════════════════════

    log "  Checking for merged remote branches..."

    # Get merged remote branches (excluding protected)
    MERGED_REMOTE=$(git branch -r --merged "$DEFAULT_BRANCH" 2>/dev/null | grep "origin/" | grep -vE "origin/($PROTECTED_BRANCHES|HEAD)" | sed 's/origin\///' | sed 's/^[ \t]*//' || echo "")

    if [[ -n "$MERGED_REMOTE" ]]; then
        while IFS= read -r branch; do
            if [[ -n "$branch" ]]; then
                log "  Deleting remote branch: origin/$branch"
                git push origin --delete "$branch" 2>/dev/null || log "    Failed to delete remote $branch"
                ((TOTAL_REMOTE_DELETED++)) || true
            fi
        done <<< "$MERGED_REMOTE"
    else
        log "  No merged remote branches to delete"
    fi

    # ═══════════════════════════════════════════════════════════════
    # STEP 3: Find stale unmerged branches (> 30 days)
    # ═══════════════════════════════════════════════════════════════

    log "  Checking for stale unmerged branches..."

    # Get unmerged branches with last commit date
    THIRTY_DAYS_AGO=$(date -v-30d +%s 2>/dev/null || date -d "30 days ago" +%s)

    for branch in $(git branch -r 2>/dev/null | grep "origin/" | grep -vE "origin/($PROTECTED_BRANCHES|HEAD)" | sed 's/origin\///' | sed 's/^[ \t]*//'); do
        # Get last commit timestamp for this branch
        LAST_COMMIT=$(git log -1 --format="%ct" "origin/$branch" 2>/dev/null || echo "0")

        if [[ "$LAST_COMMIT" -lt "$THIRTY_DAYS_AGO" ]] && [[ "$LAST_COMMIT" != "0" ]]; then
            LAST_COMMIT_DATE=$(date -r "$LAST_COMMIT" "+%Y-%m-%d" 2>/dev/null || date -d "@$LAST_COMMIT" "+%Y-%m-%d")
            STALE_BRANCHES+="- [$repo_name] $branch (last commit: $LAST_COMMIT_DATE)\n"
            log "  STALE: $branch (last commit: $LAST_COMMIT_DATE)"
        fi
    done

    ((REPOS_PROCESSED++)) || true
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# MAIN: Process all repos in Development
# ═══════════════════════════════════════════════════════════════

log "Scanning $DEV_DIR for git repositories..."
echo ""

# Find all git repos (max depth 2 to include x-place/*, etc.)
while IFS= read -r gitdir; do
    repo_path=$(dirname "$gitdir")
    clean_repo "$repo_path"
done < <(find "$DEV_DIR" -maxdepth 3 -name ".git" -type d 2>/dev/null)

# ═══════════════════════════════════════════════════════════════
# STEP 4: Prune orphaned worktrees
# ═══════════════════════════════════════════════════════════════

log "Pruning orphaned worktrees..."

if [[ -d "$WORKTREE_DIR" ]]; then
    # Count worktrees before pruning
    WORKTREE_COUNT_BEFORE=$(find "$WORKTREE_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | wc -l | tr -d ' ')

    # Prune from each repo
    while IFS= read -r gitdir; do
        repo_path=$(dirname "$gitdir")
        cd "$repo_path"
        git worktree prune 2>/dev/null || true
    done < <(find "$DEV_DIR" -maxdepth 3 -name ".git" -type d 2>/dev/null)

    WORKTREE_COUNT_AFTER=$(find "$WORKTREE_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | wc -l | tr -d ' ')
    TOTAL_WORKTREES_PRUNED=$((WORKTREE_COUNT_BEFORE - WORKTREE_COUNT_AFTER))

    if [[ $TOTAL_WORKTREES_PRUNED -gt 0 ]]; then
        log "Pruned $TOTAL_WORKTREES_PRUNED orphaned worktrees"
    else
        log "No orphaned worktrees to prune"
    fi
else
    log "Worktree directory not found at $WORKTREE_DIR"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
# GENERATE REPORT
# ═══════════════════════════════════════════════════════════════

log "Generating report..."

cat > "$REPORT_FILE" << EOF
# Weekly Git Hygiene Report
**Date:** $(date '+%A, %B %d, %Y')
**Completed:** $(date '+%H:%M %Z')

## Summary

| Metric | Count |
|--------|-------|
| Repositories processed | $REPOS_PROCESSED |
| Local branches deleted | $TOTAL_LOCAL_DELETED |
| Remote branches deleted | $TOTAL_REMOTE_DELETED |
| Worktrees pruned | $TOTAL_WORKTREES_PRUNED |

## Stale Branches (> 30 days, unmerged)

These branches haven't had commits in over 30 days and are NOT merged to main.
Review and either complete or abandon them.

$(if [[ -n "$STALE_BRANCHES" ]]; then echo -e "$STALE_BRANCHES"; else echo "No stale branches found."; fi)

## Log Location
\`$LOG_FILE\`

---
*Generated by git-hygiene.sh*
EOF

log "========================================"
log "Git Hygiene Complete"
log "Finished: $(date)"
log "Report: $REPORT_FILE"
log "========================================"

# Optional: Send notification
if command -v terminal-notifier &> /dev/null; then
    terminal-notifier -title "Git Hygiene" \
        -message "Deleted $TOTAL_LOCAL_DELETED local, $TOTAL_REMOTE_DELETED remote branches" \
        -sound default
fi

exit 0
