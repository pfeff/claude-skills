# Setup Operation

Ensure the vault clone exists and load the compliance contract. Every `vault-cloud` invocation
runs this first; it is idempotent.

## Configuration (which vault, resolved not hardcoded)

This skill does not name a vault repo. The operator supplies it, so the published plugin carries
no private-instance slug:

- **`OBSIDIAN_VAULT_REPO`** — the vault's GitHub repo as `<owner>/<repo>`. Set it as an
  environment variable in your cloud/remote execution environment (the same place setup scripts
  and other env vars are configured), or export it in-session before invoking the skill.
- **`OBSIDIAN_VAULT_PATH`** — where the clone lives; defaults to `/workspace/vault`.

```bash
VAULT_REPO="${OBSIDIAN_VAULT_REPO:?set OBSIDIAN_VAULT_REPO=<owner>/<repo> for your vault}"
VAULT="${OBSIDIAN_VAULT_PATH:-/workspace/vault}"
export OBSIDIAN_VAULT_PATH="$VAULT"
```

If `OBSIDIAN_VAULT_REPO` is unset, stop and ask the operator for their vault repo (or tell them
to configure it in the environment) — do not guess a slug.

## Steps

1. **Locate or create the clone.** Check first — never re-clone over a live clone:

   ```bash
   if git -C "$VAULT" rev-parse HEAD >/dev/null 2>&1; then
       echo "[vault-cloud] vault present at $VAULT"
   else
       echo "[vault-cloud] no clone yet — attach + clone (see step 2)"
   fi
   ```

2. **If absent, attach and clone.** A private vault must be added to the session before it can be
   cloned:
   - Call the `add_repo` tool with the owner/repo parsed from `$OBSIDIAN_VAULT_REPO`
     (`{owner: "<owner>", repo: "<repo>", access: "read"}`; use `access: "push"` only if you
     will push from this same step — `write-note` handles its own push).
   - Then clone **once, inline, with a generous timeout** (a shallow pack can take minutes
     through the proxy; do not interrupt `git index-pack`):

     ```bash
     git clone --depth 1 "https://github.com/$VAULT_REPO" "$VAULT"
     ```
   - After a successful clone, call `register_repo_root` (owner/repo from `$OBSIDIAN_VAULT_REPO`,
     `directory: "$VAULT"`) so the vault's own CLAUDE.md/skills load. Best-effort — proceed if it
     is denied.

   If `add_repo` reports the repo is not accessible, stop and tell the operator: cloud vault
   access depends on the session having GitHub access to the configured vault repo.

3. **Load the compliance contract.** Read the vault's own rules — they are the source of truth,
   and they may have changed since this skill was written:

   ```
   Read(file_path: "$OBSIDIAN_VAULT_PATH/_meta/agent-contract.md")
   Read(file_path: "$OBSIDIAN_VAULT_PATH/_meta/vocabulary.md")
   ```

   `write-note` parses `_meta/vocabulary.md` mechanically via
   `vault_compliance.parse_vocabulary`; reading them here also gives you the human-facing rules
   (path scheme, "don't invent values", "don't touch `_meta/`", "don't reorganize").

4. **Freshness.** If the clone already existed, pull the default branch before reading or writing
   so you are not working against a stale vault (retry on network error, bounded):

   ```bash
   git -C "$OBSIDIAN_VAULT_PATH" pull --ff-only origin main || \
     echo "[vault-cloud] pull skipped (offline or diverged) — working against current clone" >&2
   ```

## Output

`OBSIDIAN_VAULT_PATH` exported and pointing at a usable clone; the contract loaded. Hand off to
`search.md` or `write-note.md`.
