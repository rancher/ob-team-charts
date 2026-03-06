#!/usr/bin/env bash
# Update package.yaml files for all charts in a branch.
#
# Prerequisites: group-by-branch.sh (or TARGET_BRANCH set for auto-derivation)
#
# Inputs (env):
#   CHARTS_DIR    - path to rancher/charts clone (required)
#   COMMIT_SHA    - upstream commit SHA to pin in package.yaml (required)
#   BRANCH_FILE   - path to branch data CSV; if unset, auto-derived from TARGET_BRANCH
#   TARGET_BRANCH - branch name (required when BRANCH_FILE is not set)
#
# Output: git commit in CHARTS_DIR; writes versions to ${BRANCH_FILE}.versions
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_charts_dir
require_var COMMIT_SHA
ensure_branch_file

CHART_NAMES=$(cut -d',' -f1 "$BRANCH_FILE" | cut -d'/' -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

# Clear versions file for this branch
> "${BRANCH_FILE}.versions"

while IFS=, read -r chart_full_version PACKAGE_PATH; do
  CHART_NAME=$(echo "$chart_full_version" | cut -d'/' -f1)
  CHART_VERSION=$(echo "$chart_full_version" | cut -d'/' -f2)
  PACKAGE_YAML_PATH="$CHARTS_DIR/packages/$PACKAGE_PATH/package.yaml"

  if [ ! -f "$PACKAGE_YAML_PATH" ]; then
    echo "WARNING: package.yaml not found at $PACKAGE_YAML_PATH" >&2
    continue
  fi

  yq e -i ".subdirectory = \"charts/$CHART_NAME/$CHART_VERSION\"" "$PACKAGE_YAML_PATH"
  yq e -i ".commit = \"$COMMIT_SHA\"" "$PACKAGE_YAML_PATH"

  CURRENT_VERSION=$(yq e '.version' "$PACKAGE_YAML_PATH")
  if [[ "$CURRENT_VERSION" == *"-rc."* ]]; then
    NEW_VERSION=$(echo "$CURRENT_VERSION" | awk -F- '{split($2, a, "."); print $1"-rc."a[2]+1}')
  else
    NEW_VERSION=$(echo "$CURRENT_VERSION" | awk -F. '{print $1"."$2"."$3+1"-rc.1"}')
  fi

  yq e -i ".version = \"$NEW_VERSION\"" "$PACKAGE_YAML_PATH"
  echo "${chart_full_version}=${NEW_VERSION}" >> "${BRANCH_FILE}.versions"
  summary "  - Updated \`$PACKAGE_PATH\` to version \`$NEW_VERSION\`"

  if yq e '.additionalCharts | has(0)' "$PACKAGE_YAML_PATH" &>/dev/null; then
    CRD_CHART_NAME="${CHART_NAME}-crd"
    yq e -i ".additionalCharts[0].upstreamOptions.subdirectory = \"charts/${CRD_CHART_NAME}/${CHART_VERSION}\"" "$PACKAGE_YAML_PATH"
    yq e -i ".additionalCharts[0].upstreamOptions.commit = \"$COMMIT_SHA\"" "$PACKAGE_YAML_PATH"
  fi
done < "$BRANCH_FILE"

commit_if_changed "chore(charts): Update \`${CHART_NAMES}\` package.yaml"
summary "  - Committed package.yaml changes"
