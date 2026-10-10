# Stage 1 notes: reader A (subsystems 1, 2, 4, 14)

Frozen commit 289d57c (worktree `C:/tmp/ws22-b`). Description only; nothing
here is a verdict. Inventory: `inventory_A.csv` (52 rules, A-001 to A-052).
Probes: `dev/audit/pit_universe/probes/A_ingest_edges.R` (cases A1-A9) and
`A_calendar_window.R` (cases C1-C6), both run through `run_low.sh`.

## Schema notes for the integrator

- Rule IDs follow the reader brief (`A-nnn`), not the README pattern
  (`PIT-<subsystem>-<seq>`); renumber when merging.
- `code_location` is `path:line (function)` at 289d57c; the README asks for
  `R/file.R:function`, and both are present where it helps.
- No `yardstick` column (Stage 3 only; the yardstick was not read).
- `applies_to_paths` uses: ingest (from_df, from_csv, from_yahoo, seal),
  facts_validate, experiment construction, run, resume, sweep, walk_forward,
  run_window (internal `ledgr_run_window()`), precompute, promote, reconstruct,
  readers.

## Terminology met

- Fact family: one normalized family object (`membership`, `trading_status`,
  `lifetime`, `sessions`, `equity_corporate_actions`), keyed by
  `(family, scope_id)`. Scope is `universe_id` for membership, `instrument` for
  status and lifetime, `equity` for corporate actions, `venue_id` for sessions.
- Knowledge mode: `evidenced` versus `assume_effective` (metadata
  `knowledge_assumption = "effective"`). The plan calls an assumed family
  `assumption_backed`.
- Report outcomes from `ledgr_facts_validate()`: facts `accepted`,
  `runtime_conflict`, `audit_only`, `rejected`; observations `accepted`,
  `quarantine_candidate`, `rejected`. `observed_row_outside_expectation` is a
  reason on an accepted observation, not an outcome.
- Hash rule 1 (bars and instruments) versus rule 2 (adds facts and acknowledged
  quarantine). "Sealed range" means the bar min/max timestamps in snapshot
  metadata (`start_date`, `end_date`), not the calendar coverage.
- Two different "calendars": session facts (`ledgr_facts_sessions`) drive the
  availability clock; `ledgr_calendar()`, `ledgr_calendar_us_equity()` and
  `ledgr_calendar_crypto()` (R/metric-context.R) are metric annualization
  calendars only. Easy to confuse in the map.
- Decision pulse = open-session close; execution opportunity = next in-window
  open session's `session_open`.
- Scoring start / hydration start / execution start: three window clocks that
  are forced equal today (A-044).

## Oddities with pointers (flags only)

1. A-005, A-024: off-calendar bars (closed day, intraday, outside coverage)
   seal as runtime bars; the only signal is the validate report, which
   `ledgr_snapshot_from_df()` discards on success.
2. A-009: no positivity rule at ingest; zero and negative prices seal.
3. A-010: membership and lifetime cannot carry a later-known revision of the
   same interval (structural conflict); status has supersession. Not stated
   in contracts.md; synthesis s4.1 defers revision facts.
4. A-012: exact duplicate corporate-action rows refuse, while other families
   collapse exact duplicates silently.
5. A-014: a `terminal_event` label is accepted on `known_active` and `unknown`
   lifetime rows.
6. A-017: unknown corporate-action subtypes (for example `cash_dividend`) seal
   and are never acted on.
7. A-019: corporate-action provenance records `knowledge = evidenced` even when
   `knowledge_time` is missing.
8. A-020: non-session fact Dates mean UTC midnight, not the venue civil date.
9. A-025: undeclared price basis runs with corporate actions; only an explicit
   `distribution_adjusted` declaration is refused.
10. A-028: `ledgr_facts_sessions_qlcal()` defaults to `assume_effective`,
    `ledgr_facts_sessions()` to `evidenced`.
11. A-032: an intraday-announced closure or early close cannot be evidenced.
12. A-033: POSIXct session times are not checked to fall on `session_date`.
13. A-034: two venues pass `ledgr_facts()` and refuse only at validation.
14. A-038: a calendar shorter than the bar range silently shortens the run
    (probe C1: 30 of 40 sessions, config end still the last bar time) or
    starts it late (C3). Synthesis s4.1 says declared coverage must determine
    every session in the requested run range.
15. A-041: `ledgr_run()` stores an opening date earlier than the sealed start
    as `start_ts_utc` (probe C4); sweep and precompute clamp it.
