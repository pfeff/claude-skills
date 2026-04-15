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
6. **Deploy Agent Coordinator** — builds and deploys AC release (see below)
7. **Removes worktrees** — via `cleanup-worktrees.sh`
8. **Kills sessions** — via `cleanup-sessions.sh`
9. **Archives** — tarballs project to `~/src/work/.archive/<parent>/<project>.tar.gz`
10. **Updates guardian issue** — adds closure comment (does NOT close the issue)
11. **Removes directory** — `rm -rf` the project path
12. **Verifies** — checks directory gone, sessions gone, archive exists

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
      "",
      # L0: Acceptance criteria pass rate
      (if [map(select(.acceptance_rate != null))] | .[0] | length > 0 then
        [map(select(.acceptance_rate != null))] | .[0] |
        "L0 acceptance rate: \(map(.acceptance_rate) | add / length | . * 1000 | round / 1000) avg (\(length) evaluated)"
      else
        "L0 acceptance rate: no evaluation data"
      end),
      # L1: Batch success rate + cycle time
      (if [map(select(.acceptance_rate != null))] | .[0] | length > 0 then
        [map(select(.acceptance_rate != null))] | .[0] |
        "L1 batch success: \([map(select(.acceptance_rate >= 1.0))] | .[0] | length)/\(length) (\([map(select(.acceptance_rate >= 1.0))] | .[0] | length / length | . * 1000 | round / 1000))"
      else
        "L1 batch success: no evaluation data"
      end),
      "L1 cycle time:  \(map(.elapsed_hours) | add / length | . * 10 | round / 10) avg hours/task",
      "───────────────────────────────────────"
    end
  ' --arg epic "$EPIC"
else
  echo "No finish.jsonl found — metrics collection not yet active."
fi
```

The scorecard is displayed as part of the confirmation output. If the file is missing or no entries match the epic, a message is shown and the close proceeds normally — the scorecard is informational, not blocking.

### Step 6: Deploy Agent Coordinator

If the cycle included changes to `agent-coordinator`, build and deploy a fresh release before tearing down the project. See [docs/how-to/deploy-local-prod.md](https://github.com/pfeff/agent-coordinator/blob/main/docs/how-to/deploy-local-prod.md) for full details.

1. **Build release**
   ```bash
   cd ~/src/github/pfeff/agent-coordinator
   MIX_ENV=prod mix deps.get
   MIX_ENV=prod mix compile
   MIX_ENV=prod mix assets.deploy
   MIX_ENV=prod mix release --overwrite
   ```

2. **Install release**
   ```bash
   cp -r _build/prod/rel/agent_coordinator/ ~/.local/opt/agent-coordinator/
   ```

3. **Run migrations**
   ```bash
   set -a && source /usr/local/var/agent-coordinator/env && set +a
   ~/.local/opt/agent-coordinator/bin/migrate
   ```

4. **Restart launchd service**
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.pfeff.agent-coordinator
   ```

This step is informational, not blocking — if the cycle has no AC changes, skip it. The operator decides whether a deploy is warranted.

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
