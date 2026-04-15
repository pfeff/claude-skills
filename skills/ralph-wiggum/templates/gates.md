# Gates

Project-specific commands for the Ralph Wiggum autonomous build loop.

## Container

| Setting | Value |
|---------|-------|
| image | `{{image}}` |
| source | `{{image_source}}` |

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
- **Image discovery**: Ralph discovers the test container image from the repo's `.devcontainer/devcontainer.json` (`image` field). If the repo has no devcontainer.json or no `image` field, Ralph falls back to its base image (`mcr.microsoft.com/devcontainers/base:ubuntu`). The `source` field records where the image came from: `devcontainer` (repo-declared) or `ralph-default` (fallback).
- **Config merging**: When a repo declares a devcontainer.json, `run-container.sh` merges it additively with Ralph's base config — Ralph's required features (Node, GitHub CLI, go-task) are injected, and project features win on key collision. The `image` field from the repo's config takes precedence over Ralph's base image.
