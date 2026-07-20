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
See the recipe below.

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
hard wall-clock cap and independently samples `%cpu` to catch a stall
before the cap even fires.

```bash
# run_bounded_external <cmd> [hard_cap_s] [sample_interval_s] [stall_samples] [flat_cpu_pct]
#
# Returns 0 on normal completion (echoes nothing extra; exit code is the
# command's own). Returns 2 on hard-cap timeout, 3 on detected stall
# (flat CPU) — both print "inconclusive: <reason>" to stdout.
run_bounded_external() {
  local cmd="$1" hard_cap="${2:-60}" interval="${3:-5}" stall_samples="${4:-3}" flat_cpu="${5:-1.0}"
  local start=$SECONDS flat_count=0 pid

  eval "$cmd" &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    if (( SECONDS - start >= hard_cap )); then
      kill -TERM "$pid" 2>/dev/null; sleep 1; kill -KILL "$pid" 2>/dev/null
      echo "inconclusive: hard-cap-exceeded (${hard_cap}s)"
      return 2
    fi

    local cpu
    cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ -n "$cpu" ]] && awk -v c="$cpu" -v t="$flat_cpu" 'BEGIN{exit !(c<t)}'; then
      flat_count=$((flat_count + 1))
    else
      flat_count=0
    fi

    if (( flat_count >= stall_samples )); then
      kill -TERM "$pid" 2>/dev/null; sleep 1; kill -KILL "$pid" 2>/dev/null
      echo "inconclusive: blocked-io (flat CPU across ${stall_samples} samples)"
      return 3
    fi

    sleep "$interval"
  done

  wait "$pid"
}
```

Defaults are deliberately small (60s cap, 5s sampling, 3 flat samples ≈15s
of near-zero CPU before declaring a stall) — tune per verify step, not
globally. A step known to be legitimately slow-but-CPU-active (e.g. a large
local build) should raise `hard_cap` rather than disable stall detection.

## References

- `../SKILL.md` — self-verify Step 2, where a required-verification step
  runs and this recipe applies.
- `annotation-schema.md` — `evidence.tests_run[].result` vocabulary,
  including `inconclusive`.
- `../../dispatch-gate/SKILL.md` — Step 5 (standing dispatch-brief
  instruction) and Step 6 (frozen-manifest STOP protocol, preserved
  unchanged by this doctrine).
