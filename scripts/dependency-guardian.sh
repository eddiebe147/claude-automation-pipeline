#!/bin/bash
# dependency-guardian.sh - Catch Outdated/Vulnerable Dependencies
# Runs: Monday 6 AM via launchd
# Logs: ~/Library/Logs/claude-automation/dependency-guardian/
#
# This script:
# 1. Runs npm audit on all projects
# 2. Checks for outdated packages (npm outdated)
# 3. Flags security vulnerabilities by severity
# 4. Tracks time since last dependency update
# 5. Generates prioritized update list

set -euo pipefail

# Configuration
LOGS_DIR="$HOME/Library/Logs/claude-automation/dependency-guardian"
DEV_DIR="$HOME/Development"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOGS_DIR/guardian-$DATE.log"
REPORT_FILE="$LOGS_DIR/report-$DATE.md"

# Create directories
mkdir -p "$LOGS_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "Dependency Guardian - Security Audit"
log "Date: $DATE"
log "========================================"
echo ""

# Initialize collections
CRITICAL_VULNS=""
HIGH_VULNS=""
OUTDATED_DEPS=""
PROJECT_SUMMARIES=""
TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_MODERATE=0

# ===================================================================
# STEP 1: Scan all Node.js projects
# ===================================================================

log "Step 1: Scanning for Node.js projects..."

while IFS= read -r package_json; do
    project_dir=$(dirname "$package_json")
    project_name=$(basename "$project_dir")
    
    # Skip node_modules
    if [[ "$project_dir" == *"node_modules"* ]]; then
        continue
    fi
    
    log "  Checking $project_name..."
    cd "$project_dir" 2>/dev/null || continue
    
    # ===================================================================
    # Run npm audit
    # ===================================================================
    
    AUDIT_OUTPUT=$(npm audit --json 2>/dev/null || echo '{"vulnerabilities":{}}')
    
    # Count vulnerabilities by severity
    CRITICAL=$(echo "$AUDIT_OUTPUT" | jq '[.vulnerabilities[].severity] | map(select(. == "critical")) | length' 2>/dev/null || echo "0")
    HIGH=$(echo "$AUDIT_OUTPUT" | jq '[.vulnerabilities[].severity] | map(select(. == "high")) | length' 2>/dev/null || echo "0")
    MODERATE=$(echo "$AUDIT_OUTPUT" | jq '[.vulnerabilities[].severity] | map(select(. == "moderate")) | length' 2>/dev/null || echo "0")
    
    TOTAL_CRITICAL=$((TOTAL_CRITICAL + CRITICAL))
    TOTAL_HIGH=$((TOTAL_HIGH + HIGH))
    TOTAL_MODERATE=$((TOTAL_MODERATE + MODERATE))
    
    if [[ $CRITICAL -gt 0 ]]; then
        CRITICAL_VULNS+="- **$project_name**: $CRITICAL critical vulnerabilities\n"
    fi
    
    if [[ $HIGH -gt 0 ]]; then
        HIGH_VULNS+="- **$project_name**: $HIGH high severity vulnerabilities\n"
    fi
    
    # ===================================================================
    # Check outdated packages
    # ===================================================================
    
    OUTDATED_OUTPUT=$(npm outdated --json 2>/dev/null || echo '{}')
    OUTDATED_COUNT=$(echo "$OUTDATED_OUTPUT" | jq 'length' 2>/dev/null || echo "0")
    
    # Get major version updates (potentially breaking)
    MAJOR_UPDATES=$(echo "$OUTDATED_OUTPUT" | jq -r 'to_entries | map(select(.value.current != .value.latest)) | map(.key + ": " + .value.current + " -> " + .value.latest) | .[:5] | .[]' 2>/dev/null || echo "")
    
    if [[ $OUTDATED_COUNT -gt 0 ]]; then
        OUTDATED_DEPS+="### $project_name ($OUTDATED_COUNT outdated)\n"
        if [[ -n "$MAJOR_UPDATES" ]]; then
            OUTDATED_DEPS+='```\n'"$MAJOR_UPDATES"'\n```\n\n'
        fi
    fi
    
    # ===================================================================
    # Check lock file age
    # ===================================================================
    
    LOCK_AGE=""
    if [[ -f "package-lock.json" ]]; then
        LOCK_MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d" package-lock.json 2>/dev/null || stat --format="%y" package-lock.json 2>/dev/null | cut -d' ' -f1)
        LOCK_AGE="Lock file last updated: $LOCK_MODIFIED"
    fi
    
    # ===================================================================
    # Add to project summary
    # ===================================================================
    
    PROJECT_SUMMARIES+="| $project_name | $CRITICAL | $HIGH | $MODERATE | $OUTDATED_COUNT |\n"
    
    log "    Critical: $CRITICAL | High: $HIGH | Moderate: $MODERATE | Outdated: $OUTDATED_COUNT"
    
