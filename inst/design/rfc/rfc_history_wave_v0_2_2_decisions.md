# Decision Register: WS3/WS4 History Wave

**Status:** Working register, opened 2026-10-08. Records the maintainer's
decision on every finding of the
[Type 2 review](rfc_history_wave_v0_2_2_review.md) of the
[proposal](rfc_history_wave_v0_2_2_proposal.md). Binds nothing until stage 3
writes the accepted decisions into an amendment.
**Owner:** maintainer decides; executor verifies and drafts.

## Stages

| Stage | What | Exit | State |
| --- | --- | --- | --- |
| 1 | Verify | Every finding's premise rerun or read at `e38b0d7`; result in the Verified column | done 2026-10-08 |
| 2 | Decide | Every row has a decision or a recorded deferral, in the order of the sessions below | in progress: Session 0, A and B decided 2026-10-08 |
| 3 | Amend | One amendment to v11 (sections 3, 6, 7) carrying the accepted decisions under the amendment discipline in `../rfc_cycle.md`; `decisions.md` and `README.md` updated | open |
| 4 | Final review | Type 1 review of the amendment against this register | open |
| 5 | Ticket cut | WS3/WS4 cut in `tickets.yml`; cut review; pipeline rows leave `README.md` | open |

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
| X-F5 | consider | Sweep feature-matrix helper may take the dense path in availability mode | refuted: called only by `tests/testthat/test-sweep.R`; production uses `R/precompute-features.R:632` and `R/backtest-runner.R:1039`, both strict-branching | No decision needed; optionally delete the test-only helper | pending |
| D4-F4 | should-fix | History-dependent indicators are refused in availability mode, so WS7 on a PIT universe has no EMA/RSI/ATR/MACD | confirmed and stronger: refusal is anything not `strict_window` (`R/availability-policy.R:246-269`); `ledgr_ind_ema` is not `strict_window`, nor are bounded TTR functions other than SMA | Decide: v0.2.2 scope statement, or WS4 decides the gap rule | **decided** (maintainer, 2026-10-08): every supported indicator, built-in and TTR, must work on both ragged (availability) and dense universes in v0.2.2. WS4 owns the gap rule and the remaining blockers (see "B blockers" below) |
| D4-F5 | consider | `ledgr_check_no_lookahead` is never called; full-history hydration spreads a lookahead | confirmed: defined at `R/features-engine.R:487`, used only in `tests/testthat/test-features.R` | Sampled build-time causality check beside D3's refutation | pending |
| D4-F6 | consider | Stance on convergence for readiness and structural completeness | confirmed (no premise); burn-in measurement above is relevant | `stable_after` stays first-valid; convergence undisclosed in v0.2.2 | pending |

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

## Session C: knowledge clocks the history must carry

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D5-F1 | should-fix (was blocking) | Interval membership end applies on its effective date though known a day later; honest encoding refused | corrected: mechanism confirmed (fold drops X on day 10; open TRUE then open FALSE refused), but the production premise is wrong: the Sharadar adapter prohibits intervals and emits complete snapshot sets with equal clocks | Decide: add optional `end_knowledge_time` to interval facts in WS3, or document intervals as single-clock and snapshot sets as the two-clock path | **decided** (maintainer, 2026-10-08, "be pragmatic"): document interval membership as single-clock (its end is known when its start is) and complete snapshot sets as the two-clock path, which the Sharadar adapter already uses; no `end_knowledge_time` in this wave |
| D5-F2 | should-fix | Lifetime deferral needs v11 section 9's reopen trigger and precise wording (only opposing overlaps refused) | confirmed: same-assertion restatement accepted, opposing refused | Defer with trigger: acquisitions merged into bitemporal lifetime facts | **defer** (maintainer, 2026-10-08, "be pragmatic"): lifetime corrections reopen when acquisitions are merged into bitemporal lifetime facts (v11 s9); state that only opposing overlaps are refused |
| D5-F3 | consider | "Treats a correction as a later-known fact" is true of storage, not rules | confirmed | Reword | **accept** (maintainer, 2026-10-08, "be pragmatic"): say the representation, not the rules, treats a correction as a later-known fact |
| D1-F7 | should-fix | Sessions and corporate actions as known at t uncovered; 82 CA backfilled in 16 hours | confirmed: corporate actions carry optional `knowledge_time`, sessions carry it under evidenced knowledge (`R/availability-facts.R:36-50`); the spike covered neither | Decide: extend segments to CA and sessions, or ship barriers at the diagonal with a stated reason | **decided** (maintainer, 2026-10-08, "be pragmatic"): corporate actions and sessions without a knowledge clock use known-when-effective (`assume_effective`), disclosed in results; the representation keeps a slot for real knowledge clocks when a source supplies them |
| X-F3 | should-fix | Carry barriers depend on lifetime and CA at t | confirmed: v11 s5 barriers use knowable `known_inactive`, corporate actions and terminal assertions | Name the dependency in the amendment | **accept** (maintainer, 2026-10-08, "be pragmatic"): the amendment names the dependency of carry barriers on lifetime and corporate actions at t |
| X-F2 | should-fix | Feature-value revision (v11 7(d)) has no owner | corrected: the macro plan's WS3 owns "numerical correctness at the history boundary"; what is missing is the proposal's stance | WS3 stance: one prepared series per feature and policy; revision unexercised in this release; keep v11 section 8 fixtures as an obligation | **accept** (maintainer, 2026-10-08, "be pragmatic"): WS3 states the stance; revision is unexercised by Sharadar in this release; v11 s8 detecting fixtures stay an obligation |

