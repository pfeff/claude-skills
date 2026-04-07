---
name: guardian-sync
description: Synchronize Guardian project documentation and traceability. Use when regenerating TRACEABILITY.md, validating requirement coverage, or adding new requirements to the project.
allowed-tools:
  - Read
  - Write
  - Bash
  - Edit
  - Grep
  - Glob
allowed-prompts:
  - tool: Bash
    prompt: run gh project commands
  - tool: Bash
    prompt: run gh issue commands
  - tool: Bash
    prompt: run grep commands
version: 1.2.0
---

# Guardian Sync

Manage Guardian project documentation across repositories.

## Overview

The Guardian project uses a documentation architecture with:
- **Meta-repository** (`pfeff/guardian`): Central docs (PROJECT.md, REQUIREMENTS.md, ARCHITECTURE.md, TRACEABILITY.md)
- **GitHub Project #4**: Task tracking with custom fields (OKR, Requirement ID, Architecture Component, Phase)
- **Participating repos**: agent-orchestrator, cursor-rules with CLAUDE.md context

## Operations

### 1. Sync Traceability Matrix

Regenerate TRACEABILITY.md from GitHub Project data.

**When**: After issue updates, requirement changes, or on demand

**Implementation**: Load `operations/sync-traceability.md`

**Quick summary**: Query GitHub Project #4, generate matrix mapping OKRs → Requirements → Issues → Status

### 2. Validate Coverage

Find gaps between requirements and implementation.

**When**: Before releases, periodically, or when reviewing project health

**Implementation**: Load `operations/validate-coverage.md`

**Quick summary**: Compare REQUIREMENTS.md requirement IDs against GitHub Project, report unlinked items

### 3. Add Requirement

Add a new requirement with proper ID and cross-references.

**When**: New requirement identified during planning or development

**Implementation**: Load `operations/add-requirement.md`

**Quick summary**: Generate ID, add to REQUIREMENTS.md, optionally create issue and update ARCHITECTURE.md

## Requirement ID Convention

Format: `{PROJECT}-{CATEGORY}-{NUMBER}`

| Prefix | Repository |
|--------|------------|
| AO | agent-orchestrator |
| CR | cursor-rules |
| GN | guardian (cross-cutting) |

| Category | Meaning |
|----------|---------|
| CORE | Core component |
| AGENT | Agent/backend |
| SKILL | Skills system |
| SEC | Security |
| INT | Integration |
| OBS | Observability |
| NFR | Non-functional requirement |

Example: `CR-SKILL-01` = cursor-rules, skill category, requirement 1

## Paths

| Resource | Path |
|----------|------|
| Guardian repo | `~/src/github/pfeff/guardian` |
| REQUIREMENTS.md | `~/src/github/pfeff/guardian/REQUIREMENTS.md` |
| ARCHITECTURE.md | `~/src/github/pfeff/guardian/ARCHITECTURE.md` |
| TRACEABILITY.md | `~/src/github/pfeff/guardian/TRACEABILITY.md` |
| Scripts | `~/src/github/pfeff/guardian/scripts/` |

## Progressive Disclosure

Load only what you need:

**References** (always available):
- `references/project-field-ids.md` - Cached Project #4 field IDs and single-select option IDs

**Operations** (load on-demand):
- `operations/sync-traceability.md` - Regenerate traceability matrix
- `operations/validate-coverage.md` - Find coverage gaps
- `operations/add-requirement.md` - Add new requirement with ID

## Workflow Integration

This skill supports the Guardian documentation workflow:

1. **Adding requirements**: Use `add-requirement` operation
2. **Creating issues**: Link to requirement ID in GitHub Project custom field
3. **Syncing matrix**: Run after issue updates to regenerate TRACEABILITY.md
4. **Validating**: Run before releases to ensure complete traceability
