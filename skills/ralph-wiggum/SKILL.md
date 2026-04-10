---
name: ralph-wiggum
description: Scaffold a project for the Ralph Wiggum autonomous control loop. Use when setting up a new project for autonomous iteration, creating loop configuration files, or preparing specs for AI-driven development. Supports single-repo and multi-repo workspaces.
allowed-tools:
  - Read
  - Write
  - Glob
  - AskUserQuestion
version: 1.4.0
---

# Ralph Wiggum Project Scaffolding

Scaffolds the files needed to run a Ralph Wiggum autonomous control loop on a project. Supports both single-repo projects and multi-repo workspaces.

## Overview

The Ralph Wiggum pattern is a `while true` bash loop that repeatedly feeds the same prompt to Claude Code. Between iterations, files and git history persist while context resets fresh. The agent sees its own previous work and iteratively improves until backpressure gates (tests, lint, build) all pass.

**Core philosophy**: Backpressure over direction—engineer environments where wrong outputs get rejected automatically.

### Multi-Repo Support

Ralph can operate on workspaces containing multiple git repositories. In multi-repo mode:
- A workspace manifest (`.ralph/workspace.md`) lists all repos with paths and gate configs
- Each repo has its own `.ralph/gates.md` with repo-specific gate commands
- Tasks in `PLAN.md` are annotated with `[repo-name]` prefix to target specific repos
- Branches, commits, and PRs are managed per-repo
- The loop runs from the workspace root directory

## Operations

### 1. Gather Requirements
**When**: Starting scaffolding, need project info
**Implementation**: Load `operations/gather-requirements.md`
**Quick summary**: Detects single-repo or multi-repo workspace, collects language and gate commands (per-repo in multi-repo mode), and optional external service dependencies via AskUserQuestion.

### 2. Scaffold Project
**When**: Requirements gathered, ready to create files
**Implementation**: Load `operations/scaffold-project.md`
**Quick summary**: Checks for existing files, creates from templates with user-provided values. In multi-repo mode, creates workspace manifest and per-repo gate files. Shows next steps.

## Prerequisites

- Current directory is a git repository, or contains subdirectories that are git repos (for multi-repo mode)
- `Write` and `AskUserQuestion` tools available

## End-to-End Flow

When invoked, run operations sequentially:

### Input

- Working directory (scanned for git repos to detect workspace mode)
- User responses to AskUserQuestion prompts

### Sequence

```
1. gather-requirements → workspace_type, gate commands, optional services
2. scaffold-project(gathered_values) → created files list
```

### Output

- **Success**: All configuration files created. User shown file list and next steps (write specs, run plan, run build).
- **Partial**: Some files skipped (user chose to preserve existing). User shown which files were created vs skipped.

## Quick Reference

**Invoke skill**: User asks to "scaffold ralph wiggum", "set up autonomous loop", or "prepare project for ralph"

**Template location**: `skills/ralph-wiggum/templates/`

**Three-phase workflow**:
1. **Spec** - Human writes requirements in `specs/*.md`
2. **Plan** - Agent generates `PLAN.md` from specs
3. **Build** - Agent implements one task per iteration

**Backpressure gates**: Tests, lint, typecheck, and build must all pass before a task is complete.

**Workspace modes**:
- **Single-repo**: `.ralph/gates.md` at project root (original behavior)
- **Multi-repo**: `.ralph/workspace.md` at workspace root + per-repo `.ralph/gates.md`

## Progressive Disclosure

Load only what you need:

- `operations/gather-requirements.md` - Interactive requirements collection (detects workspace type)
- `operations/scaffold-project.md` - File creation from templates (supports both modes)
- `references/environment.md` - Pre-flight checks and prerequisites
- `templates/` - File generation templates (gates, services, specs, prompts, workspace)
- `scripts/` - Host-side runtime: `run-container.sh`, `loop.sh`, `lib.sh`, `setup-network.sh`, devcontainer config
