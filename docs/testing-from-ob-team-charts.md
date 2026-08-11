# How to Test Charts from ob-team-charts

The ORBS team uses the ob-team-charts repository for custom Helm charts. By default, Rancher only pulls charts from the `rancher/charts` repository. To test charts directly from `ob-team-charts` or a fork, you need to complete some extra steps.

## Step 1: Create a ClusterRepo

### Quick method: Use ob-charts-tool

If you have the repository cloned locally, you can generate a ClusterRepo for your current branch:

```bash
./bin/ob-charts-tool branchQaHint
```

This outputs a ClusterRepo YAML that points to your current branch and remote repository. Copy the output and apply it to your cluster.

### Manual method: Create ClusterRepo YAML

Alternatively, create a custom ClusterRepo resource manually:

```yaml
## ClusterRepo pulling from the main branch in the original ob-team-charts repo
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: ob-team-charts
spec:
  gitBranch: main
  gitRepo: https://github.com/rancher/ob-team-charts

```

This ClusterRepo points to the `main` branch in the original ob-team-charts repository. 

To pull from a fork instead, change the `gitRepo` URL and `gitBranch` to match your fork:

```yaml
## ClusterRepo pulling from a fork
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: ob-team-charts-jbiers
spec:
  gitBranch: rancher-monitoring-69.8.2
  gitRepo: https://github.com/jbiers/ob-team-charts
```

Save your ClusterRepo definition as a YAML file and apply it:
- Using kubectl: `kubectl apply -f <my-clusterrepo-file>`
- Or import the file through the Rancher UI

## Step 2: Install Charts from ob-team-charts

After creating the ClusterRepo, Rancher will pull charts from the specified repository.

1. **Filter chart sources**: In the Rancher UI, go to **Apps > Charts**. Use the dropdown menu to show only your new ClusterRepo (the name matches the `metadata.name` field).

2. **Enable prerelease charts**: Go to **Preferences > Helm Charts > Include Prerelease Versions** and enable it.

3. **Install charts**: All charts from the target repository are now available in the Apps section and can be installed normally.
