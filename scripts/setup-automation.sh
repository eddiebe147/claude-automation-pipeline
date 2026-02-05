#!/bin/bash
# Setup Development Automation Pipeline
#
# This script configures launchd agents for:
# - 3 AM: Nightly health collection
# - 6 AM: LLM analysis
# - 7 AM: Morning report generation
#
# Usage: bash ~/Development/scripts/setup-automation.sh [--enable|--disable|--status]

set -e

CONFIG_DIR="$HOME/Development/config"
LAUNCH_DIR="$HOME/Library/LaunchAgents"

ENABLE="${1:-status}"

# Launchd agents
AGENTS=(
    "com.eddieb.dev-health-collection"
    "com.eddieb.dev-health-analysis"
    "com.eddieb.dev-health-morning-report"
)

case "$ENABLE" in
    --enable)
        echo "Installing launchd agents..."
        mkdir -p "$LAUNCH_DIR"

        for agent in "${AGENTS[@]}"; do
            plist="$CONFIG_DIR/$agent.plist"
            if [[ -f "$plist" ]]; then
                cp "$plist" "$LAUNCH_DIR/"
                launchctl load "$LAUNCH_DIR/$agent.plist" 2>/dev/null || true
                echo "✓ Loaded: $agent"
            else
                echo "✗ Not found: $plist"
            fi
        done

        echo ""
        echo "Automation enabled! Daily schedule:"
        echo "  3:00 AM - Collect product health"
        echo "  6:00 AM - Analyze with Claude"
        echo "  7:00 AM - Generate morning report"
        ;;

    --disable)
        echo "Uninstalling launchd agents..."

        for agent in "${AGENTS[@]}"; do
            launchctl unload "$LAUNCH_DIR/$agent.plist" 2>/dev/null || true
            rm -f "$LAUNCH_DIR/$agent.plist"
            echo "✓ Removed: $agent"
        done

        echo "Automation disabled"
        ;;

    --status)
        echo "Automation Status:"
        echo ""

        for agent in "${AGENTS[@]}"; do
            if launchctl list | grep -q "$agent"; then
                echo "✓ $agent - LOADED"
            else
                echo "✗ $agent - NOT LOADED"
            fi
        done

        echo ""
        echo "To enable: bash ~/Development/scripts/setup-automation.sh --enable"
        echo "To disable: bash ~/Development/scripts/setup-automation.sh --disable"
        ;;

    *)
        echo "Usage: bash ~/Development/scripts/setup-automation.sh [--enable|--disable|--status]"
        exit 1
        ;;
esac

exit 0
