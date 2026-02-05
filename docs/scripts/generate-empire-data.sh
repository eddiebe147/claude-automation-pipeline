#!/bin/bash
# ============================================================================
# Eddie's Automation Empire - Data Generator
# ============================================================================
# Generates empire-data.json for the subway map dashboard
# Scans git repos, HYDRA DB, and launchd plists
#
# Run: ./generate-empire-data.sh
# Schedule: 6 AM daily via com.hydra.empire-data.plist
# ============================================================================

set -eo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="${OUTPUT_DIR}/empire-data.json"
HYDRA_DB="$HOME/.hydra/hydra.db"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
DEV_DIR="$HOME/Development"

# Calculate freshness score based on last activity
# hot=24h, warm=3d, cool=7d, stale=7d+
calculate_freshness() {
    local last_commit_epoch=$1
    local now_epoch=$(date +%s)
    local age_hours=$(( (now_epoch - last_commit_epoch) / 3600 ))

    if [ $age_hours -lt 24 ]; then
        echo "hot"
    elif [ $age_hours -lt 72 ]; then
        echo "warm"
    elif [ $age_hours -lt 168 ]; then
        echo "cool"
    else
        echo "stale"
    fi
}

# Get git stats for a repo
get_git_stats() {
    local repo_path=$1

    if [ ! -d "$repo_path/.git" ]; then
        echo '{"error": "not a git repo"}'
        return
    fi

    cd "$repo_path"

    # Get last commit info
    local last_commit_hash=$(git log -1 --format="%H" 2>/dev/null || echo "none")
    local last_commit_msg=$(git log -1 --format="%s" 2>/dev/null | head -c 80 | sed 's/"/\\"/g' || echo "")
    local last_commit_date=$(git log -1 --format="%ci" 2>/dev/null || echo "")
    local last_commit_epoch=$(git log -1 --format="%ct" 2>/dev/null || echo "0")
    local last_commit_author=$(git log -1 --format="%an" 2>/dev/null || echo "")

    # Get 7-day commit count
    local commits_7d=$(git rev-list --count --since="7 days ago" HEAD 2>/dev/null || echo "0")

    # Get recent 5 commits for detail panel
    local recent_commits=$(git log -5 --format='{"hash":"%h","message":"%s","author":"%an","date":"%ci"}' 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]")

    # Calculate freshness
    local freshness=$(calculate_freshness "$last_commit_epoch")

    # Get current branch
    local current_branch=$(git branch --show-current 2>/dev/null || echo "main")

    # Count uncommitted changes
    local uncommitted=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    cat <<EOF
{
    "lastCommit": {
        "hash": "$last_commit_hash",
        "message": "$last_commit_msg",
        "date": "$last_commit_date",
        "author": "$last_commit_author"
    },
    "commits7d": $commits_7d,
    "recentCommits": $recent_commits,
    "freshness": "$freshness",
    "branch": "$current_branch",
    "uncommitted": $uncommitted
}
EOF
}

# Get HYDRA agent data
get_hydra_agents() {
    if [ ! -f "$HYDRA_DB" ]; then
        echo '[]'
        return
    fi

    sqlite3 -json "$HYDRA_DB" "
        SELECT
            a.id,
            a.name,
            a.role,
            a.model,
            a.status,
            a.last_heartbeat,
            a.heartbeat_minutes,
            a.cost_tier,
            COALESCE(w.pending_tasks, 0) as pending_tasks,
            COALESCE(w.in_progress_tasks, 0) as in_progress_tasks,
            COALESCE(w.completed_today, 0) as completed_today
        FROM agents a
        LEFT JOIN v_agent_workload w ON a.id = w.agent_id
    " 2>/dev/null || echo '[]'
}

