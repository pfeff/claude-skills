# Branch Management Operation

Manages branches and worktrees for parallel goal tree execution. All work happens in worktrees — source repos stay on main (DD-18).

## Branch Strategy

```
main
└── <project-branch>                          (integration branch)
    ├── <project-branch>/<node-id-A>          (node A)
    └── <project-branch>/<node-id-B>          (node B)
```

### Branch Naming

| Level | Pattern | Example |
|-------|---------|---------|
| Integration | `<issue-id>/<user>/<project-slug>` | `213/mbp/feat-goal-tree` |
| Node | `<project-branch>/<node-id>` | `213/mbp/feat-goal-tree/B` |

The integration branch is created as a tracking branch at start-project time but has no worktrees. Node branches merge into it during synthesis.

For **single-node projects**: the node branch *is* the integration branch (skip the extra layer).

## Workspace Layout

### Node Workspace

Created at dispatch time by `dispatch-node.md`. Each node gets its own workspace directory with repo worktrees on the node's branch:

```
~/src/work/<project>/
├── GOAL.md
├── CLAUDE.md
├── <node-id>/                 ← node workspace
│   ├── CLAUDE.md              ← task context
│   ├── <repo-1>/              ← worktree on node branch
│   └── <repo-2>/              ← worktree on node branch
├── <another-node-id>/
│   └── <repo-1>/
└── ...
```

No repo worktrees exist at the project level. The project directory is a container for GOAL.md and node workspaces.

## Operations

### Create Integration Branch

Called by `start-project.md` during project initialization. Creates the branch but no worktrees.

```bash
for repo in <repo-list>; do
  REPO_SOURCE=~/src/github/<owner>/${repo}

  # Fetch latest without touching source repo working tree
  git -C "$REPO_SOURCE" fetch origin

  # Create integration branch from remote main (no checkout, no worktree)
  git -C "$REPO_SOURCE" branch "${PROJECT_BRANCH}" origin/main
done
```

### Create Node Workspace

Called by `dispatch-node.md` before dispatching any strategy (subagent, inline, or sub-session).

```bash
skills/goal-tree/scripts/create-node-workspace.sh \
  "$PROJECT_DIR" "$NODE_ID" "$PROJECT_BRANCH" "$OWNER" <repo1> [repo2 ...]
```

### Merge Node Branch to Integration

Called by `synthesize.md` when collecting results from all node workspaces. Per-repo merge:

```bash
skills/goal-tree/scripts/merge-node-branch.sh \
  "$REPO_SOURCE" "$PROJECT_BRANCH" "$NODE_BRANCH" "$NODE_REPO_DIR"
```

Or merge all repos in a node at once:

```bash
skills/goal-tree/scripts/synthesize-node.sh \
  "$PROJECT_DIR" "$NODE_ID" "$PROJECT_BRANCH" "$OWNER"
```

On conflict, the script exits 1 and preserves the merge worktree for resolution.

### Clean Up All Worktrees

Called by `synthesize.md` or workspace close.

```bash
skills/goal-tree/scripts/cleanup-worktrees.sh "$PROJECT_DIR"
```

## Conflict Handling

When merge conflicts occur during synthesis (merging node branches to integration):

```
1. Preserve the node workspace (don't clean up)
2. Mark the node as "blocked" in GOAL.md
3. Report conflict to root session:
   "Merge conflict in <repo> when integrating <node-id> changes.
    Conflicting files: <list>
    Node workspace preserved at: <path>"
4. Root session attempts resolution:
   a. Read conflicting files
   b. Resolve conflicts
   c. Complete merge
   d. Clean up workspace
5. If root cannot resolve → escalate to user
```

## Integration Branch Lifecycle: Rebase vs Merge

### When to rebase

Use **rebase** when:
- Updating a node branch to pick up upstream integration-branch changes before opening a PR.
- Command: `git -C <repo-worktree> rebase <integration-branch>` (or `git rebase origin/<integration-branch>` after fetch).
- Goal: keep node-branch history linear so the integration PR diff is clean.
- **Never rebase a branch that has already been pushed and has an open PR** — force-pushes to an open PR require notifying reviewers and can break in-flight review threads.

### When to merge (fast-forward or squash)

Use **merge** (or squash-merge via `gh pr merge --squash`) when:
- Landing a completed node branch into the integration branch. Squash-merging keeps the integration branch history clean.
- Landing the integration branch into main. Use a regular merge commit (not squash) to preserve the integration-branch summary.

### Rebase before PR, not after

The safe pattern:
1. Rebase node branch onto latest integration branch **before** opening the PR (`git rebase <integration>`).
2. Open the PR; do not rebase again after the PR is open (unless the integration branch is force-pushed, which should not happen).
3. Merge via `gh pr merge --squash` when the PR is approved.

### Force-push discipline

Force-push is allowed only on node branches with NO open PR. Once a PR is open, treat the branch as immutable to avoid blast radius on reviewers. If you must rebase a branch with an open PR, notify the operator first. (2026-05-26 session: rebase of slice-1-main required repairing 17 worktrees — always verify blast radius before rebasing an integration branch.)

## Safety Rules

1. **Never checkout branches in source repos** — source repos (`~/src/github/`) always stay on main
2. **Always use worktrees** — all work in `~/src/work/`
3. **Fetch before worktree creation** — ensure we branch from latest main
4. **Delete node branches after merge** — keep the branch tree clean
5. **Preserve workspaces on conflict** — never lose work by premature cleanup

## Integration Points

- **Called by**: start-project (integration branch), dispatch-node (node workspaces), synthesize (merge + cleanup)
- **References**: DD-18 (worktree isolation)
- **Reuses**: `task-workflow/scripts/create-workspace.sh` for workspace bootstrapping
