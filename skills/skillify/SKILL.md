---
name: skillify
description: Fast-capture entrypoint for turning a workflow just performed in this conversation into a skill. Reads back over the recent turns, drafts a lite SKILL.md (trigger description + steps + edge cases), and confirms with the user before writing anything. Hands off to skill-creator for the full interview/eval/benchmark loop only when the pattern warrants that investment. Use when the user says "skillify this," "capture this pattern," "turn this into a skill," "make this repeatable," or similar — this is the terse trigger for a two-minute capture, not the heavyweight skill-creator interview.
allowed-tools:
  - Read
  - Write
  - Edit
  - AskUserQuestion
version: 1.0.0
---

# skillify — fast-capture entrypoint

`skill-creator` already has everything needed to capture a workflow from
conversation history (its "Capture Intent" step) and a lite path for when
formal evals aren't warranted (its "just vibe with me" escape hatch). What's
missing is a one-word trigger that jumps straight there without first
explaining to skill-creator's full interview flow that this is a quick
capture, not a from-scratch skill design session.

`skillify` is that trigger. It is deliberately **thin**: draft, confirm,
write, hand off. It does not run evals, benchmark variance, or reimplement
any part of skill-creator's interview loop. If you catch yourself doing that
inside this skill, stop — that logic belongs in skill-creator, not here.

## When this fires

- "skillify this"
- "capture this pattern"
- "turn this into a skill"
- "make this repeatable" / "we'll want to do this again"
- Any moment where the user points at something just done in this session
  and asks for it to become a reusable skill

## What it does

1. **Extract the pattern from conversation history.** Look back over the
   turns that cover the workflow being referenced (usually the last 10-30
   turns, or however far back the user points). Identify:
   - The trigger: what the user said or the situation that kicked this off
   - The steps actually taken: tool calls, decision points, any corrections
     the user made along the way
   - Inputs consumed and the output produced
   - Anything that varied by judgment rather than a fixed rule (a candidate
     edge case)

2. **Draft a SKILL.md** — don't write it to disk yet:
   - `name`: short, kebab-case, matching the pattern's action
   - `description`: trigger phrases plus what it does, specific and a
     little "pushy" (skill-creator's term — bias toward firing rather than
     under-triggering)
   - `version: 1.0.0` for a new skill
   - `allowed-tools`: only the tools the extracted pattern actually used
   - Body: numbered steps of the workflow, in imperative form
   - An explicit **Edge Cases** section listing anything the history
     couldn't resolve — gaps to ask the user about, not guesses to bake in
     silently

3. **Show the draft and confirm before writing.** This is the safety step —
   never skip it. If the user wants changes, iterate on the draft in
   conversation. Only write to disk once they say to proceed.

4. **Write and register.** Once confirmed, write to
   `skills/<name>/SKILL.md` in the target plugin. If the target is this
   `pfeff/claude-skills` marketplace's `mbp` plugin, see "Registration"
   below — a skill directory alone does **not** make it resolvable as a
   slash command. For any other repo, check how a recently merged sibling
   skill was wired in before assuming the same shape applies.

5. **Hand off to skill-creator when the pattern warrants it.** A pattern
   warrants the fuller loop when it has real edge cases, ambiguous
   triggering, or the user wants it tested at scale before trusting it.
   Say so explicitly and let the user decide whether to continue into
   skill-creator's interview/eval/benchmark loop now or later. Skip the
   handoff for a genuinely trivial one-off — the drafted SKILL.md from step
   2 is often enough on its own.

## Registration (this marketplace)

Adding a skill directory under `skills/` is not sufficient for it to
resolve as a slash command in this repo. It must also be added to the
`skills` array of the `mbp` plugin entry in
`.claude-plugin/marketplace.json`, with `metadata.version` there and
`version` in `.claude-plugin/plugin.json` both bumped (minor bump for a new
skill, matching the pattern used when `kb-capture`/`kb-compile`/`kb-lint`
were added). Skipping this step is a real failure mode in this repo:
PR #133 had to retroactively register six skill directories that had sat
on disk for a while with no entry in that array, so none of them resolved
as slash commands despite looking complete.

## What this is NOT

- Not a reimplementation of skill-creator's interview, eval-writing, or
  benchmarking — hand off for that.
- Not a place to accumulate skill-authoring best practices — those live in
  skill-creator's own references.
- Not a bypass of the confirm-before-write step, even for "obviously fine"
  drafts.

## See also

- `skill-creator` (vendored, not owned by this marketplace) — the full
  draft → test → benchmark → iterate loop
- `lessons-learned` — retrospective analysis of what went wrong; use that
  when the goal is diagnosing a problem, not capturing a working pattern
