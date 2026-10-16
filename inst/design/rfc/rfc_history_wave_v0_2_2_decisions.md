# Decision Register: WS3/WS4 History Wave

Role: living; current decision register for the active WS3/WS4 history wave.
Status: stage 4 accepted; stage 5 ticket cut is current
Authority: working register. Accepted maintainer decisions are inputs to the
accepted v12 successor; this register does not itself supersede v11.

Opened 2026-10-08. Records the maintainer's
decision on every finding of the
[Type 2 review](rfc_history_wave_v0_2_2_review.md) of the
[proposal](rfc_history_wave_v0_2_2_proposal.md). The register changes no
accepted synthesis until stage 3 writes and accepts the amendment.
**Owner:** maintainer decides; executor verifies and drafts.

## Resume here

**Stage 4 (H4) is accepted.** Cut 15, the reviewed H0 drift map, the H1
real-data input record and the H2 evidence wave are complete. Sessions D, E
and F, the H0 questions and every remaining consider row were decided on
2026-10-16 after two focused peer-review passes. The consolidated
[v12 synthesis](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md)
now carries those decisions. Its H4 final review returned eight Type 1
document findings and no Type 2 question; the focused confirmation returned
`PASS_AFTER_PATCHES`, its two bounded corrections are applied, and the
maintainer accepted v12 on 2026-10-16. Resume with the H5 ticket cut. The joint gate in the
[current macro-plan order](../ledgr_v0_2_2_spec_packet/macro_plan.md#7-remaining-order)
is satisfied; everything needed is linked below.

The stage-3 successor to
[historical-projection v11](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md)
is the first application-specific supersession carrier required by the
[governance-lifecycle synthesis](rfc_governance_lifecycle_v0_2_2_synthesis.md)
Sections 4 and 7. The history wave owns that consolidated v12 synthesis; this
register does not apply it early. The detailed execution route and the
maintainer's 2026-10-16 reason for using a successor rather than another
amendment layer are in the
[macro plan](../ledgr_v0_2_2_spec_packet/macro_plan.md#history-wave-execution-plan).

**Current real-data input (2026-10-15):** the Cut 15 WS39
[schema-120, rule-3 aggregate record](../../../dev/bench/v0_2_2_sharadar_run/evidence/ws39_schema120/README.md)
is the pre-history Sharadar build. Its cold verification and full-membership
plus dynamic-membership availability-path probes pass on one snapshot
identity. It opens no schema-119 store and includes no dividend facts. It is
the current history-wave input now that the joint gate is satisfied.

H1 extends that record in `ledgr-research` commit
`e07e89d5eb14237d6975170a7306fb56f7267cf2`,
`experiments/history-wave-h1/` (final independent verdict: PASS). It records
post-adapter gaps and fact coverage, current phase timings, a one-run
whole-stage working-set peak, and a representative two-worker process-tree
peak. The memory peaks are coarse lower bounds from one host and one run; H6
must repeat the same measurement boundary before applying a percentage gate.
Two source captures provide negative correction-chain evidence only.

**Decided so far** (details in the rows):
- Session 0: the [research strategy UX brief](../ledgr_v0_2_2_spec_packet/research_strategy_ux_brief.md)
  is the WS3 history API direction (`ledgr_history_frame()`,
  `ledgr_history_matrix()`, exclusions kept). V12 must reconcile it
  with v11's `ctx$window()`.
- A: history reaches back to the start of the data; shorter lookbacks on
  request; every read strictly point-in-time (columns s <= t, facts knowable
  at t); decisions only on scoring pulses.
- B: every indicator starts at the beginning of the data in every run, sweep,
  walk-forward window and inspection. Every supported built-in and TTR
  indicator must work on ragged and dense universes; WS4 owns the five
  blockers listed under Session B.
- C: pragmatic clocks. Facts without a knowledge clock are known when
  effective, disclosed; interval membership is single-clock, snapshot sets are
  the two-clock path; lifetime corrections deferred with a trigger.
- Sharadar goal: the full available S&P span, 1998-2026, runs without stops;
  the adapter drops carried zero-volume bars (LFB-027).
- Durable factor and prediction evidence is routed downstream, not into WS3:
  v12 preserves the identity needed to join future decision evidence
  to history, while capture, retention and reopening remain a separate RFC.
- Mode (maintainer, 2026-10-14; accepted release-line authority `4397f58f`):
  history is built on the availability path only. Dense mode is frozen and
  leaves through the execution-core consolidation before the first CRAN
  release. B's "dense universes" means full membership on the availability
  path. This later decision supersedes Cut 15's earlier both-modes wording.
- E: one immutable prepared substrate replaces the three current bar copies;
  fact-state families use provenance-preserving bitemporal segments; staged
  ordinary-R inputs serve each sweep daemon; `mori` is not adopted; the
  supported claim covers one and two local workers; and paired H6 records,
  not the coarse H1 values, apply the 10% memory gate.
- H0: availability-aware pulse inspection runs preparation plus P1 and P2;
  history defaults to the admissible set with explicit inclusion evidence;
  shorter lookbacks are suffixes of the single data-start preparation; venue
  Dates, session narrowing, price-basis defaults and clockless actions are
  bound below.
- D: every supported indicator has a bounded or history-dependent class;
  `requires_bars` is the bounded dependency width; recursive state restarts
  over treated-input segments; return and volatility families never consume
  carried prices; custom definitions receive exact sampled causality and
  refutation checks.
- F: correction chains use monotone knowledge, interval coverage, no revival,
  ancestor-only exemptions and one rule across construction and runtime.

**Still open:** no H2 semantic decision. Accepted v12 expresses the decisions
below without reopening them. H5 implementation and H6 measured resource and
full-history acceptance evidence remain open under Cut 16.

**Next steps:**
1. Complete the Cut 16 review and obtain maintainer acceptance of its H5
   tickets.
2. Implement stage 5 and close H6. The later dividend-facts rebuild stays
   with its existing adapter/WS7 owner.

**Evidence index:**
- Proposal, review: [proposal](rfc_history_wave_v0_2_2_proposal.md),
  [Type 2 review](rfc_history_wave_v0_2_2_review.md).
- Spikes: [two-clock history](../spikes/two_clock_history_spike/closeout.md)
  (with `sharadar_census.csv`, `sharadar_vintage_diff.csv`) and
  [recursive-indicator history](../spikes/recursive_indicator_history_spike/closeout.md)
  (with `fragility.csv`).
- Stage 1 checks: `dev/design-checks/history_wave_stage1/` (probes, TTR gap
  behavior, burn-in, speed).
- Adapter and long-run state: [Sharadar adapter survey](../ledgr_v0_2_2_spec_packet/sharadar_adapter_survey.md).
- H0 reconciliation: [v11 current-tree drift map](rfc_point_in_time_historical_projection_v11_current_tree_drift_map.md)
  and its [independent review](rfc_point_in_time_historical_projection_v11_current_tree_drift_map_review.md)
  (final focused verdict PASS at `16f415cd`).
- H1 real-data inputs: `ledgr-research` commit `e07e89d`,
  `experiments/history-wave-h1/README.md` and `review.md` (final verdict PASS).
- Memory baseline: [long-window Cut 3 baseline](../ledgr_v0_2_2_spec_packet/long_window_cut3_baseline.md)
  (peak 512 MiB at 252 pulses to 3,832 MiB at 6,056 pulses, 600
  instruments); Cut 5 removed about 14%; EXP-0003 peaked at 7.0 GB on 0.2.1.0.

## Stages

| Stage | What | Exit | State |
| --- | --- | --- | --- |
| 1 | Verify | Every finding's premise rerun or read at `e38b0d7`; result in the Verified column | done 2026-10-08 |
| 2 | Decide | Every row has a decision or a recorded deferral, in the order of the sessions below | done 2026-10-16; H0-H2 and Sessions A-F complete |
| 3 | Supersede | One consolidated v12 synthesis carrying retained v11 rules, the accepted register decisions and the post-Cut 15 architecture under `../rfc_cycle.md`; the RFC index routes its review | accepted 2026-10-16 |
| 4 | Final review | Type 1 review of v12 against the drift map, this register, current contracts and the current tree | done 2026-10-16; `PASS_AFTER_PATCHES`, bounded patches applied |
| 5 | Ticket cut | Cut 16 in `tickets.yml`; cut review; pipeline obligations leave `README.md` | drafted 2026-10-16; cut-review corrections current |

Values: Verified is `confirmed`, `corrected` (premise partly wrong; note says
how) or `refuted`. Decision is `pending`, `accept`, `accept with change`
(note), `reject` (durable reason), `defer` (trigger) or `route` (owner).

Stage 1 evidence: [`dev/design-checks/history_wave_stage1/`](../../../dev/design-checks/history_wave_stage1/)
holds the reviewer's probes rerun (`probe_d2_d5`, `probe_d2_partial`), the
executor's checks (`claims`, `burnin`) with outputs, and the adapter read
(`adapter_membership.R`, against the installed `ledgr.sharadar`).

### Stage 1 summary

- 36 rows: 33 confirmed (D4-F4 stronger than stated), 2 corrected (D5-F1,
  X-F2), 1 refuted (X-F5).
- **D5-F1 drops from blocking.** The Sharadar adapter never emits interval
  membership: `sharadar_ledgr_membership_intervals()` aborts with
  `sharadar_membership_intervals_prohibited`, and membership is emitted as
  complete snapshot sets with effective = knowledge = the availability
  instant. The one-day leak is real only for user-supplied interval facts
  whose end rides on the start row.
- **X-F5 is refuted.** `ledgr_sweep_compute_feature_matrix` is called only by
  tests; production sweeps compute through precompute and the runner, both of
  which branch to the strict path.
- **D4-F4 is stronger than stated.** `ledgr_ind_ema` is not `strict_window`
  either, so availability mode refuses ledgr's own EMA, not only TTR's.
- **New input for D4.** Decaying indicators restarted later become
  bit-identical to the full-history series after a finite burn-in: 226 bars
  for EMA(14), 489 for RSI(14), 859 for EMA(50) on a 3,000-bar walk. Path-
  dependent ones (running max) never do.

## Session 0: public history API

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| UX-1 | blocking | The public history surface is proposed in the [research strategy UX brief](../ledgr_v0_2_2_spec_packet/research_strategy_ux_brief.md) but not adopted; v11 s3 binds `ctx$window()` while the brief proposes `ledgr_history_frame()` outside `ctx` | confirmed: brief status "Active, non-binding" | Adopt the brief; reconcile with `ctx$window()` in the amendment | **accept** (maintainer, 2026-10-08): the brief is the WS3 history direction. The amendment reconciles it with v11's `ctx$window()` and settles the brief's remaining open names |

### Routed downstream obligation: durable factor evidence

External practitioner feedback recorded as research finding `LFB-028` asks
for the factor or prediction used for ranking to remain traceable through
selection, weights, target intent, costs, execution and outcome. ledgr already
owns durable downstream economic evidence, but not that coherent research
chain.

This does not expand WS3 into an artifact store. The stage 3 amendment must
only keep the history contract compatible with a later evidence owner: a
future record must be able to identify the run or candidate, decision pulse,
instrument, history cutoff, feature or model identity, and the inclusion or
exclusion decision without inventing a second point-in-time history contract.
The future evidence RFC decides capture, schema, retention, reopening and
paper/live use after WS3/WS4 is accepted. Model fitting and artifact lifecycle
remain with the ML RFC. The parked upstream record is the 2026-10-10 durable
factor entry in `../horizon.md`; no API, schema or release commitment is made
here.

## Session A: what history a strategy sees

Decides everything after it. Amends v11 section 3.

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| X-F1 / D4-F2 | blocking | Public history axis undecided: a 252-day read at the first scoring pulse returns 251 NA; WS7 sees mostly NA in short test windows | confirmed: v11 s3 says columns count "consecutive prepared decision pulses", early requests have leading NA, "no hidden fetch of pre-range history", hydration "may supply a carry seed without expanding the public axis"; `ctx$window()` and `ledgr_history_*` do not exist yet | Option (a): history axis = prepared pulses from the hydration start; decision axis = scoring pulses; causal, s <= t | **accept with change** (maintainer, 2026-10-08): history reaches back to the start of the data; the user may request any shorter lookback; every history read is strictly point-in-time (as of the decision pulse: columns s <= t, facts knowable at t). Decisions occur only on scoring pulses |
| D1-F6 | consider | The representation can answer s > t (facts known before effect) | confirmed: a status fact known day 2, effective day 5 is accepted; Sharadar listed seven splits five days ahead | History API refuses s > t; columns are s <= t | **accept** (maintainer, 2026-10-08), as part of the as-of rule above |

## Session B: one hydration rule

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D4-F1 | blocking | Two hydration rules create a per-feature clock identity and inspection cannot carry | confirmed: one `hydration_start_utc` per window (`R/walk-forward-folds.R:583-592`), one per fold row (`R/walk-forward.R:803`), one `warmup_range$start` per payload (`R/precompute-features.R:200-261`). New input: decaying indicators reach bit-exact parity after a finite burn-in | One rule: feature state starts at the snapshot start for every entry point and class; bounded shortcut only as a proven exact optimization | **accept** (maintainer, 2026-10-08): every indicator starts at the beginning of the data in every run, sweep, walk-forward window and inspection |
| D4-F3 | should-fix | Cut 9 oracle must flip to the carried arms; dense bounded parity is about 1e-12 under two rules | confirmed: LTB-0196 asserts restart and documents the carried values (`tests/testthat/test-feature-start.R:28-35`); dense SMA(20) cross-start gap 2.91e-12, strict built-in identical | Flip LTB-0196 expectations under the single rule | **accept** (follows from D4-F1) |
| X-F4 | consider | Pulse inspection reproduces hydration only under one rule | confirmed: `ledgr_pulse_snapshot()` computes each series over bars up to the cutoff (`R/pulse-snapshot.R:285-300`) | Follows from D4-F1 | **accept** (follows from D4-F1) |
| X-F5 | consider | Sweep feature-matrix helper may take the dense path in availability mode | refuted: called only by `tests/testthat/test-sweep.R`; production uses `R/precompute-features.R:632` and `R/backtest-runner.R:1039`, both strict-branching | No decision needed; optionally delete the test-only helper | **accept with change** (H2): delete `ledgr_sweep_compute_feature_matrix`; keep its three fold-projection oracles by moving their fixture construction to the production precompute path, without weakening their prebuilt-view or mutation-isolation assertions |
| D4-F4 | should-fix | History-dependent indicators are refused in availability mode, so WS7 on a PIT universe has no EMA/RSI/ATR/MACD | confirmed and stronger: refusal is anything not `strict_window` (`R/availability-policy.R:246-269`); `ledgr_ind_ema` is not `strict_window`, nor are bounded TTR functions other than SMA | Decide: v0.2.2 scope statement, or WS4 decides the gap rule | **decided** (maintainer, 2026-10-08): every supported indicator, built-in and TTR, must work on both ragged (availability) and dense universes in v0.2.2. WS4 owns the gap rule and the remaining blockers (see "B blockers" below) |
| D4-F5 | consider | `ledgr_check_no_lookahead` is never called; full-history hydration spreads a lookahead | confirmed: defined at `R/features-engine.R:487`, used only in `tests/testthat/test-features.R` | Sampled build-time causality check beside D3's refutation | **accept with change** (H2): exact prefix invariance at fixed deterministic positions for every concrete definition before artifacts; the sample rule is fixed and reproducible and failure refuses with a classed condition before any store write. Experiment-data window refutation applies only to custom bounded definitions, as Session D specifies |
| D4-F6 | consider | Stance on convergence for readiness and structural completeness | confirmed (no premise); burn-in measurement above is relevant | `stable_after` stays first-valid; convergence undisclosed in v0.2.2 | **accept with change** (H2): `stable_after` means first-valid, never converged; teach the distinction and the measured recovery ranges. Structural completeness is a separate finite-lookback plus minimum-instrument query, not readiness |
| C11-F1 | should-fix | `ledgr_folds_rolling()` started on the 31st of a month builds non-contiguous test windows: month arithmetic from day 31 overflows, so a one-month step from 2019-12-31 leaves 2020-05-01 between two test windows | confirmed by the Cut 11 LDG-2977 oracle (2026-10-08); since LDG-2979 `carry_test_state` refuses such a list, `flat_test_state` still runs it with the gap | Fix the constructor's month arithmetic (clamp to month end) in the WS3/WS4 cut, which owns window and history starts; routed by the maintainer 2026-10-08 | **accept with change** (H2): compute every rolling and anchored boundary from the original anchor plus `k * step`, then clamp to that result month's last civil day; never shift the preceding clamped boundary |
| PIT-S2-007 | should-fix | Walk-forward `carry_test_state` boundaries are not state-continuous: a `next_open` dividend whose entitlement is a window's last pulse never posts, and carried holdings have no mark history, so one without a bar on the next window's first pulse stops the test run at once | confirmed by the point-in-time audit Stage 2 (S2-007, probes `S2_wf_dividend`, `I_walk_forward` W4) and its challenger; the dropped last decision is the stated per-window rule | Mark history and entitlement belong to the same history-start decision as feature hydration; routed by the maintainer at audit Gate 2, 2026-10-10 | **accept with change** (H2): `carry_test_state` is one economic chain; the deciding run owns the following-open fill, economic state crosses the boundary, and feature, mark and entitlement history come from the shared substrate. Standalone and flat windows retain their terminal rule |
| PIT-S2-011 | consider | Fact Dates and date-only window boundaries mean UTC midnight, not the venue's civil date: one Date fact blocks an open fill in New York but not in Sydney, and Honolulu windows shift one session | confirmed by the point-in-time audit Stage 2 (S2-011, probe `S2_venue`) and its challenger | Decide venue civil dates (session open) or explicit UTC instants only, with the window and history-start rules; routed by the maintainer at audit Gate 2, 2026-10-10 | **accept with change** (H2): availability-path Dates are venue civil-session labels: effective starts and exclusive ends resolve to that session's open, knowledge Dates to its open, and window starts/ends to session open/close. POSIXct remains exact; ambiguous Dates refuse. Stored facts preserve the original value, resolved instant, venue zone and calendar identity; D3-F5 owns identity. Dense UTC-midnight behavior stays frozen |
| PIT-G-013 | should-fix | v11 price-input carry (on by default, five sessions) will feed repeated prices into return and volatility features, so carried sessions contribute zero returns; a minimum-variance estimator then understates the variance of exactly the halted names the adapter exposes (LFB-027) | point-in-time audit Stage 3 (gap_analysis.md G-013; yardstick U4.4, U7.2) | The stage 3 amendment binds how input carry meets return-family features: bridge last valid to next valid, or no carry for them by default; the carried share travels with the history result and WS7 consumes it; routed by the maintainer at audit Gate 3, 2026-10-10 | **accept with change** (H2 Session D): return and volatility families never consume carried prices and silently bridge nothing; affected outputs are missing, carried share remains disclosed and WS7 consumes it. A span-labelled bridged-return feature is parked with the Sharadar gap census as its reopening trigger |
| PIT-G-014 | should-fix | Widens PIT-S2-007: under `carry_test_state` the last decision of each test window is also dropped (`final_pulse_no_execution`); the chain is not one run with scheduled parameter switches | point-in-time audit Stage 3 (G-014; yardstick U8.4, S36), probe `I_walk_forward` W1 | Decide whether a continuous carry chain equals one run (handing the last decision to the next window's first open) or state the non-equivalence in the Execution Contract; take the window-dependent corporate-action clock refusal (G-012) with it; routed at audit Gate 3, 2026-10-10 | **accept with change** (H2): continuous carry must equal one public `ledgr_run()` with parameter switches at the same decision pulses on events, equity and diagnostics; a boundary decision is terminal only at the end of the whole chain |
| PIT-G-015 | should-fix | Decision A speaks of strategy reads; mark history and dividend entitlement also start at the window start, so carried holdings and new entrants lose pre-window marks | point-in-time audit Stage 3 (G-015; PIT-04-014, PIT-09-005) | The history-start decision names mark history and entitlement beside feature history; Session E trims the decision trace (C11-F2) only where omitted rows are exactly reconstructible and `ledgr_run_explain()` still answers; routed at audit Gate 3, 2026-10-10 | **accept with change** (H2): feature, mark and entitlement history all start at the single data start and are read from the common substrate; only cash, positions, lot state, pending entitlements and frozen or stale mark status carry as economic state |

### B blockers: every indicator on ragged and dense universes

Verified 2026-10-08 (`dev/design-checks/history_wave_stage1/`). These become
WS4 decisions and tickets:

1. **TTR refuses gaps.** `TTR::SMA`, `EMA` and `RSI` stop with "Series contains
   non-leading NAs" on one interior missing value. Ragged universes have gaps
   (halts, missing prints, late listings), so a TTR indicator cannot be called
   on an instrument's raw series.
2. **No gap rule for history-dependent indicators.** The strict path computes
   bounded indicators window by window and skips incomplete windows; an
   EMA-style recursion has no window to skip. Needs a decision: short gaps
   filled by v11 s5 price carry (default five sessions), and what happens after
   a longer gap (proposal: the indicator restarts its warm-up after the gap).
3. **Certification is narrower than the evidence.** Only built-in SMA and
   returns, TTR SMA and custom indicators declaring `strict_window` run in
   availability mode. Bounded indicators such as `ledgr_ind_ema` (an n+1
   filter), TTR WMA, ROC, momentum, MFI, CMF, CCI and the run* family are not
   declared. Declaration plus tests per function.
4. **The strict path does not scale.** For custom and TTR indicators it calls
   the indicator once per window per instrument
   (`R/features-engine.R:291-347`); at 32 years and about 1,200 instruments
   that is millions of R calls per feature. Compute per contiguous segment
   instead. Measured (`speed.R`): a full-history TTR EMA over 8,000 bars takes
   1.6 ms, about 2 seconds for 1,200 instruments; the per-window path takes
   about 3 seconds per instrument, about an hour per feature.
5. **Multi-output TTR works** through `output =` (for example BBands `up`); not
   a blocker.

## Cut goal: 32-year Sharadar history without stops

Maintainer, 2026-10-08: the wave's goal is to make ledgr usable with 32 years
of Sharadar history. No rule may stop a run on something that happens often in
real data. Every fact rule touched by this wave is tested empirically against
the full Sharadar history before its decision is accepted, and an end-to-end
32-year run is an acceptance gate of the cut.

Maintainer, 2026-10-08, after the adapter survey:
- **Span:** 1998-01-02 to 2026-09-04, about 28.7 years. The lake holds full
  daily split-adjusted prices for S&P members only from 1998
  (`ledgr-research` adoption check, EXP-0003 correction); "32-year" above
  means the full available history.
- **Carried zero-volume bars (LFB-027):** the Sharadar adapter drops them, so
  untraded sessions arrive as missing observations and ledgr's own carry,
  staleness and freeze rules apply. This changes the snapshot hash.
- **Real-data stoppers in v0.2.2:** three ledgr-side failures from EXP-0003
  (`ledgr-research` feedback log) become one small workstream, independent of
  the history design and able to run in parallel with WS3/WS4:
  - LFB-017: an eligible member without a price on the decision session no
    longer aborts the run. It is skipped for that rebalance (no new position;
    an existing holding is kept) and the skip is recorded.
  - LFB-023: walk-forward gains an explicit per-fold policy for a fold with no
    selectable candidate instead of aborting the session; the policy and its
    use are recorded.
  - LFB-018: a run that exits early after its row is created ends `FAILED`
    with the interruption as its error, not `CREATED`.
- **Adapter patches** (eight, in `ledgr-research`, none in ledgr) precede the
  Sharadar census: vendor terminal reasons, dropping carried zero-volume bars,
  explicit stale policy, retiring the 0.2.1.0 diagnostic replica,
  reconciliation helpers aware of disposals and freezes, re-pinned artifacts,
  ledgr pinned by commit, runner window sizing.

## Session C: knowledge clocks the history must carry

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D5-F1 | should-fix (was blocking) | Interval membership end applies on its effective date though known a day later; honest encoding refused | corrected: mechanism confirmed (fold drops X on day 10; open TRUE then open FALSE refused), but the production premise is wrong: the Sharadar adapter prohibits intervals and emits complete snapshot sets with equal clocks | Decide: add optional `end_knowledge_time` to interval facts in WS3, or document intervals as single-clock and snapshot sets as the two-clock path | **decided** (maintainer, 2026-10-08, "be pragmatic"): document interval membership as single-clock (its end is known when its start is) and complete snapshot sets as the two-clock path, which the Sharadar adapter already uses; no `end_knowledge_time` in this wave |
| D5-F2 | should-fix | Lifetime deferral needs v11 section 9's reopen trigger and precise wording (only opposing overlaps refused) | confirmed: same-assertion restatement accepted, opposing refused | Defer with trigger: acquisitions merged into bitemporal lifetime facts | **defer** (maintainer, 2026-10-08, "be pragmatic"): lifetime corrections reopen when acquisitions are merged into bitemporal lifetime facts (v11 s9); state that only opposing overlaps are refused |
| D5-F3 | consider | "Treats a correction as a later-known fact" is true of storage, not rules | confirmed | Reword | **accept** (maintainer, 2026-10-08, "be pragmatic"): say the representation, not the rules, treats a correction as a later-known fact |
| D1-F7 | should-fix | Sessions and corporate actions as known at t uncovered; 82 CA backfilled in 16 hours | confirmed: corporate actions carry optional `knowledge_time`, sessions carry it under evidenced knowledge (`R/availability-facts.R:36-50`); the spike covered neither | Decide: extend segments to CA and sessions, or ship barriers at the diagonal with a stated reason | **decided** (maintainer, 2026-10-08, "be pragmatic"): corporate actions and sessions without a knowledge clock use known-when-effective (`assume_effective`), disclosed in results; the representation keeps a slot for real knowledge clocks when a source supplies them |
| X-F3 | should-fix | Carry barriers depend on lifetime and CA at t | confirmed: v11 s5 barriers use knowable `known_inactive`, corporate actions and terminal assertions | Name the dependency in the amendment | **accept** (maintainer, 2026-10-08, "be pragmatic"): the amendment names the dependency of carry barriers on lifetime and corporate actions at t |
| X-F2 | should-fix | Feature-value revision (v11 7(d)) has no owner | corrected: the macro plan's WS3 owns "numerical correctness at the history boundary"; what is missing is the proposal's stance | WS3 stance: one prepared series per feature and policy; revision unexercised in this release; keep v11 section 8 fixtures as an obligation | **accept** (maintainer, 2026-10-08, "be pragmatic"): WS3 states the stance; revision is unexercised by Sharadar in this release; v11 s8 detecting fixtures stay an obligation |

## H0 questions closed in H2

The reviewed
[v11 current-tree drift map](rfc_point_in_time_historical_projection_v11_current_tree_drift_map.md)
exposed these choices. H0 deliberately did not answer them; H2 disposed of
each one after the evidence wave and focused peer review.

| ID | Sev | Question | Current evidence and owner | Decision |
| --- | --- | --- | --- | --- |
| H0-Q1 | should-fix | Does history carry treat an omitted price basis as the effective assumed `split_adjusted` model, or as an undeclared-basis conservative barrier, and what enters history identity? | The 2026-10-11 maintainer amendment makes omitted basis economically and visibly `split_adjusted` while identity remains `NULL`; on the availability path `NULL` reaches that assumed model. V11's carry-barrier rule predates the amendment. | **accept with change** (H2): omitted basis uses the disclosed assumed `split_adjusted` model and creates no barrier; identity retains `NULL`. The history-treatment implementation version enters identity under v11 Section 5 and D3-F5 owns the resulting rule advance |
| H0-Q2 | should-fix | Are instrument-narrowed expected sessions rejected, deferred, or bound; if bound, how are they cutoff-resolved, aligned to the common axis, and how do they treat observations inside inactive intervals? | Owned today by the RFC pipeline `instrument-specific-session-axis` row and the WS3 macro-plan bullet. V11 says no request window may choose the inactive-interval treatment silently. H2 must dispose of both owners. | **accept with change** (H2): one common public axis plus a cutoff-resolved expected-session mask per instrument. Lifetime-inactive absence is structural, not missing; trading-status halts remain gaps. Prints inside knowable lifetime-inactive intervals remain readable with a structural flag and inclusion evidence but enter no computation segment and supply no mark. This closes the pipeline row |
| H0-Q3 | should-fix | Does history support a knowable corporate action with neither entitlement nor effective clock; if so, what class, parent, fields and timing refuse it? | Ingest currently permits both optional clocks to be absent; execution maps the missing clocks to `NA` and never posts the action. `ledgr_invalid_corporate_action_event` currently covers only a non-finite entitlement-recount delta. | **accept with change** (H2): a row without knowledge time is audit-only and never due. A row with knowledge time but neither event clock refuses preparation at every cutoff on or after knowledge with `ledgr_corporate_action_clock_missing`, parent `ledgr_invalid_corporate_action_event`; fields name `fact_id`, `parent_instrument_id`, `knowledge_time`, `entitlement_time` and `effective_time`, and the message says to supply a clock or quarantine the row |
| H0-Q4 | blocking | How does pulse inspection satisfy availability-only history parity? | `ledgr_pulse_snapshot()` is a separate dense one-pulse helper outside the fold, with its own SQL and non-strict feature path. H2 must either bind an availability-aware inspection route or assign a different owner; it must not claim the current helper already shares the fold. | **accept with change** (H2): availability-aware `ledgr_pulse_snapshot()` runs shared preparation, P1 observe-and-settle and P2 context construction at one cutoff, with no P3-P5, run row or store write. Its data planes equal a run's first pulse under the same inputs and opening. The frozen dense branch remains until execution-core consolidation; add no new dense-only path |
| H0-Q5 | should-fix | What is the default estimator row set, including held nonmembers, and how are inclusion and exclusion represented? | V11 keeps held nonmembers on the decision axis and does not exclude a past observation merely because membership was inactive then. The UX brief proposes `instruments = "admissible"` but leaves selector vocabulary and exclusion representation open. | **accept with change** (H2): default `instruments = "admissible"`; also accept `"decision_axis"` and explicit known IDs. Unknown explicit IDs refuse. Results name requested, included and excluded IDs and every exclusion reason. Estimation exclusion never means liquidation; omitted holdings remain until a separate target says otherwise |
| H0-Q6 | consider | What may seed the first column of a shorter lookback under the one data-start rule? | Sessions A and B supersede the old public-axis hydration mechanism, no-second-warmup rule and `0 x lookback` shape. V12 still needs an explicit shorter-lookback carry-seed statement without creating a second history start. | **accept with change** (H2): lookback counts expected venue sessions on Q2's common axis, oldest to cutoff. Return the suffix of the one data-start preparation; seed nothing independently. Record data start, window start, cutoff, requested and available span, and whether any bounded or history-dependent result used observations or state before the returned window |

History identity remains with D3-F5 rather than a duplicate H0 row. That row
must decide whether history inputs and the hydration change require an
identity-rule or store-format bump; rule 3 is current authority, not a promise
that no bump is needed.

Three adjacent v12 clauses follow from these answers. Structural completeness
is a finite requested lookback plus a minimum included-instrument count and is
separate from feature readiness. One history call requests one feature; wider
multi-feature projection stays outside this surface. The accepted Q2 rule
closes the RFC pipeline row for instrument-specific expected sessions.

## Session D: indicator history class

H1 threshold input: inside observed instrument spans there are 1,000 missing
sessions in 746 runs: 612 one-session runs, 93 two-session runs, 33 runs of
three to five sessions, three runs of six to ten, and five runs of eleven to
twenty. This is one vendor/universe and chooses no tolerance or history class.

H2 evidence input (2026-10-16): the reviewed
[indicator-history conformance spike](../spikes/history_indicator_conformance_spike/closeout.md)
records 34 default outputs and eight algorithm variants. Classification is per
family, output and algorithm-changing argument: six default outputs retain
earlier state, while EMA/SMA variants change the class of several families.
Every sampled prefix was causal. Hostile level-shift fixtures show that small
floating drift cannot define the class, and the observed Aroon witness needs
eleven rows despite `n = 10`. Gap-recovery ranges vary by family and gap
position. The spike supplies evidence; H2 made the decisions below after
focused peer review.

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D3-F1 | should-fix | `strict_window` already means bounded; the TTR default contradicts it | confirmed: contracts say the declaration "commits the definition to a finite window with no internal carry"; `ledgr_ind_ttr("SMA")` is `strict_window` | strict_window implies bounded; refuse the contradictory pair | **accept with change** (H2): every supported definition is `bounded` or `history_dependent`; `strict_window` implies bounded and contradictions refuse. Undeclared custom definitions default to disclosed `history_dependent`; bounded is declared, never inferred |
| D3-F2 | should-fix | TTR class belongs in the warmup rules table, per function | confirmed for testable single-output rows: WMA, ROC, momentum, MFI, CMF, runMean/SD/Var/MAD gaps <= 1e-15, CCI 1.15e-11 (float noise); ATR, MACD, BBands, aroon, DonchianChannel need `output` (multi-column) | Bounded vs history-dependent per row; verify each against TTR source | **accept with change** (H2): classify registered TTR forms per function, output and algorithm-changing argument in a package-tested catalogue; unregistered TTR forms follow the custom-definition rules |
| D3-F3 | should-fix | Refutation belongs in the strict path, against the full series once | confirmed: strict scalar compares `fn(window)` with `tail(series_fn(window))` per window of `stable_after` (`R/features-engine.R:291-347`) | Compare `fn(window_i)` with `series_fn(full)[i]` | **accept with change** (H2): exact deterministic prefix invariance applies to every concrete definition; experiment-data window-versus-prefix refutation applies to custom bounded definitions only, using `requires_bars` as the window |
| D3-F4 | consider | Refusal must name instrument, position and gap, with a product tolerance | confirmed (no premise) | Accept | **accept with change** (H2): custom checks are exact unless the definition declares a nonzero tolerance; refusal names instrument, position and gap. Bundled catalogue rows have no runtime product tolerance |
| D3-F5 | consider | Does `history_class` enter identity, and do history inputs or the hydration change require an identity-rule or store-format bump? | confirmed: current `ledgr_active_feature_fingerprint()` carries `gap_contract` (`R/features-engine.R:85-94`); `R/feature-cache.R` was deleted in Cut 15 | Feature fingerprint beside `gap_contract`; decide the current-format effect rather than presupposing rule 3 remains sufficient | **accept with change** (H2): fingerprint history class, `requires_bars`, gap and restart behavior, readiness, custom tolerance, TTR version and algorithm-changing arguments; history treatment enters config identity. Advance run/config identity and refuse old resumptions. Keep snapshot hash rule 3 unless stored representation changes; H6 compares fresh builds and records the rebuild cost |
| D3-F6 | consider | Define bounded testably | confirmed (no premise) | A function of the last `stable_after` bars only | **accept with change** (H2): a bounded output is a function only of the last `requires_bars` expected sessions on Q2's per-instrument mask. `requires_bars` is the existing dependency width and the window handed to `fn`; `stable_after >= requires_bars` remains the first-valid boundary. Add no third width field |
| I-F3 | consider | Spike B's 1e-9 is a 120-bar fixture tolerance | confirmed: dense SMA(20) 2.91e-12 at 3,000 bars; TTR SMA 9.95e-14; BBands 1.14e-13 | State a basis for any product tolerance | **accept with change** (H2): promote no spike drift into a product tolerance. Built-ins are exact; bundled rows are certified by registered hostile-fixture package tests that record measured drift and TTR version; custom nonzero tolerance is explicit and fingerprinted |

### H2-bound gap and certification rules

- A bounded definition receives the last `requires_bars` expected sessions.
  An incomplete required window produces missing output.
- A history-dependent definition restarts on each contiguous segment of
  treated input. Treated input includes observations plus values carried by
  v11's declared price-input policy, except for the return and volatility
  families below. Restart, rather than skip, is the disclosed v0.2.2 policy.
  Lifetime-inactive intervals split segments structurally; halts and missing
  observations beyond the carry horizon create gaps. Prints inside a knowable
  lifetime-inactive interval enter no segment.
- Return- and volatility-family definitions never consume carried prices.
  Their output is missing wherever a required input is missing or carried.
  V0.2.2 ships no silent multi-session bridge. Consequently one missing
  session can exclude an instrument from a 252-session complete estimator
  window for 252 sessions. A span-labelled bridged-return design reopens only
  from the parked Sharadar gap census. History results retain carried-share
  disclosure and WS7 must consume it.
- Prefix invariance is exact, deterministic and checked before any artifact
  write. User-data window refutation is for custom bounded definitions only.
  Catalogue definitions are certified by package tests rather than re-derived
  on every user's data.

## Session E: storage details and budget

H1 resource input: the representative 7,213-pulse run records native phase
times of 6.92 seconds pre, 38.55 seconds loop and 0.06 seconds post. The whole
stage, including source loading, snapshot copy and cold verification/open,
peaked at 3,106.50 MiB parent working set. A two-candidate/two-worker sweep
peaked at 8,957.23 MiB in the parent and 14,945.56 MiB across the sampled
process tree. These are coarse one-host lower bounds sampled about every 2.3
seconds; summed working sets may double-count shared pages. They set an order
of magnitude, not the budget or representation. H6 must repeat the same
boundary before applying a percentage gate.

H2 evidence input (2026-10-16): the reviewed
[mirai attribution spike](../spikes/history_mirai_payload_attribution/closeout.md)
finds that current candidate tasks repeat about 45 MB of immutable input at the
registered synthetic shape. Staging that input once per persistent daemon
reduced sampled parent-plus-daemon working set 10.6% and private commit 15.0%,
with no speed claim. The reviewed
[mori feasibility spike](../spikes/history_mori_feasibility/closeout.md) proves
exact atomic-leaf sharing and Windows cleanup, but rejects adoption for the
current two-worker design: the structural saving ceiling is only one extra
44.9 MB copy, about 3--4% of the roughly 1.3 GB sampled total, matching the
observed 3.1%. Rebuilding `bars_mat` and `static_bars_views` was worse than
sharing them; rebuilding `pulses_iso` stayed cheap. Promise-retained payload,
unique RSS/PSS and POSIX orphan cleanup remain unmeasured. These results choose
no budget or public representation by themselves.

### Session E decisions

Accepted by the maintainer on 2026-10-16 after a focused peer review of the
evidence-backed proposals. The review accepted E2, E3 and E10 as proposed,
relabeled E9 as current behavior, and narrowed E1 and E4--E8. It requested no
further spike.

1. **E1, canonical prepared substrate.** Build one immutable history substrate
   once per snapshot identity and preparation policy before any fold, and
   share it across the run, all sweep candidates and all walk-forward windows.
   Fact-state families (trading status, membership and lifetime) use flat
   bitemporal segment vectors per instrument and family. Bar and feature
   panels are stored once as observation-time columns on the common axis, with
   a knowledge-clock slot where the source supplies one; revised observations
   remain unexercised in this release. Candidate and window cursors remain
   outside the immutable object. This substrate replaces, rather than sits
   beside, `bars_by_id`, `bars_mat` and `static_bars_views`. Reads are
   vectorised across instruments. Public history frames and the matrix adapter
   are temporary views over the substrate, not retained copies or independent
   readers.
2. **E2, provenance-preserving merge.** Adjacent fact-state segments merge
   only when state, winning fact and reason all match. Equal visible states do
   not erase the evidence that selected them.
3. **E3, state and declaration.** Preserve active, inactive, unknown and
   conflicting membership states. Family declaration and completeness travel
   separately from fact rows; completeness is a property of the snapshot fact
   set, not the presence of an individual row.
4. **E4, segment guard.** During preparation, count segments per instrument
   and fact family and refuse when the count exceeds
   `max(4 * facts, 16)`. The refusal is classed and names the instrument,
   family, fact count, segment count and ratio. Never truncate. A declared
   experiment-level override exists; v12 decides its name and placement, and
   D3-F5 owns whether it changes the identity rule. Like other declared
   assumptions, it enters canonical config identity. Record aggregate and
   maximum counts per family. A full Sharadar build census must confirm the
   default before acceptance; refusal of that reference build is a defect in
   the default. This guard protects preparation shape and is not the memory
   budget.
5. **E5, worker transport.** Prepare candidate-invariant inputs once in the
   parent and stage them once on each persistent daemon of a sweep. Tasks carry
   candidate-varying fields and the expected staged-invariant identity. A
   daemon verifies that identity and refuses a missing or different invariant
   with a classed condition. Per-sweep daemons stop on exit or interruption,
   so staged state never outlives the sweep and discard-all interruption stays
   unchanged. Sequential, current and staged arms must agree on final equity,
   trade count, seed, snapshot, strategy and reproduction-key hashes. This is
   private executor machinery: no public strategy API, executor abstraction
   or new dependency.
6. **E6, no `mori` adoption.** Add no `mori` dependency in v0.2.2. The E1
   saving ceiling was measured at 160 instruments and is not an H1-scale
   claim. After E1 removes the duplicate bar representations, H6 computes
   `(workers - 1) * staged_invariant_bytes / total_private_commit` on the H1
   Sharadar workload. Reopen shared memory only if that share is at least the
   10% E8 ceiling. If reopened, share the bar substrate rather than rebuilding
   it and rebuild only `pulses_iso`.
7. **E7, supported parallel envelope.** Claim the availability-history
   workload for one and two local workers, the shapes measured by H1 and H6.
   Larger worker counts continue to run but are disclosed as unmeasured in the
   sweep record. Worker count and resource settings never enter experiment,
   candidate or run identity; they belong in run evidence and telemetry. Add
   no override argument. Dense-mode and non-history sweeps are unchanged.
8. **E8, paired memory gate.** A history-enabled build may not exceed the
   current-tree baseline by more than 10% for any of: single-run parent peak,
   two-worker parent peak, or the sum of parent and daemon peaks. H6 measures
   both arms as paired runs on one host and the same H1 workload, using the
   same approximately 0.2-second process sampler and the median of three
   repeats. Parent gates use working set and private commit; the process-tree
   gate uses private commit and discloses summed working set as a lower bound.
   The H1 values record scale, not limits. Report preparation- and fold-phase
   peaks separately, live substrate bytes, worker count, instruments, pulses,
   bars, facts and segments. A breach is corrected or accepted explicitly by
   the maintainer with a user-visible limitation and routed follow-up.
9. **E9, decision trace.** Preserve the full logical trace. Its durable writer
   continues to stream bounded typed chunks, and sweep workers continue to
   return compact summaries rather than the trace. The trace is not part of
   the history substrate or worker payload. Physical compression remains
   deferred until omitted rows can be reconstructed exactly without changing
   `ledgr_run_explain()` answers. H6 measures the read-side cost of loading the
   full diagnostics trace and routes any material problem to WS8.
10. **E10, evidence boundaries.** Interval membership remains single-clock;
    complete snapshot fact sets remain the two-clock path, with no diagonal
    carve-out. Earlier evidence covers status, membership, late-known starts
    and lifetime, not sessions, corporate actions or end clocks. One Sharadar
    acquisition plus synthetic lag is not evidence about rare restatement.

The WS3 cut and H6 carry failure-sensitive oracles for the staged-identity
check and the single-copy bar representation. H6 also owns the full Sharadar
segment census, paired fine-sampler baseline, post-E1 `mori` trigger
calculation and read-side decision-trace measurement. These obligations are
acceptance evidence, not reasons to introduce another public resource API.

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D1-F9 | should-fix | Memory budget must be set before the representation is accepted | confirmed: macro-plan decision 8 requires a phase baseline and a budget for one run and a representative parallel workload; the Cut 9 single-run baseline exists, a parallel baseline does not | Maintainer sets the WS3 budget in this session; record the missing parallel baseline as a WS3 ticket | **accept with change** (E8): paired H6 baseline and 10% gate; H1 values are scale only |
| D1-F1 | should-fix | Size guard must be named, overridable, with recorded counts | confirmed (design point) | Accept | **accept with change** (E4): `max(4 * facts, 16)`, declared override, counts and full-build census |
| D1-F2 | should-fix | Production build and read shape (spike shape is an antipattern) | confirmed: `spike_build` rebuilds the provider per global epoch, appends data-frame rows; `spike_query` scans all segments | Per-instrument epochs, flat vectors, cursor re-seek, vectorised reads | **accept with change** (E1): one immutable substrate replaces all three bar representations; cursors remain outside it |
| D1-F3 | should-fix | Merging equal states loses deciding-fact evidence | confirmed: the lifetime plane carries `lifetime_fact_id` and `terminal_event` per segment (`R/availability-provider-prepared.R:246-256`) | Merge on (state, winning fact, reason) | **accept** (E2) |
| D1-F4 | should-fix | Membership has four states; parity oracle is the resolver plus `members_at` | confirmed: `members_at` returns `key[state]` only (`R/availability-provider-prepared.R:91`) | Accept | **accept** (E3) |
| D1-F5 | should-fix | Family declaration travels apart from rows | confirmed: default keys on `has_status` (`R/availability-provider-prepared.R:243`) | Accept | **accept** (E3) |
| D1-F8 | consider | Diagonal parity needs a carve-out if the end clock lands | confirmed; moot if D5-F1 chooses documentation | Follows from D5-F1 | **accept with change** (E10): no carve-out; interval membership stays single-clock and complete snapshot sets stay two-clock |
| I-F1 | should-fix | Evidence wording overclaims "no restatement" | confirmed: one acquisition; the only knowledge clock is a synthetic one-day lag | Guard exists because the shape is unmeasured | **accept with change** (E10): retain the evidence boundary; do not infer rare-restatement behavior |
| I-F4 | consider | State what spike A discharged | confirmed | Accept | **accept** (E10): status, membership, late-known starts and lifetime only |
| C11-F2 | consider | Decision-trace volume drives diagnostic memory: availability runs write one `decision_recorded` row per member per pulse, about 3.6 million (momentum) and 4.2 million (equal-weight) rows on the 1998-2026 Sharadar runs, including pulses where the strategy holds | measured in Cut 11 LDG-2976 (`dev/bench/v0_2_2_sharadar_run/evidence/run1`); Workstream 22 removes the sweep's quadratic copy (F4) but not the volume | Decide with the memory budget whether the default decision trace stays per member per pulse; changing it changes what `ledgr_results(bt, 'diagnostics')` and `ledgr_run_explain()` show, so it is a design decision, not an optimization; routed by the maintainer 2026-10-08 | **accept with change** (E9): retain the full trace and bounded streaming; measure read-side cost in H6 and route material cost to WS8 |

## Session F: correction chains

H1 supplies negative evidence only: two captures expose current-list redates,
contraticker-only same-key changes and one hard-coded terminal replacement,
not empirical correction chains. The source has no trading-status facts.
Session F therefore decides from requirements and the vendor-neutral matrix;
H1 cannot close the chain rules by absence.

H2 evidence input (2026-10-16): the reviewed
[correction-chain spike](../spikes/history_correction_chain_spike/closeout.md)
executes ten vendor-neutral chain shapes through the constructor, validator,
prepared resolver, ingest classifier and, where accepted, public run. It
confirms that direct full and partial replacements run; a monotone three-link
chain can be refused despite deterministic resolution; precedence is applied
after supersession; a partial successor can revive its predecessor; and the
ingest classifier can truncate that revival and disagree with runtime. The H1
Sharadar captures still contain no real trading-status chain, so they remain
negative vendor evidence rather than a policy oracle.

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D2-F4 | consider | Route chains out of the WS3 wave | confirmed: Sharadar has no trading-status facts; the validator runs on the seal path (`R/availability-persistence.R:587`) | Small facts ticket under the Cut 3 exact-byte oracles | **route** (H2): a small prerequisite facts workstream before the history substrate, under the existing exact-byte oracles. The full-Sharadar condition is satisfied vacuously because that source contains no trading-status facts; the vendor-neutral ten-shape matrix is the semantic oracle |
| D2-F1 | blocking | Chain learned out of order: resolver says `conflicting` | confirmed: f1 known 3, f2 known 8, f3 known 5 answers `conflicting` on days 5-7 (the probe's "day 8.5 unknown" line is an artifact: `day(8.5)` lands on day 9, outside the interval) | Constructor rule: superseder knowledge >= predecessor knowledge | **accept** (H2): every successor's knowledge time is at least its direct predecessor's; the constructor, validator, classifier and resolver enforce the same rule |
| D2-F2 | should-fix | Exempt ancestor pairs, not whole components | confirmed: two facts superseding f1 and disagreeing are refused today and resolve `conflicting` | Accept | **accept with change** (H2): only direct and transitive ancestor/descendant pairs receive the supersession exemption. Siblings and unrelated descendants compete normally; tied contradiction refuses |
| D2-F3 | should-fix | Resolver revives a predecessor; ingest helper truncates it | confirmed by reading: `resolve_status` revives (day 8 `halted`); `ledgr_status_runtime_conflicts` ends the predecessor at the superseder's start (`R/availability-facts.R:1891-1898`) and feeds ingest outcomes (`R/availability-ingest.R:282-286`). The probe's own D2-e line does not show the truncation | Superseder must cover its predecessor's interval; align the ingest helper | **accept with change** (H2): a successor may start before its predecessor, but must start no later than the predecessor's end and cover the predecessor from the successor start through the predecessor end; it may extend later. Before successor start the predecessor remains valid; afterwards it never revives. A successor ending early refuses |
| I-F2 | consider | "Matches the resolver" was read, not executed | confirmed; now executed by the probes | Covered by D2-F1..F3 | **accept** (H2): the vendor-neutral matrix executes the rule through constructor, validator, classifier, resolver and public run where accepted |

Supersession is applied before ordinary precedence. Cycles and dangling
predecessor references refuse. The constructor's existing same-source lookup
already makes cross-source references dangling, so v12 adds no second
same-source rule. Sharadar remains regression evidence only, not the policy
oracle.
