# Type 1 Final Review: Typed Accounting Event Boundary

- Status: PASS_AFTER_PATCHES
- Reviewer: Codex, author of seed v2 but not the synthesis
- Date: 2026-10-29
- Mode: Type 1 final review; verification, not design
- Synthesis: `rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md`
- Baseline checked: `269553ca`

## 1. Verdict

**PASS_AFTER_PATCHES.** The synthesis faithfully adopts seed v2, the Type 2
response, the response review and all four maintainer decisions. Its central
architecture is internally coherent and matches the current seams: one wide
typed ledger; cash authority distinct from lot-derived position authority;
one validation vocabulary at append and read; one prepared replay; the named
`inline_summary()` exception; one ordered WS7/WS8 cut; schema 125 and no
compatibility path.

Five in-place corrections are required. They narrow or complete rules already
chosen; none requires Type 2 or a new maintainer decision. After those patches,
the synthesis is ready for maintainer acceptance. Because the synthesis brief
was author-drafted, acceptance also confirms that the maintainer has reread
the brief and synthesis together, as its header requires.

## 2. Required Patches

### P1. Scheduled dispositions require a positive price

Synthesis Section 3.3 line 112 permits `price >= 0` for both scheduled and
lifetime dispositions. The scheduled resolver emits only when price is finite
and strictly positive (`terminal-outcomes.R:75-90`); zero is `no_mark` and no
event is posted. Lifetime resolution admits zero, including write-off
(`terminal-outcomes.R:15-48`).

Patch the matrix to `scheduled: req, > 0` and `lifetime: req, >= 0`. Keep the
zero-price fixture on the lifetime/write-off arm and add a mutation proving a
zero-price scheduled row refuses.

### P2. Complete the disposition and evidence vocabularies

Section 3.3 names scheduled choices and both basis vocabularies, but does not
seal lifetime `disposition_choice`. Bind persisted lifetime choices to
`last_permissible`, `last_mark`, `haircut` or `write_off`; `refuse` produces no
event. This follows the current policy vocabulary and resolver
(`corporate-action-policy.R:65-69`; `terminal-outcomes.R:34-48`).

Also state the row semantics that `req` alone does not express:

- source-fact and policy identifiers are non-empty;
- `affected_marked_exposure` is finite and non-negative;
- `mark_source` is non-empty, `mark_source_ts_utc` is valid UTC and
  `mark_age` is a non-negative integer; and
- `terminal_event` and `matched_label` are non-empty on lifetime rows.

These are producer and audit-evidence constraints, not new product choices.
The existing disposition validator already requires non-empty source-fact and
policy identifiers (`accounting-replay.R:188-216`), and the producers supply
the remaining values (`terminal-outcomes.R:108-121`, `:187-198`). Add empty,
negative and invalid-time mutations to Section 6 item 6.

### P3. Thread ordering state across validation blocks

Sections 3.3 and 3.4 bind event-time monotonicity and per-run sequence
uniqueness, but only describe validating an isolated block. A decreasing
timestamp or duplicate/out-of-order sequence at a fetched-block boundary can
escape a block-local check. Today's preparer checks duplicate sequence only
within its input (`accounting-replay.R:45-49`), and its later timestamp helper
falls back when it observes decreasing time (`accounting-replay.R:348-361`).

State that the validator accepts the prior block's last `event_seq` and
`ts_utc` at both append and read boundaries. A later block must begin with a
strictly greater sequence and a timestamp no earlier than the prior block's
last timestamp. Section 6 must split immediately before a duplicate sequence
and a decreasing timestamp so removing this boundary state fails.

### P4. Do not require a production memory-replay caller

Section 6 item 3 requires a production caller for both the memory and DuckDB
prepared-block arms. Ordinary memory candidates deliberately call
`inline_summary()` first (`sweep.R:1884-1900`); that is D4 and Section 3.5's
named exception. Requiring production to prepare the memory event carrier
would either be false or reintroduce replay into the optimized path.

Keep memory-versus-DuckDB block equality as a failure-sensitive boundary
fixture. Require a production-caller detector for `inline_summary()` and for
the durable preparer separately. Do not require the memory-preparation arm
itself to be a production caller.

### P5. Narrow the sole-reader statement

Section 3.5 line 172 says every durable reader goes through preparation and
replay. This conflicts with the accepted raw `SELECT *` ledger in Section 3.7,
the typed resume-dedupe query in Section 3.4, and bookkeeping queries for the
next sequence, last fill timestamp and resume cleanup
(`ledger-writer.R:107`; `backtest-runner.R:1061`; `run-resume.R:74-84`). None
of those derives accounting state and none should replay.

Replace it with: every durable or reconstruction reader that derives
accounting state or an accounting-semantic projection goes through the
preparer and replay. Explicitly exempt the raw ledger projection, typed
dedupe and identity/order/cleanup queries; they may read typed primitives but
may not derive cash, positions, lots, realized PnL or trades.

For clarity, change Section 2's `Dependencies: none` to `Package dependency
changes: none`; the same synthesis binds the sequencing dependency WS4 to the
WS7/WS8 cut in D7.

## 3. Verified Clean

- The three durable write paths and the non-fill serialize/parse chain resolve
  at the cited locations.
- The cash-versus-position authority split matches fold and replay: both
  derive position from lots, while replay consumes `cash_delta`.
- Opening bases zero and negative are registered by LTB-0020 and the synthesis
  preserves them.
- Scheduled rows persist no lifetime label, while lifetime rows require a
  sealed non-empty label before posting.
- Write-off provenance is correctly bound to source `write_off`, age zero and
  the disposition pulse.
- `instrument_id NOT NULL` and `fee NOT NULL` are compatible with every
  inventoried producer.
- The producer list includes db-live, buffered and resume-opening writes plus
  the compiled handler boundary. The source-derived census at ticket cut is
  still necessary and correctly not replaced by guessed counts.
- Removing `meta_json` requires both cited contract amendments. Schema 124 is
  current, so 125 is the correct successor.
- The public `SELECT *` ledger decision is explicitly recorded as an intended
  shape change; other public parity and the decided INCOMPLETE correction are
  separated.
- D5 to D8 stay within synthesis authority and do not contradict seed v2.
- Identity is correctly limited to the store-format fingerprint; no snapshot
  or run-configuration input changes.
- The compiled execution envelope remains untouched; only its handler-facing
  typed publication changes.
- The rejected alternatives do not conflict with a bound decision.

## 4. Next Step

Patch P1 to P5 in place with a revision note. No further design round or
focused review is required; the maintainer may accept the corrected synthesis
after checking the diff. Acceptance then performs the Section 11 routing:
amend the macro plan for D7, update `decisions.md`, route Section 9 and prepare
the one ordered WS7/WS8 ticket cut.
