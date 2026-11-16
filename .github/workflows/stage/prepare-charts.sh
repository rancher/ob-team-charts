#!/usr/bin/env bash
# Prepares the charts of a chart version of assets/ for the ship-family-staged
# action of rancher/charts, for one Rancher version: extracts the chart and its
# -crd chart, when there is one, to <output dir>, and sets in them what
# rancher/charts used to set in the dev-v2.X branch of that Rancher version:
#   - rancher-version: ">= 2.X.0-0 < 2.(X+1).0-0"
#   - kube-version: from rancher-versions in charts-config.yaml
#   - the icon: cargueiro needs an http(s) address, so a logo of assets/logos is
#     given by its address in this repository at this commit
#   - the tag of every kuberlr-kubectl image: the latest release of the major of
#     the branch that kuberlr-kubectl in charts-config.yaml gives for dev-v2.X
# The archives in assets/ stay as they are.
#
# Usage: prepare-charts.sh <chart> <version> <rancher version> <output dir>
#   e.g. prepare-charts.sh rancher-monitoring 80.9.1-rancher.23 2.16 "$RUNNER_TEMP/charts"
#
# Prints the folders of the charts, one to a line, the main chart first.
#
# Environment:
#   GH_TOKEN           can read the releases of rancher/kuberlr-kubectl
#   GITHUB_REPOSITORY  this repository (default: rancher/ob-team-charts)
#   GITHUB_SHA         the commit the icon address points at (default: HEAD)
set -euo pipefail

OB_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
CONFIG="$OB_DIR/charts-config.yaml"
REPOSITORY=${GITHUB_REPOSITORY:-rancher/ob-team-charts}
SHA=${GITHUB_SHA:-$(git -C "$OB_DIR" rev-parse HEAD)}

usage="usage: $0 <chart> <version> <rancher version> <output dir>"
CHART=${1:?$usage}
VERSION=${2:?$usage}
RANCHER_VERSION=${3:?$usage}
OUT_DIR=${4:?$usage}

fail() {
  echo "::error::$1" >&2
  exit 1
}

[[ "$CHART" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "The chart '$CHART' is not a chart name"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || fail "The version '$VERSION' must look like X.Y.Z or X.Y.Z-rancher.N"
[[ "$RANCHER_VERSION" =~ ^2\.([0-9]+)$ ]] || fail "The Rancher version '$RANCHER_VERSION' must look like 2.X"
RANCHER_MINOR="${BASH_REMATCH[1]}"

KUBE_VERSION=$(RV="$RANCHER_VERSION" yq e '.rancher-versions[strenv(RV)].kube-version // ""' "$CONFIG")
KUBERLR_BRANCH=$(BRANCH="dev-v$RANCHER_VERSION" yq e '.kuberlr-kubectl[strenv(BRANCH)] // ""' "$CONFIG")
[ -n "$KUBE_VERSION" ] || fail "charts-config.yaml has no rancher-versions.\"$RANCHER_VERSION\".kube-version"

charts=("$CHART")
if [ -f "$OB_DIR/assets/$CHART-crd/$CHART-crd-$VERSION.tgz" ]; then
  charts+=("$CHART-crd")
fi

mkdir -p "$OUT_DIR"
for chart in "${charts[@]}"; do
  archive="$OB_DIR/assets/$chart/$chart-$VERSION.tgz"
  [ -f "$archive" ] || fail "There is no assets/$chart/$chart-$VERSION.tgz"
  rm -rf "${OUT_DIR:?}/$chart"
  tar -xzf "$archive" -C "$OUT_DIR"
  [ -f "$OUT_DIR/$chart/Chart.yaml" ] || fail "assets/$chart/$chart-$VERSION.tgz has no $chart/Chart.yaml"
done

main_chart="$OUT_DIR/$CHART/Chart.yaml"
RANCHER_RANGE=">= 2.${RANCHER_MINOR}.0-0 < 2.$((RANCHER_MINOR + 1)).0-0"
RANCHER_RANGE="$RANCHER_RANGE" KUBE_VERSION="$KUBE_VERSION" yq e -i '
  .annotations."catalog.cattle.io/rancher-version" = strenv(RANCHER_RANGE) |
  .annotations."catalog.cattle.io/kube-version" = strenv(KUBE_VERSION)
' "$main_chart"

# The logo is the file of a file://assets/logos/ icon, or assets/logos/<chart>.*
# for a chart with no icon. An http(s) icon is kept.
icon=$(yq e '.icon // ""' "$main_chart")
case "$icon" in
  http://* | https://*) logo="" ;;
  file://assets/logos/*) logo="${icon#file://assets/logos/}" ;;
  "") logo=$(find "$OB_DIR/assets/logos" -maxdepth 1 -name "$CHART.*" -exec basename {} \; | sort | head -1) ;;
  *) fail "The icon '$icon' of $CHART is neither an http(s) address nor a file of assets/logos" ;;
