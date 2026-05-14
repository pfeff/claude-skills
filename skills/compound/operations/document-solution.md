# Document Solution Operation

**When**: User invokes `/claude-skills:compound` to capture a solved problem as a searchable solution doc.

## Purpose

Captures a single solved problem as a dated note in the tcetra Obsidian vault (`type: solution`) so QMD's hybrid search can route future agents to it. Fast and focused — not a retrospective.

## Execution

### Step 1: Load Schema

The frontmatter contract lives in the vault template. Reference it at runtime via the Obsidian CLI if needed:

```bash
OBSIDIAN_CLI="/mnt/c/Users/mpfefferle/AppData/Local/Programs/Obsidian/Obsidian.com"
"$OBSIDIAN_CLI" vault=tcetra read path="Templates/Solution.md"
```

### Step 2: Gather Problem Context

If `$ARGUMENTS` contains a problem description, use it as seed context. Otherwise, derive context from the current conversation.

**Information needed** (ask only for what can't be inferred):

| Field | Source | Ask if missing |
|-------|--------|----------------|
| Problem description | Conversation context or `$ARGUMENTS` | Yes |
| What was the fix | Conversation context | Yes |
| Symptoms (body section) | Conversation context | Only if not obvious |
| Repository | Current working directory or workspace | Only if ambiguous |
| Module/component | Code context | Only if unclear |

**Use AskUserQuestion** to fill gaps efficiently. Prefer a single question with multiple fields over multiple rounds.

Example:
```
I'll capture this as a solution note in the vault. Based on our session:

**Problem**: OTP supervisor restart loop on config reload
**Fix**: Validate config in handle_continue/2 before applying
**Repo**: agent-coordinator
**Module**: PolicyEngine

Anything to adjust before I write it up?
```

### Step 3: Generate Frontmatter

Map the gathered context to the frontmatter contract:

| Field | Type | How to derive |
|-------|------|---------------|
| `type` | text | Always `solution` (set by template) |
| `date` | date | Today's date (set by template) |
| `problem_type` | text | Classify from problem: `build-error` \| `test-failure` \| `runtime-error` \| `performance` \| `integration` \| `workflow` \| `best-practice` |
| `severity` | text | Infer from impact: `critical` (system down), `high` (feature broken), `medium` (degraded), `low` (cosmetic/minor) |
| `module` | text | Module or system name (optional) |
| `repo` | text | Repository where the fix landed — informational only (optional) |
| `project` | text | Jira key or epic slug (optional) |
| `tags` | list | Always include `solution` + one problem-domain tag (e.g. `kafka`, `terraform`, `aws-iam`) + one tool/tech tag (e.g. `python`, `dotnet`) |
| `keywords` | list | Wiki-links to `Keywords/` pages for canonical domain terms (optional) |
| `related` | list | Wiki-links to sibling solutions or runbooks (optional) |

**Tag rule**: every note must have `solution` + at least one problem-domain tag. Severity and problem_type stay in frontmatter only — do not add them to tags.

### Step 4: Determine File Location

All notes go to the tcetra vault at the dated-notes path. No category subdirectory.

**Slug**: 2–5 lowercase hyphenated words from the problem headline.

**Target path**: `Notes/YYYY/MM/YYYY-MM-DD-<slug>.md`

**Collision probe** — before creating, check if the path is free:

```bash
OBSIDIAN_CLI="/mnt/c/Users/mpfefferle/AppData/Local/Programs/Obsidian/Obsidian.com"
out=$("$OBSIDIAN_CLI" vault=tcetra read path="Notes/YYYY/MM/YYYY-MM-DD-<slug>.md" 2>&1)
first_line=$(printf '%s\n' "$out" | head -1)
```

If `$first_line` does NOT start with `Error:`, the path is taken — increment the `-NN-` suffix:
- First collision: `YYYY-MM-DD-01-<slug>.md`
- Second: `YYYY-MM-DD-02-<slug>.md`
- Re-probe after each increment.

### Step 5: Write Solution Document

Use the Obsidian CLI — never write vault files directly.

**5a. Create from template** (pre-fills `type`, `date`, body skeleton):

```bash
OBSIDIAN_CLI="/mnt/c/Users/mpfefferle/AppData/Local/Programs/Obsidian/Obsidian.com"
out=$("$OBSIDIAN_CLI" vault=tcetra create \
  path="Notes/YYYY/MM/YYYY-MM-DD-<slug>.md" \
  template="Solution" 2>&1)
if printf '%s\n' "$out" | head -1 | grep -q '^Error:'; then
  printf '[compound] create failed: %s\n' "$out" >&2
fi
```

**5b. Set frontmatter properties** (use the correct `type=` per the obsidian-notes Frontmatter Contract):

```bash
NOTE="Notes/YYYY/MM/YYYY-MM-DD-<slug>.md"

# Required fields (type and date already set by template)
"$OBSIDIAN_CLI" vault=tcetra property:set name=problem_type value="<enum>" type=text path="$NOTE"
"$OBSIDIAN_CLI" vault=tcetra property:set name=severity value="<enum>" type=text path="$NOTE"
"$OBSIDIAN_CLI" vault=tcetra property:set name=tags value="solution, <domain-tag>, <tech-tag>" type=list path="$NOTE"

# Optional fields — only set if non-empty
"$OBSIDIAN_CLI" vault=tcetra property:set name=module value="<ComponentName>" type=text path="$NOTE"
"$OBSIDIAN_CLI" vault=tcetra property:set name=repo value="<repo-name>" type=text path="$NOTE"
"$OBSIDIAN_CLI" vault=tcetra property:set name=project value="<DO-key>" type=text path="$NOTE"
"$OBSIDIAN_CLI" vault=tcetra property:set name=keywords value="[[KeywordA]], [[KeywordB]]" type=list path="$NOTE"
"$OBSIDIAN_CLI" vault=tcetra property:set name=related value="[[sibling-note]]" type=list path="$NOTE"
```

**5c. Append body content** — replace the template's placeholder heading with actual content:

```bash
"$OBSIDIAN_CLI" vault=tcetra append \
  path="$NOTE" \
  content="# <Concise problem title>\n\n## Problem\n\n<What went wrong and how it manifested.>\n\n## Symptoms\n\n- <symptom 1>\n- <symptom 2>\n\n## Root Cause\n\n<What actually caused the issue.>\n\n## Solution\n\n<What was done to fix it, with code examples if applicable.>\n\n## Prevention\n\n<How to avoid this in the future.>\n"
```

> **Note**: The `create` command pre-populates the body skeleton from the template. If the template content is already present, use `Obsidian CLI read` to inspect and edit rather than append.

**5d. Update related notes** (if `related:` is set): if the relationship is symmetric, append a reciprocal wiki-link to each related note's `related:` frontmatter field.

### Step 6: Check for Critical Pattern Promotion

If `severity` is `critical` OR the problem has recurred (user confirms), offer to promote to the vault's critical-patterns MOC:

```
This is a critical/recurring issue. Should I add it to the critical-patterns MOC?
```

If yes:

1. Locate or create the MOC at `Notes/YYYY/MM/YYYY-MM-DD-critical-patterns-moc.md` with `type: moc`.
   - Probe first: if it exists, append; if not, create with `template="MOC"` and set `type=moc`.
2. Append a summary entry:

```bash
"$OBSIDIAN_CLI" vault=tcetra append \
  path="<moc-path>" \
  content="### CP-N: <pattern title>\n\n**Severity**: <severity>\n**Repos**: <repo list>\n**Tags**: <tags>\n\n<one-paragraph description> See [[<slug>]].\n"
```

### Step 7: Report Output

Display:
```
Solution captured:
  Notes/YYYY/MM/YYYY-MM-DD-<slug>.md

Fields: type=solution, problem_type=<type>, severity=<level>, tags=[solution, <tags>]

Vault content is not committed to a git repo — the note is available immediately in Obsidian and will be indexed by QMD after the next update (Step 8).
```

### Step 8: Index Refresh

Run `qmd update` so the new note enters the search index immediately. Capture combined output and apply the non-blocking-failure contract — never block on this step.

```bash
qmd_out=$(qmd update 2>&1)
if echo "$qmd_out" | grep -qi 'error\|fatal'; then
  printf '[compound] qmd update warning: %s\n' "$qmd_out" >&2
fi
```

## Error Handling

| Error | Response |
|-------|----------|
| `create` returns `Error:` | Report and stop; do not attempt property:set on a note that doesn't exist |
| Can't classify `problem_type` | Ask user to pick from enum |
| `qmd update` fails | Log warning to stderr; do not block completion |
| Related note not found for backlink | Skip reciprocal update; log a note to the user |

## Idempotency

Re-running with the same problem context hits the Obsidian-CLI `read` probe at Step 4 and increments the `-NN-` suffix to produce a new note. If the intent is to update an existing note, locate it via `qmd query` or `Obsidian CLI read` first and use `property:set` / `append` to modify it.
