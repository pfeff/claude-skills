# Surface → Repo Map

Where each improvable surface's PR must land, and how the load-bearing check
applies. **Provisional** (DESIGN "Design Decisions") — revisit via
`loop-optimizer` grading once validated by real use.

## The map

| Surface | Repo | Path(s) |
|---------|------|---------|
| `mbp` plugin skills & their commands (`lessons-learned`, `self-improvement`, `skillify`, `goal-tree`, `task-workflow`, `git`, …) | `pfeff/claude-skills` | `skills/<name>/`, `.claude-plugin/marketplace.json` |
| `improvement-loop` skill itself | `pfeff/claude-skills` | `skills/improvement-loop/` |
| `tc` plugin skills (`aws`, `octopus`, `atlassian`, corporate workflows) | `Tcetra/claude-skills` | `skills/<name>/` |
| Personal skills (`chief-of-staff`, `l1-*`, `l2-*`, `durable-driver`, `loop-optimizer`, `obsidian-notes`) | `dotfiles` | `claude/skills/<name>/` |
| Slash commands (`/skillify`, `/lessons-learned`, workspace commands) | `dotfiles` | `claude/commands/*.md` |
| **Global** CLAUDE.md | `dotfiles` | `claude/CLAUDE.md` |
| **Per-repo** CLAUDE.md | that repo | `<repo>/CLAUDE.md` |
| Hooks & settings, permissions | `dotfiles` | `claude/hooks/`, `claude/settings*.json`, `claude/build-settings.sh` |
| Launchers & scripts (`ct`, tmux/tmuxp, workspace tooling) | `dotfiles` | `bin/`, `tmuxp/`, `tcetra/bin/` |
| improvement-loop scripts (`skillify-capture`, `resolve-working-session`, `improvement-mine-delta`, `improvement-backoff`) | `dotfiles` | `claude/bin/` |
| improvement-loop seed state (`load-bearing.md`) | `dotfiles` | `claude/improvement/` |

## Scope-by-breadth rule (CLAUDE.md placement)

When a lesson wants a CLAUDE.md change, decide the file by the breadth of the rule:

- **Cross-cutting / applies everywhere** → global `dotfiles/claude/CLAUDE.md`. Keep this file lean; prefer a one-line pointer over prose.
- **Specific to one repo/project** → that repo's `CLAUDE.md`.

## Load-bearing check (R5)

Before opening any PR, cross-reference the target surface against
`~/.claude/improvement/load-bearing.md`. If the change touches a listed
surface (billing invariant, L{N} supervision doctrine, `ct` tick delivery
mechanics — or anything else the operator has added there):

1. The PR **must** carry the `load-bearing` label/flag.
2. It is **never auto-merged** — it waits for explicit operator discussion,
   regardless of how routine the diff looks.
3. Note the load-bearing status prominently in the PR body and the pending index.

All PRs (load-bearing or not) land on a feature branch — no direct pushes, no
auto-merge (R4).
