---
name: prose-mention-fixture
description: "Fixture (c): a non-mandatory prose mention of an undeclared tool must not fail (R4)."
allowed-tools:
  - Bash
  - Read
version: 1.0.0
---

# prose-mention-fixture

## Background

Some environments also expose an Agent capability for dispatching
sub-agents, and other skills in this collection use it for fan-out work.
This skill does not need it and never asks for it in its steps.

## Steps

### 1. Gather context

Read the PR diff with Bash.

### 2. Summarize

Summarize the findings and stop. No further tools are needed here.
