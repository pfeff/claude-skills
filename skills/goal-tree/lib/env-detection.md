# Environment Detection

Determines which backend to use for goal-tree operations.

## Detection Logic

### Backend opt-in

```bash
[ "${GOAL_TREE_BACKEND:-}" = "work" ] && echo "work" || echo "personal"
```

A host declares the GOAL.md ("work") backend explicitly via its per-host config
(`~/.claude/hosts/<hostname>.md` exporting `GOAL_TREE_BACKEND=work`) — typically
a corporate machine with no coordinator available. The script names no specific
host; the choice is config-driven.

- **`GOAL_TREE_BACKEND=work`**: Bootstrap environment (file-based tracking)
- **Otherwise**: Coordinator environment

### Backend Selection

| Environment | Backend | Rationale |
|-------------|---------|-----------|
| Work (opt-in) | GOAL.md + TodoWrite | No coordinator available, file-based tracking |
| Personal | Coordinator API | Full orchestration via `coord` CLI |

### Environment Variables

Check these when selecting backend:

| Variable | Purpose | Required For |
|----------|---------|--------------|
| `GOAL_TREE_BACKEND` | Set to `work` to force the GOAL.md bootstrap backend | Bootstrap mode opt-in |
| `COORDINATOR_URL` | API endpoint (default: `http://localhost:4000`) | Coordinator mode |
| `COORDINATOR_TOKEN` | Authentication token | Coordinator mode |

### Decision Tree

```
Is GOAL_TREE_BACKEND=work?
├── Yes → Use GOAL.md backend (bootstrap mode)
└── No → Check COORDINATOR_URL/TOKEN
    ├── Set and reachable → Use coordinator backend
    └── Missing or unreachable → Use GOAL.md backend (bootstrap mode)
```

## Usage

Operations should call `scripts/detect-env.sh` to determine the backend:

```bash
ENV=$(${CLAUDE_PLUGIN_ROOT}/skills/goal-tree/scripts/detect-env.sh)
if [ "$ENV" = "work" ]; then
    # Use GOAL.md + TodoWrite
else
    # Use coordinator API
fi
```

## Bootstrap Mode Implications

When using GOAL.md backend:
- Tree structure stored in `GOAL.md` at workspace root
- Task tracking via TodoWrite tool
- No coordinator API calls
- Parallel dispatch still uses subagents
- All other conventions (worktrees, scripted sessions) still apply
