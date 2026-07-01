# Synthesize Operation

Completes the project: verifies all nodes are done, merges node branches into the integration branch, commits outstanding changes, creates a PR from integration branch to main, and reports a summary.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `tree_id` | Yes | Coordinator tree ID |
| `project_dir` | Yes | Project directory path |
| `project_branch` | Yes | Project integration branch name |
| `guardian_issue` | Yes | Guardian issue reference (e.g., `owner/repo#213`) |

## Execution Steps

### 1. Verify Completeness

```bash
coord tree show $TREE_ID
```

Parse the response and check all nodes:

```
completed = [n for n in all_nodes if n.status == "completed"]
skipped = [n for n in all_nodes if n.status == "skipped"]
blocked = [n for n in all_nodes if n.status == "blocked"]
pending = [n for n in all_nodes if n.status == "pending"]
in_progress = [n for n in all_nodes if n.status == "in_progress"]
```

| State | Action |
|-------|--------|
| All completed | Proceed to step 2 |
| Mix of completed + skipped | Proceed with warning about skipped nodes |
| Pending or in_progress remain | Warn: "Not all nodes complete. Proceed anyway?" |
| All blocked | Error: "Cannot synthesize — all nodes blocked" |

### 2. Merge Node Branches to Integration Branch

Iterate node workspaces and merge each node branch into the integration branch:

For each completed node, first commit any outstanding changes (using the git skill), then merge:

```bash
skills/goal-tree/scripts/synthesize-node.sh \
  "$PROJECT_DIR" "$NODE_ID" "$PROJECT_BRANCH" "$OWNER"
```

The script exits 1 on uncommitted changes or merge conflicts — commit first, then retry. On merge conflict, the merge worktree is preserved for resolution.

### 3. Push Integration Branch

For each repo with changes on the integration branch:

```bash
for repo in <repos-with-changes>; do
  REPO_SOURCE=~/src/github/<owner>/${repo}
  git -C "$REPO_SOURCE" push -u origin "${PROJECT_BRANCH}"
done
```

### 4. Create PR Per-Repo

GitHub requires one PR per repo. Create a PR for each repo that has changes on the integration branch:

For each repo with changes on the integration branch:

1. Check for existing PR:

```bash
gh pr view --repo <owner>/<repo> --head "${PROJECT_BRANCH}" --json url,state 2>/dev/null
```

2. If no existing PR, **read the PR template first** (mandatory — do not skip):

```
Read: ${REPO_SOURCE}/.github/PULL_REQUEST_TEMPLATE.md
```

Use the template's structure for the PR body. The example below is a fallback only if no template exists.

3. Detect merge queue support:

```bash
gh api repos/<owner>/<repo>/rules/branches/main --jq 'any(.[].type == "merge_queue")' 2>/dev/null
```

4. Create the PR:

```bash
gh pr create \
  --repo <owner>/<repo> \
  --base main \
  --head "${PROJECT_BRANCH}" \
  --title "<conventional commit title>" \
  --body "## Summary

Part of goal tree project: <root goal title>
Guardian issue: <guardian_issue>

### Changes in this repo
<for each node targeting this repo>
- <node.id>. <node.title> — <node.result>

### Goal Tree Summary
- **Completed**: <N>/<total> nodes
- **Skipped**: <N> (see guardian issue for details)

Closes #<issue-number-if-applicable>

## Test Plan
- [ ] All acceptance criteria verified
- [ ] Tests pass
- [ ] No regressions"
```

If merge queue was detected, note it for the user.

### 5. Update Guardian Issue

The coordinator manages GitHub sync, so this step uses the coordinator to trigger a final update:

```bash
# Query final tree state for the report
coord tree show $TREE_ID
```

The coordinator automatically syncs progress to the guardian issue. If a manual update is needed:

```bash
gh issue edit <guardian_issue> --body "## Project Spec
<original spec content>

## Final Status: Complete

### Results
<for each top-level node>
- [x] <node.title> — <node.result>
  <for each child>
  - [x] <child.title> (<dispatch method>)

### PRs
<for each PR created>
- <repo>: <PR URL>

### Summary
- **Nodes completed**: <N>
- **Nodes skipped**: <N>
- **Repos touched**: <list>
- **Commits**: <N>"
```

### 6. Report Summary

```
## Project Complete: <root goal title>

**Nodes completed**: <N>/<total>
<for each completed top-level goal>
  - <id>. <title>
    <for each child>
    - <child.id>. <child.title> [<dispatch>]

**Nodes skipped**: <N>
<for each skipped node>
  - <id>. <title> (reason: <stuck detector>)

**PRs created**:
<for each PR>
  - <repo>: <PR URL>

**Guardian issue**: <issue URL> (updated with final status)

**Dispatch summary**:
  - Subagent: <N>
  - Sub-session: <N>
  - Inline: <N>
  - Fallback: <N>

**Total commits**: <N>
```

### 7. Clean Up

```bash
skills/goal-tree/scripts/cleanup-sessions.sh "<project-slug>"
```

Node workspaces are already cleaned in step 2. The integration branch remains on remote — it holds the PR.

## Error Handling

| Error | Response |
|-------|----------|
| Merge conflict | Pause, report conflicting files, ask user to resolve |
| PR creation fails (transient) | Retry with backoff per error-classification |
| PR creation fails (permanent) | Report error, provide manual `gh pr create` command |
| Guardian issue update fails | Report error, continue (non-critical) |
| Some nodes still pending | Warn user, offer to proceed or go back to execution |
| Coordinator unreachable | Fall back to local tree state for summary |

## Example

```
## Project Complete: Add OAuth Authentication

**Nodes completed**: 5/6
  - A. OAuth Provider Integration
    - A.1. Add OAuth config [subagent]
    - A.2. Implement Google OAuth [subagent]
  - B. Frontend Integration
    - B.1. Add login UI [subagent]
    - B.2. Add token refresh [subagent]
  - C. Documentation
    - C.1. Update API docs [inline]

**Nodes skipped**: 1
  - A.3. Implement GitHub OAuth (reason: repeated-failure — test mock issue)

**PRs created**:
  - api-service: https://github.com/pfeff/api-service/pull/45
  - web-app: https://github.com/pfeff/web-app/pull/12

**Guardian issue**: https://github.com/<owner>/<repo>/issues/40 (updated)

**Dispatch summary**: subagent: 4, inline: 1, skipped: 1
**Total commits**: 8
```

## Integration Points

- **Called by**: execute-tree (on completion), `/finish-project` command
- **Calls**: `coord tree show`, branch-management (merge + cleanup), git/commit
- **References**: `/gh-pr-create` command pattern
