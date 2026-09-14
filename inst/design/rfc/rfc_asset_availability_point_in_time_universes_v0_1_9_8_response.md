# Response: Asset Availability, Point-in-Time Universes, and Missing-Data Semantics (Seed v1)

## 1. Status, Author, Date, and Response-Stage Authority

**Status:** Response-stage adversarial review. Non-binding. This document
authorizes no implementation, no contract change, no schema, and no widening
of the accepted empirical scope.
**Respondent:** Claude (response stage). The seed was authored by Codex; per
`../rfc_cycle.md` the response author is a different model.
**Date:** 2026-09-07.
**Responds to:**
`rfc_asset_availability_point_in_time_universes_v0_1_9_8_seed.md` at commit
`149169ce7930ef43c10d4ae5d96985db224664f9` on branch `v0.1.9.8`.
**Stage:** Stage 3 (response) of `../rfc_cycle.md`. The next stage is
response review (stage 4). This document is not Seed v2, not a synthesis, not
a specification, and not a ticket list.

**Revision note:** The seed was not edited. Every code claim below was checked
against the working tree at the seed commit; line numbers refer to that
commit. Where a claim could not be verified in this session, that is stated
rather than assumed.

**Revision 2 (2026-09-07, after maintainer review of the draft):** F-2
rewritten around the held-non-member default rather than `flat()`/`hold()`
convergence; F-3 restated sign-safe and split into strategy-output and
post-risk admissibility; F-5 withdrawn as a precision error and downgraded to
placement guidance; F-6 reframed around the not-knowable-row invariant with
abort, quarantine, and classify-and-ignore as alternatives; F-8 split into
recipe identity and fitted-artifact identity; F-1 narrowed to held
instruments lacking a valid decision-time price; Section 6 derived predicates
corrected; Section 8 cross-venue sentence and Section 10 memory sentence
replaced; Section 15 sequencing made explicit; Section 16 (strategy-author
UX and workflow) added. The reviewer's confirmations of the architecture
inventory, the F-1 core concern, F-4, F-9, the non-implementation boundary,
and the empirical limits are unchanged.

**Revision 3 (2026-09-07, after second maintainer review):** F-2 now
recommends that zero always means desired quantity zero and that
zero-default constructors initialize held non-members to their current
quantity; the earlier "zero means no instruction" alternative with an
execution marker is withdrawn because it turned target quantities into
commands and made `ledgr_target` carry execution state, contradicting the
Strategy Contract. F-3 is narrowed to the post-risk closure defect; partial
reductions at strategy output are moved to Section 12 as a product choice.
The decision-time context in Section 16.3 no longer exposes execution
eligibility, which under next-open execution depends on the execution-pulse
bar; Section 6 now separates submittability, target admissibility, and
fillability across the decision-time / execution-time boundary. Section 16
code, error text, and evidence views are updated to match.

**Revision 4 (2026-09-07, after third maintainer review):** the decision-time
field `submittable` is renamed `target_restricted`, because every visible
instrument, a known-inactive holding included, must carry a target under the
full-vector contract and only its admissible values are constrained; F-3's
post-risk rule now admits zero explicitly, so that `long_only` mapping a
negative target to zero is covered; Section 16.1 principle 5 claims only the
strategy-visible as-of planes, and Section 16.7 claims only that existing
`dense_static` identities stay byte-identical while `ragged_pit` adds
identity-bearing inputs; Section 16.4 states that plain full named vectors
remain valid strategy output.

**Review status (2026-09-07):** Stage 4 response review accepted Revision 4.
The bounded comparative architecture spike is next, followed by Seed v2.

---

## 2. Executive Verdict

The seed's direction survives the attack. Sparse sealed facts, versioned
as-of classification, a bounded fold-local decision frame with orthogonal
state planes, one fold core, and a pulse-dependent public view is the right
shape for ledgr, and the seed correctly refuses to select a physical schema,
state encoding, or strategy API before a comparative spike. Its code audit
(Section 3 of the seed) is accurate in every load-bearing particular I could
check, including its account of which `meta_json` column the snapshot hash
covers. Its evidence discipline is intact: every enumerated empirical limit
appears in the seed's own text and none of its proposed defaults outrun the
record.

The seed is not v2-ready. Three High findings sit exactly at the seam the
seed itself nominates for attack (Section 22 item 1, the strategy-domain
evolution), and each is a design gap rather than a product preference:

- a hold target on a held instrument that lacks a valid decision-time price
  cannot pass `ledgr_risk_max_weight()`, which aborts on any nonzero target
  whose price is non-finite (`R/risk-model.R:422-431`), and the seed gives
  risk no way to obtain a valuation mark that is distinct from
  `ctx$vec$close`;
- the seed does not say what a zero-default target constructor emits for a
  held non-member once that instrument enters `ctx$universe`; under Section
  9.2 as written the answer is a liquidation request re-derived on every
  pulse, so the documented `ctx$flat()` and `ledgr_target_rebalance()` idioms
  would liquidate a resumed or relisted holding the author never chose to
  sell;
- the hold-or-zero rule for held instruments that are known-inactive at the
  decision pulse is stated for strategy output only and is not closed under
  the risk transformation the accepted contract applies afterwards, so
  post-risk validation (`R/fold-engine.R:413-414`) has no rule to apply.

Eight Medium findings name touchpoints the seed's own proposals require but
do not mention (walk-forward opening-state validators, the per-instrument
feature cache key family, recipe versus fitted-artifact identity), sharpen
identity and parity claims that are currently ambiguous, bind the invariant
that observed rows for not-yet-knowable instruments must satisfy, propose a
default for the unresolved-terminal case, and give the architecture spike
disqualification criteria so it cannot benchmark accidental
implementations. Low findings record silent-skip precedents in current
code, leak surfaces beyond strategy helpers, wording contradictions, and
where the lineage digest should live.

Section 16 adds a non-binding, opinionated strategy-author UX and workflow
proposal, because the High findings are all failures of the public shape
rather than of the engine, and a v2 that fixes the engine without fixing the
shape would still ship a footgun.

Recommended disposition: proceed to response review; bind the
architecture-spike charter (F-12) at that review; run the spike; then Seed
v2 incorporating both. The findings warrant a v2; they do not warrant a
competing architecture.

---

## 3. Claims Independently Verified Against Current Code

Each row states what the seed claims, what the code shows, and the verdict.
"Verified" means the claim holds as written at the seed commit.

