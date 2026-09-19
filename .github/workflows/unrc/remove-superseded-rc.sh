#!/usr/bin/env bash
# Remove all rc assets superseded by the release version.
# Inputs (env):
#   CHARTS_DIR    - path to rancher/charts clone (required)
#   BASE_VERSION  - the (non-rc) version that was just released (required)
#   BRANCH_FILE   - path to branch data CSV; if unset, auto-derived from TARGET_BRANCH
#   TARGET_BRANCH - branch name (required when BRANCH_FILE is not set)
set -euo pipefail
source "$(dirname "$0")/../push/common.sh"

require_charts_dir
require_var BASE_VERSION
ensure_branch_file

while IFS=, read -r chart_full_version CHARTS_PACKAGE_DIR; do
  CHART_NAME=$(echo "$chart_full_version" | cut -d'/' -f1)
  OB_VERSION=$(echo "$chart_full_version" | cut -d'/' -f2)
  PACKAGE_YAML_PATH="$CHARTS_DIR/packages/$CHARTS_PACKAGE_DIR/package.yaml"

  NAMES_TO_CHECK=("$CHART_NAME")
  if [ "$(yq e '.additionalCharts | has(0)' "$PACKAGE_YAML_PATH")" = "true" ]; then
    NAMES_TO_CHECK+=("${CHART_NAME}-crd")
  fi

  for NAME in "${NAMES_TO_CHECK[@]}"; do
    CHART_ASSET_DIR="$CHARTS_DIR/charts/$NAME"
    [ -d "$CHART_ASSET_DIR" ] || continue

    shopt -s nullglob
    for dir in "$CHART_ASSET_DIR/${BASE_VERSION}-rc."*"+up${OB_VERSION}"; do
      OLD_FULL_VERSION=$(basename "$dir")
      make -C "$CHARTS_DIR" remove CHART="$NAME" VERSION="$OLD_FULL_VERSION"
      commit_if_changed "chore(charts): Remove superseded \`$NAME\` version \`$OLD_FULL_VERSION\`"
      summary "  - Removed superseded \`$NAME\` version \`$OLD_FULL_VERSION\`"
    done
    shopt -u nullglob
  done
done < "$BRANCH_FILE"
