# Skill Authoring & Publishing Doctrine

Author-facing guidance for **where a skill's slash command lives**, **what
release hygiene a new published skill requires**, and **how a verify/validation
step must handle external resources**. Three rules, all learned from a
retrospective; apply them whenever you add or evolve a skill in this repo.

## 1. Where does the slash command live?

**Ship the command in-plugin by default.** A skill's slash command belongs at
`skills/<name>/commands/<name>.md` inside this repo. The published plugin already
surfaces these commands directly — no external wrapper is needed for the command
to exist. Precedent: `skills/goal-tree/commands/inbox.md` ships `/inbox` straight
from the plugin.

**Add a separate host-side wrapper only when it carries host-specific behavior.**
A wrapper command (a thin `commands/<name>.md` kept in a personal dotfiles repo,
outside this plugin) is justified **only** when it does something the public,
host-agnostic plugin cannot — e.g. writing to a local notes vault, integrating a
host-only staff/assistant flow, or applying a per-machine tweak. The `/finish`
command is the model for a *justified* wrapper: it exists because it fires
host-specific hooks.

**Do not** add a wrapper that merely forwards `$ARGUMENTS` to the in-plugin
command with no host-specific logic. A pass-through wrapper adds nothing and
splits one capability across two repos.

**The precedent check.** Before copying any existing command as a template, read
*why* that precedent is shaped the way it is and ask: **does that rationale apply
here?** A wrapper justified by host hooks (`/finish`) is not a reason to wrap a
command that has no host hooks. Pick the *minimal correct* template, not the most
visible one.

## 2. Release hygiene: bump the version IN the PR that changes what ships

The version bump is **atomic with the change that necessitates it** — it lands
in the *same* PR, not in a separate maintainer step afterward. Do all of this
in the one PR:

1. **Register the skill** (for a new skill) in
   `.claude-plugin/marketplace.json` under `plugins[].skills`. Keep the list
   **alphabetical**. Skip this and the skill ships in the tree but not in the
   published plugin — it will not load for installed users.
2. **Bump the version** in both manifests by running, from the repo root:

   ```
   scripts/bump-version.sh
   ```

   This minor-bumps `.claude-plugin/plugin.json` and
   `.claude-plugin/marketplace.json` together, keeping them byte-in-sync.
   Commit the result as part of the PR.
3. *(Optional)* Update the **README skills table** so the new skill is
   discoverable from the front page.

Any PR that touches the **shipped surface** — `skills/**` or
`.claude-plugin/**` — must carry its own bump. Docs-only, scripts-only, or
CI-only PRs need not bump.

### Why hand-bumping used to be banned — and why it's safe now

The old doctrine kept the bump *out* of PRs because of a real defect: when two
skill-adding PRs are open concurrently, each computes the same "next" version
independently (both write `2.12.0`). The edits are byte-identical, so git's
merge machinery sees no conflict and lets **both** land under one version
number — N releases silently flatten into one. Deferring the bump to a manual
post-merge script sidestepped the collision but decoupled the version from the
change, and left the bump easy to forget (it was — see the vault-cloud gap that
2.12.0 repaid).

We now keep the bump in the PR **and** make the collision fail loudly, via a
required CI gate.

### Enforcement — the version gate

`scripts/check-version-bump.py`, wired in
`.github/workflows/version-gate.yml`, runs on every PR and enforces:

- both manifests are **in sync**;
- if the PR changed the shipped surface, its version is **strictly greater than
  main's *current* version** — compared against `origin/main`'s tip, not the
  PR's stale branch point.

That comparison is what turns the silent collision into a hard failure. The
moment one PR merges and bumps main, every other open PR that reused that same
version is measured against the new, equal base and **fails** the
strictly-greater check — the author is told to rebase and re-run
`scripts/bump-version.sh` so the bump leapfrogs main's new value. Two PRs can
no longer share a version or clobber each other's bump silently; a stale bump
is a visible, blocking error.

**Admin setup (one-time, required for full coverage).** The gate is airtight
only once an admin, in the repo's branch-protection / ruleset settings:

- makes **`Version Gate / version-bump`** a **required status check** on
  `main`, and
