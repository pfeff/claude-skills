# Aggregate Patterns Operation

**When**: User wants to identify recurring patterns across multiple lessons learned sessions

## Purpose

Scans historical lessons learned documents to extract and aggregate patterns, anti-patterns, bottlenecks, and recommendations. Surfaces the most common improvement opportunities across sessions.

## Execution

### Step 1: Resolve Vault Path and Locate Files

Resolve Obsidian vault constants via the host-config helper:

```bash
source "$HOME/.claude/skills/obsidian-notes/scripts/host-config.sh" || {
  echo "[obsidian-notes] vault unavailable on this host; aborting aggregation" >&2
  exit 1
}
```

On success: `$OBSIDIAN_VAULT_PATH` is the vault filesystem root (used for read-side globs); `$OBSIDIAN_CLI` / `$OBSIDIAN_VAULT` are the CLI binary and vault name for writes (see Step 6).

Search for lessons files:
```bash
ls -1t "$OBSIDIAN_VAULT_PATH"/Generated/*Lesson*.md 2>/dev/null | head -20
```

Default location: `Generated/*Lesson*.md` under `$OBSIDIAN_VAULT_PATH`.

### Step 1b: Locate Previous Aggregation Report

Search for the most recent aggregation report to use as a baseline for effectiveness comparison:

```bash
# Find previous aggregation reports
ls -1 "$OBSIDIAN_VAULT_PATH"/Generated/*Pattern*Aggregation*.md 2>/dev/null | sort -r | head -1
```

If found, extract:
- **Date** of previous aggregation
- **Pattern frequencies** (from frequency tables)
- **Anti-pattern frequencies**
- **Implemented recommendations** (checked action items: `- [x] REC-XXX`)

Store as baseline for comparison in Step 4.

### Step 2: Extract Patterns from Each File

For each lessons learned file, extract:

**Positive Patterns** (under `## Positive Patterns`):
- Each bullet item under this heading is a pattern
- Extract the full bullet text

**Recommendations** (under `## Recommendations`):
- REC-ID and title (from `#### REC-\d+:` lines)
- Category
- Priority
- Implementation status (if action items show completion)

### Step 3: Aggregate and Count

Build frequency tables:

```
Pattern Frequency:
| Pattern | Count | Sessions | Avg Impact |
|---------|-------|----------|------------|
| Parallel File Reading | 5 | 50% | HIGH |
| Taskfile-First | 4 | 40% | MEDIUM |
...

Anti-Pattern Frequency:
| Anti-Pattern | Count | Sessions |
|--------------|-------|----------|
| Direct Terraform Commands | 3 | 30% |
...

Recommendation Categories:
| Category | Count | Implemented | Pending |
|----------|-------|-------------|---------|
| Documentation | 8 | 3 | 5 |
| Workflow | 5 | 2 | 3 |
...
```

### Step 3b: Effectiveness Analysis (if baseline exists)

If a previous aggregation report was found in Step 1b, compare current vs baseline:

**Pattern Frequency Delta**:
For each anti-pattern present in both reports:
- Calculate frequency change: `current_count - baseline_count`
- Classify as: **Improving** (decreased), **Stable** (unchanged), **Worsening** (increased)

**Recommendation Correlation**:
Cross-reference implemented recommendations (from self-improvement traceability markers and action item checkboxes) with anti-pattern changes:
- Find REC-IDs marked as implemented since baseline date
- Check which anti-patterns those recommendations targeted
- Correlate: did the targeted anti-pattern frequency decrease?

**New Pattern Detection**:
- Patterns in current report but not in baseline → **New** (potential regression or new workflow)
- Patterns in baseline but not in current report → **Resolved** (no longer occurring)

**Effectiveness Output Format**:

```markdown
## Skill Evolution Effectiveness

**Baseline**: [previous aggregation date]
**Current**: [this aggregation date]
**Sessions since baseline**: [N]

### Improvements Working
| Anti-Pattern | Baseline | Current | Change | Related REC |
|-------------|----------|---------|--------|-------------|
| Direct Terraform Commands | 5 (50%) | 1 (10%) | -4 ↓ | REC-012 |

### No Change Detected
| Anti-Pattern | Baseline | Current | Related REC |
|-------------|----------|---------|-------------|
| Manual Config Edits | 3 (30%) | 3 (25%) | REC-008 (pending) |

### New Anti-Patterns
| Anti-Pattern | Current | Sessions |
|-------------|---------|----------|
| Excessive Context Loading | 2 (20%) | session-A, session-B |

### Resolved (No Longer Occurring)
| Anti-Pattern | Last Seen | Related REC |
|-------------|-----------|-------------|
| Redundant File Reads | [baseline date] | REC-005 |

### Effectiveness Score
- **Improvements working**: N/M targeted anti-patterns reduced
- **Overall trend**: [Improving / Stable / Declining]
```

