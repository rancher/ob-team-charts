# Rancher Monitoring Rebase

This document will outline the overall process for how "rebasing monitoring" (adding a new upstream version) works.
It will cover the steps taken within this repo and explain how to expect to land those in a specific Rancher version via `rancher/charts`.

The charts affected by the rebase will be: `rancher-monitoring` (and all subcharts), `rancher-project-monitoring`, and `prometheus-federator`.
Of these 3, the first two will fully take place here and changes for `prometheus-federator` image (and chart) done there.

## Getting Started

The `rancher-monitoring` chart is based off of the upstream `kube-prometheus-stack` chart.

### Identify the new upstream version for Rebase

Sometimes the version you need to target during rebase is listed in the issue you're assigned.
If it is not, you will want to start by identifying what version(s) are candidates - feel free to work with the team to pick if you are unsure.

1. Identify the current highest upstream version we use,
2. Go to https://github.com/prometheus-community/helm-charts,
3. Using Branch & Tags box search for `kube-prometheus-stack`,
4. Review the tagged releases for the options higher than current version,
5. It's good to note the list of options to refer to later,
6. Start reviewing the changes between the current version, and the potential versions; factors to consider:
   - Do any sub-charts have major/breaking updates?
   - Are there any Product specific changes we are targeting (i.e. minimum upgrade we must target)?
   - Are there important fixes from upstream included in a specific option we need?
7. One a target version is selected, identify the commit hash that tag exists on (note it).

After this you have the commit hash to use within the package files.

<details>
  <summary>Example: Picking rebase version to target</summary>

### Details
1. Newest `rancher-monitoring` targets upstream `61.3.2`,
2. The `61.3.2` version doesn't exist in ob-team-charts,
3. **Consideration**: Last Rebase was done before new repo and process; any version higher than `61.3.2` is ok.
4. We know Prometheus 3.0 is coming and could be a breaking change.
5. **Consideration**: We should aim to ship a compatability update to compliment and the 3.0 update;
   1. First, find the first version introducing Prometheus 3.0,
   2. Do a rebase to update to the version just under that (compatability update),
   3. Then, pick a stable version after that to target for rebase after.

Next, I go look at our options and find:
- Major versions go as high as 68 currently,
- The version introducing Prom 3.0 is `67.0.0`,

### Conclusion
We should target both: `kube-prometheus-stack-66.7.1` and a version with Prometheus 3.0.
Because Prom 3.0 may be a big change it shouldn't necessarily be simultaneous efforts.
</details>

### Creating a new `rancher-monitoring/{version}` package
1. Often it's easiest to start the process by seeding with files from the next newest version,
2. Create a version folder matching the Major and Minor of your target,
3. Edit the `package.yaml` for `rancher-monitoring`:
   1. Update `version` field to match upstream target,
   2. Append (or increment) the rancher suffix vesrion (`-rancher.1`)
   3. Update the `commit` fields (both main and crd chart) to target
4. Edit the `dependency.yaml` files as needed to use your new package
   - If copied from older version, find-replace for new target,
5. Run `PACKAGE={your new package} make prepare` to update sub-package versions and such.
6. 