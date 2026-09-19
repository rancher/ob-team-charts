#!/usr/bin/env bash
# Local entry point for promoting a chart's rc version to a release version
# against a local rancher/charts clone.
#
# Usage:
#   ./run-local.sh --charts-dir /path/to/rancher/charts --chart rancher-monitoring \
#       --version 110.0.2-rc.1+up80.9.1-rancher.20 [OPTIONS]
#
# Options:
#   --charts-dir DIR   Path to local rancher/charts clone (required)
#   --chart NAME       Chart name, e.g. rancher-monitoring (required)
#   --version VERSION  <rancher_version>[-rc.N]+up<ob_version> (required)
#   --source-repo REPO Source repo for PR body (default: rancher/ob-team-charts)
#   --remote NAME      Remote name for rancher/charts in CHARTS_DIR (default: origin)
#   --dry-run          Skip push and PR creation (all local git work still runs)
#   --help             Show this message
set -euo pipefail

UNRC_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUSH_SCRIPT_DIR="$(cd "$UNRC_SCRIPT_DIR/../push" && pwd)"
source "$PUSH_SCRIPT_DIR/common.sh"

usage() {
  sed -n '/^# Usage/,/^[^#]/{ s/^# \{0,1\}//; /^[^#]/d; p }' "$0"
  exit 0
}

SOURCE_REPO="rancher/ob-team-charts"
CHART_NAME=""
UNRC_VERSION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --charts-dir)   CHARTS_DIR="$2";     shift 2 ;;
    --chart)        CHART_NAME="$2";     shift 2 ;;
    --version)      UNRC_VERSION="$2";   shift 2 ;;
    --source-repo)  SOURCE_REPO="$2";    shift 2 ;;
    --remote)       CHARTS_REMOTE="$2";  shift 2 ;;
    --dry-run)      DRY_RUN="true";      shift ;;
    --help|-h)      usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

require_charts_dir
require_var CHART_NAME
require_var UNRC_VERSION

if [[ "$UNRC_VERSION" != *"+up"* ]]; then
  echo "ERROR: --version must be in the form <rancher_version>[-rc.N]+up<ob_version>, got '$UNRC_VERSION'" >&2
  exit 1
fi

RANCHER_VERSION_RAW="${UNRC_VERSION%%+up*}"
OB_VERSION="${UNRC_VERSION#*+up}"
BASE_VERSION=$(echo "$RANCHER_VERSION_RAW" | sed -E 's/-rc\.[0-9]+$//')
UPSTREAM_VERSION=$(echo "$OB_VERSION" | cut -d'.' -f1,2)

export CHARTS_DIR OB_DIR DRY_RUN BRANCH_DATA_DIR SOURCE_REPO CHARTS_REMOTE
export CHART_NAME UNRC_VERSION BASE_VERSION OB_VERSION UPSTREAM_VERSION

echo "Chart: $CHART_NAME"
echo "Requested version: $UNRC_VERSION"
echo "Release version: $BASE_VERSION"

echo ""
echo "=== Resolving target branch ==="
bash "$UNRC_SCRIPT_DIR/resolve-target.sh"

for branch_file in "$BRANCH_DATA_DIR"/*; do
  TARGET_BRANCH=$(basename "$branch_file")
  echo ""
  echo "=== Processing branch: $TARGET_BRANCH ==="

  BRANCH_NAME="bot/unrc-$TARGET_BRANCH-$(date +%s)"
  CHART_NAMES=$(cut -d',' -f1 "$branch_file" | cut -d'/' -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

  git -C "$CHARTS_DIR" checkout -B "$TARGET_BRANCH" "$CHARTS_REMOTE/$TARGET_BRANCH"
  git -C "$CHARTS_DIR" checkout -b "$BRANCH_NAME"

  export TARGET_BRANCH BRANCH_FILE="$branch_file" BRANCH_NAME CHART_NAMES SOURCE_SHA="${OB_VERSION}"

  echo "--- Promoting package.yaml ---"
  bash "$UNRC_SCRIPT_DIR/promote-version.sh"

  echo "--- Generating release chart assets ---"
  ASSET_LABEL="Release" bash "$PUSH_SCRIPT_DIR/generate-assets.sh"

  echo "--- Removing superseded rc versions ---"
  bash "$UNRC_SCRIPT_DIR/remove-superseded-rc.sh"

  echo "--- Updating release.yaml ---"
  bash "$UNRC_SCRIPT_DIR/finalize-release-yaml.sh"

  echo "--- Creating PR ---"
  PR_TITLE="chore(charts): Release \`${CHART_NAMES}\` \`${BASE_VERSION}\` for $TARGET_BRANCH" \
    PR_BODY="Automated PR promoting \`${CHART_NAMES}\` \`${UNRC_VERSION}\` to release version \`${BASE_VERSION}\`, triggered from ${SOURCE_REPO}." \
    bash "$PUSH_SCRIPT_DIR/create-pr.sh"

  echo "=== Done with $TARGET_BRANCH ==="
done

echo ""
echo "Workflow complete."
