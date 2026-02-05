#!/bin/bash
# hydra-standup.sh - HYDRA Daily Standup Generator
# Runs: 8:35 AM daily via launchd (after hydra-sync at 8:30)
# Logs: ~/Library/Logs/claude-automation/hydra-standup/
#
# This script:
# 1. Aggregates agent activity from last 24 hours
# 2. Includes automation findings
# 3. Shows task status per agent
# 4. Sends formatted report to Telegram via OpenClaw
# 5. Archives standup in ~/.hydra/logs/standups/

set -euo pipefail

# Configuration
HYDRA_DB="$HOME/.hydra/hydra.db"
LOGS_BASE="$HOME/Library/Logs/claude-automation"
LOGS_DIR="$LOGS_BASE/hydra-standup"
STANDUP_DIR="$HOME/.hydra/logs/standups"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOGS_DIR/standup-$DATE.log"
STANDUP_FILE="$STANDUP_DIR/standup-$DATE.md"
OPENCLAW_GATEWAY="http://localhost:18789"

# Create directories
mkdir -p "$LOGS_DIR" "$STANDUP_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "HYDRA Daily Standup Generator"
log "Date: $DATE"
log "========================================"

# Check database
if [[ ! -f "$HYDRA_DB" ]]; then
    log "ERROR: HYDRA database not found"
    exit 1
fi

# ============================================================================
# GATHER DATA
# ============================================================================

log "Gathering data..."

