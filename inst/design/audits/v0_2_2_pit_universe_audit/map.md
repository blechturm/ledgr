# Point-in-time universe audit, Stage 1: map

**Status:** Stage 1 output for Gate 1, written 2026-10-10 by the cross-path
integrator. Description only: nothing here judges whether a behavior is right.
**Frozen commit:** 289d57c (worktree `C:/tmp/ws22-b`). Code citations are
`R/file.R:function` at that commit.
**Companions:** `inventory.csv` (195 rules), `path_matrix.csv` (56 rows),
probes in `dev/audit/pit_universe/probes/` (`A_*`, `B_*`, `C_*` by the three
readers, `I_*` by the integrator), reader notes in `stage1/`.

## How to read this

- Rules are cited as `PIT-<subsystem>-<sequence>`. Each inventory `notes`
  starts with `src`: the reader row(s) it came from (`A-`, `B-`, `C-`) or
  `integrator`. Contract headings are the `##` headings of `contracts.md`
  plus "Decision Axis And Eligibility" in the Strategy Contract.
- `applies_to_paths` uses the README tokens plus `resume` (added in Stage 1:
  a rerun of an unfinished run ID behaves differently enough to need its own
  token). Reader A's finer names were folded in: `facts_validate` into
  `ingest`; `experiment_plan` and the quarantine reader into `readers`;
  `precompute` and the internal `ledgr_run_window()` into `sweep` and
  `walk_forward`. The path matrix keeps the finer entry points.
- `path_matrix.csv` labels each difference `stated` (contract or code says
  so), `observed` (neutral) or `flag` (an oddity). An `oddity = yes` is a
  flag, not a finding; Stage 2 classifies.

## The running example

The shared fixture (`dev/audit/pit_universe/fixture.R`) is 40 New York
sessions from 2021-03-01 with two ad hoc closed weekdays after s20 and an
early close on s30, and 17 instrument IDs in the yardstick's roles: BBB added
s10 (announced s5 after the close), CCC cash acquisition (terminal s19), DDD
stock acquisition (s25), EEE removed s21 and `quotation_only` from s23, FFF
halted s14 to s15 with no bars, HHH dividend (ex s15), III spin-off of JJJ
(s17), KKK delisted after s12, LLL listed s8 and added s20, MMM missing bars
on s8 and s10, NNN removed s15 and re-added s30, OOO redomiciled as OOO2.

The frozen default (`status_coverage = "declared"`) has trading status for
FFF and EEE only, so every other instrument is `status_unknown` and cannot be
bought (PIT-03-015; probe `I_paths.R` P7: only FFF trades, 404
`status_unknown` rows, run DONE). Stage 1 added `status_coverage = "full"`
(active rows for the rest); the path probes use it (README explains).

The walk below follows one run of the probe strategy "hold everything, set
every tradable ID to 10 shares" (`I_paths.R` P1) on the full fixture with a
membership universe `ledgr_universe_members("AUDIT500")`,
`ledgr_valuation_stale(3)`, zero costs and 100,000 cash. It ends DONE after
40 pulses with 15 fills, 5 dispositions and 1 dividend cashflow.

## 1. Fact model and ingest

What happens. The adapter hands ledgr bars plus up to five fact families
from the `ledgr_facts_*()` constructors (sessions, membership, trading
status, lifetime, equity corporate actions); `ledgr_facts()` bundles them and
`ledgr_snapshot_from_df()` validates everything together and seals.

Every interval fact is half-open, `[effective_from, effective_to)`
(PIT-01-001). Each family is built under one knowledge mode, `evidenced`
(supplied `knowledge_time` kept, missing stays NA) or `assume_effective`
(missing `knowledge_time` filled from `effective_from`), recorded in hashed
metadata and row provenance (PIT-01-002). An evidenced row without a
knowledge time still seals and is reported `audit_only` (PIT-01-003); at run
time it never applies (PIT-03-007). Bars have no knowledge clock of their own:
`ts_utc` is all there is (PIT-01-004).

Validation sorts observations into accepted, quarantine candidates and
rejected (PIT-01-006, PIT-01-007). Facts are deduplicated, conflicts
classified, and every referenced instrument must be in the instrument master
(PIT-01-011, PIT-01-013, PIT-01-015, PIT-01-016). Sealing re-checks all of it
(PIT-01-020). Several things seal quietly: a bar that is not at an open-session
close (PIT-01-005); zero or negative prices (PIT-01-009); corporate-action rows
with unknown subtypes or no knowledge time (PIT-10-001, PIT-01-018).
Membership and lifetime have no revision mechanism, so a later-known reversal
of the same interval is a structural conflict (PIT-01-010); trading status
does have source-local supersession (PIT-01-013). Exact duplicate
corporate-action rows refuse while other families collapse duplicates
(PIT-01-011, PIT-01-012). Fact Dates mean UTC midnight (PIT-01-019).
Corporate-action rows carry four optional, ordered clocks (PIT-01-017).

