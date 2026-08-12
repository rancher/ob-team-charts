# ob-team-charts

This repository contains Helm charts maintained by the Rancher Observability & Backups (ORBS) team. It serves as the primary development location for these charts before they are released to `rancher/charts`.

## Prerequisites

You need [`dep-fetch`](https://github.com/rancherlabs/dep-fetch) installed and available on your `PATH`. The Makefile and scripts use it to download binary dependencies (such as `charts-build-scripts`, `yq`, and `gh`) before running chart operations.

**Installation:**
1. Download the latest release from https://github.com/rancherlabs/dep-fetch
2. Place the binary in your `PATH` (e.g., `/usr/local/bin`)
3. Make it executable: `chmod +x /path/to/dep-fetch`
4. After cloning this repository, run: `dep-fetch sync`

## What charts are in this repository?

This repository contains the following ORBS team charts:
- `rancher-monitoring`
- `rancher-project-monitoring`
- `rancher-logging`

This is where we apply most Rancher-specific changes to these charts. Changes made here should work across all Rancher minor versions, not just one specific version.

## Chart version numbering

Most charts use this format: `{upstream version}-rancher.{incrementing number}`

Each new `{upstream version}` resets the `{incrementing number}` back to 1. This format allows us to:
- Track Rancher-specific changes for any upstream version
- Use the same version across all Rancher minor versions that support a given `{upstream version}`

**Example**: `66.7.1-rancher.1`, `66.7.1-rancher.2`, then `67.0.0-rancher.1`

For more details on why we use this format, see: [How do we manage Chart versions across this repo and `rancher/charts`?](./docs/semver-across-chart-repos.md)

**Exception**: Rancher Project Monitoring uses standard SemVer. Each Project Monitoring version depends on a specific Rancher Monitoring version.

## Pull request workflow

PRs are only merged after testing is complete. The workflow is:

1. ORBS team approves the PR
2. QA validates the changes and comments on the associated issue
3. ORBS team merges the PR

This ensures every commit on `main` is tested and ready to release. It also allows us to maintain a single `main` branch instead of separate development and release branches.

**Important**: Revision numbers are sequential (example: `1.2.3-rancher.1`, `1.2.3-rancher.2`). This means PRs must merge in order. If multiple PRs are open for the same package, they must coordinate merge order and rebase after earlier revisions merge.

For details on what information to provide QA for testing, see: [How to test charts from ob-team-charts](./docs/testing-from-ob-team-charts.md).

### PR labels

The ORBS team uses these labels to track PR status:

- **`revision-hold`**: Another PR has a lower `-rancher.x` revision number that must merge first. When that PR merges, this label will be removed and the PR will need a rebase.

- **`needs-rebase`**: The PR is behind `main` or has become stale. The contributor should rebase their PR to include recent changes.

- **`stale-revision-number`**: The revision number in this PR is already released or claimed by another PR that is further along in QA. Contact the ORBS team to choose a new revision number.

## Rancher Monitoring chart rebasing

The rebasing process is similar to before, but how we manage upstream versions is different. We suffix each upstream version with a `-rancher.{num}` identifier.

This format provides better tracking for Rancher-specific modifications across all Rancher minor versions.

**Benefits**:
- ORBS team maintains a single canonical version of upstream chart changes
- `rancher-monitoring` and `rancher-project-monitoring` rebases can be done in a single PR
- Follow-up PRs in `rancher/prometheus-federator` can be synced to `rancher/charts` together

For more details on the rebase process, see: [Example Monitoring Rebase](./docs/example-monitoring-rebase.md)

## Repository naming

The team is now called ORBS (previously O&B). The repository name `ob-team-charts` remains unchanged.