- **serializes merges** so each PR is re-validated against a main that already
  includes the previous merge. Do this with **"Require branches to be up to date
  before merging"** (recommended — provably closes the race): after one PR
  merges and bumps main, every other PR is forced to update onto the new main
  before it can merge. Updating collapses the trailing PR's byte-identical bump
  into a no-op (its version now equals main's), so the gate re-runs and fails
  the strictly-greater check — forcing a re-bump. The cost is manual update
  churn (each merge invalidates the others).

  A **merge queue** is only a safe substitute if it is configured to merge
  **one PR at a time** (maximum group size = 1). Do **not** rely on a *batched*
  merge queue for this: it stacks several queued PRs into a single `merge_group`
  and checks them once against the pre-queue base, and two byte-identical bumps
  to the same version collapse to one `X→X+1` transition in that combined tree
  (git sees both sides making the identical edit — no conflict). The gate's
  `version > base` check then passes for the whole group and both PRs merge
  under one version — the exact collision we are trying to prevent. The gate
  still runs on `merge_group` (so a size-1 queue re-validates correctly), but
  batching defeats it.

Without that admin step the gate still catches the common case (a branch behind
main, or a within-PR desync); only the exact-simultaneous-merge race needs the
queue/up-to-date toggle to close.

## 3. Verify/validation steps that touch external resources must run bounded

**Applies at authoring time**, not just when a job later executes the step:
if you are writing a verify, validation, or acceptance-check step — in a new
skill's `SKILL.md`, in an `operations/*.md` file, or in any doctrine that
prescribes a check — and that step depends on a flaky or slow **external**
resource (a third-party API/service, an OS-integration shell-out such as
AppleScript/iCloud, anything outside the repo's own test/build toolchain),
it MUST run under the hard-cap + kill-on-stall recipe (`run_bounded_external`)
in `skills/self-verify/references/bounded-external-waits.md` — never as a
wait the step's own reader/executor supervises unbounded. A bare wall-clock
timeout is not sufficient; that recipe also detects a stall via flat-CPU
sampling before the cap fires. Read that file's "Doctrine" section for the
full rule and the `inconclusive` outcome a capped/stalled step degrades to
(never a silent pass, never an indefinite block).

**Pin the interpreter explicitly — this recipe requires bash and hard-errors
under zsh.** The recipe uses bash job control (`set -m`) for process-group
isolation; under zsh, `set -m` fails outright (`set: can't change option:
-m`) because zsh refuses job-control changes in a non-interactive shell, and
zsh's `$-` doesn't carry the `m` flag at all for the save/restore guard to
work. Concretely: invoke it with `bash script.sh`, `bash -c '...'`, or a
`#!/usr/bin/env bash` shebang — never by sourcing it into a login shell or a
`sh`/`zsh`-tagged code block. A step that gets this wrong either aborts
outright or, under lenient error handling, silently runs *without*
process-group isolation — losing the exact protection the recipe exists to
provide, which is worse than not having attempted it. If your skill's code
blocks default to a different shell (e.g. this repo's `scripts/*.sh` files
are POSIX `sh` for portability — see `check-host-agnostic.sh`), a verify
step using this recipe is the one exception that needs an explicit `bash`
invocation rather than following that convention.

Distinguishing "an external call" from "a call to the repo's own
test/build/coordinator tooling," and distinguishing "this bash block is a
verify step" from "this bash block is an illustrative example," both
require judgment a general regex can't apply reliably (see
`bounded-external-waits.md`'s own doctrine section for the class of
resource this covers) — this rule is primarily enforced through self-review
and the axis-2 doctrine-class PR sub-checklist
(`skills/lN-review-doctrine/references/verification-map.md` item 7), not
mechanically.

## Related

- `README.md` — the skills table (release-hygiene step 3).
- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` — the
  manifests; step 1 registers the skill, step 2's `scripts/bump-version.sh`
  bumps both version fields in sync.
- `scripts/bump-version.sh` — the in-PR version bump (rule 2 step 2).
- `scripts/check-version-bump.py` / `.github/workflows/version-gate.yml` — the
  required CI gate that enforces the atomic bump and makes concurrent/stale
  bumps fail loudly (rule 2 "Enforcement").
- `skills/goal-tree/commands/inbox.md` — in-plugin command precedent (rule 1).
- `skills/self-verify/references/bounded-external-waits.md` — canonical home
  of the bounded-wait recipe, the `inconclusive` outcome, and the
  bash-vs-zsh constraint (rule 3).
- `skills/lN-review-doctrine/references/verification-map.md` — Doctrine-class
  PR sub-checklist item 7, the review-time check for rule 3.
- `skills/skillify/SKILL.md` — the authoring-time entrypoint where a new
  skill's draft steps get checked against this doctrine before being
  written (all three rules).
