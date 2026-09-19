#!/usr/bin/env bash
# Strip the -rc.N suffix from a package's version
# Inputs (env):
#   CHARTS_DIR    - path to rancher/charts clone (required)
#   BASE_VERSION  - target (non-rc) version to write, e.g. "110.0.2" (required)
#   BRANCH_FILE   - path to branch data CSV; if unset, auto-derived from TARGET_BRANCH
#   TARGET_BRANCH - branch name (required when BRANCH_FILE is not set)
set -euo pipefail
source "$(dirname "$0")/../push/common.sh"

require_charts_dir
require_var BASE_VERSION
ensure_branch_file

CHART_NAMES=$(cut -d',' -f1 "$BRANCH_FILE" | cut -d'/' -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

> "${BRANCH_FILE}.versions"

while IFS=, read -r chart_full_version CHARTS_PACKAGE_DIR; do
  PACKAGE_YAML_PATH="$CHARTS_DIR/packages/$CHARTS_PACKAGE_DIR/package.yaml"

  CURRENT_VERSION=$(yq e '.version' "$PACKAGE_YAML_PATH")
  yq e -i ".version = \"$BASE_VERSION\"" "$PACKAGE_YAML_PATH"
  echo "${chart_full_version}=${BASE_VERSION}" >> "${BRANCH_FILE}.versions"
  summary "  - Promoted \`$CHARTS_PACKAGE_DIR\` from \`$CURRENT_VERSION\` to \`$BASE_VERSION\`"
done < "$BRANCH_FILE"

commit_if_changed "chore(charts): Promote \`${CHART_NAMES}\` to release version \`${BASE_VERSION}\`"
summary "  - Committed package.yaml changes"