esac
if [ -n "$logo" ] || [ -z "$icon" ]; then
  [ -n "$logo" ] && [ -f "$OB_DIR/assets/logos/$logo" ] || fail "$CHART has no logo in assets/logos (icon: '$icon')"
  ICON="https://raw.githubusercontent.com/$REPOSITORY/$SHA/assets/logos/$logo" yq e -i '.icon = strenv(ICON)' "$main_chart"
fi

mapfile -t kuberlr_values < <(grep -rl --include=values.yaml 'rancher/kuberlr-kubectl' "${charts[@]/#/$OUT_DIR/}" || true)
if [ "${#kuberlr_values[@]}" -gt 0 ]; then
  [ -n "$KUBERLR_BRANCH" ] || fail "charts-config.yaml has no kuberlr-kubectl.\"dev-v$RANCHER_VERSION\", and $CHART has kuberlr-kubectl images"
  # By the major of the branch, not by the branch the release was cut from:
  # the releases of a major can be cut from main before its release branch exists.
  [[ "$KUBERLR_BRANCH" =~ ^release/(v[0-9]+)\.x$ ]] || fail "The kuberlr-kubectl branch '$KUBERLR_BRANCH' must look like release/vN.x"
  KUBERLR_MAJOR="${BASH_REMATCH[1]}"
  kuberlr_tag=$(
    gh api --paginate "repos/rancher/kuberlr-kubectl/releases?per_page=100" \
      --jq '.[] | select(.draft == false and .prerelease == false) | .tag_name' |
      grep -E "^${KUBERLR_MAJOR}\.[0-9]+\.[0-9]+$" | sort -V | tail -1
  ) || true
  [ -n "$kuberlr_tag" ] || fail "rancher/kuberlr-kubectl has no release ${KUBERLR_MAJOR}.Y.Z"

  # The tag line that follows the repository line, as update-kuberlr.sh does, so
  # the rest of values.yaml stays byte for byte as it is.
  for values in "${kuberlr_values[@]}"; do
    awk -v tag="$kuberlr_tag" '
      /rancher\/kuberlr-kubectl/ { found = 1 }
      found && /^[[:space:]]*tag:/ { sub(/tag:.*/, "tag: " tag); found = 0 }
      { print }
    ' "$values" > "$values.tmp"
    mv "$values.tmp" "$values"
    wrong=$(TAG="$kuberlr_tag" yq e '[.. | select(tag == "!!map" and (.repository // "" | test("rancher/kuberlr-kubectl$")) and .tag != strenv(TAG))] | length' "$values")
    [ "$wrong" = 0 ] || fail "$wrong kuberlr-kubectl images of ${values#"$OUT_DIR"/} were not set to $kuberlr_tag"
  done
  echo "kuberlr-kubectl: $kuberlr_tag in ${#kuberlr_values[@]} values.yaml" >&2
fi

echo "Prepared ${charts[*]} $VERSION for Rancher $RANCHER_VERSION in $OUT_DIR" >&2
printf '%s\n' "${charts[@]/#/$OUT_DIR/}"
