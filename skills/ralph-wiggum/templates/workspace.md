# Workspace

Multi-repo workspace configuration for the Ralph Wiggum autonomous build loop.

## Repos

| Repo | Path | Gates | Image |
|------|------|-------|-------|
| {{repo_name}} | `{{repo_path}}` | `{{repo_path}}/.ralph/gates.md` | `{{image}}` |

## Branch

| Setting | Value |
|---------|-------|
| name | `{{branch_name}}` |
| strategy | `workspace` |

Branch strategy:
- `workspace` — derive branch name from spec, apply to all repos. Use existing worktree branch if already checked out.

## Notes

- Each repo listed above must contain its own `.ralph/gates.md` with repo-specific gate commands
- Tasks in `PLAN.md` are annotated with `[repo-name]` prefix to indicate the target repo
- The agent cds to the repo path before implementing each task
- Commits are made in the repo that changed
- One PR is created per repo that has changes, with cross-references in descriptions
