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
  summary "Package Version to Remove RCs: $OLD_VERSION"

  # Find all directories that match the version prefix
  CHART_PATH="$CHARTS_DIR/charts/$CHART_NAME"
  if [ ! -d "$CHART_PATH" ]; then
    summary "  - Warning: Chart directory not found: $CHART_PATH"
    continue
  fi

  # Find matching version directories
  MATCHED_VERSIONS=()
  while IFS= read -r -d '' version_dir; do
    version_name=$(basename "$version_dir")
    MATCHED_VERSIONS+=("$version_name")
  done < <(find "$CHART_PATH" -maxdepth 1 -type d -name "${OLD_VERSION}*" -print0)

  if [ ${#MATCHED_VERSIONS[@]} -eq 0 ]; then
    summary "  - Warning: No versions found matching \`$OLD_VERSION\` for chart \`$CHART_NAME\`"
    continue
  fi

  # Remove each matching version
  for FULL_VERSION in "${MATCHED_VERSIONS[@]}"; do
    make -C "$CHARTS_DIR" remove CHART="$CHART_NAME" VERSION="$FULL_VERSION"
    commit_if_changed "chore(charts): Remove superseded \`$CHART_NAME\` version \`$FULL_VERSION\`"
    summary "  - Removed superseded \`$CHART_NAME\` version \`$FULL_VERSION\`"
  done
done < "$REMOVALS_FILE"
