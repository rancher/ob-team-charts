#!/usr/bin/env bash
# Detect which charts have changed.
#
# Inputs (env):
#   NEW_CHARTS         - if set, used as-is (manual override)
#   COMMIT_SHA_BEFORE  - base commit for diff (required if NEW_CHARTS not set)
#   COMMIT_SHA         - head commit for diff (required if NEW_CHARTS not set)
#
# Output: space-separated list of "chart/version" pairs echoed to stdout.
#         Also writes to $GITHUB_OUTPUT if that env var is set.
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [ -n "${NEW_CHARTS:-}" ]; then
  echo "Using manually specified charts: $NEW_CHARTS"
  RESULT="$NEW_CHARTS"
else
  require_var COMMIT_SHA_BEFORE
  require_var COMMIT_SHA

  git -C "$OB_DIR" fetch origin "$COMMIT_SHA_BEFORE" 2>/dev/null || true
  RESULT=$(git -C "$OB_DIR" diff --name-only "$COMMIT_SHA_BEFORE" "$COMMIT_SHA" \
    | grep -E '^charts/(rancher-monitoring|rancher-logging)/[^/]*/Chart.yaml$' \
    | sed -e 's|charts/\(.*\)/\(.*\)/Chart.yaml|\1/\2|' \
    | tr '\n' ' ' | sed 's/ $//')
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "new_charts=${RESULT}" >> "$GITHUB_OUTPUT"
fi

echo "$RESULT"
