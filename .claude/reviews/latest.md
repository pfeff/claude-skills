---
target: PR #91
timestamp: 2026-05-19T00:00:00Z
agents: 4
blocking: 1
advisory: 18
verdict: BLOCKING
---

## Review Summary

**Target**: PR #91 — feat(compound): rehome solution capture to Obsidian vault
**Agents**: 4 (security, simplicity, architecture, correctness)
**Verdict**: BLOCKING — 1 issue must be resolved

### Blocking

- **skills/compound/operations/document-solution.md:21-26** — [architecture] _non-blocking failure contract_ — Step 1's host-config block (`source "$HOST_CONFIG" || { :; }`) does not actually gate downstream CLI calls. If the helper fails, `$OBSIDIAN_CLI` is unset but Step 4 and Step 5 still invoke `"$OBSIDIAN_CLI" ...`, producing a `command not found` error rather than the documented graceful skip. Peer pattern (`lessons-learned/operations/{single-session-analysis,aggregate-patterns}.md`) uses an explicit `if [[ -z "$OBSIDIAN_CLI" ]]; then skip` guard or early-return. Add the same guard before Step 4 and Step 5 CLI invocations.

### Advisory

- **skills/compound/operations/document-solution.md:153** — [security] _command injection via unescaped body content_ (warning) — `content="# <Problem title>\n\n## Problem\n\n<Problem text>..."` interpolates user-supplied prose into a shell-quoted argument with no escaping guidance. A title or body text containing `"` or `$(...)` closes the quote or executes a subshell under user privileges. Self-injection only, but tighten via heredoc/`--content-file`, or require single-quote-with-`'\''`-escape for substituted text.
- **skills/compound/operations/document-solution.md:99-110** — [security] _command injection via slug interpolation_ (warning) — `slug="<short-description>"` is filled by the agent from user-controlled title. Same unescaped-interpolation risk. Constrain slug to `[a-z0-9-]+` and state the constraint in the recipe.
- **skills/compound/operations/document-solution.md:128-145** — [security] _command injection via property values_ (warning) — `value="<problem_type>"`, `value="<repo>"`, `value="<module>"`, etc. are unescaped agent-filled double-quoted shell args. Same fix applies.
- **skills/compound/operations/document-solution.md:102-114** — [simplicity] _over-engineered collision loop_ (warning) — The `while :` infinite loop with double-probe is overkill for a vanishingly-rare slug collision. Probe once; if collision, append `-01-`. On second collision, surface an error and let the user retry — don't loop.
- **skills/compound/operations/document-solution.md:Step 5/Step 6 tags writes** — [simplicity] _duplicate tag writes_ (warning) — Step 5 writes `tags=solution, <tag1>, <tag2>`, then Step 6 conditionally re-writes `tags=solution, critical-pattern, <other-tags>`. Restructure: compute final tag list (including `critical-pattern` if applicable) before any `property:set`, then issue a single tags call.
- **skills/compound/operations/document-solution.md:Step 5 project field** — [simplicity/architecture] _contradictory recipe_ (warning) — Recipe shows `property:set name=project ...` immediately after comment "Omit project: when there is no DO ticket / epic slug." Wrap call in `if [ -n "$project" ]` or drop the example call. As written, an LLM following literally always writes `project`, often with empty value.
- **skills/compound/operations/document-solution.md:Step 5 template pre-set claim** — [simplicity] _unverified assumption_ (warning) — Step 5 comment says "template pre-sets `type`, `date`, and the `solution` entry in `tags`." If the Solution template doesn't actually pre-set `tags=[solution]`, every note silently misses the foundational tag. Either explicitly set all three (don't rely on template), or confirm in Step 1's template read and remove the caveat.
- **skills/compound/operations/document-solution.md:Step 4 probe failure path** — [architecture] _failure-emission rule_ (warning) — Step 4's probe-loop captures `2>&1` but never emits `[obsidian-notes] <output>` to stderr on CLI failure (only treats `^Error:` as not-found). Peer pattern applies the failure-emission rule to all CLI invocations. Apply uniformly.
- **skills/compound/operations/document-solution.md:Step 6 critical-pattern tag** — [architecture] _missing reader reference_ (warning) — "QMD search and Dataview queries surface all `critical-pattern`-tagged notes on demand" has no canonical query reference. Peer skills point at `skills/task-workflow/references/solution-search.md` for the read-side protocol. Add a one-line pointer so read/write paths stay in sync.
- **README.md:22** — [correctness] _scope gap vs DESIGN.md_ (warning) — DESIGN.md Affected Components lists README.md under cross-reference prose updates; PR doesn't modify it. Description "Capture solved problems as searchable solution documents with YAML frontmatter for agent discovery" is location-agnostic but doesn't reflect the vault rehome. Either update or document the deliberate skip. (Task #1 audit in workspace CLAUDE.md classified as "no edit needed" — surface the inconsistency.)
- **skills/lessons-learned/SKILL.md:26,31,177,185** — [correctness] _scope gap vs DESIGN.md_ (warning) — DESIGN.md lists lessons-learned SKILL.md as cross-reference prose to update. PR touched only `operations/single-session-analysis.md`, leaving parent SKILL.md "creates searchable solution docs" prose. Refresh or document the deliberate skip.
- **skills/diataxis/SKILL.md:162** — [correctness] _scope gap vs DESIGN.md_ (warning) — DESIGN.md lists diataxis SKILL.md as cross-reference prose. Current text "Document solutions (pairs with how-to guides)" is location-agnostic; PR leaves untouched. Either retouch to make vault framing explicit or document the deliberate skip.
- **skills/compound/SKILL.md:5-13** — [architecture] _unused allowed-tools_ (info) — `Write` and `Edit` remain in `allowed-tools` but the operation no longer writes solution files directly. Trim to `Read, Bash, Grep, Glob, AskUserQuestion`.
- **~/.claude/skills/obsidian-notes/SKILL.md:91** — [architecture] _documentation gap_ (info) — Available-templates list omits `Solution`. CLI accepts any template that exists in vault, so this is cosmetic — follow-up on obsidian-notes skill.
- **skills/compound/operations/document-solution.md:Step 2 example** — [simplicity] _example bloat / real-incident flavor_ (info) — Example confirmation balloons from 4 lines to 9 fields using a real Dev-Stacks scenario ("legacy-stacks.auto.tfvars"). Reads as captured incident, not generic skill example. Trim or use placeholders.
- **skills/compound/operations/document-solution.md:Idempotency section** — [simplicity] _hand-wavy spec_ (info) — "if update, set additional property:set calls and append deltas" — no recipe for computing deltas, and `append` would duplicate body sections. Tighten to: "if duplicate detected, prompt user; on confirm-update, re-run `property:set` for changed fields only — do not re-append body."
- **skills/compound/operations/document-solution.md:Error Handling table** — [simplicity] _duplication of NBF contract_ (info) — Two rows duplicate guidance in obsidian-notes Non-Blocking Failure Contract. Could be one row: "Any obsidian-notes CLI error → follow Non-Blocking Failure Contract."
- **skills/compound/operations/document-solution.md:Step 6 tag re-write** — [correctness] _clobber risk_ (info) — Step 6 re-issues the full tag list. If operator forgets a tag from Step 5 when constructing Step 6, Step 5 tags get clobbered. Recommend computing final tag list before any tag write (see also redundancy finding above).
