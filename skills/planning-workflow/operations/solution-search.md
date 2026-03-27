# Solution Search

Search `docs/solutions/` for relevant past solutions before planning. Surfaces prior knowledge to avoid redundant research and repeat mistakes.

## Parameters

- `query_terms` (required): Keywords describing the problem — extracted from issue title, description, or user input
- `solutions_path` (optional): Path to solutions directory. Defaults to `docs/solutions/` in the current repository root.

## Execution Steps

### 1. Check for solutions directory

```
Glob: pattern="docs/solutions/**/*.md"
```

If no `docs/solutions/` directory exists or no `.md` files found, report "No solutions directory found — skipping local knowledge search" and proceed to step 4.

### 2. Search frontmatter fields

Run grep searches against frontmatter fields for each query term. Search these fields in order of specificity:

**By tags** (most targeted):
```
Grep: pattern="tags:.*<term>" path="docs/solutions/" -i=true output_mode="content" -A=3
```

**By symptoms**:
```
Grep: pattern="symptoms:.*<term>" path="docs/solutions/" -i=true output_mode="content" -A=3
```

**By module**:
```
Grep: pattern="module:.*<term>" path="docs/solutions/" -i=true output_mode="files_with_matches"
```

**By component**:
```
Grep: pattern="component:.*<term>" path="docs/solutions/" -i=true output_mode="files_with_matches"
```

Collect unique file paths from all matches. Deduplicate before reading.

### 3. Read matched solutions

For each matched solution file (up to 5 most relevant):
```
Read: file_path="<matched_file>"
```

Extract from each:
- **Title** (from frontmatter)
- **Severity** (from frontmatter)
- **Root cause** (from frontmatter or Problem section)
- **Solution summary** (from Solution section)
- **Prevention guidance** (from Prevention section)

### 4. Load critical patterns

Always read critical patterns, regardless of search results:
```
Read: file_path="docs/solutions/patterns/critical-patterns.md"
```

If the file doesn't exist, skip silently.

### 5. Compile findings

Produce a summary section for the plan:

```markdown
## Prior Solutions

### Relevant Solutions Found
- **<title>** (<severity>) — <one-line summary of solution>
  - Root cause: <root_cause>
  - Prevention: <prevention summary>

### Critical Patterns
<content from critical-patterns.md, or "No critical patterns documented yet">

### Assessment
<brief statement: how much prior knowledge applies to this task>
```

If no solutions matched and no critical patterns exist, output:

```markdown
## Prior Solutions

No relevant prior solutions found. No critical patterns documented.
```

## Output

The compiled "Prior Solutions" section, ready to be included as context in the planning workflow. Downstream phases (research gating, plan generation) use this to calibrate depth.

## Error Handling

| Condition | Behavior |
|-----------|----------|
| `docs/solutions/` doesn't exist | Skip search, note absence, continue |
| `critical-patterns.md` doesn't exist | Skip, continue |
| No grep matches | Report "no matches", still load critical patterns |
| Too many matches (>10 files) | Take top 5 by severity (critical > high > medium > low) |
