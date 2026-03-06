#!/usr/bin/env bash
# Local entry point for running the chart update workflow against a local charts clone.
#
# Usage:
#   ./run-local.sh --charts-dir /path/to/rancher/charts [OPTIONS]
#
# Options:
#   --charts-dir DIR    Path to local rancher/charts clone (required)
#   --charts CHARTS     Space-separated "chart/version" pairs to process
#                       If omitted, auto-detects from git diff (HEAD~1..HEAD) in this repo
#   --commit-sha SHA    Commit SHA to pin in package.yaml (defaults to HEAD of ob-team-charts)
#   --source-repo REPO  Source repo for PR body (default: rancher/ob-team-charts)
#   --remote NAME       Remote name for rancher/charts in CHARTS_DIR (default: origin)
#   --dry-run           Skip push and PR creation (all local git work still runs)
#   --help              Show this message
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

usage() {
  sed -n '/^# Usage/,/^[^#]/{ s/^# \{0,1\}//; /^[^#]/d; p }' "$0"
  exit 0
}

COMMIT_SHA=""
SOURCE_REPO="rancher/ob-team-charts"

while [[ $# -gt 0 ]]; do
  case $1 in
    --charts-dir)  CHARTS_DIR="$2";      shift 2 ;;
    --charts)      NEW_CHARTS="$2";      shift 2 ;;
    --commit-sha)  COMMIT_SHA="$2";      shift 2 ;;
    --source-repo) SOURCE_REPO="$2";     shift 2 ;;
    --remote)      CHARTS_REMOTE="$2";   shift 2 ;;
    --dry-run)     DRY_RUN="true";       shift ;;
    --help|-h)     usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

require_charts_dir

COMMIT_SHA="${COMMIT_SHA:-$(git -C "$OB_DIR" rev-parse HEAD)}"
export CHARTS_DIR OB_DIR DRY_RUN COMMIT_SHA BRANCH_DATA_DIR SOURCE_REPO CHARTS_REMOTE

# --- Step 1: Detect/validate charts ---
if [ -z "${NEW_CHARTS:-}" ]; then
  COMMIT_SHA_BEFORE=$(git -C "$OB_DIR" rev-parse HEAD~1)
  export COMMIT_SHA_BEFORE COMMIT_SHA
  NEW_CHARTS=$(bash "$SCRIPT_DIR/detect-charts.sh")
fi

if [ -z "${NEW_CHARTS:-}" ]; then
  echo "No charts detected. Exiting."
  exit 0
fi

echo "Charts to process: $NEW_CHARTS"
export NEW_CHARTS

# --- Step 2: Group by branch ---
bash "$SCRIPT_DIR/group-by-branch.sh"

# --- Step 3: Process each target branch ---
for branch_file in "$BRANCH_DATA_DIR"/*; do
  TARGET_BRANCH=$(basename "$branch_file")
  echo ""
  echo "=== Processing branch: $TARGET_BRANCH ==="

  BRANCH_NAME="bot/update-charts-for-$TARGET_BRANCH-$(date +%s)"
  CHART_NAMES=$(cut -d',' -f1 "$branch_file" | cut -d'/' -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

  git -C "$CHARTS_DIR" checkout -B "$TARGET_BRANCH" "$CHARTS_REMOTE/$TARGET_BRANCH"
  git -C "$CHARTS_DIR" checkout -b "$BRANCH_NAME"

  export TARGET_BRANCH BRANCH_FILE="$branch_file" BRANCH_NAME CHART_NAMES SOURCE_SHA="$COMMIT_SHA"

  echo "--- Updating package.yaml files ---"
  bash "$SCRIPT_DIR/update-package-yaml.sh" || { echo "No package.yaml changes, skipping branch."; continue; }

  echo "--- Preparing chart dependencies ---"
  bash "$SCRIPT_DIR/prepare-deps.sh"

  echo "--- Updating chart patches ---"
  bash "$SCRIPT_DIR/update-patches.sh"

  echo "--- Generating initial chart assets ---"
  ASSET_LABEL="Initial" bash "$SCRIPT_DIR/generate-assets.sh"

  echo "--- Updating kuberlr-kubectl version ---"
  bash "$SCRIPT_DIR/update-kuberlr.sh"

  echo "--- Generating final chart assets ---"
  ASSET_LABEL="Final" bash "$SCRIPT_DIR/generate-assets.sh"

  echo "--- Updating release.yaml ---"
  bash "$SCRIPT_DIR/update-release-yaml.sh"

  echo "--- Creating PR ---"
  bash "$SCRIPT_DIR/create-pr.sh"

  echo "=== Done with $TARGET_BRANCH ==="
done

echo ""
echo "Workflow complete."
