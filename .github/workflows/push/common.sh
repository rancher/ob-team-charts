#!/usr/bin/env bash
# Shared setup for push scripts. Source this file: source "$(dirname "$0")/common.sh"

# Determine OB_DIR (ob-team-charts root) from this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OB_DIR="${OB_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

# Required: path to a local rancher/charts clone
CHARTS_DIR="${CHARTS_DIR:-}"

# Remote name for rancher/charts in CHARTS_DIR (may differ locally if using a fork)
CHARTS_REMOTE="${CHARTS_REMOTE:-origin}"

# Skip git commits, push, and PR creation when true
DRY_RUN="${DRY_RUN:-false}"

# Temp dir for branch data files
BRANCH_DATA_DIR="${BRANCH_DATA_DIR:-/tmp/ob-push/branch_data}"

# Write to GitHub step summary if available, and always print to stdout
summary() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "$@" >> "$GITHUB_STEP_SUMMARY"
  fi
  echo "$@"
}

require_var() {
  local var="$1"
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is required" >&2
    exit 1
  fi
}

require_charts_dir() {
  require_var CHARTS_DIR
  if [ ! -d "$CHARTS_DIR" ]; then
    echo "ERROR: CHARTS_DIR '$CHARTS_DIR' does not exist" >&2
    exit 1
  fi
}

# Commit all changes in CHARTS_DIR if any exist. Does nothing if tree is clean.
commit_if_changed() {
  local message="$1"
  if git -C "$CHARTS_DIR" diff --quiet --exit-code && [ -z "$(git -C "$CHARTS_DIR" status --porcelain)" ]; then
    return 0
  fi
  git -C "$CHARTS_DIR" add .
  git -C "$CHARTS_DIR" commit -m "$message"
}

# Ensures BRANCH_FILE is set to a valid CSV branch data file.
# If BRANCH_FILE is unset or missing, auto-derives it from TARGET_BRANCH + charts-config.yaml.
# Writes derived file to $BRANCH_DATA_DIR/$TARGET_BRANCH and exports BRANCH_FILE.
#
# Each step script that needs BRANCH_FILE should call this instead of require_var BRANCH_FILE.
# To run a step script standalone, set TARGET_BRANCH (and optionally CHARTS_DIR, OB_DIR).
# To run as part of the full workflow, set BRANCH_FILE to the pre-generated branch data file.
ensure_branch_file() {
  if [ -n "${BRANCH_FILE:-}" ] && [ -f "$BRANCH_FILE" ] && [ -s "$BRANCH_FILE" ]; then
    return 0
  fi
  require_var TARGET_BRANCH
  mkdir -p "$BRANCH_DATA_DIR"
  local derived="$BRANCH_DATA_DIR/$TARGET_BRANCH"
  yq e '.packages' -o=json "$OB_DIR/charts-config.yaml" \
    | jq -r 'to_entries[] | .key as $chart | .value | to_entries[] | .key as $version
             | .value.branches[] | select(.branch == "'"$TARGET_BRANCH"'")
             | ($chart + "/" + $version + "," + .package)' \
    > "$derived"
  if [ ! -s "$derived" ]; then
    echo "ERROR: No charts configured for TARGET_BRANCH='$TARGET_BRANCH' in charts-config.yaml" >&2
    exit 1
  fi
  export BRANCH_FILE="$derived"
  echo "  (auto-derived BRANCH_FILE for $TARGET_BRANCH → $BRANCH_FILE)"
}

# Returns 0 if the given TARGET_BRANCH is frozen, 1 otherwise.
is_branch_frozen() {
  local target_branch="$1"
  local freeze_manifest="${2:-/tmp/ob-push/code-freeze.yaml}"
  if [ ! -f "$freeze_manifest" ]; then
    return 1
  fi
  local manifest_branch_name
  manifest_branch_name=$(echo "$target_branch" | sed 's|dev-v|release/v|')
  local manifest_ref="refs/heads/$manifest_branch_name"
  local result
  result=$(yq e ".spec.forProvider.conditions[].refName[].include[] | select(. == \"$manifest_ref\")" "$freeze_manifest")
  [ -n "$result" ]
}
