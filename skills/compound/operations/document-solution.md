# Document Solution Operation

**When**: User invokes `/claude-skills:compound` to capture a solved problem as a searchable solution note in the host's Obsidian vault.

## Purpose

Captures a single solved problem as a `type=solution` note with structured YAML frontmatter so future agents can discover it via QMD hybrid search. Fast and focused — not a retrospective.

## Prerequisites

The `obsidian-notes` skill must be available and the host's `~/.claude/hosts/<hostname>.md` must define an `## Obsidian` section. If the vault is unreachable, this operation degrades to a non-blocking warning per the obsidian-notes Non-Blocking Failure Contract — the user can re-run later.

## Execution

### Step 1: Source Host Config and Read the Solution Template

Source the obsidian-notes host helper to load vault constants:

```bash
HOST_CONFIG="$HOME/.claude/skills/obsidian-notes/scripts/host-config.sh"
source "$HOST_CONFIG" || {
    # Helper printed `[obsidian-notes] <reason>`; report capture skipped and stop.
    :
}
# Sets OBSIDIAN_CLI, OBSIDIAN_VAULT, OBSIDIAN_VAULT_PATH
```

Read the vault's Solution template to see the canonical field list and body structure:

```
Read(file_path: "${OBSIDIAN_VAULT_PATH}/Templates/Solution.md")
```

### Step 2: Gather Problem Context

If `$ARGUMENTS` contains a problem description, use it as seed context. Otherwise, derive context from the current conversation.

**Information needed** (ask only for what can't be inferred):

| Field | Source | Ask if missing |
|-------|--------|----------------|
| Problem title (short, descriptive) | Conversation or `$ARGUMENTS` | Yes |
| Problem description | Conversation | Yes |
| Symptoms (observable behaviors, 1–5) | Conversation | Yes |
| Root cause | Conversation | Yes |
| Fix / solution | Conversation | Yes |
| Prevention (how to avoid recurrence) | Conversation | Optional |
| Repository | Workspace context | Only if ambiguous |
| Module/component | Code context | Only if unclear |
| Project (DO ticket / epic slug) | Workspace context | Only if ambiguous |

**Use AskUserQuestion** to fill gaps efficiently. Prefer a single confirmation with all fields over multiple rounds.

Example confirmation:

```
I'll capture this as a solution note in your Obsidian vault. Based on our session:

**Title**: Safely remove a terraform legacy variable shim after migration completes
**Problem**: legacy-stacks.auto.tfvars persisted past its migration cutoff…
**Symptoms**: 1) duplicate Cloudflare rules, 2) silent merge override, 3) dead variables
**Root cause**: file header precondition ("once all stacks migrated") became true but was never enforced
**Fix**: removed the file; collapsed merge() in cloudflare.tf
**Prevention**: add migration-cutoff assertion to the module
**Repo**: Dev-Stacks
**Module**: devstacks-shared
**Project**: stack97-98-teardown

Anything to adjust before I write it up?
```

### Step 3: Generate Frontmatter

Map the gathered context to the vault Solution template fields:

| Field | Type | How to derive |
|-------|------|---------------|
| `type` | text | Always `solution` (pre-set by template) |
| `date` | date | Today's date (auto-resolved from the template's `{{date}}` token at create time) |
| `problem_type` | text | One of: `build-error`, `test-failure`, `runtime-error`, `performance`, `integration`, `workflow`, `best-practice` |
| `severity` | text | `critical` (system down) / `high` (feature broken) / `medium` (degraded) / `low` (cosmetic/minor) |
| `module` | text | Module or system name |
| `repo` | text | Repository where the fix was applied |
| `project` | text | DO ticket / epic slug, if applicable (omit if not workspace-scoped) |
| `tags` | list | Always include `solution`. Append topical keywords (lowercase, hyphen-separated). If `severity=critical` or the problem is known to recur, also include `critical-pattern` (see Step 6). |
| `keywords` | list | Wiki-links to existing `Keywords/` pages, if relevant terms exist (e.g., `"[[Terraform]]"`). Omit when nothing applies. |
| `related` | list | Wiki-links to related vault notes, optional |

### Step 4: Determine Note Path

```
Notes/<YYYY>/<MM>/<YYYY-MM-DD>-<slug>.md
```

