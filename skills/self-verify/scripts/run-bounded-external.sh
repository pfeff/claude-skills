#!/usr/bin/env bash
# run-bounded-external.sh — canonical, sourceable implementation of the
# hard-cap + kill-on-stall recipe documented in
# ../references/bounded-external-waits.md. Edit the doctrine there; this
# file exists so consumers don't each hand-copy the function body.
#
# Requires bash. run_bounded_external's process-group isolation (`set -m`)
# hard-errors under zsh ("set: can't change option: -m") and zsh's `$-`
# does not carry the `m` flag at all, so both the isolation and its
# save/restore guard are bash-specific. Never source this into an
# interactive shell or a sh/zsh script — invoke it via an explicit bash
# process instead, e.g.:
#
#   bash -c "
#     source '\${CLAUDE_PLUGIN_ROOT}/skills/self-verify/scripts/run-bounded-external.sh'
#     run_bounded_external 'curl -sf http://localhost:4000/api/health' 10 2 3
#   "
#
# See ../references/bounded-external-waits.md for the full doctrine,
# argument semantics, return codes (0 success, 2 hard-cap, 3 stall), and
# per-platform CPU-sampling notes.

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
  # its descendants. Restored to the caller's prior state (not unconditionally
  # off) immediately after backgrounding — the group assignment happens at
  # fork time and survives that. Without the save/restore, a caller that
  # already had monitor mode on (interactive shells default to this) would
  # find it silently turned off after calling this function.
  local restore_m; case $- in *m*) restore_m="set -m" ;; *) restore_m="set +m" ;; esac
  set -m
  eval "$cmd" &
  pid=$!
  $restore_m

  while kill -0 "$pid" 2>/dev/null; do
    if (( SECONDS - start >= hard_cap )); then
      _run_bounded_external_kill_group "$pid" "$term_kill_grace"
      echo "inconclusive: hard-cap-exceeded (${hard_cap}s)"
      return 2
    fi

    local flat=0
    if [[ "$platform" == "Linux" ]]; then
      # Delta-sample /proc/<pid>/stat — see the doctrine doc's platform note
      # for why a single ps %cpu read is unsafe on Linux.
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
# Also signal the direct pid itself as a fallback: if process-group isolation
# somehow didn't take (set -m failed to create a distinct pgid), the group
# kill above silently targets a group that doesn't exist — a no-op, strictly
# worse than the pre-fix direct-pid kill. The direct kill is a strict subset
# of what the group kill already reaches when isolation worked (same pid, so
# it never signals wider than intended), and is a harmless redundant no-op
# (suppressed) once the group kill has already reaped it.
_run_bounded_external_kill_group() {
  local pid="$1" grace="${2:-1}"
  kill -TERM -- "-$pid" 2>/dev/null
  kill -TERM "$pid" 2>/dev/null
  sleep "$grace"
  kill -KILL -- "-$pid" 2>/dev/null
  kill -KILL "$pid" 2>/dev/null
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
