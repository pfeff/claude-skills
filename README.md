# claude-skills

A Claude Code plugin with engineering skills for git workflows, code review, test-driven development, documentation, CI automation, knowledge capture, structured planning, and an LLM knowledge base over an Obsidian vault.

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
| **review** | `/claude-skills:review` | Spawn parallel specialist review agents (security, simplicity, architecture, correctness) against a PR or branch diff. Synthesizes findings by severity. |
| **ci-feedback-loop** | `/claude-skills:ci-feedback-loop` | Monitor PR check status after push, auto-diagnose CI failures, attempt fixes, and escalate when unable to resolve. |
| **planning-workflow** | `/claude-skills:planning-workflow` | Structured planning that validates the problem, reconciles DESIGN.md, searches past solutions, calibrates research depth, analyzes edge cases via SpecFlow, and generates living plans with checkable criteria. |
| **kb** (capture/compile/lint) | `/kb-capture` · `/kb-compile` · `/kb-lint` | LLM Knowledge Base over an Obsidian vault: capture Readwise Reader sources to `raw/`, compile into `type:`-routed summary + concept notes in `Notes/` (cross-linked to `Keywords/`, surfaced via a KB MOC), and lint for health. Bounded writes (git-reviewed, no fence); shared logic in `kb-core`. Interactive-only (subscription billing). |

## Attribution

This plugin was influenced by and borrows ideas from:

- **[compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin)** (EveryInc, MIT) — The Brainstorm → Plan → Work → Review → Compound workflow. Our `compound` skill draws from their knowledge capture approach.

## License

MIT
