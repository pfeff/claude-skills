# Ralph Wiggum Skill

Scaffolds a project for the Ralph Wiggum autonomous control loop pattern. Supports single-repo and multi-repo workspaces.

## Overview

The Ralph Wiggum pattern is a `while true` bash loop that repeatedly feeds the same prompt to Claude Code. Between iterations, files and git history persist while context resets fresh. The agent sees its own previous work and iteratively improves until backpressure gates (tests, lint, build) all pass.

**Core philosophy**: Backpressure over direction—engineer environments where wrong outputs get rejected automatically.

**Multi-repo**: Workspaces with multiple git repos are supported via a workspace manifest (`.ralph/workspace.md`) and per-repo gate configs. Tasks are annotated with `[repo-name]` prefixes for repo targeting.

## Usage

Invoke the skill by asking Claude to scaffold a project for Ralph Wiggum:

```
"scaffold ralph wiggum for this project"
"set up autonomous loop"
"prepare project for ralph"
```

The skill will:
1. Ask for your project's test, lint, typecheck, and build commands
2. Create the required files in your project directory
3. Provide next steps for writing specs and running the loop

## Files Created

| File | Purpose |
|------|---------|
| `PROMPT_plan.md` | Instructions for the planning phase |
| `PROMPT_build.md` | Instructions for the build phase |
| `.ralph/gates.md` | Project-specific gate commands (single-repo) |
| `.ralph/workspace.md` | Workspace manifest with repo list (multi-repo) |
| `<repo>/.ralph/gates.md` | Per-repo gate commands (multi-repo) |
| `specs/` | Directory for requirement specifications |
| `specs/example.md` | Example spec demonstrating the format |

## Three-Phase Workflow

### Phase 1: Spec (Human)

Write requirements in `specs/` directory:
- One file per topic (e.g., `auth.md`, `api.md`, `database.md`)
- Be specific: "Password must be 8+ characters" not "secure passwords"
- Include acceptance criteria as checkboxes
- Avoid implementation details—say what, not how

### Phase 2: Plan (Agent)

```bash
./loop.sh plan
```

The agent reads all specs and generates `PLAN.md` with prioritized tasks. Each task has:
- One concern (no "and" in descriptions)
- Verifiable completion criteria
- Dependency ordering

### Phase 3: Build (Agent)

```bash
./loop.sh build
```

The agent iterates, picking one unchecked task per iteration:
1. Read `PLAN.md`, find first unchecked task
2. Implement the task
3. Run all backpressure gates
4. Mark task complete, commit, exit
5. Loop restarts with fresh context

## Backpressure Gates

All gates must pass before a task is marked complete:

| Gate | Purpose |
|------|---------|
| Lint | Code quality |
| Typecheck | Type safety |
| Test | Verify correctness |
| Build | Compilation |

Configure commands in `.ralph/gates.md`. Skip gates by leaving the command empty.

## Running the Loop

The host-side scripts ship with this skill at `skills/ralph-wiggum/scripts/`. Invoke them via `$CLAUDE_PLUGIN_ROOT`:

```bash
# Run in sandbox (recommended)
"$CLAUDE_PLUGIN_ROOT/skills/ralph-wiggum/scripts/run-container.sh" /path/to/project -- ./loop.sh build

# Or directly on host (less secure)
./loop.sh build
```

### Options

```bash
./loop.sh plan            # Generate PLAN.md from specs
./loop.sh build           # Execute build loop (default)
./loop.sh build 50        # Set max iterations (default: 20)
```

### Exit Conditions

The loop stops when:
- All tasks in `PLAN.md` are complete
- `BLOCKERS.md` is created (agent encountered blocking questions)
- Max iterations reached

## Blockers

If the agent cannot proceed due to unclear requirements or missing context, it writes questions to `BLOCKERS.md` and exits. Review the file, resolve the issues, delete it, and restart the loop.

## Security

For autonomous execution, run the loop inside a sandboxed container:

```bash
# Build and run the sandbox container (uses Claude account auth by default)
"$CLAUDE_PLUGIN_ROOT/skills/ralph-wiggum/scripts/run-container.sh" /path/to/project --network

# Or use API key instead
ANTHROPIC_API_KEY=... "$CLAUDE_PLUGIN_ROOT/skills/ralph-wiggum/scripts/run-container.sh" /path/to/project --api-key --network

# Container provides:
# - Filesystem isolation (only project dir mounted)
# - Network allowlist (api.anthropic.com, github.com, package registries)
# - Claude account credentials (~/.claude/) mounted read-only
# - Read-only filesystem with tmpfs for scratch
```

See `skills/ralph-wiggum/scripts/CREDENTIALS.md` for credential management details.

## Example Workflow

```bash
# 1. Scaffold the project
claude
> scaffold ralph wiggum for this project
> test: npm test, lint: npm run lint, build: npm run build

# 2. Write specs
rm specs/example.md
echo "# Auth Spec\n\n- Users can register with email/password\n- ..." > specs/auth.md

# 3. Generate plan
./loop.sh plan

# 4. Review PLAN.md, adjust if needed

# 5. Run autonomous build
./loop.sh build

# 6. Review results, repeat if needed
```

## References

- [Ralph Wiggum Playbook](https://paddo.dev/blog/ralph-wiggum-playbook/)
- [Ralph Orchestrator](https://github.com/mikeyobrien/ralph-orchestrator)
- [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)
