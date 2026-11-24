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
#   SKIP_RC       - when "true", bump to a release version instead of an rc:
#                   X.Y.Z-rc.N -> X.Y.Z (the rc is superseded), X.Y.Z -> X.Y.(Z+1)
#
# Output: git commit in CHARTS_DIR; writes versions to ${BRANCH_FILE}.versions;
#         writes superseded rc versions (chart bumped from one rc to the next) to ${BRANCH_FILE}.rc_removals
#
# Charts whose version is already released in the target branch (a
# charts/<chart>/*+up<version> directory exists) are skipped and removed from
# BRANCH_FILE, so later steps don't touch them. With SKIP_RC=true only an existing
# release (not an rc) counts, so an rc of that version can be promoted.
#
# Exit codes: 0 = updated, 3 = nothing left to update in this branch (skip it), other = error
set -euo pipefail
source "$(dirname "$0")/common.sh"

SKIP_RC="${SKIP_RC:-false}"
EXIT_NOTHING_TO_DO=3

# Prints the existing charts/<chart>/<pkg>+up<version> directories of the target branch
existing_versions() {
  local chart="$1" version="$2"
  find "$CHARTS_DIR/charts/$chart" -mindepth 1 -maxdepth 1 -type d -name "*+up${version}" \
    -exec basename {} \; 2>/dev/null | sort -V
}

require_charts_dir
require_var COMMIT_SHA
ensure_branch_file

# Clear versions/rc_removals files for this branch
> "${BRANCH_FILE}.versions"
> "${BRANCH_FILE}.rc_removals"
KEPT_FILE="${BRANCH_FILE}.kept"
> "$KEPT_FILE"

while IFS=, read -r chart_full_version CHARTS_PACKAGE_DIR; do
  CHART_NAME=$(echo "$chart_full_version" | cut -d'/' -f1)
  CHART_VERSION=$(echo "$chart_full_version" | cut -d'/' -f2)
  PACKAGE_YAML_PATH="$CHARTS_DIR/packages/$CHARTS_PACKAGE_DIR/package.yaml"

  if [ ! -f "$PACKAGE_YAML_PATH" ]; then
    echo "WARNING: package.yaml not found at $PACKAGE_YAML_PATH" >&2
    continue
  fi

  EXISTING=$(existing_versions "$CHART_NAME" "$CHART_VERSION")
  if [ "$SKIP_RC" = "true" ]; then
    EXISTING=$(echo "$EXISTING" | grep -v -- '-rc\.' || true)
  fi
  if [ -n "$EXISTING" ]; then
    summary "  - \`$CHART_NAME\` \`$CHART_VERSION\` is already in \`${TARGET_BRANCH:-target branch}\` as \`$(echo "$EXISTING" | tr '\n' ' ' | sed 's/ $//')\`. Skipping."
    continue
  fi

  yq e -i ".subdirectory = \"charts/$CHART_NAME/$CHART_VERSION\"" "$PACKAGE_YAML_PATH"
  yq e -i ".commit = \"$COMMIT_SHA\"" "$PACKAGE_YAML_PATH"

  CURRENT_VERSION=$(yq e '.version' "$PACKAGE_YAML_PATH")
  IS_RC_BUMP=false
  if [[ "$CURRENT_VERSION" == *"-rc."* ]]; then
    # Either way the current rc is superseded and gets removed
    IS_RC_BUMP=true
    if [ "$SKIP_RC" = "true" ]; then
      NEW_VERSION="${CURRENT_VERSION%%-rc.*}"
    else
      NEW_VERSION=$(echo "$CURRENT_VERSION" | awk -F- '{split($2, a, "."); print $1"-rc."a[2]+1}')
    fi
  elif [ "$SKIP_RC" = "true" ]; then
    NEW_VERSION=$(echo "$CURRENT_VERSION" | awk -F. '{print $1"."$2"."$3+1}')
  else
    NEW_VERSION=$(echo "$CURRENT_VERSION" | awk -F. '{print $1"."$2"."$3+1"-rc.1"}')
  fi

  yq e -i ".version = \"$NEW_VERSION\"" "$PACKAGE_YAML_PATH"
  echo "${chart_full_version},${CHARTS_PACKAGE_DIR}" >> "$KEPT_FILE"
  echo "${chart_full_version}=${NEW_VERSION}" >> "${BRANCH_FILE}.versions"
  summary "  - Updated \`$CHARTS_PACKAGE_DIR\` to version \`$NEW_VERSION\`"

  if [ "$IS_RC_BUMP" = "true" ]; then
    echo "${CHART_NAME},${CURRENT_VERSION}" >> "${BRANCH_FILE}.rc_removals"
  fi

  if [ "$(yq e '.additionalCharts | has(0)' "$PACKAGE_YAML_PATH")" = "true" ]; then
    CRD_CHART_NAME="${CHART_NAME}-crd"
    yq e -i ".additionalCharts[0].upstreamOptions.subdirectory = \"charts/${CRD_CHART_NAME}/${CHART_VERSION}\"" "$PACKAGE_YAML_PATH"
    yq e -i ".additionalCharts[0].upstreamOptions.commit = \"$COMMIT_SHA\"" "$PACKAGE_YAML_PATH"

    if [ "$IS_RC_BUMP" = "true" ]; then
      echo "${CRD_CHART_NAME},${CURRENT_VERSION}" >> "${BRANCH_FILE}.rc_removals"
    fi
  fi
done < "$BRANCH_FILE"

# Later steps read BRANCH_FILE: keep only the charts that were updated
mv "$KEPT_FILE" "$BRANCH_FILE"
if [ ! -s "$BRANCH_FILE" ]; then
  summary "  - Nothing to update in \`${TARGET_BRANCH:-target branch}\`."
  exit "$EXIT_NOTHING_TO_DO"
fi

CHART_NAMES=$(cut -d',' -f1 "$BRANCH_FILE" | cut -d'/' -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
commit_if_changed "chore(charts): Update \`${CHART_NAMES}\` package.yaml"
summary "  - Committed package.yaml changes"
