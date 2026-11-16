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

while IFS=, read -r chart_full_version CHARTS_PACKAGE_DIR; do
  LOCAL_VALUES="$OB_DIR/charts/$chart_full_version/values.yaml"
  KUBERLR_TAG=$(grep kuberlr -A2 $LOCAL_VALUES | grep tag: | awk '{print $2}' | uniq)
  LINE_COUNT=$(echo "$KUBERLR_TAG" | grep -c . || true)
  if [ "$LINE_COUNT" -ne 1 ]; then
    echo "Error: Expected exactly 1 tag, but found $LINE_COUNT:" >&2
    echo "$KUBERLR_TAG" >&2
    exit 1
  fi

  crd_chart_version="${chart_full_version/\//-crd/}"
  LOCAL_CRD_VALUES="$OB_DIR/charts/$crd_chart_version/values.yaml"
  CRD_KUBERLR_TAG=""
  if [ -f "$LOCAL_CRD_VALUES" ]; then
    CRD_KUBERLR_TAG=$(grep kuberlr -A2 $LOCAL_CRD_VALUES | grep tag: | awk '{print $2}' | uniq)
    LINE_COUNT=$(echo "$CRD_KUBERLR_TAG" | grep -c . || true)
    if [ "$LINE_COUNT" -ne 1 ]; then
      echo "Error: Expected exactly 1 tag, but found $LINE_COUNT:" >&2
      echo "$CRD_KUBERLR_TAG" >&2
      exit 1
    fi
  fi


  CHART_NAME=$(echo "$chart_full_version" | cut -d'/' -f1)

  # Process each chart subdirectory
  for chart_subdir in charts charts-crd; do
      target_kuberlr=$KUBERLR_TAG
      # Patch file in CHARTS_DIR (rancher/charts clone) that we need to modify
      PATCH_FILE="$CHARTS_DIR/packages/$CHARTS_PACKAGE_DIR/generated-changes/patch/values.yaml.patch"
      if [ $chart_subdir == "charts-crd" ]; then
        PATCH_FILE="$CHARTS_DIR/packages/$CHARTS_PACKAGE_DIR/generated-changes/additional-charts/charts-crd/generated-changes/patch/values.yaml.patch"
        target_kuberlr=$CRD_KUBERLR_TAG
      fi
      # Only process if patch exists and contains kuberlr references
      if [ ! -f "$PATCH_FILE" ] || ! grep -q "rancher/kuberlr-kubectl" "$PATCH_FILE"; then
        summary "  - No kuberlr-kubectl references in patch. Skipping \`$CHARTS_PACKAGE_DIR\`."
        make -C "$CHARTS_DIR" clean
        continue
      fi

      # Check if the patch already has the correct tag
      CURRENT_PATCH_TAG=$(grep -A1 "rancher/kuberlr-kubectl" "$PATCH_FILE" | grep "^-.*tag:" | awk '{print $NF}' | uniq)
      if [ "$CURRENT_PATCH_TAG" = "$target_kuberlr" ]; then
        summary "  - Patch already has correct tag \`$target_kuberlr\`. Skipping \`$PATCH_FILE\`."
        continue
      fi

      # Update the minus lines in the patch to use the current KUBERLR_TAG
      sed -i.bak 's/^-\([[:space:]]*tag: \).*/\-\1'"$target_kuberlr"'/' "$PATCH_FILE"
      rm -f "$PATCH_FILE.bak"

    summary "  - Updated patch base tag from \`$CURRENT_PATCH_TAG\` to \`$target_kuberlr\` in \`$PATCH_FILE\`"
  done

  make -C "$CHARTS_DIR" clean
done < "$BRANCH_FILE"

commit_if_changed "bug(charts): Correct base \`kuberlr-kubectl\` tag patches"
