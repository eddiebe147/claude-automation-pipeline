#!/bin/bash
# Phase 2: Morning Report Generation
# Runs: 7 AM daily via launchd
# Input: ~/Development/reports/analysis-YYYY-MM-DD.json
# Output: ~/Development/reports/morning-YYYY-MM-DD.md
#
# This script creates a beautiful, actionable morning report:
# - Executive summary with key metrics
# - Prioritized task list with dev-execute commands
# - Pipeline status matrix
# - Decision gates requiring human approval
# - Recommendations grouped by timeframe

set -e

DEV_DIR="$HOME/Development"
ID8_DIR="$DEV_DIR/id8"
REPORTS_DIR="$DEV_DIR/reports"
DATE=$(date +%Y-%m-%d)
ANALYSIS_FILE="$REPORTS_DIR/analysis-$DATE.json"
MORNING_REPORT="$REPORTS_DIR/morning-$DATE.md"

# Check if analysis file exists
if [[ ! -f "$ANALYSIS_FILE" ]]; then
    echo "✗ Error: Analysis report not found: $ANALYSIS_FILE"
    echo "  Run: ~/Development/scripts/analyze-report.sh"
    exit 1
fi

# Parse analysis file
analysis=$(cat "$ANALYSIS_FILE")

# Initialize report
cat > "$MORNING_REPORT" << 'EOF'
# Morning Development Report
EOF

echo "# Morning Development Report" > "$MORNING_REPORT"
echo "**Date:** $(date '+%A, %B %d, %Y')" >> "$MORNING_REPORT"
echo "**Generated:** $(date '+%H:%M %Z')" >> "$MORNING_REPORT"
echo "" >> "$MORNING_REPORT"

# ═══════════════════════════════════════════════════════════════
# 1. EXECUTIVE SUMMARY
# ═══════════════════════════════════════════════════════════════

cat >> "$MORNING_REPORT" << 'EOF'
## Executive Summary

EOF

# Extract summary from analysis
if command -v jq &> /dev/null; then
    summary=$(echo "$analysis" | jq -r '.summary // "Health check complete"' 2>/dev/null)
    echo "$summary" >> "$MORNING_REPORT"
    echo "" >> "$MORNING_REPORT"
fi

# ═══════════════════════════════════════════════════════════════
# 2. CRITICAL ISSUES (Stop and Decide)
# ═══════════════════════════════════════════════════════════════

cat >> "$MORNING_REPORT" << 'EOF'

## 🚨 Major Decisions (Need Your Strategic Input)

EOF

if command -v jq &> /dev/null; then
    critical_count=$(echo "$analysis" | jq '.critical_issues | length' 2>/dev/null || echo "0")

    if [[ "$critical_count" -gt 0 ]]; then
        decision_gates=$(echo "$analysis" | jq -r '.decision_gates[]? | "**decision-\(.id)**: \(.project) - \(.question)\n  Options: \(.options | join(", "))"' 2>/dev/null)
        if [[ -n "$decision_gates" ]]; then
            echo "$decision_gates" >> "$MORNING_REPORT"
        else
            echo "_No major decisions needed today_" >> "$MORNING_REPORT"
        fi
    else
        echo "_No major decisions needed today_" >> "$MORNING_REPORT"
    fi
fi

echo "" >> "$MORNING_REPORT"

# ═══════════════════════════════════════════════════════════════
# 3. EXECUTABLE TASKS
# ═══════════════════════════════════════════════════════════════

cat >> "$MORNING_REPORT" << 'EOF'

## ⚡ Executable Tasks

### Quick Wins (Low Risk, High Impact)

EOF

if command -v jq &> /dev/null; then
    quick_wins=$(echo "$analysis" | jq -r '.quick_wins[]? | "**\(.id)**: \(.description)\n  → Run: `dev-execute \(.id)`\n  → Effort: \(.estimated_effort) | Risk: \(.risk)\n"' 2>/dev/null)
    if [[ -n "$quick_wins" ]]; then
        echo "$quick_wins" >> "$MORNING_REPORT"
    else
        echo "_None identified today_" >> "$MORNING_REPORT"
    fi
fi

echo "" >> "$MORNING_REPORT"

cat >> "$MORNING_REPORT" << 'EOF'

### High Priority (Requires Implementation)

EOF

if command -v jq &> /dev/null; then
    high_priority=$(echo "$analysis" | jq -r '.high_priority[]? | "**\(.id)**: [\(.type)] \(.project)\n  \(.description)\n  → Run: `dev-execute \(.id)`\n"' 2>/dev/null)
    if [[ -n "$high_priority" ]]; then
        echo "$high_priority" >> "$MORNING_REPORT"
    else
        echo "_None pending_" >> "$MORNING_REPORT"
    fi
fi

echo "" >> "$MORNING_REPORT"

# ═══════════════════════════════════════════════════════════════
# 4. PIPELINE STATUS MATRIX
# ═══════════════════════════════════════════════════════════════

cat >> "$MORNING_REPORT" << 'EOF'

## 📊 Pipeline Status

| Project | Stage | Status | Next Action |
|---------|-------|--------|-------------|
EOF

