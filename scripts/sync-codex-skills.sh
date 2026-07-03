#!/bin/sh
# sync-codex-skills.sh — install this repo's cadence-goals skill into the
# operator's local Codex runtime.
#
# ~/.codex/skills/<name>/ is a *synced install target* for the Codex CLI, not
# a source of truth: canonical content for cadence-goals lives in this repo at
# skills/cadence-goals/. Run this script after changing that skill to push the
# update into ~/.codex/skills/cadence-goals/ for Codex to pick up. Codex does
# not read this repo directly, so without this sync the two copies drift.
#
# Runnable locally:  sh scripts/sync-codex-skills.sh
#
# This script only writes under $HOME/.codex/skills — it never modifies
# anything inside this repo.

set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
dest_root="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"

sync_skill() {
  name="$1"
  src="$repo_root/skills/$name"
  dest="$dest_root/$name"

  if [ ! -d "$src" ]; then
    echo "sync-codex-skills: source $src does not exist, skipping" >&2
    return 1
  fi

  mkdir -p "$dest"
  # Mirror src into dest, deleting files removed upstream; exclude repo-only
  # metadata that has no place in a Codex skill install.
  rsync -a --delete \
    --exclude 'commands/' \
    "$src/" "$dest/"

  echo "synced $src -> $dest"
}

sync_skill cadence-goals
