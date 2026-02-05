#!/bin/bash
# hydra-sync.sh - HYDRA Multi-Agent Task Synchronization
# Runs: 8:30 AM daily via launchd
# Logs: ~/Library/Logs/claude-automation/hydra-sync/
#
# This script:
# 1. Reads findings from all automation jobs
# 2. Creates tasks in hydra.db with smart routing
# 3. Assigns tasks to appropriate agents (FORGE/SCOUT/PULSE)
# 4. Notifies MILO of coordination tasks
# 5. Logs all activity for audit trail

set -euo pipefail

# Configuration
LOGS_BASE="$HOME/Library/Logs/claude-automation"
LOGS_DIR="$LOGS_BASE/hydra-sync"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOGS_DIR/sync-$DATE.log"
HYDRA_DB="$HOME/.hydra/hydra.db"

# Create directories
mkdir -p "$LOGS_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ============================================================================
# DATABASE HELPERS
# ============================================================================

# Check if database exists
check_db() {
    if [[ ! -f "$HYDRA_DB" ]]; then
        log "ERROR: HYDRA database not found at $HYDRA_DB"
        log "Run: sqlite3 ~/.hydra/hydra.db < ~/.hydra/init-db.sql"
        exit 1
    fi
}

# Escape single quotes for SQL
escape_sql() {
    echo "$1" | sed "s/'/''/g"
}

# Generate UUID
gen_uuid() {
    uuidgen | tr '[:upper:]' '[:lower:]'
}

# Route task to appropriate agent based on type
get_agent_for_type() {
    local task_type="$1"
    case "$task_type" in
        dev|code|bug|feature)
            echo "forge"
            ;;
        research|marketing|seo|content|growth)
            echo "scout"
            ;;
        ops|devops|security|infra|automation)
            echo "pulse"
            ;;
        *)
            echo "milo"  # Coordinator handles general tasks
            ;;
    esac
}

