# Example Monitoring Rebase Doc

This document is created as a place in time example showing a specific implementation of the new process.
It is not intended to be kept updated, but rather summary and report of one implementation of the new process.

---

## Start the rebase

### Outline
1. Select the new version to target,
2. Refresh repo and setup branch,
3. Create new initial new version package,

### Select a new target version:
#### Details
1. Current newest `rancher-monitoring` targets upstream `61.3.2`,
2. The `61.3.2` version doesn't exist in ob-team-charts,
3. **Consideration**: Last Rebase was done before new `ob-team-charts` repo and process; any version higher than `61.3.2` is ok.
4. We know Prometheus 3.0 is coming and could be a breaking change.
5. **Consideration**: We should aim to ship a compatability update before the major 3.0 update;
    1. First, find the first version introducing Prometheus 3.0,
    2. Do a rebase to update to the version just under that (compatability update),
    3. Then, pick a stable version after that to target for rebase after.

Next, I go look at our options and find:
- Major versions go as high as 68 currently,
- The version introducing Prom 3.0 is `67.0.0`,

#### Conclusion
We should target both: [`kube-prometheus-stack-66.7.1`](https://github.com/prometheus-community/helm-charts/tree/kube-prometheus-stack-66.7.1) and a version with Prometheus 3.0.
Because Prom 3.0 may be a big change it shouldn't necessarily be simultaneous efforts.

### Refresh repo and setup branch

> [!WARNING]
> If this is your first time working with the repo, set it up as you had `rancher/charts`. So that way you can work locally and make a new branch for your PR.

Assuming you have your local `ob-team-charts` repo setup and a terminal with that directory open, get started:

> git checkout main && git pull  
> git checkout -b rebase-monitoring/66.7

#### Step Explanation
- In this case, we create a branch targeting `66.7`,
  - Our subsequent package will also be versioned as such,
- This deviates from the existing `rancher-monitoring/{version}` examples intentionally, because:
  - Those charts were imported from `rancher/charts` to fit the new repo and new process for Proof of Concept,
  - After doing those charts I (dan) learned enough to realize versioning by `Major.Minor` is better,
  - By versioning with `Major.Minor` and excluding patch we only maintain the newest patch we have released of upstream,

### Create new initial new version package

There are two paths to take here: start from scratch then import old patches that don't conflict, or start from previous newest package and work from there.
This example opted to copy from an existing versioned package as that's most similar to `rancher/charts` only process - so may be easier to get started with.

Like the last step, starting from within the `ob-team-charts` repo with your new branch:

> ± |rebase-monitoring/66.7 ?:1 ✗| → cd packages/rancher-monitoring/  
> ± |rebase-monitoring/66.7 ?:1 ✗| → cp -a 57.0.3 66.7

Now we have a new package, but we need to update a handful of references first.
Let's do that here before loading our preferred IDE:

> ± |rebase-monitoring/66.7 ?:2 ✗| → cd 66.7/  
> → find . -type f -name dependency.yaml -exec sed -i 's/57.0.3/66.7/g' {} +

Be sure that you have GNU sed and not the apple/BSD sed which will not work here.
If you have GNU sed but not linked as sed, you should update to point to the `gsed` path on your system.

Finally, in your preferred IDE (or vim) edit the main `package.yaml` - but for now only to have the proper new version.
We are not going to target a new chart yet for reasons that will become clear in further steps.

> In this example, I edited with my IDE that's essentially:  
> sed -i 's/57.0.3-rancher.1/66.7.1-rancher.1/g' rancher-monitoring/package.yaml

At this point we can create our first commit. This example will be via CLI, but use whatever tool you're comfortable in.
First start at the root of `ob-team-charts` then:

> ± |rebase-monitoring/66.7 S:255 ?:1 ✗| → git add packages/  
> ± |rebase-monitoring/66.7 S:255 ?:1 ✗| → git commit -m "Add initial 66.7 package"

From here a good next step is to run `make prepare` on the new chart before our next major steps.

> ± |rebase-monitoring/66.7 S:255 ?:1 ✗| → PACKAGE=rancher-monitoring/66.7 make prepare

## Chart the game plan

> Excuse the silly dad-joke pun.

This part of the process is helpful to ensure we're thinking from the process top down.
We already will know all the chart versions and hashes we need to get the process started.
However, the new images - of which we'll need to mirror - will be revealed when we first prepare components.

### Outline
1. Find the new version's commit hash targets,
2. Find the sub-charts version constraints,
3. Resolve the newest version of each sub-chart and note the hash


### Find the new versions and commit hash targets

Start by referring back to our target tag: [`kube-prometheus-stack-66.7.1`](https://github.com/prometheus-community/helm-charts/tree/kube-prometheus-stack-66.7.1)
Fetch the commit hash of this tag via `git` cli or GitHub.

- The commit hash is: `9c2619e6f3650a5722b0f81f18850b3751ce31ba`,

### Find the sub-charts version constraints
For this step, we refer to the `Chart.yaml` and find the dependencies listed there and the accepted versions.
In this case, here are the most important facts gathered about that release:

- The commit hash is: `9c2619e6f3650a5722b0f81f18850b3751ce31ba`,
- The target chart has subcharts of:
  - `kube-state-metrics` @ `5.27.*`
  - `prometheus-node-exporter` @ `4.42.*`
  - `grafana` @ `8.7.*`
  - `prometheus-windows-exporter` @ `0.7.*`

### Resolve the newest version of each sub-chart and note the hash

Now because the versions have wildcard patches, this means two important things:
1. We need to manually find the highest patch and use that,
2. Our team can maintain older versions of upstreams by checking if sub-charts get patch releases and updating to use those,

Here's what we find when resolving the above wildcards:
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

Our next observation will be to compare to the newest version of Monitoring we have.

- `kube-prometheus-stack`/`rancher-monitoring` 61.3.2 -> 66.7.1
  - `grafana` 8.3.6 -> 8.7.1
  - `kube-state-metrics` 5.21.0 -> 5.27.1
  - `prometheus-node-exporter` 4.37.1 -> 4.42.0
  - `rancher-prometheus-adapter` 4.2.0 -> 4.11.0
  - `prometheus-windows-exporter` 0.3.1 -> 0.7.1

## Execute the rebase on the new package

This next phase essentially entails taking the details we organized above and using them to update sub-charts.
And specifically we're going to work "inside out" meaning; update the sub-charts first, then `rancher-monitoring` chart.

For any of the "rancher produced" image based charts, we should take care to start with those since they're easiest.
Often we just need to bump image versions for local charts (pushprox).

### Outline
1. Work on the sub-charts of the package,
2. Update the main package for rebase,
3. Rebuild any dependant packages (Rancher Project Monitoring)


### Work on the sub-charts of the package

The overall "loop" over our workflow for each sub-chart target is:
1. > `PACKAGE=rancher-monitoring/{version}/{target} make prepare`
2. Fix, or move patches to disable them. (Doing `make patch` as needed)
3. Redo `make prepare` and then `helm template --debug {target} ./` (where `./` is the path to the temporary `charts`  directory of your target.)
4. If you see helm errors you know you have more patch changes to make,
5. Rinse and repeat until you're complete with the current target.

Something's to keep an eye out for that are easy to get mixed up on are:
- `values.yaml` file patching may "downgrade" the image tags
  - Make sure you refer to the original chart's `values.yaml` as needed,
  - Because it's a rebase, generally it's safe to assume the tag versions go up - if not verify it,
- The `appVersion` of the main rancher chart is used for many -but not all- of the component tags as well.
  - Keep this in mind for when you mirror images 

That in mind the summary of changes I'm making and in order are:
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
      - I have my own process that I documented here, see notes on [Dan's suggested method](dans-suggested-patch-resolution.md)
      - In this case, I edited some patches (values/Chart) and then used `make patch` for the rest.
4. Kube State Metrics:
   1. Bump the hash version of the package then immediately create a commit,
   2. Run `PACKAGE=rancher-monitoring/66.7/rancher-kube-state-metrics make prepare` - found errors:
      - See git branch for specifics; a lot more conflicts than previous parts,
5. Prometheus Adapter:
   1. Bump the hash version of the package then immediately create a commit,
   2. Run `PACKAGE=rancher-monitoring/66.7/rancher-node-exporter make prepare` - found errors:
      - See git branch for specifics; a lot more conflicts than previous parts,

At this point, all of the sub-packages for this rebase version should be completed.
Next you can take on the larger task of the main rancher-monitoring package for this version.

### Update the main package for rebase

For the main rancher-monitoring package we did the following:
1. After all the sub-charts are updated, bump the hash version then immediately create a commit,
2. It gets updated 2 times in this package so get both places, (both `commit` fields in the file)
3. Run `PACKAGE=rancher-monitoring/66.7/rancher-monitoring make prepare` - found errors:
   - Also has lots of changes, check git branch for specifics.
   - Use notes from [Dan's suggested method](dans-suggested-patch-resolution.md) to find all very broken patches
   - Once all broken patches disabled, make a test build: `PACKAGE=rancher-monitoring/66.7/rancher-monitoring make charts`
   - Add back removed broken patches via manual comparison of the last version of `rancher-monitoring` and consider upstream diffs.

> [!NOTE]
> This specific example had some undocumented steps but those can be reviewed in the PRs commits.
> The following is a good summary of the process many of those commits worked though.

The next aspect, that will be new to the process, is to also create a new `rancher-project-monitoring`.
However before this we should verify the changes this far all work together and sort out rough edges first.
Then we'll have an easier time creating and testing `rancher-project-monitoring`.

A good place to start is to mirror all new images we will need.
The best way to discover those images is usually to do something like: `helm template --debug |grep image`.
From within the `charts/rancher-monitoring/{version}` directory, then compare the output to the list in `image-mirror` repo.

At this point, we're able to create a version of the chart that can be installed by Rancher.
Doing so reveals the following issues:
- rancher-monitoring-operator pod with error: `flag provided but not defined: -kubelet-endpoints`
    - Here is where I realized many of my image tags in `values.yaml` were accidentally downgraded via patching.
    - To fix this, I referred to the upstream chart versions - then also our dockerhub versions for ones we bump higher (shell, nginx, etc)
- Fixing the previous issue prompted me to re-do the image mirroring step and make a new PR with more images I missed.
- From within the compiled chart directory (e.g. `ob-team-charts/charts/rancher-monitoring/66.7.1-rancher.1`) run:
    - `helm template --debug "rancher-monitoring" ./ | ../../../dev-scripts/verify-chart-images`
    - This will give output to help verify what images need to be mirrored

Finally, after the new images are mirrored, and you've debugged the chart fully, you can move onto the `rancher-project-monitoring` steps.

### Rebuild any dependant packages (Rancher Project Monitoring)

This next step to create `rancher-project-monitoring` can be done in a few ways.
This repo is still exploring what standards we should use to enforce consistency with this process.
However, until one is picked we can use which ever method the PR author is familiar with as long as the results are correct.

In this instance the method used is similar to what was done to port `0.3.4` Rancher Project Monitoirng into this repo.
In other words, we will accomplish that by:
- Creating a Rancher Project Monitoring specific Grafana under the new rebase,
- Create our new Rancher Project Monitoring version copied from `0.3.4` but using rebase

#### Creating a Rancher Project Monitoring specific Grafana under the new rebase
To create the `project-monitoirng-grafana` we have a few minimal patches to apply on top of `rancher-grafana`.
So we copy `project-monitoirng-grafana` from a previous release and then:
1. Update the `pacakge.yaml` file's `url` field to the correct version,
2. Disable exiting patches by renaming `patch` to `patch-off`,
3. Do a make prepare on this new sub-package `PACKAGE=rancher-monitoring/66.7/project-monitoring-grafana make prepare`,
4. Manually recreate the patching changes on prepared chart and run `make prepare`,
5. Remove the `patch-off` directory

After this, we have a grafana that we can use in Rancher Project Monitoring.

#### Creating Rancher Project Monitoring
To start, we copy `0.3.4` (the other package using this same method) into `0.5.0`.

After this, simply edit `generated-changes/dependencies/grafana/dependency.yaml` to update the `url` to match the new package.
In this case we updated to: `packages/rancher-monitoring/66.7/project-monitoring-grafana`.

After this, because it's a local based package, you will need to run `PACKAGE=rancher-project-monitoring/0.5.0 make charts` to test.

To test this new Rancher Project Monitoring you may need to use some clever tricks to update an existing installation of Rancher Project Monitoring (and disable PromFed).
Or you can try other tricks to install it directly into a project similar to how Prom Fed would.
Expanding on and documenting the process around testing this before PromFed will be explored further in the future.

## Next Steps after rebase

The next steps after a rebase are -ideally- to go update Prometheus Federator for the branch you're seeking to ship it on.
Keep in mind, you will need to do this for each branch you're releasing Monitoring on.

Only after you complete this should you work to move changes into `rancher/charts` on the target branch.
This will ensure that we can update both Rancher Monitoring and Prometheus Federator at the same time.
These steps are intentionally left out of this example documentation.
If requested we can document them, however they are very consistent with existing practices before this repo.