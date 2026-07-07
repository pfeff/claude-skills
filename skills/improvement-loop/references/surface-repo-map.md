# Surface → Repo Map

Where each improvable surface's PR must land, and how the load-bearing check
applies. **Provisional** — revisit via `loop-optimizer` grading once
validated by real use.

## The map

| Surface | Repo | Path(s) |
|---------|------|---------|
| `mbp` plugin skills & their commands (`lessons-learned`, `self-improvement`, `skillify`, `goal-tree`, `task-workflow`, `git`, …) | `pfeff/claude-skills` | `skills/<name>/`, `.claude-plugin/marketplace.json` |
| `improvement-loop` skill itself | `pfeff/claude-skills` | `skills/improvement-loop/` |
| `l1-supervisor`, `l2-supervisor` (mbp role-contract skills) | `pfeff/claude-skills` | `skills/l1-supervisor/`, `skills/l2-supervisor/` |
| `tc` plugin skills (`aws`, `octopus`, `atlassian`, corporate workflows) | `Tcetra/claude-skills` | `skills/<name>/` |
| Personal skills & launchers (`chief-of-staff`, `l1-supervise`/`l2-supervise` launchers, `durable-driver`, `loop-optimizer`, `obsidian-notes`) | `dotfiles` | `claude/skills/<name>/` |
| Slash commands (workspace commands, etc.) | `dotfiles` | `claude/commands/*.md` |
| **Global** CLAUDE.md | `dotfiles` | `claude/CLAUDE.md` |
| **Per-repo** CLAUDE.md | that repo | `<repo>/CLAUDE.md` |
| Hooks & settings, permissions | `dotfiles` | `claude/hooks/`, `claude/settings*.json`, `claude/build-settings.sh` |
| Launchers & scripts (`ct`, tmux/tmuxp, workspace tooling) | `dotfiles` | `bin/`, `tmuxp/`, host-specific `bin/` dirs |

## Scope-by-breadth rule (CLAUDE.md placement)

When a finding wants a CLAUDE.md change, decide the file by the breadth of
the rule:

- **Cross-cutting / applies everywhere** → global `dotfiles/claude/CLAUDE.md`.
  Keep this file lean; prefer a one-line pointer over prose.
- **Specific to one repo/project** → that repo's `CLAUDE.md`.

## Load-bearing check

Before opening any PR, check whether the target surface is load-bearing:

- the **billing invariant** (`~/.claude/CLAUDE.md` → "Claude Code Billing —
  Margin of Safety"),
- **L{N} supervision doctrine** (`lN-lifecycle-doctrine`,
  `lN-review-doctrine`),
- **`ct` tick-delivery mechanics**,
- or anything else the operator has designated load-bearing.

If the change touches one of these:

1. Flag the PR as **load-bearing** in its title or body.
2. It is **never auto-merged** — it waits for explicit operator discussion,
   regardless of how routine the diff looks.
3. Note the load-bearing status prominently in the PR body.

All PRs (load-bearing or not) land on a feature branch — no direct pushes,
no auto-merge (per Write Discipline in the main skill).
