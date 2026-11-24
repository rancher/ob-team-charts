#!/usr/bin/env bash
# Local entry point for running the chart update workflow against a local charts clone.
#
# Usage:
#   ./run-local.sh --charts-dir /path/to/rancher/charts [OPTIONS]
#
# Options:
#   --charts-dir DIR      Path to local rancher/charts clone (required)
#   --charts CHARTS       Space-separated "chart/version" pairs to process
#                         If omitted, auto-detects from the diff of the commit (SHA~1..SHA)
#   --commit-sha SHA      Commit SHA to pin in package.yaml. Must exist on GitHub in
#                         SOURCE_REPO, since charts-build-scripts fetches it from there
#   --source-repo REPO    Source repo (default: rancher/ob-team-charts)
#   --remote NAME         Remote name for rancher/charts in CHARTS_DIR (default: origin)
#   --target-branch NAME  Process only this target branch (e.g., dev-v2.9, dev-v2.10)
#                         If omitted, processes all detected target branches
#   --skip-rc             Create a release version instead of an rc
#                         (X.Y.Z-rc.N -> X.Y.Z, X.Y.Z -> X.Y.(Z+1))
#   --dry-run             Skip push and PR creation (all local git work still runs)
#   --help                Show this message
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

usage() {
  sed -n '/^# Usage/,/^[^#]/{ s/^# \{0,1\}//; /^[^#]/d; p }' "$0"
  exit 0
}

COMMIT_SHA=""
SOURCE_REPO="rancher/ob-team-charts"
TARGET_BRANCH_FILTER=""
SKIP_RC="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    --charts-dir)     CHARTS_DIR="$2";           shift 2 ;;
    --charts)         NEW_CHARTS="$2";           shift 2 ;;
    --commit-sha)     COMMIT_SHA="$2";           shift 2 ;;
    --source-repo)    SOURCE_REPO="$2";          shift 2 ;;
    --remote)         CHARTS_REMOTE="$2";        shift 2 ;;
    --target-branch)  TARGET_BRANCH_FILTER="$2"; shift 2 ;;
    --skip-rc)        SKIP_RC="true";            shift ;;
    --dry-run)        DRY_RUN="true";            shift ;;
    --help|-h)        usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

require_charts_dir

# package.yaml pins url: https://github.com/$SOURCE_REPO.git, so the commit must be on
# GitHub; the local HEAD may be an unpushed commit ("upload-pack: not our ref").
SOURCE_URL="https://github.com/$SOURCE_REPO.git"
if [ -z "$COMMIT_SHA" ]; then
  COMMIT_SHA=$(git ls-remote "$SOURCE_URL" refs/heads/main | cut -f1)
  [ -n "$COMMIT_SHA" ] || { echo "ERROR: Could not resolve main of $SOURCE_REPO" >&2; exit 1; }
  echo "Using tip of $SOURCE_REPO main: $COMMIT_SHA"
fi
if ! COMMIT_SHA=$(gh api "repos/$SOURCE_REPO/commits/$COMMIT_SHA" --jq .sha 2>/dev/null); then
  echo "ERROR: Commit ${COMMIT_SHA} is not on GitHub in $SOURCE_REPO. Push it (and merge it to $SOURCE_REPO) or pass --commit-sha." >&2
  exit 1
fi
export CHARTS_DIR OB_DIR DRY_RUN COMMIT_SHA BRANCH_DATA_DIR SOURCE_REPO CHARTS_REMOTE SKIP_RC

# --- Step 1: Detect/validate charts ---
if [ -z "${NEW_CHARTS:-}" ]; then
  # detect-charts.sh diffs locally, so make sure the commit is available
  git -C "$OB_DIR" cat-file -e "${COMMIT_SHA}^{commit}" 2>/dev/null \
    || git -C "$OB_DIR" fetch -q "$SOURCE_URL" "$COMMIT_SHA"
  COMMIT_SHA_BEFORE=$(git -C "$OB_DIR" rev-parse "${COMMIT_SHA}~1")
  export COMMIT_SHA_BEFORE COMMIT_SHA
  NEW_CHARTS=$(bash "$SCRIPT_DIR/detect-charts.sh")
fi

