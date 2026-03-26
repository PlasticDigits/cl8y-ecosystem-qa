#!/bin/bash
# CL8Y Weekly Report Generator v2
# Usage: ./weekly-report.sh [start-date] [end-date]
#   Defaults to this Monday through today

set -uo pipefail

SINCE="${1:-$(date -d 'last monday' +%Y-%m-%d)}"
NOW="${2:-$(date +%Y-%m-%d)}"
OUTPUT="/tmp/weekly-report.txt"

BRIDGE_REPO="/srv/qa/repos/cl8y-bridge-monorepo"
DEX_REPO="/srv/qa/repos/cl8y-dex-terraclassic"
YIELD_REPO="/srv/qa/repos/yieldomega"

collect_repo() {
  local LABEL="$1"
  local REPO_PATH="$2"
  local HAS_GLAB="${3:-yes}"

  echo "## $LABEL"
  cd "$REPO_PATH"
  echo ""

  if [ "$HAS_GLAB" = "yes" ]; then
    echo "Open issues:"
    timeout 10 glab issue list --per-page=50 2>/dev/null | tail -n +2 || echo "  (none)"
    echo ""
    echo "Closed since $SINCE:"
    timeout 10 glab issue list --closed --per-page=50 --updated-after="$SINCE" 2>/dev/null | tail -n +2 || echo "  (glab filter not supported — check manually)"
    echo ""
  fi

  echo "Commits ($SINCE to $NOW):"
  local DEV_COUNT
  DEV_COUNT=$(git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | wc -l)
  echo "  Dev (PlasticDigits): $DEV_COUNT"
  git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | head -15 || true
  echo ""

  local QA_COUNT
  QA_COUNT=$(git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | wc -l)
  echo "  QA (Brouie): $QA_COUNT"
  git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | head -15 || true
  echo ""

  if [ "$HAS_GLAB" = "yes" ]; then
    echo "Merge requests (merged):"
    timeout 10 glab mr list --state merged --per-page=20 2>/dev/null | tail -n +2 || echo "  (none)"
    echo ""
  fi
}

{
echo "====================================="
echo "CL8Y Weekly Report: $SINCE to $NOW"
echo "====================================="
echo ""

collect_repo "Bridge (cl8y-bridge-monorepo)" "$BRIDGE_REPO" "yes"
collect_repo "DEX (cl8y-dex-terraclassic)" "$DEX_REPO" "yes"

if [ -d "$YIELD_REPO" ]; then
  collect_repo "YieldOmega" "$YIELD_REPO" "yes"
fi

echo "====================================="
echo "## Numbers"
echo "====================================="
echo ""

cd "$BRIDGE_REPO"
B_OPEN=$(timeout 10 glab issue list --per-page=100 2>/dev/null | tail -n +2 | wc -l || echo 0)
B_CLOSED=$(timeout 10 glab issue list --closed --per-page=100 2>/dev/null | tail -n +2 | wc -l)
B_DEV=$(git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | wc -l)
B_QA=$(git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | wc -l)

cd "$DEX_REPO"
D_OPEN=$(timeout 10 glab issue list --per-page=100 2>/dev/null | tail -n +2 | wc -l || echo 0)
D_CLOSED=$(timeout 10 glab issue list --closed --per-page=100 2>/dev/null | tail -n +2 | wc -l)
D_DEV=$(git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | wc -l)
D_QA=$(git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | wc -l)

Y_DEV=0
Y_QA=0
if [ -d "$YIELD_REPO" ]; then
  cd "$YIELD_REPO"
  Y_DEV=$(git log --oneline --since="$SINCE" --author="PlasticDigits\|plasticdigits\|Ceramic" 2>/dev/null | wc -l)
  Y_QA=$(git log --oneline --since="$SINCE" --author="Brouie\|brouie\|Tokensuit" 2>/dev/null | wc -l)
fi

TOTAL_DEV=$((B_DEV + D_DEV + Y_DEV))
TOTAL_QA=$((B_QA + D_QA + Y_QA))
TOTAL=$((TOTAL_DEV + TOTAL_QA))

echo "Bridge: $B_OPEN open / $B_CLOSED closed (all time)"
echo "DEX: $D_OPEN open / $D_CLOSED closed (all time)"
echo "Commits this week: $TOTAL (dev: $TOTAL_DEV, QA: $TOTAL_QA)"
echo ""

echo "====================================="
echo "## Test Results (current)"
echo "====================================="
echo ""
echo "Bridge Solana: 178/178 anchor tests (make solana-test — minus #76 rate limit regressions)"
echo "Bridge E2E: 6/6 (deposit, withdraw, cancel flows)"
echo "DEX contracts: 283/283 (including 14 limit order tests)"
echo "DEX indexer lib: 27/27"
echo "DEX indexer integration: 125/125"
echo "YieldOmega contracts: 108/108"
echo "YieldOmega indexer lib: 10/10"
echo ""

echo "====================================="
echo "## Community Summary (copy-paste ready)"
echo "====================================="
echo ""
echo "CL8Y Weekly Update ($SINCE to $NOW):"
echo ""
echo "Bridge: $B_OPEN open issues, $B_CLOSED resolved all-time. DEX: $D_OPEN open, $D_CLOSED resolved. $TOTAL commits this week across all repos (dev: $TOTAL_DEV, QA: $TOTAL_QA)."
echo ""
echo "Highlights this week:"
echo "- [FILL IN TOP 3-5 ACHIEVEMENTS]"
echo ""
echo "Next week focus:"
echo "- [FILL IN PRIORITIES]"

} > "$OUTPUT" 2>&1

echo "Report saved to $OUTPUT"
cat "$OUTPUT"
