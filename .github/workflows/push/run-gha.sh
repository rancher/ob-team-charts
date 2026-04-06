#!/usr/bin/env bash
# GHA entry point: orchestrates the full chart update workflow.
# Called from the push.yaml workflow step after chart detection and token generation.
#
# Required env vars (set by push.yaml):
#   NEW_CHARTS  - space-separated "chart/version" pairs
#   GH_TOKEN    - GitHub app token
#   COMMIT_SHA  - source commit SHA
#   OB_DIR      - path to ob-team-charts workspace ($GITHUB_WORKSPACE)
#   CHARTS_DIR  - path to clone charts into ($GITHUB_WORKSPACE/charts-repo)
#   SOURCE_REPO - source repo (github.repository)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_var NEW_CHARTS
require_var GH_TOKEN
require_var COMMIT_SHA

export OB_DIR CHARTS_DIR DRY_RUN BRANCH_DATA_DIR

# --- Clone downstream repo ---
git clone "https://oauth2:${GH_TOKEN}@github.com/rancher/charts.git" "$CHARTS_DIR"
git -C "$CHARTS_DIR" config user.name "github-actions[bot]"
git -C "$CHARTS_DIR" config user.email "github-actions[bot]@users.noreply.github.com"

# --- Download charts-build-scripts binary ---
make -C "$CHARTS_DIR" pull-scripts

# --- Download code-freeze manifest ---
FREEZE_MANIFEST="/tmp/ob-push/code-freeze.yaml"
mkdir -p "$(dirname "$FREEZE_MANIFEST")"
curl -sf -H "Authorization: token $GH_TOKEN" \
  "https://raw.githubusercontent.com/rancher/org/refs/heads/main/manifests/resources/RepositoryRuleset/rancher/code-freeze.yaml" \
  -o "$FREEZE_MANIFEST" || echo "WARNING: Could not fetch code-freeze manifest, freeze checks will be skipped" >&2

# --- Group charts by target branch ---
export NEW_CHARTS
bash "$SCRIPT_DIR/group-by-branch.sh"

summary ""
summary "## Branch Processing"

# --- Process each target branch ---
for branch_file in "$BRANCH_DATA_DIR"/*; do
  TARGET_BRANCH=$(basename "$branch_file")
  summary ""
  summary "### Processing branch: \`$TARGET_BRANCH\`"

  if is_branch_frozen "$TARGET_BRANCH" "$FREEZE_MANIFEST"; then
    MANIFEST_BRANCH=$(echo "$TARGET_BRANCH" | sed 's|dev-v|release/v|')
    summary "- Branch \`$MANIFEST_BRANCH\` is frozen. Skipping."
    continue
  fi

  BRANCH_NAME="bot/update-charts-for-$TARGET_BRANCH-$(date +%s)"
  CHART_NAMES=$(cut -d',' -f1 "$branch_file" | cut -d'/' -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

  git -C "$CHARTS_DIR" checkout -B "$TARGET_BRANCH" "$CHARTS_REMOTE/$TARGET_BRANCH"
  git -C "$CHARTS_DIR" checkout -b "$BRANCH_NAME"

  export TARGET_BRANCH BRANCH_FILE="$branch_file" COMMIT_SHA BRANCH_NAME CHART_NAMES SOURCE_SHA="$COMMIT_SHA" SOURCE_REPO="${SOURCE_REPO:-}"

  summary "- Updating package.yaml files..."
  bash "$SCRIPT_DIR/update-package-yaml.sh" || { summary "- package.yaml update produced no changes, skipping branch."; continue; }

  summary "- Cleaning and preparing chart dependencies..."
  bash "$SCRIPT_DIR/prepare-deps.sh"

  summary "- Updating chart patches..."
  bash "$SCRIPT_DIR/update-patches.sh"

  summary "- Generating initial chart assets..."
  ASSET_LABEL="Initial" bash "$SCRIPT_DIR/generate-assets.sh"

  summary "- Updating kuberlr-kubectl version..."
  bash "$SCRIPT_DIR/update-kuberlr.sh"

  summary "- Generating final chart assets..."
  ASSET_LABEL="Final" bash "$SCRIPT_DIR/generate-assets.sh"

  summary "- Updating release.yaml..."
  bash "$SCRIPT_DIR/update-release-yaml.sh"

  summary "- Pushing changes and creating PR..."
  bash "$SCRIPT_DIR/create-pr.sh"
done

summary ""
summary "## Workflow Complete"
