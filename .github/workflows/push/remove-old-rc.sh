#!/usr/bin/env bash
# Runs make remove for the old rc version
#
# Inputs (env):
#   CHARTS_DIR    - path to rancher/charts clone (required)
#   BRANCH_FILE   - path to branch data
#
# Output: one git commit per removed chart/version in CHARTS_DIR
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_charts_dir
ensure_branch_file

REMOVALS_FILE="${BRANCH_FILE}.rc_removals"
if [ ! -f "$REMOVALS_FILE" ] || [ ! -s "$REMOVALS_FILE" ]; then
  summary "  - No superseded rc versions to remove."
  exit 0
fi

while IFS=, read -r CHART_NAME OLD_VERSION; do
  make -C "$CHARTS_DIR" remove CHART="$CHART_NAME" VERSION="$OLD_VERSION"
  commit_if_changed "chore(charts): Remove superseded \`$CHART_NAME\` version \`$OLD_VERSION\`"
  summary "  - Removed superseded \`$CHART_NAME\` version \`$OLD_VERSION\`"
done < "$REMOVALS_FILE"
