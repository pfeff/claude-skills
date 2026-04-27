# Tooling Discipline Reference

Rules every supervisor follows for its *own* bash invocations, regardless of layer. Complex one-liners trigger permission prompts even when every component is on the safe set; each prompt stalls the loop and forces an operator intervention. The goal is to stay frictionless: complexity → friction → intervention → loop failure.

Throughout this file, **you** = the supervisor reading this.

## Rules

- **Single-purpose commands.** One tool per invocation. Pipe at most into `head`, `tail`, `wc`, `grep`, or a file-only `jq` filter — nothing more.
- **No inline interpreters.** Never run `python3 -c "..."`, `node -e "..."`, `ruby -e "..."`, `bash -c "..."`. If you need parsing, call a script under `goal-tree/scripts/` or `task-workflow/scripts/`, or use a single-line `jq`/`awk`/`grep` filter.
- **No compound pipelines mixing readers and writers.** Process substitution (`< <(...)`), command substitution that writes files, or a terminal writer (`> file`, `tee outside /tmp`) flag the whole pipeline.
- **Prefer existing scripts.** Before composing a pipeline, check `goal-tree/scripts/` and `task-workflow/scripts/` for a single-purpose helper. If none exists for a recurring need, stop and commit a script first — do not inline the parser.

If you cannot fit your need into a simple command, that is a signal to add a script, not to write a more complex one-liner.