Contracts: Snapshot Contract, Availability Contract.
Paths: ingest only. Dense versus point-in-time ingest differs for sub-second
bars (PIT-01-008), unknown-instrument bars (PIT-01-016) and Date labels
(PIT-02-001).

## 2. Adapter boundary

What happens. `ledgr_snapshot_from_df()` is the point-in-time ingest door;
`ledgr_snapshot_from_csv()` delegates to it; `ledgr_snapshot_from_yahoo()`
accepts no facts (PIT-02-002, PIT-02-005). With a sessions family, Date bar
labels map to that date's session close; without one they mean UTC midnight
(PIT-02-001). `ledgr_facts_validate()` runs the same validation without
writing; it is the only public place that shows accepted-with-flag outcomes,
because a successful seal discards the report (PIT-02-003; probe `I_paths.R`
P11 shows an off-session bar accepted by validation and then never seen).

The caller declares `price_basis`; only `distribution_adjusted` is refused,
an undeclared basis runs (PIT-02-004). The caller chooses the knowledge mode
per family; `ledgr_experiment_plan()` labels assumed families
`assumption_backed`, and no other surface does: `summary()` prints valuation
and terminal assumptions only (PIT-02-006, probed). The two session
constructors have opposite knowledge defaults (PIT-02-007).
`ledgr_sim_pit_inputs()` is a teaching adapter that returns raw frames
(PIT-02-008).

Ownership: the inventory has one `adapter` rule (instrument identity,
PIT-14-001) and three `unclear` rules: whether complete status coverage is the
adapter's job (PIT-03-015), who owns the corporate-action subtype vocabulary
(PIT-10-001), and what promotion owes the sweep's configuration (PIT-13-007).

Contracts: Snapshot Contract, Availability Contract.

## 3. Provider and resolver

What happens. When the experiment is built, ledgr decides whether the run is
availability-aware: any membership, sessions, trading-status or lifetime
family on the snapshot, or a valuation policy on the experiment, activates it;
corporate actions alone do not (PIT-03-001). There is no mode flag. An active
experiment must have a sessions family and an explicit
`ledgr_valuation_stale()` (PIT-03-003), and `ledgr_universe_members()` must
name a declared universe (PIT-03-004). The exception found in Stage 1:
`ledgr_backtest()`, the lower-level wrapper, never builds the availability
block, so it runs a dense fold on the same snapshot (PIT-03-002, probe P13).

Under a membership rule the fold's physical axis is every snapshot instrument
(PIT-03-006); under a character vector it is the declared basket, whose
members never change (PIT-03-005; probe P8). At each cutoff the provider
applies a fact only once it is both effective and knowable,
`max(effective_from, knowledge_time) <= t < effective_to` (PIT-03-007).
Membership sets resolve by effective order, the last complete set resetting
membership (PIT-03-008); interval rows override set state (PIT-03-009),
though the public constructors cannot put both kinds in one universe.
Runtime membership is two-valued: no evidence means nonmember, while
`ledgr_facts_resolve()` reports the same case as NA (PIT-03-010). Reader B's
probe shows BBB a nonmember at the s9 close (announced s5, effective s10).

The decision axis is the members in C-locale ID order followed by held
nonmembers (PIT-03-011, PIT-03-012); in the example NNN stays on the axis
after its removal at s15 because it is held (reader `availability` table, P6).
Trading status resolves by supersession and precedence (PIT-03-013); a
superseded row applies again after its superseder ends (PIT-03-014). Once a
status family exists, any instrument-time without a row is `status_unknown`
and restricted (PIT-03-015). Lifetime takes the latest applicable row
(PIT-03-016). Restrictions map to reason tokens (PIT-03-017). An execution
view resolves the same facts again at the next session open (PIT-03-018).

The public inspection functions cover membership and sessions only
(PIT-03-019, PIT-03-020). The provider exposes five operations; production
calls two (PIT-03-021). Durable runs and readers build the provider from the
snapshot connection, sweeps and walk-forward from in-memory bars through the
same builder (PIT-03-022).

Contracts: Availability Contract.

## 4. Calendar, windows and sealed range

What happens. The session calendar has one row per civil date across its
coverage (PIT-04-001), each session knowable by its open (PIT-04-002), with
local times resolved in one IANA zone (PIT-04-003); one venue per snapshot
(PIT-04-004). The sealed range is the bar minimum and maximum, not the
calendar coverage (PIT-04-005).

