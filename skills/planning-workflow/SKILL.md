---
name: planning-workflow
description: Plan implementation tasks by validating the problem, reconciling DESIGN.md, searching past solutions, calibrating research depth, analyzing edge cases via SpecFlow, and generating living plans with checkable criteria. Use when starting implementation planning for a task or issue.
allowed-tools:
  - Read
  - Edit
  - Grep
  - Glob
  - Write
  - Task
  - AskUserQuestion
  - WebSearch
  - WebFetch
  - EnterPlanMode
  - ExitPlanMode
  - TaskCreate
  - TaskList
version: 1.0.2
---

# Planning Workflow

Structured planning that validates the problem and mines past knowledge before investing in new research. Produces living plans with checkable acceptance criteria.

## Plan Mode Front-End

Plan Mode (`EnterPlanMode` → interactive drafting → `ExitPlanMode`) is the
interactive drafting front-end that brackets the phase pipeline below. The draft
is assembled **ephemerally** inside Plan Mode (no durable writes); only on user
approval does the **materialization** step write the durable `DESIGN.md`/`PLAN.md`
and seed native `TaskCreate`/`TaskList`. Plan Mode is ephemeral (it resets on
acceptEdits) — the durable docs and seeded native tasks remain authoritative.
See `operations/plan-mode-frontend.md`. If Plan Mode is unavailable, run the
pipeline directly and write durable artifacts as before.

## Overview

The planning workflow runs these phases in order:

1. **Problem validation** — validate who, what pain, current workflow, and success criteria; for document tasks, gate on content correctness before proceeding
2. **DESIGN.md reconciliation** — compare workspace DESIGN.md against problem validation, repo docs, and strategic docs
3. **Solution search** — QMD hybrid search over the Obsidian vault for relevant prior notes (DD4)
4. **Research gating** — decide if external research is needed based on risk
5. **SpecFlow analysis** — walk user flows to find edge cases and audit the layer each requirement belongs to
6. **Detail level selection** — choose plan depth based on complexity
7. **Plan generation** — produce markdown plan with checkable criteria
8. **ADR propagation** — propagate superseding decisions to strategic docs, issues, and project board

## Operations

### 1. Problem Validation

**When**: Always — first step of any planning session, before solution search.

**Implementation**: Load `operations/problem-validation.md`

**Quick summary**: Scans the task description for four dimensions (user, pain, current workflow, success criteria). Extracts what's covered, infers what's implied, and interviews the user for anything missing. Then classifies the task as document/plan vs. code implementation using keyword heuristics (with confidence fallback to user). For document tasks, presents an interactive content gate — "Content is correct" proceeds; "Needs revision" stops the workflow. Produces a "Problem Validation" section that grounds all downstream phases.

### 2. DESIGN.md Reconciliation

**When**: After problem validation — reconciles workspace DESIGN.md before solution search.

**Implementation**: Load `operations/designmd-reconciliation.md`

**Quick summary**: Three-layer validation of workspace DESIGN.md against problem validation findings, repo-level docs (CLAUDE.md, docs/), and strategic docs (strategic meta-repo REQUIREMENTS.md, ARCHITECTURE.md, PROJECT.md). Surfaces contradictions and gaps for user approval. Bidirectional conflict resolution for strategic docs — changes may flow down (update DESIGN.md) or up (flag strategic doc update). Produces a "DESIGN.md Reconciliation" section for the plan.

### 2a. Fast Path Gate

**When**: After DESIGN.md reconciliation — evaluates whether to skip phases 3-6.

**Implementation**: Load `operations/fast-path-gate.md`

**Quick summary**: Checks three deterministic criteria: (1) task has explicit, testable acceptance criteria, (2) task targets known, locatable code, (3) DESIGN.md reconciliation is clean (no unresolved contradictions). All three must pass for fast path. On fast path, skips directly to plan generation with Minimal detail level. On full path, continues to phase 3.

### 3. Solution Search

**When**: After fast path gate (full path only) — searches for relevant prior solutions.

**Implementation**: Load `operations/solution-search.md`

**Quick summary**: Delegates a QMD query (hybrid BM25 + vector + reranker + HyDE) against the configured vault collection to an out-of-context `Explore` subagent (Task tool, `subagent_type: Explore`), which follows `task-workflow/references/solution-search.md` for the canonical invocation and fail-open protocol and returns the compiled "Prior Solutions" section. The planning session consumes that section as context for downstream phases; it does not run `qmd` directly. Per DD4, no longer reads `docs/solutions/`.

### 4. Research Gating

**When**: After solution search — decides whether to invoke external research.

**Implementation**: Load `operations/research-gating.md`

**Quick summary**: Classifies task risk (high/low/uncertain), evaluates local knowledge strength, and decides whether external research is needed. High-risk topics always get external research; low-risk with strong local knowledge skips it.

### 5. SpecFlow Analysis

**When**: After research, before finalizing plan.

**Implementation**: Load `operations/specflow-analysis.md`

**Quick summary**: Systematically walks all user/operational flows, maps decision points, enumerates error states and edge cases, identifies specification gaps, audits where each requirement should run to catch layer mismatches before implementation, and generates acceptance criteria from findings.

### 6. Detail Level Selection

**When**: After SpecFlow analysis — determines plan structure.

**Implementation**: Load `operations/detail-level.md`

**Quick summary**: Scores complexity signals (flows, edge cases, spec gaps, files affected) and selects Minimal, More, or A Lot detail level. Determines which sections the plan generator includes.

