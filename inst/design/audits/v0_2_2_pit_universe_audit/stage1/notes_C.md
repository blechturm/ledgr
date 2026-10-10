# Stage 1 notes, reader C (subsystems 9 to 13)

Frozen commit 289d57c, read from `C:/tmp/ws22-b`. Description only: nothing
here judges whether a behavior is right. Inventory: `inventory_C.csv`
(74 rules, C-001 to C-074). Probes: `dev/audit/pit_universe/probes/C_*.R`.

## Conventions used in the inventory

- `rule_id` is `C-nnn` per the brief; the integrator renumbers to `PIT-xx-nnn`.
- `applies_to_paths` adds one token to the README vocabulary: `resume`, for a
  rerun of an unfinished run ID (and the walk-forward test-run resume). The
  path matrix needs it as its own path because several rules differ there.
- `oddity` is a one-line flag (not `yes`), as the brief asked; probes ran via `run_low.sh`.
- `evidence = probed`: a probe printed the behavior (sometimes one branch only).

## Probe setup (read before reusing the probes)

The shared fixture declares trading status only for FFF and EEE. Every other
instrument then resolves `status_unknown` and is target-restricted on every
pulse (seen with `ledgr_results(bt, "availability")`; FFF is also
`status_unknown` before its first row at s14). A strategy that buys anything
fails with `ledgr_restricted_target`. The smoke check never trades, so it
did not show this. `probes/C_helpers.R` builds a variant that adds `active`
status rows from s1 for every instrument; all reader C probes use it. This
belongs to subsystem 3 (provider) and to the fixture owner: see Handoffs.

| Probe | Shows |
| --- | --- |
| `C_entitlement_resume.R` | fresh vs interrupted-and-resumed dividend entitlement (C-020, C-021) |
| `C_reconstruct_stop.R` | refuse stop with a pending fill; freeze cycle; reconstruct (C-008, C-009, C-046 to C-048) |
| `C_corporate_actions.R` | dividend, cash and stock acquisition, spin-off; refuse; strict; sweep parity; `cash_dividend` subtype (C-016 to C-032, C-061) |
| `C_window_marks.R` | opening holding without an in-window bar; first-pulse stop finalization (C-005, C-038, C-049, C-059) |

## Terminology met

- **Pulse**: an open-session close in the run window (availability) or a
  bar timestamp (dense). **Execution opportunity**: the next declared session
  opening after a pulse.
- **Mark / reference / mark_source / mark_age**: `reference` is the last
  observed close; `mark` is that close when permissible (or frozen), else NA;
  age counts pulses. Sources: `current_close`, `stale_close`,
  `expired_close`, `missing`, `frozen_close`.
- **Last fully valued pulse**: the last pulse with an equity row; equals the
  completion row's `achieved_end_utc`.
- **Entitlement boundary / bound quantity**: the pulse at the entitlement
  clock; the entitled quantity is fixed ("bound") when the fold reaches it.
- **Scheduled disposition** (`corporate_action_disposition`, basis
  `evidence`) versus **lifetime terminal disposition**
  (`lifetime_terminal_disposition`, basis `label`, `default` or
  `frozen_fallback`).
- **Fidelity**: `not_supplied`, `none`, `modeled`, `unsupported`.
- **Terminal recovery / finalization-only resume**: a RUNNING or FAILED row
  that already has a completion row is finalized without replaying the fold.
- **Prefix commit**: the equity rows of an INCOMPLETE or soft-stopped run are
  exactly the calendar pulses up to the achieved end.

## Oddities (flags only)

1. **Resume changes dividend entitlement (C-021, C-020, C-034).** The fold
   binds the entitled quantity at the end of the previous pulse, before that
   pulse's fills; resume and the composition reader recount from events
   stamped before the entitlement time, which includes a fill at the
   entitlement session's open. Probe: uninterrupted 99990, resumed 100000.
   `corporate-action-settlement.R:58-102,263-290`, `fold-engine.R:1103-1108`.
2. **First-pulse stop writes a full NA equity curve (C-038, C-059, C-073).**
   With zero fold equity facts, `ledgr_run_finalize` takes the dense replay
   branch (`run-finalize.R:457,526-537`) and stores one row per calendar
   pulse with NA equity, while the completion row says no pulse was valued.
   `ledgr_run_open` and a rerun of the run ID then fail with
   `ledgr_run_terminal_evidence_invalid`.
