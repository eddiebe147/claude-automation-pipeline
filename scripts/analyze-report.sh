#!/bin/bash
# Phase 1: Morning LLM Analysis
# Runs: 6 AM daily via launchd
# Input: ~/Development/reports/nightly-YYYY-MM-DD.json
# Output: ~/Development/reports/analysis-YYYY-MM-DD.json
#
# This script:
# 1. Reads the nightly health report
# 2. Calls Claude API for intelligent analysis
# 3. Categorizes issues: critical, high-priority, maintenance
# 4. Identifies pipeline blockers and decision gates
# 5. Surfaces agent parity gaps
# 6. Generates actionable recommendations

set -e

DEV_DIR="$HOME/Development"
REPORTS_DIR="$DEV_DIR/reports"
DATE=$(date +%Y-%m-%d)
NIGHTLY_FILE="$REPORTS_DIR/nightly-$DATE.json"
ANALYSIS_FILE="$REPORTS_DIR/analysis-$DATE.json"

# Get API key from environment or config files
CLAUDE_API_KEY="${CLAUDE_API_KEY:-${ANTHROPIC_API_KEY:-}}"
if [[ -z "$CLAUDE_API_KEY" ]]; then
    # Try clawdbot auth-profiles first (most reliable)
    clawdbot_auth="$HOME/.clawdbot/agents/main/agent/auth-profiles.json"
    if [[ -f "$clawdbot_auth" ]] && command -v jq &> /dev/null; then
        CLAUDE_API_KEY=$(jq -r '.profiles["anthropic:default"].key // empty' "$clawdbot_auth" 2>/dev/null)
    fi
fi
if [[ -z "$CLAUDE_API_KEY" ]]; then
    # Try Claude settings files as fallback
    for settings_file in "$HOME/.claude/settings.json" "$HOME/Development/id8/tools/claude-settings/settings.json"; do
        if [[ -f "$settings_file" ]] && command -v jq &> /dev/null; then
            CLAUDE_API_KEY=$(jq -r '.api_key // empty' "$settings_file" 2>/dev/null)
            [[ -n "$CLAUDE_API_KEY" ]] && break
        fi
    done
fi

if [[ -z "$CLAUDE_API_KEY" ]]; then
    echo "✗ Error: CLAUDE_API_KEY not set"
    echo "  Set: export CLAUDE_API_KEY='sk-...'"
    echo "  Or add to ~/.claude/settings.json: {\"api_key\": \"sk-...\"}"
    exit 1
fi

# Check if nightly report exists
if [[ ! -f "$NIGHTLY_FILE" ]]; then
    echo "✗ Error: Nightly report not found: $NIGHTLY_FILE"
    echo "  Run: ~/Development/scripts/collect-product-health.sh"
    exit 1
fi

# Read the nightly report
nightly_content=$(cat "$NIGHTLY_FILE")

echo "Analyzing report with Claude..."

# Prepare analysis prompt (system instructions only, health report read separately)
system_prompt="You are analyzing a development portfolio health report. Your job is to:

1. CATEGORIZE ISSUES by severity and type
2. IDENTIFY pipeline blockers (Stage 1-4 blockers are critical)
3. FLAG decision gates (architecture, data migration, external integration)
4. SURFACE quick wins (low-risk, high-impact fixes)
5. ASSESS agent parity gaps

Respond with valid JSON (no markdown, no code blocks). Include these fields:
- analysis_timestamp
- summary
- critical_issues (array)
- high_priority (array with id, type, project, description)
- quick_wins (array of objects with id, project, description, estimated_effort, risk)
- agent_parity_gaps (array)
- decision_gates (array)
- recommendations (object with immediate, this_week, next_week arrays)"

# Build JSON payload safely using jq with proper escaping
# This prevents command injection by letting jq handle the file content
payload=$(jq -n \
  --arg model "claude-opus-4-5-20251101" \
  --arg system_prompt "$system_prompt" \
  --rawfile health_report "$NIGHTLY_FILE" \
  '{
    model: $model,
    max_tokens: 2000,
    messages: [
      {
        role: "user",
        content: ($system_prompt + "\n\nHealth Report to analyze:\n" + $health_report)
      }
    ]
  }')

# Call Claude API
response=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$payload")

# Extract the analysis from response
if echo "$response" | grep -q '"content"'; then
    analysis=$(echo "$response" | jq -r '.content[0].text' 2>/dev/null || echo "")

    if [[ -z "$analysis" ]]; then
        echo "✗ Error: No analysis returned from Claude"
        echo "Response: $response"
        exit 1
    fi

    # Clean up any markdown formatting
    analysis=$(echo "$analysis" | sed 's/^```json//; s/^```//' | sed '1s/^[^{]*//')

    # Validate JSON
    if echo "$analysis" | jq . > /dev/null 2>&1; then
        echo "$analysis" > "$ANALYSIS_FILE"
        echo "✓ Analysis saved: $ANALYSIS_FILE"
    else
        echo "✗ Error: Claude response is not valid JSON"
        echo "Response: $analysis"
        exit 1
    fi
else
    echo "✗ Error: API request failed"
    echo "Response: $response"
    exit 1
fi

exit 0