### 7. Plan Generation

**When**: Final phase — assembles the plan document.

**Implementation**: Load `operations/plan-generation.md`

**Quick summary**: Generates PLAN.md using the selected detail level template, populated with findings from all prior phases. Acceptance criteria use `[ ]`/`[x]` checkboxes for progress tracking during implementation. Standard documentation and demo criteria are always included (with deduplication against task-specific criteria).

### 8. ADR Propagation

**When**: After plan generation — propagates superseding design decisions to downstream artifacts.

**Implementation**: Load `operations/adr-propagation.md`

**Quick summary**: Consumes upstream flags from DESIGN.md reconciliation. For strategic docs (PROJECT.md, REQUIREMENTS.md, ARCHITECTURE.md), proposes specific edits and applies with user approval. For GitHub issues and project board items, generates actionable checklist entries. Skips cleanly when no upstream flags exist.

## End-to-End Flow

When invoked, run all phases sequentially. Each phase produces a section that feeds into the next. After phase 2, a fast path gate may skip phases 3-6 for qualifying tasks (see "Fast Path" below).

### Input

- Task description (from issue, DESIGN.md, or user input)
- Repository context (working directory, available files)

### Phase Pipeline

When Plan Mode is available, `EnterPlanMode` wraps the pipeline (phases 1–7 draft
ephemerally), `ExitPlanMode` presents the assembled draft for approval, and the
materialization step writes durable `DESIGN.md`/`PLAN.md` + seeds native Tasks
(see `operations/plan-mode-frontend.md`).

```
EnterPlanMode  (read-only drafting; no durable writes)
      │
      ▼
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
│  Reconcile   │     (3-layer check: validation, repo docs, strategic docs)
└─────────────┘
      │
      ▼
┌─────────────┐
│ 2a. Fast     │──→ Fast Path Gate section
│  Path Gate   │     (criteria check: acceptance criteria + known code + low risk)
└─────────────┘
      │
      ├── all criteria pass → FAST PATH (skip to phase 7)
      │
      ▼ (any criterion fails → full path)
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
      │
      ▼
┌─────────────┐
│ 8. ADR       │──→ ADR Propagation section
│  Propagation │     (strategic doc edits + issue/board checklist)
└─────────────┘
      │
      ▼
ExitPlanMode  ──→ present assembled draft for approval
      │
      ▼ (approved)
MATERIALIZE   ──→ write durable DESIGN.md/PLAN.md (phase 7 step 5)
                  + seed native TaskCreate/TaskList from criteria
```

### Output

`PLAN.md` written to the workspace root, containing:
- Plan body (sections per detail level)
- Acceptance criteria with `[ ]` checkboxes
- Planning context appendix (outputs from phases 1-7)
- ADR propagation section (strategic doc changes applied + issue/board checklist)

## Fast Path

An alternative flow for tasks that don't benefit from phases 3-6. The fast path produces the same PLAN.md output format as the full path, using Minimal detail level.

### When It Applies

The fast path gate runs after phase 2 (DESIGN.md reconciliation) and checks three deterministic criteria. **All three must pass**:

1. **Explicit acceptance criteria** — the task description contains at least one testable, pass/fail statement
2. **Known code target** — the task targets files or modules that exist in the repo and can be located (via Glob/Grep)
3. **Low risk** — DESIGN.md reconciliation produced no unresolved contradictions

### What Gets Skipped

| Phase | Full path | Fast path |
|-------|-----------|-----------|
| 1. Problem validation | Runs | Runs |
| 2. DESIGN.md reconciliation | Runs | Runs |
| 2a. Fast path gate | Runs | Runs |
| 3. Solution search | Runs | Skipped |
| 4. Research gating | Runs | Skipped |
| 5. SpecFlow analysis | Runs | Skipped |
| 6. Detail level selection | Runs | Skipped (defaults to Minimal) |
| 7. Plan generation | Runs | Runs |

### Implementation

Load `operations/fast-path-gate.md` for criteria definitions and execution details.

Full path remains the default. The fast path gate evaluates criteria and routes automatically — no user decision required.

## Common Patterns

**Query term extraction**: Derive search terms from the issue title, description, error messages, and component names. Use 3-5 specific terms rather than broad keywords.

**Graceful degradation**: Every phase handles missing inputs without failing. If QMD is not installed or `$QMD_COLLECTION` is unset, solution-search logs and continues — planning never blocks on retrieval (see `task-workflow/references/solution-search.md`).

## Progressive Disclosure

Load only what you need:

- `operations/plan-mode-frontend.md` — Plan Mode front-end: `EnterPlanMode` → ephemeral drafting → `ExitPlanMode` → materialize durable docs + seed native Tasks
- `operations/problem-validation.md` — Problem validation, user interview, task type classification, and interactive content gate
- `operations/designmd-reconciliation.md` — DESIGN.md three-layer reconciliation
- `operations/fast-path-gate.md` — Fast path criteria evaluation and routing
- `operations/solution-search.md` — Solution search implementation details
- `operations/research-gating.md` — Research gating decision logic
- `operations/specflow-analysis.md` — SpecFlow edge case analysis
- `operations/detail-level.md` — Detail level selection logic
- `operations/plan-generation.md` — Plan generation with checkable criteria
- `operations/adr-propagation.md` — Post-ADR propagation to strategic docs, issues, and board
