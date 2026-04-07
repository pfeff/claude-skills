# Test Run: start-project (2026-03-15)

## Setup
- **Command**: `/start-project --issue pfeff/guardian#186 --repos agent-coordinator,cursor-rules`
- **Purpose**: Multi-purpose — advance Guardian, validate top-level objectives, validate updated workflow
- **Coordinator**: needs local deployment with persistence (bootstrap dependency)

## Observations

### 1. Big-batch questioning instead of conversational flow
- **Severity**: UX / workflow design
- **Where**: start-project.md Step 2, conversation rules (lines 66-76)
- **What happened**: Agent dumps all outstanding questions at once instead of having a natural dialogue
- **Root cause**: Rule on line 68: "Present all outstanding questions together — do not drip-feed one at a time"
- **Intent of original rule**: Ensure questions are asked with enough context for the user to answer well. Avoid context-free drip-feed where each question arrives without connection to prior answers.
- **Fix direction**: Balance between focus and context. Lead with what you learned, ask 1-2 focused questions that build on context, let answers shape follow-ups. The running spec table already provides the "big picture" — questions don't need to do that too. Avoid both extremes: dumping 5 questions at once, or asking one decontextualized question at a time.

### 2. Plan presented as monolithic wall of text
- **Severity**: UX / readability
- **Where**: start-project.md Step 5 (Present for Approval)
- **What happened**: Agent produced a single massive plan block — context, data model design, bootstrap steps, goal tree, key files, verification — all in one Claude Code "Plan" artifact. No conversation break between "here's what I understood" and "here's the decomposition".
- **Problem**: User can only accept/reject the whole thing. No opportunity to course-correct the framing before the agent invests in decomposition. The plan mixes project understanding (context, data model) with execution plan (goal tree, key files) — these should be separate approval gates.
- **Fix direction**: Split into phases with checkpoints: (1) present understanding + spec table, get confirmation; (2) present decomposition, get approval; (3) then create artifacts. The operation already defines these steps but the agent collapsed them.

### 3. TodoWrite fallback for bootstrap phase — acceptable
- **Severity**: Expected / not a bug
- **Where**: start-project.md Steps 7-9 (Register Tree, Create Directory, Transition to Execution)
- **What happened**: Agent created a TodoWrite task list instead of registering with the coordinator. AC isn't deployed yet — deploying it is the first phase of this project (chicken-egg).
- **Assessment**: TodoWrite is fine for the bootstrap phase. The workflow should explicitly handle this: when AC is unavailable, use TodoWrite to track bootstrap tasks, then register the remaining tree with AC once it's running.
- **Fix direction**: Document the bootstrap path in start-project.md — detect coordinator unavailability, use TodoWrite for bootstrap tasks, transition to coordinator once available. Not a silent fallback but an explicit documented mode.

### 6. Agent editing repos directly instead of using workspaces
- **Severity**: Workflow compliance — high
- **Where**: Execution phase (all tasks)
- **What happened**: Agent is editing files directly in `~/src/github/pfeff/agent-coordinator` instead of creating a worktree workspace. This causes excessive approval prompts because the working directory (`~/src/work`) doesn't cover the repo path. More importantly, it's editing the shared source repo directly — no branch isolation, no safe rollback.
- **Root cause**: The agent skipped workspace/worktree creation entirely. The goal-tree workflow delegates to task-workflow for workspace setup (dispatch-node → setup-workspace), but since the agent fell back to TodoWrite it bypassed that whole path.
- **Impact**: (1) Every file edit and bash command outside the working directory triggers approval. (2) Changes land directly on the repo's current branch with no isolation. (3) No CLAUDE.md per workspace for context.
- **Fix direction**: Even in bootstrap/TodoWrite mode, the agent should create worktrees for repos it's editing. The workspace creation step shouldn't be coupled to coordinator availability — it's a local git operation.

