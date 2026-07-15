#!/usr/bin/env python3
"""Git-backed detection for kb-lint's auto-apply-eligibility gate.

Auto-fix is only "reversible (git)" (INV-1) when the target vault is actually a git working
tree. That must be re-verified fresh, every run, against the live filesystem — never cached,
and never trusted from a passed-in flag or a prior run's/session's determination. This module
holds exactly that one deterministic, unit-testable primitive; it does no other vault I/O.
"""

import subprocess


def is_git_backed(vault_path: str) -> bool:
    """True iff ``vault_path`` is inside a git working tree, checked fresh against the
    filesystem on every call. Callers (kb-lint's apply-fixes step) must call this each run
    before treating any fix as auto-apply-eligible — do not cache the result or assume it
    carries over from a previous check. Returns False (never raises) if git is missing, the
    path doesn't exist, or the path is not inside a work tree."""
    try:
        result = subprocess.run(
            ["git", "-C", vault_path, "rev-parse", "--is-inside-work-tree"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0 and result.stdout.strip() == "true"
