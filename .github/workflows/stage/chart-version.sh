#!/usr/bin/env bash
# Works out the final version of the charts of a family with cargueiro
# chart-version, for the version of assets/ they are built from.
#
# rancher/charts versions these charts 1XY.Z.W+up<version of assets/>, such as
# 110.0.2+up80.9.1-rancher.22, but chart-version takes the +up part from the
# appVersion, which is not that version (rancher-monitoring has v0.87.1). So it
# is run on copies whose main chart has the version of assets/ as appVersion; the
# charts themselves keep their appVersion, which their images use.
#
# Usage: chart-version.sh <family> <version> <chart dir>...
#   e.g. chart-version.sh rancher-monitoring 80.9.1-rancher.23 \
#          "$RUNNER_TEMP/charts/rancher-monitoring" "$RUNNER_TEMP/charts/rancher-monitoring-crd"
#
# Prints the version, such as 111.0.0+up80.9.1-rancher.23. Requires cargueiro and
# yq on PATH.
set -euo pipefail

usage="usage: $0 <family> <version> <chart dir>..."
FAMILY=${1:?$usage}
VERSION=${2:?$usage}
shift 2
[ "$#" -gt 0 ] || { echo "$usage" >&2; exit 1; }

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

copies=()
for dir in "$@"; do
  name=$(yq e '.name' "$dir/Chart.yaml")
  cp -r "$dir" "$scratch/$name"
  if [ "$name" = "$FAMILY" ]; then
    VERSION="$VERSION" yq e -i '.appVersion = strenv(VERSION)' "$scratch/$name/Chart.yaml"
  fi
  copies+=("$scratch/$name")
done

cargueiro chart-version --family "$FAMILY" "${copies[@]}"
