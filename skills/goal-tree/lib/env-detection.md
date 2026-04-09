# Environment Detection

Determines which backend to use for goal-tree operations.

## Detection Logic

### Hostname Check

```bash
hostname | grep -q '^TCETRA' && echo "work" || echo "personal"
```

- **TCETRA prefix**: Work environment (corporate machine)
- **Other**: Personal environment

### Backend Selection

| Environment | Backend | Rationale |
|-------------|---------|-----------|
| Work (TCETRA) | GOAL.md + TodoWrite | No coordinator available, file-based tracking |
| Personal | Coordinator API | Full orchestration via `coord` CLI |

### Environment Variables

Check these when selecting backend:

| Variable | Purpose | Required For |
|----------|---------|--------------|
| `COORDINATOR_URL` | API endpoint (default: `http://localhost:4000`) | Coordinator mode |
| `COORDINATOR_TOKEN` | Authentication token | Coordinator mode |

### Decision Tree

```
Is hostname TCETRA*?
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
