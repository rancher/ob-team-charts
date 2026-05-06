# Installation Guide for rancher-monitoring-dashboards (Sidecar Approach)

This chart provides Rancher monitoring dashboards and integrates with kube-prometheus-stack using an nginx sidecar approach (same as the full rancher-monitoring chart).

## Prerequisites

- Kubernetes cluster with Rancher
- Helm 3.x

## Installation Steps

### Step 1: Install kube-prometheus-stack with Grafana sidecar

First, install kube-prometheus-stack with the provided values file that configures the nginx sidecar:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace cattle-monitoring-system \
  --create-namespace \
  -f kube-prometheus-stack-values.yaml
```

**What this does:**
- Installs Prometheus, Alertmanager, and Grafana
- Adds nginx sidecar to Grafana pod for URL rewriting
- Configures Grafana for sub-path serving and embedding
- Sets up anonymous viewer access for Rancher Dashboard

### Step 2: Install rancher-monitoring-dashboards

Next, install this chart to add dashboards and bridge services:

```bash
helm install rancher-monitoring ./rancher-monitoring-0.2.0.tgz \
  --namespace cattle-monitoring-system
```

**What this does:**
- Creates dashboard ConfigMaps in `cattle-dashboards` namespace
- Creates nginx proxy ConfigMap (mounted by Grafana sidecar)
- Creates bridge services (`rancher-monitoring-grafana`, `rancher-monitoring-prometheus`, `rancher-monitoring-alertmanager`)
- Creates RBAC roles for dashboard access

### Step 3: Wait for Grafana to be Ready

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n cattle-monitoring-system --timeout=300s
```

### Step 4: Verify Installation

Check that services are routing correctly:

```bash
kubectl get endpoints -n cattle-monitoring-system | grep rancher-monitoring
```

**Expected output:**
```
rancher-monitoring-alertmanager   10.43.x.x:9093           1m
rancher-monitoring-grafana        10.43.x.x:8080           1m
rancher-monitoring-prometheus     10.43.x.x:9090           1m
```

All endpoints should show IP addresses (not `<none>`).

### Step 5: Access in Rancher Dashboard

1. Navigate to **Cluster Explorer → Monitoring → Grafana**
2. Navigate to **Workloads → Pods → Select any pod → Scroll to dashboard**

The Grafana iframes should load correctly with all plugins!

## How It Works

### Architecture

```
Rancher Dashboard
    ↓
rancher-monitoring-grafana:80 (bridge service)
    ↓
kube-prometheus-stack Grafana pod
    ↓ port 8080
nginx sidecar (URL rewriting)
    ↓ localhost:3000
Grafana container
```

### Key Components

1. **Bridge Service** (`rancher-monitoring-grafana`)
   - Created by this chart
   - Routes to kube-prometheus-stack Grafana pod port 8080

2. **Nginx Sidecar**
   - Injected into Grafana pod via kube-prometheus-stack values
   - Listens on port 8080
   - Rewrites `appSubUrl` for Rancher's proxy path
   - Forwards to Grafana on localhost:3000

3. **Grafana Configuration**
   - `root_url`: Full proxy path
   - `serve_from_sub_path`: true
   - Grafana generates correct URLs for plugins/assets

## Custom Configuration

### Using a Different kube-prometheus-stack Release Name

If you installed kube-prometheus-stack with a different release name (e.g., `my-monitoring`):

```bash
# Update selector in rancher-monitoring-dashboards values
cat > custom-values.yaml <<EOF
dashboardIntegration:
  grafana:
    selector:
      app.kubernetes.io/name: grafana
      app.kubernetes.io/instance: my-monitoring
EOF

helm upgrade rancher-monitoring ./rancher-monitoring-0.2.0.tgz \
  --namespace cattle-monitoring-system \
  -f custom-values.yaml
```

Also update the nginx ConfigMap name reference in `kube-prometheus-stack-values.yaml` if needed.

## Upgrading from Standalone Proxy Approach

If you previously tried the standalone proxy deployment (v0.1.0):

```bash
# Uninstall old version
helm uninstall rancher-monitoring -n cattle-monitoring-system

# Uninstall kube-prometheus-stack (if you want a clean start)
helm uninstall kube-prometheus-stack -n cattle-monitoring-system

# Follow installation steps above
```

## Troubleshooting

### Grafana Pod Won't Start

**Symptom**: Grafana pod shows `ConfigMapNotFound` error

**Cause**: You installed kube-prometheus-stack before rancher-monitoring-dashboards

**Solution**: Install in correct order (kube-prometheus-stack references the ConfigMap created by this chart)

**Alternative**: Split installation into two steps:
1. Install rancher-monitoring-dashboards first (creates ConfigMap)
2. Then install kube-prometheus-stack

### Endpoints Show `<none>`

**Symptom**: `kubectl get endpoints rancher-monitoring-grafana` shows no addresses

**Cause**: Selector doesn't match Grafana pod labels

**Solution**: Check actual pod labels and update values.yaml:
```bash
kubectl get pods -n cattle-monitoring-system -l app.kubernetes.io/name=grafana --show-labels
```

### Grafana Dashboard Shows 404 or Blank

**Symptom**: Embedded Grafana iframes don't load

**Possible causes:**
1. Nginx sidecar not configured correctly
2. Grafana `root_url` not set
3. RBAC permissions missing

**Check:**
```bash
# Verify sidecar is running
kubectl get pod -n cattle-monitoring-system -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].spec.containers[*].name}'
# Should show: grafana-sc-dashboard grafana grafana-proxy

# Test nginx sidecar
kubectl exec -n cattle-monitoring-system -c grafana-proxy deployment/kube-prometheus-stack-grafana -- wget -O- http://localhost:8080/api/health
```

## Comparison with Full rancher-monitoring Chart

| Feature | rancher-monitoring | rancher-monitoring-dashboards |
|---------|-------------------|-------------------------------|
| Prometheus | ✓ Deploys | Uses kube-prometheus-stack |
| Alertmanager | ✓ Deploys | Uses kube-prometheus-stack |
| Grafana | ✓ Deploys with sidecar | Uses kube-prometheus-stack + configures sidecar |
| Dashboards | ✓ Included | ✓ Included |
| Exporters | ✓ Included | Not included |
| ServiceMonitors | ✓ Included | Not included |
| Bridge Services | ✓ Included | ✓ Included |

## Support

For issues or questions:
- Check INTEGRATION-GUIDE.md for detailed scenarios
- Check README.md for quick reference
- Verify all installation steps were followed in order
