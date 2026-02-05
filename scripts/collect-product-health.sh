#!/bin/bash
# Phase 0: Nightly Product Health Collection
# Runs: 3 AM daily via launchd
# Outputs: ~/Development/reports/nightly-YYYY-MM-DD.json
#
# This script gathers comprehensive health data:
# - Git status (uncommitted, unpushed, stale branches)
# - Pipeline status (PIPELINE_STATUS.md from each product)
# - Supabase health (error logs, database stats)
# - Test results (latest CI/CD runs)
# - Agent parity gaps (PARITY_MAP.md audit)

set -e

DEV_DIR="$HOME/Development"
ID8_DIR="$DEV_DIR/id8"
REPORTS_DIR="$DEV_DIR/reports"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)
NIGHTLY_FILE="$REPORTS_DIR/nightly-$DATE.json"

# Ensure directories exist
mkdir -p "$REPORTS_DIR"

# Initialize JSON structure
cat > "$NIGHTLY_FILE" << 'EOF'
{
  "metadata": {},
  "timestamp": "",
  "git": {
    "uncommitted": [],
    "unpushed": [],
    "stale_branches": [],
    "summary": {}
  },
  "pipeline": {
    "products": [],
    "blockers": []
  },
  "supabase": {
    "projects": [],
    "error_summary": {}
  },
  "tests": {
    "failed": [],
    "coverage": {}
  },
  "agent_parity": {
    "gaps": [],
    "crud_audit": []
  },
  "disk_usage": {},
  "recommendations": []
}
EOF

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Update JSON value
update_json() {
    local path="$1"
    local value="$2"
    local file="$3"

    # Use jq to update (gracefully handle if jq not available)
    if command -v jq &> /dev/null; then
        jq "$path = $value" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
}

# Append to JSON array
append_json() {
    local path="$1"
    local value="$2"
    local file="$3"

    if command -v jq &> /dev/null; then
        jq "$path += [$value]" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
}

# ═══════════════════════════════════════════════════════════════
# 1. GIT HEALTH SNAPSHOT
# ═══════════════════════════════════════════════════════════════

echo "Collecting git health..."

uncommitted_count=0
unpushed_count=0
stale_count=0

for product_dir in "$ID8_DIR/products"/* "$ID8_DIR/tools"/*; do
    if [[ -d "$product_dir/.git" ]]; then
        name=$(basename "$product_dir")

        # Check uncommitted changes
        uncommitted=$(git -C "$product_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$uncommitted" -gt 0 ]]; then
            ((uncommitted_count++))
            if command -v jq &> /dev/null; then
                value="{\"project\": \"$name\", \"files\": $uncommitted}"
                append_json ".git.uncommitted" "$value" "$NIGHTLY_FILE"
            fi
        fi

        # Check unpushed commits
        unpushed=$(git -C "$product_dir" log @{u}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$unpushed" -gt 0 ]]; then
            ((unpushed_count++))
            if command -v jq &> /dev/null; then
                value="{\"project\": \"$name\", \"commits\": $unpushed}"
                append_json ".git.unpushed" "$value" "$NIGHTLY_FILE"
            fi
        fi

        # Check for stale branches (30+ days old)
        thirty_days_ago=$(date -v-30d +%s 2>/dev/null || date -d "30 days ago" +%s)
        last_commit=$(git -C "$product_dir" log -1 --format=%ct 2>/dev/null || echo "0")
        if [[ "$last_commit" -lt "$thirty_days_ago" ]]; then
            ((stale_count++))
            days_ago=$(( ($(date +%s) - last_commit) / 86400 ))
            if command -v jq &> /dev/null; then
                value="{\"project\": \"$name\", \"days_inactive\": $days_ago}"
                append_json ".git.stale_branches" "$value" "$NIGHTLY_FILE"
            fi
        fi
    fi
done

# Update summary
if command -v jq &> /dev/null; then
    jq ".git.summary = {\"uncommitted\": $uncommitted_count, \"unpushed\": $unpushed_count, \"stale\": $stale_count}" "$NIGHTLY_FILE" > "$NIGHTLY_FILE.tmp" && mv "$NIGHTLY_FILE.tmp" "$NIGHTLY_FILE"
fi

# ═══════════════════════════════════════════════════════════════
# 2. PIPELINE STATUS
# ═══════════════════════════════════════════════════════════════

echo "Collecting pipeline status..."

for product_dir in "$ID8_DIR/products"/*; do
    if [[ -d "$product_dir" ]]; then
        name=$(basename "$product_dir")
        pipeline_file="$product_dir/PIPELINE_STATUS.md"

        if [[ -f "$pipeline_file" ]]; then
            # Parse PIPELINE_STATUS.md to extract current stage
            stage=$(grep -i "current.*stage" "$pipeline_file" | head -1 | sed 's/.*Stage \([0-9]*\).*/\1/' || echo "unknown")
            blockers=$(grep -i "blocker\|blocked" "$pipeline_file" | head -3)

            if command -v jq &> /dev/null; then
                value="{\"project\": \"$name\", \"stage\": \"$stage\", \"blockers\": $(echo "$blockers" | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null || echo '[]')}"
                append_json ".pipeline.products" "$value" "$NIGHTLY_FILE"
            fi

            # Track high-impact blockers
            if grep -qi "stage 1\|stage 2\|stage 3" <<< "$blockers"; then
                if command -v jq &> /dev/null; then
                    value="{\"project\": \"$name\", \"impact\": \"high\"}"
                    append_json ".pipeline.blockers" "$value" "$NIGHTLY_FILE"
                fi
            fi
        fi
    fi