# Tasks completed today
COMPLETED_TODAY=$(sqlite3 "$HYDRA_DB" "
    SELECT COALESCE(assigned_to, 'unassigned') || ': ' || title
    FROM tasks
    WHERE status = 'completed'
    AND date(completed_at) = date('now')
    ORDER BY completed_at DESC;
" 2>/dev/null || echo "")

# Count non-empty lines
if [[ -z "$COMPLETED_TODAY" ]]; then
    COMPLETED_COUNT=0
else
    COMPLETED_COUNT=$(echo "$COMPLETED_TODAY" | wc -l | tr -d ' ')
fi

# Tasks in progress
IN_PROGRESS=$(sqlite3 "$HYDRA_DB" "
    SELECT COALESCE(assigned_to, 'unassigned') || ': ' || title
    FROM tasks
    WHERE status = 'in_progress'
    ORDER BY priority, updated_at DESC;
" 2>/dev/null || echo "")

if [[ -z "$IN_PROGRESS" ]]; then
    IN_PROGRESS_COUNT=0
else
    IN_PROGRESS_COUNT=$(echo "$IN_PROGRESS" | wc -l | tr -d ' ')
fi

# Blocked tasks
BLOCKED=$(sqlite3 "$HYDRA_DB" "
    SELECT COALESCE(assigned_to, 'unassigned') || ': ' || title ||
           CASE WHEN blocked_reason IS NOT NULL THEN ' (' || blocked_reason || ')' ELSE '' END
    FROM tasks
    WHERE status = 'blocked'
    ORDER BY priority;
" 2>/dev/null || echo "")

if [[ -z "$BLOCKED" ]]; then
    BLOCKED_COUNT=0
else
    BLOCKED_COUNT=$(echo "$BLOCKED" | wc -l | tr -d ' ')
fi

# Pending tasks by agent
PENDING_BY_AGENT=$(sqlite3 "$HYDRA_DB" "
    SELECT COALESCE(assigned_to, 'unassigned') || ': ' || COUNT(*) || ' pending'
    FROM tasks
    WHERE status = 'pending'
    GROUP BY assigned_to
    ORDER BY COUNT(*) DESC;
" 2>/dev/null || echo "")

# Agent workload
WORKLOAD=$(sqlite3 "$HYDRA_DB" "
    SELECT agent_name || ': ' ||
           pending_tasks || 'P/' ||
           in_progress_tasks || 'IP/' ||
           completed_today || 'Done'
    FROM v_agent_workload;
" 2>/dev/null || echo "")

# Pending notifications
NOTIF_COUNT=$(sqlite3 "$HYDRA_DB" "SELECT COUNT(*) FROM notifications WHERE delivered = 0;" 2>/dev/null || echo "0")
URGENT_NOTIF=$(sqlite3 "$HYDRA_DB" "SELECT COUNT(*) FROM notifications WHERE delivered = 0 AND priority = 'urgent';" 2>/dev/null || echo "0")

# Recent activity highlights
ACTIVITY_HIGHLIGHTS=$(sqlite3 "$HYDRA_DB" "
    SELECT COALESCE(agent_id, 'system') || ': ' || description
    FROM activities
    WHERE datetime(created_at) > datetime('now', '-24 hours')
    ORDER BY created_at DESC
    LIMIT 5;
" 2>/dev/null || echo "")

# ============================================================================
# CHECK AUTOMATION REPORTS
# ============================================================================

log "Checking automation reports..."

AUTOMATION_FINDINGS=""

# 70% Detector
SEVENTY_REPORT=$(find "$LOGS_BASE/seventy-percent-detector" -name "report-*.md" -type f 2>/dev/null | sort -r | head -1 || echo "")
if [[ -n "$SEVENTY_REPORT" ]] && [[ -f "$SEVENTY_REPORT" ]]; then
    SEVENTY_ITEMS=$(grep -c "^- " "$SEVENTY_REPORT" 2>/dev/null || echo "0")
    if [[ "$SEVENTY_ITEMS" -gt 0 ]]; then
        AUTOMATION_FINDINGS="${AUTOMATION_FINDINGS}70% Detector: $SEVENTY_ITEMS items need attention\n"
    fi
fi

# Dependency Guardian
SECURITY_REPORT=$(find "$LOGS_BASE/dependency-guardian" -name "report-*.md" -type f 2>/dev/null | sort -r | head -1 || echo "")
if [[ -n "$SECURITY_REPORT" ]] && [[ -f "$SECURITY_REPORT" ]]; then
    URGENCY=$(grep "Urgency Level" "$SECURITY_REPORT" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "")
    if [[ -n "$URGENCY" ]] && [[ "$URGENCY" != "LOW" ]]; then
        AUTOMATION_FINDINGS="${AUTOMATION_FINDINGS}Security: $URGENCY priority vulnerabilities\n"
    fi
fi

# Marketing streak
MARKETING_STREAK_FILE="$LOGS_BASE/marketing-check/.marketing-streak"
if [[ -f "$MARKETING_STREAK_FILE" ]]; then
    STREAK_COUNT=$(cut -d: -f1 "$MARKETING_STREAK_FILE" 2>/dev/null || echo "0")
    AUTOMATION_FINDINGS="${AUTOMATION_FINDINGS}Marketing streak: $STREAK_COUNT days\n"
fi

# Context switch score
CONTEXT_REPORT=$(find "$LOGS_BASE/context-switch" -name "report-*.md" -type f 2>/dev/null | sort -r | head -1 || echo "")
if [[ -n "$CONTEXT_REPORT" ]] && [[ -f "$CONTEXT_REPORT" ]]; then
    FOCUS_SCORE=$(grep "Focus Score" "$CONTEXT_REPORT" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "")
    if [[ -n "$FOCUS_SCORE" ]]; then
        AUTOMATION_FINDINGS="${AUTOMATION_FINDINGS}Focus score: $FOCUS_SCORE%\n"
    fi
fi

# ============================================================================
# GENERATE STANDUP REPORT
# ============================================================================

log "Generating standup report..."

# Format for Telegram (limited markdown)
cat > "$STANDUP_FILE" << EOF
# HYDRA Daily Standup
**Date:** $DATE

---

## Agent Status
$(echo "$WORKLOAD" | while read line; do echo "- $line"; done)

---

## Completed Today ($COMPLETED_COUNT)
$(if [[ -n "$COMPLETED_TODAY" ]]; then
    echo "$COMPLETED_TODAY" | while read line; do echo "- $line"; done
else
    echo "- (none)"
fi)

---

## In Progress ($IN_PROGRESS_COUNT)
$(if [[ -n "$IN_PROGRESS" ]]; then
    echo "$IN_PROGRESS" | while read line; do echo "- $line"; done
else
    echo "- (none)"
fi)

---

## Blocked ($BLOCKED_COUNT)
$(if [[ -n "$BLOCKED" ]]; then
    echo "$BLOCKED" | while read line; do echo "- $line"; done
else
    echo "- (none)"
fi)

---

## Automation Signals
$(if [[ -n "$AUTOMATION_FINDINGS" ]]; then
    echo -e "$AUTOMATION_FINDINGS" | while read line; do [[ -n "$line" ]] && echo "- $line"; done
else
    echo "- All systems nominal"
fi)

---

## Notifications
- Pending: $NOTIF_COUNT (urgent: $URGENT_NOTIF)

---

## Recent Activity
$(if [[ -n "$ACTIVITY_HIGHLIGHTS" ]]; then
    echo "$ACTIVITY_HIGHLIGHTS" | while read line; do echo "- $line"; done
else
    echo "- (no recent activity)"
fi)

---
*Generated by HYDRA at $(date '+%H:%M')*
EOF

log "Standup saved to: $STANDUP_FILE"

# ============================================================================
# STORE IN DATABASE
# ============================================================================

STANDUP_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
PENDING_COUNT=$(sqlite3 "$HYDRA_DB" "SELECT COUNT(*) FROM tasks WHERE status = 'pending';" 2>/dev/null || echo "0")
HIGHLIGHTS_SAFE=$(echo "$ACTIVITY_HIGHLIGHTS" | head -3 | tr '\n' '|' | sed "s/'/''/g")
AUTOMATION_SAFE=$(echo -e "$AUTOMATION_FINDINGS" | tr '\n' '|' | sed "s/'/''/g")

sqlite3 "$HYDRA_DB" "
    INSERT OR REPLACE INTO standups (id, date, agent_id, tasks_completed, tasks_in_progress, tasks_blocked, tasks_pending, highlights, automation_findings, generated_at)
    VALUES ('$STANDUP_ID', '$DATE', NULL,
            $COMPLETED_COUNT, $IN_PROGRESS_COUNT, $BLOCKED_COUNT, $PENDING_COUNT,
            '$HIGHLIGHTS_SAFE', '$AUTOMATION_SAFE', datetime('now'));
" 2>/dev/null || log "Warning: Could not store standup in database"

log "Standup stored in database"

# ============================================================================
# SEND TO TELEGRAM (via OpenClaw)
# ============================================================================

log "Attempting to send to Telegram..."

# Create a compact version for Telegram (character limit)
TELEGRAM_MSG=$(cat << EOF
HYDRA Standup $DATE

Agents: $(echo "$WORKLOAD" | tr '\n' ' ')

Done: $COMPLETED_COUNT | WIP: $IN_PROGRESS_COUNT | Blocked: $BLOCKED_COUNT

$(if [[ "$URGENT_NOTIF" -gt 0 ]]; then echo "URGENT: $URGENT_NOTIF notifications"; fi)
$(if [[ -n "$AUTOMATION_FINDINGS" ]]; then echo -e "\nSignals:\n$AUTOMATION_FINDINGS"; fi)

Full report: ~/.hydra/logs/standups/standup-$DATE.md
EOF
)

# Try to send via OpenClaw (if gateway is running)
# Note: OpenClaw gateway token from environment or config
OPENCLAW_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

if curl -s --connect-timeout 2 "$OPENCLAW_GATEWAY/health" &>/dev/null 2>&1; then
    log "OpenClaw gateway available, attempting send..."
    # For now, just log - actual Telegram integration requires OpenClaw API setup
    log "Standup ready for Telegram (manual send or OpenClaw integration needed)"
else
    log "OpenClaw gateway not available, standup saved to file only"
fi

# macOS notification as fallback
if command -v terminal-notifier &> /dev/null; then
    terminal-notifier -title "HYDRA Daily Standup" \
        -message "Done: $COMPLETED_COUNT | WIP: $IN_PROGRESS_COUNT | Blocked: $BLOCKED_COUNT" \
        -sound default \
        -open "file://$STANDUP_FILE" 2>/dev/null || true
fi

# ============================================================================
# SUMMARY
# ============================================================================

log "========================================"
log "HYDRA Standup Complete"
log "Tasks: $COMPLETED_COUNT done, $IN_PROGRESS_COUNT WIP, $BLOCKED_COUNT blocked"
log "Report: $STANDUP_FILE"
log "========================================"

echo "HYDRA Standup: $COMPLETED_COUNT done | $IN_PROGRESS_COUNT WIP | $BLOCKED_COUNT blocked"
