# Skill Authoring & Publishing Doctrine

Author-facing guidance for **where a skill's slash command lives** and **what
release hygiene a new published skill requires**. Two rules, both learned from a
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

Do all of this **in the same commit/PR** that adds the published skill — a new
skill is not "published" until the manifests know about it.

1. **Register the skill** in `.claude-plugin/marketplace.json` under
   `plugins[].skills`. Keep the list **alphabetical**.
2. **Minor-bump the version** in **both** `.claude-plugin/plugin.json` and
   `.claude-plugin/marketplace.json`. A new skill is an additive feature, so it
   is a minor bump. (Precedent: commit `f758c17` bumped the manifest minor when
   it added two skills.)
3. *(Optional)* Update the **README skills table** so the new skill is
   discoverable from the front page.

Skip step 1/2 and the skill ships in the tree but not in the published plugin —
it will not load for installed users.

## Related

- `README.md` — the skills table (release-hygiene step 3).
- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` — the manifests
  steps 1–2 update.
- `skills/goal-tree/commands/inbox.md` — in-plugin command precedent (rule 1).
