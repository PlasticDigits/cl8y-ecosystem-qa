#!/bin/bash
# CL8Y Weekly Report Generator
# Pulls issues, commits, MRs from both repos and generates a community summary
#
# Usage: ./weekly-report.sh [start-date] [end-date]
#   Defaults to this Monday through Friday

set -euo pipefail

SINCE="${1:-$(date -d 'last monday' +%Y-%m-%d)}"
NOW="${2:-$(date -d 'next friday' +%Y-%m-%d)}"
echo "====================================="
echo "CL8Y Weekly Report: $SINCE → $NOW"
echo "====================================="
echo ""

BRIDGE_REPO="/srv/qa/repos/cl8y-bridge-monorepo"
DEX_REPO="/srv/qa/repos/cl8y-dex-terraclassic"

echo "## Issues"
echo ""
echo "### Bridge (cl8y-bridge-monorepo)"
cd "$BRIDGE_REPO"
echo "Open:"
timeout 10 glab issue list --per-page=50 2>/dev/null | tail -n +2 || echo "  (none)"
echo ""
echo "Closed this week:"
echo ""

echo "### DEX (cl8y-dex-terraclassic)"
cd "$DEX_REPO"
echo "Open:"
timeout 10 glab issue list --per-page=50 2>/dev/null | tail -n +2 || echo "  (none)"
echo ""
echo "Closed this week:"
echo ""

echo "## Commits ($SINCE → $NOW)"
echo ""
echo "### Bridge"
cd "$BRIDGE_REPO"
echo "PlasticDigits:"
git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | wc -l | xargs -I{} echo "  {} commits"
git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | head -10
echo ""
echo "Brouie:"
git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | wc -l | xargs -I{} echo "  {} commits"
git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | head -10
echo ""

echo "### DEX"
cd "$DEX_REPO"
echo "PlasticDigits:"
git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | wc -l | xargs -I{} echo "  {} commits"
git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | head -10
echo ""
echo "Brouie:"
git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | wc -l | xargs -I{} echo "  {} commits"
git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | head -10
echo ""

echo "## Merge Requests"
echo ""
echo "### Bridge"
cd "$BRIDGE_REPO"
timeout 10 glab mr list --state merged --per-page=20 2>/dev/null | tail -n +2 || echo "  (none found)"
echo ""
echo "### DEX"
cd "$DEX_REPO"
timeout 10 glab mr list --state merged --per-page=20 2>/dev/null | tail -n +2 || echo "  (none found)"
echo ""

echo "====================================="
echo "## Community Summary (copy-paste ready)"
echo "====================================="
echo ""

cd "$BRIDGE_REPO"
BRIDGE_OPEN=$(timeout 10 glab issue list --per-page=100 2>/dev/null | tail -n +2 | wc -l)
BRIDGE_CLOSED=$(timeout 10 glab issue list -s closed --per-page=100 2>/dev/null | tail -n +2 | wc -l)
BRIDGE_COMMITS_DEV=$(git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | wc -l)
BRIDGE_COMMITS_QA=$(git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | wc -l)

cd "$DEX_REPO"
DEX_OPEN=$(timeout 10 glab issue list --per-page=100 2>/dev/null | tail -n +2 | wc -l)
DEX_CLOSED=$(timeout 10 glab issue list -s closed --per-page=100 2>/dev/null | tail -n +2 | wc -l)
DEX_COMMITS_DEV=$(git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | wc -l)
DEX_COMMITS_QA=$(git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | wc -l)

TOTAL_COMMITS=$((BRIDGE_COMMITS_DEV + BRIDGE_COMMITS_QA + DEX_COMMITS_DEV + DEX_COMMITS_QA))

echo "CL8Y Weekly Update ($SINCE to $NOW): Bridge has $BRIDGE_OPEN open issues and $BRIDGE_CLOSED resolved; DEX has $DEX_OPEN open and $DEX_CLOSED resolved. $TOTAL_COMMITS commits this week across both repos (dev: $((BRIDGE_COMMITS_DEV + DEX_COMMITS_DEV)), QA: $((BRIDGE_COMMITS_QA + DEX_COMMITS_QA))). Key highlights: [EDIT — add top achievements from above]."
echo ""