done < <(find "$DEV_DIR" -maxdepth 3 -name "package.json" -type f 2>/dev/null)

echo ""

# ===================================================================
# GENERATE REPORT
# ===================================================================

log "Step 2: Generating report..."

# Determine urgency
URGENCY="LOW"
if [[ $TOTAL_CRITICAL -gt 0 ]]; then
    URGENCY="CRITICAL"
elif [[ $TOTAL_HIGH -gt 0 ]]; then
    URGENCY="HIGH"
elif [[ $TOTAL_MODERATE -gt 5 ]]; then
    URGENCY="MODERATE"
fi

cat > "$REPORT_FILE" << EOF
# Dependency Guardian Report
**Date:** $DATE
**Urgency Level:** $URGENCY

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | $TOTAL_CRITICAL |
| High | $TOTAL_HIGH |
| Moderate | $TOTAL_MODERATE |

---

## Critical Vulnerabilities (Fix Immediately)

$(if [[ -n "$CRITICAL_VULNS" ]]; then echo -e "$CRITICAL_VULNS"; else echo "No critical vulnerabilities."; fi)

---

## High Severity (Fix This Week)

$(if [[ -n "$HIGH_VULNS" ]]; then echo -e "$HIGH_VULNS"; else echo "No high severity vulnerabilities."; fi)

---

## Outdated Dependencies

$(if [[ -n "$OUTDATED_DEPS" ]]; then echo -e "$OUTDATED_DEPS"; else echo "All dependencies are up to date."; fi)

---

## Project Summary

| Project | Critical | High | Moderate | Outdated |
|---------|----------|------|----------|----------|
$(echo -e "$PROJECT_SUMMARIES")

---

## Recommended Actions

1. **Critical**: Run \`npm audit fix --force\` or update packages manually
2. **High**: Review and update within the week
3. **Moderate**: Include in next sprint
4. **Outdated**: Review changelogs before updating major versions

### Quick Fix Commands

\`\`\`bash
# Auto-fix what can be fixed safely
npm audit fix

# Force fix (may include breaking changes)
npm audit fix --force

# Update all dependencies to latest (review first!)
npx npm-check-updates -u && npm install
\`\`\`

---
*Generated by dependency-guardian.sh*
*Security is everyone's responsibility*
EOF

log "========================================"
log "Dependency Guardian Complete"
log "Urgency: $URGENCY"
log "Report: $REPORT_FILE"
log "========================================"

# Notification based on urgency
if command -v terminal-notifier &> /dev/null; then
    case "$URGENCY" in
        CRITICAL)
            terminal-notifier -title "CRITICAL: Security Vulnerabilities" \
                -message "$TOTAL_CRITICAL critical vulnerabilities found. Fix immediately!" \
                -sound Basso
            ;;
        HIGH)
            terminal-notifier -title "Security Alert" \
                -message "$TOTAL_HIGH high severity vulnerabilities. Fix this week." \
                -sound Basso
            ;;
        *)
            terminal-notifier -title "Dependency Guardian" \
                -message "Weekly scan complete. No urgent issues." \
                -sound default
            ;;
    esac
fi

exit 0
