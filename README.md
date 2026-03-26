# claude-skills

A Claude Code plugin with five engineering skills for git workflows, test-driven development, documentation, CI automation, and knowledge capture.

## Installation

```bash
# From GitHub
claude plugin install pfeff/claude-skills

# Local development
claude --plugin-dir /path/to/claude-skills
```

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| **git** | `/claude-skills:git` | Git usage patterns and conventions. Compact commit messages, conventional commits, incremental commit heuristic, worktree-aware PR merges, and branch guards. |
| **testing-without-mocks** | `/claude-skills:testing-without-mocks` | TDD using the Testing Without Mocks pattern language. Nullables instead of mocking frameworks. Supports Python, Go, and Elixir. |
| **diataxis** | `/claude-skills:diataxis` | Project documentation using the Diataxis methodology. Scaffold, write, or audit docs by type (tutorial, how-to, reference, explanation). |
| **compound** | `/claude-skills:compound` | Capture solved problems as searchable solution documents with YAML frontmatter for agent discovery. |
| **ci-feedback-loop** | `/claude-skills:ci-feedback-loop` | Monitor PR check status after push, auto-diagnose CI failures, attempt fixes, and escalate when unable to resolve. |

## Attribution

This plugin was influenced by and borrows ideas from:

- **[compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin)** (EveryInc, MIT) — The Brainstorm → Plan → Work → Review → Compound workflow. Our `compound` skill draws from their knowledge capture approach.

## License

MIT