## Session D: indicator history class

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D3-F1 | should-fix | `strict_window` already means bounded; the TTR default contradicts it | confirmed: contracts say the declaration "commits the definition to a finite window with no internal carry"; `ledgr_ind_ttr("SMA")` is `strict_window` | strict_window implies bounded; refuse the contradictory pair | pending |
| D3-F2 | should-fix | TTR class belongs in the warmup rules table, per function | confirmed for testable single-output rows: WMA, ROC, momentum, MFI, CMF, runMean/SD/Var/MAD gaps <= 1e-15, CCI 1.15e-11 (float noise); ATR, MACD, BBands, aroon, DonchianChannel need `output` (multi-column) | Bounded vs history-dependent per row; verify each against TTR source | pending |
| D3-F3 | should-fix | Refutation belongs in the strict path, against the full series once | confirmed: strict scalar compares `fn(window)` with `tail(series_fn(window))` per window of `stable_after` (`R/features-engine.R:291-347`) | Compare `fn(window_i)` with `series_fn(full)[i]` | pending |
| D3-F4 | consider | Refusal must name instrument, position and gap, with a product tolerance | confirmed (no premise) | Accept | pending |
| D3-F5 | consider | Does `history_class` enter identity? | confirmed: `ledgr_active_feature_fingerprint` carries `gap_contract` (`R/feature-cache.R:82-94`) | Feature fingerprint beside `gap_contract` | pending |
| D3-F6 | consider | Define bounded testably | confirmed (no premise) | A function of the last `stable_after` bars only | pending |
| I-F3 | consider | Spike B's 1e-9 is a 120-bar fixture tolerance | confirmed: dense SMA(20) 2.91e-12 at 3,000 bars; TTR SMA 9.95e-14; BBands 1.14e-13 | State a basis for any product tolerance | pending |

## Session E: storage details and budget

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D1-F9 | should-fix | Memory budget must be set before the representation is accepted | confirmed: macro-plan decision 8 requires a phase baseline and a budget for one run and a representative parallel workload; the Cut 9 single-run baseline exists, a parallel baseline does not | Maintainer sets the WS3 budget in this session; record the missing parallel baseline as a WS3 ticket | pending |
| D1-F1 | should-fix | Size guard must be named, overridable, with recorded counts | confirmed (design point) | Accept | pending |
| D1-F2 | should-fix | Production build and read shape (spike shape is an antipattern) | confirmed: `spike_build` rebuilds the provider per global epoch, appends data-frame rows; `spike_query` scans all segments | Per-instrument epochs, flat vectors, cursor re-seek, vectorised reads | pending |
| D1-F3 | should-fix | Merging equal states loses deciding-fact evidence | confirmed: the lifetime plane carries `lifetime_fact_id` and `terminal_event` per segment (`R/availability-provider-prepared.R:246-256`) | Merge on (state, winning fact, reason) | pending |
| D1-F4 | should-fix | Membership has four states; parity oracle is the resolver plus `members_at` | confirmed: `members_at` returns `key[state]` only (`R/availability-provider-prepared.R:91`) | Accept | pending |
| D1-F5 | should-fix | Family declaration travels apart from rows | confirmed: default keys on `has_status` (`R/availability-provider-prepared.R:243`) | Accept | pending |
| D1-F8 | consider | Diagonal parity needs a carve-out if the end clock lands | confirmed; moot if D5-F1 chooses documentation | Follows from D5-F1 | pending |
| I-F1 | should-fix | Evidence wording overclaims "no restatement" | confirmed: one acquisition; the only knowledge clock is a synthetic one-day lag | Guard exists because the shape is unmeasured | pending |
| I-F4 | consider | State what spike A discharged | confirmed | Accept | pending |

## Session F: correction chains

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D2-F4 | consider | Route chains out of the WS3 wave | confirmed: Sharadar has no trading-status facts; the validator runs on the seal path (`R/availability-persistence.R:587`) | Small facts ticket under the Cut 3 exact-byte oracles | **conditional** (maintainer, 2026-10-08): not accepted until each rule is tested against the full Sharadar history and shown not to stop real data |
| D2-F1 | blocking | Chain learned out of order: resolver says `conflicting` | confirmed: f1 known 3, f2 known 8, f3 known 5 answers `conflicting` on days 5-7 (the probe's "day 8.5 unknown" line is an artifact: `day(8.5)` lands on day 9, outside the interval) | Constructor rule: superseder knowledge >= predecessor knowledge | pending |
| D2-F2 | should-fix | Exempt ancestor pairs, not whole components | confirmed: two facts superseding f1 and disagreeing are refused today and resolve `conflicting` | Accept | pending |
| D2-F3 | should-fix | Resolver revives a predecessor; ingest helper truncates it | confirmed by reading: `resolve_status` revives (day 8 `halted`); `ledgr_status_runtime_conflicts` ends the predecessor at the superseder's start (`R/availability-facts.R:1891-1898`) and feeds ingest outcomes (`R/availability-ingest.R:282-286`). The probe's own D2-e line does not show the truncation | Superseder must cover its predecessor's interval; align the ingest helper | pending |
| I-F2 | consider | "Matches the resolver" was read, not executed | confirmed; now executed by the probes | Covered by D2-F1..F3 | pending |
