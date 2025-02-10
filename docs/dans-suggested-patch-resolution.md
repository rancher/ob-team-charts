# Dan's Suggested Patch Resolution Process

This is a process that I think I discovered on my own - if not shout out to whomever helped me figure it out - that resolves patch issues swiftly.
The directions here assume that you have a chart where the patches had conflicts. Intentionally excluding the "happy path" where existing patches work.

The basic "process loop" looks like this:

1. Pick a `{Package}/{Version}/{Chart}` that has conflicts,
2. Create a `patch-off` directory in the `{Package}/{Version}/{Chart}/generated-changes` directory,
3. Try `make prepare` for the specific Package/Version/Chart,
4. When it hits an error patch, do:
   1. Copy the patch from `patch/{filePath}` to `patch-off/{filePath}`
   2. Run `make clean` targeting your current `{Package}/{Version}/{Chart}`
   3. Run `make patch` targeting your current `{Package}/{Version}/{Chart}`
   4. Repeat until no patches with errors
5. After that is complete the final time your run `make patch` create a commit:
   - Message something like `[DROP] turn conflicting patches off`
6. The next phase is resolving those conflicting patches,
   - Something that requires its own directions/decision-tree.
   - See "How to resolve patches we turned-off?" section for more info.
   - In this phase, as you resolve a conflicted patch you can make a commit for each or a single you keep amending.
7. Once all patches are resolved or recreated create a new commit:
   - Something like `[rancher-monitoring/{version}/{subpackage}] update patches` where you squash all changes made to existing patches,
8. Next, check if the new version has any newly added templates, other new files, or updated values needing patching,
   - During this process, do as many make prepares/cleans/patch/etc as needed, 
9. If they do, then update those first and commit again:
   - Something like `[rancher-monitoring/{version}/{subpackage}] add new patches for rebase`
10. Finally, you should have a working sub-chart that doesn't error on `make prepare` and can remove the temporary commit
    - This is why we labeled it with `[DROP]` previously,
    - Once removed git history will rewrite and patches show normal (but maybe large/complciated) diffs,
    - Find the commit hash and do: `git rebase -i {hash}~1`, then drop it.
    - Afterward there should be no actual new diffs (re-added files or newly removed ones); if there are, resolve them as needed.

## How to resolve patches we turned-off?
So you have a handful, or a lot, of patches that are now in the `patch-off` directory - what's next? Well resolving those patch diffs.

The best way to do this will vary based on how much of the patch diff was rejected.
The two primary categories of how this is done would be:
1. Updating existing patch to fit new target, OR
2. Start with no patch and rebuild it via previous stable version's chart equivilent file

In other words, Sometimes you will notice specific confined sections that were rejected. Overtimes, you may have way too many diffs and what's best is to actually start with no patch.

In a case where you can re-use existing patches, first copy the patch back in place and remove that section of patch (or even manually update that sections patch text values to fix them).
Then recapture the change via `make patch` to get an updated patch generated.
Once happy with the results make a commit to add the fixed one and move on to the next patch. (Leaving a duplicate outdated patch in `patch-off`.)

Overtimes, when it's better to start from no patch being active, you will work to re-create the effects of one based on the old results.
Meaning you compare the equivalent file from the newest stable chart version before the current rebase.
This is more tedious of a process but may be necessary for large rebases and be a faster result than other options.
As you do this process for each patch file you can make a new commit that you amend as you `make prepare/patch/clean` your way through the whole file.

### Fixing disabled Grafana dashboard patches
This mode is potentially causing us to skip some changes, however it keeps our existing patch working.
In some cases that is a better outcome than fully breaking the dashboard (or causing a regression) by not using our patch.

The issue with these is that they come as a minified JSON blob that our patch expands.
This means we can't really identify what to fix in ours manually by comparing.
And that if we apply old patches that we created, then the expanded form we use may miss needed updates.

That said the easy way to fix these is:
1. Prepare the chart without the broken patches (while they are in `patch-off`),
2. Copy them from your disabled patch directory (e.g from `patch-off` back to `patch`)
3. Open the prepared (unedited file) from charts folder,
4. Copy the long line of JSON near the bottom (from start `{{` to end `}}`),
5. Go to the patch file,
6. Find the line starting with `-` that looks similar to the one copied,
7. Paste the copied text into that line from `{{` to `}}`

I'd suggest doing 2-3 patches at a time and then re-run `make prepare` to see if they break.

## Can this process be made easier?
Yes - I'm working on some changes to `charts-build-scripts` that will allow a "skip errors" mode.

The short version is that with `skip errors mode` enabled it will allow you to run `make prepare` in one shot.
Then all patches with issues will be revealed in one run - and can be handled as appropriate on a patch by patch basis.