# Session-End Review

Reviews FEEDBACK.md files from completed workspaces and triages entries into actionable improvements. Run after completing a workspace or batch of workspaces.

## When to Run

- After `/close-workspace` or `/finish` completes a task workspace
- During sprint review or periodic maintenance
- When multiple workspaces have accumulated FEEDBACK.md entries

## Relationship to /claude-skills:lessons-learned

| | Session Review | /claude-skills:lessons-learned |
|---|---|---|
| **Input** | FEEDBACK.md files from workspaces | Current conversation context |
| **Scope** | Specific friction entries with suggested fixes | Broad session analysis with metrics |
| **Output** | Triage list: skill updates, scripts, tool gaps | Obsidian note with recommendations |
| **When** | After workspace completion | After any session |

They are complementary: FEEDBACK.md captures friction at the point it occurs; /claude-skills:lessons-learned analyzes patterns across the session. Session review acts on the captured friction.

## Execution Steps

### 1. Scan for FEEDBACK.md Files

```bash
scan-feedback.sh <work_dir> --verbose
```

If no FEEDBACK.md files found, stop: "No feedback to review."

### 2. Read and Categorize Entries

For each FEEDBACK.md with entries, read the full file and categorize each entry:

| Category | Signal | Action |
|----------|--------|--------|
| **Skill update** | Entry suggests a simpler command exists or a skill should recommend a different approach | Update the relevant skill doc or reference doc |
| **New script** | Entry describes a repeated multi-step operation that could be scripted | Create script in the appropriate skill's `scripts/` directory |
| **Tool gap** | Entry identifies missing flags or capabilities in a tool (coord CLI, gh, etc.) | File as enhancement requirement or add to existing spec |

### 3. Triage and Act

For each categorized entry, decide:

**Skill updates** (do now):
- Edit the relevant skill SKILL.md, operation doc, or reference doc
- Add the simpler alternative to `docs/reference/command-simplification.md`

**New scripts** (do now if simple, defer if complex):
- Simple (< 50 lines, single purpose): create the script, add to reference doc
- Complex (multi-file, needs testing): create a task for later implementation

**Tool gaps** (defer):
- Add to the coord CLI enhancement spec (`docs/reference/coord-cli-enhancements.md`)
- Or create a GitHub issue on the relevant repo

### 4. Update Reference Doc

After triaging, update `docs/reference/command-simplification.md` with any new patterns discovered.

### 5. Archive Processed Feedback

After acting on entries, add a processed marker to each FEEDBACK.md:

```markdown
<!-- Reviewed: YYYY-MM-DD -->
```

This prevents re-processing on future scans.

## Checklist Format

For quick manual execution without loading the full operation:

```
Session-End Review Checklist:

1. [ ] Run: scan-feedback.sh ~/src/work/<project> --verbose
2. [ ] For each entry, classify: skill-update | new-script | tool-gap
3. [ ] Apply skill updates (edit docs, add to reference)
4. [ ] Create simple scripts (< 50 lines)
5. [ ] File tool gaps (issue or enhancement spec)
6. [ ] Update command-simplification.md with new patterns
7. [ ] Mark FEEDBACK.md files as reviewed
```

## Error Handling

| Condition | Behavior |
|-----------|----------|
| No FEEDBACK.md files | Report "No feedback to review" and stop |
| FEEDBACK.md exists but empty | Skip, report "present but empty" |
| Already-reviewed FEEDBACK.md | Skip (check for `<!-- Reviewed:` marker) |
| Ambiguous classification | Default to tool-gap (safest — defers action) |
