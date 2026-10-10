# Stage 1 notes, implementation reader B

Subsystems (3) provider and resolver, (5) strategy context, (6) features,
(7) targets and sizing, (8) execution. Frozen commit 289d57c (worktree
`C:/tmp/ws22-b`). Description only; oddities are flagged, not judged.
Inventory: `inventory_B.csv` (76 rules, B-001 to B-076).

## Terminology met in the code

- **Physical axis**: the fold's fixed `instrument_ids`. All snapshot
  instruments under a membership rule; the declared basket otherwise
  (`R/experiment.R:257-262`). Bars, features, positions and marks live here.
- **Decision axis (Daxis)**: `ctx$universe` per pulse; members, then held
  nonmembers (`R/availability-provider-prepared.R:267-272`).
- **Members (M)**: `ctx$members`; provider members at the decision cutoff.
- **Held**: any nonzero position, either sign.
- **Target-restricted / admissible**: restriction comes from status, lifetime
  or freezing; `admissible = member & !target_restricted` is the single
  eligibility plane all helpers read.
- **Decision view / execution view**: provider resolutions at the decision
  close and at the next session open.
- **Execution opportunity**: the next open session's `session_open` within the
  window (`R/availability-facts.R:1949`).
- **Permissible / priced / frozen mark**: valuation-state outputs (subsystem 9)
  that context and the risk gate consume.
- **Strict window**: `gap_contract = "strict_window"`; a feature window of
  `stable_after` open sessions that must be fully observed.
- **Pulse notes**: per-pulse environment `ctx$.notes` where helpers record
  `sizing_skipped`; survives whatever the strategy returns.

## Pulse order inside one availability pulse (as read)

1. Corporate-action postings (`R/fold-engine.R:519`), then decision view
   (538), corporate dispositions (539-560), lifetime terminals (566-644),
   unvalued-holding stop (655), freeze diagnostics.
2. Equity fact at the decision close (721-750), before the strategy.
3. Context built on the decision axis; features filtered to it (767-824).
4. Strategy, target validation (871), restriction validators, risk-mark gate
   (913), risk chain (940), post-risk and short checks (941-945).
5. Execution plan at the next open (991): restriction at the open blocks,
   missing bar rejects, affordability, reconciliation (1037, 1209).
6. Accounting, state update, asset-state normalization (1251).

## Oddities (pointers; no verdicts)

- B-014: a trading-status family with rows for some instruments makes every
  uncovered instrument `status_unknown` (restricted). The shared fixture
  declares status for FFF and EEE only, so in a fixture run nearly every
  instrument is untradeable at every pulse (probe run D: 404
  `status_unknown` decisions; only FFF traded). **The integrator should
  decide whether fixture runs need a full-coverage status family** (probe
  `B_execution_paths.R` shows one way: active rows for all others).
- B-013: a superseded status row applies again after its superseding row's
  `effective_to` passes (supersession is computed only among applicable rows).
- B-008: open-ended interval membership overrides a later complete set that
  omits the instrument (provider and resolver agree).
- B-009: two membership resolvers (runtime prepared closure,
  `ledgr_membership_resolve_at`); runtime has no unknown state.
- B-016: reason token `status_unknown_or_conflicting` is used only for
  conflicting; unknown uses `status_unknown`.
- B-019: runtime calendar ignores session knowledge times; the public session
  resolver honours them.
- B-022: provider `history` and `identity` operations are unused in production.
- B-003: inactive-snapshot message names membership and session facts, while
  activation needs any one runtime family or a valuation policy.
- B-026: `held`, `risk_mark`, `mark_source` planes are exposed but not in the
  Context Contract's bound-field list.
- B-028: runtime silently drops bars not stamped at an open-session close;
  alignment code is duplicated (runner inline vs `ledgr_sweep_align_availability_bars`).
- B-034: `ledgr_pulse_snapshot()` is always dense (no strict windows, full
  history, every instrument a member) even on a point-in-time snapshot.
- B-038: strict completeness checks open, high, low and close even for
  close-only indicators (not observable while ingest rejects non-finite OHLC).
- B-051: a raw positive target on a member without a permissible mark stops
  the whole run INCOMPLETE (probe run B), while helpers skip that member.
