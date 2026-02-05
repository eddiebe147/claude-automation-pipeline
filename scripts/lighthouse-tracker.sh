#!/bin/bash
# lighthouse-tracker.sh - Track Performance Across Web Projects
# Runs: Sunday 5 AM via launchd
# Logs: ~/Library/Logs/claude-automation/lighthouse-tracker/
#
# This script:
# 1. Runs Lighthouse CI on known web projects
# 2. Compares to previous week's scores
# 3. Flags regressions > 5 points
# 4. Tracks Core Web Vitals trends
# 5. Generates weekly performance report

set -euo pipefail

# Configuration
LOGS_DIR="$HOME/Library/Logs/claude-automation/lighthouse-tracker"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOGS_DIR/tracker-$DATE.log"
REPORT_FILE="$LOGS_DIR/report-$DATE.md"
SCORES_FILE="$LOGS_DIR/.scores-history.json"

# URLs to test (add your production URLs)
declare -A URLS=(
    ["Homer"]="https://homer.id8labs.com"
    ["X-Place"]="https://x-place.id8labs.com"
    ["id8labs"]="https://id8labs.com"
)

# Create directories
mkdir -p "$LOGS_DIR"

# Initialize scores history if needed
if [[ ! -f "$SCORES_FILE" ]]; then
    echo '{}' > "$SCORES_FILE"
fi

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================"
log "Lighthouse Performance Tracker"
log "Date: $DATE"
log "========================================"
echo ""

# Check for lighthouse CLI
if ! command -v lighthouse &> /dev/null; then
    log "Installing Lighthouse CLI..."
    npm install -g lighthouse 2>/dev/null || {
        log "ERROR: Could not install Lighthouse. Install with: npm install -g lighthouse"
        exit 1
    }
fi

# Initialize results
RESULTS=""
REGRESSIONS=""
IMPROVEMENTS=""

# ===================================================================
# STEP 1: Run Lighthouse for each URL
# ===================================================================

log "Step 1: Running Lighthouse audits..."

for project in "${!URLS[@]}"; do
    url="${URLS[$project]}"
    log "  Testing $project ($url)..."
    
    # Run lighthouse in headless mode
    OUTPUT_FILE="$LOGS_DIR/${project,,}-$DATE.json"
    
    # Run lighthouse (skip if URL is unreachable)
    if curl -s --head "$url" | head -1 | grep -q "200\|301\|302"; then
        lighthouse "$url" \
            --output=json \
            --output-path="$OUTPUT_FILE" \
            --chrome-flags="--headless --no-sandbox" \
            --only-categories=performance,accessibility,best-practices,seo \
            --quiet 2>/dev/null || {
            log "    WARNING: Lighthouse failed for $project"
            continue
        }
        
        # Extract scores
        PERF=$(jq '.categories.performance.score * 100 | floor' "$OUTPUT_FILE" 2>/dev/null || echo "0")
        A11Y=$(jq '.categories.accessibility.score * 100 | floor' "$OUTPUT_FILE" 2>/dev/null || echo "0")
        BP=$(jq '.categories["best-practices"].score * 100 | floor' "$OUTPUT_FILE" 2>/dev/null || echo "0")
        SEO=$(jq '.categories.seo.score * 100 | floor' "$OUTPUT_FILE" 2>/dev/null || echo "0")
        
        # Extract Core Web Vitals
        FCP=$(jq '.audits["first-contentful-paint"].numericValue | floor' "$OUTPUT_FILE" 2>/dev/null || echo "0")
        LCP=$(jq '.audits["largest-contentful-paint"].numericValue | floor' "$OUTPUT_FILE" 2>/dev/null || echo "0")
        CLS=$(jq '.audits["cumulative-layout-shift"].numericValue * 1000 | floor' "$OUTPUT_FILE" 2>/dev/null || echo "0")
        
        log "    Performance: $PERF | A11y: $A11Y | BP: $BP | SEO: $SEO"
        
        # Get previous scores
        PREV_PERF=$(jq -r ".[\"$project\"].performance // 0" "$SCORES_FILE")
        
        # Check for regressions (> 5 points drop)
        if [[ $PERF -lt $((PREV_PERF - 5)) ]]; then
            REGRESSIONS+="- **$project**: Performance dropped from $PREV_PERF to $PERF (-$((PREV_PERF - PERF)) points)\n"
        elif [[ $PERF -gt $((PREV_PERF + 5)) ]]; then
            IMPROVEMENTS+="- **$project**: Performance improved from $PREV_PERF to $PERF (+$((PERF - PREV_PERF)) points)\n"
        fi
        
        # Store current scores
        RESULTS+="### $project\n"
        RESULTS+="| Metric | Score |\n|--------|-------|\n"
        RESULTS+="| Performance | $PERF |\n"
        RESULTS+="| Accessibility | $A11Y |\n"
        RESULTS+="| Best Practices | $BP |\n"
        RESULTS+="| SEO | $SEO |\n\n"
        RESULTS+="**Core Web Vitals:**\n"
        RESULTS+="- FCP: ${FCP}ms\n"
        RESULTS+="- LCP: ${LCP}ms\n"
        RESULTS+="- CLS: 0.$CLS\n\n"
        
        # Update scores file
        jq ".[\"$project\"] = {\"performance\": $PERF, \"accessibility\": $A11Y, \"bestPractices\": $BP, \"seo\": $SEO, \"date\": \"$DATE\"}" "$SCORES_FILE" > "$SCORES_FILE.tmp" && mv "$SCORES_FILE.tmp" "$SCORES_FILE"
        
        # Cleanup large JSON output
        rm -f "$OUTPUT_FILE"
        
    else
        log "    SKIPPED: $url is not reachable"
        RESULTS+="### $project\n*URL not reachable*\n\n"
    fi
done

echo ""

# ===================================================================
# GENERATE REPORT
# ===================================================================

log "Step 2: Generating report..."

cat > "$REPORT_FILE" << EOF
# Weekly Lighthouse Performance Report
**Week of:** $DATE

---

## Summary

$(if [[ -n "$REGRESSIONS" ]]; then echo "### Regressions (Action Required)"; echo -e "$REGRESSIONS"; else echo "No performance regressions this week."; fi)

$(if [[ -n "$IMPROVEMENTS" ]]; then echo "### Improvements"; echo -e "$IMPROVEMENTS"; fi)

---

## Detailed Scores

$(echo -e "$RESULTS")

---

## Recommendations

### Performance Targets
- Performance: 90+ (green)
- Accessibility: 95+ (essential)
- Best Practices: 90+
- SEO: 90+

### Core Web Vitals Thresholds
- FCP: < 1800ms (good)
- LCP: < 2500ms (good)  
- CLS: < 0.1 (good)

---

## Historical Data

See: \`$SCORES_FILE\`

---
*Generated by lighthouse-tracker.sh*
*Performance matters - users leave slow sites*
EOF

log "========================================"
log "Lighthouse Tracker Complete"
log "Report: $REPORT_FILE"
log "========================================"

# Notification
if command -v terminal-notifier &> /dev/null; then
    if [[ -n "$REGRESSIONS" ]]; then
        terminal-notifier -title "Lighthouse: Regressions Found" \
            -message "Performance regressions detected. Check report." \
            -sound Basso
    else
        terminal-notifier -title "Lighthouse Weekly Report" \
            -message "Performance tracking complete. All stable." \
            -sound default
    fi
fi

exit 0
