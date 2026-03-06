#!/usr/bin/env bash
# Push the working branch and open a PR against the target branch.
#
# Inputs (env):
#   CHARTS_DIR     - path to rancher/charts clone
#   TARGET_BRANCH  - base branch for the PR
#   BRANCH_NAME    - working branch to push
#   CHART_NAMES    - human-readable chart name(s) for the PR title
#   SOURCE_REPO    - source repo for PR body (e.g. "rancher/ob-team-charts")
#   SOURCE_SHA     - source commit SHA for PR body
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_charts_dir
require_var TARGET_BRANCH
require_var BRANCH_NAME
require_var CHART_NAMES

SOURCE_REPO="${SOURCE_REPO:-unknown}"
SOURCE_SHA="${SOURCE_SHA:-unknown}"

PR_TITLE="chore(charts): Update \`${CHART_NAMES}\` from upstream for $TARGET_BRANCH"
PR_BODY="Automated PR to update charts from ${SOURCE_REPO} commit ${SOURCE_SHA}"

if [ "$DRY_RUN" = "true" ]; then
  echo "[DRY RUN] Skipping push and PR creation."
  echo "  Branch: $BRANCH_NAME"
  echo "  Title:  $PR_TITLE"
  echo "  Base:   $TARGET_BRANCH"
  echo "All commits are in your local $CHARTS_DIR checkout."
  exit 0
fi

git -C "$CHARTS_DIR" push "$CHARTS_REMOTE" "$BRANCH_NAME"
PR_URL=$(gh pr create \
  --title "$PR_TITLE" \
  --body "$PR_BODY" \
  --base "$TARGET_BRANCH" \
  --head "$BRANCH_NAME" \
  --repo rancher/charts)

summary "  - Created PR: $PR_URL"
echo "$PR_URL"