# Get HYDRA task stats
get_hydra_task_stats() {
    if [ ! -f "$HYDRA_DB" ]; then
        echo '{"total":0,"pending":0,"inProgress":0,"completedToday":0}'
        return
    fi

    local total=$(sqlite3 "$HYDRA_DB" "SELECT COUNT(*) FROM tasks" 2>/dev/null || echo "0")
    local pending=$(sqlite3 "$HYDRA_DB" "SELECT COUNT(*) FROM tasks WHERE status='pending'" 2>/dev/null || echo "0")
    local in_progress=$(sqlite3 "$HYDRA_DB" "SELECT COUNT(*) FROM tasks WHERE status='in_progress'" 2>/dev/null || echo "0")
    local completed_today=$(sqlite3 "$HYDRA_DB" "SELECT COUNT(*) FROM tasks WHERE status='completed' AND date(completed_at)=date('now')" 2>/dev/null || echo "0")

    echo "{\"total\":$total,\"pending\":$pending,\"inProgress\":$in_progress,\"completedToday\":$completed_today}"
}

# Get launchd job data grouped by category
get_launchd_jobs() {
    local morning_jobs="[]"
    local health_jobs="[]"
    local hydra_jobs="[]"
    local evening_jobs="[]"
    local other_jobs="[]"

    for plist in "$LAUNCH_AGENTS"/com.id8labs*.plist "$LAUNCH_AGENTS"/com.hydra*.plist "$LAUNCH_AGENTS"/com.eddieb*.plist "$LAUNCH_AGENTS"/com.homer*.plist; do
        [ -f "$plist" ] || continue

        local label=$(basename "$plist" .plist)
        local comment=$(/usr/libexec/PlistBuddy -c "Print :Comment" "$plist" 2>/dev/null | sed 's/"/\\"/g' || echo "")
        local program=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:1" "$plist" 2>/dev/null | sed 's/"/\\"/g' || echo "")
        # Handle both simple and array-based StartCalendarInterval
        local hour_raw=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Hour" "$plist" 2>/dev/null || echo "")
        local minute_raw=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Minute" "$plist" 2>/dev/null || echo "")

        # Extract numeric hour (handle "Dict {" case by taking first occurrence)
        local hour="-1"
        local minute="0"
        if [[ "$hour_raw" =~ ^[0-9]+$ ]]; then
            hour="$hour_raw"
        fi
        if [[ "$minute_raw" =~ ^[0-9]+$ ]]; then
            minute="$minute_raw"
        fi

        # Format schedule time
        local schedule="manual"
        if [ "$hour" != "-1" ]; then
            schedule=$(printf "%02d:%02d" "$hour" "$minute")
        fi

        # Build job entry
        local job_entry="{\"label\":\"$label\",\"comment\":\"$comment\",\"schedule\":\"$schedule\",\"script\":\"$program\"}"

        # Determine category based on label and schedule
        if [[ "$label" == *"hydra"* ]]; then
            hydra_jobs=$(echo "$hydra_jobs" | jq --argjson entry "$job_entry" '. += [$entry]')
        elif [[ "$hour" =~ ^[0-9]+$ ]] && [ "$hour" -ge 5 ] && [ "$hour" -lt 12 ]; then
            morning_jobs=$(echo "$morning_jobs" | jq --argjson entry "$job_entry" '. += [$entry]')
        elif [[ "$hour" =~ ^[0-9]+$ ]] && { [ "$hour" -ge 17 ] || [ "$hour" -lt 5 ]; }; then
            evening_jobs=$(echo "$evening_jobs" | jq --argjson entry "$job_entry" '. += [$entry]')
        elif [[ "$label" == *"health"* ]] || [[ "$label" == *"guardian"* ]] || [[ "$label" == *"tracker"* ]]; then
            health_jobs=$(echo "$health_jobs" | jq --argjson entry "$job_entry" '. += [$entry]')
        else
            other_jobs=$(echo "$other_jobs" | jq --argjson entry "$job_entry" '. += [$entry]')
        fi
    done

    echo "{\"morning\":$morning_jobs,\"health\":$health_jobs,\"hydra\":$hydra_jobs,\"evening\":$evening_jobs,\"other\":$other_jobs}"
}

