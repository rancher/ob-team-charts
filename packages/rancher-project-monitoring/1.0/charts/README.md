# rancher-project-monitoring

Project monitoring integration for Rancher that provides project-scoped dashboards and metadata.

## Architecture Change

**Previous versions (< 1.0.0):** Deployed dedicated Prometheus, Grafana, and Alertmanager instances per project, federating metrics from the cluster-wide Prometheus.

**Version 1.0.0+:** Metadata-only deployment that integrates with cluster-wide monitoring infrastructure. No per-project workloads are created, reducing operational overhead and improving CVE remediation speed.

## What this chart deploys

- **Dashboard ConfigMaps**: Rancher-specific Grafana dashboards for workloads and pods
- **Integration metadata**: ConfigMap containing Grafana/Prometheus URLs and dashboard inventory
- **RBAC roles**: Project-scoped role markers for Rancher permission aggregation

## Configuration

```yaml
dashboardIntegration:
  grafanaURL: "http://grafana.cattle-monitoring-system.svc:80"
  prometheusURL: "http://prometheus.cattle-monitoring-system.svc:9090"
  alertmanagerURL: "http://alertmanager.cattle-monitoring-system.svc:9093"
```

## Prerequisites

- Cluster-wide monitoring stack (kube-prometheus-stack or similar)
- Prometheus Federator (for automated project deployments)

## Usage

This chart is deployed automatically by [Prometheus Federator](https://github.com/rancher/prometheus-federator) when a project monitoring is created. Manual installation is not recommended.
