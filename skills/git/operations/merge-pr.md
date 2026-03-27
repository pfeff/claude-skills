# Merge PR Operation

Merges a GitHub pull request with worktree-aware branch cleanup.

## Purpose

Merge PRs safely from any context, including git worktrees where `--delete-branch` fails because git cannot checkout main.

## Inputs

- **pr** (optional): PR number or branch name. Defaults to current branch's PR.
- **method** (optional): Merge method — `merge`, `squash`, or `rebase`. Resolved via strategy resolution (see Step 2b).

## Implementation Steps

### 1. Detect Worktree Context

```bash
git rev-parse --git-common-dir
git rev-parse --git-dir
```

If these differ, you're in a worktree. Store the result:

```bash
COMMON_DIR=$(git rev-parse --git-common-dir)
GIT_DIR=$(git rev-parse --git-dir)
IS_WORKTREE=false
[[ "$COMMON_DIR" != "$GIT_DIR" ]] && IS_WORKTREE=true
```

### 2. Identify the PR

```bash
# If no PR specified, find PR for current branch
gh pr view --json number,title,headRefName,state
```

Verify PR is open. Abort if already merged or closed.

### 2b. Resolve Merge Strategy

Determine the merge method (`METHOD`) using this resolution order:

1. **Explicit input**: If `method` was provided as input, use it.
2. **Repo CLAUDE.md convention**: Read the repository's CLAUDE.md for a `Merge Strategy: <method>` line. If found, use that method.
3. **GitHub repo settings**: Query allowed merge types:
   ```bash
   gh api repos/{owner}/{repo} --jq '[.allow_merge_commit, .allow_squash_merge, .allow_rebase_merge]'
   ```
   If exactly one type is `true`, use the corresponding method:
   - `allow_merge_commit` → `merge`
   - `allow_squash_merge` → `squash`
   - `allow_rebase_merge` → `rebase`
4. **Default**: Use `merge`.

**Validation**: After resolution, verify `METHOD` is one of `merge`, `squash`, or `rebase`. If not (e.g., typo in CLAUDE.md or injected flags), discard and fall through to the next resolution step.

**Edge cases**:
- If the GitHub API call fails, fall through to the default.
- If CLAUDE.md doesn't exist or has no `Merge Strategy` line, fall through to the API check.
- If CLAUDE.md contains an invalid method value, warn and fall through to the API check.

### 3. Merge the PR

**If in a worktree** — merge remotely without local branch deletion:

```bash
gh pr merge <number> --$METHOD --delete-branch=false
```

Then delete the remote branch separately:

```bash
git push origin --delete <branch-name>
```

**If NOT in a worktree** — standard merge:

```bash
gh pr merge <number> --$METHOD --delete-branch
```

### 4. Verify

```bash
gh pr view <number> --json state,mergedAt
```

Confirm state is `MERGED`.

## Edge Cases

| Case | Response |
|------|----------|
| In a worktree | Merge without `--delete-branch`, delete remote branch separately |
| Not in a worktree | Standard `gh pr merge --delete-branch` |
| PR already merged | Report already merged, no action |
| PR has failing checks | Warn user, let them decide to proceed with `--admin` |
| No PR for current branch | Ask user to specify PR number |

## Why Worktrees Break `--delete-branch`

`gh pr merge --delete-branch` deletes the remote branch, then attempts to checkout the repo's default branch locally. In a worktree, that branch is already checked out in the main working tree, causing:

```
fatal: 'main' is already used by worktree at '/path/to/main'
```

The fix: merge and delete the remote branch without triggering a local checkout.
