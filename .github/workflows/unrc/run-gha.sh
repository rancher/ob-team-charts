#!/usr/bin/env bash

# Required env vars:
#   CHART_NAME  - chart name, e.g. "rancher-monitoring"
#   UNRC_VERSION - version to unrc, e.g. "110.0.2-rc.1+up80.9.1-rancher.20"
#   GH_TOKEN    - GitHub app token
#   OB_DIR      - path to ob-team-charts workspace ($GITHUB_WORKSPACE)
#   CHARTS_DIR  - path to clone charts into ($GITHUB_WORKSPACE/charts-repo)
#   SOURCE_REPO - source repo (github.repository)
set -euo pipefail

UNRC_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUSH_SCRIPT_DIR="$(cd "$UNRC_SCRIPT_DIR/../push" && pwd)"
source "$PUSH_SCRIPT_DIR/common.sh"

require_var CHART_NAME
require_var UNRC_VERSION
require_var GH_TOKEN

export OB_DIR CHARTS_DIR DRY_RUN BRANCH_DATA_DIR

if [[ "$UNRC_VERSION" != *"+up"* ]]; then
  echo "ERROR: VERSION must be in the form <rancher_version>[-rc.N]+up<ob_version>, got '$UNRC_VERSION'" >&2
  exit 1
fi

RANCHER_VERSION_RAW="${UNRC_VERSION%%+up*}"
OB_VERSION="${UNRC_VERSION#*+up}"
BASE_VERSION=$(echo "$RANCHER_VERSION_RAW" | sed -E 's/-rc\.[0-9]+$//')
UPSTREAM_VERSION=$(echo "$OB_VERSION" | cut -d'.' -f1,2)

export BASE_VERSION OB_VERSION UPSTREAM_VERSION

summary "### Un-RC Target"
summary "- Chart: \`$CHART_NAME\`"
summary "- Requested version: \`$UNRC_VERSION\`"
summary "- Release version: \`$BASE_VERSION\`"

git clone "https://oauth2:${GH_TOKEN}@github.com/rancher/charts.git" "$CHARTS_DIR"
git -C "$CHARTS_DIR" config user.name "github-actions[bot]"
git -C "$CHARTS_DIR" config user.email "github-actions[bot]@users.noreply.github.com"

make -C "$CHARTS_DIR" pull-scripts

summary ""
summary "## Resolving target branch"
bash "$UNRC_SCRIPT_DIR/resolve-target.sh"

summary ""
summary "## Branch Processing"

for branch_file in "$BRANCH_DATA_DIR"/*; do
  TARGET_BRANCH=$(basename "$branch_file")
  summary ""
  summary "### Processing branch: \`$TARGET_BRANCH\`"

  BRANCH_NAME="bot/unrc-$TARGET_BRANCH-$(date +%s)"
  CHART_NAMES=$(cut -d',' -f1 "$branch_file" | cut -d'/' -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

  git -C "$CHARTS_DIR" checkout -B "$TARGET_BRANCH" "$CHARTS_REMOTE/$TARGET_BRANCH"
  git -C "$CHARTS_DIR" checkout -b "$BRANCH_NAME"

  export TARGET_BRANCH BRANCH_FILE="$branch_file" BRANCH_NAME CHART_NAMES SOURCE_SHA="${OB_VERSION}" SOURCE_REPO="${SOURCE_REPO:-}"

  summary "- Promoting package.yaml to \`$BASE_VERSION\`..."
  bash "$UNRC_SCRIPT_DIR/promote-version.sh"

  summary "- Generating release chart assets..."
  ASSET_LABEL="Release" bash "$PUSH_SCRIPT_DIR/generate-assets.sh"

  summary "- Removing superseded rc versions..."
  bash "$UNRC_SCRIPT_DIR/remove-superseded-rc.sh"

  summary "- Updating release.yaml..."
  bash "$UNRC_SCRIPT_DIR/finalize-release-yaml.sh"

  summary "- Pushing changes and creating PR..."
  PR_TITLE="chore(charts): Release \`${CHART_NAMES}\` \`${BASE_VERSION}\` for $TARGET_BRANCH" \
    PR_BODY="Automated PR promoting \`${CHART_NAMES}\` \`${UNRC_VERSION}\` to release version \`${BASE_VERSION}\`, triggered from ${SOURCE_REPO:-unknown}." \
    bash "$PUSH_SCRIPT_DIR/create-pr.sh"
done

summary ""
summary "## Workflow Complete"
