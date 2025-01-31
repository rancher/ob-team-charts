# ob-team-charts
A repo for Rancher Observability &amp; Backups team's charts - a canonical dev spot just before rancher/charts.

## How does re-basing of Rancher Monitoring Charts work with this repo involved?
Today this repo is primarily used to benefit `rancher-monitoring`, `rancher-project-monitoring` and `prometheus-federator`.
Specifically to incorporate the following benefits:
- O&B team maintains a single canonical version of upstream chart changes,
- `rancher-monitoring` and `rancher-project-monitoirng` rebase can be a single PR.

Please review the [Monitoring Rebase doc](./docs/monitoring-rebase.md) for more details on the process this repo allows.