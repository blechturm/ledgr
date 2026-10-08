# Type 2 Review: WS3/WS4 History-Wave Decisions

**Status:** Independent Type 2 design review of the
[proposal](rfc_history_wave_v0_2_2_proposal.md), 2026-10-08. Findings are
dispositioned in the [decision register](rfc_history_wave_v0_2_2_decisions.md);
this record is not edited after the fact.
**Reviewer:** clean-context agent (Claude, Fable model), read-only, no access
to the private Sharadar root. Brief written by the executor at the
maintainer's instruction.
**Baseline:** branch `v0.2.2` at `8afd098`.
**Probes:** scratch only (`$TEMP/claude/design-review/probe_d2_d5.R`,
`probe_d2_partial.R`); claims the register relies on are re-verified there.

**Overall verdict: PROCEED_AFTER_CHANGES.** The representation choice (D1) and
"declare, not detect" (D3) are right. Four things must change before spec: D2
needs two constructor rules or it admits chains the resolver answers
"conflicting"; D4's two hydration rules must collapse to one; the public
history axis is undecided and WS7 cannot work without it; D5 defers the
interval end clock, which is a one-day lookahead on the production Sharadar
membership shape, not a "correction".

## Inputs (Type 1 obligation)

- **I-F1 (should-fix).** D1's Sharadar evidence does not bear on restatement.
  The only family with a knowledge clock is S&P 500 membership with a
  synthetic +1-day lag (`sharadar_census.csv`: basis
  `unobserved_source_timestamp_conservative_lag_1d`, start/end lag 1/1), which
  cannot restate by construction; 2.61 segments/fact measures append-only
  growth. The vintage diff is one 16-hour window over a lake holding one
  acquisition; segment growth under revision is unmeasured. Reword: the guard
  exists because the shape is unmeasured, not because evidence shows it absent.
- **I-F2 (consider).** D2's "matching the resolver" is read from
  `resolve_status` (`R/availability-provider-prepared.R:197-205`), not
  executed at equal precedence. The reading is correct as far as it goes, but
  a second reading exists (D2-F3).
- **I-F3 (consider).** Spike B's 1e-9 tolerance is a 120-bar fixture fact
  (charter section 8). At 3,000 bars the dense SMA(20) cross-start gap is
  2.9e-12 (cumsum rolling mean); TTR::SMA 1e-13. A product tolerance needs a
  stated basis.
- **I-F4 (consider).** Spike A discharges v11 7(a)/(b) for status, membership
  sets, late-known interval starts and lifetime only; not interval end clocks,
  sessions or corporate actions. D1 should say so.

## D1. Bitemporal segments

- **D1-F1 (should-fix).** The count guard is acceptable only as a named
  preparation refusal with an experiment-level budget override and recorded
  per-instrument counts. Memory is a non-issue for covered families (all
  S&P 500 membership = 5,030 segments; 30,834 lifetime facts at 3/fact is about
  4 MB), so the guard really protects build time, not RSS. Alternative: a
  knowledge-epoch cursor advancing one live effective timeline per instrument
  (memory linear in facts, pathological shape costs time). Recommends segments
  plus an overridable guard.
- **D1-F2 (should-fix).** Build and read shapes are unspecified and the
  spike's are antipatterns: per global epoch it re-filters every fact table and
  rebuilds the whole provider (`spike_core.R`, O(epochs x facts)), appends rows
  to a data frame, and `spike_query` scans the full table per lookup.
  Production: per-instrument epochs (as `sharadar_census.R` did), CSR flat
  vectors with a knowledge dimension, a cursor on t with `findInterval` re-seek
  (the existing `ledgr_availability_prepared_cursor` pattern), vectorised
  k-column reads per pulse. The macro plan's WS3 measures this phase's peak.
- **D1-F3 (should-fix).** "Merge adjacent equal states" loses evidence:
  adjacent runs with equal state can have different deciding facts
  (`lifetime_fact_id`, reasons), which WS3's exclusion reasons and v11
  section 5 disclosure need. Merge on the full resolved tuple (state, winning
  fact, reason), or keep evidence separately.
- **D1-F4 (should-fix).** Membership tri-state and oracle: the fold's prepared
  membership returns only members (`R/availability-provider-prepared.R:91`), so
  it cannot be the parity oracle. State that the plane carries TRUE /
  FALSE-asserted / FALSE-by-omission / NA and that parity is against
  `ledgr_membership_resolve_at` (tri-state) plus `members_at` (set).