# Create task in HYDRA database
# Args: title, description, source_job, task_type, priority
create_hydra_task() {
    local title="$1"
    local description="$2"
    local source_job="$3"
    local task_type="$4"
    local priority="${5:-3}"

    local safe_title=$(escape_sql "$title")
    local safe_desc=$(escape_sql "$description")

    # Check for duplicate (same title, not completed/cancelled)
    local existing=$(sqlite3 "$HYDRA_DB" "SELECT COUNT(*) FROM tasks WHERE title = '$safe_title' AND status NOT IN ('completed', 'cancelled');" 2>/dev/null || echo "0")

    if [[ "$existing" -gt 0 ]]; then
        log "  SKIP (exists): $title"
        TASKS_SKIPPED=$((TASKS_SKIPPED + 1))
        return 1
    fi

    # Determine agent assignment
    local assigned_to=$(get_agent_for_type "$task_type")

    # Generate IDs
    local task_id=$(gen_uuid)
    local activity_id=$(gen_uuid)
    local notification_id=$(gen_uuid)

    # Insert task
    sqlite3 "$HYDRA_DB" "
        INSERT INTO tasks (id, title, description, source, source_job, assigned_to, created_by, status, priority, task_type)
        VALUES ('$task_id', '$safe_title', '$safe_desc', 'automation', '$source_job', '$assigned_to', 'system', 'pending', $priority, '$task_type');
    " 2>/dev/null

    if [[ $? -eq 0 ]]; then
        log "  CREATED: $title -> @$assigned_to (priority $priority)"
        TASKS_CREATED=$((TASKS_CREATED + 1))

        # Log activity
        sqlite3 "$HYDRA_DB" "
            INSERT INTO activities (id, agent_id, activity_type, entity_type, entity_id, description)
            VALUES ('$activity_id', NULL, 'task_created', 'task', '$task_id', 'Auto-created from $source_job');
        " 2>/dev/null

        # Create notification for assigned agent
        sqlite3 "$HYDRA_DB" "
            INSERT INTO notifications (id, target_agent, notification_type, source_type, source_id, priority, content_preview)
            VALUES ('$notification_id', '$assigned_to', 'task_assigned', 'task', '$task_id',
                    CASE WHEN $priority <= 2 THEN 'urgent' ELSE 'normal' END,
                    'New task: $safe_title');
        " 2>/dev/null

        NOTIFICATIONS_CREATED=$((NOTIFICATIONS_CREATED + 1))
        return 0
    else
        log "  FAILED: $title"
        return 1
    fi
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

log "========================================"
log "HYDRA Sync - Multi-Agent Task Distribution"
log "Date: $DATE"
log "========================================"
echo ""

check_db

TASKS_CREATED=0
TASKS_SKIPPED=0
NOTIFICATIONS_CREATED=0

# ============================================================================
# STEP 1: Process 70% Detector Findings -> MILO (coordination)
# ============================================================================

log "Step 1: Processing 70% detector findings..."

SEVENTY_REPORT="$LOGS_BASE/seventy-percent-detector/report-$DATE.md"
# Also check for Sunday reports (weekly job)
if [[ ! -f "$SEVENTY_REPORT" ]]; then
    SEVENTY_REPORT=$(find "$LOGS_BASE/seventy-percent-detector" -name "report-*.md" -type f 2>/dev/null | sort -r | head -1 || echo "")
fi

if [[ -n "$SEVENTY_REPORT" ]] && [[ -f "$SEVENTY_REPORT" ]]; then
    while IFS= read -r line; do
        CLEAN_LINE=$(echo "$line" | sed 's/^- //' | sed 's/\*\*//g')

        if [[ "$line" == *"ABANDON OR FINISH"* ]]; then
            create_hydra_task "70%: $CLEAN_LINE" "From 70% detector: Branch needs to be finished or abandoned" "70%-detector" "general" 2
        elif [[ "$line" == *"MERGE OR CLOSE"* ]]; then
            create_hydra_task "70%: $CLEAN_LINE" "From 70% detector: PR needs attention" "70%-detector" "dev" 2
        elif [[ "$line" == *"ADVANCE PIPELINE"* ]]; then
            create_hydra_task "70%: $CLEAN_LINE" "From 70% detector: Pipeline stage stuck" "70%-detector" "general" 1
        fi
    done < <(grep "^- " "$SEVENTY_REPORT" 2>/dev/null | head -20)
else
    log "  No 70% detector report found"
fi

echo ""

# ============================================================================
# STEP 2: Process Security Findings -> PULSE (ops)
# ============================================================================

log "Step 2: Processing security findings..."

SECURITY_REPORT=$(find "$LOGS_BASE/dependency-guardian" -name "report-*.md" -type f 2>/dev/null | sort -r | head -1 || echo "")

if [[ -n "$SECURITY_REPORT" ]] && [[ -f "$SECURITY_REPORT" ]]; then
    URGENCY=$(grep "Urgency Level" "$SECURITY_REPORT" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "")

    if [[ "$URGENCY" == "CRITICAL" ]]; then
        create_hydra_task "SECURITY: Critical vulnerabilities found" "Run npm audit fix - critical security issues detected by dependency guardian. Report: $SECURITY_REPORT" "dependency-guardian" "security" 1
    elif [[ "$URGENCY" == "HIGH" ]]; then
        create_hydra_task "SECURITY: High severity vulnerabilities" "Review and fix high severity npm audit findings this week. Report: $SECURITY_REPORT" "dependency-guardian" "security" 2
    fi
else
    log "  No security report found"
fi

echo ""

# ============================================================================
# STEP 3: Marketing streak -> SCOUT (marketing)
# ============================================================================

log "Step 3: Checking marketing accountability..."

MARKETING_STREAK_FILE="$LOGS_BASE/marketing-check/.marketing-streak"

if [[ -f "$MARKETING_STREAK_FILE" ]]; then
    STREAK_DATA=$(cat "$MARKETING_STREAK_FILE")
    LAST_DATE=$(echo "$STREAK_DATA" | cut -d: -f2)
    YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)

    if [[ "$LAST_DATE" != "$YESTERDAY" ]] && [[ "$LAST_DATE" != "$DATE" ]]; then
        create_hydra_task "MARKETING: Rebuild your streak" "Marketing streak broken - do ONE marketing task today to restart" "marketing-check" "marketing" 2
    else
        log "  Marketing streak intact"
    fi
else
    log "  No marketing streak file found"
fi

echo ""

# ============================================================================
# STEP 4: Morning commitment -> MILO (coordination)
# ============================================================================

log "Step 4: Checking morning commitment..."

COMMITMENT_FILE="$LOGS_BASE/morning-commitment/.commitments.json"

if [[ -f "$COMMITMENT_FILE" ]]; then
    TODAY_COMMITMENT=$(jq -r ".[\"$DATE\"].commitment // \"none\"" "$COMMITMENT_FILE" 2>/dev/null || echo "none")

    if [[ "$TODAY_COMMITMENT" == "none" ]]; then
        create_hydra_task "Morning: Set your ONE thing" "No commitment made today - run morning-commitment.sh --commit 'Your task'" "morning-commitment" "general" 1
    else
        log "  Commitment set: $TODAY_COMMITMENT"
    fi
