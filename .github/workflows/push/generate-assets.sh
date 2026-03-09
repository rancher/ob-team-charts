#!/usr/bin/env bash
# Generate chart assets for all charts in a branch.
#
# Prerequisites (Initial run): prepare-deps.sh, update-patches.sh
# Prerequisites (Final run):   update-kuberlr.sh
#
# Inputs (env):
#   CHARTS_DIR    - path to rancher/charts clone (required)
#   BRANCH_FILE   - path to branch data CSV; if unset, auto-derived from TARGET_BRANCH
#   TARGET_BRANCH - branch name (required when BRANCH_FILE is not set)
#   ASSET_LABEL   - commit label prefix: "Initial" or "Final" (default: "Initial")
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_charts_dir
ensure_branch_file

ASSET_LABEL="${ASSET_LABEL:-Initial}"
CHART_NAMES=$(cut -d',' -f1 "$BRANCH_FILE" | cut -d'/' -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
BASE_REF=${BASE_REF:-upstream/main}

MODIFIED_PACKAGES=$(git -C "$CHARTS_DIR" diff --name-only "$BASE_REF"...HEAD | grep '^packages/' | cut -d/ -f2-3 | sort -u || true)

while IFS=, read -r chart_full_version PACKAGE_PATH; do
  if echo "$MODIFIED_PACKAGES" | grep -q "^$PACKAGE_PATH$"; then
     make -C "$CHARTS_DIR" charts PACKAGE="$PACKAGE_PATH" USE_CACHE=true
     summary "  - Generated assets for \`$PACKAGE_PATH\`"
  fi
done < "$BRANCH_FILE"

commit_if_changed "chore(charts): $ASSET_LABEL \`${CHART_NAMES}\` chart assets build"
