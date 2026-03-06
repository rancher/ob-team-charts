#!/usr/bin/env bash
# Update release.yaml with new chart versions.
#
# Prerequisites: update-package-yaml.sh — requires ${BRANCH_FILE}.versions written by that script
#
# Inputs (env):
#   CHARTS_DIR    - path to rancher/charts clone (required)
#   BRANCH_FILE   - path to branch data CSV; if unset, auto-derived from TARGET_BRANCH
#   TARGET_BRANCH - branch name (required when BRANCH_FILE is not set)
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_charts_dir
ensure_branch_file

VERSIONS_FILE="${BRANCH_FILE}.versions"
if [ ! -f "$VERSIONS_FILE" ]; then
  echo "ERROR: Versions file $VERSIONS_FILE not found. Run update-package-yaml.sh first." >&2
  exit 1
fi

while IFS=, read -r chart_full_version PACKAGE_PATH; do
  CHART_NAME=$(echo "$chart_full_version" | cut -d'/' -f1)
  CHART_VERSION=$(echo "$chart_full_version" | cut -d'/' -f2)
  NEW_PACKAGE_VERSION=$(grep "^${chart_full_version}=" "$VERSIONS_FILE" | cut -d'=' -f2)

  if [ -z "$NEW_PACKAGE_VERSION" ]; then
    echo "WARNING: No version found for $chart_full_version in $VERSIONS_FILE" >&2
    continue
  fi

  FULL_VERSION="${NEW_PACKAGE_VERSION}+up${CHART_VERSION}"
  yq e -i ".${CHART_NAME} |= [\"${FULL_VERSION}\"] + ." "$CHARTS_DIR/release.yaml"
  summary "  - Added \`$CHART_NAME\`: \`$FULL_VERSION\`"

  CRD_CHART_NAME="${CHART_NAME}-crd"
  if yq e ".${CRD_CHART_NAME}" "$CHARTS_DIR/release.yaml" &>/dev/null; then
    yq e -i ".${CRD_CHART_NAME} |= [\"${FULL_VERSION}\"] + ." "$CHARTS_DIR/release.yaml"
    summary "  - Added \`$CRD_CHART_NAME\`: \`$FULL_VERSION\`"
  fi
done < "$BRANCH_FILE"

if ! git -C "$CHARTS_DIR" diff --quiet --exit-code -- release.yaml; then
  git -C "$CHARTS_DIR" add release.yaml
  git -C "$CHARTS_DIR" commit -m "chore(charts): Update release.yaml"
  summary "  - Committed release.yaml changes"
fi
