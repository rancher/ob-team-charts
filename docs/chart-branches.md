# Chart Release Process

This document explains how charts are released from this repository to the downstream `rancher/charts` repository.

## The `charts-config.yaml` file

The `charts-config.yaml` file defines the relationship between charts in this repository and branches in the downstream repository.

This file serves two purposes:

1.  **Coordination**: It provides a single source of truth for which chart versions should go to which downstream branch. This helps coordinate team work and prevents confusion.
2.  **Automation**: GitHub Actions workflows use this file to automatically create pull requests in the downstream `rancher/charts` repository when changes are merged to `main`.

## File structure

The `charts-config.yaml` file uses this structure:

```yaml
packages:
  <package-name>:
    "<package-version>":
      branches:
        - branch: "<downstream-branch-1>"
          package: <package-path>
        - branch: "<downstream-branch-2>"
          package: <package-path>
```

**Fields**:

*   `<package-name>`: Chart package name (example: `rancher-monitoring`, `rancher-logging`).
*   `<package-version>`: Package version (example: `4.10`, `66.7`).
*   `<downstream-branch>`: Branch name in the downstream `rancher/charts` repository (example: `dev-v2.14`, `dev-v2.15`).
*   `<package-path>`: Path to the package within this repository (example: `rancher-logging`, `rancher-monitoring/rancher-monitoring`).

## How to use this file

This file maps which downstream branches should receive chart updates for each package version.

**Example**:

```yaml
packages:
  rancher-logging:
    "4.10":
      branches:
        - branch: "dev-v2.14"
          package: rancher-logging
        - branch: "dev-v2.15"
          package: rancher-logging
```

This configuration means: any updates to the `4.10` version of `rancher-logging` will automatically create pull requests in both the `dev-v2.14` and `dev-v2.15` branches of the `rancher/charts` repository.

## How the automation works

When changes are merged to the `main` branch, the GitHub Actions workflow (`.github/workflows/push.yaml`) automatically:

1. Detects which charts were updated
2. Reads `charts-config.yaml` to determine target branches
3. Creates pull requests in `rancher/charts` for each target branch up to `dev-v2.15`. `dev-v2.16` and later are skipped, because those charts are staged with cargueiro. Kept their entries under `packages` anyway, since the staging workflow reads them (need to remove this later).
4. Updates dependencies, patches, and release metadata

The automation can also be triggered manually using the workflow dispatch option if needed.

## Staging charts with cargueiro (Rancher 2.16 and later)

The `stage-charts.yaml` workflow stages a chart of `assets/` in the staging registry with cargueiro, next to the flow above. It is started by hand:

```bash
gh workflow run stage-charts.yaml --ref main -f chart=rancher-monitoring/80.9.1-rancher.23
```

The chart, and its `-crd` chart when there is one, is staged once for every `dev-v2.X` branch, with X of 16 or more, that its `Major.Minor` maps to under `packages`. Each Rancher version gets its own chart version, such as `111.0.0+up80.9.1-rancher.23` for 2.16. What the workflow sets in the chart for a Rancher version comes from `charts-config.yaml`:

```yaml
kuberlr-kubectl:
  dev-v2.16: release/v9.x  # the latest v9.Y.Z release goes into every kuberlr-kubectl image

rancher-versions:
  "2.16":
    kube-version: ">= 1.35.0-0 < 1.38.0-0"  # the catalog.cattle.io/kube-version annotation
```

The `rancher-version` annotation is set to `>= 2.X.0-0 < 2.(X+1).0-0`. A `file://assets/logos/` icon, or no icon, is replaced by the address of the logo in `assets/logos/` of this repository, because cargueiro downloads the icon. The chart must also be listed in the `rules.yaml` of [cargueiro](https://github.com/rancher/cargueiro).
