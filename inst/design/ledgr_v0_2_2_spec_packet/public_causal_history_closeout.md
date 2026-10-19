# Cut 16 Workstream 42 closeout: public causal history and continuous windows

Implementation commits: `c843dc2e` (LDG-3062), `a126a182` (LDG-3063),
`eb69aff3` (LDG-3064), `558811f2` (decision (16) completion) and the close
review correction commit that follows it, on branch `ws42/public-history` from
`a915ba66`. The close review is `close_review_42.md`.

Role: record; Workstream 42 implementation evidence.
Authority: non-binding. `tickets.yml` owns status and `contracts.md` owns
behavior.
Status: under review. LDG-3062, LDG-3063 and LDG-3064 are implemented and
evidenced. The close review returned `CHANGES_REQUIRED`; its findings are
corrected or routed below ("Close review corrections"). The one `NEEDS_TYPE_2` raised during implementation (whether the
data-start rule binds dense experiments) was answered by Cut 16 decision
(16) on 2026-10-18: availability only, dense frozen. Workstream 42 is
`review_pending`; nothing here is acceptance.

## Necessity and scope

Synthesis v12 Sections 2, 3 and 8 require one public causal history read for
availability-aware strategies, an external pulse inspection derived from an
experiment, and walk-forward test windows that form one economic chain. The
pre-cut tree had no public history read, a pulse constructor that needed the
caller to restate the universe and features, a per-window feature restart
with three hydration seams, and month folds that drifted from the anchor.

This workstream builds those surfaces on the Workstream 41 substrate. It adds
no reader beside the substrate, no dense history branch, no durable history
artifact and no feature-history semantics: indicator readiness, output carry
and calculation validity on treated inputs remain Workstream 43's.

## LDG-3062: one immutable history result

`ledgr_history_frame(ctx, feature, bar, lookback, instruments, na_action,
layout)` reads one bar field or one feature from `ctx$.history`, the history
view P1 attaches to the observation packet and P2 copies into the context
(`R/history-frame.R`, `R/fold-engine.R`). The view holds the substrate, its
column and the decision planes; it is a closure over prepared state, not a
second reader. `ledgr_history_matrix()` converts the result with no read and
no cutoff logic, and `ledgr_history_sufficient()` answers structural
completeness only.

The treatment primitive was split so one cell can be evaluated without the
whole prefix: `ledgr_history_carry_positions()` resolves the carry source and
last barrier, and `ledgr_history_input_carry_matrix()` is now the composition
of that and the value lookup. On 400 random cases the composition equals the
pre-split matrix exactly.

Only segments whose knowledge time falls after the cell's observation can
make a mask depend on the cutoff. The read service therefore prepares base
expected-session masks and carry positions once at knowledge `Inf` and, for
each instrument with late-known lifetime or terminal facts, one overlay per
knowledge epoch, held in the substrate's `history_memo`. A cutoff read selects
base or overlay columns and slices its window; it never re-treats the prefix.
Inactive-interval prints are shown raw with their inactive flag (v12
Section 4). Feature cells use the Workstream 43 seam: `calculated` equals
non-missing, input and output carry are false, and the reasons are
`not_calculated` or `not_expected`. (Superseded 2026-10-18 by Workstream 43
LDG-3067: in `6680bdb7` feature cells began reading the retained input- and
output-carry planes; in its Correction 1 they read every v12 Sections 5-6
state, with `calculated` as admission, `ready` as first-valid readiness and
`calculation_valid` as a ready finite value, and reasons `not_ready`,
`required_input_missing`, `carried_input_excluded`, `output_carry_expired`,
`output_carried` and `outside_calculation`; see
`indicator_history_closeout.md`.)

The result carries `data_start_utc`, `window_start_utc`, `cutoff_utc`,
requested and available lookback, source and policy identity, the selection
table (requested, included, exclusion reason, decision-axis and admissible
flags, carried counts and share) and `used_before_window`. Unknown explicit
IDs refuse with `ledgr_history_unknown_instrument`; a cutoff outside the
prepared axis refuses with `ledgr_history_outside_axis`; a dense context
refuses with `ledgr_history_unavailable`. P2 now hands availability strategies the schema-only
`ctx$feature_table`, which the contract allows, instead of materializing it
every pulse (the Workstream 41 routed finding).