else
    log "  No commitment file found"
fi

echo ""

# ============================================================================
# STEP 5: Git hygiene findings -> FORGE (dev)
# ============================================================================

log "Step 5: Checking git hygiene..."

GIT_HYGIENE_REPORT=$(find "$LOGS_BASE/git-hygiene" -name "report-*.md" -type f 2>/dev/null | sort -r | head -1 || echo "")

if [[ -n "$GIT_HYGIENE_REPORT" ]] && [[ -f "$GIT_HYGIENE_REPORT" ]]; then
    # Count stale branches
    STALE_COUNT=$(grep -c "stale branch" "$GIT_HYGIENE_REPORT" 2>/dev/null || echo "0")
    WORKTREE_COUNT=$(grep -c "orphaned worktree" "$GIT_HYGIENE_REPORT" 2>/dev/null || echo "0")

    if [[ "$STALE_COUNT" -gt 5 ]]; then
        create_hydra_task "GIT: $STALE_COUNT stale branches need cleanup" "Run git branch cleanup - $STALE_COUNT branches older than 7 days. Report: $GIT_HYGIENE_REPORT" "git-hygiene" "dev" 3
    fi

    if [[ "$WORKTREE_COUNT" -gt 0 ]]; then
        create_hydra_task "GIT: $WORKTREE_COUNT orphaned worktrees" "Run wt list and cleanup orphaned worktrees. Report: $GIT_HYGIENE_REPORT" "git-hygiene" "ops" 2
    fi
else
    log "  No git hygiene report found"
fi

echo ""

# ============================================================================
# STEP 6: Context switch findings -> MILO (for review)
# ============================================================================

log "Step 6: Checking context switch patterns..."

CONTEXT_REPORT="$LOGS_BASE/context-switch/report-$DATE.md"
# Check yesterday if today's not ready
if [[ ! -f "$CONTEXT_REPORT" ]]; then
    YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
    CONTEXT_REPORT="$LOGS_BASE/context-switch/report-$YESTERDAY.md"
fi

if [[ -f "$CONTEXT_REPORT" ]]; then
    FOCUS_SCORE=$(grep "Focus Score" "$CONTEXT_REPORT" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "100")

    if [[ "$FOCUS_SCORE" -lt 50 ]]; then
        create_hydra_task "FOCUS: Low focus score ($FOCUS_SCORE%) yesterday" "Too much context switching detected. Review and consolidate work. Report: $CONTEXT_REPORT" "context-switch" "general" 2
    else
        log "  Focus score acceptable: $FOCUS_SCORE%"
    fi
else
    log "  No context switch report found"
fi

echo ""

# ============================================================================
# STEP 7: Lighthouse/Performance findings -> FORGE (dev)
# ============================================================================

log "Step 7: Checking performance metrics..."

LIGHTHOUSE_REPORT=$(find "$LOGS_BASE/lighthouse-tracker" -name "report-*.md" -type f 2>/dev/null | sort -r | head -1 || echo "")

if [[ -n "$LIGHTHOUSE_REPORT" ]] && [[ -f "$LIGHTHOUSE_REPORT" ]]; then
    PERF_REGRESSION=$(grep -i "regression" "$LIGHTHOUSE_REPORT" 2>/dev/null | head -1 || echo "")

    if [[ -n "$PERF_REGRESSION" ]]; then
        create_hydra_task "PERF: Performance regression detected" "Lighthouse found performance regression. Investigate and fix. Report: $LIGHTHOUSE_REPORT" "lighthouse-tracker" "dev" 2
    else
        log "  No performance regressions"
    fi
else
    log "  No lighthouse report found"
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

log "========================================"
log "HYDRA Sync Complete"
log "Tasks created: $TASKS_CREATED"
log "Tasks skipped (duplicates): $TASKS_SKIPPED"
log "Notifications queued: $NOTIFICATIONS_CREATED"
log "========================================"

# Show agent workload
echo ""
log "Agent Workload:"
sqlite3 "$HYDRA_DB" -header -column "SELECT * FROM v_agent_workload;"

# Notification
if command -v terminal-notifier &> /dev/null; then
    if [[ $TASKS_CREATED -gt 0 ]]; then
        terminal-notifier -title "HYDRA Sync Complete" \
            -message "$TASKS_CREATED tasks distributed to agents" \
            -sound default
    fi
fi

exit 0