### Step 4: Identify Top Opportunities

**Focus on Skills/Commands/Agents**: Filter recommendations to those that can be implemented as improvements to Claude's configuration in `~/.claude/`. Transform project-specific insights into skill improvements where possible.

Rank by:
1. **Implementability** - Can be added to a skill, command, or agent
2. **Frequency** - Patterns appearing in >30% of sessions
3. **Impact** - HIGH impact patterns prioritized
4. **Actionability** - Clear target file in `${CLAUDE_PLUGIN_ROOT}/skills/` or `~/.claude/commands/`

### Step 5: Generate Summary Report

Output format (to stdout or optional file):

```markdown
# Pattern Aggregation Report

**Sessions Analyzed**: [N]
**Date Range**: [earliest] to [latest]

## Top Positive Patterns (Keep Doing)

1. **Pattern Name** - [N] sessions ([%])
   - Impact: [level]
   - Example sessions: [list]

## Top Anti-Patterns (Avoid)

1. **Anti-Pattern Name** - [N] sessions ([%])
   - Common context: [description]
   - Recommended fix: [action]

## Recurring Bottlenecks

1. **Bottleneck** - [N] sessions
   - Root cause theme: [description]
   - Suggested systemic fix: [action]

## Pending High-Priority Recommendations

1. **REC-XXX: Title** (from [session])
   - Category: [cat]
   - Rationale: [why important across sessions]

## Skill Improvement Opportunities

Based on patterns, these skills could be enhanced:
- **[skill-name]** (v[current version]): [specific improvement]

## Skill Evolution Effectiveness

[Include effectiveness analysis from Step 3b if baseline exists.
If no baseline exists, note: "No previous aggregation found. Run again after implementing improvements to track effectiveness."]
```

### Step 6: Save Report to Obsidian Vault

Save the aggregation report as an Obsidian note for future baseline comparison.

**Filename**: `Generated/YYYYMMDDHHmm-Pattern Aggregation Report.md` — this consistent naming enables Step 1b to locate previous reports via the `*Pattern*Aggregation*.md` glob.

**Write via the Obsidian CLI** (Non-Blocking Failure Contract applies per `obsidian-notes/SKILL.md`):

```bash
NOTE_PATH="Generated/$(date +%Y%m%d%H%M)-Pattern Aggregation Report.md"

# 1. Create the note. No dedicated template — use Reference, or create without template= if Reference is unsuitable.
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" create path="$NOTE_PATH" template="Reference"

# 2. Set frontmatter via property:set (always pass type=).
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set name=date     value="[[$(date +%Y-%m-%d)]]" type=text path="$NOTE_PATH"
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set name=month    value="[[$(date +%Y-%m)]]"    type=text path="$NOTE_PATH"
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set name=tags     value="generated_note, lessons_learned" type=list path="$NOTE_PATH"
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" property:set name=keywords value="[[Pattern Aggregation]], [[Skill Evolution]]" type=list path="$NOTE_PATH"

# 3. Append the aggregation report body (the markdown produced in Step 5).
"$OBSIDIAN_CLI" vault="$OBSIDIAN_VAULT" append path="$NOTE_PATH" content="<report markdown>"
```

After each CLI call, scan stdout's first line for an `Error:` prefix and emit `[obsidian-notes] <captured output>` on stderr without exiting. If `$OBSIDIAN_CLI` is unset (host-config helper failed in Step 1), skip the CLI block — the report is still available in the operation's stdout and can be redirected via `--output`.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--limit` | int | 20 | Max files to analyze |
| `--output` | string | vault | Output file path (default: Obsidian vault) |
| `--since` | date | none | Only analyze files after this date |
| `--min-frequency` | int | 2 | Min occurrences to include pattern |

## Example Usage

```
/claude-skills:lessons-learned --aggregate
/claude-skills:lessons-learned --aggregate --limit 10 --since 2026-01-01
/claude-skills:lessons-learned --aggregate --output aggregated-patterns.md
```

## Implementation Notes

### Pattern Extraction Regex

For extracting positive patterns (plain bullet items under `## Positive Patterns`):
```
^- (.+)$
```

For extracting recommendations:
```
#### (REC-\d+): (.+)\n\*\*Category\*\*: (.+)\n\*\*Effort\*\*: (.+)\n\*\*Impact\*\*: (.+)
```

### Aggregation Algorithm

1. Parse each file's markdown structure
2. Build pattern → {count, sessions[], impacts[]} map
3. Sort by frequency descending
4. Filter by min-frequency threshold
5. If baseline exists: compute frequency deltas and correlate with implemented REC-IDs
6. Format output report with effectiveness section

### Error Handling

- **No files found**: Report "No lessons learned files found in [path]"
- **Parse errors**: Skip file, log warning, continue
- **Empty patterns**: Report "No patterns extracted from [N] files"