- B-061: `ledgr_signal_strategy()` defaults `short_qty = -1`, which
  availability runs refuse.
- B-063: `ledgr_select_top_n()` tie order follows the collation locale (probe:
  C picks B1, A4; English picks a3, A4); the provider uses C-locale order.
- B-066: execution-time restriction blocks exits too, so a `quotation_only` or
  `known_inactive` holding cannot be sold while restricted (the contract
  states this for halts only).

## Cross-subsystem handoffs for the integrator

- Subsystem 1 (ingest, reader A): bars outside session closes are accepted at
  ingest as `observed_row_outside_expectation` (`R/availability-ingest.R:138`)
  and then dropped at runtime (B-028). Membership IDs not in the instruments
  table would make `valuation_state$advance()` abort; check that ingest
  forbids them. Whether one universe may mix sets and intervals (B-008).
- Subsystems 1/2 (reader A): status-coverage completeness is an ownership
  question (B-014, owner `unclear`); activation and experiment validation
  (B-001 to B-003) overlap subsystem 2.
- Subsystem 4 (reader A): B-019 (calendar from open sessions in the window,
  knowledge ignored), B-045 (dense requires complete coverage, availability
  tolerates no bars), execution opportunities are window-relative.
- Subsystem 9 (reader C): marks, ages, permissibility, freezing
  (`R/availability-economics.R:3-173`) feed `ctx$vec$priced/mark_age/
  risk_mark`, `ctx$equity` (B-030), the risk gate (B-051) and max-weight
  (B-052). Equity fact precedes the strategy at each pulse.
- Subsystem 10 (reader C): corporate-action posting and lifetime terminal
  dispositions run before the decision view is final (B-017). Spin-off
  recipients outside a fixed basket: can they become held nonmembers (B-011)?
- Subsystem 11 (reader C): run-fatal target errors (B-055) and the INCOMPLETE
  stops `risk_mark_unavailable`, `affordability_reconciliation_failed`.
- Subsystem 12 (reader C): readers rebuild decision views post hoc
  (`R/availability-results.R:480-507`); fill recording pulse derivation
  (`R/execution-timing.R:86-257`); diagnostics reason ordering (B-076).
- Subsystem 13 (reader C): sweep and walk-forward use the portable provider
  and the duplicated bar alignment (B-023, B-028, B-047). The window's last
  pulse never executes (B-069), so under `carry_test_state` a test window's
  final decision is dropped even though the next window's first session
  exists; worth a path-matrix row.
- Subsystem 14 (reader A): active feature fingerprints and engine version
  (B-043); execution timing version in identity (B-075).

## Dense versus availability differences seen (for Stage 2 (d))

Empty axis allowed only in availability (B-035); no short, post-risk sign or
restriction guards in dense (B-053, B-054); dense max-weight uses current
close, availability the risk mark (B-052); dense rebalance warns and zeroes an
unpriced member, availability skips (B-058); dense final pulse warns,
availability records a diagnostic (B-069); dense has no affordability (B-071);
dense fill timestamp is the next bar's timestamp, availability the session
open (B-065); dense requires complete bars, availability tolerates gaps (B-045).

## Open questions and things not determined

- Whether any test pins B-013 (supersession revival), B-008 (interval over
  complete set) or B-014 (partial-status default); none located by grep.
- Function-mode features skip the construction-time gap check (B-036); the
  run path re-checks at config build and strict compute refuses anyway. I did
  not trace every sweep candidate route for the exact refusal point.
- `ledgr_backtest()` (lower-level path) builds availability config in
  `R/backtest-config.R:204-233`; not traced further (path owner to decide).
- Held nonmembers in a fixed basket: only reachable through corporate-action
  recipients; not probed.
- Probe runs used `ledgr_corporate_actions_research()` defaults; terminal
  dispositions (3 per run) were observed but not inventoried (reader C).

## Probes

All in `dev/audit/pit_universe/probes/`, run through `run_low.sh`, each
under 10 s. `B_provider_resolution.R`: provider views on the fixture plus
synthetic membership, supersession and status-default cases.
`B_execution_paths.R`: runs A (churn, full status), B (risk-mark gate),
C (helper rebalance), D (churn, fixture status). `B_helper_ties.R`: top-n
tie order under C and English collation.
