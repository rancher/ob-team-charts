# Patch Resolution Process

This process helps resolve patch conflicts during chart rebases. It assumes your chart has patch conflicts. If existing patches work without conflicts, you don't need this process.

## Step-by-step process

1. **Select the chart**: Pick a `{Package}/{Version}/{Chart}` that has conflicts

2. **Create patch-off directory**: In `{Package}/{Version}/{Chart}/generated-changes`, create a `patch-off` directory

3. **Run make prepare**: Try `make prepare` for the specific Package/Version/Chart

4. **Disable failing patches**: When a patch fails:
   - Copy the patch from `patch/{filePath}` to `patch-off/{filePath}`
   - Run `make clean` for your `{Package}/{Version}/{Chart}`
   - Run `make patch` for your `{Package}/{Version}/{Chart}`
   - Repeat until no patches fail

5. **Create temporary commit**: After the last `make patch` run, create a commit with message: `[DROP] turn conflicting patches off`

6. **Resolve disabled patches**: See the "Resolving disabled patches" section below

7. **Commit resolved patches**: Create a commit like: `[rancher-monitoring/{version}/{subpackage}] update patches`

8. **Check for new patches**: Check if the new version has new templates, files, or values that need patching

9. **Add new patches**: If needed, commit with message: `[rancher-monitoring/{version}/{subpackage}] add new patches for rebase`

10. **Remove temporary commit**: 
    - Find the commit hash of the `[DROP]` commit
    - Run: `git rebase -i {hash}~1` and drop it
    - The git history will rewrite to show normal diffs
    - Verify no unexpected files were added or removed

## Resolving disabled patches

After moving patches to `patch-off`, you need to resolve them. The approach depends on how much of the patch was rejected.

### Two approaches

**Approach 1: Update existing patch**
- Use when only specific sections were rejected
- Copy the patch back from `patch-off` to `patch`
- Remove or fix the rejected sections
- Run `make patch` to regenerate the updated patch
- Commit the fixed patch

**Approach 2: Rebuild from scratch**
- Use when too many sections were rejected
- Compare the file with the previous stable chart version
- Recreate the patch based on what changed
- Run `make prepare`, `make patch`, and `make clean` as needed
- More work, but may be faster for large rebases

### Special case: Grafana dashboard patches

Grafana dashboard patches are tricky because they contain minified JSON that our patches expand. We cannot easily identify what needs fixing by comparing the JSON.

**Process**:

1. Run `make prepare` without the broken patches (they should be in `patch-off`)
2. Copy patches from `patch-off` back to `patch`
3. Open the prepared file from the charts folder
4. Copy the long JSON line near the bottom (from `{{` to `}}`)
5. Open the patch file
6. Find the line starting with `-` that looks similar
7. Paste the copied JSON into that line (replacing from `{{` to `}}`)

**Tip**: Fix 2-3 patches at a time, then run `make prepare` to verify they work.

## Skip errors mode

The `charts-build-scripts` tool supports a "skip errors" mode. Enable it using either method:

**Environment variable**:
```bash
SOFT_ERRORS=true make prepare
```

**CLI flag**:
```bash
make prepare --soft-errors
```

This feature:
- Allows `make prepare` to run completely even with failing patches
- Reveals all patch issues in one run
- Makes it easier to handle problems one patch at a time