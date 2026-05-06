# Rancher Monitoring Dashboards Integration Guide

## Overview

This chart bridges Rancher Dashboard's hardcoded monitoring service expectations with your actual monitoring stack (typically kube-prometheus-stack).

## Architecture

```
Rancher Dashboard (hardcoded) → rancher-monitoring-* services → Your actual monitoring pods
                                 (created by this chart)        (kube-prometheus-stack)
```

Rancher Dashboard code has **hardcoded service names**:
- `http:rancher-monitoring-grafana:80`
- `http:rancher-monitoring-prometheus:9090`
- `http:rancher-monitoring-alertmanager:9093`

This chart creates Services with these exact names in `cattle-monitoring-system` namespace, using pod selectors to route traffic to your actual monitoring stack.

## Prerequisites

1. A Kubernetes cluster with Rancher
2. kube-prometheus-stack (or equivalent) installed
3. This chart installed in `cattle-monitoring-system` namespace

## Installation Scenarios

### Scenario 1: Fresh Install (Recommended)

**Step 1**: Install kube-prometheus-stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace cattle-monitoring-system \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false
```

**Step 2**: Install rancher-monitoring-dashboards with defaults

```bash
helm install rancher-monitoring ./rancher-monitoring-dashboards-*.tgz \
  --namespace cattle-monitoring-system
```

The default values automatically connect to kube-prometheus-stack!

**Step 3**: Verify

```bash
# Check services exist
kubectl get svc -n cattle-monitoring-system | grep rancher-monitoring

# Check endpoints are populated (should show IP addresses)
kubectl get endpoints -n cattle-monitoring-system | grep rancher-monitoring
```

### Scenario 2: Custom Release Name

If you installed kube-prometheus-stack with name `my-prom`:

**Step 1**: Find your pod labels

```bash
kubectl get pods -n cattle-monitoring-system -l app.kubernetes.io/name=prometheus --show-labels
```

**Step 2**: Create custom-values.yaml

```yaml
dashboardIntegration:
  prometheus:
    selector:
      app.kubernetes.io/name: prometheus
      operator.prometheus.io/name: my-prom-prometheus
  alertmanager:
    selector:
      app.kubernetes.io/name: alertmanager
      alertmanager: my-prom-alertmanager
  grafana:
    selector:
      app.kubernetes.io/name: grafana
      app.kubernetes.io/instance: my-prom
```

**Step 3**: Install with custom values

```bash
helm install rancher-monitoring ./rancher-monitoring-dashboards-*.tgz \
  --namespace cattle-monitoring-system \
  -f custom-values.yaml
```

### Scenario 3: Different Namespace

**This scenario is NOT supported** because Rancher Dashboard expects services in `cattle-monitoring-system`.

**Workaround**: Reinstall kube-prometheus-stack in cattle-monitoring-system.

### Scenario 4: External/Managed Prometheus

If using a managed Prometheus (e.g., GCP Managed Service for Prometheus), you cannot use selector-based services.

**Alternative approach** (requires Rancher Dashboard modifications - NOT in current scope):
```yaml
dashboardIntegration:
  prometheusURL: "https://prometheus.example.com"
  grafanaURL: "https://grafana.example.com"
```

## Grafana Integration Options

### Option A: Grafana Proxy (Recommended)

Use the built-in nginx proxy to handle URL rewriting:

```yaml
grafanaProxy:
  enabled: true
  upstreamService: kube-prometheus-stack-grafana
  upstreamPort: 80
```

**Pros**:
- No modifications to kube-prometheus-stack
- Clean separation of concerns
- Handles Rancher's proxy path rewriting automatically

**Cons**:
- Additional nginx pod

### Option B: Direct Service Selector

If your Grafana already has nginx sidecar (from older rancher-monitoring):

```yaml
dashboardIntegration:
  grafana:
    selector:
      app.kubernetes.io/name: grafana
      app.kubernetes.io/instance: kube-prometheus-stack
    port: 8181  # nginx sidecar port
grafanaProxy:
  enabled: false
```

### Option C: Disable Grafana Integration

If you only want Prometheus/Alertmanager:

```yaml
dashboardIntegration:
  grafana:
    selector: {}  # Empty selector = no service created
```

## Verification

After installation, verify the services are created and routing correctly:

```bash
# Check services exist
kubectl get svc -n cattle-monitoring-system | grep rancher-monitoring

# Expected output:
# rancher-monitoring-grafana        ClusterIP   10.x.x.x   <none>   80/TCP     1m
# rancher-monitoring-prometheus     ClusterIP   10.x.x.x   <none>   9090/TCP   1m
# rancher-monitoring-alertmanager   ClusterIP   10.x.x.x   <none>   9093/TCP   1m

