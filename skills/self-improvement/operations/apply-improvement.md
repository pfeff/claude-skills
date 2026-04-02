# Apply Improvement Operation

**When**: User requests `/self-improvement REC-XXX --apply`

## Purpose

Apply proposed changes with explicit user confirmation and update source lessons learned file to maintain traceability.

## Execution

### Step 1: Load or Generate Proposal

If not already proposed, run propose-changes first:

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/self-improvement/operations/propose-changes.md")
```

Ensure we have:
- Complete diff for each file
- Target file paths
- Line numbers for modifications

### Step 2: Display Confirmation Request

```markdown
## Ready to Apply REC-{id}: {title}

### Changes Summary

| File | Change | Lines |
|------|--------|-------|
| `{path1}` | {type} | +{add}/-{del} |
| `{path2}` | {type} | +{add}/-{del} |

### Full Changes

[Display complete diffs from proposal]

### Post-Apply Actions

1. Bump skill version and update CHANGELOG.md (if skill files modified)
2. Update `{source_file}` to mark REC-{id} as implemented
3. Add `<!-- IMPLEMENTED: REC-{id} -->` marker to modified files
```

### Step 3: Request User Confirmation

```
AskUserQuestion(
  questions: [{
    question: "Apply these changes to implement REC-{id}?",
    header: "Confirm",
    options: [
      { label: "Apply changes", description: "Write changes to files and mark as implemented" },
      { label: "Dry run only", description: "Show what would happen without writing" },
      { label: "Cancel", description: "Abort without changes" }
    ],
    multiSelect: false
  }]
)
```

### Step 4: Determine Delivery Method

For each target file, resolve symlinks and determine whether changes should be submitted via PR or applied directly.

```bash
RESOLVED=$(realpath "{target_file}")
REPO_ROOT=$(git -C "$(dirname "$RESOLVED")" rev-parse --show-toplevel 2>/dev/null)
```

**Routing rule**: If `$REPO_ROOT` is under `~/src/github/pfeff/`, use the **PR workflow** (Step 5a). Otherwise, use **direct edit** (Step 5b).

Group all target files by their resolved repository. A single recommendation may produce both PR and direct-edit deliveries if it touches files in different locations.

### Step 5a: PR Workflow (pfeff repos)

For each pfeff repository with changes:

**1. Create branch**

```bash
git -C "{repo_root}" checkout -b "self-improvement/REC-{id}"
```

**2. Apply edits and traceability markers**

Same `Edit()` calls as Step 5b, but targeting the resolved paths within the repo. Also add traceability markers (Step 6) to these files now, before committing — they'll be included in the PR.

**3. Stage, commit, and push**

Use the git skill's commit operation (`skills/git/operations/commit.md`) with:
- type: `feat`
- message: `implement REC-{id}: {title}`

Then push:
```bash
git -C "{repo_root}" push -u origin "self-improvement/REC-{id}"
```

**4. Create PR**

Use the `/gh-pr-create` command process to create a template-aware PR:

1. Read `.github/PULL_REQUEST_TEMPLATE.md` from the repo (if it exists)
2. Populate template sections with context:
   - **Summary**: "Implements self-improvement recommendation REC-{id}. {recommendation_summary}"
   - **Requirement**: REC-{id}
   - **Issue**: Source lessons file reference
   - **Changes**: Files modified by this recommendation
3. Fall back to freeform body if no template exists:
   ```bash
   gh pr create \
     --repo "pfeff/{repo_name}" \
     --title "feat: implement REC-{id}: {title}" \
     --body "$(cat <<'EOF'
   ## Summary

   Implements self-improvement recommendation REC-{id}.

   {recommendation_summary}

   ## Source

   - Lessons file: `{source_lessons_file}`
   - Recommendation: REC-{id}: {title}
   EOF
   )"
   ```

Record the PR URL for use in Steps 7 and 9.

**5. Clean up**

Return to the original branch:
```bash
git -C "{repo_root}" checkout -
```

### Step 5b: Direct Edit (non-pfeff files)

**For each file modification**:

```
Edit(
  file_path: "{target_file}",
  old_string: "{original_content}",
  new_string: "{new_content}"
)
```

Or for new sections:
```
Edit(
  file_path: "{target_file}",
  old_string: "{anchor_content}",
  new_string: "{anchor_content}\n\n{new_content}"
)
```

### Step 5c: Version Management (skill changes only)

After applying edits (Step 5a or 5b), check if any modified file is within a skill directory (`skills/*/`). If so, bump the skill version and update its changelog.

**1. Detect affected skills**

For each modified file, check if its path matches `skills/{skill-name}/`:
```
# Extract skill name from path
# e.g., skills/task-workflow/operations/create-workspace.md → task-workflow
```

Deduplicate — if multiple files in the same skill were modified, bump version once.

**2. Read current version**

```
Read(file_path: "skills/{skill-name}/SKILL.md")
```

Extract `version:` from YAML frontmatter.

**3. Determine version bump**

| Change Type | Bump | Example |
|-------------|------|---------|
| Bug fix, wording change, minor tweak | Patch (x.y.Z) | 1.0.0 → 1.0.1 |
| New capability, new operation, enhanced behavior | Minor (x.Y.0) | 1.0.0 → 1.1.0 |
| Breaking change to skill interface | Major (X.0.0) | 1.0.0 → 2.0.0 |

Default to **patch** unless the recommendation clearly adds new functionality.

**4. Update SKILL.md version**

```
Edit(
  file_path: "skills/{skill-name}/SKILL.md",
  old_string: "version: {old_version}",
  new_string: "version: {new_version}"
)
```

**5. Append CHANGELOG.md entry**

```
Edit(
  file_path: "skills/{skill-name}/CHANGELOG.md",
  old_string: "## [{previous_version}]",
  new_string: "## [{new_version}] - {YYYY-MM-DD}\n\n### Changed\n- {change_description}\n\n**Reasoning**: {recommendation_title} — {why_this_change_improves_the_skill}. Source: REC-{id} from {source_lessons_file}.\n\n## [{previous_version}]"
)
```

**Note for PR workflow (Step 5a)**: Include version bump and changelog update in the same commit before pushing. These files should be staged alongside the other changes.

### Step 6: Add Traceability Markers (direct-edit files only)

For files delivered via direct edit (Step 5b), add implementation marker as a comment near the change. PR-delivered files already have markers included in the commit (Step 5a.2).

For markdown files:
```markdown
<!-- IMPLEMENTED: REC-{id} - {title} -->
```

For shell scripts:
```bash
# IMPLEMENTED: REC-{id} - {title}
```

### Step 7: Update Source Lessons Learned File

Locate the action items section in source file and mark based on delivery method.

**When PR workflow was used** (Step 5a):

```
Edit(
  file_path: "{source_lessons_file}",
  old_string: "- [ ] REC-{id}",
  new_string: "- [~] REC-{id} (PR submitted {date}: {pr_url})"
)
```

If no checkbox exists:

```
Edit(
  file_path: "{source_lessons_file}",
  old_string: "#### REC-{id}: {title}",
  new_string: "#### REC-{id}: {title} 🔀 PR SUBMITTED\n\n**PR**: {pr_url} ({date})"
)
```

**When direct edit was used** (Step 5b):

```
Edit(
  file_path: "{source_lessons_file}",
  old_string: "- [ ] REC-{id}",
  new_string: "- [x] REC-{id} (implemented {date})"
)
```

If no checkbox exists:

```
Edit(
  file_path: "{source_lessons_file}",
  old_string: "#### REC-{id}: {title}",
  new_string: "#### REC-{id}: {title} ✅ IMPLEMENTED\n\n**Implemented**: {date}"
)
```

### Step 8: Complete Associated Task (if exists)

Search for tasks containing this REC-ID and mark as completed:

**8a. Query Task List**

```
TaskList
```

**8b. Search for Associated Task**

Look for tasks where:
- `subject` or `description` contains `REC-{id}`, OR
- `metadata.recId` equals `REC-{id}`

**8c. Mark Task Complete and Store Metadata**

If a matching task is found:

```
TaskUpdate(
  taskId: "{matching_task_id}",
  status: "completed",
  metadata: {
    recId: "REC-{id}",
    sourceFile: "{source_lessons_file}",
    implementedAt: "{ISO_date}"
  }
)
```

This stores the source Obsidian file path in task metadata for reverse lookup.

**8d. Log Result**

- **Task found**: "Associated task #{id} marked complete (source: {sourceFile})"
- **No task found**: Log (do not fail): "No associated task found for REC-{id}"

### Step 9: Report Results

```markdown
## Applied REC-{id}: {title}

### Changes Made

| File | Status | Delivery | Details |
|------|--------|----------|---------|
| `{path1}` | ✅ Applied | Direct | {change_summary} |
| `{path2}` | ✅ PR submitted | PR {pr_url} | {change_summary} |
| `{source_file}` | ✅ Updated | Direct | Marked as implemented/PR submitted |

### Version Updates

| Skill | Old Version | New Version |
|-------|-------------|-------------|
| `{skill-name}` | {old_version} | {new_version} |

### Task Integration

| Item | Status |
|------|--------|
| Source lessons file | Marked as implemented / PR submitted |
| Task #{task_id} | Completed (metadata updated) |

### Verification

**Direct edits**: Applied and active immediately. Review modified files and test affected functionality.

**PR-submitted changes**: Pending merge. Review and approve the PR(s) listed above before changes take effect.

### Next Recommendations

{List next pending recommendations from scan}
```

## Dry Run Mode

When `--dry-run` is specified:

1. Display all proposed changes
2. Show what files would be modified
3. Show traceability updates that would occur
4. **Do not write any files**

Output:
```markdown
## Dry Run: REC-{id}

### Would Apply

[Full diffs]

### Would Update

- `{source_file}`: Mark REC-{id} as implemented

### No files were modified (dry run mode)

To apply for real, run: `/self-improvement REC-{id} --apply`
```

## Rollback Support

Before applying changes, note original content for potential rollback:

```markdown
### Rollback Information

If needed, restore original content:

**{path1}**:
```
{original_content}
```

**{path2}**:
```
{original_content}
```
```

## Error Handling

**Edit fails (content mismatch)**:
```
Failed to apply changes to {file}.

Reason: Target content has changed since proposal was generated.

Options:
1. Re-run `/self-improvement REC-{id} --propose` to regenerate
2. Apply changes manually using the diff above
```

**File not writable**:
```
Cannot write to {file}: Permission denied

Check file permissions and try again.
```

**Partial success**:
```
Partial application of REC-{id}:

| File | Status |
|------|--------|
| `{path1}` | ✅ Applied |
| `{path2}` | ❌ Failed: {reason} |

Some changes applied. Manual intervention needed for failed files.
```

**User cancels**:
```
Application cancelled. No changes made.

The proposal is still available. Re-run `/self-improvement REC-{id} --apply` when ready.
```

## Batch Mode

When processing multiple recommendations (`--batch`):

1. List all recommendations to be processed
2. Process each sequentially
3. Request confirmation for each (unless `--yes` flag)
4. Report aggregate results

```markdown
## Batch Apply Results

| REC-ID | Status | Files Changed |
|--------|--------|---------------|
| REC-001 | ✅ Applied | 2 |
| REC-003 | ✅ Applied | 1 |
| REC-007 | ⏭️ Skipped | User cancelled |

**Total**: 2 applied, 1 skipped, 0 failed
```
