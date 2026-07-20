# Archive Workspace Operation

Archive completed workspaces rather than deleting them, preserving historical context for reference.

**Superseded mechanics**: this operation is not registered in `SKILL.md` and its old manual
steps (`git worktree remove`, `rm -rf`) are exactly the commands `operations/close-workspace.md`
now prohibits — freehanding them has caused data loss. Do not run manual teardown from this file.
The concepts below (when to archive, the decision tree, retrieving archived context) still apply;
for the mechanics, invoke `/close-workspace`, which archives to `~/src/work/.archive/<epic>/<task>.tar.gz`
before deleting.

## When to Use

- Task is fully complete and no longer actively worked
- Workspace consuming disk space but may have valuable context
- Cleaning up `~/src/work/` directory while preserving history

## Archive Structure

The tarball `close-workspace.sh` produces preserves the full workspace tree (DESIGN.md, notes,
worktree state) at `~/src/work/.archive/<epic>/<task>.tar.gz`.

## Implementation

### Step 1: Verify Completion

Use `TaskList` to verify all tasks are completed. All tasks should have status `completed`.

### Step 2: Durable Artifacts Check

Before closing, confirm any spec, design doc, runbook, or decision record meant to outlive this
task is already in the Obsidian vault (via the `obsidian-notes` skill) — see
`operations/close-workspace.md` "Durable Artifacts Check". **This is the rule that actually
prevents loss.** The archive tarball below is a convenience copy, not the durable record: it can
still be pruned, and unlike the vault it isn't versioned. Do not treat "it got archived" as
equivalent to "it's durable."

### Step 3: Invoke the Close Path

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/close-workspace.sh <task-id-or-path> --force --caller-cwd "$(pwd)"
```

See `operations/close-workspace.md` for the full argument surface (`--no-archive`,
`--no-close-issue`) and CWD-safety requirement. The script handles archiving, worktree removal,
tmux cleanup, issue closing, directory removal, and verification — do not replicate any of these
steps by hand.

## Archive vs Delete Decision Tree

```
Is the task complete?
├── No → Keep active, don't archive
└── Yes → Continue
    │
    Was significant learning captured?
    ├── Yes → Archive (preserve context)
    └── No → Continue
        │
        Was the task trivial (<1 day work)?
        ├── Yes → Safe to close with --no-archive
        └── No → Archive (preserve history)
```

Either branch closes via `/close-workspace` (`--no-archive` for the trivial case) — never via
manual `rm -rf`/`git worktree remove`.

## Retrieving Archived Context

```bash
# Find archived workspace
ls ~/src/work/.archive/<epic>/

# Extract and read archived documentation
tar -xzOf ~/src/work/.archive/<epic>/<task>.tar.gz <task>/DESIGN.md
```

## Key Lesson

**Archive rather than delete** — historical configurations and decisions provide valuable
reference for similar future work, and the disk space cost is minimal compared to the context
preservation value. But archiving a workspace is not the same as making its content durable:
only the Obsidian vault is git-backed and versioned. A workspace — archived or not — is working
space; treat anything that must outlive the task as vault content, written during the work.

## See Also

- `operations/close-workspace.md` - Canonical close mechanics; "Durable Artifacts Check" and
  "MANDATORY: No Manual Teardown"
- `operations/list-workspaces.md` - List active workspaces
- `references/workspace-structure.md` - Standard workspace layout