Decision pulses are the open-session closes inside the window; the runtime
ignores the session rows' own knowledge times (PIT-04-006). In the example
that is 40 pulses from 2021-03-01 21:00 UTC (16:00 New York, standard time)
to 2021-04-27 20:00 UTC (after the DST change), with s30 at 13:00 local.
Each non-final pulse executes at the next session open; the final pulse of a
window never executes (PIT-04-007). Nothing checks that the calendar covers
the bars: a shorter calendar quietly shortens the run (PIT-04-008). The run
guard checks per-instrument bar coverage only in dense mode (PIT-04-009).

Bars are aligned to pulse closes by exact instant on every path; anything
else is dropped without a diagnostic, and a pulse without a bar becomes an NA
row marked `MISSING_EXPECTED_SESSION` (PIT-04-010; probe P11 confirms the
durable run, answering reader A's open question). The alignment exists twice:
inline in the runner and as a sweep helper.

Window boundaries: `ledgr_run()` stores an opening date earlier than the
sealed start as given, sweep clamps it (PIT-04-011; probe P10, equity equal).
Walk-forward and precompute windows are checked by UTC date (PIT-04-012), and
a date-only end excludes that date's session (PIT-04-013). Feature,
hydration and execution start are all forced to the scoring start
(PIT-04-014), a temporary rule pending the history wave.

Contracts: Availability Contract, Execution Contract, Snapshot Contract.

## 5. Strategy context

What happens. Before the strategy runs, the fold builds `ctx`. `ctx$universe`
is the decision axis and `ctx$ts_utc` the session close (PIT-05-001);
`ctx$members` the provider members (PIT-05-002). `ctx$vec` carries the
eligibility planes `member`, `held`, `target_restricted`,
`target_restriction_reason`, `admissible`, `priced`, `mark_age`, plus
`risk_mark` and `mark_source`, which the Context Contract's field list does
not name (PIT-05-003). Missing sessions show as NA bars (PIT-05-004).
Feature reads are limited to the axis (PIT-05-005). Per-asset state follows
the axis (PIT-05-006). `ctx$tradable()` is admissible and priced
(PIT-05-007); `ctx$hold()` and `ctx$flat()` are literal targets over the
axis (PIT-05-008). An empty axis still calls the strategy (PIT-05-010).

`ledgr_pulse_snapshot()`, the interactive context, is always dense even on a
point-in-time snapshot: in probe P12 BBB is a member and admissible at s5,
before it joins (PIT-05-009). `ledgr_indicator_dev()` also reads no facts
(path matrix).

Contracts: Context Contract, Strategy Contract / Decision Axis And
Eligibility, Availability Contract.

## 6. Features

What happens. Every indicator in an availability-aware experiment must
declare `gap_contract = "strict_window"` (PIT-06-001). The feature series has
one row per open session with NA rows for missing sessions (PIT-06-002); a
window yields a value only when all its rows are complete (PIT-06-003).
Built-in SMA and returns use masked vector code, others run per window with
a parity check (PIT-06-004). Features ignore membership and restriction
(PIT-06-005) and never see stale or frozen marks (PIT-06-006). Feature
identity wraps the fingerprint with the gap contract (PIT-06-007); the cache
key reaches facts only through the snapshot hash (PIT-06-008). Only SMA
among TTR indicators is certified (PIT-06-009). Sweep and walk-forward
precompute from the same aligned bars and refuse a payload whose start
differs (PIT-06-010).

Contracts: Context Contract, Execution Contract.

## 7. Targets and sizing

What happens. The strategy returns a full named target vector over the axis
(PIT-07-001). Restricted IDs may only hold or exit (PIT-07-002); unrestricted
held nonmembers may hold or reduce (PIT-07-003). A raw increase on an ID
without a permissible mark stops the whole run INCOMPLETE with
`risk_mark_unavailable` (PIT-07-004), while the helpers would skip that ID
(PIT-07-011). The risk chain runs next; `ledgr_risk_max_weight()` uses the
risk mark (PIT-07-005). Post-risk targets may not grow or flip sign
(PIT-07-006), and no new short may open (PIT-07-007). Validation errors are
run-fatal (PIT-07-008).

Helpers read `ctx$vec$admissible` (PIT-07-009). `ledgr_target_rebalance()`
reserves held ineligible exposure and sizes the rest (PIT-07-010), skips
unpriced members and records `sizing_unavailable` (PIT-07-011; reader B
run C: MMM at s8 and s10), sizing from today's close only (PIT-07-012).
`ledgr_target_quantity()`, the signal helpers and `ledgr_passed_warmup()`
follow the same plane (PIT-07-013, PIT-07-015, PIT-07-017).
`ledgr_signal_strategy()`'s default `short_qty = -1` is refused under
availability (PIT-07-014). Top-n ties follow the collation locale
(PIT-07-016).

Contracts: Strategy Contract, Decision Axis And Eligibility, Availability
Contract, Execution Contract.

## 8. Execution

What happens. Each accepted target executes at the next session open at that
bar's open price, and the fill is stamped with the session open (PIT-08-001):
in the example the first fills are at 2021-03-02 14:30 UTC (09:30 New York)
for the s1 decision. A restriction resolved at the open blocks every fill,
exits included (PIT-08-002; reader B run A: FFF at the s14 open). A
membership change between decision and open does not block
(PIT-08-003). A missing next bar rejects the fill and the target is not kept
(PIT-08-004). Affordability accepts sells first, then buys, in C-locale order
(PIT-08-005); dense runs have no affordability check (PIT-08-006). Recorded
cash must reconcile, one `affordability_reconciled` row per pulse
(PIT-08-007; 40 in the example). Fills use observed opens only (PIT-08-008).
Availability runs are canonical R only (PIT-08-009). Configs record
`execution_timing_version = 2` (PIT-08-010). Diagnostics order their reasons
(PIT-08-011).

Contracts: Availability Contract (including its reason-token table),
Execution Contract.

## 9. Valuation

What happens. A per-instrument valuation state keeps the last finite close
observed at a pulse (PIT-09-001; no positivity check). Its age counts pulses
(PIT-09-002) and a mark is permissible up to `max_sessions` (PIT-09-003);
each axis ID gets one `mark_source` (PIT-09-004). The mark history starts at
the window's first pulse, so an opening or carried holding without a bar
there has no mark at all (PIT-09-005). Equity values holdings at the mark
(PIT-09-006).

Pulse order inside one availability pulse (PIT-09-007): post due
corporate-action cash, resolve the decision view and marks, post scheduled
dispositions, resolve lifetime terminals, stop or freeze exhausted marks,
write the equity row, then build `ctx`. A holding with no permissible mark
stops `valuation_horizon_exhausted` before its equity row under `refuse`
(PIT-09-008) or freezes under `freeze` (PIT-09-009, PIT-09-010); known
inactive holdings never freeze (PIT-09-011). Stale-mark use is recorded
(PIT-09-012; four `stale_mark_pass_through` rows in the example). Stop
evidence records affected exposure (PIT-09-013).

Contracts: Availability Contract, Persistence Contract.

## 10. Terminal outcomes and corporate actions

What happens. Every run builds a corporate-action plan from all sealed rows
under the experiment's policy, dense runs included; only availability runs
apply scheduled dispositions (PIT-10-002). Only five subtypes act
(PIT-10-001). Entitlement and effective clocks must land exactly on a pulse
inside the run (PIT-10-003). A row becomes due at the later of its posting
or effective pulse and its knowledge pulse (PIT-10-004); a row without a
knowledge time never becomes due (PIT-10-006, probe `I_ca_knowledge.R`).
Dividend cash posts at the entitlement pulse under the setting named
`effective_close` (PIT-10-005); the fixture puts entitlement on the close
before the ex-date, so HHH's $1 posts at s14 while its price drops at s15
(gross cash 10 in the example).

Entitlement is bound from positions before the entitlement pulse's fills in a
fresh run (PIT-10-007) but recounted from ledger events in a resumed run and
in the summary (PIT-10-008, PIT-10-021); the two differ when a fill executes
at the entitlement session's open. Cash posts once per fact (PIT-10-009).
Strict refusals fail the run (PIT-10-010). Quantity effects never change
positions, so spin-off recipients are never credited (PIT-10-011; JJJ is
never held). Scheduled acquisitions dispose at the mark, not the sealed cash
terms (PIT-10-012), before lifetime terminals (PIT-10-013). Held
`known_inactive` instruments resolve by exact label or the default
(PIT-10-014) at policy prices (PIT-10-015), posting one `DISPOSITION` each
(PIT-10-016). In the example five holdings are disposed: CCC and DDD by
scheduled rows, KKK, EEE and OOO by lifetime labels, all `last_permissible`.
Configs without a policy identity refuse terminals (PIT-10-017); schema-1
policies refuse execution (PIT-10-018). Dispositions are not trades
(PIT-10-019; zero closed trades in the example). The summary reports fidelity
and omitted value (PIT-10-020) and counts assumed outcomes (PIT-10-022; three
in the example).

Contracts: Availability Contract, Execution Contract, Result Contract,
Config Contract.

## 11. Persistence, completion, resume and reconstruction

What happens. A run that reaches its end, normally or by a typed stop, writes
one completion row with intended and achieved bounds (PIT-11-001). A soft
interrupt leaves it RUNNING with a committed prefix (PIT-11-002). A stop on
the first pulse stores one NA equity row per calendar pulse and cannot be
reopened (PIT-11-003). Rerunning an INCOMPLETE run ID returns the stored
evidence (PIT-11-004); RUNNING or FAILED rows with a completion row are
finalized only (PIT-11-005). Resume restarts after the last stored strategy
state, cutting events on the close clock (PIT-11-006), replays the ledger
(PIT-11-007; probe P4: interrupts at s15, s19 and s23 reproduce the fresh
equity and ledger exactly) and posts openings once (PIT-11-008). Errors after
registration record FAILED (PIT-11-009); resume refuses a changed config,
snapshot or timing version (PIT-11-010).

`ledgr_state_reconstruct()` rebuilds equity on the session calendar and
rewrites `equity_curve` (PIT-11-011; probe P5: identical on a DONE run,
readers unchanged), fails the cash identity on an INCOMPLETE run with events
after its prefix (PIT-11-012, PIT-11-013), and refuses a run with no valued
pulse (PIT-11-014).

Contracts: Persistence Contract, Result Contract, Availability Contract,
Execution Contract.

## 12. Results and readers

What happens. Readers open a stored run and project the ledger, equity and
diagnostics. Diagnostics come back in sequence (PIT-12-001). The
availability table is rebuilt after the fact from sealed facts, ledger
holdings and bars (PIT-12-002), and is synthetic for dense runs (PIT-12-003).
`ledgr_run_explain()` joins one decision with its availability row and
execution diagnostic (PIT-12-004). Fill rows carry a recording pulse derived
one way for durable runs and another for sweeps (PIT-12-005). `print` and
`summary` follow completion evidence and withhold annualized metrics for
incomplete performance (PIT-12-006), while `ledgr_compute_metrics()` does not
(PIT-12-007). The valuation summary classifies frozen, stale or current
(PIT-12-008; `stale` in the example) and one assumption warning precedes
metrics (PIT-12-009). Completion readers project the completion row
(PIT-12-010). `ledgr_run_open()` opens DONE and validated INCOMPLETE runs
only (PIT-12-011). `ledgr_run_compare()` excludes non-DONE runs (PIT-12-012).

Contracts: Result Contract, Persistence Contract.

## 13. Sweep, walk-forward and promote

What happens. A sweep candidate runs the same fold with an in-memory handler
and a portable provider; its final equity equals the durable run's (PIT-13-001;
probe P2). Availability sweeps refuse compiled accounting and dense feature
payloads (PIT-13-002). Rows carry status and completion JSON (PIT-13-003);
extraction refuses INCOMPLETE rows (PIT-13-004); only DONE rows rank
(PIT-13-005); saved sweeps persist all of it (PIT-13-006). Promotion
re-executes through `ledgr_run()` with the promoting experiment's universe and
policies and checks only the snapshot hash (PIT-13-007; probe P3: equity
identical to the run), writing its context after success (PIT-13-008).