| # | Seed claim (section) | Code evidence | Verdict |
| --- | --- | --- | --- |
| V1 | `snapshot_bars` stores one non-null-OHLC row per instrument and timestamp; neither table represents lifetime, membership, expected sessions, or quality (3.1) | `R/db-schema-create.R:245-270`: `snapshot_instruments(snapshot_id, instrument_id, symbol, currency, asset_class, multiplier, tick_size, meta_json)`; `snapshot_bars` with `open/high/low/close DOUBLE NOT NULL`, PK `(snapshot_id, instrument_id, ts_utc)`. No other snapshot fact table. | Verified |
| V2 | Snapshot hash covers instrument and bar payloads including `snapshot_instruments.meta_json`; the `snapshots` envelope including `snapshots.meta_json` is excluded (3.1) | `R/snapshots-hash.R:140-186`: instruments query selects `meta_json` (line 142) and hashes it (line 156); bars query at 163-184; comment at 137-139: "The envelope row in `snapshots` is intentionally excluded". | Verified; the seed states both channels correctly (F-5 addresses placement). |
| V3 | Sealing validates referential integrity, timestamp granularity, and OHLC consistency but does not require a rectangle (3.1) | `R/snapshots-seal.R:255-345`: three checks (bars reference known instruments, no sub-second timestamps, high/low ordering). No per-instrument coverage or cross-join check. | Verified |
| V4 | Runtime views supply constant `gap_type = 'NONE'` and `is_synthetic = FALSE` (3.1) | `R/snapshot-source.R:93`. | Verified |
| V5 | `ledgr_experiment_snapshot_universe()` / `_normalize_universe()` turn snapshot instruments and configured IDs into a fixed universe (3.2) | `R/experiment.R:314-354`: sorted `snapshot_instruments` list; configured universe must be a non-empty unique subset. | Verified |
| V6 | `ledgr_run_fold()` applies an early fixed-universe coverage-count gate before the exact Cartesian product in `ledgr_pulse_timestamps()` (3.2) | Enclosing function `ledgr_run_fold` begins `R/backtest-runner.R:574`. Instruments-present check 812-823; pulse set = `DISTINCT ts_utc` over the configured universe's bars in range, 833-841; per-instrument bar count must equal pulse count, 852-869; runtime views 872; `ledgr_pulse_timestamps()` called at 905 and performs the `CROSS JOIN` / `LEFT JOIN` missing-cell count at 1498-1547, aborting `ledgr_missing_bars` at 1537. | Verified. The reconstruction path re-imposes the same rectangle: `R/derived-state.R:146` calls `ledgr_pulse_timestamps()` again. |
| V7 | An instrument starting one session late raises `LEDGR_SNAPSHOT_COVERAGE_ERROR` (3.2) | `tests/testthat/test-runner-snapshots.R:219-222`. | Verified |
| V8 | `ledgr_precompute_validate_static_coverage()` requires the same aligned shape (3.2) | `R/precompute-features.R:301-326`: every universe ID must have bars, and every ID's timestamp key vector must be `identical()` to the first's. | Verified |
| V9 | Feature hydration hydrates one exactly aligned series per instrument (3.2) | `R/backtest-runner.R:1108-1124`: per-instrument row count must equal pulse count and timestamps must match `pulses_posix` elementwise. | Verified |
| V10 | Session feature cache keys by snapshot hash, instrument ID, indicator fingerprint, feature-engine version, and range (3.3) | `R/feature-cache.R:83-132`; key prefix `ledgr_feature_cache_v2`. No universe, calendar, membership, or classification field. | Verified. See F-9. |
| V11 | `ledgr_precompute_features()` records the fixed universe, scoring/hydration ranges, grid labels, and feature fingerprints (3.3) | `R/precompute-features.R:52-77`. | Verified |
| V12 | Indicator fingerprints cover fn, series_fn, params, required bars, and warm-up (3.3) | `R/indicator.R:170-187`. | Verified |
| V13 | Warm-up may produce `NA` before `stable_after`; post-warm-up non-finite output is invalid (3.3) | `R/features-engine.R:208` (`non_warmup <- idx >= stable_after`), 231-232 (`ledgr_invalid_feature_output`). | Verified |
| V14 | `ledgr_validate_strategy_targets()` requires names to match `ctx$universe` exactly with finite quantities; missing names are an error (3.4) | `R/strategy-contracts.R:34-96`: `setdiff` both directions at 78-93; finiteness at 68-76; returns `targets[universe]`. Tests `tests/testthat/test-strategy-contracts.R:121-126`, `145-150`. | Verified |
| V15 | The fold validates targets, applies risk, validates again, then plans the next-open fill against the next matrix column (3.4) | `R/fold-engine.R:413-414` (risk then `ledgr_validate_post_risk_targets(targets, instrument_ids)`); `R/fold-engine.R:99-108` (`bars_mat$open[inst_idx, pulse_idx + 1L]`). | Verified |
| V16 | `ledgr_next_open_fill_proposal()` requires a finite positive next open; the final bar emits no fill (3.4) | `R/fill-model.R:24-33` (`NULL` next bar -> `ledgr_fill_none` with `LEDGR_LAST_BAR_NO_FILL`), 55-57 and 67-69 (abort on non-finite or non-positive open). `tests/testthat/test-acceptance-v0.1.0.R:318`, `342`, `396-399`. | Verified |
| V17 | Portfolio value multiplies every held quantity by the current close, in the fold and in reconstruction; `ledgr_state_asof()` queries current-timestamp closes (3.4) | `R/fold-engine.R:298-304`; `R/backtest-runner.R:1394`; `R/backtest-runner.R:1776-1830` (query at 1805-1815 is `FROM bars ... AND ts_utc = ?`). | Verified. See F-13 for the NA path. |
| V18 | Sweep resolves the same fixed universe through the shared fold core; initial positions are zeros over that universe (3.5) | `R/sweep.R:204-211` (static coverage check at 209), `R/sweep.R:1294`. | Verified |
| V19 | Walk-forward folds define calendar-time windows then apply the static pulse-coverage gate (3.5) | `R/walk-forward-folds.R:594-606` (`ledgr_experiment_window_validate_pulses` calls `ledgr_precompute_validate_static_coverage`). | Verified |
| V20 | Walk-forward session identity includes snapshot, experiment, grid, folds, selection rule, metric context, cost, risk, seed, and opening-state policy, with no calendar, universe-construction, classification, valuation, execution, or fitted-preprocessing layer (3.5) | `R/walk-forward.R:200-239`; payload `R/walk-forward-identity.R:193-217` (adds `walk_forward_schema_version` and `ledgr_version`). `experiment_hash` is over `ledgr_walk_forward_base_config()` at `R/walk-forward.R:241-267`, which includes `universe = exp$universe` (line 244) -- so the static universe list is inside `session_id` today. | Verified; the universe-list detail matters for F-10. |
| V21 | Candidate identity covers strategy, feature, alias, metric-context, cost, risk, seed, fold, and window-role inputs | `R/walk-forward-identity.R:33-52` (payload fields), `56-75`. No slot for a fitted-preprocessing artifact. | Verified. See F-8. |
| V22 | No membership, lifetime, or expected-session concept exists in `R/` today | `grep` for `members`/`membership`/`lifetime` hits only `R/validation-dsr.R` (cluster membership) and `R/walk-forward-inspection.R`. | Verified |
| V23 | 563 x 757 = 426,191 cells versus 382,288 observed member-session rows (2.1) | Arithmetic checked. | Verified |
| V24 | `ctx$hold()` aligns to `ctx$universe` (implicit in 9.1) | `R/pulse-context.R:744-777`: builds zeros over `lookup$universe`; **aborts at 767-773 if `positions` contains an ID not in `universe`** (`ledgr_invalid_pulse_context`). | Verified, and it corroborates the seed's union design: a members-only `ctx$universe` would make `ctx$hold()` abort on the first pulse a held instrument left the member set. |
| V25 | Opening positions are validated against the universe (not claimed by the seed; needed for F-4) | `R/experiment.R:502-507` (`ledgr_experiment_validate_opening`), `R/config-validate.R:99-103`; tests `tests/testthat/test-runner.R:92-104`, `tests/testthat/test-experiment.R:133`. Fail-closed, not silent. | Verified |

External primary-source rechecks performed in this session:

- scikit-learn common pitfalls: confirmed verbatim -- transformations "are
  only learnt from the training data"; "Never include test data when using
  the `fit` and `fit_transform` methods." Supports seed Section 12.
- Nasdaq Trading Halt Codes: confirmed -- the page publishes Halt Date, Halt
  Time, Issue Symbol, Reason Code, Pause Threshold Price, Resumption Quote
  Time, and Resumption Trade Time, with codes such as `T1` (news pending),
  `T5` (single-stock pause), `H10` (SEC suspension), `LUDP` (volatility
  pause). Supports representing a halt as explicit status separate from a
  missing row. It does not define a cross-venue taxonomy, as the seed says.
- ALFRED download help: confirmed -- "The observation date is the date for
  which a data value is measuring"; "A vintage date is a date in history
  used to download data as it actually existed on that past date"; real-time
  period start/end bound when a value was the latest revision. Supports the
  seed's knowledge-time / effective-time separation.
- zipline-reloaded API reference: **not reverified here**. The page returned
  HTTP 403 in this session. The seed's `can_trade()` / `is_stale` claim
  therefore rests on the prior-art review and the seed author's own
  2026-09-07 recheck; this response treats it as plausible but unconfirmed
  (F-17).

---

## 4. Findings Ordered by Severity

Severity scale: **High** (a design gap the seed's own proposal cannot satisfy
as written), **Medium** (a required correction, missing touchpoint, or
ambiguity that Seed v2 must resolve), **Low** (precedent, wording, or scope
item that v2 should record), **Informational**.

Classification vocabulary from the prompt: *defect* (contradicts code or an
accepted contract), *unresolved product choice* (legitimate maintainer
decision the seed must surface), *missing evidence* (cannot be settled
without new empirical work), *implementation concern* (real but belongs to
the specification stage).

### F-1 -- Hold targets on held instruments without a valid decision-time price cannot pass `ledgr_risk_max_weight()`

- **Severity:** High. **Class:** defect (seed contradicts an accepted
  execution contract). **Blocks v2:** yes.
- **Seed sections:** 9.2, 13.1, 18 rows 2/4/6, 22 item 1.
- **Verified current-code evidence:**
  `R/risk-model.R:416-439` -- `ledgr_apply_risk_step_max_weight()` reads
  `prices <- ledgr_risk_context_prices(ctx, names(targets))` and aborts
  `ledgr_invalid_risk_context` when any target with nonzero quantity has a
  price that is non-finite, `NA`, or non-positive (lines 421-431).
  `R/risk-model.R:453-470` -- `ledgr_risk_context_prices()` takes
  `ctx$vec$close` when its length equals the universe, else calls
  `ctx$close(id)` per ID. `ctx$vec$close` is built from the bar matrix
  aligned to `ctx$universe` (`R/pulse-context.R:578-592`). Contracts,
  Execution: "Target risk is a target-vector transformation layer... The
  fold applies the normalized `risk_chain` after strategy target validation
  and before fill timing."
- **Why it matters:** Seed 9.2 makes "current quantity (hold)" the primary
  allowed target for a held-but-inactive instrument. Seed 13.1 says a stale
  mark "is not relabeled current" and 18 row 6 says "Stale valuation is not
  an indicator source unless declared". The problem is confined to held
  instruments that lack an accepted decision-time close -- a held non-member
  that still trades has a price and is unaffected. For a held ID with no
  accepted decision-time observation, those rules make `ctx$vec$close` `NA`,
  so any experiment with `ledgr_risk_max_weight()` in its chain aborts on
  the first pulse such an instrument is held. If instead the stale mark is
  written into `ctx$vec$close` so risk can run, it *is* relabeled current for
  every consumer of the close vector -- the strategy included -- which is the
  collapse Section 19 forbids. The seed's sentence "Risk calculations that
  consume stale marks must declare that permission and the maximum admitted
  age" names the requirement but proposes no mechanism: risk steps receive
  `ctx`, not a valuation plane.
- **Required correction:** Seed v2 must bind (a) what `ctx$vec$close`
  carries for a held ID with no accepted decision-time observation (`NA` is
  the causally honest answer), and (b) how risk obtains a permitted
  valuation mark that is *not* the strategy close vector -- either a
  distinct valuation plane passed to `ledgr_apply_risk_plan()`, or a rule
  that quantity-limiting steps treat a hold target on an unpriced ID as
  pass-through with a classified reason. (b) also settles whether
  `ledgr_risk_none()` and `long_only` (`R/risk-model.R:408-414`, price-free)
  are the only steps admissible on an unpriced held ID in a first
  implementation. Either answer must also state that risk identity
  (`risk_chain_hash`) does not change merely because a valuation plane is
  consulted; the valuation-policy identity carries that.

### F-2 -- The seed does not say what zero-default constructors emit for a held non-member, and Section 9.2 as written makes the answer a repeated liquidation request

- **Severity:** High. **Class:** unresolved product choice with a defect
  consequence. **Blocks v2:** yes.
