# Recommendation Categories Reference

Maps recommendation categories from lessons learned to improvement targets in the skills system.

## Category Mapping

### Workflow

**Description**: Improvements to how operations are executed within skills

**Primary Targets**:
- `skills/*/operations/*.md` - Operation implementation files

**Secondary Targets**:
- `skills/*/SKILL.md` - Skill definition (operation descriptions)
- `~/.claude/workflows/core/*.md` - Core workflow definitions

**Common Improvements**:
- Adding parallel execution patterns
- Improving step ordering
- Adding error handling
- Optimizing tool usage sequences

**Example Recommendations**:
- "Add parallel file reading in workspace creation"
- "Reduce sequential Bash calls in git operations"

---

### Commands

**Description**: Enhancements to slash commands (user-facing interfaces)

**Primary Targets**:
- `~/.claude/commands/*.md` - Slash command definitions

**Secondary Targets**:
- Related skill's `SKILL.md` - If command invokes skill
- Related skill's operations - If command behavior changes

**Common Improvements**:
- Adding new options/flags
- Improving help text
- Adding argument validation
- Enhancing output formatting

**Example Recommendations**:
- "Add --verbose flag to /create-workspace"
- "Add category filter to /claude-skills:lessons-learned"

---

### Utilities

**Description**: Helper scripts and tools supporting skills

**Primary Targets**:
- `skills/*/scripts/*.sh` - Shell utility scripts
- `skills/*/scripts/*.py` - Python helper scripts

**Secondary Targets**:
- `operations/*.md` - Operations that use the utilities
- `references/*.md` - Documentation for utilities

**Common Improvements**:
- Performance optimizations
- Adding caching
- Improving error messages
- Adding new helper functions

**Example Recommendations**:
- "Cache git status results in workspace-locator.sh"
- "Add timeout handling to create-tmuxp-session.sh"

---

### Skills

**Description**: Direct improvements to skill definitions and structure

**Primary Targets**:
- `skills/*/SKILL.md` - Main skill definition file

**Secondary Targets**:
- `skills/*/operations/*.md` - All operations
- `skills/*/references/*.md` - Reference documentation

**Common Improvements**:
- Adding new operations
- Updating operation descriptions
- Improving progressive disclosure
- Adding integration points

**Example Recommendations**:
- "Add batch mode operation to task-workflow"
- "Improve error handling section in lessons-learned"

---

### Documentation

**Description**: Documentation improvements (usually not auto-implementable)

**Primary Targets**:
- `skills/*/references/*.md` - Reference documentation
- `skills/*/*.md` - Any markdown in skill directories

**Secondary Targets**:
- `~/.claude/CLAUDE.md` - Global instructions (rarely)

**Common Improvements**:
- Adding examples
- Clarifying instructions
- Updating outdated information
- Adding troubleshooting guides

**Note**: Documentation recommendations often require manual review to ensure accuracy.

**Example Recommendations**:
- "Add examples for parallel operation patterns"
- "Document workspace status conventions"

---

### User Practices

**Description**: Behavioral recommendations for users (not auto-implementable)

**Primary Targets**: None (user behavior change required)

**Action**: Flag for user awareness, do not attempt auto-implementation

**Example Recommendations**:
- "Run /claude-skills:lessons-learned at end of each session"
- "Use tmux for long-running tasks"

---

## Priority Mapping

| Priority | Auto-Implement | Characteristics |
|----------|---------------|-----------------|
| HIGH | Preferred | Clear target, measurable impact, low risk |
| MEDIUM | Suitable | Clear target, moderate complexity |
| LOW | With caution | May require more context or have side effects |

## Effort Mapping

| Effort | Expected Scope | Auto-Implementation |
|--------|----------------|---------------------|
| Quick (<30m) | Single file, small change | Highly suitable |
| Medium (30-120m) | 2-3 files, moderate change | Suitable with review |
| Complex (>2h) | Multiple files, architectural | Manual preferred |

## Target Path Resolution

### Skill Path Patterns

```
skills/{skill-name}/
├── SKILL.md                    # Skill definition (version in frontmatter)
├── CHANGELOG.md                # Version history with reasoning
├── operations/
│   └── {operation-name}.md     # Operation implementations
├── references/
│   └── {topic}.md              # Reference documentation
├── scripts/
│   └── {utility}.sh            # Shell utilities
└── templates/
    └── {name}.tmpl             # File templates
```

### Command Path Pattern

```
~/.claude/commands/{command-name}.md
```

### Workflow Path Pattern

```
~/.claude/workflows/core/{workflow-name}.md
```

## Search Strategy

When recommendation doesn't specify exact file:

1. **Keyword extraction**: Pull key terms from recommendation
2. **Category narrowing**: Use category to limit search scope
3. **Pattern matching**: Search for related patterns in target directories
4. **Context clues**: Use surrounding analysis for hints

Example:
- Recommendation: "Add caching to workspace discovery"
- Keywords: "caching", "workspace", "discovery"
- Category: Utilities -> search `scripts/`
- Pattern: `Grep(pattern: "workspace.*discover|find.*workspace")`
- Result: `skills/task-workflow/scripts/workspace-locator.sh`
