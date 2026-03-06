#!/usr/bin/env bash
# Group charts by their target branches using charts-config.yaml.
#
# Inputs (env):
#   NEW_CHARTS  - space-separated "chart/version" pairs
#   OB_DIR      - path to ob-team-charts repo (for charts-config.yaml)
#
# Output: creates files at $BRANCH_DATA_DIR/<branch>, each containing
#         comma-separated "chart_full_version,package_path" lines.
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_var NEW_CHARTS

mkdir -p "$BRANCH_DATA_DIR"
rm -rf "${BRANCH_DATA_DIR:?}"/*

VALID_CHARTS_FOUND=false

for chart_full_version in $NEW_CHARTS; do
  CHART_NAME=$(echo "$chart_full_version" | cut -d'/' -f1)
  CHART_VERSION=$(echo "$chart_full_version" | cut -d'/' -f2)
  UPSTREAM_VERSION=$(echo "$CHART_VERSION" | cut -d'.' -f1,2)

  CONFIG_EXISTS=$(yq e ".packages.$CHART_NAME.\"$UPSTREAM_VERSION\".branches" "$OB_DIR/charts-config.yaml")
  if [ "$CONFIG_EXISTS" = "null" ] || [ -z "$CONFIG_EXISTS" ]; then
    summary "WARNING: No configuration found for $CHART_NAME $UPSTREAM_VERSION. Skipping."
    continue
  fi

  VALID_CHARTS_FOUND=true
  yq e ".packages.$CHART_NAME.\"$UPSTREAM_VERSION\".branches" -o=json "$OB_DIR/charts-config.yaml" \
    | jq -c '.[]' | while read -r branch_config; do
        TARGET_BRANCH=$(echo "$branch_config" | jq -r '.branch')
        PACKAGE_PATH=$(echo "$branch_config" | jq -r '.package')
        echo "${chart_full_version},${PACKAGE_PATH}" >> "$BRANCH_DATA_DIR/$TARGET_BRANCH"
    done
done

if [ "$VALID_CHARTS_FOUND" = "false" ]; then
  echo "ERROR: No charts with valid configuration found in charts-config.yaml." >&2
  exit 1
fi

echo "Branch data written to $BRANCH_DATA_DIR:"
ls "$BRANCH_DATA_DIR"
