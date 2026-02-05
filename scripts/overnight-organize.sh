#!/bin/bash
# overnight-organize.sh - Headless file organization via Claude Code
# Runs: 3 AM daily via launchd
# Logs: ~/Library/Logs/claude-overnight/
#
# This script runs Claude Code in headless mode to:
# 1. Organize ~/Downloads by file type
# 2. Organize ~/Desktop/00-inbox by file type
# 3. Clean up old screenshots from Desktop
# 4. Archive files older than 30 days
# 5. Generate a summary report

set -e

# Configuration
LOGS_DIR="$HOME/Library/Logs/claude-overnight"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOGS_DIR/organize-$DATE.log"
REPORT_FILE="$LOGS_DIR/report-$DATE.md"

# Directories to organize
DOWNLOADS_DIR="$HOME/Downloads"
INBOX_DIR="$HOME/Desktop/00-inbox"
DESKTOP_DIR="$HOME/Desktop"
ARCHIVE_DIR="$HOME/Documents/Archive"

# Create logs directory
mkdir -p "$LOGS_DIR"
mkdir -p "$ARCHIVE_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "Overnight File Organization"
echo "Started: $(date)"
echo "========================================"
echo ""

# Check if Claude CLI is available
if ! command -v claude &> /dev/null; then
    echo "ERROR: Claude CLI not found in PATH"
    echo "Make sure Claude Code is installed and in PATH"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# TASK 1: Organize Downloads
# ═══════════════════════════════════════════════════════════════

echo "TASK 1: Organizing Downloads..."
echo ""

claude -p "
Organize files in $DOWNLOADS_DIR with these rules:

1. Create these folders if they don't exist:
   - Images/ (png, jpg, jpeg, gif, webp, svg, ico)
   - Documents/ (pdf, doc, docx, txt, rtf, odt, xls, xlsx, csv)
   - Videos/ (mp4, mov, avi, mkv, webm)
   - Audio/ (mp3, wav, flac, m4a, aac)
   - Archives/ (zip, tar, gz, rar, 7z, dmg)
   - Code/ (js, ts, py, sh, json, yaml, yml, md)
   - Other/ (everything else)

2. Move each file to the appropriate folder based on extension
3. Skip folders - only move files
4. If a file with the same name exists, add a number suffix (file-1.pdf, file-2.pdf)
5. Skip files modified in the last 24 hours (they might be in use)

After organizing, output a summary of what was moved.
" --allowedTools "Bash,Read,Write,Glob" \
  --output-format stream-json 2>&1 || {
    echo "WARNING: Downloads organization had issues"
}

echo ""
echo "Downloads organization complete."
echo ""

# ═══════════════════════════════════════════════════════════════
# TASK 2: Organize 00-inbox
# ═══════════════════════════════════════════════════════════════

echo "TASK 2: Organizing 00-inbox..."
echo ""

if [[ -d "$INBOX_DIR" ]]; then
    claude -p "
Organize files in $INBOX_DIR with these rules:

1. Create these folders if they don't exist:
   - Images/ (png, jpg, jpeg, gif, webp, svg, ico, heic)
   - Documents/ (pdf, doc, docx, txt, rtf, odt, xls, xlsx, csv, pages, numbers)
   - Videos/ (mp4, mov, avi, mkv, webm)
   - Audio/ (mp3, wav, flac, m4a, aac)
   - Archives/ (zip, tar, gz, rar, 7z, dmg)
   - Code/ (js, ts, py, sh, json, yaml, yml, md, html, css)
   - Other/ (everything else)

2. Move each file to the appropriate folder based on extension
3. Skip folders - only move files at the root level
4. If a file with the same name exists, add a number suffix (file-1.pdf, file-2.pdf)
5. Skip files modified in the last 2 hours (they might be in use)

After organizing, output a summary of what was moved.
" --allowedTools "Bash,Read,Write,Glob" \
      --output-format stream-json 2>&1 || {
        echo "WARNING: 00-inbox organization had issues"
    }
else
    echo "00-inbox directory not found, skipping..."
fi

echo ""
echo "00-inbox organization complete."
echo ""

# ═══════════════════════════════════════════════════════════════
# TASK 3: Clean Desktop Screenshots
# ═══════════════════════════════════════════════════════════════

echo "TASK 3: Cleaning Desktop screenshots..."
echo ""

claude -p "
Clean up screenshots on $DESKTOP_DIR:

1. Find all files matching 'Screenshot*.png' or 'Screen Shot*.png'
2. If they are older than 7 days, move them to $ARCHIVE_DIR/Screenshots/
3. Create the Screenshots archive folder if needed
4. Count how many were archived

Output the count of archived screenshots.
" --allowedTools "Bash,Read,Write,Glob" \
  --output-format stream-json 2>&1 || {
    echo "WARNING: Screenshot cleanup had issues"
}

echo ""
echo "Screenshot cleanup complete."
echo ""

# ═══════════════════════════════════════════════════════════════
# TASK 4: Archive Old Downloads
# ═══════════════════════════════════════════════════════════════

echo "TASK 4: Archiving old files..."
echo ""

claude -p "
Archive old files from $DOWNLOADS_DIR:

1. Find files in $DOWNLOADS_DIR (including subfolders) older than 30 days
2. Move them to $ARCHIVE_DIR/Downloads-$(date +%Y-%m)/
3. Create the archive folder if needed
4. Preserve the folder structure when moving
5. Skip any files larger than 1GB (might be important)

Output a count of archived files and total size.
" --allowedTools "Bash,Read,Write,Glob" \
  --output-format stream-json 2>&1 || {
    echo "WARNING: Archive task had issues"
}

echo ""
echo "Archiving complete."
echo ""

# ═══════════════════════════════════════════════════════════════
# GENERATE SUMMARY REPORT
# ═══════════════════════════════════════════════════════════════

echo "Generating summary report..."

# Count files in organized folders
DOWNLOADS_COUNT=$(find "$DOWNLOADS_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
INBOX_COUNT=$(find "$INBOX_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
ARCHIVE_COUNT=$(find "$ARCHIVE_DIR" -type f -mtime -1 2>/dev/null | wc -l | tr -d ' ')

cat > "$REPORT_FILE" << EOF
# Overnight Organization Report
**Date:** $(date '+%A, %B %d, %Y')
**Completed:** $(date '+%H:%M %Z')

## Summary

- **Downloads folder:** $DOWNLOADS_COUNT files remaining
- **00-inbox folder:** $INBOX_COUNT files remaining
- **Newly archived:** $ARCHIVE_COUNT files

## Log Location
\`$LOG_FILE\`

## Folders Organized
- ~/Downloads/ (sorted by file type)
- ~/Desktop/00-inbox/ (sorted by file type)
- ~/Desktop/ (screenshots archived)
- ~/Documents/Archive/ (old files moved)

---
*Generated by overnight-organize.sh via Claude Code headless mode*
EOF

echo ""
echo "========================================"
echo "Organization Complete"
echo "Finished: $(date)"
echo "Report: $REPORT_FILE"
echo "========================================"

# Optional: Send notification (if terminal-notifier is installed)
if command -v terminal-notifier &> /dev/null; then
    terminal-notifier -title "Overnight Organization" \
        -message "File organization complete. Check $REPORT_FILE" \
        -sound default
fi

exit 0