# Check service endpoints are populated
kubectl get endpoints -n cattle-monitoring-system rancher-monitoring-prometheus
kubectl get endpoints -n cattle-monitoring-system rancher-monitoring-alertmanager
kubectl get endpoints -n cattle-monitoring-system rancher-monitoring-grafana

# Expected: Each endpoint should show IP addresses, NOT <none>

# Test connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n cattle-monitoring-system \
  -- curl http://rancher-monitoring-prometheus:9090/-/healthy

# Expected: Healthy
```

## Troubleshooting

### No endpoints for service

**Symptom**: `kubectl get endpoints rancher-monitoring-prometheus` shows no addresses.

**Cause**: Selector doesn't match any pods.

**Solution**:
1. Find the actual pod labels:
```bash
kubectl get pods -n cattle-monitoring-system -l app.kubernetes.io/name=prometheus --show-labels
```

2. Update values.yaml with correct selectors and upgrade the chart.

### Rancher Dashboard shows "Failed to connect"

**Possible causes**:
1. Services not in cattle-monitoring-system namespace
2. monitoring-ui-view ClusterRole not bound to user
3. Grafana requires authentication but user is not authenticated

**Solution**:
```bash
# Check if user has RBAC permissions
kubectl auth can-i get services/proxy --as=system:serviceaccount:cattle-system:cattle -n cattle-monitoring-system

# Check ClusterRole exists
kubectl get clusterrole monitoring-ui-view
```

### Grafana shows 404 or redirect loops

**Cause**: Grafana not configured for sub-path serving.

**Solution**: Use grafanaProxy instead of direct service selector:

```yaml
grafanaProxy:
  enabled: true
```

### Dashboards don't appear in Rancher UI

**Cause**: Dashboard ConfigMaps not being picked up by Grafana sidecar.

**Solution**:
```bash
# Check dashboard ConfigMaps exist
kubectl get configmap -n cattle-dashboards -l grafana_dashboard=1

# Check Grafana sidecar configuration
kubectl get deployment -n cattle-monitoring-system kube-prometheus-stack-grafana -o yaml | grep -A 10 sidecar
```

## Advanced Configuration

### Custom Grafana Port

If Grafana runs on non-standard port:

```yaml
dashboardIntegration:
  grafana:
    port: 8080
```

Note: The external service still exposes port 80; this is the targetPort.

### Disable Specific Components

```yaml
dashboardIntegration:
  prometheus:
    selector: {}  # Disables Prometheus service
  alertmanager:
    selector: {}  # Disables Alertmanager service
  grafana:
    selector: {}  # Disables Grafana service
```

### Dashboard Groups

Disable specific dashboard groups:

```yaml
dashboardArtifacts:
  groups:
    rancherCore: true
    fleet: false  # Don't deploy Fleet dashboards
    ingressNginx: true
    logging:
      fluentd: false
      fluentbit: false
```

## Finding Pod Labels

For any component, you can find the actual labels with:

```bash
# For Prometheus
kubectl get pods -n cattle-monitoring-system -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.labels}' | jq

# For Alertmanager
kubectl get pods -n cattle-monitoring-system -l app.kubernetes.io/name=alertmanager -o jsonpath='{.items[0].metadata.labels}' | jq

# For Grafana
kubectl get pods -n cattle-monitoring-system -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.labels}' | jq
```

Then copy the relevant labels to your values.yaml selectors.

## Migration from rancher-monitoring

If migrating from the full `rancher-monitoring` chart:

**Step 1**: Export your custom values

```bash
helm get values rancher-monitoring -n cattle-monitoring-system > old-values.yaml
```

**Step 2**: Uninstall old chart

```bash
helm uninstall rancher-monitoring -n cattle-monitoring-system
```

**Step 3**: Install kube-prometheus-stack

```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace cattle-monitoring-system
```

**Step 4**: Install this chart

```bash
helm install rancher-monitoring ./rancher-monitoring-dashboards-*.tgz \
  --namespace cattle-monitoring-system
```

**Note**: Some values from old-values.yaml may need to be adapted for kube-prometheus-stack.

## Known Limitations

- ✅ Supports: kube-prometheus-stack in same namespace (cattle-monitoring-system)
- ✅ Supports: Custom kube-prometheus-stack release name (with selector override)
- ✅ Supports: Grafana disabled in kube-prometheus-stack
- ✅ Supports: Multiple Prometheus replicas (service load-balances automatically)
- ❌ **NOT** supported: Monitoring stack in different namespace
- ❌ **NOT** supported: External/managed Prometheus (would require URL-based integration)
- ❌ **NOT** supported: Multiple Grafana instances with same labels

## Getting Help

If you encounter issues not covered in this guide:

1. Check the Helm chart NOTES.txt for verification commands
2. Check logs of the monitoring pods
3. Verify RBAC permissions
4. Open an issue in the chart repository
