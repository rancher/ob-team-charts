#!/usr/bin/env bash
# Maps CHART_NAME/UPSTREAM_VERSION to rancher/charts branch(es) via charts-config.yaml.
# Inputs (env):
#   CHART_NAME       - chart name, e.g. "rancher-monitoring" (required)
#   OB_VERSION       - ob-team-charts chart version, e.g. "80.9.1-rancher.20" (required)
#   UPSTREAM_VERSION - major.minor of OB_VERSION, used to look up charts-config.yaml (required)
#   OB_DIR           - path to ob-team-charts repo (for charts-config.yaml)
set -euo pipefail
source "$(dirname "$0")/../push/common.sh"

require_var CHART_NAME
require_var OB_VERSION
require_var UPSTREAM_VERSION

CONFIG_EXISTS=$(yq e ".packages.$CHART_NAME.\"$UPSTREAM_VERSION\".branches" "$OB_DIR/charts-config.yaml")
if [ "$CONFIG_EXISTS" = "null" ] || [ -z "$CONFIG_EXISTS" ]; then
  echo "ERROR: No configuration found for $CHART_NAME $UPSTREAM_VERSION in charts-config.yaml" >&2
  exit 1
fi

mkdir -p "$BRANCH_DATA_DIR"
rm -rf "${BRANCH_DATA_DIR:?}"/*

CHART_FULL_VERSION="${CHART_NAME}/${OB_VERSION}"

yq e ".packages.$CHART_NAME.\"$UPSTREAM_VERSION\".branches" -o=json "$OB_DIR/charts-config.yaml" \
  | jq -c '.[]' | while read -r branch_config; do
      TARGET_BRANCH=$(echo "$branch_config" | jq -r '.branch')
      CHARTS_PACKAGE_DIR=$(echo "$branch_config" | jq -r '.package')
      echo "${CHART_FULL_VERSION},${CHARTS_PACKAGE_DIR}" >> "$BRANCH_DATA_DIR/$TARGET_BRANCH"
    done

echo "Branch data written to $BRANCH_DATA_DIR:"
ls "$BRANCH_DATA_DIR"