Evidence: LTB-0297 (frame, matrix, scalar, selectors, empty shapes and a
hostile three-epoch instrument), LTB-0298 (every cutoff of a hostile
substrate equals the whole-prefix primitive cell for cell in forward and
shuffled order; finite suffixes; immutability), LTB-0299 (sufficiency and
estimation exclusion versus execution intent). Claims LCL-0292 and LCL-0293.

## LDG-3063: run, sweep, inspection and precompute agree

`ledgr_pulse_snapshot(exp, ts_utc, params, feature_params)` on an
availability experiment calls `ledgr_pulse_inspection()`
(`R/pulse-snapshot.R`). It builds the experiment's substrate to its end,
computes the payload from the data start to the cutoff, and executes the
shared fold through the sweep's candidate executor
(`ledgr_sweep_candidate_execution()`, factored out of
`ledgr_sweep_run_candidate()`) with a capture strategy. The capture signals
`ledgr_internal_pulse_inspection_capture` at P2 and unwinds before P3, so no
plan, fill, event or run row exists; a P1 stop refuses with
`ledgr_pulse_inspection_stopped`. The experiment is the configuration
authority: universe, features, cash, positions and state arguments refuse
with `ledgr_invalid_args`, and a dense experiment refuses with
`ledgr_pulse_snapshot_availability_required`. The snapshot-and-universe form
is unchanged.

`ledgr_precompute_features()` prepares availability payloads through the
substrate and records `history_axis` (normalized calculation start, cutoff,
session count and axis hash). A sweep validates that identity before any
candidate runs; dense and availability payloads cannot cross
(`ledgr_precomputed_feature_mismatch`). The warm-up feasibility table is
vectorized over instruments.

Evidence: LTB-0300 (literal session-6 history equal across run, sweep,
`run_window`, `sweep_window`, precompute and inspection; policy change moves
the inspected ctx), LTB-0301 (exact reuse, stale refusal before candidate
work, backward and reordered purity, mutation isolation), LTB-0302 (P1/P2
only, no strategy-side inspection, availability gating) and the extended
LTB-0293 structural detector. Claims LCL-0294 to LCL-0296.

## LDG-3064: one data start and one economic chain

Data start. `ledgr_history_calculation_start(substrate)` now returns the
substrate's data start. Runner, sweep, precompute and inspection calculate
features from it; the valuation state, `ledgr_results()` marks and
`ledgr_state_reconstruct()` read marks from the history calendar rather than
the first scoring pulse. `hydration_start_utc` (window argument and stored
fold column), `warmup_range`, `ledgr_unsupported_hydration_start` and
`ledgr_precomputed_hydration_mismatch` are removed; experiment-store schema
moves to 122 and schema-120 and schema-121 stores refuse through the existing
gate. Dense payload windows now refuse a different scoring start with
`ledgr_precomputed_range_mismatch`.

Carried chain. For `carry_test_state` on availability experiments,
`ledgr_walk_forward_continue_windows()` gives every test window but the last
a `final_execution_ts_utc` equal to the next window's first session. The
runner's run calendar appends that session's open as a final execution
opportunity (`ledgr_availability_run_calendar()`), so the window's last
decision fills inside the same run at the next open, and its finalizer bounds
on that instant. The next window opens from
`ledgr_walk_forward_carried_opening()`: cash and positions after that fill,
FIFO lots replayed from the ledger, every corporate-action row the window
bound but one run would settle later, and holdings frozen at the boundary.
The carried rows come from the window's own settlement plan
(`ledgr_corporate_action_plan()`), rebuilt from its ledger as a resume past
its last pulse would rebuild it, over its pulses plus the next window's first
pulse; the plan's `carry_out()` names each cash entitlement, disposition and
quantity effect whose posting, effective or knowledge clock falls after the
window. The next window's plan treats a passed clock as reached on its first
pulse and resolves knowledge as one run does (correction for close review
F1). Config validation requires the
carried lots to sum to the positions and frozen holdings to be in the
universe. Standalone runs and `flat_test_state` windows are unchanged.

