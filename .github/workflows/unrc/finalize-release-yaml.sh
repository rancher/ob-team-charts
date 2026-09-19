#!/usr/bin/env bash
# Replace the superseded rc entries in release.yaml with the new release version.
# Inputs (env):
#   CHARTS_DIR    - path to rancher/charts clone (required)
#   BASE_VERSION  - the (non-rc) version that was just released (required)
#   BRANCH_FILE   - path to branch data file; if unset, auto-derived from TARGET_BRANCH
#   TARGET_BRANCH - branch name (required when BRANCH_FILE is not set)
set -euo pipefail
source "$(dirname "$0")/../push/common.sh"

require_charts_dir
require_var BASE_VERSION
ensure_branch_file

VERSIONS_FILE="${BRANCH_FILE}.versions"
if [ ! -f "$VERSIONS_FILE" ]; then
  echo "ERROR: Versions file $VERSIONS_FILE not found. Run promote-version.sh first." >&2
  exit 1
fi

while IFS=, read -r chart_full_version CHARTS_PACKAGE_DIR; do
  CHART_NAME=$(echo "$chart_full_version" | cut -d'/' -f1)
  OB_VERSION=$(echo "$chart_full_version" | cut -d'/' -f2)
  PACKAGE_YAML_PATH="$CHARTS_DIR/packages/$CHARTS_PACKAGE_DIR/package.yaml"
  FULL_VERSION="${BASE_VERSION}+up${OB_VERSION}"

  NAMES_TO_CHECK=("$CHART_NAME")
  if [ "$(yq e '.additionalCharts | has(0)' "$PACKAGE_YAML_PATH")" = "true" ]; then
    NAMES_TO_CHECK+=("${CHART_NAME}-crd")
  fi

  for NAME in "${NAMES_TO_CHECK[@]}"; do
    yq e -i "del(.${NAME}[] | select(test(\"^${BASE_VERSION}-rc\\.[0-9]+\\+up${OB_VERSION}\$\")))" "$CHARTS_DIR/release.yaml"
    yq e -i ".${NAME} |= [\"${FULL_VERSION}\"] + ." "$CHARTS_DIR/release.yaml"
    summary "  - Set \`$NAME\` release.yaml entry to \`$FULL_VERSION\`"
  done
done < "$BRANCH_FILE"

if ! git -C "$CHARTS_DIR" diff --quiet --exit-code -- release.yaml; then
  git -C "$CHARTS_DIR" add release.yaml
  git -C "$CHARTS_DIR" commit -m "chore(charts): Update release.yaml"
  summary "  - Committed release.yaml changes"
fi
