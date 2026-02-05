#!/bin/bash
# milo-sync.sh - Push Automation Findings to MILO
# Can be run manually or triggered by other scripts
# Logs: ~/Library/Logs/claude-automation/milo-sync/
#
# This script:
# 1. Reads findings from 70% detector
# 2. Reads stale PRs from evening kickoff
# 3. Creates MILO tasks for actionable items
# 4. Avoids duplicates by checking existing tasks

set -euo pipefail

# Configuration
LOGS_BASE="$HOME/Library/Logs/claude-automation"
LOGS_DIR="$LOGS_BASE/milo-sync"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOGS_DIR/sync-$DATE.log"
MILO_DB="$HOME/.milo/milo.db"

# Create directories
mkdir -p "$LOGS_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "MILO Sync - Push Automation Findings"
log "Date: $DATE"
log "========================================"
echo ""

# Check if MILO database exists
if [[ ! -f "$MILO_DB" ]]; then
    log "ERROR: MILO database not found at $MILO_DB"
    log "Make sure MILO has been run at least once to create the database."
    exit 1
fi

TASKS_CREATED=0
TASKS_SKIPPED=0

# Function to create task in MILO
create_milo_task() {
    local title="$1"
    local description="$2"
    local priority="${3:-3}"  # Default priority 3
    
    # Check if task already exists (by title)
    EXISTING=$(sqlite3 "$MILO_DB" "SELECT COUNT(*) FROM tasks WHERE title = '$title' AND status != 'done';" 2>/dev/null || echo "0")
    
    if [[ "$EXISTING" -gt 0 ]]; then
        log "  SKIP (exists): $title"
        TASKS_SKIPPED=$((TASKS_SKIPPED + 1))
        return
    fi
    
    # Generate UUID
    UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Insert task
    sqlite3 "$MILO_DB" "
        INSERT INTO tasks (id, title, description, status, priority, created_at, updated_at, days_worked)
        VALUES ('$UUID', '$title', '$description', 'todo', $priority, '$TIMESTAMP', '$TIMESTAMP', 0);
    " 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        log "  CREATED: $title (priority $priority)"
        TASKS_CREATED=$((TASKS_CREATED + 1))
    else
        log "  FAILED: $title"
    fi
}

# ===================================================================
# STEP 1: Process 70% Detector Findings
# ===================================================================

log "Step 1: Processing 70% detector findings..."

SEVENTY_REPORT="$LOGS_BASE/seventy-percent-detector/report-$DATE.md"

if [[ -f "$SEVENTY_REPORT" ]]; then
    # Extract priority items (lines starting with "- ABANDON OR FINISH:" etc.)
    while IFS= read -r line; do
        # Clean up the line
        CLEAN_LINE=$(echo "$line" | sed 's/^- //' | sed 's/\*\*//g')
        
        if [[ "$line" == *"ABANDON OR FINISH"* ]]; then
            TITLE="70%: $CLEAN_LINE"
            create_milo_task "$TITLE" "From 70% detector: Branch needs to be finished or abandoned" 2
        elif [[ "$line" == *"MERGE OR CLOSE"* ]]; then
            TITLE="70%: $CLEAN_LINE"
            create_milo_task "$TITLE" "From 70% detector: PR needs attention" 2
        elif [[ "$line" == *"ADVANCE PIPELINE"* ]]; then
            TITLE="70%: $CLEAN_LINE"
            create_milo_task "$TITLE" "From 70% detector: Pipeline stage stuck" 1
        fi
    done < <(grep "^- " "$SEVENTY_REPORT" | head -20)
else
    log "  No 70% detector report for today"
fi

echo ""

# ===================================================================
# STEP 2: Process Security Findings
# ===================================================================

log "Step 2: Processing security findings..."

SECURITY_REPORT=$(ls -t "$LOGS_BASE/dependency-guardian/report-"*.md 2>/dev/null | head -1)

if [[ -n "$SECURITY_REPORT" ]] && [[ -f "$SECURITY_REPORT" ]]; then
    URGENCY=$(grep "Urgency Level" "$SECURITY_REPORT" | cut -d: -f2 | tr -d ' ')
    
    if [[ "$URGENCY" == "CRITICAL" ]]; then
        create_milo_task "SECURITY: Critical vulnerabilities found" "Run npm audit fix - critical security issues detected by dependency guardian" 1
    elif [[ "$URGENCY" == "HIGH" ]]; then
        create_milo_task "SECURITY: High severity vulnerabilities" "Review and fix high severity npm audit findings this week" 2
    fi
else
    log "  No security report found"
fi

echo ""

# ===================================================================
# STEP 3: Marketing reminder (if streak broken)
# ===================================================================

log "Step 3: Checking marketing accountability..."

MARKETING_STREAK_FILE="$LOGS_BASE/marketing-check/.marketing-streak"

if [[ -f "$MARKETING_STREAK_FILE" ]]; then
    STREAK_DATA=$(cat "$MARKETING_STREAK_FILE")
    LAST_DATE=$(echo "$STREAK_DATA" | cut -d: -f2)
    YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
    
    if [[ "$LAST_DATE" != "$YESTERDAY" ]] && [[ "$LAST_DATE" != "$DATE" ]]; then
        create_milo_task "MARKETING: Rebuild your streak" "Marketing streak broken - do ONE marketing task today to restart" 2
    fi
fi

echo ""

# ===================================================================
# STEP 4: Add morning commitment if not done
# ===================================================================

log "Step 4: Checking morning commitment..."

COMMITMENT_FILE="$LOGS_BASE/morning-commitment/.commitments.json"

if [[ -f "$COMMITMENT_FILE" ]]; then
    TODAY_COMMITMENT=$(jq -r ".[\"$DATE\"].commitment // \"none\"" "$COMMITMENT_FILE")
    
    if [[ "$TODAY_COMMITMENT" == "none" ]]; then
        create_milo_task "Morning: Set your ONE thing" "No commitment made today - run morning-commitment.sh --commit \"Your task\"" 1
    fi
fi

echo ""

# ===================================================================
# SUMMARY
# ===================================================================

log "========================================"
log "MILO Sync Complete"
log "Tasks created: $TASKS_CREATED"
log "Tasks skipped (already exist): $TASKS_SKIPPED"
log "========================================"

# Notification
if command -v terminal-notifier &> /dev/null; then
    if [[ $TASKS_CREATED -gt 0 ]]; then
        terminal-notifier -title "MILO Sync Complete" \
            -message "$TASKS_CREATED new tasks added to MILO" \
            -sound default
    fi
fi

exit 0