Walk-forward selects only DONE candidates with a finite metric (PIT-13-009).
An INCOMPLETE test run ends the carry chain (PIT-13-010). Under
`carry_test_state` the next fold opens with the previous test run's cash and
holdings (PIT-13-011) and windows must be contiguous on session closes
(PIT-13-012). A rerun reopens finished test runs and resumes others
(PIT-13-013); PARTIAL folds are not extractable (PIT-13-014).

Probe `I_walk_forward.R`: with two anchored folds every test run's last
decision is dropped (`final_pulse_no_execution`, W1); flat and carried
openings differ as designed (W2); an interrupted session resumes under the
same `session_id` (W3); and with seven-day test windows the third test run
opens holding CCC with no mark history, stops on its first pulse with
`terminal_mark_unavailable`, stores three NA equity rows, and the same
`ledgr_walk_forward()` call then fails `ledgr_run_terminal_evidence_invalid`
(W4).

Contracts: Sweep Promotion Contract, Execution Contract, Persistence
Contract, Result Contract.

## 14. Identity

What happens. Instrument identity is the exact `instrument_id` string,
prepared by the adapter (PIT-14-001). Fact and set IDs are derived hashes
(PIT-14-002, PIT-14-003). Families are keyed by (family, scope)
(PIT-14-004). Any facts make the snapshot hash rule 2 (PIT-14-005).
`config_hash` binds the store-local `snapshot_id`, walk-forward `session_id`
binds `snapshot_hash` (PIT-14-006). The availability block enters
`config_hash` (PIT-14-007), as does a declared price basis (PIT-14-008).