### 7. Sub-session created via raw `tmux new-session` instead of scripted path
- **Severity**: Workflow compliance — medium
- **Where**: Session creation during execution
- **What happened**: Agent created `s1-traceability: Migrate Traceability to AC` using a direct `tmux new-session` call instead of the scripted `create-tmuxp-session.sh` from dispatch-node.md (line 218). This bypasses workspace setup, CLAUDE.md generation, and any tmuxp layout configuration.
- **Root cause**: Same as #6 — TodoWrite fallback bypassed the dispatch-node pipeline entirely, so the agent improvised session creation.
- **Fix direction**: The scripted session creation (`create-tmuxp-session.sh` / `create-node-workspace.sh`) should be reachable even outside the coordinator dispatch path. These are local operations that don't depend on the coordinator.

---

## Run 2 (post-fix)

### Setup
- **Command**: `/start-project` (bare — no flags)
- **Symlinks**: `~/.claude/skills` and `~/.claude/commands` repointed to worktree
- **Fixes applied**: conversational flow, decomposition checkpoint, bootstrap mode, scripted sessions

### What improved
- **Conversational flow**: Agent had a multi-turn dialogue, reached tree decomposition through conversation, presented tree separately for approval. Observations #1 and #2 are fixed.
- **Bootstrap mode named**: Agent detected coordinator unavailability and explicitly said "Entering bootstrap mode." Observation #3 fix is working.

### 8. Excessive approval prompts during execution
- **Severity**: UX — high
- **Where**: Bootstrap execution phase (tasks A.1, A.2)
- **What happened**: Agent executed PostgreSQL setup as a series of individual `psql -c` commands, each requiring approval. User interrupted and told it to batch. Agent then wrote a setup script — good recovery, but should have done that from the start.
- **Root cause**: The operation doesn't guide execution style during bootstrap mode. The agent defaulted to imperative step-by-step commands rather than writing scripts and running them.
- **Fix direction**: Bootstrap mode guidance should say: "Write scripts, then execute. Minimize interactive commands. Each major phase should be one script execution, not a chain of individual shell commands."

### 9. No workspace/worktree created (still)
- **Severity**: Workflow compliance — high
- **Where**: Bootstrap execution
- **What happened**: Agent created project directory (`~/src/work/ac-local-prod/`) and wrote `setup.sh` directly there. No worktree from the agent-coordinator repo. The setup script references the source repo directly (`AC_REPO="/Users/matt/src/github/pfeff/agent-coordinator"`) rather than working from a worktree.
- **Root cause**: Despite fix in start-project.md step 9 saying "create node workspace via scripted path", the agent still didn't do it. The bootstrap execution guidance may not be strong enough, or the agent doesn't see worktrees as relevant for a deployment task (no code changes to isolate).
- **Assessment**: For this specific task (local deployment), a worktree is arguably unnecessary — the agent is building a release from main, not modifying code. But the approval prompt issue remains because the working directory doesn't cover the source repo path.

### 11. Agent writes directly to source repo, ignoring workspace conventions
- **Severity**: Workflow compliance — high
- **Where**: Documentation task in bootstrap execution
- **What happened**: Agent attempted to `Write(~/src/github/pfeff/agent-coordinator/docs/...)` directly to the source repo. User rejected twice. Agent didn't understand why until explicitly told "YOU KNOW HOW WE STRUCTURE PROJECT WORKSPACES." Even then, it asked follow-up questions instead of just doing it. Took 3 user corrections before the agent created a worktree.
- **Root cause**: The bootstrap mode guidance in start-project.md says to use scripted workspaces, but the agent either didn't load that context or didn't retain it through the execution phase. The skill was loaded at the start of the session but the convention faded from active context by the time execution reached this task.
- **Fix direction**: The bootstrap execution guidance needs to be more forceful: "NEVER write to source repos directly. Always work in a worktree, even in bootstrap mode." Consider adding this as a hard rule in SKILL.md core concepts, not just in start-project step 9. Also consider having the agent re-read the relevant operation section before each task dispatch.