done

# ═══════════════════════════════════════════════════════════════
# 3. AGENT PARITY AUDIT
# ═══════════════════════════════════════════════════════════════

echo "Auditing agent parity..."

for product_dir in "$ID8_DIR/products"/*; do
    if [[ -d "$product_dir" ]]; then
        name=$(basename "$product_dir")
        parity_file="$product_dir/PARITY_MAP.md"

        if [[ -f "$parity_file" ]]; then
            # Count implemented vs planned
            total=$(grep -c "^-" "$parity_file" || echo 0)
            implemented=$(grep -c "^\- \[x\]" "$parity_file" || echo 0)

            if command -v jq &> /dev/null; then
                value="{\"project\": \"$name\", \"total\": $total, \"implemented\": $implemented, \"gap\": $((total - implemented))}"
                append_json ".agent_parity.crud_audit" "$value" "$NIGHTLY_FILE"
            fi
        fi
    fi
done

# ═══════════════════════════════════════════════════════════════
# 4. DISK USAGE
# ═══════════════════════════════════════════════════════════════

echo "Calculating disk usage..."

dev_size=$(du -sh "$DEV_DIR" 2>/dev/null | cut -f1 || echo "unknown")
id8_size=$(du -sh "$ID8_DIR" 2>/dev/null | cut -f1 || echo "unknown")

# Identify largest projects
if command -v jq &> /dev/null; then
    jq ".disk_usage = {\"total_dev\": \"$dev_size\", \"total_id8\": \"$id8_size\"}" "$NIGHTLY_FILE" > "$NIGHTLY_FILE.tmp" && mv "$NIGHTLY_FILE.tmp" "$NIGHTLY_FILE"
fi

# ═══════════════════════════════════════════════════════════════
# 5. METADATA
# ═══════════════════════════════════════════════════════════════

echo "Finalizing report..."

if command -v jq &> /dev/null; then
    jq ".timestamp = \"$DATE $TIME\"" "$NIGHTLY_FILE" > "$NIGHTLY_FILE.tmp" && mv "$NIGHTLY_FILE.tmp" "$NIGHTLY_FILE"
    jq ".metadata = {\"collection_date\": \"$DATE\", \"collection_time\": \"$TIME\", \"hostname\": \"$(hostname)\"}" "$NIGHTLY_FILE" > "$NIGHTLY_FILE.tmp" && mv "$NIGHTLY_FILE.tmp" "$NIGHTLY_FILE"
fi

echo "✓ Health report saved: $NIGHTLY_FILE"

# Keep only last 30 days of reports
if ! find "$REPORTS_DIR" -name "nightly-*.json" -type f -mtime +30 -delete 2>/dev/null; then
    echo "Warning: Failed to clean old reports (non-critical)" >&2
fi

exit 0