Contracts: Snapshot Contract, Availability Contract, Execution Contract.

## Where paths differ

`path_matrix.csv` has one row per public entry point and path. In short:

| Path | Differs from `ledgr_run()` in |
| --- | --- |
| `ledgr_sweep()` | in-memory handler and provider; duplicated bar alignment; summary-only diagnostics; recording pulse from the opportunity index; clamped start (equity equal) |
| `ledgr_promote()` | re-runs through `ledgr_run()`; policies from the promoting experiment; config_hash differs from a direct run with the same params because candidate `feature_params` are stored (generic, not availability-specific) |
| `ledgr_walk_forward()` | windowed sweep and windowed run; final pulse of each test window dropped; carried holdings without mark history; rerun fails after a first-pulse stop |
| resume | entitlement recount from the ledger; otherwise identical in probe P4 |
| `ledgr_state_reconstruct()` | own calendar replay with no horizon check; writes `equity_curve`; fails after post-prefix events |
| readers | availability table rebuilt post hoc; summary entitlement by the resume rule; compute_metrics ignores completion |
| `ledgr_backtest()` | dense fold on a point-in-time snapshot |
| `ledgr_pulse_snapshot()`, `ledgr_indicator_dev()` | dense, facts ignored |
| facts-free snapshot | dense clock, fills stamped at bar time, no guards, synthetic reader |

