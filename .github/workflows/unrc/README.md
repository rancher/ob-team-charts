# Chart Un-RC Scripts

These scripts promote a chart's already-built rc version to a release version
(no `-rc.N` suffix) in `rancher/charts`, and clean up the superseded rc assets.
They're the counterpart to `../push`, which creates/bumps rc versions; this
promotes an existing rc to release without pulling new content from upstream.

Triggered via the `unrc.yaml` workflow (`workflow_dispatch`), typically
dispatched from `rancher/charts` once an rc has been validated.

## Full local run

```bash
./run-local.sh --charts-dir /path/to/rancher/charts \
  --chart rancher-monitoring \
  --version 110.0.2-rc.1+up80.9.1-rancher.20 \
  [OPTIONS]

Options:
  --source-repo REPO  # source repo for PR body (default: rancher/ob-team-charts)
  --remote NAME       # remote name in rancher/charts clone (default: origin)
  --dry-run           # skips push and PR creation
```

`--version` accepts either the rc string (`<rancher_version>-rc.N+up<ob_version>`)
or the already-bare version (`<rancher_version>+up<ob_version>`) — the `-rc.N`
suffix is stripped if present. `resolve-target.sh` looks up `charts-config.yaml`
(by chart name and the `major.minor` of `<ob_version>`) for the branch(es) this
chart/version is configured for and checks them out — nothing here verifies the
branch is actually at that rc; this is only ever triggered from `rancher/charts`
once the rc it names already exists there, so the caller is trusted.

## Running a single step

Each script can be run standalone. Set `TARGET_BRANCH` and it will auto-derive
the package list from `charts-config.yaml`. Set `BRANCH_FILE` explicitly if you
have a pre-generated branch data file.

**Required env for all step scripts:** `CHARTS_DIR`, `TARGET_BRANCH` (or `BRANCH_FILE`)

## Step sequence and prerequisites

| Script | Prerequisites |
|---|---|
| `resolve-target.sh` | `CHART_NAME`, `OB_VERSION`, `UPSTREAM_VERSION` set |
| `promote-version.sh` | none (first step per branch) |
| `../push/generate-assets.sh` | `promote-version.sh` |
| `remove-superseded-rc.sh` | `promote-version.sh`, `../push/generate-assets.sh` |
| `finalize-release-yaml.sh` | `promote-version.sh` (needs `${BRANCH_FILE}.versions`) |
| `../push/create-pr.sh` | all of the above |

## Key env vars

| Var | Description |
|---|---|
| `CHARTS_DIR` | Path to local rancher/charts clone |
| `CHART_NAME` | Chart name, e.g. `rancher-monitoring` |
| `UNRC_VERSION` | Requested version, e.g. `110.0.2-rc.1+up80.9.1-rancher.20` |
| `BASE_VERSION` | Requested version with any `-rc.N` suffix stripped |
| `OB_VERSION` | The `+up...` part, i.e. the ob-team-charts chart version |
| `TARGET_BRANCH` | Target branch in rancher/charts (e.g. `dev-v2.15`) |
| `BRANCH_FILE` | CSV file of `chart/version,package_path` lines (auto-derived if unset) |
| `OB_DIR` | Path to ob-team-charts root (auto-detected from script location) |
| `DRY_RUN` | Set to `true` to skip push and PR creation |

## What this does not do

Unlike `../push`, this does not re-pull chart content, re-run patches, or touch
kuberlr-kubectl tags — the commit and subdirectory pinned in `package.yaml` are
left untouched. Only the `version` field changes, so the resulting PR is a pure
version-relabel plus removal of the superseded rc assets.
