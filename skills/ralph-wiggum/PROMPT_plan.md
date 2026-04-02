# Planning Phase

You are generating a PLAN.md for a Ralph Wiggum autonomous build loop.

## Your Task

1. Read all spec files in `specs/`
2. Detect workspace mode:
   - If `.ralph/workspace.md` exists → **multi-repo mode**: read it to discover repos and their gate configs
   - Otherwise → **single-repo mode**: read `.ralph/gates.md`
3. In multi-repo mode, read each repo's `.ralph/gates.md` (paths listed in workspace manifest)
4. If `.ralph/services.md` exists, read it and consider service dependencies when ordering tasks (e.g., database setup before features that require it)
5. Generate `PLAN.md` with a prioritized task list

## Constraints

- **One concern per task** - no "and" in task descriptions
- **One repo per task** - in multi-repo mode, each task targets exactly one repo
- **Verifiable completion** - each task has clear done criteria
- **Backpressure gates** - every task must pass the target repo's gates
- **Dependency order** - foundational work before features; cross-repo dependencies respected

## PLAN.md Format

### Single-repo

```markdown
# Plan: {Project Name}

## Status
{One-line summary of current state}

## Tasks

### Phase 1: {Category}
- [ ] Task description
- [ ] Task description

### Phase 2: {Category}
- [ ] Task description
```

### Multi-repo

```markdown
# Plan: {Project Name}

## Status
{One-line summary of current state}

## Repos
{List of repos from workspace manifest}

## Tasks

### Phase 1: {Category}
- [ ] [repo-name] Task description
- [ ] [repo-name] Task description

### Phase 2: {Category}
- [ ] [repo-name] Task description
```

In multi-repo mode, every task is prefixed with `[repo-name]` matching a repo from the workspace manifest. This tells the build agent which repo directory to work in.

**Cross-repo ordering**: If a change in repo A must happen before repo B can use it, order the tasks accordingly.

## Task Guidelines

**Good tasks** (single-repo):
- "Add User model with email validation"
- "Implement login endpoint"
- "Write tests for authentication flow"

**Good tasks** (multi-repo):
- "[api] Add User model with email validation"
- "[api] Implement login endpoint"
- "[web] Add login form component"
- "[web] Wire login form to API endpoint"

**Bad tasks**:
- "Add User model and implement login" (multiple concerns)
- "[api] Add model [web] Add form" (multiple repos in one task)
- "Make it work better" (not verifiable)

## After Writing PLAN.md

1. Verify each task can pass its repo's backpressure gates independently
2. Check that task order respects dependencies (including cross-repo)
3. In multi-repo mode, verify every task has a valid `[repo-name]` prefix
4. Exit cleanly—do not start building

## Blockers

If you cannot generate a plan because:
- Specs are unclear or contradictory
- Required context is missing
- Architectural decisions are needed
- External services are missing or unhealthy (see `.ralph/services.md`)
- Workspace manifest references repos that don't exist

Write the blocking questions to `BLOCKERS.md` and exit.
