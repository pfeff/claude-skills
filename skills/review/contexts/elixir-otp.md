# Elixir/OTP Platform Context for Code Review

When reviewing Elixir/OTP code, calibrate your findings against these idiomatic patterns. Do NOT flag the patterns below as issues.

## 1. "Let It Crash" and Supervision

Processes crash intentionally on unexpected input. Supervisors restart them to a known good state. This is a deliberate architectural choice.

**Do not flag:**
- Missing try/rescue in GenServer callbacks — let the process crash and restart
- Functions that raise instead of returning `{:error, reason}` — bang functions express intent that failure is a bug
- Missing catch-all/default clauses — `FunctionClauseError` on bad input is intentional
- "Crash risk" in supervised processes — the supervisor handles recovery

## 2. GenServer Conventions

GenServers serialize all access through their mailbox. The canonical structure separates **client API** (public functions) from **server callbacks**.

**Do not flag:**
- No mutex/lock protecting shared state — GenServer mailbox serializes access
- Public functions that just wrap `GenServer.call` — this is the standard client API pattern
- Unused `_from` in `handle_call` — required by the callback signature, underscore-prefixed is idiomatic
- `@impl true` annotations — enables compiler verification of callbacks
- `handle_continue` for deferred initialization — recommended pattern to avoid blocking supervisor startup
- Preference for `handle_call` over `handle_cast` — provides backpressure and delivery confirmation

## 3. Pattern Matching as Control Flow

Multiple function clauses replace if/else chains. `with` pipelines handle happy-path chaining.

**Do not flag:**
- No default/else branch — `FunctionClauseError` on unexpected input is a feature
- "Duplicate" function definitions with different arguments — multiple clauses dispatched by pattern matching
- Underscore-prefixed variables (`_result`) — intentionally ignored, compiler enforced
- Complex `with` blocks — idiomatic for chaining failable operations
- No early return — Elixir has no `return` statement; pattern matching handles branching
- Single-expression function bodies using `do:` syntax — idiomatic for simple operations

## 4. Ecto Changesets

Changesets are data pipelines for validation. Errors are data (`valid?: false`), not exceptions. Multiple changeset functions per context is standard.

**Do not flag:**
- No exception raised on invalid data — changesets return `%Changeset{valid?: false}` by design
- "Duplicated" validation across changeset functions — context-specific changesets are the recommended pattern
- `unique_constraint` not checking uniqueness — it translates DB constraint violations into changeset errors
- Schema modules containing validation — co-locating schema and changeset functions is the Ecto convention

## 5. Bang vs Non-Bang Repo Functions

- `Repo.insert` / `Repo.get` — returns tagged tuples or nil, for expected-error paths
- `Repo.insert!` / `Repo.get!` — raises on failure, for must-succeed paths

**Do not flag:**
- `Repo.insert!` as unsafe — the bang expresses intent that failure is a bug
- `Repo.get` returning nil — no null pointer exceptions in Elixir; callers pattern-match
- Mixed bang/non-bang usage — different call sites have different expectations (seeds use bang, controllers use non-bang)

## 6. Phoenix PubSub

Fire-and-forget topic-based broadcasting using native Erlang terms. No serialization needed within a BEAM cluster.

**Do not flag:**
- No message serialization/deserialization — PubSub uses native term passing
- No acknowledgment or retry logic — fire-and-forget is by design
- Dynamic topic strings (`"tasks:#{id}"`) as injection risk — PubSub topics are opaque internal strings
- Broadcasting raw structs — efficient and idiomatic within a BEAM node

## 7. LiveView handle_info Patterns

LiveView mount runs twice (static render + WebSocket connect). `handle_info` handles all async messages.

**Do not flag:**
- `connected?(socket)` guard as redundant — prevents duplicate subscriptions during two-phase mount
- `{ref, result}` pattern with `when is_reference(ref)` — standard pattern for Task.async results
- `Process.demonitor(ref, [:flush])` — mandatory cleanup after task completion
- Multiple `handle_info` clauses — dispatching by pattern for different message types is standard
- Side effects in `mount/3` — subscribing and loading data in mount is the standard lifecycle pattern

## 8. Additional Idioms

- **Long pipelines** (`|>`) are normal — 5-10 steps is fine, this is the primary composition mechanism
- **Tagged tuples** (`{:ok, result}`, `{:error, reason}`, bare `:ok`) — standard return convention, not inconsistency
- **Module attributes** (`@max_retries 3`) — these ARE constants, not magic numbers needing config extraction
- **Atoms as enums** (`:in_progress`, `:completed`) — atoms are interned symbols, fast to compare
- **Behaviours with `@impl true`** — define contracts even with single implementations
- **ETS tables** — standard high-performance concurrent data store, not "global mutable state"

## Top False Positive Categories to Suppress

1. "Missing error handling" — intentional crash + supervisor recovery
2. "No try/catch" — pattern matching and tagged tuples handle expected errors
3. "No default case" — `FunctionClauseError` is a feature
4. "Inconsistent function signatures" — multi-clause dispatch
5. "No locks/synchronization" — GenServer serializes access
6. "God module" — GenServer co-locates client API, callbacks, and state by convention
7. "Bang functions are unsafe" — they express intent
8. "Fire-and-forget is unreliable" — appropriate for PubSub
9. "Side effects in constructors" — `mount/init` setup is standard
10. "No DTO/serialization layer" — BEAM term passing is efficient
