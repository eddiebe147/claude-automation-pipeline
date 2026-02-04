# Claude Automation Pipeline

An intelligent development workflow that automatically surfaces portfolio health, analyzes priorities with Claude AI, and generates actionable morning reports.

## What It Does

**3-Phase Daily Automation:**

1. **3:00 AM** - Collect product health data (git status, pipeline metrics, agent parity)
2. **6:00 AM** - Claude AI analyzes and categorizes issues  
3. **7:00 AM** - Beautiful morning report opens automatically

## Quick Setup

```bash
# Clone this repo
git clone https://github.com/eddiebelaval/claude-automation-pipeline.git
cd claude-automation-pipeline

# Copy to Development directory
cp *.sh ~/Development/scripts/
cp *.json ~/Development/config/
cp -r skills/ ~/Development/id8/skills-registry/skills/stackshack/
cp *.md ~/Development/

# Set your Claude API key
export CLAUDE_API_KEY="sk-..."

# Enable automation
bash ~/Development/scripts/setup-automation.sh --enable
```

## Files

- **scripts/** - Main automation scripts
  - `collect-product-health.sh` - Gather metrics
  - `analyze-report.sh` - Claude API analysis
  - `generate-morning-report.sh` - Beautiful reports
  - `dev-execute` - Task executor
  - `feedback-tracker.sh` - Learning system

- **config/** - Configuration files
  - `automation.json` - Global settings
  - `quality-gates.json` - Quality requirements per project
  - `launchd/` - macOS scheduling (plist files)

- **skills/** - Claude skills for task generation
  - `compound-tasks/` - Atomic task breakdown
  - `scope-validator/` - Scope fence validation
  - `quality-checker/` - Quality gate enforcement

## Documentation

- `AUTOMATION_PIPELINE.md` - Complete system guide
- `IMPLEMENTATION_SUMMARY.md` - What was built and why

## Requirements

- macOS (uses launchd for scheduling)
- Claude API key
- `gh` CLI (GitHub command line)
- `jq` (JSON processing)
- `bash` 4.0+

## Environment Setup

Set your Claude API key permanently:

```bash
# Add to ~/.zshrc or ~/.bash_profile
export CLAUDE_API_KEY="sk-..."
```

## Status

**Live Phases:** 0-3 (Collection, Analysis, Reporting, Execution)
**In Development:** 4-5 (Quality Skills, Feedback Learning)

## Next Steps

1. Enable automation: `bash ~/Development/scripts/setup-automation.sh --enable`
2. Check logs: `tail -f ~/Development/reports/launchd-*.log`
3. View reports: `cat ~/Development/reports/morning-*.md`

## License

MIT - Use freely, modify as needed

---

**Made with Claude Code** - Automated development workflow