## Terminology

One vocabulary used here, with the other words met in code, contracts and
docs.

| Term used here | Meaning | Also called |
| --- | --- | --- |
| availability-aware run | a run whose config carries an active availability block | point-in-time run (charter), PIT (audit), active config (code) |
| dense run | a run without that block | dense mode, canonical omission (contracts) |
| fact family | one normalized family keyed by (family, scope) | family, fact family header |
| knowledge mode | `evidenced` or `assume_effective` per family | `knowledge_assumption = "effective"` (metadata); `assumption_backed` (plan) |
| applicable | effective and knowable at the cutoff | "effective and knowable" (contracts) |
| session calendar | the sealed sessions family that drives pulses | calendar; not `ledgr_calendar()`, which is a metric annualization calendar |
| pulse | a decision time: an open-session close (availability) or a bar time (dense) | decision pulse, decision close |
| execution opportunity | the next in-window session open after a pulse | next open, execution open |
| window | the run's [start, end] in pulses | scoring range; hydration start and execution start (all equal today) |
| sealed range | bar minimum and maximum timestamps | `start_date`, `end_date` (snapshot metadata) |
| physical axis | the fold's fixed instrument IDs | instrument axis; `execution_universe` and `exp$universe` (code) |
| decision axis | members then held nonmembers at a pulse | Daxis (contracts), `ctx$universe` |
| members | provider members at the cutoff | M (contracts), `ctx$members` |
| restricted | status, lifetime or freeze restriction | target-restricted, ineligible (helpers) |
| eligible | member and not restricted | admissible (`ctx$vec$admissible`) |
| mark | the valuation price of a holding | risk mark (`ctx$vec$risk_mark`), reference (last close), `mark_source` |
| stop | a typed early end with status INCOMPLETE | soft stop, typed stop, terminal stop |
| disposition | a modeled terminal exit posted as `DISPOSITION` | terminal outcome, settlement (scheduled rows) |
| resume | rerunning an unfinished run ID | restart, recovery; finalization-only resume (C notes) |

Word clashes worth knowing:

- "Calendar" names both the sealed sessions family and the metric
  annualization calendars `ledgr_calendar()`, `ledgr_calendar_us_equity()`,
  `ledgr_calendar_crypto()`.
- `cash_posting = "effective_close"` posts at the entitlement clock, not the
  effective clock (PIT-10-005).
- `status_unknown_or_conflicting` is emitted only for conflicts; plain
  unknown is `status_unknown` (PIT-03-017).
- "Universe" is the experiment argument, the physical axis and, in
  `ctx$universe`, the decision axis.
- The fixture's entitlement clock is the close before the ex-date; the
  equity-settlement synthesis reads the entitlement clock as the ex-dividend
  boundary (reader C handoff; a fixture mapping question for Stage 3, the
  fixture is unchanged).

## Completeness

Every inventory rule appears in at least one path-matrix row. The frozen
NAMESPACE exports 168 functions; 107 appear as matrix entry points. The other
61 can touch a snapshot or store but carry no point-in-time semantics:

