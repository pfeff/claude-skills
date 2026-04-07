# Close Project Operation

Cleanly closes a goal-tree project workspace by removing all node worktrees, killing tmux sessions, archiving artifacts, and removing the project directory.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `project_path` | No | Path to project directory (defaults to CWD) |
| `no_archive` | No | Skip archiving before removal (default: false) |
| `no_update_issue` | No | Skip updating the guardian issue (default: false) |
| `force` | No | Skip confirmation prompt (default: false) |

## Purpose

Tears down a goal-tree project after completion or abandonment. Composes `cleanup-worktrees.sh` and `cleanup-sessions.sh` for node-level cleanup, then handles project-level concerns (archiving, guardian issue update, directory removal).

## Execution

Run the close-project script:

```bash
skills/goal-tree/scripts/close-project.sh "$PROJECT_PATH" [OPTIONS]
```

Options:
- `--no-archive` — skip archiving
- `--no-update-issue` — skip guardian issue comment
- `--caller-cwd "$PWD"` — pass caller's CWD for safety check
- `--force` — skip confirmation

### CWD Safety

Always pass `--caller-cwd` so the script can warn if the shell is inside the project being closed. If running non-interactively (e.g., from a subagent), also pass `--force`.

### What It Does

1. **Locates project** — validates CLAUDE.md exists
2. **Extracts metadata** — project title, guardian issue reference from CLAUDE.md
3. **Inventories components** — counts node workspaces, worktrees, tmux sessions
4. **Confirms** — shows what will be removed (unless `--force`)
5. **Project Scorecard** — summarizes finish metrics before teardown (see below)
6. **Removes worktrees** — via `cleanup-worktrees.sh`
7. **Kills sessions** — via `cleanup-sessions.sh`
8. **Archives** — tarballs project to `~/src/work/.archive/<parent>/<project>.tar.gz`
9. **Updates guardian issue** — adds closure comment (does NOT close the issue)
10. **Removes directory** — `rm -rf` the project path
11. **Verifies** — checks directory gone, sessions gone, archive exists

### Step 5: Project Scorecard

Before teardown, summarize task metrics from `finish.jsonl` for the project's epic. This gives the operator a quantitative view of the project before artifacts are archived.

**Determine epic**: Extract from the project CLAUDE.md or workspace path segment.

```bash
METRICS_FILE=~/src/work/.metrics/finish.jsonl

if [[ -f "$METRICS_FILE" ]]; then
  jq -r --arg epic "$EPIC" '
    select(.epic == $epic)
  ' "$METRICS_FILE" | jq -s '
    if length == 0 then
      "No finish metrics found for epic: \($epic)."
    else
      "── Project Scorecard ──────────────────",
      "Total tasks:    \(length)",
      "Elapsed hours:  \(map(.elapsed_hours) | add | . * 10 | round / 10)",
      "Avg hours/task: \(map(.elapsed_hours) | add / length | . * 10 | round / 10)",
      "Review rounds:  \(map(.review_rounds) | add) total (\(map(.review_rounds) | add / length | . * 10 | round / 10) avg)",
      "───────────────────────────────────────"
    end
  ' --arg epic "$EPIC"
else
  echo "No finish.jsonl found — metrics collection not yet active."
fi
```

The scorecard is displayed as part of the confirmation output. If the file is missing or no entries match the epic, a message is shown and the close proceeds normally — the scorecard is informational, not blocking.

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid arguments |
| 2 | Project not found or invalid (no CLAUDE.md) |
| 3 | Archive creation failed |
| 4 | Verification failed |

## Relationship to close-workspace

`close-workspace` closes a single task workspace (DESIGN.md, one worktree, one session). `close-project` closes a goal-tree project (CLAUDE.md, multiple node workspaces with multiple worktrees, multiple sessions). They compose — close-project uses the same cleanup scripts that close-workspace relies on.

## Integration Points

- **Called by**: User via `/close-project` command
- **Calls**: `scripts/close-project.sh`, which calls `scripts/cleanup-worktrees.sh` and `scripts/cleanup-sessions.sh`
- **References**: `operations/start-project.md` (creates what this closes)
