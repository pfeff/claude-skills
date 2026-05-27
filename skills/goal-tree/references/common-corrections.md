# Common Corrections Reference

Operator-confirmed corrections and feedback patterns from multi-L1 goal-tree sessions.
These are persistent memory entries; the bodies live in the memory store — look them up by name for detail.

For the memory-store pattern see `references/feedback-convention.md` (task-workflow skill).

---

## Devstacks-arch slice-1 session (2026-05-26 → 2026-05-27)

Five feedback memories from the ~24h devstacks-arch L2 supervision session. All encoded during the session; all cited by name in subsequent decisions within the same session.

| Memory name | One-line summary |
|-------------|-----------------|
| `feedback-tmux-tickler-window-target` | `ct add --session <name>` must include `:9` (window index) — omitting it silently routes ticks to nvim instead of claude. |
| `feedback-tmux-anchor-ghost-text` | Classify from agent-output ABOVE the `❯ ` prompt; never from ghost-text autocomplete at the prompt itself. |
| `feedback-l2-cadence-no-unilateral-change` | L2 may not change cadence unilaterally — operator must authorize changes outside the documented auto-policy thresholds. |
| `feedback-l1-review-red-ci` | Red CI = REJECT the PR regardless of root cause; L1 escalates to operator rather than merging with failing checks. |
| `feedback-fix-ci-in-place` | Fix CI failures with in-place commits on the same PR branch; do not open a new PR or abandon the original. |

## How to use this reference

When a new multi-L1 session starts, scan this list for corrections relevant to the current stack (tmux layout, supervision layer, CI policy). Cite the memory name in your first orient step if any apply — e.g. "applying [[feedback-tmux-tickler-window-target]] from common-corrections.md".

Add new corrections here when a feedback memory is saved that is broadly applicable across goal-tree sessions (not just one project). One row per memory; no body copy-paste.
