---
name: planning-workflow
description: Plan implementation tasks by validating the problem, reconciling DESIGN.md, searching past solutions, calibrating research depth, analyzing edge cases via SpecFlow, and generating living plans with checkable criteria. Use when starting implementation planning for a task or issue.
allowed-tools:
  - Read
  - Edit
  - Grep
  - Glob
  - Write
  - AskUserQuestion
  - WebSearch
  - WebFetch
version: 1.0.0
---

# Planning Workflow

Structured planning that validates the problem and mines past knowledge before investing in new research. Produces living plans with checkable acceptance criteria.

## Overview

The planning workflow runs these phases in order:

1. **Problem validation** — validate who, what pain, current workflow, and success criteria; for document tasks, gate on content correctness before proceeding
2. **DESIGN.md reconciliation** — compare workspace DESIGN.md against problem validation and repo docs
3. **Solution search** — search `docs/solutions/` for relevant prior solutions
4. **Research gating** — decide if external research is needed based on risk
5. **SpecFlow analysis** — walk user flows to find edge cases
6. **Detail level selection** — choose plan depth based on complexity
7. **Plan generation** — produce markdown plan with checkable criteria

## Operations

### 1. Problem Validation

**When**: Always — first step of any planning session, before solution search.

**Implementation**: Load `operations/problem-validation.md`

**Quick summary**: Scans the task description for four dimensions (user, pain, current workflow, success criteria). Extracts what's covered, infers what's implied, and interviews the user for anything missing. Then classifies the task as document/plan vs. code implementation using keyword heuristics (with confidence fallback to user). For document tasks, presents an interactive content gate — "Content is correct" proceeds; "Needs revision" stops the workflow. Produces a "Problem Validation" section that grounds all downstream phases.

### 2. DESIGN.md Reconciliation

**When**: After problem validation — reconciles workspace DESIGN.md before solution search.

**Implementation**: Load `operations/designmd-reconciliation.md`

**Quick summary**: Two-layer validation of workspace DESIGN.md against problem validation findings and repo-level docs (CLAUDE.md, docs/). Surfaces contradictions and gaps for user approval. Extensions can add additional reconciliation layers (e.g., strategic doc validation). Produces a "DESIGN.md Reconciliation" section for the plan.

### 3. Solution Search

**When**: After DESIGN.md reconciliation — searches for relevant prior solutions.

**Implementation**: Load `operations/solution-search.md`

**Quick summary**: Grep-searches `docs/solutions/` frontmatter (tags, symptoms, module, component) for relevant prior solutions. Always loads `critical-patterns.md`. Surfaces findings as "Prior Solutions" context for downstream phases.

### 4. Research Gating

**When**: After solution search — decides whether to invoke external research.

**Implementation**: Load `operations/research-gating.md`

**Quick summary**: Classifies task risk (high/low/uncertain), evaluates local knowledge strength, and decides whether external research is needed. High-risk topics always get external research; low-risk with strong local knowledge skips it.

### 5. SpecFlow Analysis

**When**: After research, before finalizing plan.

**Implementation**: Load `operations/specflow-analysis.md`

**Quick summary**: Systematically walks all user/operational flows, maps decision points, enumerates error states and edge cases, identifies specification gaps, and generates acceptance criteria from findings.

### 6. Detail Level Selection

**When**: After SpecFlow analysis — determines plan structure.

**Implementation**: Load `operations/detail-level.md`

**Quick summary**: Scores complexity signals (flows, edge cases, spec gaps, files affected) and selects Minimal, More, or A Lot detail level. Determines which sections the plan generator includes.

### 7. Plan Generation

**When**: Final phase — assembles the plan document.

**Implementation**: Load `operations/plan-generation.md`

**Quick summary**: Generates PLAN.md using the selected detail level template, populated with findings from all prior phases. Acceptance criteria use `[ ]`/`[x]` checkboxes for progress tracking during implementation. Standard documentation and demo criteria are always included (with deduplication against task-specific criteria).

## End-to-End Flow

When invoked, run all phases sequentially. Each phase produces a section that feeds into the next.

### Input

- Task description (from issue, DESIGN.md, or user input)
- Repository context (working directory, available files)

### Phase Pipeline

```
Task Description
      │
      ▼
┌─────────────┐
│ 1. Problem   │──→ Problem Validation section
│  Validation  │     (user, pain, current workflow, success criteria)
│              │     + task type classification
└─────────────┘
      │
      ├── if document task → Interactive Content Gate
      │     ├── "Content is correct" → continue
      │     └── "Needs revision" → STOP (revise and re-run)
      │
      ▼
┌─────────────┐
│ 2. DESIGN.md │──→ DESIGN.md Reconciliation section
│  Reconcile   │     (2-layer check: validation, repo docs)
└─────────────┘
      │
      ▼
┌─────────────┐
│ 3. Solution  │──→ Prior Solutions section
│    Search    │     (matched solutions + critical patterns)
└─────────────┘
      │
      ▼
┌─────────────┐
│ 4. Research  │──→ Research Decision section
│    Gating    │     (risk category + local knowledge → skip/research)
└─────────────┘
      │
      ├── if "research externally" → conduct web search / doc lookup
      │
      ▼
┌─────────────┐
│ 5. SpecFlow  │──→ SpecFlow Analysis section
│   Analysis   │     (flows, edge cases, gaps, generated criteria)
└─────────────┘
      │
      ▼
┌─────────────┐
│ 6. Detail    │──→ Plan Detail Level section
│    Level     │     (Minimal / More / A Lot)
└─────────────┘
      │
      ▼
┌─────────────┐
│ 7. Plan      │──→ PLAN.md
│  Generation  │     (living plan with checkable criteria)
└─────────────┘
```

### Output

`PLAN.md` written to the workspace root, containing:
- Plan body (sections per detail level)
- Acceptance criteria with `[ ]` checkboxes
- Planning context appendix (outputs from phases 1-6)

## Common Patterns

**Query term extraction**: Derive search terms from the issue title, description, error messages, and component names. Use 3-5 specific terms rather than broad keywords.

**Graceful degradation**: Every phase handles missing files/directories without failing. A repo with no `docs/solutions/` simply skips the search and proceeds.

## Progressive Disclosure

Load only what you need:

- `operations/problem-validation.md` — Problem validation, user interview, task type classification, and interactive content gate
- `operations/designmd-reconciliation.md` — DESIGN.md two-layer reconciliation
- `operations/solution-search.md` — Solution search implementation details
- `operations/research-gating.md` — Research gating decision logic
- `operations/specflow-analysis.md` — SpecFlow edge case analysis
- `operations/detail-level.md` — Detail level selection logic
- `operations/plan-generation.md` — Plan generation with checkable criteria
