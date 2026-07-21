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

## 2. Release hygiene when publishing a new skill

Do this **in the same commit/PR** that adds the published skill — a new skill
is not "published" until the manifest knows about it.

1. **Register the skill** in `.claude-plugin/marketplace.json` under
   `plugins[].skills`. Keep the list **alphabetical**.
2. *(Optional)* Update the **README skills table** so the new skill is
   discoverable from the front page.

Skip step 1 and the skill ships in the tree but not in the published plugin —
it will not load for installed users.

**Do NOT bump the version** in `.claude-plugin/plugin.json` or
`.claude-plugin/marketplace.json` as part of a skill-adding PR. That used to
be step 2 here, and it caused a real defect: when multiple skill-adding PRs
are open concurrently, each computes the same "next" version independently,
so a batch of N concurrent PRs all claim the *same* version instead of
leapfrogging it. The resulting text is byte-identical, so git's merge
machinery sees no conflict — the pileup lands silently, with no signal that
N releases got flattened into one version number. Concurrent additions to the
`skills` array are fine (they touch distinct array positions and any real
conflict there surfaces normally); the version fields are the collision
point because every concurrent PR edits the exact same line.

The version bump is a **separate, maintainer-run step**, done once after
merging a batch of skill-adding PRs (or per merge, if you're not batching):

```
scripts/bump-version.sh
```

This minor-bumps `plugin.json` and `marketplace.json` together and keeps them
in sync — run it, then commit the result.

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

- `README.md` — the skills table (release-hygiene step 2).
- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` — the
  manifest step 1 updates; `scripts/bump-version.sh` bumps the version fields
  separately.
- `scripts/bump-version.sh` — the release-time version bump, run outside any
  individual skill-adding PR.
- `skills/goal-tree/commands/inbox.md` — in-plugin command precedent (rule 1).
- `skills/self-verify/references/bounded-external-waits.md` — canonical home
  of the bounded-wait recipe, the `inconclusive` outcome, and the
  bash-vs-zsh constraint (rule 3).
- `skills/lN-review-doctrine/references/verification-map.md` — Doctrine-class
  PR sub-checklist item 7, the review-time check for rule 3.
- `skills/skillify/SKILL.md` — the authoring-time entrypoint where a new
  skill's draft steps get checked against this doctrine before being
  written (all three rules).
