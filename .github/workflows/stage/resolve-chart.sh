#!/usr/bin/env bash
# Checks a chart of assets/ and works out the Rancher versions it is staged for:
# the dev-v2.X branches (X >= 16, the first Rancher version cargueiro makes charts
# for) that charts-config.yaml maps its Major.Minor to.
#
# Usage: resolve-chart.sh <chart>/<version>
#   e.g. resolve-chart.sh rancher-monitoring/80.9.1-rancher.23
#
# Prints, for $GITHUB_OUTPUT:
#   name=rancher-monitoring
#   version=80.9.1-rancher.23
#   rancher-versions=["2.16"]
set -euo pipefail

OB_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
MIN_RANCHER_MINOR=16

INPUT=${1:?usage: $0 <chart>/<version>}

if ! [[ "$INPUT" =~ ^([a-z0-9]+(-[a-z0-9]+)*)/([0-9]+)\.([0-9]+)\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "::error::'$INPUT' must look like <chart>/<version>, e.g. rancher-monitoring/80.9.1-rancher.23" >&2
  exit 1
fi
NAME="${BASH_REMATCH[1]}"
MAJOR_MINOR="${BASH_REMATCH[3]}.${BASH_REMATCH[4]}"
VERSION="${INPUT#*/}"

ARCHIVE="assets/$NAME/$NAME-$VERSION.tgz"
if [ ! -f "$OB_DIR/$ARCHIVE" ]; then
  echo "::error::There is no $ARCHIVE" >&2
  exit 1
fi

rancher_versions=$(
  NAME="$NAME" MAJOR_MINOR="$MAJOR_MINOR" \
    yq e '.packages[strenv(NAME)][strenv(MAJOR_MINOR)].branches[].branch' "$OB_DIR/charts-config.yaml" |
    sed -n 's/^dev-v2\.\([0-9]\+\)$/\1/p' |
    awk -v min="$MIN_RANCHER_MINOR" '$1 >= min { print "2." $1 }' |
    sort -t. -k2,2n -u
)
if [ -z "$rancher_versions" ]; then
  echo "::error::charts-config.yaml maps $NAME $MAJOR_MINOR to no dev-v2.X branch with X >= $MIN_RANCHER_MINOR" >&2
  exit 1
fi

echo "name=$NAME"
echo "version=$VERSION"
echo "rancher-versions=$(jq -R . <<<"$rancher_versions" | jq -sc .)"
