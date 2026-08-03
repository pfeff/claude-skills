# /vault-cloud — Record & search the Obsidian vault from a cloud session

Read and write the Obsidian vault (the repo configured in `OBSIDIAN_VAULT_REPO`) over git from a
cloud/web/container session, where the macOS `obsidian` CLI is unavailable. Search is lexical (ripgrep); writes are
vocabulary-compliant and land on a `cloud/<date>-<topic>` branch for the operator to merge.

## Usage

```
/vault-cloud setup                 # clone the vault + load _meta/ contract
/vault-cloud search <query>        # lexical search over the clone (no QMD/semantic)
/vault-cloud write <description>   # write a compliant note, commit to a cloud/* branch
/vault-cloud                       # blank → set up, then ask search vs write
```

## Procedure

1. Load the skill entrypoint and run setup first (idempotent):

   ```
   Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/vault-cloud/SKILL.md")
   Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/vault-cloud/operations/setup.md")
   ```

2. Dispatch on `$ARGUMENTS`:
   - starts with `search` → `operations/search.md`
   - starts with `write` → `operations/write-note.md`
   - `setup` or blank → finish setup, then ask which operation the operator wants.

3. Report results per the operation (search: matches + lexical-only caveat; write: note path +
   branch name awaiting merge).

## Guardrails

- Only use in the cloud case — on the Mac, `compound`/`kb-*`/`obsidian-notes` own vault I/O.
- Writes never touch `main`, `_meta/`, `DevOps Documentation/`, or `Confluence/`, and never
  reorganize existing notes (the vault's `_meta/agent-contract.md`).