Months. Rolling and anchored folds compute every boundary as anchor plus
`k * step` with month-end clamping (`ledgr_walk_forward_offset()`); no
boundary is derived from a clamped predecessor.

Evidence: LTB-0303 (two-fold carried walk-forward equals one run: boundary
fill of one AAA share at 16 on 2021-01-11 14:30 UTC, dividend 1.0 on two
shares at session 6, equity 1049, 1051, 1053, 1056, 1063, 1067, cash 1000,
1000, 1000, 985, 985, 1021, FIFO realized 16, equal diagnostics and
reconstruction; flat and standalone keep their terminal rule), LTB-0304
(run, sweep, `run_window`, `sweep_window`, promotion, precompute and
inspection read SMA 13.5 and BBB's stale mark 22 at age 2 at scoring session
4; one substrate per walk-forward session), LTB-0305 (twelve rolling and
anchored month folds from 2019-12-31 without drift or gap), the rewritten
LTB-0197, the store gate LTB-0260, the availability LTB-0196 and the dense
witness LTB-0306 (below). Claims LCL-0297 to LCL-0300; LCL-0196, LCL-0197 and
LCL-0291 updated.

## Decision (16): the data-start rule is availability-only

Implementation stopped on one `NEEDS_TYPE_2`. The ticket said "rewrite
LTB-0196/LCL-0196" for the single data-start rule, and v12 Section 10 item 9
and decision D4-F1 ("every indicator starts at the beginning of the data in
every run, sweep, walk-forward window and inspection") read as all modes,
while LTB-0196 was a dense fixture and v12 Sections 1 and 8, Cut 16 decision
(1) and the AGENTS dense-frozen rule forbid changing dense execution.

Cut 16 decision (16) (maintainer, 2026-10-18) binds the single data-start
rule and the carried walk-forward chain to availability experiments only;
dense stays frozen. Accordingly:

- LTB-0196/LCL-0196 now run a ten-session availability fixture (closes 30 on
  sessions 1-5, then 6..10) through `ledgr_run()`, `ledgr_sweep()` with and
  without a precomputed payload, `ledgr_promote()`, `run_window`,
  `sweep_window`, walk-forward training and experiment-derived inspection,
  all scoring from session 6. SMA(3) carried from the data start reads 22 at
  session 6, so a strategy holding while SMA(3) exceeds 10 ends at 1002, one
  holding once SMA(3) exists ends at 1003, training on sessions 6-8 ends at
  1001, and inspection reads 22. Restarted at session 6 those would be 1000,
  1001, 1000 and NA. Availability accepts only strict-window indicators
  until Workstream 43, so the recursive EMA witness stays dense-only.
- The Cut 9 dense literals move unchanged to LTB-0306/LCL-0300, the
  dense-frozen witness: every dense entry point still restarts features at
  its scoring start (finals 1001, training 1000).

## Test changes and their reasons

Every registered block changed only for an accepted v12 Section 2 rule:

- LTB-0296: run and fold literals flip because features now start at the
  data start (fill 2020-01-06 09:30, equity 100007, train equity 100003, test
  fill 2020-01-10 09:30); the old values are kept in a comment.
- LTB-0197: replaced by "history has one start and no hydration seam
  remains"; the second-start mutation fails it.
- LTB-0196: rewritten onto an availability fixture under decision (16);
  its dense literals move unchanged to the new LTB-0306, whose only edits are
  the retired field names (`warmup_range` to `scoring_range`, the stored
  hydration column now absent, the retired class replaced by
  `ledgr_precomputed_range_mismatch`).
- LTB-0218: the fixture's valuation policy moves from `ledgr_valuation_stale(2)`
  to a zero-session refusing horizon. Marks now read from the data start, so
  BBB's earlier close would value the first pulse under two sessions; the
  block's subject (a run that values no pulse) needs a pulse with no
  admissible mark.
- LTB-0258, LTB-0260 and the fold-witness block: schema 121 to 122; the golden
  catalogue differs only in the removed column and ordinal shifts.
- LTB-0255: the snapshot verification census gains `R/derived-state.R`, which
  now reads snapshot bars for data-start marks.
- LTB-0281: the observe packet's expected fields gain `history_view`, which
  P1 now issues (LDG-3062).
- LTB-0200: its hand-inserted fold row drops the retired
  `hydration_start_utc` column (schema 122).
- LTB-0206: asserts that a window has no `hydration_start_utc` field instead
  of pinning its value; the boundary resolution it protects is unchanged.
- LTB-0303 (close review F1): six late-known and next-pulse corporate-action
  cases are added against the one-run oracle; existing assertions are
  unchanged.
- Unregistered precompute and walk-forward fold and schema tests: retired
  field names and the replacement refusal class.

## Detecting evidence

Each mutation was applied to a source copy and the named blocks run; every
listed block failed and the copy was restored.

| Ticket | Mutation | Failing blocks |
| --- | --- | --- |
| 3062 | skip late overlay | LTB-0298 |
| 3062 | overlay knowledge at epoch start | LTB-0298 |
| 3062 | candidate pruning drops a late instrument | LTB-0298 |
| 3062 | window-seeded carry | LTB-0297, LTB-0298 |
| 3062 | carry value from the cell, not the source | LTB-0297, 0298, 0299 |
| 3062 | `used_before_window` never set | LTB-0298 |
| 3062 | feature width ignored | LTB-0298 |
| 3062 | explicit request drops inadmissible ID | LTB-0297 |
| 3062 | unknown IDs dropped | LTB-0297 |
| 3062 | inactive print hidden | LTB-0298 |
| 3062 | matrix rows reversed | LTB-0297, LTB-0298 |
| 3062 | sufficiency requires values | LTB-0299 |
| 3062 | sufficiency ignores instrument floor | LTB-0299 |
| 3062 | drop ignores admission | LTB-0299 |
| 3062 | future rows leak | LTB-0297 |
| 3063 | inspection ignores opening | LTB-0300, LTB-0302 |
| 3063 | inspection features from a different start | LTB-0300 |
| 3063 | inspection skips corporate actions | LTB-0300, LTB-0302 |
| 3063 | inspection runs the strategy | LTB-0300, LTB-0302 |
| 3063 | inspection reads the substrate directly | LTB-0293 |
| 3063 | experiment accepts extra configuration | LTB-0300 |
| 3063 | dense experiment allowed | LTB-0302 |
| 3063 | precompute ignores cutoff | LTB-0301 |
| 3063 | precompute ignores axis hash | LTB-0301 |
| 3063 | precompute stub definitions | LTB-0300 |
| 3063 | precompute dense engine version | LTB-0300, LTB-0301 |
| 3063 | dense sweep accepts availability payload | LTB-0301 |
| 3064 | second history start | LTB-0304; LTB-0197 |
| 3064 | marks from scoring start | LTB-0303 |
| 3064 | runner or sweep features from scoring start | LTB-0296, LTB-0304 |
| 3064 | inspection calculates from cutoff window | LTB-0197, LTB-0304 |
| 3064 | reconstruct or results marks window-local | LTB-0303, LTB-0304 |
| 3064 | substrate rebuilt per window | LTB-0304 |
| 3064 | no continuation | LTB-0303 |
| 3064 | continuation one session late | LTB-0303, LTB-0304 |
| 3064 | lots averaged | LTB-0303 |
| 3064 | pending entitlements not carried | LTB-0303 |
| 3064 | frozen holdings not carried | LTB-0303 |
| 3064 | next window from pre-fill cash | LTB-0303 |
| 3064 | flat windows continue | LTB-0303 |
| 3064 | month boundary from previous boundary | LTB-0305 |
| 3064 | test end from clamped start | LTB-0305 |
| 3064 | store format not bumped | LTB-0260 |
| 3064 | hydration field restored | LTB-0197 |
| 3064 | availability calculation start dropped | LTB-0196, LTB-0197 |
| 3064 | availability runner features from scoring start | LTB-0196 |
| 3064 | availability sweep features from scoring start | LTB-0196 |
| 3064 | dense run features from the data start | LTB-0306 |
| 3064 (F1) | carry only cash rows | LTB-0303 |
| 3064 (F1) | passed effective clock left unreached in the next window | LTB-0303 |
| 3064 (F1) | predecessor plan rebuilt without the next window's first pulse | LTB-0303 |
| 3064 (F1) | carried late-arrival flag dropped | LTB-0303 |
| 3064 (F1) | later knowledge clock ignored | LTB-0303 |
| 3064 (F1) | nothing carried | LTB-0303 |

Three first-round survivors were closed by strengthening the new blocks
before their commits: the overlay off-by-one survived until LTB-0297/0298
gained CCC's three-epoch history; the month shift survived until LTB-0305
asserted train starts; and a test run building its own substrate survived
while LTB-0304 counted only `ledgr_history_substrate_for_experiment()`, so the
block now counts the substrate constructor that every preparation path
calls (the training-sweep variant failed under both counters).

## Execution-mode branches added

The cut adds no new mode to the fold. Branch-count deltas against
`a915ba66` (`availability_active` or `is.null(history_substrate)` tests):

- Fold engine, one: P1 attaches `history_view` only when a history reader
  exists. Dense has no substrate to view.
- Runner, one: the preparation end comes from the availability run
  calendar. The final-execution branch the review found redundant is
  removed: the dense calendar has no `final_execution_posix`, so the spec
  receives `NULL` either way.
- Sweep, two: the payload mode mismatch refusal and the availability payload
  validation. Required by LDG-3063's "dense and availability payloads cannot
  cross".
- Walk-forward, two: carried opening and window continuation run only with a
  substrate. Decision (16) binds the chain to the availability path. This
  `is.null(history_substrate)` split is the only semantic mode branch the
  cut adds; it is listed for removal at execution-core consolidation, when
  dense leaves.
- Precompute, three: the availability payload path.

## Seven-shape walk

The changed read, inspection, precompute, run-calendar and walk-forward
functions were checked against the seven shapes in
`optimization_coding_style.qmd`. Numbers are from
`dev/bench/v0_2_2_public_history/evidence/` at 1,166 instruments by 7,213
sessions.

1. No frame grows a row at a time. A read builds its selection table and
   evidence matrices once; the carried opening builds its lot vectors once
   per boundary.
2. Prepare and index once. The read service prepares the base masks and
   carry positions once (first read 0.68 s, memo 96 MB beside a 580 MB
   substrate). Instruments with late-known lifetime or terminal facts get one
   overlay per knowledge epoch (116 built across 100 reads spanning every
   late epoch); every read then selects columns by index.
3. Column work is vectorized. Carry source values are read by linear index:
   a 252-session wide read costs 55 ms, long 52 ms and a 21-session read 7 ms.
   A full-lookback read costs 1.96 s because it materializes all 7,213 rows
   of values and evidence the caller asked for. Its allocation is about 8.6
   times the value bytes (close review F2): 139, 278 and 554 MB per read at
   cutoffs 1,803, 3,606 and 7,213, against 16, 32 and 64 MB of values.
   Reading the default (`lookback = Inf`) on every pulse is therefore
   quadratic over a run: roughly 2 TB of allocation and an estimated 8,200 s
   added to a 131 s run at this shape. Strategies should pass a finite
   lookback (routed below).
4. No row-wise JSON or hashing in hot paths. The precompute axis hash is
   computed once per payload. One stated exception: rebuilding the
   predecessor's settlement plan for the carried rows parses each window
   event's metadata, as the plan does on resume, once per carried fold.
5. Candidate-invariant work happens once per owning operation. One
   substrate serves a whole walk-forward session (LTB-0304 counts the
   constructor), and sweep staging resets the read memo. Each
   experiment-derived inspection prepares its own substrate and payload
   (three inspections plus a frame took 28.1 s), because inspection is an
   external one-off call.
6. No pulse operation scans the full axis. Strategy reads slice a suffix of
   prepared planes; the Workstream 41 whole-prefix helper, 2.8 s per call at
   this shape, is not called by any pulse path. A strategy reading 21
   sessions every pulse and 252 sessions with `drop_instruments` monthly adds
   about 5 ms per pulse to the run (168.0 s against 131.0 s).
7. One representation. Reads, inspection and precompute use the
   availability substrate; dense keeps its pre-cut representation.

New loops, each with its reason: the per-lot opening loops
(`R/fold-event-buffer.R`, `R/lot-accounting.R`) run once per carried
boundary over open lots; the overlay loop in `ledgr_history_cutoff_planes()`
(`R/history-frame.R`) runs per read over requested instruments whose last
late-known lifetime or terminal fact lies after the cutoff; and the month and
continuation loops run over folds. The review measured the overlay loop
(close review F3): 58 iterations per read at cutoff n/2 with 5 percent
late-known instruments and 583 with 50 percent; a 21-session read cost 21 ms
against 8 ms after the epochs at 5 percent and 69 ms against 10 ms at 50
percent, with memos of 101 and 145 MB. The count stays high for most of the
history when late facts are spread over it. If LDG-3070's real-data count is
material, overlays should be grouped by epoch and written by index.

## Scale

Arms: `a915ba66` exported with `git archive` and the candidate tree, each
loaded with `pkgload` and building its own snapshot of the H1-shaped
fixture (1,166 instruments, 7,213 sessions, 580 membership sets, 16 folds).
One workload ran per process, sequentially. Another agent was running tests
on this host, so elapsed times are disclosure, not gate evidence; the same
candidate walk-forward ran in 411 s and then 212 s.

| Workload | a915ba66 | ws42 | Note |
| --- | --- | --- | --- |
| build and seal | 224.5 s, 3,811 MB | 219.0 s, 3,801 MB | |
| run, no history reads | 133.6 s, 2,153 MB | 131.0 s, 2,235 MB | equal final equity |
| sweep, 3 candidates | 347.0 s, 1,967 MB | 322.0 s, 1,975 MB | equal final equities |
| walk-forward, 16 carried folds | stops at fold 2 (70.1 s) | 16/16 folds, 211.8 s, 2,258 MB | see below |
| explicit precompute | refuses | 13.3 s, 1,863 MB | availability payload is new |
| run with history reads | n/a | 168.0 s, 2,235 MB | equal final equity |
| three inspections | n/a | 28.1 s, 2,226 MB | 252 x 599 last frame |

Heap figures are R's allocation high-water mark since the workload started.

The baseline walk-forward stops at fold 2. Its carried test run opens with
holdings at the test start, and its window-local marks have no admissible
mark for a held instrument without a first-pulse bar, so the run values no
pulse and the session ends `PARTIAL`. Marks read from the data start remove
that failure; this is the LDG-3064 behavior, not a timing effect.

## Routed, not fixed here

Proposed owners pending maintainer confirmation; none changes a WS42 result.

- Substrate planes no public read consumes: `expected`, `halted`,
  `missing_expected_bar` and `inactive_print`. The read service derives
  expected masks from segments, so for instruments without late facts the
  base mask duplicates `expected`. LDG-3069 owns staged memory and can drop
  or reuse them.
- Feature-cell evidence is the Workstream 43 seam (LDG-3065/LDG-3066):
  readiness, output carry and calculation validity replace the placeholders.
  (Carry was replaced in `6680bdb7` (LTB-0318); WS43 close review F2 found
  readiness, validity and reasons still placeholders, so the route stayed
  open until WS43 Correction 1 (2026-10-18) replaced them; registered
  detectors LTB-0318 and LTB-0319.)
- Realized PnL remains per run (each window's result reports its own
  realized trades); the chain equality is on events, equity, cash, lots and
  diagnostics. (The earlier cash-only carry route is superseded by the F1
  correction.)
- Default full-lookback reads (close review F2): teaching "pass a finite
  `lookback` inside strategies" to LDG-3071; the eager evidence
  representation (lazy or on-request evidence planes, logical rather than
  character reason planes, no per-plane transpose) to LDG-3069, or to the
  maintainer if it needs a v12 Section 3 reading.
- Late-known overlay loop (close review F3): LDG-3070 to report the
  real-data count of instruments with late-known lifetime or terminal facts.
- Private context carrier (close review F4): `ctx$.history` holds the read
  service and therefore the whole substrate. A strategy reading
  `ctx$.history$service$substrate$bars` can see future bars and still passes
  `ledgr_strategy_preflight()` as `tier_1`. The contract now says so. A
  preflight rule rejecting strategy access to dot-prefixed context internals,
  and a check whether `environment(ctx$feature)$projection` reaches future
  values, go to the strategy-preflight owner as a proposed follow-up; it is
  not a few-line change inside LDG-3062's Context Pulse Data contract, so it
  is not implemented here.
- `ledgr_history_substrate_treated_field()` remains a whole-prefix helper used
  by tests and the oracle; no pulse path calls it.

## Close review corrections

`close_review_42.md` (Type 1) returned `CHANGES_REQUIRED` on one product
defect and four record items.

- F1 (high, corrected): a corporate action effective in one carried test
  window but known in a later one was dropped by the chain (one run disposed
  of BBB at 2021-01-12; the chain never did). The walk-forward driver no
  longer decides settlement timing: the carried rows come from the
  predecessor's own settlement plan, as described under LDG-3064, and cover
  cash entitlements, dispositions and quantity effects. LTB-0303 now also
  compares one run and the chain on a late-known dividend and acquisition
  (final equities 1064.5 and 1063), a refused spin-off and a strict
  acquisition that both stop at session 7 (1058), and a next-pulse dividend
  and acquisition across a boundary fill (1070.5 and 1070). LCL-0297's scope
  is widened accordingly.
- F2, F3 (recorded and routed): see the seven-shape walk and "Routed, not
  fixed here".
- F4 (recorded and routed): the contract and LDG-3062's acceptance and
  evidence text now name the private `ctx$.history` carrier; the preflight
  rule is routed.
- F5 (records): refusal classes corrected here and in `tickets.yml`; trailing
  whitespace removed from `evidence/frame_probe_h1.txt`; the LTB-0281,
  LTB-0200 and LTB-0206 reasons added; `contracts.md`'s Units, Price Basis
  And Universe no longer calls the selectors pending; the redundant runner
  branch removed and the walk-forward split listed for removal.

## Verification record

- Full suite on a source copy of the committed LDG-3064 tree
  (`testthat::test_local(load_package = "none")` after `pkgload::load_all()`):
  1,123 blocks, 0 failures, 0 errors, one optional-package skip (Yahoo
  missing-package path, quantmod installed), 10.9 minutes. The pre-cut
  baseline at `a915ba66` was 1,114 blocks with no failures; the LDG-3063
  commit state was 1,120 blocks with no failures.
- After decision (16) (availability LTB-0196 plus the dense witness
  LTB-0306), the full suite on a fresh source copy: 1,124 blocks, 0 failures,
  0 errors, the same optional skip, 11.2 minutes.
- After the close review corrections, the full suite on a fresh source copy:
  1,124 blocks, 0 failures, 0 errors, the same optional skip. The host
  carried other load, so no timing is drawn from it.
- Mutations: every row of the table above, each on a source copy of the
  tree it belongs to.
- Codebase census regenerated (`tools/check-codebase-contracts.R
  --mode=report`: 74 connections, 158 versions, 80 run configs, 1,768
  helpers, 2,381 condition sites, 71 findings, the same per-family finding counts as before); fold-phase
  checker `LEDGR_FOLD_PHASE_CONTRACT_OK`; `tickets.yml` and `claims.yml`
  parse; no `_problems` artifacts. (The review found trailing whitespace in
  `evidence/frame_probe_h1.txt` that this record had missed; it is removed and
  `git diff --check a915ba66..HEAD` is clean after the correction.)
- Not run here, by instruction: the timed fast, review and heavy profiles,
  which the coordinator runs on a quiet host, and `R CMD check`.

Durable evidence is under `dev/bench/v0_2_2_public_history/evidence/`.
Scratch snapshots and source copies are not evidence.