- **Seed sections:** 9.1, 9.2, 13.2, 18 rows 2/4, 19.
- **Verified current-code evidence:**
  `R/pulse-context.R:744-777` -- `ctx$hold()` returns the current quantity
  for every universe ID. `R/pulse-context.R:428` -- `ctx$flat()` returns a
  scalar default (zero) for every universe ID. `R/strategy-helpers.R:215`
  onward -- `ledgr_target_rebalance()` builds a full-universe zero vector
  and sizes only the IDs with nonzero weight. Contracts, Context: `ctx$flat()`
  "is appropriate when unspecified instruments should go flat"; `ctx$hold()`
  "is appropriate for hold-unless-signal strategies". These are intentionally
  different semantics for *members*, and this finding does not ask them to
  converge. Contracts, Strategy: "Target values are desired instrument
  quantities after the next fill, not portfolio weights, order sizes, or
  signals. `ledgr_target` is a thin wrapper around those same target
  quantities and is unwrapped before execution."
- **Why it matters:** Today `ctx$universe` contains only configured
  instruments, so "unspecified goes flat" never touches an instrument the
  author did not configure. Under seed 9.1 `ctx$universe` also contains held
  non-members, and under 9.2 a zero target on such an ID is a liquidation
  request. The seed never states what `ctx$flat()` or the reference
  rebalance helper should emit for that new class of ID. If the answer is
  "zero, as for any unspecified instrument", every flat-unless-signal
  strategy re-derives a sell request for each held non-member on each pulse.
  The engine persists nothing -- a freshly generated zero is not carried
  intent, and Section 13.2 holds -- but the *outcome* is the one 13.2 exists
  to prevent: on the first pulse the instrument can trade again (halt
  resumption, relisting) the fold executes a liquidation the author never
  chose. It also emits the non-order diagnostic every pulse until then. This
  is the "silent liquidation" path the prompt asks about, reached through
  the default constructor rather than the validator.
