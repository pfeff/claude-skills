# Bounded external verify waits

Canonical home for this doctrine. Referenced by `../SKILL.md` (self-verify),
`../../dispatch-gate/SKILL.md`, and `../../task-workflow/operations/validate-implementation.md`.
Edit here, not in the consumer skills.

## Origin evidence

A dispatched worker's verify step shelled out to iCloud AppleScript reminder
enumeration. The worker waited on it by parking on `Monitor` and resuming —
across 3 park/resume cycles (~110k+ tokens, ~7 minutes) — before the
dispatcher inspected the process directly and found it hung at 0% CPU
(blocked I/O, not merely slow). The dispatcher had to kill it manually; the
worker's wall-clock-only waiting gave no signal that the process had
stopped making progress.

**Preserved, not regressed**: in the same episode, dispatch-gate's
frozen-manifest STOP protocol (`../../dispatch-gate/SKILL.md` Step 6) worked
correctly — it is the right mechanism for a worker that discovers its frozen
scope no longer matches reality, and this doctrine does not replace it. The
two are complementary: STOP handles scope drift; the bounded-wait recipe
below handles a single external call that stalls without any scope having
changed.

## Doctrine

### 1. Hard cap with kill-on-stall (flat CPU, not wall-clock alone)

Any verify step that depends on a flaky or slow **external** resource — a
third-party API/service, an OS-integration shell-out (AppleScript, iCloud,
system automation), anything outside the repo's own test/build toolchain —
MUST run under a hard time cap with active kill-on-stall detection. A bare
wall-clock timeout cannot distinguish "slow but making progress" from
"hung": detect the hang by sampling the process's CPU usage — flat (near
0%) CPU across several samples means it is blocked on I/O, not computing.
Kill-on-stall and hard-cap termination must reach the whole process
subtree, not just the directly-backgrounded pid — an OS-integration
shell-out is commonly a wrapper (script, pipeline, `bash -c '...'`) around
the actual external call, and a kill that misses the descendant orphans it
to PID 1 instead of terminating it. See the recipe below.

### 2. The dispatcher owns long external waits, not the worker

The dispatcher — the session/agent that launched a job knowing (or
discovering) it will exercise a flaky/slow external resource — owns any
wait beyond the job's own bounded-cap budget. A worker that re-parks on its
own long-running subprocess (repeated `Monitor` park/resume cycles waiting
on a shell-out it started) burns tokens on every resume for no new signal —
the process is still just "running," which the worker already knew. When a
bounded run (recipe below) returns `inconclusive`, the worker records that
and moves on in its own turn; it does not loop back to re-wait on the same
stalled resource. If a wait genuinely needs supervision past the hard cap,
that supervision belongs to the dispatcher's own babysitting loop (a
dispatcher-side `Monitor`, or a scheduled recheck) — never a worker parking
on itself.

### 3. Inconclusive is a first-class verify outcome

