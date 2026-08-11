# Developer Scripts

> [!NOTE]
> All dev-scripts are wrappers for a Go CLI tool. New dev tools can be added as either bash scripts or as part of the Go CLI.

## Verify Chart Images

This script checks whether Docker images referenced in a Helm chart exist in Docker Hub.

**Input sources**:
- A Rancher Monitoring chart version (must be in `charts/rancher-monitoring`)
- Standard input from a Helm install dry-run

### Usage

**Method 1: Specify a chart version**

```bash
./dev-scripts/verify-chart-images <chart_version>
```

Example:
```bash
./dev-scripts/verify-chart-images 66.7.1-rancher.1
```

> [!NOTE]
> When using this method, create a `debug.yaml` (values.yaml) file generated from Rancher. A default file may be provided in the future.

**Method 2: Pipe Helm debug output**

```bash
helm install --dry-run --debug rancher-monitoring ./charts/rancher-monitoring/<chart_version> -n cattle-monitoring-system | ./dev-scripts/verify-chart-images
```

Example:
```bash
helm install --dry-run --debug rancher-monitoring ./charts/rancher-monitoring/57.0.3-rancher.1 -n cattle-monitoring-system | ./dev-scripts/verify-chart-images
```

**Method 3: Use a custom values file**

```bash
helm install --dry-run --debug rancher-monitoring ./charts/rancher-monitoring/<chart_version> -f ./debug.yaml -n cattle-monitoring-system | ./dev-scripts/verify-chart-images
```

Example:
```bash
helm install --dry-run --debug rancher-monitoring ./charts/rancher-monitoring/57.0.3-rancher.1 -f ./debug.yaml -n cattle-monitoring-system | ./dev-scripts/verify-chart-images
```

### Output

The script outputs a table showing each image and its status:
```bash
+----+-------------------------------------------------------------------------+--------+
|  # | IMAGE                                                                   | STATUS |
+----+-------------------------------------------------------------------------+--------+
|  1 | rancher/mirrored-prometheus-alertmanager:v0.27.0                        | ✅     |
|  2 | rancher/mirrored-library-nginx:1.24.0-alpine                            | ✅     |
|  3 | rancher/mirrored-thanos-thanos:v0.34.1                                  | ✅     |
|  4 | rancher/mirrored-kube-state-metrics-kube-state-metrics:v2.10.1          | ✅     |
|  5 | rancher/mirrored-prometheus-node-exporter:v1.7.0                        | ✅     |
|  6 | rancher/mirrored-prometheus-operator-prometheus-operator:v0.72.0        | ✅     |
|  7 | rancher/shell:v0.2.1                                                    | ✅     |
|  8 | rancher/mirrored-prometheus-windows-exporter:0.25.1                     | ✅     |
|  9 | rancher/mirrored-prometheus-adapter-prometheus-adapter:v0.12.0          | ✅     |
| 10 | rancher/mirrored-prometheus-operator-prometheus-config-reloader:v0.72.0 | ✅     |
| 11 | rancher/mirrored-kiwigrid-k8s-sidecar:1.26.1                            | ✅     |
| 12 | rancher/kubectl:v1.20.2                                                 | ✅     |
| 13 | rancher/mirrored-prometheus-prometheus:v2.50.1                          | ✅     |
| 14 | rancher/mirrored-grafana-grafana:10.4.9                                 | ✅     |
| 15 | rancher/mirrored-ingress-nginx-kube-webhook-certgen:v1.4.3              | ✅     |
+----+-------------------------------------------------------------------------+--------+
```

The script may also show images that need manual verification:

```bash
👨‍🔧 These need manual checks:
● image: {{ template system_default_registry . }}{{ .Values.proxy.image.repository }}:{{ .Values.proxy.image.tag }}
● image: {{ template system_default_registry . }}{{ .Values.prometheus.prometheusSpec.proxy.image.repository }}:{{ .Values.prometheus.prometheusSpec.proxy.image.tag }}
```

### Requirements

- `bash`
- `helm` (for processing chart versions)

## Get Rebase Target Info

When starting a rebase for monitoring charts, you need to collect information about chart and image versions. This tool automates that process by gathering chart information based on the upstream target version.

### Usage

```bash
./dev-scripts/get-rebase-info <upstream chart version>
```

Example:
```bash
./dev-scripts/get-rebase-info 66.7.1
```

### Output

The script creates a `rebase.yaml` file in the repository root with the following sections:

- **`target_version`**: The upstream chart version you specified
- **`found_chart`**: Details about the chart matching the target version
- **`chart_dependencies`**: Sub-chart dependencies from the upstream `Chart.yaml`
- **`dependency_chart_versions`**: Specific sub-chart versions to use for this rebase (automatically selects the highest valid version)
  - Each entry shows the sub-chart version and its git commit hash
  - Update `packages/rancher-monitoring/{version}/{sub-chart}/package.yaml` to use the correct hash
- **`charts_images_lists`**: All images found, grouped by chart
  - Use this to review and update the image list in `image-mirror`
  - **Note**: This feature is work in progress and may not detect all images