if [ -z "${NEW_CHARTS:-}" ]; then
  echo "No charts detected. Exiting."
  exit 0
fi

for chart in $NEW_CHARTS; do
  if ! gh api "repos/$SOURCE_REPO/contents/charts/$chart/Chart.yaml?ref=$COMMIT_SHA" --silent 2>/dev/null; then
    echo "ERROR: charts/$chart does not exist in $SOURCE_REPO at ${COMMIT_SHA:0:12}. Is it merged to main?" >&2
    exit 1
  fi
done

echo "Charts to process: $NEW_CHARTS"
export NEW_CHARTS

# --- Step 2: Group by branch ---
bash "$SCRIPT_DIR/group-by-branch.sh"

# Branch files are named after the branch (dev-v2.14); skip the side files that steps
# write next to them. Empty when every target branch was skipped (e.g. only dev-v2.16+,
# which cargueiro handles).
shopt -s nullglob
BRANCH_FILES=()
for f in "$BRANCH_DATA_DIR"/*; do
  case "$f" in *.versions|*.rc_removals|*.kept) continue ;; esac
  BRANCH_FILES+=("$f")
done
if [ "${#BRANCH_FILES[@]}" -eq 0 ]; then
  echo "No branches to push to. Exiting."
  exit 0
fi

# --- Step 3: Process each target branch ---
PROCESSED_ANY=false
for branch_file in "${BRANCH_FILES[@]}"; do
  TARGET_BRANCH=$(basename "$branch_file")

  # Skip if --target-branch was specified and this isn't it
  if [ -n "$TARGET_BRANCH_FILTER" ] && [ "$TARGET_BRANCH" != "$TARGET_BRANCH_FILTER" ]; then
    continue
  fi

  PROCESSED_ANY=true
  echo ""
  echo "=== Processing branch: $TARGET_BRANCH ==="

  BRANCH_NAME="bot/update-charts-for-$TARGET_BRANCH-$(date +%s)"
  CHART_NAMES=$(cut -d',' -f1 "$branch_file" | cut -d'/' -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

  git -C "$CHARTS_DIR" checkout -B "$TARGET_BRANCH" "$CHARTS_REMOTE/$TARGET_BRANCH"
  git -C "$CHARTS_DIR" checkout -b "$BRANCH_NAME"

  export TARGET_BRANCH BRANCH_FILE="$branch_file" BRANCH_NAME CHART_NAMES SOURCE_SHA="$COMMIT_SHA"

  echo "--- Updating package.yaml files ---"
  rc=0; bash "$SCRIPT_DIR/update-package-yaml.sh" || rc=$?
  if [ "$rc" -eq 3 ]; then
    echo "All charts already released in $TARGET_BRANCH, skipping branch."
    git -C "$CHARTS_DIR" checkout -q "$TARGET_BRANCH"
    git -C "$CHARTS_DIR" branch -q -D "$BRANCH_NAME"
    continue
  elif [ "$rc" -ne 0 ]; then
    exit "$rc"
  fi
  # update-package-yaml.sh drops already-released charts from BRANCH_FILE
  CHART_NAMES=$(cut -d',' -f1 "$branch_file" | cut -d'/' -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
  export CHART_NAMES

  echo "--- Correct kuberlr patch versions ---"
  bash "$SCRIPT_DIR/correct-kuberlr-patch.sh"

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

  echo "--- Removing superseded rc versions ---"
  bash "$SCRIPT_DIR/remove-old-rc.sh"

  echo "--- Updating release.yaml ---"
  bash "$SCRIPT_DIR/update-release-yaml.sh"

  echo "--- Creating PR ---"
  bash "$SCRIPT_DIR/create-pr.sh"

  echo "=== Done with $TARGET_BRANCH ==="
done

if [ -n "$TARGET_BRANCH_FILTER" ] && [ "$PROCESSED_ANY" = "false" ]; then
  echo ""
  echo "Error: Target branch '$TARGET_BRANCH_FILTER' not found in detected branches."
  echo "Available branches:"
  for branch_file in "${BRANCH_FILES[@]}"; do
    echo "  - $(basename "$branch_file")"
  done
  exit 1
fi

echo ""
echo "Workflow complete."
