---
name: all-declared-fixture
description: "Fixture (b): every mandatory-step tool reference is declared in allowed-tools."
allowed-tools:
  - Bash
  - Read
  - Agent
version: 1.0.0
---

# all-declared-fixture

## Steps

### 1. Gather context

Read the PR diff with Bash.

### 2. Dispatch a reviewer

This step MUST invoke the Agent tool to grade the work product in an
independent context before recording a verdict.