3. **Reconstruct fails on INCOMPLETE runs with post-prefix events (C-047,
   C-048).** A fill decided at the last valued pulse executes at the stop
   session's open and is committed; the cash identity check
   (`derived-state.R:187-191`) then fails. LTB-0203's stopped case has no
   such event.
4. **Mark history restarts at every window start (C-005, C-071).** An opening
   or carried holding with no bar on the window's first pulse stops at once
   with `valuation_horizon_exhausted`, whatever `max_sessions` is.
5. **Unrecognized corporate-action subtypes are inert (C-016).** A sealed
   `cash_dividend` row on a held instrument posts nothing and the summary
   says `NONE - supplied facts did not affect held instruments`.
6. **Refusal kinds differ (C-023 vs C-026).** Cash or quantity refusal aborts
   (run FAILED); terminal refusal stops typed (run INCOMPLETE).
7. **Cash-acquisition terms do not price the disposition (C-025).** CCC
   disposes at the 49.80 stale mark; the $50 terms appear only in the
   omitted-value estimate. The contract text says "permissible mark", so this
   may be intended; flagged because the sealed row carries the $50 terms.
8. **`effective_close` posts at the entitlement clock (C-019)**; payment_time
   is never read by execution.
9. **Dense runs never dispose acquisitions (C-015)**, though they do post
   dividends and run quantity checks.
10. **Stop pulses differ in valuation (C-012 vs C-008).** A
    `risk_mark_unavailable` stop pulse has an equity row and counts as valued;
    a valuation stop pulse does not.
11. **Dispositions are not trades (C-032).** Terminal exits never appear in
    fills, closed trades, `n_trades` or `win_rate`.
12. **Promotion checks only the snapshot hash (C-067).** Universe rule,
    valuation and corporate-action policy come from the promoting experiment
    and are not in candidate provenance (read, not probed).
13. **Reconstruction writes (C-046).** `ledgr_state_reconstruct()` deletes
    and rewrites `equity_curve`.
14. **Resume tail cut uses the close clock (C-041).** Version-2 fills are
    stamped at the next open; a fill decided at the restart pulse would
    survive the delete. No committed path seems to leave one (not probed).

## Handoffs for the integrator

- **Subsystem 3 (provider)**: instruments without trading-status rows become
  `status_unknown` and target-restricted once the family is declared. This
  shapes every fixture run; the shared fixture may need status rows.
- **Subsystem 1 (facts)**: corporate-action `fact_id` values are rewritten to
  `fact_<hash>` at sealing (probe output); the subtype vocabulary is open
  (`availability-facts.R:401-405`), which feeds oddity 5.
- **Subsystem 4 (calendar)**: availability bars off any pulse are dropped
  before valuation (`backtest-runner.R:1004-1023`, `sweep.R:255-259`); the
  sweep calendar is built from snapshot sessions over
  `[warmup_start, scoring_end]`.
- **Fixture / adapter mapping**: the fixture's entitlement clock is the close
  before the ex-date; the equity-settlement synthesis (3.4) reads the
  entitlement clock as the ex-dividend boundary. Under the fixture the cash
  posts one session before the price drop.
- **Subsystem 7**: the risk-mark gate (C-012) and helper sizing read the mark
  plane; C-012 is listed here with owner `unclear` to avoid a gap.
- **Subsystem 8**: execution reasons, affordability and the next-open fill
  rule were not inventoried here.
- **Path matrix**: run, resume, sweep, walk_forward (train = sweep, test =
  durable run), promote (durable run), reconstruct, readers. Intended
  differences seen: sweeps keep only summary diagnostics; dense
  availability reader is synthetic; recording pulse is derived differently
  for durable runs and sweeps (C-054). Unintended-looking differences:
  oddities 1 to 4.

## Open questions (for Stage 2, not answered here)

- Is the fresh-run entitlement (pre-fill positions) or the resume rule the
  one the design means by "immediately before the ex-dividend boundary"?
- Should a first-pulse stop store zero equity rows, as the completion row
  and the opener expect?
- Is a window-bounded mark lookback intended for openings and carried
  walk-forward state, given the feature-start rule is labeled temporary?

## Not determined

- Walk-forward behavior with a carried holding that lacks a first-pulse bar
  and the rerun failure in C-073 are inferred, not probed (a walk-forward
  probe was not attempted within the probe time budget).
- Parallel sweep parity with corporate actions (only sequential probed).
- Whether `next_open` posting combined with resume shows the same entitlement
  divergence (same code path; not probed).
- Promotion with a differently configured experiment (C-067) not probed.