16. A-042: sealed-date checks use UTC dates, not venue session dates (not
    probed; matters only for venues whose close is on the next UTC date).
17. A-043: a date-only window end excludes that date's session, and on the
    last sealed date it is not moved to the last bar (probe C5); a date-only
    start includes its session.
18. A-050: `config_hash` binds `data.snapshot_id` (store-local name), not
    `snapshot_hash` (probe C6: equal snapshot hashes, different config
    hashes); walk-forward `session_id` binds `snapshot_hash`.
19. A-023 (documentation only, not a rule): the `ledgr_snapshot_from_csv`
    roxygen block sits above `ledgr_snapshot_format_distinct_ts_utc`
    (R/snapshot_adapters.R:506), which explains the stray untracked
    `man/ledgr_snapshot_format_distinct_ts_utc.Rd` in the main tree. Not read.

## Handoffs (rules seen but owned by other readers)

- Reader B, subsystem 3: activation families (R/availability-policy.R:152;
  corporate actions alone never activate, LTB-0029); fixed basket versus
  `ledgr_universe_members()` (test-availability-workflow.R:125); membership
  universe execution axis = all snapshot instruments (R/experiment.R:258);
  `ledgr_availability_applicable()` (R/availability-provider.R:51) makes NA
  knowledge rows never applicable; membership set supersession and status
  precedence resolution at a cutoff; C-locale stable-ID ordering
  (R/availability-provider.R:9); `ledgr_facts_history()` and
  `ledgr_facts_resolve()` (R/availability-inspection.R).
- Readers of 6 and 8: whether the durable run path excludes off-pulse bars
  (A-005, A-040): the run reads the `bars` temp view
  (R/snapshot-source.R:76) filtered only by [start, end], while sweep and
  window validation align bars to pulses by exact instant and drop the rest.
  Availability features require `gap_contract = "strict_window"`
  (R/availability-policy.R:233; R/backtest-config.R:206) and the active
  feature fingerprint changes (R/backtest-config.R:232).
- Readers of 7 and 9: runtime handling of zero or negative closes (A-009).
- Reader of 10: subtype vocabulary (A-017); corporate actions with NA
  `knowledge_time` (A-019); corporate-action clocks must land on pulses
  (fixture README, `ledgr_corporate_action_clock_mismatch`); terminal label
  matching against lifetime rows (A-014).
- Readers of 11 and 13: run versus sweep `start_ts_utc` identity (A-041);
  config identity versus walk-forward identity base (A-050); final-pulse
  no-execution inside walk-forward test windows with carried state (A-037);
  walk-forward contiguity calendar (R/walk-forward-folds.R:707) uses
  open-session closes without clipping to the bar range, unlike runs (A-038).
- Reader of 12: whether `summary()` and readers label assumption-backed runs
  (synthesis s4.2; A-027 found only `ledgr_experiment_plan()`).
- Integrator, path matrix: dense versus point-in-time differences in this
  scope are A-008 (sub-second bar handling), A-016 (unknown-instrument bars:
  quarantine versus error), A-022 (Date labels: session close versus UTC
  midnight), A-036 (pulse clock and coverage rule), A-039 (guard checks).
  Public window entry points: `ledgr_experiment_window()` and
  `ledgr_run_window()` are internal (not in NAMESPACE); public windows arrive
  only through `ledgr_walk_forward()` and precompute `start`/`end`.

## Open questions (not resolved)

- Does a durable `ledgr_run()` in availability mode read an off-calendar bar
  (A-005) as a current close or feature input? Not probed here because it is
  runtime behavior in other readers' scope.
- With a calendar shorter than the bars (A-038), does valuation of a holding
  stop at the last declared session while the config end is later? The probe
  observed only pulse counts.
- Whether the A-041 start difference changes `config_hash` between a run and a
  promote of the same candidate (subsystem 13).
- `ledgr_snapshot_open()` reopen of facts was not read in detail (LTB-0151 covers reopened rule-2 identity).

## Could not determine

- The UTC-date versus venue-date boundary effect (A-042) for a non-Americas
  venue; reading shows UTC dates, no probe was run.
- Whether any public surface other than `ledgr_facts_validate()` exposes the
  ingest report after a successful seal; none found by grep in R/.

## Stop conditions

None triggered: 52 rules (cap about 85), no product change needed, nothing
observed contradicts the WS22 byte-identity (no hash comparison was in scope),
and no finding needed a design decision to continue.