- **D1-F5 (should-fix).** Family declaration must travel apart from rows (the
  closeout's finding; `spike_core.R` override). Omitted from the proposal;
  without it an epoch before the first status fact answers "active"
  (`R/availability-provider-prepared.R:243`).
- **D1-F6 (consider).** The table can answer s > t (facts known early: seven
  splits known five days before effect). The history API must refuse or clip
  s > t; v11 section 3 columns are s <= t.
- **D1-F7 (should-fix).** Sessions and corporate actions: constructors carry
  `knowledge_time` (`R/availability-facts.R:38, 48`) but D1 covers three
  planes. v11 section 5 barriers need CA knowable at t; v11 section 4
  narrowing needs sessions at t. In the Sharadar lake CA has no knowledge clock
  while the diff shows 82 events backfilled 1998-2026, so exposure is real and
  invisible under `assume_effective`. D1 must state that the layout extends to
  CA (event points) and sessions, or that WS3 ships barriers at the diagonal
  for them and why.
- **D1-F8 (consider).** "Diagonal must equal the shipped provider" needs a
  carve-out: the shipped diagonal has the interval-end leak (D5-F1); if the end
  clock lands, the diagonal legitimately changes on those inputs.
- **D1-F9 (should-fix, process).** Macro-plan decision 8 and WS3 require the
  memory budget before the representation is chosen; the baseline exists
  (LDG-2971 evidence) but the budget is unset. Set it in the same acceptance.

## D2. Supersession chains

- **D2-F1 (blocking as written).** Transitive exemption is unsafe without
  knowledge monotonicity along the chain. Executed: f1 known day 3 <- f2 known
  day 8 <- f3 known day 5, same precedence. The prepared diagonal answers
  `conflicting` on days 5-8 (f2 unknown; f3 names an absent fact; f1 and f3
  tie), while D2's validator would have exempted (f1, f3). Nothing enforces
  superseder knowledge >= predecessor knowledge
  (`ledgr_fact_validate_status_supersession`, `R/availability-facts.R:1665-1692`,
  checks source, existence and acyclicity only). Fix: add that constructor
  rule. Direct pairs do not have this hazard.
- **D2-F2 (should-fix).** The grouped sweep must exempt ancestor/descendant
  pairs in the supersession DAG, not connected components. Executed: f2 and f3
  both supersede f1 and disagree; refused today, resolver answers
  `conflicting`; a component rule would admit it. Add to the v0.2.0.1
  section 4.2 matrix.
- **D2-F3 (should-fix).** Two supersession readings exist. `resolve_status`
  drops a predecessor only where the superseder is applicable, so it revives
  after a shorter superseder ends (f1 halted [3,9), f2 active [5,7) supersedes
  f1: day 8 = `halted`). `ledgr_status_runtime_conflicts`
  (`R/availability-facts.R:1891-1898`) truncates the predecessor permanently at
  the superseder's start and feeds ingest evidence
  (`R/availability-ingest.R:282-286`). D2 must bind one (recommend: a
  superseder must cover its predecessor's effective interval, else refuse) and
  align the ingest helper.
- **D2-F4 (consider).** Routing: Sharadar has zero trading-status facts; WS3
  does not rely on chains. Cut D2 as a small facts ticket under the Cut 3
  exact-byte oracles (the validator is on the seal path), not inside the WS3
  wave. Precedence crossing is harmless; state it.

## D3. Declared history class

- **D3-F1 (should-fix).** `gap_contract = "strict_window"` entails bounded
  (contracts: "commits the definition to a finite window with no internal
  carry"). D3's TTR default makes `ledgr_ind_ttr("SMA", n)` history_dependent
  plus strict_window. Make strict_window imply bounded and refuse the
  contradictory pair at construction.
- **D3-F2 (should-fix).** Put `history_class` in
  `ledgr_ind_ttr_warmup_rules()`: bounded for SMA, WMA, ROC, momentum, CCI,
  BBands, aroon, DonchianChannel, MFI, CMF, runMean/SD/Var/MAD;
  history_dependent for EMA, RSI, ATR, MACD and any Wilder or ratio EMA.
  Verify each row against TTR source; unknown TTR functions keep the
  conservative default.
- **D3-F3 (should-fix).** Put the refutation in the strict path:
  `ledgr_compute_feature_series_strict_scalar` (`R/features-engine.R:313-347`)
  calls `fn` and `series_fn` per window, which is why P3b passes. Compare
  `fn(window_i)` against `series_fn(full aligned series)[i]` computed once per
  instrument: one extra series call, every position, no sampling.
- **D3-F4 (consider).** A build-time data-dependent refusal is deterministic
  given the snapshot and reads the full range before the fold (as precompute
  does; not a value leak); it must name instrument, position and gap, with a
  product tolerance (I-F3).
- **D3-F5 (consider).** Decide whether `history_class` enters identity: under
  the single rule (D4-F1) it is refusal and disclosure only and belongs in
  `ledgr_active_feature_fingerprint` beside `gap_contract`
  (`R/feature-cache.R:82-94`).
- **D3-F6 (consider).** Define bounded testably: the value is a function of
  the last `stable_after` bars only.

## D4. History-dependent indicators

- **D4-F1 (blocking).** Two hydration rules create a per-feature hydration
  clock that identity cannot carry and inspection cannot reproduce:
  `hydration_start_utc` is one clock per window
  (`R/walk-forward-folds.R:583-592`; `R/walk-forward.R:803`),
  `ledgr_precompute_validate_window_coverage` compares one `warmup_start`
  (`R/precompute-features.R:200-261`), `ledgr_pulse_snapshot()` has no window.
  Recommends one rule: feature state starts at the snapshot start for every
  entry point and class, as an undated dense `ledgr_run()` already does.
  Consequences: `hydration_start_utc` stored = snapshot start; one precompute
  payload serves every walk-forward fold; sweeps compute from snapshot start
  and slice before the fold. The bounded shortcut becomes an optional
  exact-parity optimization proven like Cut 2.
- **D4-F2 (blocking; = X-F1).** The public history axis is undecided. v11
  section 3: `ctx$window()` columns are consecutive prepared decision pulses,
  hydration may supply a carry seed without expanding the public axis, no
  hidden fetch of pre-range history. Under D4 the indicator is warm at the
  first scoring pulse, but a 252-column history read there is 251 NAs unless
  pre-scoring prepared pulses are on the public axis. Decide: (a) public
  history axis = prepared pulses from the hydration start, decision axis =
  scoring pulses (an explicit v11 section 3 amendment; causal, s <= t), or
  (b) keep v11 literal and accept estimators get no pre-scoring history. Only
  (a) makes WS7 work.
- **D4-F3 (should-fix).** It does not reopen Cut 9 if every entry point applies
  the same rule; the Cut 9 oracle stays the detector with expectations flipped
  to the carried arms (LTB-0196). Under two rules, run-vs-window parity for
  dense bounded indicators is about 1e-12, not exact.
- **D4-F4 (should-fix).** Availability-mode scope is silent.
  History-dependent indicators are refused in availability mode
  (`R/availability-policy.R:246-269`; `R/features-engine.R:293-301`), so D4
  reaches them in dense mode only; on a PIT universe WS7 cannot use EMA, RSI,
  ATR or MACD. State this as the v0.2.2 scope or make WS4 decide the gap rule.
- **D4-F5 (consider).** Nothing enforces causality of a custom `series_fn`:
  `ledgr_check_no_lookahead` (`R/features-engine.R:487`) is never called.
  Full-history hydration spreads any lookahead to all windows; a sampled
  build-time check can sit beside D3's refutation.
- **D4-F6 (consider).** WS4's exit and the WS3 structural-completeness query
  need a stance: `stable_after` remains first-valid; convergence undisclosed in
  v0.2.2.

## D5. Corrections

- **D5-F1 (blocking as written).** The interval end clock is not a correction.
  Executed: TRUE [1,10) known day 2, FALSE [10,inf) known day 11. On day 10
  the fold drops X (`members_at` = {}) and `ledgr_facts_resolve` says NA: the
  exit applies on its effective date although knowable only on day 11, a
  one-day lookahead under v11 section 3. The honest encoding is refused. The
  reviewer states this is the production Sharadar shape (intervals with
  `end_available_at_utc`, end riding on the start row). Options: (a) optional
  `end_knowledge_time` on interval facts, applied by prepared membership from
  `pmax(effective_to, end_knowledge_time)`; (b) snapshot sets per change date,
  about 600k rows against 1,925. Recommends (a) in WS3; defer only
  restatement.
- **D5-F2 (should-fix).** Lifetime deferral is defensible; record v11
  section 9's reopen trigger. Only opposing overlaps are refused; a
  same-assertion restatement is accepted and `resolve_lifetime` picks by
  (effective_from, knowledge_time) rank.
- **D5-F3 (consider).** "The segment representation already treats a
  correction as a later-known fact" is true of storage, not of the lifetime or
  interval resolution rules. Say "representation", not "rules".

## Cross-cutting and missing decisions

- **X-F1 (blocking)** = D4-F2, public history axis.
- **X-F2 (should-fix).** v11 7(d) feature-value revision has no owner: state
  WS3's stance, note that Sharadar CA and lifetime are `assume_effective` so
  revision is unexercised in this release, and keep the v11 section 8
  detecting fixtures as an obligation.
- **X-F3 (should-fix).** Carry barriers (v11 section 5) consume
  `known_inactive` intervals and terminal assertions at t and CA clocks (needs
  D1-F7). Name the dependency.
- **X-F4 (consider).** Pulse inspection: under the single rule
  `ledgr_pulse_snapshot()` reproduces hydration trivially
  (`R/pulse-snapshot.R:297`); under two rules it cannot.
- **X-F5 (consider, untraced).** `ledgr_sweep_compute_feature_matrix`
  (`R/sweep.R:2511-2527`) uses the dense path while the runner and precompute
  branch to the strict path in availability mode; check before D4 binds.

## Per-decision verdicts

- **D1: ACCEPT_WITH_CHANGES** (D1-F1, F2, F3, F4, F5, F7, F9; I-F1).
- **D2: REJECT as written; accept with two added rules** (D2-F1, F2, F3);
  route as a facts ticket (D2-F4).
- **D3: ACCEPT_WITH_CHANGES** (D3-F1, F2, F3, F5).
- **D4: REJECT the two-rule form; accept the single rule** (D4-F1); decide the
  public history axis (D4-F2); state availability-mode scope (D4-F4).
- **D5: ACCEPT_WITH_CHANGES** (D5-F1 into WS3; D5-F2, F3).

**Overall: PROCEED_AFTER_CHANGES.**