- `<slug>`: 2–5 words, lowercase, hyphen-separated, derived from the problem title.
- Probe for collision before creating. If the path is taken, append `-NN-` after the date (e.g., `2026-05-18-01-<slug>.md`).

```bash
slug="<short-description>"
target="Notes/$(date +%Y)/$(date +%m)/$(date +%Y-%m-%d)-${slug}.md"

probe_out=$("$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" read path="$target" 2>&1)
if ! printf '%s\n' "$probe_out" | head -1 | grep -q '^Error:'; then
  # Collision: increment -NN- prefix and re-probe until free.
  i=1
  while :; do
    nn=$(printf '%02d' "$i")
    candidate="Notes/$(date +%Y)/$(date +%m)/$(date +%Y-%m-%d)-${nn}-${slug}.md"
    out=$("$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" read path="$candidate" 2>&1)
    if printf '%s\n' "$out" | head -1 | grep -q '^Error:'; then target="$candidate"; break; fi
    i=$((i+1))
  done
fi
```

### Step 5: Create the Note and Set Frontmatter

Delegate the write to the `obsidian-notes` CLI. Create from the `Solution` template:

```bash
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" create \
  path="$target" template="Solution"
```

Set each frontmatter field that needs filling (the template pre-sets `type`, `date`, and the `solution` entry in `tags`):

```bash
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set \
  name=problem_type value="<problem_type>" type=text path="$target"

"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set \
  name=severity value="<severity>" type=text path="$target"

"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set \
  name=module value="<module>" type=text path="$target"

"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set \
  name=repo value="<repo>" type=text path="$target"

# Omit project: when there is no DO ticket / epic slug.
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set \
  name=project value="<project-slug>" type=text path="$target"

"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set \
  name=tags value="solution, <tag1>, <tag2>" type=list path="$target"
```

Pass `type=` on every `property:set` call (per the obsidian-notes Frontmatter Contract — the CLI silently skips writes when `type=` is omitted for fields not already in the vault's property registry).

Append the body:

```bash
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" append path="$target" content="# <Problem title>\n\n## Problem\n\n<Problem text>\n\n## Symptoms\n\n- <symptom 1>\n- <symptom 2>\n\n## Root Cause\n\n<Root cause text>\n\n## Solution\n\n<Solution text — code examples welcome>\n\n## Prevention\n\n<Prevention text>\n"
```

Wrap each CLI call per the obsidian-notes Non-Blocking Failure Contract: capture combined stdout+stderr, check whether the first line starts with `Error:`, and emit `[obsidian-notes] <output>` to stderr on failure. Continue the rest of the operation; don't fail the parent flow.

### Step 6: Critical-Pattern Tagging

If `severity=critical`, OR if the user confirms the problem has recurred, ensure `critical-pattern` is included in the `tags` list (re-run `property:set` for `tags` with the augmented list):

```bash
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set \
  name=tags value="solution, critical-pattern, <other-tags>" type=list path="$target"
```

This replaces the legacy `docs/solutions/patterns/critical-patterns.md` aggregator. QMD search and Dataview queries surface all `critical-pattern`-tagged notes on demand — no separate aggregator file is needed.

### Step 7: Report

Display:

```
Solution captured:
  <vault>/Notes/<YYYY>/<MM>/<filename>

Fields: problem_type=<type>, severity=<level>, tags=[<tags>]
```

No git-commit step — the vault has its own sync.

## Error Handling

| Error | Response |
|-------|----------|
| Host config missing `## Obsidian` section | `source "$HOST_CONFIG"` returns non-zero; report capture skipped and stop. Don't fail the parent flow. |
| Obsidian CLI reachable but returns `Error:` | Emit `[obsidian-notes] <output>` to stderr; continue. Report which step failed in the final report. |
| Can't classify `problem_type` | Ask user to pick from the enum (build-error, test-failure, runtime-error, performance, integration, workflow, best-practice). |
| Collision on target path | Append `-NN-` prefix per Step 4; re-probe until free. |

## Idempotency

Re-running with the same problem context will detect an existing note at the candidate path via the Step 4 probe (`read` returns content rather than `Error:`). Ask whether to update or skip; if update, set additional `property:set` calls and `append` deltas; if skip, exit cleanly.