- **Required correction:** Seed v2 should bind: zero always means desired
  quantity zero, for every instrument and every state; every zero-default
  constructor and helper (`ctx$flat()`, `ledgr_target_rebalance()`, any
  full-universe zero vector the package builds on the author's behalf)
  initializes held non-members to their current quantity, so that "flat"
  means "flat for members"; liquidating a held non-member is an explicit
  assignment of zero, for which a convenience helper may exist (Section
  16.4) but which adds no state to the target. `ctx$flat()` and `ctx$hold()`
  keep their distinct member semantics. The alternative -- a plain zero on a
  held non-member meaning "no instruction", with an execution marker on the
  wrapper to request liquidation -- was proposed in an earlier draft of this
  response and is withdrawn: it makes one numeric value carry two meanings
  depending on the instrument's state, turns target quantities into
  commands, and makes `ledgr_target` carry execution state, each of which
  contradicts the Strategy Contract quoted above. The accepted cost of the
  recommended rule is that a raw zero vector an author builds by hand is
  literal and requests an exit of every held non-member; the constructors
  are the safe path, and the diagnostics view (Section 16.6) shows any such
  exit as pending until the fill layer can execute it.

### F-3 -- The hold-or-zero rule is not closed under the risk transformation the accepted contract applies afterwards

- **Severity:** High. **Class:** defect. **Blocks v2:** yes.
- **Seed sections:** 3.4 ("validate targets, apply target risk, validate
  again"), 9.2, 4 (adjacent decision: "Target risk runs after target
  validation and before fill planning").
- **Verified current-code evidence:** `R/fold-engine.R:413-414` -- risk
  plan is applied, then `ledgr_validate_post_risk_targets(targets,
  instrument_ids)`. `R/risk-model.R:436-437` -- `max_weight` reduces a
  nonzero target to `sign * pmin(abs, max_abs_qty)`; `R/risk-model.R:408-414`
  -- `long_only` clamps negatives to zero. Both are legitimate transformations
  of a hold target.
- **Why it matters:** Seed 9.2 admits exactly two targets on a held ID that
  is known-inactive at the decision pulse: the current quantity or zero. As a
  strategy-output rule that is complete and sign-safe, because both admitted
  values are exact. Its defect is closure. The accepted contract then applies
  risk, and `max_weight` may return, for a current quantity of 100, a target
  of 80. Eighty is neither admitted value, so the post-risk validator has no
  rule: it must either reject a target the strategy did not author or wave
  through a value the strategy-output rule does not admit. An earlier draft
  of this response also widened the strategy-output rule to admit any
  same-sign partial reduction; that is a product choice, not a required
  correction, and is moved to Section 12.
- **Required correction:** Seed v2 should keep hold-or-zero as the
  strategy-output rule on known-inactive held IDs and add a separate
  *post-risk admissibility* rule: the post-risk validator accepts a target
  that is zero, or that has the same sign as the admissible strategy target
  with magnitude no greater than it. Both shipped steps satisfy this by
  construction, `long_only` mapping a negative target to zero included. A
  step that could increase magnitude or reverse sign on such an ID would need
  the decision-time state plane and must be rejected until it has it.
  Admitting zero explicitly and stating the rest in sign and magnitude terms
  keeps the rule correct if short positions are admitted later
  (`R/walk-forward.R:845-850` currently aborts on carried shorts). This keeps
  risk free to transform a hold target, which it legitimately does today.

### F-4 -- Walk-forward carry and opening-state validators scope to the static universe; the seed names none of them

- **Severity:** Medium. **Class:** implementation concern that v2 must
  name (it is not silent today). **Blocks v2:** yes, as a named touchpoint.
- **Seed sections:** 3.5, 8.2 ("`axis_ids` ... including positions carried
  into it"), 9.1, 18 row 10.
- **Verified current-code evidence:**
  `R/experiment.R:502-507` -- `ledgr_experiment_validate_opening()` aborts
  when opening positions name instruments outside `universe`.
  `R/config-validate.R:99-103` -- same check at the low-level runner.
  `R/walk-forward.R:790-794` -- `ledgr_walk_forward_experiment_with_opening()`
  assigns `out$opening <- opening` without re-validation, so the check fires
  later at config validation. `R/walk-forward.R:829-857` --
  `ledgr_walk_forward_opening_from_run()` reconstructs the carried opening
  from the run's final positions and calls
  `ledgr_lot_state_asof(opened$con, run_id, exp$universe, final_ts)` (line
  852) with the **static** universe. `R/backtest-runner.R:1041-1044` --
  `initial_positions` is built over `instrument_ids` and then indexed by
  opening-position names.
- **Why it matters:** Under `dense_static` these are unreachable hazards
  because carried positions are always inside the static list. Under
  `ragged_pit`, `carry_test_state` will routinely carry a held former member
  into a fold whose knowable member set excludes it. Today that fails closed
  at config validation -- which is good: the prompt's "silent liquidation"
  does not occur through this path. But the seed's 8.2 promise that the
  frame's axis includes carried positions is not connected to the three
  validators that currently enforce "opening positions are a subset of the
  static universe", nor to `ledgr_lot_state_asof()`'s universe argument,
  whose cost-basis lookup would return `NA` for an ID outside the list it
  is given.
- **Required correction:** Seed v2 Section 8.2 or 9.1 must state that the
  opening-state validators validate against the fold's `axis_ids` (members
  union carried positions), that `ledgr_lot_state_asof()` and the
  `initial_positions` construction take `axis_ids`, and that the carried
  opening's cost basis for a former member is preserved (not `NA`). This is
  also where the seed should state that a carried former member enters the
  next fold's `ctx$universe` on its first pulse even if it has no
  observation there.

### F-5 -- Where the lineage digest belongs should be answered, not left as "sealed into semantic identity"

- **Severity:** Low. **Class:** implementation concern. **Blocks v2:** no;
  v2 should answer seed question 9 directly.
- **Seed sections:** 3.1, 14.1, 22 item 9.
- **Verified current-code evidence:** `R/snapshots-hash.R:142` selects
  `meta_json` from `snapshot_instruments` and line 156 hashes it; lines
  137-139 exclude only the `snapshots` envelope row. The seed's Section 3.1
  states exactly this distinction, and its "external sidecar" refers to
  lineage held outside both tables (the Sharadar hash-bound sidecar), so the
  seed's statement that such a sidecar does not change the snapshot hash is
  accurate. An earlier draft of this response called it a precision error;
  that was wrong and is withdrawn.
- **Why it matters:** Two in-database channels exist today with opposite
  hash behavior, and a specification could put membership or lifetime
  assertions into either. The seed's conclusion (a mutable un-hashed sidecar
  is insufficient when it supplies PIT facts) is correct; what is missing is
  the affirmative placement.
- **Required correction:** v2 Section 14.1 should state that lineage and
  classification-input digests belong in a hashed fact table (or an
  extension of the hashed instrument payload), never in the `snapshots`
  envelope, and that the `snapshot_hash` combination rule
  (`R/snapshots-hash.R:134-136`) is versioned when new fact families join
  it so that existing dense hashes remain reproducible (ties to F-10).

### F-6 -- The rule for observed rows outside the declared calendar, or for not-yet-knowable instruments, is unstated; v2 must bind the invariant and choose among abort, quarantine, and classify-and-ignore

- **Severity:** Medium. **Class:** unresolved product choice under a
  binding invariant. **Blocks v2:** yes.
- **Seed sections:** 8.2 ("`pulses`: an identity-bound experiment calendar,
  not merely observed bar timestamps"), 10.1, 10.2, 22 item 4.
- **Verified current-code evidence:** `R/backtest-runner.R:833-841` --
  today's pulse set is `SELECT DISTINCT ts_utc FROM snapshot_bars WHERE
  instrument_id IN (<configured universe>)`; any bar of any configured
  instrument creates a pulse. Sharadar Gate 3 recorded 31 of 101 cells as
  `observed_row_outside_expectation`, so off-calendar rows are an
  established fact class.
- **Why it matters:** The seed moves calendar ownership to an identity-bound
  source but does not say what the frame builder does with an observed row
  that falls outside the declared calendar, or with a row for an ID that is
  not knowable at that pulse. The binding requirement is: *a row for an
  instrument that is not knowable at a pulse must not alter any successful
  run's runtime inputs, fitted state, pulse axis, or outputs.* Three
  responses relate to that invariant differently. Letting such rows
  *contribute* pulses violates it: a future member's session would create a
  pulse before membership. *Aborting* the run satisfies it -- an abort
  visible to the maintainer is not information available to a strategy or a
  fitted model -- but carries a research-process cost the seed should name:
  the runs that complete are then conditioned on the absence of such rows,
  a selection effect on which experiments can be finished. *Quarantining*
  the row (excluded from the frame, recorded in the state plane) and
  *classify-and-ignore* (recorded as `observed_row_outside_expectation` on
  the instrument's plane with the axis untouched) both satisfy it and both
  preserve the run. An earlier draft of this response mandated
  classify-and-ignore alone; that overstated the finding.
- **Required correction:** v2 Section 10.1 should state the invariant
  above, add it to Section 19 as "alters a successful run's inputs, fitted
  state, pulse axis, or outputs because of a row for an instrument not
  knowable at that pulse", and choose among abort, quarantine, and
  classify-and-ignore as the first-implementation default, recording the
  selection-effect caveat if abort is chosen. It should also state that the
  *set of calendars* is part of run identity and is declared, never derived
  from the frame's IDs.

### F-7 -- `ctx$idx()` becomes pulse-local, which silently breaks the documented high-throughput pattern

- **Severity:** Medium. **Class:** implementation concern with a contract
  consequence. **Blocks v2:** no; may remain an open spec-cut question if
  v2 records it.
- **Seed sections:** 9.1, 18 row 10.
- **Verified current-code evidence:** `R/pulse-context.R:658-675` --
  `ctx$idx(id)` returns `lookup$id_to_idx[id]`; `R/pulse-context.R:505` --
  `id_to_idx` is built from the universe. RFC index, "Strategy callback
  accessor addendum": "the high-throughput path is `ctx$vec`, `ctx$idx()`,
  and `ctx$vec$feature(feature_id)`". Contracts, Context: `ctx$idx()`
  "returns the 1-based universe position".
- **Why it matters:** Today the universe is fixed, so a strategy may cache
  `ctx$idx("AAA")` in `state_prev` and reuse it. Under a pulse-dependent
  `ctx$universe`, the same integer points at a different instrument after
  any membership change, and nothing errors. Exposing a stable internal-axis
  index instead would leak axis dimensions (seed 8.2 forbids it).
- **Required correction:** v2 Section 9.1 should state that under
  `ragged_pit` all positional accessors are pulse-local and that caching
  positions across pulses is unsupported; the specification should decide
  whether to detect it (e.g., an opaque per-pulse token on `ctx$vec`) or
  only document it.

### F-8 -- Recipe identity and fitted-artifact identity must be separated; only the former belongs in `candidate_key`

- **Severity:** Medium. **Class:** defect (identity layering). **Blocks
  v2:** yes.
- **Seed sections:** 12, 14.1 (row "Fold-fitted preprocessing" and row
  "Walk-forward session / fold"), 22 item 6.
- **Verified current-code evidence:** `R/walk-forward-identity.R:33-52` --
  candidate payload fields are params, feature params, strategy, feature
  set, alias map, metric context, cost, risk;
  `R/walk-forward-identity.R:102-115` derives the seeded candidate key from
  the unseeded key, so the key is an *input* to seed derivation. No slot for
  a preprocessing recipe. Contracts, Strategy: ambient RNG is "Tier 2 for
  ordinary sequential runs, but ... not certified for resume or parallel
  equivalence"; parallel-safe stochastic inputs derive from
  `ctx$pulse_seed`.
- **Why it matters:** Two candidates in the same fold that differ only by
  imputation recipe or hyperparameters are different candidates; if recipe
  identity is not in `candidate_key`, selection and promotion cannot
  distinguish them. But the fitted-state digest is an *output* of running
  the recipe under the candidate's seed; putting it into the key from which
  that seed is derived is circular. The two belong in different layers, the
  way `snapshot_hash` (an artifact digest) verifies a snapshot without being
  an input to the config that references it. A fit that consumes ambient RNG
  would also be non-reproducible across parallel workers by contract.
- **Required correction:** v2 Section 14.1 should split the row: *recipe
  identity* (recipe, hyperparameters, deterministic fit policy, declared
  training-scope rule) enters the candidate layer and therefore the seed
  derivation; *fitted-artifact identity* (fitted-state digest, train bounds
  actually used, fold ID, software identity) is recorded on the artifact
  and verified on reopen and promotion, never fed back into `candidate_key`.
  Fit RNG derives from the candidate-and-fold seed in the same family as
  `ctx$pulse_seed`; a fit that uses ambient RNG is invalid for walk-forward,
  not merely Tier 2.

### F-9 -- The existing feature-cache key family is valid only for source-domain, per-instrument nodes

- **Severity:** Medium. **Class:** defect (cache invalidation). **Blocks
  v2:** yes.
- **Seed sections:** 11 (feature-domain transforms; pre-membership history),
  14.1 (row "Deterministic materialization"), 14.2, 22 item 5.
- **Verified current-code evidence:** `R/feature-cache.R:109-132` -- key
  is `ledgr_feature_cache_v2 | snapshot_hash | instrument_id |
  indicator_fingerprint | feature_engine_version | start | end`. Contracts,
  Context: "Cache entries are keyed by sealed `snapshot_hash`, instrument
  ID, indicator fingerprint, feature-engine version, and date range."
- **Why it matters:** For a per-instrument source-domain indicator this key
  is correct under `ragged_pit` too: the series depends on the instrument's
  own bars and the seed's admissible-history rule, not on who else is a
  member. But the seed's typed DAG admits feature-domain nodes
  (cross-sectional imputation, ranks) whose output depends on the pulse's
  member set, the classification policy, and the calendar. None of those
  are in the v2 key, and nothing prevents a ragged consumer from looking up
  a key that a dense run populated. The seed's 14.1 row says "all upstream
  hashes ... axis ordering" for deterministic materialization but does not
  say that this is a *new* key family or that the v2 namespace must not be
  shared.
- **Required correction:** v2 should state: the `ledgr_feature_cache_v2`
  family remains valid only for source-domain per-instrument nodes whose
  input is the instrument's own observations plus the admissible-history
  rule (and that rule's identity must be added to the fingerprint or the
  key); feature-domain nodes get a new versioned namespace keyed by
  universe-construction, classification, calendar, and axis identities; a
  ragged run must never read the v2 namespace for a feature-domain node.

### F-10 -- "Bit-identical" dense parity must name which identities can stay bit-identical if a semantic-mode field exists

- **Severity:** Medium. **Class:** unresolved product choice with a
  verifiable default. **Blocks v2:** yes.
- **Seed sections:** 7 rule 1, 16, 21 (row "Dense-mode parity and
  migration": unresolved "Bit-identical versus approved semantic equivalence
  for newly versioned metadata"), 22 item 11.
- **Verified current-code evidence:** `R/walk-forward.R:241-267` --
  `experiment_hash` is over a config that includes `universe`, `opening`,
  `timing_model`, cost and risk identity; `R/walk-forward-identity.R:193-217`
  -- session payload includes `walk_forward_schema_version` and
  `ledgr_version`. Contracts, Execution: "`config_hash` identifies the
  logical execution config after removing store-local and run-local
  fields". Contracts, Execution (risk): "Omitted `risk_chain`, `risk_chain
  = NULL`, and `risk_chain = ledgr_risk_none()` normalize to the same no-op
  risk plan for new configs" -- the codebase already has an
  omit-when-default precedent.
- **Why it matters:** `snapshot_hash`, indicator fingerprints, and the v2
  feature-cache keys for per-instrument nodes can be bit-identical because
  their inputs do not change. `config_hash`, `experiment_hash`, and
  therefore `session_id` cannot be bit-identical if a `semantic_mode =
  "dense_static"` field is *added* to their payloads; every historical
  run/sweep/session identity would move. The seed's claim "Existing dense
  snapshots remain reproducible under their current hash rules" is true of
  the snapshot and silent about the rest.
- **Required correction:** v2 Section 16 should list identity by identity
  which are bit-identical and which are "approved equivalent", and bind the
  default that makes the list short: `dense_static` is the *absent* value
  in canonical payloads (like the no-op risk plan), so legacy payloads hash
  identically; only `ragged_pit` adds fields. Whether saved-sweep and
  walk-forward *schema* versions need a bump is a separate specification
  decision about table shape and validators; identity stability does not
  settle it either way.

### F-11 -- The minimum blocker representation for an unresolved terminal state is the common case, not the edge case

- **Severity:** Medium. **Class:** unresolved product choice; partly
  missing evidence. **Blocks v2:** no, but v2 should propose a default for
  the maintainer to accept or reject.
- **Seed sections:** 13.1 ("Whether an unpriced position aborts the run,
  continues with restricted metrics, or uses an explicit recovery/terminal
  value is left unresolved"), 15, 18 row 2, 21 (row "Accounting-event
  boundary", unresolved "Minimum blocker representation").
- **Verified evidence:** Sharadar synthesis: "Only two of the seven
  lifecycle adjudications obtained known direct lifetime evidence. Five
  remained uncertain." The accepted lifecycle policy forbids inferring a
  known end from last observed price or membership bounds.
  `R/fold-engine.R:298-304` values positions by the current close with no
  age; `R/backtest-runner.R:1810-1817` would produce `NA` equity for a held
  ID with no bar at the query timestamp.
- **Why it matters:** The seed gates *known* terminal events on the
  accounting sibling and leaves *unknown* lifecycle ends "stale or
  unpriced" under policy. Empirically, unknown is the majority outcome. So
  the realistic first ragged run is one in which a held instrument stops
  observing, no terminal fact arrives, and the position is `unpriced` for
  the rest of the window with metrics either aborted or undefined. That is
  the case the seed calls unresolved, and it is the one users will hit
  first.
- **Proposed default for v2 to surface:** a held instrument that leaves
  `known_active` (or becomes `unknown`) while held is a classified
  run-stop by default -- the run completes to that pulse with an explicit
  `unresolved_terminal` status and its performance surfaces are marked
  incomplete -- unless a valuation policy with a bounded maximum stale age
  is declared, in which case the run may continue to that age and then
  stops the same way. No metric is reported as complete performance while
  an `unresolved_terminal` flag is set. This gives Section 15 its "minimum
  blocker representation" without any accounting event and keeps
  "indefinitely stale" from becoming accidental terminal accounting. It is
  a maintainer choice whether run-stop is the default or the opt-in.

### F-12 -- The comparative architecture spike has no disqualification criteria and no minimum fixture scale

- **Severity:** Medium. **Class:** missing evidence design. **Blocks v2:**
  yes (v2 should bind the spike's fixtures and falsification criteria).
- **Seed sections:** 7 (spike requirement), 17, 20 item 15, 22 item 13.
- **Verified evidence:** Prior-art review 11.3-11.4 proposes four prototypes
  and eight acceptance items but ranks rather than disqualifies. Sharadar
  Gate 4 population: 563 instruments x 757 sessions with membership
  variation; Gate 3: 101 adversarial cells across the taxonomy.
- **Why it matters:** As written, a prototype that fails a safety property
  but wins on runtime could be "selected". A spike that benchmarks four
  hand-built prototypes with different maturity measures implementation
  effort, not architecture.
- **Required correction:** v2 Section 7 should bind: (a) fixtures -- the
  twelve Section 18 scenarios as deterministic fixtures, plus one synthetic
  broad-sparse fixture at not less than 500 instruments x 750 sessions with
  at least 10% membership churn and at least one pre-membership history case
  (the shape the empirical population had), plus the existing dense
  fixtures for scenario 12; (b) *disqualifying* properties -- future-ID
  perturbation invariance (adding a future listing must not change any
  pre-listing feature, order, fill, or hash), zero fills on carried,
  imputed, or synthetic prices, dense bit-parity on scenario 12 for the
  identities F-10 lists, run/sequential-sweep/parallel-sweep/walk-forward
  parity, and one-fold-core (a prototype with a second executor is
  disqualified by the Execution Contract); (c) *ranking* measurements among
  survivors -- peak process RSS and materialized-frame bytes separately,
  per-pulse time, cold and warm cache time, and frame build time, each
  reported with the fixture that produced it; (d) that every prototype uses
  the same materializer interface so the comparison is of representations,
  not of implementations.

### F-13 -- Current code contains silent no-diagnostic paths that dense parity would preserve and ragged mode must not inherit

- **Severity:** Low. **Class:** implementation concern (precedent).
  **Blocks v2:** no; v2 should record it in Section 19.
- **Seed sections:** 13.2, 16, 19.
- **Verified current-code evidence:** `R/fold-engine.R:115-117` -- after
  cost resolution, `if (!is.finite(fill$fill_price) || fill$fill_price <=
  0) next` drops the fill with no warning, no event, no diagnostic (the
  final-bar branch at 111-114 does warn). `R/backtest-runner.R:1810-1817`
  -- `ledgr_state_asof()` computes `positions_value` from `close_by_id[
  instrument_ids]`, which is `NA` for any held ID with no bar at the query
  timestamp; equity becomes `NA` with no error.
- **Why it matters:** Both are unreachable in `dense_static` by
  construction (finite positive opens are enforced at `R/fill-model.R:55-57`
  and `67-69`; the rectangle guarantees a close). Both become reachable
  under `ragged_pit`. The seed cites the final-bar path as the precedent for
  its reason-coded diagnostic and does not mention that a silent sibling
  exists in the same function.
- **Required correction:** v2 Section 19 should add "drops a proposed fill
  without a reason-coded diagnostic" and "reports `NA` equity or value
  without an explicit `unpriced` state" to the forbidden list, and Section
  16 should note that dense parity preserves these branches only because
  they are unreachable, which the ragged specification must prove or
  remove.

### F-14 -- Leak surfaces beyond strategy helpers are not enumerated

- **Severity:** Low. **Class:** implementation concern. **Blocks v2:** no;
  v2 should enumerate.
- **Seed sections:** 8.2 ("must not be exposed through a helper"), 19 ("or
  timing"), 22 item 2.
- **Verified current-code evidence:** `R/sweep.R:223-241` -- the runtime
  projection is built from the precompute payload over the fixed universe
  and, for parallel dispatch, the experiment payload and projection are
  what workers evaluate (`R/sweep.R:961-973`, mirai invocation at
  1193-1201); I did not trace the exact serialized field list. Contracts,
  Context: `ledgr_pulse_wide()` and `ledgr_pulse_features()` are public
  read-only views "over pulse-known data"; `ledgr_backtest_bench()` and
  `run_telemetry` report counts.
- **Why it matters:** Under the seed's design every worker holds the whole
  bounded frame including future-ID rows. That is not a strategy leak, but
  worker-side telemetry, error messages that print instrument lists, the
  public wide/feature inspection views, and pulse-count or
  instrument-count telemetry are all channels the seed's Section 19 forbids
  and Section 8.2 does not cover.
- **Required correction:** v2 Section 8.2 should name the public views
  (`ledgr_pulse_wide()`, `ledgr_pulse_features()`, `ledgr_feature_contracts()`),
  telemetry counts, error-message instrument lists, and worker payload
  diagnostics as surfaces that must be membership-filtered, and Section 20
  should make the future-ID perturbation test cover them.

### F-15 -- `unknown` visibility wording contradicts the state table

- **Severity:** Low. **Class:** wording. **Blocks v2:** no.
- **Seed sections:** 5 (row "Unknown": "never silently coerced to false,
  absent, or valid"), 9.1 ("absent ... until they become knowable and
  effective").
- **Why it matters:** Visibility must be a strict predicate (`member ==
  TRUE`), so an `unknown` membership state is *not visible*. That is the
  safe direction and the seed intends it, but as written Section 5 reads as
  forbidding exactly that outcome.
- **Required correction:** State in Section 5 that consumers apply strict
  predicates to state values and that `unknown` fails every positive
  predicate (not visible, not expected, not eligible) while remaining
  distinguishable in the state plane and diagnostics. The prohibition is on
  *storing* unknown as false, not on *acting* conservatively on it.

### F-16 -- `ctx$members` is a Context Contract change even in dense mode

- **Severity:** Low. **Class:** implementation concern. **Blocks v2:** no.
- **Seed sections:** 9.1, 18 row 12 ("proposed `ctx$members` is identical").
- **Verified current-code evidence:** `R/pulse-context.R:13-29` (context
  fields), `810-849` (`ledgr_validate_pulse_context` validates `universe`
  and the data frames; no `members` field exists).
- **Required correction:** v2 should say that adding `ctx$members` (and any
  `ctx$state()` accessor) is an additive Context Contract change recorded
  in `contracts.md` for both modes, that `ledgr_validate_pulse_context()`
  validates `members` as a subset of `universe`, and that in `dense_static`
  it is identical to `universe` by construction (a testable parity
  property).

### F-17 -- External-source recheck status

- **Severity:** Informational. **Class:** missing verification in this
  session.
- The scikit-learn, Nasdaq, and ALFRED claims were confirmed verbatim
  (Section 3). The Zipline `can_trade()` / `is_stale` claim could not be
  reverified (HTTP 403). It is used only as supporting precedent for
  separating availability axes, which the Nasdaq and ALFRED sources also
  support, so nothing in this response depends on it. v2 may keep the
  citation; the response review may wish to re-attempt it.

---

## 5. Strategy-Domain and Future-Leakage Analysis

**The union design is forced, not merely chosen.** `ctx$hold()` aborts when
`positions` names an ID outside `ctx$universe` (`R/pulse-context.R:767-773`),
and `ledgr_validate_strategy_targets()` requires every universe name and
rejects every extra name (`R/strategy-contracts.R:78-93`). A members-only
public universe would therefore break `ctx$hold()` on the first pulse an
instrument was held after leaving membership, and the alternative -- a
separate target-only alignment domain -- would require the validator to
accept names outside `ctx$universe`, which is the "smuggled through a helper"
change the seed forbids. `ctx$universe = members union held` is the only
shape that keeps one aligned domain. Verified, and the seed should say that
the code compels it.

**What the union design does not settle.** Three things follow from
alignment that the seed does not carry through:

1. *What the aligned vectors hold for a held-inactive ID.* `ctx$vec$close`
   must be the same length as `ctx$universe` (`R/pulse-context.R:578-592`;
   `R/risk-model.R:455-458`). The seed's own rules imply `NA` there; the
   consequences for risk (F-1) and for the helper pipeline (F-2) are the
   High findings.
2. *What the default target is.* Two constructors, two answers (F-2).
3. *Whether the admissibility rule survives risk.* It does not (F-3).

**Cross-sectional ergonomics.** `ctx$members` as the cross-sectional
denominator is right. Two consequences the seed should state: `ctx$idx()`
becomes pulse-local (F-7); and `ledgr_select_top_n()` (Contracts, Strategy:
"ignores missing signals and breaks ties by instrument ID") must select over
`members`, never over `universe`, or a held former member with a warm
feature could be re-selected into a position it cannot execute.

**Future-ID leakage.** The seed closes the strategy-visible channels
(names, positions, helpers, dimensions) correctly. Three channels remain
open in the text: the pulse axis itself (F-6 -- the rule for observed rows of
not-yet-knowable instruments is unstated), fold-fitted transforms whose
fit set is defined by the frame rather than by the per-pulse member set (the
seed's Section 12 says "fit only on the fold's training rows" but "rows" must
be *member* rows at each training pulse, not frame rows, or a future member's
pre-membership history enters the fit), and non-strategy surfaces (F-14).
The pre-membership feature-history allowance in Section 11 is sound *only*
if the history is computed under a per-instrument source-domain rule whose
identity is in the feature key (F-9); a cross-sectional feature computed
over pre-membership rows is a leak by construction and the seed should say
so explicitly.

**Walk-forward state carried into a test fold.** The mechanism exists
(`carry_test_state`), it is fail-closed today, and the seed does not name
the validators it must change (F-4). The seed's 18 row 10 claim "fitted
universe cannot see future IDs" is correct only if the training fit is
restricted to per-pulse members (above).

---

## 6. State-Model Analysis

The ten-concept table in seed Section 5 is the right decomposition, and the
Sharadar taxonomy (nine classifications over 101 cells) shows that at least
lifetime, expectation, observation, and validity vary independently in real
data. Three observations:

**Independence holds; closure does not.** The seed treats the concepts as
orthogonal facts and that is correct for storage. But several *derived*
predicates are functions of more than one plane and the seed does not name
them, and they split along the boundary the Execution Contract binds
("Strategy contexts carry decision-time information only ... so next-bar
execution data cannot leak into strategy decisions") and seed 13.2 repeats.
Decision-time, visible to the strategy: "visible" = member OR held (the
seed's own union rule in 9.1, so a held non-member is visible and `unknown`
membership alone is not); "target_restricted" = known-inactive as of the
decision pulse; the ID stays in the target vector, because the full-vector
contract requires a target for every visible ID, and only its admissible
values narrow (nothing about the execution bar is implied); "admissible" = a
property of a target rather than of an instrument: on a restricted ID, the
current quantity or zero, which is zero alone when the ID is not held (F-3);
unconstrained otherwise; "valued" = a mark exists that is fresh, or stale
within the declared maximum age -- `unpriced` is the *absence* of a
valuation, not a kind of it. Execution-time, evaluated by the fill layer and
never exposed on the strategy context: "fillable" = an accepted observation
with a valid execution price exists at the execution pulse AND the instrument
is not known-inactive as of that pulse. Under next-open execution "fillable"
depends on the next bar and so cannot be a decision-time predicate; an
earlier draft of this response folded it together with admissibility into one
"executable" predicate, which was a lookahead channel. A specification will
need these derived predicates as the actual consumer API; v2 should list them
on each side of the boundary so that the state planes are not consumed ad
hoc.

**One missing state.** "Held" is not in the table. Whether an ID is in
`ctx$universe` depends on it (9.1), the admissible-target rule depends on it
(9.2), and the terminal-boundary gate depends on it (15). It is position
state rather than availability state, but the derived predicates above all
branch on it, so the seed should name it as an input plane of the decision
frame.

**Combinations the seed should enumerate.** Illegal: `known_inactive` with an
`accepted` observation at the same pulse (source contradiction -- classify,
do not silently prefer either). Legal but easy to mishandle: `not_expected`
with `accepted` (the Sharadar `observed_row_outside_expectation` case --
allowed, recorded, and subject to the F-6 rule for the pulse axis);
`unpriced` without `target_restricted` (legal, and it is the relisting case:
the classification says active as of the decision pulse, no accepted close
exists there, and an accepted open exists at the execution pulse -- the
restriction plane and the valuation plane are separate and a specification
must not derive one from the other); `member` with `unknown` lifetime
(allowed; visibility follows membership, valuation follows observation).
Writing these down is cheap and prevents a specification from collapsing
them.

**Where the proposal still collapses semantics.** Only one place: the
`ctx$vec$close` vector, which under the seed's rules must carry `NA` for
both "not expected today (closure)" and "expected but absent" and "held,
inactive, stale mark exists". That is acceptable for the *strategy* (it must
consult `ctx$state()` to distinguish) but not for risk and valuation (F-1),
which need the plane, not the collapsed vector.

---

## 7. Storage/Runtime Alternatives and Architecture-Spike Critique

The seed's Section 6 table is fair. Two corrections to its reasoning and
one to its process:

**"Static superset plus orthogonal masks" is rejected for a reason that does
not distinguish it from the preferred base.** The rejection is "a public
superset still leaks future IDs". But the preferred base also keeps a fixed
internal axis over the bounded window (7 rule 4, 8.2); the difference is
only that its axis is *bounded and internal*. A superset-plus-masks
prototype with an internal, membership-filtered public view is the same
design with a different storage layer. The spike should compare *storage*
(sparse facts vs dense canonical) and *view construction* (bounded
fold-local vs whole-history) as independent axes, which the seed's own
sentence "Physical DuckDB storage and consumer-facing representation are
independent choices" already admits. Otherwise the four prototypes differ on
two axes at once and the comparison cannot attribute cost.

**"Sparse/event-native execution ... could become a second engine" is a
contract argument, not a performance argument.** It disqualifies that
prototype under the Execution Contract before any measurement. The seed
should say so and either drop it from the spike or include it explicitly
as a *materializer* comparison feeding the same fold core.

**The spike cannot choose without falsification criteria** (F-12). With
them, it can: the safety properties disqualify, the parity properties
disqualify, and the measurements rank. The fixture scale must match the
empirical population's shape (hundreds of instruments, hundreds of
sessions, tens of percent churn) or the memory question the seed asks in
Section 17 is unanswerable.

**Fair comparison of the alternatives on the properties that matter here:**

| Property | Dense + state planes | Dynamic active matrices | Sparse facts + fold-local dense |
| --- | --- | --- | --- |
| Future-ID invisibility | Achievable if the public view is filtered; the internal axis is the whole superset, so the perturbation test is the proof | Strongest by construction; axis contains only knowable IDs | Achievable; internal axis is bounded to the window's union, so perturbation outside the window is trivially invariant and inside it needs the filter |
| Held-inactive alignment (F-1..F-4) | Same problem in all three; the plane is what solves it | Held IDs must be retained in the active set -- the seed's union rule, again | Same |
| Cache key shape (F-9) | Per-instrument keys stay valid; feature-domain keys are new | Every remap invalidates positional caches | Per-instrument keys stay valid; frame-level keys are new |
| Dense parity | Trivial (it is the current path plus inert planes) | Hardest (axis differs from today) | Achievable if the bounded window equals the run window and the axis order equals today's sorted universe |
| Memory at 563 x 757 | Full rectangle plus planes | Smallest | Bounded rectangle per fold; whole-history rectangle avoided |

This table is reasoning, not measurement; it supports keeping all three in
the spike and dropping event-native execution as an executor.

---

## 8. Calendar and Preprocessing Analysis

**Calendars.** The seed's ownership split (run plan owns the global pulse
axis; versioned source owns per-market sessions; expectation policy combines
them) is correct and is the only arrangement under which a scheduled closure
can be `not_expected` rather than missing. The unresolved piece is the rule
for observed rows outside the declared calendar (F-6). Two further cases the
seed should state: an *unscheduled* closure (weather, outage) is knowable
only after the fact, so the expectation policy must be able to carry
`unknown` for a session and the run must not abort on `expected` with zero
accepted observations across the whole venue -- that is a venue-level
absence, not per-instrument; and cross-venue closes at different UTC
instants raise a question the seed's "global union" must answer explicitly:
whether the pulse axis is the union of distinct session-close instants (two
pulses on one date) or one pulse per date with per-venue expectation state
(one pulse, two states). The whole-second UTC contract (Contracts, Snapshot:
sub-second timestamps fail sealing) constrains the pulse key but does not
decide this; the union rule does, and it is a maintainer choice (Section
12).

**Deterministic transforms before indicators.** The typed DAG is sound.
The one rule the seed should add: a source-domain transform may read only
the instrument's own history plus explicitly declared state, never another
instrument's values -- otherwise it is a feature-domain node and takes the
new cache key family (F-9).

**Fold-fitted preprocessing.** Confirmed against scikit-learn's primary
text. The seed's rule is right. Its identity placement is wrong (F-8), and
its fit set must be defined as per-pulse member rows (Section 5 above).
"Simple backtest" versus walk-forward stays distinct only if the simple
backtest *refuses* fitted nodes or forces an explicit training boundary;
the seed says the latter ("the whole backtest is not an acceptable implicit
fit set") -- v2 should make it a classed error rather than a documentation
rule.

---

## 9. Valuation, Execution, Identity, and Accounting Analysis

**Valuation.** fresh / stale-with-age / unpriced is the right result shape.
The seed's rule that a stale mark is never relabeled current is the
important one and is why F-1 exists: the mark needs its own plane. The
unpriced default is F-11.

**Execution.** The reason-coded non-order diagnostic is sufficient and is
the correct pre-OMS shape provided three things hold: it is emitted at most
once per (pulse, instrument, target) and never carried; it is a diagnostic
row, not a `ledger_events` row (the accounting stream must stay
economic-events-only, per Contracts Execution "event-stream meaning"); and
the *strategy* does not become the carrier through its default target
(F-2). With F-2 resolved the diagnostic cannot become an order lifecycle,
because nothing persists a desire across pulses except the strategy's next
output.

**Identity.** The layer table in seed 14.1 is complete in kind and needs one
row split (F-8) and one placement answered (F-5). The invalidation rule
"compare the complete typed dependency identity" is correct and is already
how the feature cache works. One addition: the seed should state that the
*classification* and *calendar* identities enter `experiment_hash` (they are
experiment-level policy, like `timing_model`), while *valuation* and
*execution-eligibility* policies enter run identity (they are execution
policy, like `cost_model_hash`), and that neither enters `snapshot_hash`.
That placement follows the existing split between config and execution
identity in the Execution Contract.

**Accounting boundary.** The coordinated-sibling framing is viable. The
smallest ragged capability that can ship before the sibling is: IPO / late
listing, point-in-time membership with `dense_static` parity, one EOD
calendar with scheduled closures, halts as execution-ineligible state, and
held-through-inactivity *only* under the F-11 default (classified run-stop
or bounded stale continuation, never a completed performance claim). That
excludes every terminal event and every distribution, which is where the
Cross-Asset research places the first accounting tranche ("cash dividends
and fund distributions, splits ... delistings/symbol changes"). Ticker
changes with a stable ID are identity, not accounting, and may ship in the
first tranche.

---

## 10. Dense Parity and Performance Analysis

**`dense_static` is a name for current behavior.** Verified: the seed's
Section 16 bullet list matches the code path exactly (V5-V9, V14-V18). Two
qualifications the seed should carry: the *reconstruction* path
(`R/derived-state.R:146`) is a second rectangle gate and must be part of
the parity oracle; and the silent branches in F-13 are part of "current
behavior" and should be excluded from parity by proving unreachability
rather than preserved.

**Bit-identical is realistic for some identities and impossible for others**
(F-10). The omit-when-default rule makes the impossible set empty for dense
artifacts.

**Performance.** The seed makes no unmeasured claim and this response makes
none. The per-pulse cost concern in Section 17 ("no per-instrument database
query or R loop on every pulse") is already the accepted posture from the
optimization arc; the new risk is the *frame build* (materialization of
planes per fold) and the *state-plane branch* inside the hot loop, which
the spike's ranking measurements should isolate (F-12 c). Memory: the
bounded window's rectangle is `|axis_ids| x |pulses|` per numeric plane
plus one byte or bit per state plane per cell. This response makes no
statement about whether that is acceptable at the empirical population's
shape; the spike must measure peak process memory and materialized-frame
bytes separately at that shape (F-12 c) before any such statement is made.

---

## 11. Required Seed v2 Changes

Ordered by the finding that drives them.

1. **(F-1)** Bind what `ctx$vec$close` carries for a held ID with no
   accepted decision-time observation and give risk a valuation-plane input
   or a pass-through rule; state that `risk_chain_hash` is unaffected.
2. **(F-2)** Bind zero as desired quantity zero everywhere; zero-default
   constructors and helpers initialize held non-members to their current
   quantity; liquidation is an explicit zero assignment with no execution
   marker; `ctx$flat()` and `ctx$hold()` stay distinct for members.
3. **(F-3)** Keep hold-or-zero as the strategy-output rule on known-inactive
   held IDs; bind post-risk admissibility to targets that are zero or
   same-sign with magnitude no greater than the admissible strategy target;
   leave partial reductions at strategy output to Section 12.
4. **(F-4)** Name `ledgr_experiment_validate_opening()`, the
   `config-validate.R` opening check, `ledgr_lot_state_asof()`, and
   `initial_positions` as touchpoints that validate against `axis_ids`.
5. **(F-5)** Answer seed question 9: lineage and classification-input
   digests live in a hashed fact table; the combination rule is versioned.
6. **(F-6)** State the not-knowable-row invariant, add it to Section 19,
   and choose abort, quarantine, or classify-and-ignore as the default with
   the selection-effect caveat if abort; declare the calendar set as
   identity.
7. **(F-7)** State that positional accessors are pulse-local under
   `ragged_pit`.
8. **(F-8)** Split recipe identity (candidate layer, feeds the seed) from
   fitted-artifact identity (recorded and verified, never fed back);
   candidate-and-fold fit seeds; ambient-RNG fits invalid for walk-forward.
9. **(F-9)** Scope the `ledgr_feature_cache_v2` family to source-domain
   per-instrument nodes; define a new namespace for feature-domain nodes;
   add the admissible-history rule to the per-instrument key.
10. **(F-10)** List identities as bit-identical vs approved-equivalent;
    bind `dense_static` as the omitted default value; leave schema-version
    bumps to the specification.
11. **(F-11)** Propose the `unresolved_terminal` run-stop default (or its
    opt-in inverse) for the maintainer.
12. **(F-12)** Bind spike fixtures, disqualifying properties, ranking
    measurements, and the shared-materializer requirement -- as a spike
    charter accepted at response review if the seed's spike-before-v2 order
    is kept (Section 15).
13. **(F-13, F-14, F-15, F-16)** Add the forbidden behaviors, enumerate the
    non-strategy leak surfaces, fix the `unknown` wording, and record
    `ctx$members` as a Context Contract change.
14. **(Section 6)** Add "held" as a named input plane; enumerate the derived
    predicates on each side of the decision-time / execution-time boundary
    (visible, target_restricted, admissible, valued; fillable) and the legal
    and illegal combinations, including `unpriced` without
    `target_restricted` as legal.
15. **(Section 7)** Separate the storage axis from the view axis in the
    alternatives table; drop or reclassify event-native execution.
16. **(Section 8)** Add the unscheduled-closure rule and decide the
    cross-venue pulse-axis rule; make an unbounded fit set a classed error.
17. **(Section 16)** Adopt, adapt, or reject the strategy-author UX and
    workflow proposal; whatever is adopted must be recorded as Context and
    Strategy Contract changes, not as helper conveniences, and must expose
    no execution-pulse-dependent field on the strategy context.

---

## 12. Decisions That Remain Legitimate Maintainer Choices

These are not defects. The seed should present them as choices, and this
response does not pick for the maintainer:

- **Partial liquidation at strategy output** (F-3): whether a same-sign
  reduction other than zero is admissible on a known-inactive held ID, or
  such reductions are reachable only through a risk step.
- **Not-knowable rows** (F-6): abort, quarantine, or classify-and-ignore as
  the first-implementation default.
- **Unpriced default** (F-11): run-stop by default with stale-continuation
  opt-in, or the inverse.
- **First-implementation risk admissibility** (F-1): whether only price-free
  steps are admissible on unpriced held IDs in v1, or the valuation plane is
  built in v1.
- **Whether `ctx$idx()` misuse is detected or only documented** (F-7).
- **Cross-venue pulse-axis rule** (Section 8): union of close instants, or
  one pulse per date with per-venue state.
- **Whether the first calendar scope is one EOD venue** (seed 10.1) -- the
  evidence supports it; the identity must still allow more.
- **Spike sequencing** (Section 15): spike-before-v2 with a charter bound at
  response review, or v2-before-spike.
- **Fixture scale for the spike** beyond the minimum in F-12.
- **Whether dynamic active matrices stay in the spike** after the storage /
  view axes are separated (Section 7).
- **Which of the Section 16 surfaces ship in the first implementation.**

---

## 13. Evidence Limitations Preserved

Each limit the prompt requires is confirmed present in the seed and is
carried unchanged here. Nothing in this response relaxes any of them.

- Accepted empirical scope is only `dense_static_method_validation_v001`
  (seed 2.1; Sharadar closeout table).
- No confirmed `expected_session_absence` cell was observed (seed 2.1, 18
  row 3; Sharadar Gate 3: zero of 101).
- No imputation experiment was performed (seed 2.1; Sharadar claim ledger).
- The successful trade proof covered one instrument and zero costs (seed
  2.1; Sharadar Gate 2).
- Simultaneous multi-position and nonzero-cost behavior was not established
  (seed 2.1; Sharadar Gate 2 limitations).
- Broad-equity, dynamic-membership, dividend-inclusive, and terminal-event
  performance remain unauthorized (seed 2.2, 19; Sharadar non-conclusions).
- Vendor labels are evidence, not ledgr schema or event types (seed 2.2, 5,
  19; Sharadar census note).

Additional limits this response introduces about itself: the Zipline
primary source was not reverified here (F-17); the parallel-worker payload
field list was not traced to its serialization site (F-14 states the
inference and its basis); no performance number is asserted.

---

## 14. Response Disposition Table

| Attack surface (prompt) | Disposition | Findings | Blocks v2? |
| --- | --- | --- | --- |
| 1. Strategy-domain evolution | Union design corroborated by code (V24); three defects at the seam; public shape proposed | F-1, F-2, F-3, F-4, F-7, Section 16 | Yes (F-1..F-4) |
| 2. Future-information leakage | Strategy channels closed; not-knowable-row invariant, fit-set definition, and non-strategy surfaces to bind | F-6, F-9, F-14, Section 5 | Yes (F-6, F-9) |
| 3. State model | Independence holds; derived predicates, the "held" plane, and legal/illegal combinations missing from the seed | F-15, Section 6 | No (record in v2) |
| 4. Storage/runtime alternatives | Direction survives; spike lacks falsification; storage and view axes conflated | F-12, Section 7 | Yes (F-12) |
| 5. Calendars and expected observations | Ownership correct; not-knowable-row rule is a product choice under a binding invariant; unscheduled-closure and cross-venue cases unstated | F-6, Section 8 | Yes (F-6 invariant) |
| 6. Indicators and preprocessing | DAG sound; fit-set definition and identity layering wrong | F-8, F-9, Section 8 | Yes |
| 7. Valuation, execution, pre-OMS diagnostics | Result shapes right; risk has no mark; zero-default constructors need a rule for held non-members; unpriced default open | F-1, F-2, F-11, F-13, Section 16 | Yes (F-1, F-2) |
| 8. Identity and cache invalidation | Layer table complete in kind; recipe/artifact split needed; lineage placement to be answered; parity needs an omit-default rule | F-5, F-8, F-9, F-10 | Yes (F-8, F-9, F-10) |
| 9. Accounting boundary | Sibling framing viable; minimum shippable capability and blocker representation proposed | F-11, Section 9 | No (product choice) |
| 10. Dense parity and performance | `dense_static` is current behavior; reconstruction gate and silent branches must be named; memory is a spike measurement, not a claim | F-10, F-13, Section 10 | Yes (F-10) |
| Evidence discipline | All seven limits intact; no default outruns the record | Section 13, F-17 | No |
| Strategy-author UX (added) | Opinionated, non-binding proposal for v2 to adopt, adapt, or reject | Section 16 | No (v2 decision) |

Seed Section 22 attack items map onto the same rows: items 1, 2, 3, 4, 5,
6, 7, 8, 9, 10, 11, 12, 13 correspond to surfaces 1, 2, 3, 5, 6, 6, 7, 7,
8, 10, 10, evidence, 4 respectively.

---

## 15. Recommended Next RFC Stage

Proceed to **stage 4, response review**, by the maintainer or the seed
author. The findings warrant a **Seed v2** because three High items change
contract text (Context, Strategy, Execution) rather than wording.

On sequencing, the seed's Section 23 places the bounded comparative
architecture spike *before* Seed v2. An earlier draft of this response
placed it after v2 while claiming to follow the seed; that was wrong. This
response now selects explicitly: **keep the seed's order** -- spike before
v2 -- on condition that the spike runs under a charter bound at response
review: the fixtures, disqualifying properties, ranking measurements, and
shared-materializer requirement in F-12. That preserves the seed author's
intent that v2 resolve attacks with evidence, and removes the risk that the
spike author invents the criteria the spike is judged by. If the maintainer
prefers v2-before-spike, F-12 is bound in v2 instead and nothing else in
this response changes.

No maintainer-decisions artifact (stage 6) is needed yet; the product
choices in Section 12 can be carried as explicit alternatives in v2 and
escalated only if v2 cannot state a default. The synthesis author should be
neither the seed nor the v2 author, per `../rfc_cycle.md` role rotation.

---

## 16. Proposed Strategy-Author UX and Workflow (Non-Binding)

The three High findings are failures of the public shape, not of the
engine. This section proposes the shape. It is opinionated on purpose,
tidyverse-adjacent by design (verbs, pipes, tibbles in and out, vectors not
loops, safe defaults, errors that say what to do next), and entirely
non-binding: every name is illustrative and falls under the v0.1.9.5 naming
contract; Seed v2 may adopt, adapt, or reject each item. Nothing here is an
API commitment or an implementation authorization.

### 16.1 Seven principles

1. **Safe by default.** The constructors a beginner reaches for first must
   not sell a held instrument the author never named.
2. **Quantities stay quantities.** Zero always means desired quantity zero.
   `ledgr_target` stays a thin wrapper; no target carries a command or an
   execution marker.
3. **One contract.** A strategy is still `function(ctx, params)` returning a
   full named target vector. A dense strategy is a valid ragged strategy.
4. **Decision time only.** Nothing on the strategy context depends on the
   execution-pulse bar. Whether a target fills is the fill layer's verdict,
   reported afterwards.
5. **Planes are vectors.** Every strategy-visible as-of plane is exposed on
   `ctx$vec` as a universe-aligned vector; the engine physically holds more
   (future rows, execution bars) and none of it reaches `ctx`. No
   per-instrument state calls in the hot path.
6. **Members are the cross-section; the universe is the ledger.** Signals,
   ranks, and weights are computed over `ctx$members`. Targets are returned
   over `ctx$universe`. The helpers do the bridging.
7. **Evidence is a tibble.** Every availability fact and every non-order
   diagnostic is one row you can `filter()`, `count()`, and join.

### 16.2 The mode is the type of the universe argument

Today `universe` is a character vector and means "these instruments, every
pulse". Proposed: keep that meaning exactly -- a character vector *is*
`dense_static` -- and let a classed rule object select `ragged_pit`:

```r
# dense_static (unchanged)
exp <- ledgr_experiment(snapshot, strategy, universe = c("AAA", "BBB"))

# ragged_pit: membership is a sealed fact family in the snapshot
exp <- ledgr_experiment(
  snapshot, strategy,
  universe = ledgr_universe("sp500", as_of = "knowledge")
)
```

There is no `semantic_mode` string to forget. A ragged snapshot with a
character universe fails closed today (coverage error) and should keep
doing so; a dense snapshot with a rule object fails closed with "snapshot
carries no membership facts". The rule object's canonical JSON is the
universe-construction identity the seed's Section 14.1 requires.

Membership, lifetime, and calendar facts enter at seal time as tidy tables:

```r
snapshot <- ledgr_snapshot_from_df(
  bars, instruments,
  membership = ledgr_membership(members_long),  # universe_id, instrument_id, from, to, known_at
  lifetime   = ledgr_lifetime(listings),        # instrument_id, from, to, known_at, assertion
  calendar   = "XNYS"
)
```

Absent tables mean absent facts, never inferred ones (seed 2.2).

### 16.3 What the strategy sees

`ctx$members` (character) and, on `ctx$vec`, three new universe-aligned
logical fields plus one integer field:

| Field | Meaning at this pulse |
| --- | --- |
| `ctx$vec$member` | knowable point-in-time member |
| `ctx$vec$priced` | an accepted decision-time mark exists (fresh, or stale within policy) |
| `ctx$vec$target_restricted` | known-inactive as of this pulse (halted, pre-listing, delisted, per the as-of classification); the ID stays in the target vector and its admissible targets are hold or zero |
| `ctx$vec$mark_age` | periods since the mark's source observation; `0` when fresh |

`target_restricted` is decision-time knowledge only, and it restricts values
rather than participation: every visible ID, a restricted holding included,
carries a target because the full-vector contract requires one. It does not
say whether an unrestricted target will fill: under next-open execution that
depends on the execution pulse's bar, which the strategy cannot know. The
fill layer evaluates fillability at the execution pulse and reports its
verdict in the diagnostics view (16.6), never on `ctx`. This is the Execution
Contract's decision-time boundary and seed 13.2 unchanged; earlier drafts of
this section exposed an `eligible` field that crossed it and a `submittable`
field that described restriction as exclusion.

`ctx$vec$close` is `NA` wherever `!priced`. `ctx$state(id)` remains for
inspection and error messages and returns a one-row tibble; it is not the
hot path. Feature validity collapses to one authoring guard:

```r
ledgr_usable(x)   # TRUE where a feature value may be consumed; the six-state
                  # taxonomy stays available in ledgr_availability() for audit
```

### 16.4 The two idioms, ragged-safe

Vectorized scalar strategy -- identical shape to today's:

```r
strategy <- function(ctx, params) {
  targets <- ctx$flat()                         # zero for members; current qty for held non-members
  ret20   <- ctx$vec$feature("ret20")
  buy     <- ctx$vec$member & ledgr_usable(ret20) & ret20 > params$threshold
  targets[buy] <- params$qty
  targets
}
```

Helper pipeline -- identical to today's, because the helpers bridge:

```r
strategy <- function(ctx, params) {
  ledgr_signal_return(ctx, lookback = 20) |>    # over ctx$members only
    ledgr_select_top_n(n = params$n) |>         # ranks members only
    ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx)                 # sizes members; current qty for held non-members
}
```

Liquidating a held non-member is an explicit zero, written so the intent
reads:

```r
targets <- ledgr_target_rebalance(weights, ctx)
targets <- ledgr_liquidate(targets, "XYZ")     # targets["XYZ"] <- 0, nothing more
```

This is F-2's recommended rule made concrete. Zero always means desired
quantity zero. The constructors initialize held non-members to their current
quantity, so `ctx$flat()` is flat for members and holds everything else, and
a beginner cannot sell what they did not name by reaching for the default.
`ledgr_liquidate()` is assignment sugar whose name states intent; it adds no
marker, and `ledgr_target` stays a thin wrapper. A raw zero vector built by
hand is literal: it requests an exit of every held non-member, which the fill
layer executes when the instrument can trade again and which the diagnostics
view shows as pending until then. Plain full named numeric vectors remain
valid strategy output under the Strategy Contract; constructor safety is an
ergonomic guarantee, not a restriction on what a strategy may return.

### 16.5 Errors that say what is admissible

```text
Error in strategy at 2019-03-04: target for "XYZ" is 150 but XYZ is held
(100) and target-restricted this pulse (decision-time state: known_halted).
Admissible targets: 100 (hold) or 0 (exit when XYZ can trade again).
Use ledgr_liquidate(targets, "XYZ") to request the exit.
```

Every admissibility error names the instrument, the decision-time state that
restricts it, the current quantity, and the admissible set. It is the F-3
strategy-output rule turned into a message. A target that was admissible but
does not fill at the execution pulse is not an error; it is a reason-coded
diagnostic row.

### 16.6 Evidence you can explore

```r
ledgr_availability(bt)
#> # A tibble: 24,120 x 10
#>   ts_utc     instrument_id member expected observed accepted mark_state mark_age target_restricted reason
#>   <date>     <chr>         <lgl>  <lgl>    <lgl>    <lgl>    <chr>         <int> <lgl>             <chr>

ledgr_availability(bt) |> count(reason, sort = TRUE)
ledgr_availability(bt) |> filter(instrument_id == "XYZ", target_restricted)

ledgr_results(bt, what = "diagnostics")           # fill-layer verdicts: reason-coded non-order rows
ledgr_results(bt, what = "diagnostics") |> count(reason)
```

Both are read-only views over persisted planes (Contracts, Result). The
availability view holds decision-time state; the diagnostics view holds the
fill layer's execution-time verdicts, deduplicated per (instrument, episode)
with `first_ts_utc`, `last_ts_utc`, and `n_pulses`, so a ten-session halt is
one row, not ten. Both tibbles are plot-ready; whether any article plots
them is a separate, per-item authorization under the vignette styleguide.

### 16.7 What this costs and what it does not

Adds: two fact-table constructors, one rule object, four `ctx$vec` fields,
one guard, one assignment helper, two result views, and admissibility-aware
messages. Changes: zero-default constructors initialize held non-members to
their current quantity (F-2), and the helper pipeline's bridging rule. Does
not change: the target-quantity contract, the strategy signature, the
full-vector contract, dense behavior, the byte-identity of existing
`dense_static` hashes (F-10), the one fold core, or the decision-time
boundary of the strategy context. Adds to identity, necessarily: the universe
rule's canonical JSON and the hashed membership, lifetime, and calendar fact
families (16.2), which `ragged_pit` runs carry and `dense_static` runs omit.
Does not add: a second strategy path, a callback, an event API, a
per-instrument state loop, or any marker on a target.

The test of whether v2 has kept this shape is one sentence: *a strategy
written against the dense mode runs unchanged in ragged mode, its
constructors never sell a held instrument the author did not name, and
nothing it can read depends on the execution-pulse bar.*

---

This response does not authorize implementation, a specification, tickets, a
schema, a public API, or any change to accepted contracts.