# Build station data for projects
build_project_stations() {
    local stations="[]"

    # Define repos as simple arrays: name|display_name|description|tech_stack
    local repos=(
        "Homer|Homer|Real Estate Platform|next.js,supabase,typescript"
        "x-place|AIplaces|AI Art Marketplace|next.js,supabase,stripe"
        "pura-vida|Pura Vida|Costa Rica Property|next.js,typescript"
        "id8|ID8Labs|Business Operations|typescript,automation"
        "stitch|Stitch|Content Pipeline|typescript,automation"
    )

    for repo_entry in "${repos[@]}"; do
        IFS='|' read -r repo_name display_name description tech_stack <<< "$repo_entry"
        local repo_path="${DEV_DIR}/${repo_name}"

        if [ -d "$repo_path" ]; then
            local git_stats=$(get_git_stats "$repo_path")
            local freshness=$(echo "$git_stats" | jq -r '.freshness')
            local id=$(echo "$repo_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

            local station=$(jq -n \
                --arg id "$id" \
                --arg name "$display_name" \
                --arg desc "$description" \
                --arg tech "$tech_stack" \
                --arg fresh "$freshness" \
                --argjson git "$git_stats" \
                '{
                    id: $id,
                    name: $name,
                    type: "project",
                    description: $desc,
                    techStack: ($tech | split(",")),
                    freshness: $fresh,
                    git: $git,
                    line: "business"
                }')

            stations=$(echo "$stations" | jq --argjson s "$station" '. += [$s]')
        fi
    done

    echo "$stations"
}

# Build station data for HYDRA agents
build_agent_stations() {
    local agents=$(get_hydra_agents)

    if [ "$agents" = "[]" ]; then
        echo '[]'
        return
    fi

    echo "$agents" | jq '[.[] | {
        id: .id,
        name: .name,
        type: "agent",
        role: .role,
        model: .model,
        status: .status,
        lastHeartbeat: .last_heartbeat,
        pendingTasks: .pending_tasks,
        inProgressTasks: .in_progress_tasks,
        completedToday: .completed_today,
        costTier: .cost_tier,
        freshness: (if .last_heartbeat != null and (.last_heartbeat | length) > 0 then
            (now - (.last_heartbeat | strptime("%Y-%m-%d %H:%M:%S") | mktime) | . / 3600) as $hours |
            if $hours < 1 then "hot"
            elif $hours < 24 then "warm"
            elif $hours < 72 then "cool"
            else "stale" end
        else "stale" end),
        line: "hydra"
    }]'
}

# Build infrastructure stations
build_infra_stations() {
    cat <<'EOF'
[
    {
        "id": "mac-studio",
        "name": "Mac Studio",
        "type": "infrastructure",
        "description": "M2 Max - Primary dev machine",
        "freshness": "hot",
        "line": "infrastructure"
    },
    {
        "id": "claude-code",
        "name": "Claude Code",
        "type": "infrastructure",
        "description": "AI pair programming environment",
        "freshness": "hot",
        "line": "infrastructure"
    },
    {
        "id": "supabase",
        "name": "Supabase",
        "type": "infrastructure",
        "description": "Database & auth platform",
        "freshness": "warm",
        "line": "infrastructure"
    },
    {
        "id": "vercel",
        "name": "Vercel",
        "type": "infrastructure",
        "description": "Frontend deployment platform",
        "freshness": "warm",
        "line": "infrastructure"
    }
]
EOF
}

# Build communication stations
build_comm_stations() {
    cat <<'EOF'
[
    {
        "id": "telegram",
        "name": "Telegram Hub",
        "type": "communication",
        "description": "Two-way HYDRA control",
        "freshness": "hot",
        "line": "communication"
    },
    {
        "id": "twitter",
        "name": "Twitter/X",
        "type": "communication",
        "description": "@eddiebe147",
        "freshness": "warm",
        "line": "communication"
    },
    {
        "id": "linkedin",
        "name": "LinkedIn",
        "type": "communication",
        "description": "Professional network",
        "freshness": "cool",
        "line": "communication"
    },
    {
        "id": "discord",
        "name": "Discord",
        "type": "communication",
        "description": "Community channels",
        "freshness": "cool",
        "line": "communication"
    }
]
EOF
}

