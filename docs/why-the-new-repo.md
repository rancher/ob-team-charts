# Repository FAQ

## What is this repository for compared to `rancher/charts`?

This repository is the ORBS team's primary source of truth for the charts we maintain. It focuses on charts we pull from third-party sources, but can also include internally-produced ORBS charts when appropriate.

## What problems does this repository solve?

This repository solves specific problems the ORBS team faces when maintaining Monitoring and Logging charts:

- **Regressions during rebases**: The previous workflow caused regressions
- **Missed dependency updates**: During rebases, some sub-charts kept old image tags, leaving CVEs unfixed even after the rebase
- **Inconsistent patches**: Different Rancher branches in `rancher/charts` had different patches for the same upstream chart version, making maintenance difficult

## What made the old chart process complex?

The old process in `rancher/charts` involved three types of changes:
- Chart rebases
- Image updates and security patches
- Rancher-specific modifications

Each change type could have:
- Specific image tags to match upstream charts
- Rancher version-dependent changes

This created repeated work with subtle differences across branches. Comparing similar-but-different patches for the same upstream chart across multiple Rancher branches was difficult and error-prone.

## Why does this repository only have a `main` branch?

This repository reduces redundant work by maintaining charts once instead of across multiple Rancher branches.

In the old process, we maintained the same upstream chart version separately in multiple Rancher branches. With this repository:

1. Apply Rancher-specific changes once in a version-agnostic way
2. When the chart goes to `rancher/charts`, apply only Rancher minor version-specific patches

### What about `rancher/charts` auto-bumps?

The auto-bump feature in `rancher/charts` is compatible with this repository. If needed:
- Use `main` as the source of truth
- Create Rancher minor version-specific charts on release branches
- Start new release branches from a common orphaned branch

## Where are the Helm Project Operator and Prometheus Federator charts?

The `helm-project-operator` chart was removed. It was a sub-chart of Prometheus Federator used primarily for development testing, but it made development more complex.

After removing it, the simplified Prometheus Federator chart now lives in the Prometheus Federator repository.