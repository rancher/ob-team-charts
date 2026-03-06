#!/usr/bin/env bash
# Update kuberlr-kubectl tags in chart values and regenerate patches.
#
# Prerequisites: generate-assets.sh (Initial) — charts must have been built at least once
#
# Inputs (env):
#   CHARTS_DIR    - path to rancher/charts clone (required)
#   TARGET_BRANCH - branch name used to look up the kuberlr-kubectl branch (required)
#   BRANCH_FILE   - path to branch data CSV; if unset, auto-derived from TARGET_BRANCH
#   OB_DIR        - path to ob-team-charts repo (default: auto-detected from script location)
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_charts_dir
require_var TARGET_BRANCH
ensure_branch_file

KUBERLR_BRANCH=$(yq e ".\"kuberlr-kubectl\".\"${TARGET_BRANCH}\"" "$OB_DIR/charts-config.yaml")
if [ "$KUBERLR_BRANCH" = "null" ] || [ -z "$KUBERLR_BRANCH" ]; then
  summary "  - No kuberlr-kubectl branch configured for \`$TARGET_BRANCH\`. Skipping."
  exit 0
fi

if [ -z "${GH_TOKEN:-}" ]; then
  summary "  - GH_TOKEN not set, warning kuberlr-kubectl tag fetch may not work."
fi

KUBERLR_TAG=$(gh api "repos/rancher/kuberlr-kubectl/releases?per_page=100" \
  --jq "[.[] | select(.target_commitish == \"${KUBERLR_BRANCH}\")] | sort_by(.created_at) | last | .tag_name" \
  2>/dev/null || echo "")

if [ -z "$KUBERLR_TAG" ] || [ "$KUBERLR_TAG" = "null" ]; then
  summary "  - No release found for kuberlr-kubectl branch \`$KUBERLR_BRANCH\`. Skipping."
  exit 0
fi

summary "  - Found latest kuberlr-kubectl tag for \`$KUBERLR_BRANCH\`: \`$KUBERLR_TAG\`"

while IFS=, read -r chart_full_version PACKAGE_PATH; do
  make -C "$CHARTS_DIR" prepare PACKAGE="$PACKAGE_PATH" USE_CACHE=true

  for chart_subdir in charts charts-crd; do
    find "$CHARTS_DIR/packages/$PACKAGE_PATH/$chart_subdir" -name "values.yaml" 2>/dev/null \
      | while read -r yaml_file; do
          if grep -q "rancher/kuberlr-kubectl" "$yaml_file"; then
            awk -v tag="$KUBERLR_TAG" '
              /rancher\/kuberlr-kubectl/ { found=1 }
              found && /^[[:space:]]*tag:/ { sub(/tag:.*/, "tag: " tag); found=0 }
              { print }
            ' "$yaml_file" > "${yaml_file}.tmp" && mv "${yaml_file}.tmp" "$yaml_file"
            summary "  - Updated kuberlr-kubectl tag to \`${KUBERLR_TAG}\` in \`$yaml_file\`"
          fi
        done
  done

  make -C "$CHARTS_DIR" patch PACKAGE="$PACKAGE_PATH" USE_CACHE=true
  make -C "$CHARTS_DIR" clean
  summary "  - Regenerated patches for \`$PACKAGE_PATH\`"
done < "$BRANCH_FILE"

commit_if_changed "feat(charts): Update \`kuberlr-kubectl\` tags"
