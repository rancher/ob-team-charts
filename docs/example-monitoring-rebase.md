# Example: Monitoring Chart Rebase

This document shows a specific example of the monitoring chart rebase process. It is a snapshot from one rebase and is not kept updated. Use it as a reference for understanding the process, not as current instructions.

---

## Phase 1: Start the Rebase

### Overview
1. Select the target upstream version
2. Refresh repository and create branch
3. Create initial package for new version

### Select target version

**Context for this example**:
1. Current `rancher-monitoring` targets upstream `61.3.2`
2. The `61.3.2` version doesn't exist in ob-team-charts
3. Last rebase was done before the new ob-team-charts repository and process
4. Prometheus 3.0 is coming and may introduce breaking changes

**Strategy**:
1. Find which version introduces Prometheus 3.0
2. Do a compatibility rebase to the version just before Prometheus 3.0
3. Later, pick a stable version after 3.0 for a second rebase

**Research findings**:
- Latest major version is 68
- Prometheus 3.0 is introduced in version `67.0.0`

**Decision**:
Target [`kube-prometheus-stack-66.7.1`](https://github.com/prometheus-community/helm-charts/tree/kube-prometheus-stack-66.7.1) first (just before Prometheus 3.0). A version with Prometheus 3.0 can be done as a separate effort later.

### Refresh repo and setup branch

> [!WARNING]
> If this is your first time working with the repo, set it up as you had `rancher/charts`. So that way you can work locally and make a new branch for your PR.

Assuming you have your local `ob-team-charts` repo setup and a terminal with that directory open, get started:

> git checkout main && git pull  
> git checkout -b rebase-monitoring/66.7

**About the branch name**:
- The branch targets `66.7` (Major.Minor without patch version)
- The package will use the same `66.7` versioning
- This differs from existing `rancher-monitoring/{version}` examples because:
  - Those charts were imported from `rancher/charts` as a proof of concept
  - Using `Major.Minor` (without patch) is better because we only maintain the newest patch version of upstream

### Create initial package

**Two approaches**:
1. Start from scratch, then import old patches that don't conflict
2. Copy from the previous newest package and work from there

This example uses approach 2 (copy from existing package) because it is most similar to the `rancher/charts` process.

Like the last step, starting from within the `ob-team-charts` repo with your new branch:

> ± |rebase-monitoring/66.7 ?:1 ✗| → cd packages/rancher-monitoring/  
> ± |rebase-monitoring/66.7 ?:1 ✗| → cp -a 57.0.3 66.7

Now we have a new package, but we need to update version references:

> ± |rebase-monitoring/66.7 ?:2 ✗| → cd 66.7/  
> → find . -type f -name dependency.yaml -exec sed -i 's/57.0.3/66.7/g' {} +

**Note**: Use GNU sed, not BSD sed (default on macOS). If GNU sed is installed as `gsed`, update the command to use `gsed` instead of `sed`.

Next, edit the main `package.yaml` to update only the version number. Do not target the new chart yet (this will be explained in later steps).

> In this example, I edited with my IDE that's essentially:  
> sed -i 's/57.0.3-rancher.1/66.7.1-rancher.1/g' rancher-monitoring/package.yaml

At this point we can create our first commit. This example will be via CLI, but use whatever tool you're comfortable in.
First start at the root of `ob-team-charts` then:

> ± |rebase-monitoring/66.7 S:255 ?:1 ✗| → git add packages/  
> ± |rebase-monitoring/66.7 S:255 ?:1 ✗| → git commit -m "Add initial 66.7 package"

From here a good next step is to run `make prepare` on the new chart before our next major steps.

> ± |rebase-monitoring/66.7 S:255 ?:1 ✗| → PACKAGE=rancher-monitoring/66.7 make prepare

## Phase 2: Plan the Rebase

This phase ensures we understand the requirements before making changes. We need to know chart versions and commit hashes before starting. Images that need mirroring will be discovered when we first prepare components.

### Quick method: Use ob-charts-tool

The fastest way to gather rebase information is using the `ob-charts-tool`:

```bash
./bin/ob-charts-tool monitoring:getRebaseInfo <upstream-version>
```

Example:
```bash
./bin/ob-charts-tool monitoring:getRebaseInfo 66.7.1
```

This creates a `rebase.yaml` file with all necessary chart versions, commit hashes, and dependencies. See the [dev-scripts documentation](./dev-scripts.md#get-rebase-target-info) for details on the output format.

### Manual method

If you need to gather information manually:

1. Find commit hashes for the target version
2. Find sub-chart version constraints
3. Resolve the newest version of each sub-chart and record its commit hash


#### Find commit hash for target version

Find the commit hash for the target tag [`kube-prometheus-stack-66.7.1`](https://github.com/prometheus-community/helm-charts/tree/kube-prometheus-stack-66.7.1) using `git` CLI or GitHub.

**Result**: `9c2619e6f3650a5722b0f81f18850b3751ce31ba`

#### Find sub-chart version constraints

Check the `Chart.yaml` file for the dependencies and their version constraints.

**Findings for this release**:

- The commit hash is: `9c2619e6f3650a5722b0f81f18850b3751ce31ba`,
- The target chart has subcharts of:
  - `kube-state-metrics` @ `5.27.*`
  - `prometheus-node-exporter` @ `4.42.*`
  - `grafana` @ `8.7.*`
  - `prometheus-windows-exporter` @ `0.7.*`

#### Resolve sub-chart versions and commit hashes

The version constraints use wildcards for patch versions. This means:
1. We need to find the highest patch version manually
2. We can maintain older versions by checking for sub-chart patch releases

**Resolved versions**:
1. Grafana: `grafana` @ `8.7.*`
    - For grafana, we need to source their [upstream community charts](https://github.com/grafana/helm-charts),
    - At Grafana, we find the newest `8.7.*` conforming chart is: `8.7.1`
    - So our target Grafana is from: https://github.com/grafana/helm-charts/tree/grafana-8.7.1 and the commit hash is `f1287fb9e9093c4f875b7a8c56832a69a4eb462a`
2. Kube State Metrics: `kube-state-metrics` @ `5.27.*`
   - Search Prom Community charts repo tags for `kube-state-metrics-5.27` -> find highest `kube-state-metrics-5.27.1`
   - The commit hash is: `6603ff5a3fdfccf27f29812472f727e98c57ca37`
3. Prometheus Node Exporter: `prometheus-node-exporter` @ `4.42.*`
    - Search Prom Community charts repo tags for `prometheus-node-exporter-4.42.` -> find highest `prometheus-node-exporter-4.42.0`
    - The commit hash is: `d68fafc4a577df625d20c896dae23f789b54137a`
4. Prometheus Adapter: Rancher added, but upstream community maintained
   - Because it's not directly tied to upstream versions, just try to pick the newest patch at rebase time.
   - Search Prom Community charts repo tags for `prometheus-adapter-` -> find highest `prometheus-adapter-4.11.0`
   - The commit hash is: `cfa7307424fd2e3572e0580287676c386fc91604`
5. Prometheus Windows Exporter: `prometheus-windows-exporter` @ `0.7.*`
    - Search Prom Community charts repo tags for `prometheus-windows-exporter-0.7.` -> find highest `prometheus-windows-exporter-0.7.1`
    - The commit hash is: `3cc3dbd75cf058109a75db18efe58801a112be3a`

**Version comparison** (old → new):

- `kube-prometheus-stack`/`rancher-monitoring` 61.3.2 -> 66.7.1
  - `grafana` 8.3.6 -> 8.7.1
  - `kube-state-metrics` 5.21.0 -> 5.27.1
  - `prometheus-node-exporter` 4.37.1 -> 4.42.0
  - `rancher-prometheus-adapter` 4.2.0 -> 4.11.0
  - `prometheus-windows-exporter` 0.3.1 -> 0.7.1

## Phase 3: Execute the Rebase

This phase applies the information gathered above to update charts. Work from the inside out: update sub-charts first, then the main `rancher-monitoring` chart.

Start with Rancher-produced image-based charts (like pushprox) since they are simpler. Often only image version bumps are needed.

### Overview
1. Update sub-charts
2. Update the main rancher-monitoring package
3. Rebuild dependent packages (Rancher Project Monitoring)


### Update sub-charts

**Process for each sub-chart**:

1. Run `PACKAGE=rancher-monitoring/{version}/{target} make prepare`
2. Fix patches or move failing patches to disable them (use `make patch` as needed)
3. Run `make prepare` again, then `helm template --debug {target} ./` (where `./` is the path to the temporary `charts` directory)
4. If you see Helm errors, make more patch changes
5. Repeat until the sub-chart works

**Common issues**:
- `values.yaml` patches may downgrade image tags. Check the original chart's `values.yaml` to verify. In a rebase, tag versions usually go up.
- The `appVersion` of the main rancher chart is used for many (but not all) component tags. Remember this when mirroring images. 

**Changes for this example (in order)**:
1. Pushprox:
   1. Bump the pushprox version to highest,
   2. Notice our mirrored busybox image and bump that to newest mirroed one,
    - Long term we may want to abstract pushprox charts;
      - the current method maintains 1:1 pushprox for each Major.Minor we currently maintain.
      - We need to take care to backport changes of pushprox to each version they apply in.
      - Splitting it would still have that, but pulling the version from Git releases similar to BRO style (in rancher/charts).
2. Windows Exporter:
   1. Bump the hash version of the package then immediately create a commit,
   2. Run `PACKAGE=rancher-monitoring/66.7/rancher-windows-exporter make prepare` - found no errors, move on,
3. Prometheus Node Exporter:
   1. Bump the hash version of the package then immediately create a commit,
   2. Run `PACKAGE=rancher-monitoring/66.7/rancher-node-exporter make prepare` - found errors:
      - You can follow the process you're familiar with for resolving patch errors.
      - I have my own process that I documented here, see notes on [Dan's suggested method](patch-resolution-process.md)
      - In this case, I edited some patches (values/Chart) and then used `make patch` for the rest.
4. Kube State Metrics:
   1. Bump the hash version of the package then immediately create a commit,
   2. Run `PACKAGE=rancher-monitoring/66.7/rancher-kube-state-metrics make prepare` - found errors:
      - See git branch for specifics; a lot more conflicts than previous parts,
5. Prometheus Adapter:
   1. Bump the hash version of the package then immediately create a commit,
   2. Run `PACKAGE=rancher-monitoring/66.7/rancher-node-exporter make prepare` - found errors:
      - See git branch for specifics; a lot more conflicts than previous parts,

After completing all sub-charts, move on to the main rancher-monitoring package.

### Update main rancher-monitoring package

**Steps for this example**:
1. After all the sub-charts are updated, bump the hash version then immediately create a commit,
2. It gets updated 2 times in this package so get both places, (both `commit` fields in the file)
3. Run `PACKAGE=rancher-monitoring/66.7/rancher-monitoring make prepare` - found errors:
   - Also has lots of changes, check git branch for specifics.
   - Use notes from [Dan's suggested method](patch-resolution-process.md) to find all very broken patches
   - Once all broken patches disabled, make a test build: `PACKAGE=rancher-monitoring/66.7/rancher-monitoring make charts`
   - Add back removed broken patches via manual comparison of the last version of `rancher-monitoring` and consider upstream diffs.

> [!NOTE]
> This specific example had some undocumented steps but those can be reviewed in the PRs commits.
> The following is a good summary of the process many of those commits worked though.

Before creating `rancher-project-monitoring`, verify that all changes work together. This makes creating and testing `rancher-project-monitoring` easier.

**Mirror new images**:

The best way to find required images:
1. Go to the `charts/rancher-monitoring/{version}` directory
2. Run: `helm template --debug | grep image`
3. Compare the output to the image list in the `image-mirror` repository
4. Mirror any missing images

After mirroring images, create a version of the chart that Rancher can install.

**Issues found during testing**:
- rancher-monitoring-operator pod with error: `flag provided but not defined: -kubelet-endpoints`
    - Here is where I realized many of my image tags in `values.yaml` were accidentally downgraded via patching.
    - To fix this, I referred to the upstream chart versions - then also our dockerhub versions for ones we bump higher (shell, nginx, etc)
- Fixing the previous issue prompted me to re-do the image mirroring step and make a new PR with more images I missed.
- From within the compiled chart directory (e.g. `ob-team-charts/charts/rancher-monitoring/66.7.1-rancher.1`) run:
    - `helm template --debug "rancher-monitoring" ./ | ../../../dev-scripts/verify-chart-images`
    - This will give output to help verify what images need to be mirrored

After all images are mirrored and the chart is fully debugged, move on to `rancher-project-monitoring`.

### Rebuild dependent packages (Rancher Project Monitoring)

There are multiple ways to create `rancher-project-monitoring`. This repository is still determining standards for this process. For now, use whichever method you are familiar with as long as the results are correct.

**Method used in this example** (similar to porting version `0.3.4`):
- Creating a Rancher Project Monitoring specific Grafana under the new rebase,
- Create our new Rancher Project Monitoring version copied from `0.3.4` but using rebase

#### Create project-monitoring-grafana

The `project-monitoring-grafana` chart has a few minimal patches on top of `rancher-grafana`. Copy `project-monitoring-grafana` from a previous release, then:
1. Update the `pacakge.yaml` file's `url` field to the correct version,
2. Disable exiting patches by renaming `patch` to `patch-off`,
3. Do a make prepare on this new sub-package `PACKAGE=rancher-monitoring/66.7/project-monitoring-grafana make prepare`,
4. Manually recreate the patching changes on prepared chart and run `make prepare`,
5. Remove the `patch-off` directory

After completing these steps, you have a Grafana chart ready for Rancher Project Monitoring.

#### Create Rancher Project Monitoring

1. Copy `0.3.4` (which uses the same method) to `0.5.0`
2. Edit `generated-changes/dependencies/grafana/dependency.yaml`
3. Update the `url` to: `packages/rancher-monitoring/66.7/project-monitoring-grafana`
4. Test by running: `PACKAGE=rancher-project-monitoring/0.5.0 make charts`

**Testing**: You may need to update an existing Rancher Project Monitoring installation (with Prometheus Federator disabled), or install it directly into a project. Better documentation for testing without Prometheus Federator will be added in the future.

## Next Steps After Rebase

After completing the rebase:

1. **Update Prometheus Federator**: Update it for each branch where you are releasing Monitoring
2. **Update rancher/charts**: Only after Prometheus Federator is updated, move changes to `rancher/charts` on the target branch

This ensures Rancher Monitoring and Prometheus Federator are updated together.

**Note**: These steps are intentionally not detailed here, as they follow existing practices from before this repository was created.