# Build Phase

You are executing one task from PLAN.md in a Ralph Wiggum autonomous build loop.

## Your Task

1. Read `PLAN.md` and identify the **first unchecked task** (`- [ ]`)
2. Detect workspace mode:
   - If `.ralph/workspace.md` exists → **multi-repo mode**: read it to discover repos and their gate configs
   - Otherwise → **single-repo mode**: read `.ralph/gates.md`
3. In multi-repo mode, parse the `[repo-name]` prefix from the task to determine the target repo
4. Read the target repo's `.ralph/gates.md` to understand available gate commands
5. If `.ralph/services.md` exists, read it and run each health check command. If any service is unhealthy, write to `BLOCKERS.md` and exit — do not attempt the task.
6. In multi-repo mode, `cd` to the target repo's directory before implementing
7. Implement the task
8. Run the target repo's backpressure gates (from its `.ralph/gates.md`)
9. Update `PLAN.md` marking the task complete
10. Commit changes in the target repo
11. If all tasks complete, push branches and create PRs
12. Exit cleanly

## Constraints

- **One task only** - never implement multiple tasks
- **One repo per task** - in multi-repo mode, work only in the task's target repo
- **All gates must pass** - run the target repo's gates, not other repos' gates
- **Atomic commits** - one commit per task with clear message, in the correct repo
- **No side quests** - if you notice other issues, ignore them

## Multi-Repo Task Parsing

In multi-repo mode, each task has a `[repo-name]` prefix:

```
- [ ] [api] Add User model with email validation
- [ ] [web] Add login form component
```

1. Extract `repo-name` from the `[...]` prefix
2. Look up the repo's path in `.ralph/workspace.md` (the Repos table)
3. `cd` to that path before implementing
4. Read that repo's `.ralph/gates.md` for gate commands
5. After implementation, run gates from within the repo directory
6. Commit from within the repo directory

If the task has no `[repo-name]` prefix in multi-repo mode, write to `BLOCKERS.md`:
"Task missing repo annotation: <task description>"

## Backpressure Gates

Run these commands from the target repo's `.ralph/gates.md` in order:

1. **Lint** - Code quality check
2. **Typecheck** - Type safety (if applicable)
3. **Test** - Verify correctness
4. **Build** - Compilation (if applicable)

All gates must pass before marking the task complete.

## Workflow

### Single-repo

```
Read PLAN.md → Pick first unchecked task
     ↓
Implement the task
     ↓
Run gates → Any fail? → Fix and retry
     ↓
Update PLAN.md: - [ ] → - [x]
     ↓
Update Status line in PLAN.md
     ↓
Commit: "feat: <task description>"
     ↓
All tasks complete? → Push and create PR
     ↓
Exit
```

### Multi-repo

```
Read PLAN.md → Pick first unchecked task
     ↓
Parse [repo-name] prefix → Look up repo path in .ralph/workspace.md
     ↓
cd to repo directory
     ↓
Implement the task
     ↓
Run repo's gates → Any fail? → Fix and retry
     ↓
cd back to workspace root
     ↓
Update PLAN.md: - [ ] → - [x]
     ↓
Update Status line in PLAN.md
     ↓
cd to repo directory → Commit: "feat: <task description>"
     ↓
All tasks complete? → Push branches and create PRs per repo
     ↓
Exit
```

## Updating PLAN.md

After task completion:

1. Change `- [ ]` to `- [x]` for the completed task
2. Update the `## Status` line with current state
3. Do not modify other tasks

## Commit Guidelines

- Use conventional commit format
- Message should describe what was done
- Keep message concise (one line if possible)
- Commit from within the repo directory that changed

Examples:
- `feat: add user authentication endpoint`
- `fix: handle null response in API client`
- `test: add coverage for payment flow`

## Blockers

If you cannot complete the task because:
- Requirements are unclear
- Dependencies are missing
- External services are unhealthy (see `.ralph/services.md`)
- Architectural decisions are needed
- Tests reveal spec contradictions
- Task is missing `[repo-name]` annotation in multi-repo mode
- Workspace manifest references a repo that doesn't exist

Write the blocking questions to `BLOCKERS.md` and exit immediately.
Do not attempt partial implementations.

## Pull Request

### Single-repo

When all tasks in PLAN.md are complete (no remaining `- [ ]` items):

1. Push the branch to remote
2. Read `.github/PULL_REQUEST_TEMPLATE.md` from the repo (if it exists)
3. Create a PR using `gh pr create`:
   - **Title**: Use the plan's purpose from `## Status` or first line
   - **Body**: If a PR template was found, populate its sections with context from PLAN.md and the commit history. If no template exists, summarize what was implemented.

### Multi-repo

When all tasks in PLAN.md are complete:

1. For each repo that has commits on the branch:
   a. `cd` to the repo directory
   b. Push the branch to remote
   c. Read `.github/PULL_REQUEST_TEMPLATE.md` from the repo (if it exists)
   d. Create a PR using `gh pr create`:
      - **Title**: Use the plan's purpose, scoped to this repo's changes
      - **Body**: Summarize what was implemented in this repo. Include a "Related PRs" section listing PRs created for other repos in this workspace.
2. After all PRs are created, update each PR body with the full list of related PR URLs

Skip repos that have no commits on the branch (no changes were made).

Do not create PRs if tasks remain incomplete.

## Exit Conditions

Exit after ANY of these:
- Task completed successfully and committed (more tasks remain)
- All tasks complete, PR(s) created
- Blockers written to `BLOCKERS.md`
