# Docs for Dev Scripts

## Verify Chart Images

The verify-chart-images script checks whether the Docker images referenced in a Helm chart exist in Docker Hub.
It can process images from either:

- A Rancher Monitoring chart version (provided as an argument, must be in `charts/rancher-monitoring`).
- Standard input, such as the output of a Helm install dry-run.

### Usage

You can run the script in two ways:

1. **By specifying a Rancher Monitoring chart version:**
   ```bash
   ./dev-scripts/verify-chart-images <chart_version>
   ```
   Example:
   ```bash
   ./dev-scripts/verify-chart-images 66.7.1-rancher.1
   ```

> [!NOTE]
> In this mode you should setup a `debug.yaml` (values.yaml) file generated from Rancher.
> In the future we may provide a default file that does the equivalent in a generic way.

2. **By piping Helm debug output to the script:**
   ```bash
   helm install --dry-run --debug rancher-monitoring ./charts/rancher-monitoring/<chart_version> -n cattle-monitoring-system | ./dev-scripts/verify-chart-images
   ```
   Example:
   ```bash
   helm install --dry-run --debug rancher-monitoring ./charts/rancher-monitoring/57.0.3-rancher.1 -n cattle-monitoring-system | ./dev-scripts/verify-chart-images
   ```

3. **With a values file for additional customization:**
   ```bash
   helm install --dry-run --debug rancher-monitoring ./charts/rancher-monitoring/<chart_version> -f ./debug.yaml -n cattle-monitoring-system | ./dev-scripts/verify-chart-images
   ```
   Example:
   ```bash
   helm install --dry-run --debug rancher-monitoring ./charts/rancher-monitoring/57.0.3-rancher.1 -f ./debug.yaml -n cattle-monitoring-system | ./dev-scripts/verify-chart-images
   ```

### Output Example
If an image exists:
```bash
✔ myrepo/myimage:latest exists
```
If an image is missing:
```bash
✘ myrepo/missingimage:1.0 NOT found
```

### Dependencies

Ensure the following dependencies are installed:
- bash
- curl
- helm (for processing chart versions)

