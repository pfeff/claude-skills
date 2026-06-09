---
title: "Extracting a public skill from a private repo with employer-specific code"
date: 2026-03-28
problem_type: best_practice
severity: medium
symptoms:
  - "Skill contains generic mechanics mixed with employer-specific integrations"
  - "Can't publish skill as open-source without leaking private code"
  - "Users want execution mechanics without org-specific dependencies"
tags: [migration, extraction, public-private-split, skill-refactoring, open-source]
root_cause: "Generic execution mechanics evolved alongside employer-specific integrations in a single repo"
module: task-workflow
repo: claude-skills
---

## Problem

A skill (task-workflow) contained both generic execution mechanics (auto-advance, validate-implementation, finish workflow, workspace management) and employer-specific integrations (org detection, secret fetching, Azure PAT, Jira, corporate-host paths) in the same repo. Publishing as a public plugin required clean separation without breaking the private repo's functionality.

## Solution

Systematic extraction following this pattern:

1. **Inventory**: Catalog every file (operations, scripts, templates, references) and classify as public or private
2. **Copy-then-scrub**: Copy files to the public repo, then audit each for employer-specific terms using grep with a comprehensive term list (`jira`, `azdevops`, `azure`, your corporate hostname, `1password`, `octopus`, your org slug, personal paths)
3. **Scrub categories**:
   - **Examples/URLs**: Replace org-specific GitHub URLs and repo names with generic placeholders (`user/repo`)
   - **Hardcoded conventions**: Parameterize or remove personal conventions (e.g., `/mbp/` branch infix)
   - **Env-specific features**: Remove entire sections that depend on org infrastructure (secret fetching, org detection, Obsidian symlinks)
   - **Templates**: Strip org-specific fields while keeping generic structure
4. **Cross-skill references**: Verify that references to other skills (git, review) point to skills already in the public repo
5. **Private repo update**: Add documentation noting the split; do not remove any files from private repo
6. **Automated validation**: Final grep audit of entire public skill directory for all known private terms

Key decisions:
- **Fork, don't share**: Each repo gets its own copy rather than sharing via imports. Prevents fragile cross-repo dependencies.
- **Superset in private**: The private repo retains all files (both generic and private). It can reference the public versions later but isn't forced to.
- **Conservative scrubbing**: When uncertain whether something is private, scrub it. False positives (over-scrubbing) are cheaper than leaks.

## Prevention

- When building new skills, separate generic mechanics from org-specific integrations from the start
- Use explicit parameters instead of environment inference (e.g., pass `--epic` rather than detecting org from hostname)
- Keep a running list of private terms/patterns to grep for during CI or pre-commit
