# rancher-monitoring dashboard artifact prototype

This chart keeps the `rancher-monitoring` release identity, but renders only dashboard delivery artifacts and integration metadata.

## What this prototype does

- Ships the Rancher dashboard JSON artifacts under `files/rancher/**`
- Ships the ingress-nginx addon dashboards under `files/ingress-nginx/**`
- Renders dashboard ConfigMaps into a dashboard namespace independent of `grafana.enabled`
- Publishes a `*-dashboard-values` ConfigMap with external integration metadata for Rancher consumers
- Leaves Grafana, Prometheus, Alertmanager, exporters, PushProx, datasources, and operator-managed runtime resources out of the rendered chart

## What this prototype does not do

- It does not deploy Grafana, Prometheus, Alertmanager, exporters, or PushProx
- It does not wire datasources into an external Grafana instance for you
- It does not, by itself, update Rancher Dashboard UI logic. The current prototype depends on matching Dashboard-side changes so cluster monitoring can consume the chart-published metadata.

## Values

### Dashboard artifact delivery

```yaml
dashboardArtifacts:
  enabled: true
  namespace: cattle-dashboards
  useExistingNamespace: false
  cleanupOnUninstall: false
  label: grafana_dashboard
  labelValue: "1"
  annotations: {}
  groups:
    rancherCore: true
    fleet: true
    ingressNginx: true
    performance: true
    logging:
      fluentd: true
      fluentbit: true
    backupRestore: true
```

### External integration metadata

```yaml
dashboardIntegration:
  grafanaURL: https://grafana.example.com
  prometheusURL: https://prometheus.example.com
```

The chart writes these values into the release-scoped `rancher-monitoring` dashboard-values ConfigMap as `values.json`, alongside dashboard UID/title inventory, chart metadata, and dashboard namespace/label information.

### Grafana proxy (optional)

This chart can optionally deploy a standalone nginx proxy that handles Rancher's Kubernetes API proxy URL rewriting for Grafana. This eliminates the need to inject nginx as a sidecar into the Grafana pod managed by kube-prometheus-stack.

```yaml
grafanaProxy:
  enabled: false  # Set to true to deploy the proxy
  upstreamService: ext-monitoring-grafana  # The kube-prometheus-stack Grafana service name
  upstreamPort: 80  # The port on the upstream Grafana service
  proxyPath: /api/v1/namespaces/cattle-monitoring-system/services/http:rancher-monitoring-grafana:80/proxy
  replicas: 1
```

When enabled, the proxy:
- Creates a Deployment with nginx that proxies to the upstream Grafana service
- Creates a Service named `rancher-monitoring-grafana` that Rancher Dashboard can target
- Rewrites URLs to handle the Kubernetes API proxy path
- Injects the correct `appSubUrl` into Grafana's JavaScript configuration
- Caches static assets for improved performance

This allows kube-prometheus-stack to be installed with vanilla configuration, with the proxy layer added afterward by this chart.

## Rendered resources

By default this prototype renders:

- one namespace for dashboard ConfigMaps, unless `dashboardArtifacts.useExistingNamespace=true`
- one metadata ConfigMap in the release namespace
- three RBAC Roles for metadata ConfigMaps in the release namespace
- three RBAC Roles for dashboard artifact ConfigMaps in the dashboard namespace
- twelve dashboard ConfigMaps covering the current Rancher and addon dashboard artifact set

The current artifact inventory contains 26 dashboard JSON files:

- Rancher core: home, cluster, nodes, kubernetes, workloads, pods
- Fleet dashboards
- Performance debugging dashboard
- Logging dashboards for Fluent Bit and Fluentd
- Backup and restore dashboard
- ingress-nginx dashboards

## Operational notes

- `dashboardIntegration.grafanaURL` should point at the Grafana URL Rancher Dashboard itself will load for cluster dashboards.
- For Rancher-embedded dashboards, prefer the same Rancher/Kubernetes service-proxy shape used by project monitoring, for example:
  - `/api/v1/namespaces/monitoring/services/http:ext-monitoring-grafana:80/proxy/`
