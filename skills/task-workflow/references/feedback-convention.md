# FEEDBACK.md Convention

Agents record command friction, tool gaps, and repeated patterns in FEEDBACK.md during work sessions. These entries feed into the lessons-learned skill for triage and improvement.

## When to Write

Agents should append to FEEDBACK.md when they encounter:

- **Command friction**: A task required a complex shell command when a simpler alternative should exist
- **Missing tool capability**: A tool (coord CLI, gh, etc.) lacks a flag or subcommand that would simplify a common operation
- **Repeated pattern**: The same multi-step operation was performed 2+ times in a session

**When NOT to write**:
- The command is necessarily complex (see `self-improvement/references/command-pattern-catalog.md`)
- The friction is task-specific and won't recur
- The pattern is already documented as a known gap

## File Location

FEEDBACK.md lives in the workspace root (alongside DESIGN.md and CLAUDE.md). The template is created during workspace setup from `templates/FEEDBACK.md.tmpl`.

## Entry Format

### Command Friction

```markdown
- **pattern**: What data/operation was needed
  - **workaround**: What was actually run (the complex command)
  - **suggestion**: Simpler alternative — script, tool flag, or skill update
  - **classification**: tool-gap | script-gap | skill-gap
```

### Missing Tool Capabilities

```markdown
- **tool**: Tool name (e.g., coord CLI, gh, git)
  - **need**: What capability is missing
  - **current**: How agents work around it today
```

### Repeated Patterns

```markdown
- **pattern**: Description of the repeated operation
  - **frequency**: How often it occurs (this session)
  - **suggestion**: Capture as script or skill operation
```

## Lifecycle

1. **Creation**: Workspace setup copies FEEDBACK.md.tmpl to workspace root
2. **Population**: Agent appends entries during the session as friction is encountered
3. **Scanning**: `scan-feedback.sh` aggregates entries across workspaces
4. **Triage**: Lessons-learned skill reads FEEDBACK.md during retrospective (Phase 1) and surfaces entries as problems for discussion
5. **Action**: Recommendations from lessons-learned feed into self-improvement skill

## Integration with Lessons-Learned

The lessons-learned skill's single-session analysis reads FEEDBACK.md from the current workspace as a supplementary input to Phase 1 (Surface Problems). Entries are presented alongside conversation-derived problems. This ensures command friction captured during implementation is not lost when the session ends.

## Integration with Command Pattern Catalog

When triaging feedback entries, cross-reference against `self-improvement/references/command-pattern-catalog.md`:
- If the pattern is listed as "necessarily complex" — close the entry with a note
- If the pattern is listed as "simplifiable" — the suggestion should reference the documented alternative
- If the pattern is new — add it to the catalog as part of the improvement cycle

## Scanning

Use `scan-feedback.sh` to aggregate feedback across workspaces:

```bash
scan-feedback.sh ~/src/work          # summary counts
scan-feedback.sh ~/src/work --verbose # full entry content
```

Output format: `<workspace>: <N> entries (friction:<N> tools:<N> patterns:<N>)`
