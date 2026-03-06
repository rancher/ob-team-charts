# Chart Push Scripts

These scripts automate pushing chart updates from ob-team-charts into rancher/charts and opening PRs.

## Full local run

```bash
./run-local.sh --charts-dir /path/to/rancher/charts [OPTIONS]

Options:
  --charts "rancher-monitoring/77.9"  # override auto-detection (space-separated)
  --commit-sha <sha>                  # defaults to HEAD of ob-team-charts
  --dry-run                           # skips push and PR creation
  --remote <name>                     # remote name in rancher/charts clone (default: origin)
```

Auto-detection finds changed charts by diffing HEAD~1..HEAD in this repo.

## Running a single step

Each script can be run standalone. Set `TARGET_BRANCH` and it will auto-derive the package list from `charts-config.yaml`. Set `BRANCH_FILE` explicitly if you have a pre-generated branch data file.

```bash
CHARTS_DIR=/path/to/rancher/charts TARGET_BRANCH=dev-v2.13 ./update-kuberlr.sh
```

**Required env for all step scripts:** `CHARTS_DIR`, `TARGET_BRANCH` (or `BRANCH_FILE`)

## Step sequence and prerequisites

| Script | Prerequisites |
|---|---|
| `detect-charts.sh` | none |
| `group-by-branch.sh` | `NEW_CHARTS` set |
| `update-package-yaml.sh` | none (first step per branch) |
| `prepare-deps.sh` | none |
| `update-patches.sh` | `prepare-deps.sh` |
| `generate-assets.sh` (Initial) | `update-patches.sh` |
| `update-kuberlr.sh` | `generate-assets.sh` (Initial) |
| `generate-assets.sh` (Final) | `update-kuberlr.sh` |
| `update-release-yaml.sh` | `update-package-yaml.sh` (needs `${BRANCH_FILE}.versions`) |
| `create-pr.sh` | all of the above |

## Key env vars

| Var | Description |
|---|---|
| `CHARTS_DIR` | Path to local rancher/charts clone |
| `TARGET_BRANCH` | Target branch in rancher/charts (e.g. `dev-v2.13`) |
| `BRANCH_FILE` | CSV file of `chart/version,package_path` lines (auto-derived if unset) |
| `OB_DIR` | Path to ob-team-charts root (auto-detected from script location) |
| `DRY_RUN` | Set to `true` to skip push and PR creation |
| `COMMIT_SHA` | Source commit SHA to pin in package.yaml (required by `update-package-yaml.sh`) |

## kuberlr-kubectl version mapping

`charts-config.yaml` contains a `kuberlr-kubectl` section mapping each target branch to a branch in `rancher/kuberlr-kubectl`. `update-kuberlr.sh` queries the GitHub API for the latest release on that branch.