- Store and snapshot lifecycle: `ledgr_db_init`, `ledgr_validate_schema`, `ledgr_temp_store`, `ledgr_snapshot_list`, `ledgr_snapshot_close`.
- Run metadata: `ledgr_run_label`, `ledgr_run_tag`, `ledgr_run_tags`, `ledgr_run_untag`, `ledgr_run_archive`, `ledgr_run_strategy` (stored source), `ledgr_backtest_bench` (telemetry).
- Construction without data access: `ledgr_param`, `ledgr_param_grid`, `ledgr_parameters`, `ledgr_grid_add_baseline`, `ledgr_grid_cross`, `ledgr_grid_named`, `ledgr_strategy_grid`, `ledgr_strategy_preflight` (static check), `ledgr_target`, `ledgr_weights`, `ledgr_demo_sma_crossover_strategy`.
- Cost and risk steps whose availability behavior is in the fold rows (fill price base PIT-08-008; post-risk checks PIT-07-006, PIT-07-007): `ledgr_cost_chain`, `ledgr_cost_describe`, `ledgr_cost_fixed_fee`, `ledgr_cost_notional_bps_fee`, `ledgr_cost_spread_bps`, `ledgr_cost_steps`, `ledgr_cost_zero`, `ledgr_risk_chain`, `ledgr_risk_none`, `ledgr_risk_long_only`.
- Metric annualization and statistics over returns (no snapshot or provider access): `ledgr_calendar`, `ledgr_calendar_us_equity`, `ledgr_calendar_crypto`, `ledgr_metric_context`, `ledgr_metric_context_hash`, `ledgr_metric_us_equity`, `ledgr_metric_crypto`, `ledgr_risk_free_rate`, `ledgr_dsr`, `ledgr_pbo`, `ledgr_k_ratio`, `ledgr_min_track_record`, `ledgr_effective_trials`.
- Sweep objectives over result columns (status gating is PIT-13-005): `ledgr_business_objective` and the eight `ledgr_objective_*` functions.
- Other: `ledgr_sim_bars` (dense synthetic bars), `ledgr_iso_utc`, `ledgr_utc` (formatting), `ledgr_opening_from_broker` (always aborts), `ledgr_timing_next_open` (the single timing model; availability timing is `execution_timing_version`, PIT-08-010), `ledgr_feature_cache_clear` (cache keyed by snapshot hash, PIT-06-008).

S3 methods: `print` and `summary` for backtests are matrix rows;
`plot.ledgr_backtest` draws stored equity; `close` methods are lifecycle;
fact-object `print` methods belong to their constructors' rows. The internal
`ledgr_run_window()` and `ledgr_experiment_window()` are reached only through
`ledgr_walk_forward()` and `ledgr_precompute_features(start, end)`, both rows.

## Handoffs from the readers

Every handoff in `stage1/notes_*.md` was acted on or is recorded here.

| From | Handoff | Action |
| --- | --- | --- |
| A, B, C | fixture declares status for two instruments only | `status_coverage = "full"` option; default unchanged; PIT-03-015 |
| A | does the durable run read off-session bars | probed (P11): dropped; merged into PIT-04-010 |
| A | runtime treatment of zero or negative closes | read: any finite close is a mark; noted on PIT-01-009 and PIT-09-001 |
| A | subtype vocabulary; corporate actions without knowledge time | merged PIT-10-001; new probed row PIT-10-006 |
| A | clock mismatch; terminal label matching | PIT-10-003; PIT-01-014 and PIT-10-014 |
| A | run versus sweep start identity | probed (P10): run and promote unclamped, sweep clamped, equity equal; PIT-04-011 |
| A | config versus walk-forward identity base | PIT-14-006; no new probe |
| A, B | final pulse inside walk-forward test windows | probed (W1); merged PIT-04-007 |
| A | walk-forward contiguity calendar not clipped to bars | PIT-13-012 records the rule; the unclipped case was not probed (open) |
| A | does summary label assumption-backed runs | probed (P6): no; PIT-02-006 |
| A | dense versus point-in-time differences for the matrix | rows for `ledgr_snapshot_from_df` and the facts-free run |
| A | public window entry points | matrix rows for folds and precompute |
| B | activation overlap with subsystem 2 | merged B-002 with A-030; A-048 clause moved to PIT-03-004 |
| B | can one universe mix sets and intervals | read: `ledgr_facts()` refuses a second membership family per universe; noted on PIT-03-009 and PIT-14-004 |
| B | membership IDs outside the instrument master | refused at ingest (PIT-01-016) |
| B | calendar overlap (B-019, B-045) | merged into PIT-04-006 and PIT-04-009 |
| B | decision view versus corporate-action order (B-017) | merged into PIT-09-007 |
| B | marks feeding context and risk (B-030, B-051) | merged into PIT-09-006 and PIT-07-004 |
| B | spin-off recipients as held nonmembers in a basket | moot at 289d57c: recipients are never credited (PIT-10-011) |
| B | `ledgr_backtest()` path owner | probed (P13): dense on a point-in-time snapshot; new PIT-03-002 |
| B | tests pinning B-013, B-008, B-014 | none located; left for Stage 2 (g) |
| C | corporate-action `fact_id` rewritten at sealing | covered by PIT-14-002 |
| C | fixture entitlement clock versus ex-date | recorded under Terminology; fixture unchanged |
| C | execution reasons, affordability, next-open fills | covered by reader B rows PIT-08-001 to PIT-08-011 |
| C | carried holding without a first-pulse bar; walk-forward rerun after a first-pulse stop | probed (W4); PIT-09-005, PIT-13-011, PIT-13-013 now probed |
| C | parallel sweep parity with corporate actions; `next_open` with resume; promotion from a differently configured experiment | not probed (open) |

