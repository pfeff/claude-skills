---
name: undeclared-tool-fixture
description: "Fixture (a): a mandatory step invokes a tool absent from allowed-tools."
allowed-tools:
  - Bash
  - Read
version: 1.0.0
---

# undeclared-tool-fixture

## Steps

### 1. Gather context

Read the PR diff with Bash.

### 2. Dispatch a reviewer

This step MUST invoke the Agent tool to grade the work product in an
independent context before recording a verdict.
