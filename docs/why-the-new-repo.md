# FAQs about the new repo

## What is this repository for compared to `rancher/charts`?
This repository solves a unique set of problems that the O&B team has while maintaining our charts.
At a high level, these problems are:
- Repeated issues with Regressions caused by current rebase workflows,
- Missed dependency bumps during current rebase causing usage of more image tags than necessary,
    - In other words, we do a rebase and expect to remove CVEs, but they remain because some charts use old tags.
- Varying patches based on Upstream Chart Version for Rancher Branch on `rancher/charts`

## Why move Prometheus Federator repo charts to the new repo and not part of `rancher/charts`?
The charts in Prometheus Federator repo were: prometheus-federator, rancher-project-monitoring, and helm-project-operator.

Having these tied to `rancher/charts` would immediately require them being branch specific.
Additionally, it would create a workflow dynamic where changes happen:
1. In each branch of `rancher/chart` (3 times),
2. Then, in each (future) branch of Prometheus Federator (3 times),
3. Then again in each branch of `rancher/charts` (3 more times)

All just to get new Rancher Project Monitoring inside of PromFed and updated on rancher/charts.

## What factors make the current chart process for O&B complex?
- We have 3 distinct types of changes that are made to `rancher/charts` by our team:
    - Chart Rebase Work,
    - Chart Image Bumps and Security Patches,
    - Rancher Specific Changes
- Of those sets of change types, each may (or may not) have subsets of:
- Specific Image Tags Needed to Match Upstream chart targets,
- Rancher Version dependant changes

These variables cause our team to repeat a lot of work, but just subtly different.
However, the cognitive load of comparing similar, but different, patches for the same upstream charts on different branches can be taxing.