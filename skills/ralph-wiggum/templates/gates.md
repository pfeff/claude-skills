# Gates

Project-specific commands for the Ralph Wiggum autonomous build loop.

## Commands

| Gate | Command |
|------|---------|
| lint | `{{lint_command}}` |
| typecheck | `{{typecheck_command}}` |
| test | `{{test_command}}` |
| build | `{{build_command}}` |

Run gates in order: lint → typecheck → test → build. Skip gates with empty commands.

## Notes

- All applicable gates must pass before marking a task complete
- Keep commands deterministic and reproducible
- If `.ralph/services.md` exists, ensure external services are running before executing gates
