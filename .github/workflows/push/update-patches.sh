#!/usr/bin/env bash
# Regenerate chart patches for all charts in a branch.
#
# Prerequisites: prepare-deps.sh (charts dir must be prepared before patching)
#
# Inputs (env):
#   CHARTS_DIR    - path to rancher/charts clone (required)
#   BRANCH_FILE   - path to branch data CSV; if unset, auto-derived from TARGET_BRANCH
#   TARGET_BRANCH - branch name (required when BRANCH_FILE is not set)
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_charts_dir
ensure_branch_file

while IFS=, read -r chart_full_version PACKAGE_PATH; do
  make -C "$CHARTS_DIR" prepare PACKAGE="$PACKAGE_PATH" USE_CACHE=true
  make -C "$CHARTS_DIR" patch PACKAGE="$PACKAGE_PATH" USE_CACHE=true
  make -C "$CHARTS_DIR" clean
  summary "  - Updated patches for \`$PACKAGE_PATH\`"
done < "$BRANCH_FILE"

commit_if_changed "chore(charts): Refresh chart patches"
