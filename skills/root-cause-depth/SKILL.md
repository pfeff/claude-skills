---
name: root-cause-depth
description: >-
  Use before declaring a root cause "found" in any diagnosis, debugging,
  incident, or postmortem task — especially when you've identified what is
  wrong and are about to propose a fix. Runs an evaluable stop-condition test
  that pushes past the proximate symptom to a named, owned mechanism.
  Triggers: "root cause", "RCA", "why did this happen", "the fix is to
  change/set X", diagnosing a misconfiguration or wrong state, incident
  investigation, "is that the real cause". Fire eagerly — stopping shallow is
  the default failure this guards against.
version: 1.0.0
---

# Root-Cause Depth

A "root cause" is real only when you've reached a **named, owned mechanism**
and chosen a response to it. Stopping at the first level that explains the
symptom is the default failure. Do not stop on a vibe — run the stop
condition below.

## Stop condition (evaluate every candidate cause C)

C is terminal ONLY when it passes all three gates and lands on a branch:

1. **Owner named.** What system/process was supposed to produce the correct
   state? If you cannot name it (IaC, pipeline, automation, a validation that
   should have failed, a person/team), you are above the mechanism — keep going.
2. **Recurrence test.** If you take the action C implies, can this *class* of
   failure recur through the same path? If yes → not terminal, keep going.
3. **Red-flag test.** Is the implied action "manually correct this instance"?
   If yes → not terminal, keep going. The root cause is why that value was
   wrong *and* why nothing caught it.

Once C names an owner and passes 2–3, classify **control** — this is the
actual stop:

- **In our control** → terminal. Apply the *structural* fix to the owning
  system (e.g. add to IaC), not the instance patch.
- **Outside our control** → terminal for *descent*; you can't fix the
  mechanism, so branch the *response* (one or more, not mutually exclusive):
  - **Accept & record** — add to a won't-fix / known-limitations list with rationale.
  - **Defend** — guards on our side: validation, retries, fallbacks, and/or
    detection/alerting so the failure is contained or caught fast.
  - **Escalate** — identify and engage the party who owns the mechanism.

The investigation stops at *named mechanism + chosen branch* — never at
"manually fix this instance."

## Anti-pattern

Anchoring on a checklist / acceptance-criterion's literal "classify the
cause" wording as the stop signal. Satisfying the stated bar ≠ finding the
cause that makes the fix durable. The AC is a proxy for the goal; don't
optimize the proxy.

## Note on severity

The depth push is uniform — always name the mechanism first. Severity affects
the *branch*, not whether you descend: a low-blast-radius, out-of-control
cause may resolve quickly to Accept & record; a shared-environment or
recurring one warrants Defend + Escalate.