### 13. Skill never loaded — agent improvised the entire session
- **Severity**: Root cause — critical
- **Where**: Session start
- **What happened**: User opened with `Continue with /goal-tree project. Continue with bootstrapping sub-goal...` The agent treated `/goal-tree` as a conversational reference, not a skill invocation. The goal-tree skill was never loaded. The agent explored the codebase with Explore agents and improvised all behavior — no hard rules, no workspace conventions, no scripted paths. Every subsequent observation (#8-#12) stems from this.
- **Root cause**: The skill system requires a slash command (`/start-project`, `/resume-project`) to trigger skill loading. Saying "the goal-tree project" in natural language doesn't load the skill. The agent has no way to know it should self-load a skill from a conversational reference.
- **Fix direction**: Two options: (1) The `/resume-project` command should be the documented way to re-enter a goal-tree session — make this prominent in project CLAUDE.md files. (2) Consider whether SKILL.md should be referenced from the project CLAUDE.md so that even without a slash command, the agent sees the hard rules when it reads the project context.

### 14. Mid-sentence `/goal-tree` not recognized as skill invocation
- **Severity**: Platform / instruction-following
- **Where**: Session start — user said `Continue with /goal-tree project. Continue with bootstrapping sub-goal.`
- **What happened**: The `/goal-tree` command exists and appears in the skills list, but the agent did not invoke the Skill tool. It treated `/goal-tree` as a conversational reference and proceeded without loading the skill. When explicitly told to start over, the agent called `Skill(goal-tree)` and then followed the workflow correctly — reading CLAUDE.md, checking coordinator state, asking before acting.
- **Root cause**: The model doesn't reliably recognize mid-sentence `/` references as Skill tool invocations. This is an instruction-following gap at the model level, not a missing feature. The command file, skill definition, and skill list entry all exist.
- **Mitigation options**: (1) Put the hard rules directly in project CLAUDE.md so they're in context regardless of skill loading. (2) Document that `/goal-tree` should be used at the start of a message, not mid-sentence. (3) Accept that users may need to say "start over" occasionally when the agent misses the reference.

### 12. No planning before implementation
- **Severity**: Workflow compliance — high
- **Where**: Bootstrap script writing (coordinator data loading)
- **What happened**: Agent read the AC API schema, said "Now I have the full picture. Let me write a script to load the data," then immediately wrote a 256-line bootstrap script and executed it. No planning-workflow, no PLAN.md, no user checkpoint before execution. The agent did list 4 steps in a brief inline "plan" but this is not the planning-workflow gate required by the skill.
- **Root cause**: SKILL.md hard rule #4 says "conversation before decomposition, decomposition before execution" but doesn't explicitly mention the planning-workflow gate during task execution. The execute-tree operation (line 23) says "Planning-workflow is a gate, not a suggestion" but this is in the coordinator path — the agent is in bootstrap mode and never loaded execute-tree.md.
- **Fix direction**: Add planning-workflow requirement to SKILL.md hard rules. Currently rule #4 covers the project-level gates but not the per-task planning gate. Something like: "Every task gets a plan before implementation — run planning-workflow or write PLAN.md. Do not jump from reading code to writing code."

### 15. Excessive reassurance-seeking during execution
- **Severity**: UX — medium
- **Where**: Post-bootstrap execution (design tasks)
- **What happened**: Agent ends nearly every message with "Does this match what you'd want?", "Want me to collapse them or keep separate?", "Ready to continue?" The content quality is good but the agent won't commit to a direction without explicit approval at every step.
- **Root cause**: The checkpoint culture from start-project's conversation phase (hard gate: "block on unanswered questions") is bleeding into execution. During planning/conversation, checkpoints are correct. During execution, the agent should be more decisive — propose and act, check in at phase boundaries, not after every thought.
- **Fix direction**: Distinguish between conversation-phase behavior (checkpoints at every dimension) and execution-phase behavior (act decisively, check in at round boundaries). The DD-22 checkpoint protocol in execute-tree already has auto-advance conditions — similar guidance should apply to inline execution.

### 10. Big upfront design before execution
- **Severity**: Process efficiency
- **Where**: Decomposition → execution transition
- **What happened**: The agent produced a full 7-task tree with detailed decomposition, got approval, then started executing sequentially. The user is stuck approving prompts while the agent works through tasks one at a time. No parallelism during execution.
- **Root cause**: Bootstrap mode has no dispatch pipeline — no dispatch-decision, no fan-out, no subagents. It's just the root session working through a TodoWrite list inline. The thoroughness of the upfront decomposition doesn't translate to parallel execution.
- **Fix direction**: Even in bootstrap mode, independent tasks should be dispatchable as subagents. The dispatch pipeline (dispatch-decision → dispatch-node) should work without the coordinator — it only needs the coordinator for state tracking, not for launching subagents.

### 16. PR creation skipped PR template on first attempt
- **Severity**: Workflow compliance — medium
- **Where**: PR creation for cursor-rules #220
- **What happened**: Agent created the PR without reading `.github/PULL_REQUEST_TEMPLATE.md` first. CI failed on PR Description Content validation. Agent then read the template and fixed the body. AC PR #137 had the same problem — agent read the template only after being told "incorrect description format."
- **Root cause**: The CLAUDE.md says "Always read `.github/PULL_REQUEST_TEMPLATE.md` from the repo before creating a PR." The agent didn't follow this. Likely context decay — the instruction is in the global CLAUDE.md, not in the goal-tree skill or the active operation.
- **Fix direction**: The `/finish-project` operation (or any PR creation path) should explicitly include "read PR template" as a step. Don't rely on global CLAUDE.md instructions surviving to PR creation time.

### 17. Agent tried to self-approve PRs
- **Severity**: Process awareness — low
- **Where**: CI fix for PR Review check
- **What happened**: Agent ran `gh pr review --approve` on its own PRs and got "Can not approve your own pull request." Recovered by using `--comment` instead, which satisfied the check.
- **Note**: This is a minor awareness gap, not a workflow bug. The agent learned and adapted within the session.

### 18. Stale CI run blocking merge — agent handled well
- **Severity**: Positive observation
- **Where**: PR merge attempt
- **What happened**: Old failed CI run coexisted with new passing run, blocking merge. Agent correctly diagnosed the issue and re-ran the failed workflow rather than using destructive workarounds.

### 19. PR validator too tightly coupled to GitHub issues
- **Severity**: Infrastructure — addressed in-session
- **Where**: `scripts/validate-pr-description.sh`
- **What happened**: Validator required `Closes #N` format (local issue number) and fetched issue body for acceptance criteria checkboxes. Cross-repo refs (`Closes pfeff/guardian#188`) and AC tree refs didn't match. Agent updated the validator to accept any reference format and removed the acceptance criteria fetch.
- **Note**: Good fix, addresses the transition away from GitHub as primary tracker. The agent identified and fixed this correctly.

---

## Run 1 (pre-fix)

### 4. AC repo is stale — PR #135 not in local main
- **Severity**: Environment / setup
- **Where**: Bootstrap phase
- **What happened**: Agent noticed `git log` shows AC is behind (PR #135 with goal trees not merged locally). The plan mentions pulling main but hasn't done it yet.
- **Note**: This is expected — the bootstrap step should handle it. Not a workflow bug, just confirms bootstrap must happen first.

### 5. Collapsed seed tasks (C.1-C.5) into single todo item
- **Severity**: Granularity loss
- **Where**: TodoWrite task list
- **What happened**: The decomposition had 5 distinct seed tasks with dependencies. The agent collapsed them into one "C.1-C.5: Seed OKR data in AC" todo item, losing the dependency ordering.
- **Root cause**: TodoWrite doesn't support dependencies. This is exactly why the coordinator exists — further evidence that the coordinator path should be enforced.