## Probes added by the integrator

All ran through `run_low.sh` on the frozen tree, each under 25 seconds:
`I_paths.R` (P1 to P13: run, sweep, promote, resume, reconstruct, readers,
declared status, fixed basket, dense, early opening, off-session bar, pulse
snapshot, `ledgr_backtest()`), `I_walk_forward.R` (W1 to W4: carry, flat,
interrupted rerun, carried holding without a first-pulse bar) and
`I_ca_knowledge.R` (K1: dividend without knowledge time). No stop condition
was met: 195 rules; no product change needed; nothing observed bears on
Workstream 22's byte identity (no hash comparison was in scope; the resume
probe reproduced the fresh run exactly); no finding needed a design decision.

## Flags for Gate 1

Oddities that most need the maintainer's attention, grouped. One line each;
not judged.

Path divergence

- `ledgr_backtest()` runs dense on a point-in-time snapshot, ignoring every declared family (PIT-03-002).
- Interactive contexts are dense on a point-in-time snapshot (PIT-05-009; `ledgr_indicator_dev()` in the matrix).
- Resume and the corporate-action summary recount dividend entitlement differently from a fresh run (PIT-10-007, PIT-10-008, PIT-10-021).
- Run and promote store an unclamped early opening start, sweep clamps it (PIT-04-011).
- `ledgr_compute_metrics()` reports annualized metrics that `summary()` withholds for INCOMPLETE runs (PIT-12-007, PIT-12-006).
- Promotion checks only the snapshot hash; universe and policies come from the promoting experiment (PIT-13-007).
- The public resolver and the runtime disagree on unknown membership and on session knowledge (PIT-03-010, PIT-04-006).
- Recording pulse derived two ways (PIT-12-005).

Recovery and finalization

- A first-pulse stop stores NA equity rows, cannot be reopened, and makes a walk-forward rerun fail (PIT-11-003, PIT-12-011, PIT-13-013; probed W4).
- Reconstruction rewrites `equity_curve` and fails the cash identity after a post-prefix fill (PIT-11-011, PIT-11-012, PIT-11-013).
- Resume cuts the event tail on the close clock while fills are stamped at the open (PIT-11-006).

Window boundaries

- Each window's final decision never executes, including every walk-forward test window (PIT-04-007).
- Mark history restarts at every window start, so carried and opening holdings can stop at once (PIT-09-005, PIT-13-011).
- A date-only window end drops that date's session; boundary checks use UTC dates (PIT-04-013, PIT-04-012).
- A calendar shorter than the bars shortens the run without warning (PIT-04-008).

Silent inputs

- Off-session bars seal and are then dropped without a diagnostic; the ingest report is discarded on success (PIT-01-005, PIT-04-010, PIT-02-003).
- Unknown corporate-action subtypes and rows without knowledge time seal and never act (PIT-10-001, PIT-10-006, PIT-01-018).
- No positivity rule for prices at ingest or valuation (PIT-01-009).

Eligibility and execution

- Partial trading-status coverage makes every uncovered instrument-time `status_unknown`; ownership unclear (PIT-03-015).
- A superseded status row revives after its superseder ends (PIT-03-014).
- An execution-time restriction blocks exits for `quotation_only` and `known_inactive` holdings (PIT-08-002).
- A raw target without a permissible mark stops the run; helpers skip the same case (PIT-07-004).
- `ledgr_signal_strategy()` default shorts are refused under availability; top-n ties depend on locale (PIT-07-014, PIT-07-016).

Corporate actions

- `effective_close` posts at the entitlement clock, one session before the fixture's price drop (PIT-10-005).
- Cash-acquisition terms do not price the disposition (PIT-10-012).
- Dense runs post dividends but never dispose acquisitions (PIT-10-002).
- Strict refusals end FAILED, terminal refusals INCOMPLETE (PIT-10-010).
- Dispositions never count as trades (PIT-10-019).
- Clocks between pulses refuse the run; an entitlement before the window never posts (PIT-10-003).

Ingest and knowledge clocks

- Membership and lifetime facts cannot be revised by a later-known row (PIT-01-010).
- Fact Dates mean UTC midnight; intraday closures cannot be evidenced; POSIXct session times are not checked against the date (PIT-01-019, PIT-04-002, PIT-04-003).
- Session constructors have opposite knowledge defaults; only the plan discloses assumption-backed families (PIT-02-007, PIT-02-006).
- An undeclared price basis runs with corporate actions (PIT-02-004).

Identity and contract text

- `config_hash` binds the store-local `snapshot_id`, not the content hash (PIT-14-006).
- Context planes and provider operations differ from the contract's lists (PIT-05-003, PIT-03-021); the inactive-snapshot message names the wrong activation rule (PIT-03-004).
