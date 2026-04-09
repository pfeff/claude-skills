# Environment Requirements

Before running the Ralph Wiggum loop, verify these prerequisites:

| Requirement | Check Command | Common Issues |
|-------------|---------------|---------------|
| Claude CLI installed | `claude --version` | Install via `npm i -g @anthropic-ai/claude-code` |
| Claude authenticated | `claude auth status` | Run `claude auth login`; check for multiple accounts or expired tokens |
| Git repo initialized | `git rev-parse --git-dir` | Loop relies on git history between iterations |
| Gates pass initially | Run gate commands from `.ralph/gates.md` | Fix baseline failures before starting loop |

## Pre-flight Check

Add to loop.sh to catch missing prerequisites early:

```bash
claude --version >/dev/null 2>&1 || { echo "Claude CLI not available"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not in a git repository"; exit 1; }
```
