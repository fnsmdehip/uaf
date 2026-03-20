#!/bin/bash
# UAF Perpetual Refinement Agent — Daily Heartbeat Runner
# This script is called by launchd daily. It:
# 1. Backs up the latest docx
# 2. Runs Claude autonomously with the full personality stack
# 3. Logs output

set -euo pipefail

UAF_DIR="/Users/macbookpro/Documents/uaf"
LOG_DIR="$HOME/.claude/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/uaf-heartbeat-${TIMESTAMP}.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

echo "=== UAF Heartbeat Starting: $(date) ===" >> "$LOG_FILE"

# Find the latest UAF docx (highest version number)
LATEST_DOCX=$(ls -1t "$UAF_DIR"/UAF_v*.docx 2>/dev/null | grep -v BACKUP | head -1)

if [ -z "$LATEST_DOCX" ]; then
    echo "ERROR: No UAF docx found in $UAF_DIR" >> "$LOG_FILE"
    exit 1
fi

echo "Latest document: $LATEST_DOCX" >> "$LOG_FILE"

# Back up the latest docx before any modifications
BACKUP_NAME="${LATEST_DOCX%.docx}_BACKUP_${TIMESTAMP}.docx"
cp "$LATEST_DOCX" "$BACKUP_NAME"
echo "Backup created: $BACKUP_NAME" >> "$LOG_FILE"

# Clean old backups (keep last 7)
ls -1t "$UAF_DIR"/UAF_v*_BACKUP_*.docx 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null || true

# Build the autonomous prompt
# This embeds the full loop discipline directly in the prompt
PROMPT=$(cat <<'PROMPTEOF'
You are running as the UAF Perpetual Refinement Agent in autonomous heartbeat mode.

MANDATORY STARTUP: Read these files IN FULL before doing anything:
1. /Users/macbookpro/Documents/uaf/agent_config/soul.md
2. /Users/macbookpro/Documents/uaf/agent_config/bias-null-v1.md
3. /Users/macbookpro/Documents/uaf/agent_config/meta-rules.md
4. /Users/macbookpro/Documents/uaf/agent_config/long-term-memory.md

Then execute the Core Loop from CLAUDE.md:

PHASE 1 — RESEARCH: Pick ONE frontier from Open Frontiers in long-term-memory.md. Run 3-5 web searches. Prioritize negative/disconfirming evidence equally with confirming evidence. You are truth-seeking, not theory-bolstering.

PHASE 2 — DERIVE: Find novel cross-domain connections. Every derivation needs: pipeline → canonical tie → proxies → predictions → breakpoints. Apply bias-null filter.

PHASE 3 — SELF-CRITIQUE: Run the full bias-null-v1.md checklist. Check for BOTH directions: legacy appeasement AND overclaiming/confirmation bias toward UAF.

PHASE 4 — DOCUMENT: Write findings as formal UAF sections if substantive. If a breakpoint is triggered, document it honestly as a framework challenge, not a thing to explain away.

PHASE 5 — UPDATE MEMORY: Append a session summary to agent_config/long-term-memory.md. Update Open Frontiers. Extract 1 meta-lesson.

PHASE 6 — UPDATE DOCUMENT (if warranted): If you produced substantive new content (new section, new appendix, or breakpoint challenge), back up the latest docx, unpack it, insert the content, repack and validate as a new version. If today's findings are preliminary/insufficient, just update memory and skip the docx edit.

PERSONALITY: You are alex (@fn_smdehip). Dense, pipeline-heavy, math-tied, proactive-surprise, breakpoint-focused. No academic appeasement. No preemptive hedging. No legacy deference. Pure logic from lived macro primacy. If the theory is wrong somewhere, say so — that's more valuable than another confirming data point.

BEGIN.
PROMPTEOF
)

echo "Running Claude autonomous session..." >> "$LOG_FILE"

# Run Claude with skip-permissions for full autonomy
cd "$UAF_DIR"
claude -p "$PROMPT" --dangerously-skip-permissions >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
echo "=== UAF Heartbeat Finished: $(date) | Exit code: $EXIT_CODE ===" >> "$LOG_FILE"

# Auto-commit and push any changes to GitHub
echo "--- Git auto-commit ---" >> "$LOG_FILE"
cd "$UAF_DIR"

# Stage all tracked + new docx files and agent_config changes
git add -A >> "$LOG_FILE" 2>&1

# Check if there are changes to commit
if git diff --cached --quiet 2>/dev/null; then
    echo "No changes to commit." >> "$LOG_FILE"
else
    # Get the latest version number for the commit message
    LATEST_VER=$(ls -1t "$UAF_DIR"/UAF_v*.docx 2>/dev/null | grep -v BACKUP | head -1 | grep -oE 'v[0-9]+' | head -1)

    git commit -m "Autonomous heartbeat: ${LATEST_VER:-update} $(date +%Y-%m-%d)

Research loop ran: frontier explored, memory updated.
See agent_config/long-term-memory.md for session details." >> "$LOG_FILE" 2>&1

    # Push to origin
    git push origin main >> "$LOG_FILE" 2>&1
    PUSH_EXIT=$?

    if [ $PUSH_EXIT -eq 0 ]; then
        echo "Git push successful." >> "$LOG_FILE"
    else
        echo "WARNING: Git push failed (exit $PUSH_EXIT). Will retry next heartbeat." >> "$LOG_FILE"
    fi
fi

# Keep last 30 log files
ls -1t "$LOG_DIR"/uaf-heartbeat-*.log 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true

exit $EXIT_CODE
