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
| **git** | `/mbp:git` | Git usage patterns and conventions. Compact commit messages, conventional commits, incremental commit heuristic, worktree-aware PR merges, and branch guards. |
| **testing-without-mocks** | `/mbp:testing-without-mocks` | TDD using the Testing Without Mocks pattern language. Nullables instead of mocking frameworks. Supports Python, Go, and Elixir. |
| **diataxis** | `/mbp:diataxis` | Project documentation using the Diataxis methodology. Scaffold, write, or audit docs by type (tutorial, how-to, reference, explanation). |
| **compound** | `/mbp:compound` | Capture solved problems as searchable solution documents with YAML frontmatter for agent discovery. |
| **review** | `/mbp:review` | Spawn parallel specialist review agents (security, simplicity, architecture, correctness) against a PR or branch diff. Synthesizes findings by severity. |
| **ci-feedback-loop** | `/mbp:ci-feedback-loop` | Monitor PR check status after push, auto-diagnose CI failures, attempt fixes, and escalate when unable to resolve. |
| **planning-workflow** | `/mbp:planning-workflow` | Structured planning that validates the problem, reconciles DESIGN.md, searches past solutions, calibrates research depth, analyzes edge cases via SpecFlow, and generates living plans with checkable criteria. |
| **skillify** | `/skillify` | Fast-capture entrypoint: drafts a lite SKILL.md from the workflow just performed in conversation, confirms before writing, and hands off to skill-creator's full interview/eval/benchmark loop when the pattern warrants it. |
| **kb** (capture/compile/lint) | `/kb-capture` · `/kb-compile` · `/kb-lint` | LLM Knowledge Base over an Obsidian vault: capture Readwise Reader sources to `raw/`, compile into `type:`-routed summary + concept notes in `Notes/` (cross-linked to `Keywords/`, surfaced via a KB MOC), and lint for health. Bounded writes (git-reviewed, no fence); shared logic in `kb-core`. Interactive-only (subscription billing). |
| **dispatch-gate** | `/mbp:dispatch-gate` | Dispatch-readiness gate for background jobs. Checks the four slice-complete criteria (objective, acceptance test, scope/blast-radius bound, affected surface) before the operator launches a background agent, clarifies gaps, and writes the `.claude/task-context.md` the job runs against. |
| **l1-supervisor** | `/mbp:l1-supervisor` | Adopts the L1 supervisor role for a goal tree: identity, source-of-truth precedence, tick procedure, permission/escalation rubrics, stop signal, and orient triggers. Sits above `goal-tree`'s operations and binds them into a coherent role. |
| **l2-supervisor** | `/mbp:l2-supervisor` | Adopts the L2 supervisor role for a goal tree: a KPI-driven controller that keeps Progress, Budget, and Health in band by proposing intervention L1s to the operator for approval. Does not write code, dispatch L0 work, or act unilaterally. |
| **operator-interview** | `/mbp:operator-interview <topic>` | Interviews an operator to elicit a buildable specification via a hybrid funnel (open questions, scoping batches, gap probes, clarification gate, playback, sign-off), then writes it as a signed-off spec note in the vault. Gates build/dispatch on `status: signed-off`. |
| **operator-interview-doctrine** | *(reference, loaded by `operator-interview`)* | Shared doctrine for the question taxonomy, ask-vs-default rule, adaptive-depth rubric, stop conditions, spec-note schema, and sign-off protocol. No operations of its own — keeps operator-confirmed rules in one place rather than inlined into consumer skills. |
| **self-verify** | *(invoked by dispatched jobs, not operator-facing)* | Self-verification for a job before it reports "done": checks its own change against the 3-axis review doctrine (Conformance / Process / Objective-Advancement) using existing review tooling and tests, and emits a structured annotation artifact for the operator's review. |

## Attribution

This plugin was influenced by and borrows ideas from:

- **[compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin)** (EveryInc, MIT) — The Brainstorm → Plan → Work → Review → Compound workflow. Our `compound` skill draws from their knowledge capture approach.

## License

MIT