- The proxy URL alone is not enough. Project monitoring works because Grafana is fronted by an nginx sidecar that rewrites Grafana's `appSubUrl` for the Rancher proxy path. A raw Grafana service configured only with `root_url` / `serve_from_sub_path` can loop on `301` redirects for HTML and asset routes.
- A direct external Grafana URL may still work, but then iframe embedding, cookies, and auth must all work cross-origin.
- `dashboardIntegration.prometheusURL` is optional and is included for future consumers that need a Prometheus endpoint hint.
- The current Dashboard prototype branch reads this chart's `rancher-monitoring-dashboard-values` ConfigMap directly for cluster monitoring. That means the chart's published metadata, not `catalog.cattle.io.App.status.dashboardValues`, is the effective integration contract for this proof of concept.
- Backup/restore and logging dashboards are delivered as artifacts only. They require external datasource wiring and metric collection to become functional.
- PushProx replacement and equivalent external collection paths are intentionally deferred in this prototype.
- Grafana must be configured to allow embedding and to avoid redirecting embedded requests to an iframe-blocked login page. For local prototype testing, this usually means:
  - `allow_embedding = true`
  - anonymous or equivalent pre-authenticated viewer access for the proxied dashboard requests
  - avoiding an embedded `/login` flow that returns `X-Frame-Options: deny`

## Rancher Dashboard follow-up

This chart-side contract is usable today with the matching Dashboard prototype branch, which reads the release-scoped dashboard-values ConfigMap directly for cluster monitoring. Upstream Rancher Dashboard still needs an equivalent productized integration path so cluster monitoring can consume this metadata without relying on app-status internals or hardcoded in-cluster service assumptions.

## Quick Start

### Prerequisites
- kube-prometheus-stack (or equivalent monitoring stack)
- Installed in `cattle-monitoring-system` namespace

### Default Installation

If you installed kube-prometheus-stack with the default release name:

```bash
helm install rancher-monitoring ./rancher-monitoring-dashboards-*.tgz \
  --namespace cattle-monitoring-system
```

The chart automatically connects to kube-prometheus-stack using default selectors.

Verify the services are routing correctly:

```bash
kubectl get endpoints -n cattle-monitoring-system | grep rancher-monitoring
```

All endpoints should show IP addresses (not `<none>`).

## Integration with kube-prometheus-stack

This chart creates "bridge" Services that connect Rancher Dashboard's hardcoded service names to your actual monitoring stack:

| Hardcoded Service Name | Port | Routes To |
|---|---|---|
| `rancher-monitoring-grafana` | 80 | kube-prometheus-stack Grafana pods |
| `rancher-monitoring-prometheus` | 9090 | kube-prometheus-stack Prometheus pods |
| `rancher-monitoring-alertmanager` | 9093 | kube-prometheus-stack Alertmanager pods |

### Default Configuration

The chart ships with selectors that match kube-prometheus-stack's default labels:

| Component | Default Selector | Target Port |
|---|---|---|
| **Grafana** | `app.kubernetes.io/name: grafana`<br/>`app.kubernetes.io/instance: kube-prometheus-stack` | 3000 |
| **Prometheus** | `app.kubernetes.io/name: prometheus`<br/>`operator.prometheus.io/name: kube-prometheus-stack-prometheus` | 9090 |
| **Alertmanager** | `app.kubernetes.io/name: alertmanager`<br/>`alertmanager: kube-prometheus-stack-alertmanager` | 9093 |

### Custom Release Name

If you installed kube-prometheus-stack with a different release name (e.g., `my-monitoring`):

```yaml
dashboardIntegration:
  prometheus:
    selector:
      app.kubernetes.io/name: prometheus
      operator.prometheus.io/name: my-monitoring-prometheus
  alertmanager:
    selector:
      app.kubernetes.io/name: alertmanager
      alertmanager: my-monitoring-alertmanager
  grafana:
    selector:
      app.kubernetes.io/name: grafana
      app.kubernetes.io/instance: my-monitoring
```

### Finding the Right Selectors

Use kubectl to find the labels on your actual monitoring pods:

```bash
# For Prometheus
kubectl get pods -n cattle-monitoring-system -l app.kubernetes.io/name=prometheus --show-labels

# For Alertmanager
kubectl get pods -n cattle-monitoring-system -l app.kubernetes.io/name=alertmanager --show-labels

# For Grafana
kubectl get pods -n cattle-monitoring-system -l app.kubernetes.io/name=grafana --show-labels
```

Then copy the relevant labels to your values.yaml selectors.

### Detailed Integration Guide

For comprehensive installation scenarios, troubleshooting, and advanced configuration, see [INTEGRATION-GUIDE.md](./INTEGRATION-GUIDE.md).