# Build grouped automation stations
build_automation_stations() {
    local jobs=$(get_launchd_jobs)
    local morning=$(echo "$jobs" | jq '.morning')
    local health=$(echo "$jobs" | jq '.health')
    local hydra=$(echo "$jobs" | jq '.hydra')
    local evening=$(echo "$jobs" | jq '.evening')

    jq -n \
        --argjson morning "$morning" \
        --argjson health "$health" \
        --argjson hydra "$hydra" \
        --argjson evening "$evening" \
        '[
            {
                "id": "morning-jobs",
                "name": "Morning Jobs",
                "type": "grouped",
                "description": "Daily startup automation",
                "freshness": "hot",
                "line": "automation",
                "children": $morning
            },
            {
                "id": "health-monitors",
                "name": "Health Monitors",
                "type": "grouped",
                "description": "System health & tracking",
                "freshness": "warm",
                "line": "automation",
                "children": $health
            },
            {
                "id": "hydra-ops",
                "name": "HYDRA Ops",
                "type": "grouped",
                "description": "Agent coordination jobs",
                "freshness": "hot",
                "line": "automation",
                "children": $hydra
            },
            {
                "id": "evening-jobs",
                "name": "Evening Jobs",
                "type": "grouped",
                "description": "End of day automation",
                "freshness": "warm",
                "line": "automation",
                "children": $evening
            }
        ]'
}

# Main function to generate empire data
main() {
    echo "Generating empire data..." >&2

    # Collect all stations
    local project_stations=$(build_project_stations)
    local agent_stations=$(build_agent_stations)
    local infra_stations=$(build_infra_stations)
    local comm_stations=$(build_comm_stations)
    local automation_stations=$(build_automation_stations)

    # Get task stats
    local task_stats=$(get_hydra_task_stats)

    # Merge all stations
    local all_stations=$(jq -n \
        --argjson p "$project_stations" \
        --argjson a "$agent_stations" \
        --argjson i "$infra_stations" \
        --argjson c "$comm_stations" \
        --argjson auto "$automation_stations" \
        '$p + $a + $i + $c + $auto')

    local total_stations=$(echo "$all_stations" | jq 'length')
    local total_jobs=$(ls -1 "$LAUNCH_AGENTS"/com.id8labs*.plist "$LAUNCH_AGENTS"/com.hydra*.plist "$LAUNCH_AGENTS"/com.eddieb*.plist "$LAUNCH_AGENTS"/com.homer*.plist 2>/dev/null | wc -l | tr -d ' ')

    # Build final JSON
    jq -n \
        --arg gen "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg genLocal "$(date +"%Y-%m-%d %H:%M:%S")" \
        --argjson stations "$all_stations" \
        --argjson taskStats "$task_stats" \
        --argjson totalStations "$total_stations" \
        --argjson totalJobs "$total_jobs" \
        '{
            generated: $gen,
            generatedLocal: $genLocal,
            lines: {
                business: {
                    name: "Business Empire",
                    color: "#ff6b6b",
                    description: "Revenue-generating projects"
                },
                hydra: {
                    name: "HYDRA Network",
                    color: "#00d4ff",
                    description: "AI agent coordination"
                },
                automation: {
                    name: "Automation Subway",
                    color: "#90ff90",
                    description: "Scheduled automation jobs"
                },
                infrastructure: {
                    name: "Infrastructure",
                    color: "#ffc107",
                    description: "Core infrastructure services"
                },
                communication: {
                    name: "Communication",
                    color: "#9b59b6",
                    description: "Communication channels"
                }
            },
            stations: $stations,
            stats: {
                tasks: $taskStats,
                totalStations: $totalStations,
                totalJobs: $totalJobs
            }
        }' > "$OUTPUT_FILE"

    echo "Empire data written to $OUTPUT_FILE" >&2
    echo "Total stations: $total_stations" >&2
}

# Run
main