A stalled or capped verify step degrades to `inconclusive` — not a silent
pass, not a silent skip, and not an indefinite block. Record it as
`result: inconclusive` in self-verify's `evidence.tests_run` (see
`annotation-schema.md`) with a one-line reason (`hard-cap-exceeded` or
`blocked-io`). An inconclusive required-verification step maps to axis-2
`warn` — never `fail` (the check didn't fail, it couldn't complete) and
never a silent `pass` (the check didn't run to completion). The work ships
with the gap disclosed; the operator's review sees the annotation and
decides how to weigh it, rather than the job blocking indefinitely to force
a definitive answer.

## Recipe: flat-CPU kill-on-stall

A light bash helper — not a monitoring framework. Runs a command with a
hard wall-clock cap and independently samples CPU usage to catch a stall
before the cap even fires. The command is launched as its own **process
group** (via bash job control, `set -m` — no external `setsid` dependency,
so this works unmodified on both macOS, which does not ship `setsid`, and
Linux) so that kill-on-stall and hard-cap termination reach the whole
subtree, not just the directly-backgrounded pid. This matters whenever the
external call goes through any wrapper — a script, a pipeline, `bash -c
'...'` — rather than being a single leaf process: without process-group
kill, a wrapped child is silently reparented to PID 1 and keeps running
after the function has already reported `inconclusive` and returned. See
`## Platform note: CPU sampling` below for why the stall check itself also
branches by platform.

```bash
# run_bounded_external <cmd> [hard_cap_s] [sample_interval_s] [stall_samples] [flat_cpu_pct] [term_kill_grace_s]
#
# Returns 0 on normal completion (echoes nothing extra; exit code is the
# command's own). Returns 2 on hard-cap timeout, 3 on detected stall
# (flat CPU) — both print "inconclusive: <reason>" to stdout.
run_bounded_external() {
  local cmd="$1" hard_cap="${2:-60}" interval="${3:-5}" stall_samples="${4:-3}" \
        flat_cpu="${5:-1.0}" term_kill_grace="${6:-1}"
  local start=$SECONDS flat_count=0 pid platform prev_ticks="" cur_ticks
  platform="$(uname -s)"

  # Job control (set -m) makes bash put this background job in its own new
  # process group (pgid == pid), so "kill -- -$pid" below reaches it and all
  # its descendants. Turned back off immediately after backgrounding — the
  # group assignment happens at fork time and survives that.
  set -m
  eval "$cmd" &
  pid=$!
  set +m

  while kill -0 "$pid" 2>/dev/null; do
    if (( SECONDS - start >= hard_cap )); then
      _run_bounded_external_kill_group "$pid" "$term_kill_grace"
      echo "inconclusive: hard-cap-exceeded (${hard_cap}s)"
      return 2
    fi

    local flat=0
    if [[ "$platform" == "Linux" ]]; then
      # Delta-sample /proc/<pid>/stat — see platform note below for why a
      # single ps %cpu read is unsafe on Linux.
      cur_ticks=$(_run_bounded_external_linux_cpu_ticks "$pid")
      if [[ -n "$cur_ticks" && -n "$prev_ticks" ]] && (( cur_ticks - prev_ticks <= 0 )); then
        flat=1
      fi
      prev_ticks="$cur_ticks"
    else
      local cpu
      cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ')
      if [[ -n "$cpu" ]] && awk -v c="$cpu" -v t="$flat_cpu" 'BEGIN{exit !(c<t)}'; then
        flat=1
      fi
    fi

    if (( flat )); then
      flat_count=$((flat_count + 1))
    else
      flat_count=0
    fi

    if (( flat_count >= stall_samples )); then
      _run_bounded_external_kill_group "$pid" "$term_kill_grace"
      echo "inconclusive: blocked-io (flat CPU across ${stall_samples} samples)"
      return 3
    fi

    sleep "$interval"
  done

  wait "$pid"
}

# Signal the whole process group ("-$pid", not "$pid") so descendants spawned
# by a wrapper/script/pipeline die too, not just the directly-backgrounded pid.
_run_bounded_external_kill_group() {
  local pid="$1" grace="${2:-1}"
  kill -TERM -- "-$pid" 2>/dev/null
  sleep "$grace"
  kill -KILL -- "-$pid" 2>/dev/null
}

# Read cumulative utime+stime (clock ticks) from /proc/<pid>/stat. The comm
# field (2nd field) is parenthesized and may itself contain spaces or
# parens, so strip everything up to the *last* ") " rather than splitting
# naively on whitespace.
_run_bounded_external_linux_cpu_ticks() {
  local pid="$1" stat
  stat=$(cat "/proc/$pid/stat" 2>/dev/null) || return 1
  stat="${stat##*) }"
  local -a f
  read -ra f <<< "$stat"
  echo $(( ${f[11]:-0} + ${f[12]:-0} ))
}
```

Defaults are deliberately small (60s cap, 5s sampling, 3 flat samples ≈15s
of near-zero CPU before declaring a stall) — tune per verify step, not
globally. A step known to be legitimately slow-but-CPU-active (e.g. a large
local build) should raise `hard_cap` rather than disable stall detection.
`term_kill_grace` (default 1s) is the SIGTERM→SIGKILL grace window; raise it
for a target known to need longer to unwind on SIGTERM.

### Platform note: CPU sampling differs by OS

macOS `ps -o %cpu=` reports a recent/instantaneous sample, so a single flat
reading is meaningful evidence of a current stall. **GNU/Linux `ps %cpu` is
a lifetime average** (CPU time consumed / elapsed time since process
start) — a process that burned CPU early and then hung can still read as
non-zero `%cpu` long after it went idle, which is a silent false negative
in exactly the stall detection this recipe exists for. The recipe avoids
that trap on Linux by not trusting `ps %cpu` at all: it takes two
`utime+stime` readings from `/proc/<pid>/stat` one sample interval apart
and treats a zero delta as flat, which is a true recent-activity signal on
either platform. The two code paths are intentionally different
implementations of the same "is this process making CPU progress right
now" question, not a portability shim over one shared primitive.

## Test coverage

The recipe's original test evidence used a single `sleep 30` leaf process —
the one shape immune to both the descendant-orphan bug and the Linux
`%cpu`-average false negative, since it has no descendants and never
touches the CPU at all. That gap is why those bugs shipped undetected.
Current coverage, run against the recipe verbatim, macOS/bash:

| Case | Command | Expected | Observed |
|---|---|---|---|
| Normal completion | `sleep 1; echo done` | exit 0, no `inconclusive` | exit 0 |
| Hard-cap timeout | `sleep 30`, `hard_cap=3`, stall detection disabled | exit 2, `inconclusive: hard-cap-exceeded` | exit 2, matched |
| Flat-CPU stall, leaf | `sleep 30` | exit 3, `inconclusive: blocked-io`, no orphan | exit 3, matched, no orphan |
| Flat-CPU stall, **wrapped/descendant** | `bash -c 'sleep 30'` | exit 3, `inconclusive: blocked-io`, no orphan | exit 3, matched, **no orphan** (confirmed against the pre-fix recipe: identical scenario left an orphaned `sleep 30` reparented to PID 1) |
| Used-CPU-then-hung, wrapped | `bash -c '<busy loop ~3s>; sleep 30'` | exit 3, `inconclusive: blocked-io`, no orphan | exit 3, matched, no orphan |

The `_run_bounded_external_linux_cpu_ticks` parser (comm field with
internal parens, `utime`/`stime` extraction) was unit-tested against a
synthetic `/proc/<pid>/stat` line and returns the correct tick sum.

**Not validated**: the Linux code path has not been run against a real
`/proc` filesystem — this was tested on macOS only (no Linux host or
running container was available in this session). The process-group kill
(`set -m` / `kill -- -$pid`) and the delta-sampling logic are Linux-portable
by construction (both are POSIX/bash + `/proc` mechanisms, not
macOS-specific), but that is an argument from design, not an empirical
result. Anyone running this on the operator's WSL2/Linux fleet should
re-run the wrapped-stall and used-CPU-then-hung cases there before treating
the Linux path as proven, not just plausible.

## References

- `../SKILL.md` — self-verify Step 2, where a required-verification step
  runs and this recipe applies.
- `annotation-schema.md` — `evidence.tests_run[].result` vocabulary,
  including `inconclusive`.
- `../../dispatch-gate/SKILL.md` — Step 5 (standing dispatch-brief
  instruction) and Step 6 (frozen-manifest STOP protocol, preserved
  unchanged by this doctrine).