# Scan products for PIPELINE_STATUS.md
for product_dir in "$ID8_DIR/products"/*; do
    if [[ -d "$product_dir" ]]; then
        project=$(basename "$product_dir")
        pipeline_file="$product_dir/PIPELINE_STATUS.md"

        if [[ -f "$pipeline_file" ]]; then
            # Extract stage
            stage=$(grep "## Current Stage:" "$pipeline_file" | sed 's/.*Stage \([0-9]*\).*/Stage \1/' | head -1 || echo "Unknown")

            # Check status
            uncommitted=$(git -C "$product_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$uncommitted" -gt 0 ]]; then
                status="$uncommitted changes"
            else
                status="Clean"
            fi

            # Next checkpoint question
            next=$(grep "## Checkpoint:" "$pipeline_file" | head -1 | sed 's/.*Checkpoint: //' || echo "N/A")

            echo "| $project | $stage | $status | $next |" >> "$MORNING_REPORT"
        fi
    fi
done

echo "" >> "$MORNING_REPORT"

# ═══════════════════════════════════════════════════════════════
# 5. GIT HEALTH SNAPSHOT
# ═══════════════════════════════════════════════════════════════

cat >> "$MORNING_REPORT" << 'EOF'

## 🔧 Git Health Snapshot

EOF

# Quick stats
uncommitted=0
unpushed=0
stale=0

for product_dir in "$ID8_DIR/products"/* "$ID8_DIR/tools"/*; do
    if [[ -d "$product_dir/.git" ]]; then
        uncommitted_count=$(git -C "$product_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        unpushed_count=$(git -C "$product_dir" log @{u}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')

        ((uncommitted += uncommitted_count))
        ((unpushed += unpushed_count))
    fi
done

stale=$(find "$ID8_DIR/products" -maxdepth 1 -type d -exec sh -c 'git -C "$1" log -1 --format=%ct 2>/dev/null || echo 0' _ {} \; | awk -v days_ago=$(date -v-30d +%s 2>/dev/null || date -d "30 days ago" +%s) '{if ($1 < days_ago && $1 > 0) count++} END {print count+0}' 2>/dev/null || echo 0)

cat >> "$MORNING_REPORT" << EOF

- **Uncommitted files across all projects:** $uncommitted
- **Unpushed commits:** $unpushed
- **Stale projects (30+ days inactive):** $stale

EOF

# ═══════════════════════════════════════════════════════════════
# 6. AGENT PARITY AUDIT
# ═══════════════════════════════════════════════════════════════

cat >> "$MORNING_REPORT" << 'EOF'

## 🤖 Agent Parity Status

EOF

if command -v jq &> /dev/null; then
    parity_gaps=$(echo "$analysis" | jq -r '.agent_parity_gaps[]? | "- **\(.project)**: \(.gap_count) gaps\n  \(.recommendation)"' 2>/dev/null)
    if [[ -n "$parity_gaps" ]]; then
        echo "$parity_gaps" >> "$MORNING_REPORT"
    else
        echo "_All projects at good parity_" >> "$MORNING_REPORT"
    fi
fi

echo "" >> "$MORNING_REPORT"

# ═══════════════════════════════════════════════════════════════
# 7. RECOMMENDATIONS
# ═══════════════════════════════════════════════════════════════

cat >> "$MORNING_REPORT" << 'EOF'

## 💡 Recommendations

EOF

if command -v jq &> /dev/null; then
    immediate=$(echo "$analysis" | jq -r '.recommendations.immediate[]?' 2>/dev/null)
    if [[ -n "$immediate" ]]; then
        cat >> "$MORNING_REPORT" << 'EOF'

### Today
EOF
        while IFS= read -r item; do
            echo "- $item" >> "$MORNING_REPORT"
        done <<< "$immediate"
    fi

    this_week=$(echo "$analysis" | jq -r '.recommendations.this_week[]?' 2>/dev/null)
    if [[ -n "$this_week" ]]; then
        cat >> "$MORNING_REPORT" << 'EOF'

### This Week
EOF
        while IFS= read -r item; do
            echo "- $item" >> "$MORNING_REPORT"
        done <<< "$this_week"
    fi
fi

echo "" >> "$MORNING_REPORT"

# ═══════════════════════════════════════════════════════════════
# 8. FOOTER
# ═══════════════════════════════════════════════════════════════

cat >> "$MORNING_REPORT" << 'EOF'

---

## How to Proceed

1. **Review decisions above** - Mark approved decisions in this report
2. **Run tasks** - Execute with: `dev-execute <task-id>`
3. **Track progress** - System logs outcomes automatically

_Generated by ~/Development/scripts/generate-morning-report.sh_
EOF

echo "✓ Morning report saved: $MORNING_REPORT"

# Keep only last 30 days of reports
find "$REPORTS_DIR" -name "morning-*.md" -type f -mtime +30 -delete 2>/dev/null || true

# Open the report in MacDown (lightweight markdown viewer)
if [[ -d "/Applications/MacDown.app" ]]; then
    open -a "MacDown" "$MORNING_REPORT"
elif command -v open &> /dev/null; then
    # Fallback to default if MacDown not installed
    open "$MORNING_REPORT"
fi

exit 0
