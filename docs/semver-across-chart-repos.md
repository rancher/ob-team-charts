# Chart Version Management Across Repositories

This document explains how we manage chart versions in both `ob-team-charts` and `rancher/charts` while respecting Semantic Versioning (SemVer).

## SemVer Overview

Understanding SemVer is essential for managing chart versions:
- A SemVer consists of: `core version`, `build metadata` (optional), and `prerelease identifier` (optional)
- When `-` appears **first** after the core version, everything following is a prerelease identifier
- When `+` appears **first** after the core version, everything following is build metadata (even `-` characters)
- The `-` character is valid within build metadata
- The `+` character is only valid as the separator before build metadata

**Valid SemVer formats**:
- `<core>-<prerelease>` (example: `1.0.0-rc.1`)
- `<core>+<build>` (example: `1.0.0+20130313144700`)
- `<core>-<prerelease>+<build>` (example: `1.0.0-beta+exp.sha.5114f85`)

## Why we use `-` in ob-team-charts

In `ob-team-charts`, we add a suffix using `-`. This makes the version a prerelease in SemVer.

**Example**: `66.7.1-rancher.1`

**Important**: When testing charts directly from `ob-team-charts`, you must enable the "Pre-release Charts" feature in Rancher. This is a per-user setting, so if multiple users are testing, all users need to enable it.

## Version format in rancher/charts

When we ship a chart to `rancher/charts`, the version becomes:

`106.0.0+up{upstream}-rancher.{num}`

This is valid SemVer with build metadata (the `+` section).

## Why not use `+` in ob-team-charts?

If we used `+` in `ob-team-charts`, the version would be:
- `ob-team-charts`: `106.0.0+up{upstream}`
- `rancher/charts`: `106.0.0+up{upstream}+rancher.{num}` ← **Invalid SemVer** (two `+` symbols)

To make this work, we would need to modify tooling in `rancher/charts` to convert the upstream `+` to a different character. Using `-` in `ob-team-charts` avoids this complexity.