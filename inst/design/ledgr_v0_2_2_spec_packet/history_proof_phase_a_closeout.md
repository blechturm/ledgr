# Cut 16 Workstream 44 phase A closeout: history proof and API bridge

Role: record; Workstream 44 phase A implementation evidence (LDG-3072,
LDG-3081, the LDG-3071 API items and LDG-3068).
Authority: non-binding. `tickets.yml` owns status and `contracts.md` owns
behaviour.
Status: LDG-3072 and LDG-3081 are complete. LDG-3068 is `review_pending`:
its acceptance item 5 (fast and review profiles) is recorded by the
coordinator. LDG-3071 stays `open` (phase B owns its teaching and
reconciliation); its three API items are implemented. The `NEEDS_TYPE_2`
raised by LDG-3068 was decided by the maintainer as Cut 16 decision (29) and
is implemented (below). The independent close review
(`close_review_44a.md`) returned CHANGES_REQUIRED; Correction 1 below
answers it, and Correction 2 answers its focused re-review under Cut 16
decision (30), and Correction 3 answers re-review 2. Workstream 44 stays
`open`.

BASE is `6f019c6b` (`integrate/cut15-v0.2.2`, accepted Workstreams 40-43, 46
and 47). Branch `ws44/history-proof`: the implementation is `f61d6fca`, the
first record `75636976`, and decision (29) with its record the commits after
those.

## What changed for a ledgr user

- A strategy can no longer read private context internals. Code such as
  `ctx$.history$service$substrate$bars` or
  `environment(ctx$feature)$...` reached prepared data after the pulse and
  still passed preflight as Tier 1; it is now Tier 3 and refused before any
  run, sweep or walk-forward writes anything. Every existing strategy keeps
  its tier.
- `print()` of a result used to say `max sessions 5 (default)`, which read
  like the history policy's price carry. It now says `valuation stale-mark
  horizon 5 sessions (default)` and adds a `History policy:` line (price
  carry, output carry, segment limit, each `default` or `declared`).
  `summary()`, `ledgr_experiment_plan()` and `print()` of an experiment show
  the same.
- Three helpers close the estimator round trip without `colnames()` or
  `attr()`: `ledgr_history_info(x)` returns the result's selection table,
  exclusions, cutoff, window and lookback; `ledgr_history_weights(x, w)`
  names solver output by the result's included instruments and refuses a
  mismatch; `ledgr_history_sufficient(x)` reuses the lookback the result was
  read with. `print()` of a history result names `ledgr_history_info()`.
- The contract now says which units corporate-action amounts use under
  `split_adjusted`: per split-adjusted share. ledgr credits the amount times
  the held split-adjusted quantity and converts nothing at a split, so an
  as-traded amount from before a split is credited too large by the split
  factor (a registered witness shows 5 against 10 for a 2:1 split).
- Feature history is now stated and implemented as a vintage view (Cut 16
  decision 29): after a lifetime fact becomes known late, a history read
  shows each earlier feature cell with the value and the evidence it had at
  its own pulse; bar history is restated with what is known at the cutoff.
  Before this, those cells showed their earlier values next to evidence
  computed with the later knowledge.

## Proposed function names

| Name | Usage | Notes |
| --- | --- | --- |
| `ledgr_history_info()` | `info <- ledgr_history_info(returns); info$excluded_ids` | Family-first like `ledgr_run_info()`; returns a `ledgr_history_info` list; the print footer of a `ledgr_history` names it. |
| `ledgr_history_weights()` | `returns \|> ledgr_history_weights(solver$solution) \|> ledgr_target_rebalance(ctx)` | History result first, like `ledgr_history_matrix()` and `ledgr_history_sufficient()`; refusal class `ledgr_history_weights_mismatch`. A considered alternative was a `history =` argument on `ledgr_weights()`; it was not taken because the family-first rule puts history helpers under `ledgr_history_*`. |
| `ledgr_history_sufficient()` (changed) | `if (!ledgr_history_sufficient(returns, min_instruments = 3L)) return(ctx$hold())` | `lookback = NULL` now uses the result's finite requested lookback; an `Inf` read refuses with `ledgr_invalid_history_request`. |

## LDG-3072: private context carriers

Probe (`dev/bench/v0_2_2_history_proof/ctx_reach_probe.R`, output in
`evidence/ctx_reach_probe.txt`): in a real run (eight instruments, 261
sessions, context captured at pulse 43), `ctx$.history` holds the whole
substrate (261 sessions, 218 of them after the pulse), and the closure behind the public `ctx$feature`
holds `ctx` itself (so `.history` again) and a `feature_vector` closure whose
environment holds the run's whole feature matrix (8 x 261, with 1,526 finite
values after the pulse). The
closures behind `ctx$bar`, `ctx$hold` and the other scalar accessors share
the pulse lookup environment, whose `feature_vector` reaches the context
again. So closure environments of public functions do reach future values;
they are refused by the same rule rather than documented as unreachable.

The rule as first written (`R/strategy-preflight.R`,
`ledgr_strategy_private_context_access()`) refused any literal dot-prefixed
extraction, any string naming a private field and closure, call or frame
environment introspection. The close review found it both too narrow and too
broad; Correction 1 below gives the rule as it now stands. The reason names
each access. The private carrier keeps its runtime role;
`ledgr_history_frame()` still reads it.

Evidence: LCL-0361/LTB-0371 (sixteen hostile bodies refused with the named
access; three valid strategies keep tier 1, 1 and 2; `ledgr_run()`,
`ledgr_sweep()` and `ledgr_walk_forward()` refuse with
`ledgr_strategy_tier3` and leave every store table's row count unchanged;
the same experiment with a public history read runs; a source scan of `R/`
finds every dot-prefixed context field in the preflight's list). The full
suite runs every existing test strategy through preflight and none changed
tier. Contract: Reproducibility And Preflight (new bullet) and Pulse Data And
Axis-Aligned Accessors (the "does not yet reject" sentence is now present
tense). Teaching: `?ledgr_strategy_preflight` and the reproducibility
article's Tier 3 table.

## LDG-3081: valuation horizon and history policy

Before and after, on the WS44 API demo:

```text
Point in time: membership rule 'DEMO_UNIVERSE'; max sessions 5 (default)

Point in time: membership rule 'DEMO_UNIVERSE'; valuation stale-mark horizon 5 sessions (default)
History policy: price carry 5 sessions (default); output carry off (default); segment limit 4 per fact, at least 16 (default)
```

`summary()` names `Stale-mark horizon` and adds a `History Policy` section;
`ledgr_experiment_plan()` prints `Valuation:` and `History:` lines and adds
`history.price_carry`, `history.output_carry` and `history.segment_limit`
rows to its `assumptions` table after the valuation rows; `print()` of an
experiment prints the same two lines after the price basis. A value is
marked `default` when it equals the constructor default (an explicit default
policy has the same identity as omission, so it is marked default) and
`declared` otherwise; the valuation horizon now carries `declared` too.
Dense results, experiments and plans show no history policy.

No execution-mode branch was added: the result disclosure rides the
valuation summary's availability-only basis (`history_policy` joins
`ledgr_valuation_summary()`), the plan's history rows join its existing
valuation-policy block, and the experiment print derives its lines from the
plan rows. The mode-branch census is unchanged (158 branch and 55 flow
sites).

Evidence: LCL-0396/LTB-0406. Documentation: `?ledgr_valuation_summary`,
`?ledgr_experiment_plan`, NEWS, the missing-data article's explanation and
the re-rendered `missing-data-and-sessions.md` and `survivorship-bias.md`
(their `Point in time`, `summary()` and plan outputs). Contract: Plan And
Result Disclosure.

## LDG-3071 API items (ticket stays open)

`ledgr_history_info()`, `ledgr_history_weights()` and the
`ledgr_history_sufficient()` default are in `R/history-frame.R`, exported,
documented, in the pkgdown reference and in the condition reference
(`ledgr_history_weights_mismatch`). Both new helpers and
`ledgr_history_matrix()` share one consistency check
(`ledgr_history_require_consistent()`); the matrix adapter's behaviour is
unchanged (LTB-0297 passes unchanged). Evidence: LCL-0397/LTB-0407,
including a Tier 1 strategy whose weights reach `ledgr_target_rebalance()`
(fills 20 AAA at 17 and 12 BBB at 27, derived from the rebalance flooring
rule). The executed portfolio example that uses both, the teaching items and
the decision reconciliation are phase B.

## LDG-3068: integrated correctness matrix

| Acceptance item | Evidence |
| --- | --- |
| evidence-owner check | LCL-0398/LTB-0408 parses Cut 16 `evidence_owners`, requires items 1-17, 18a and 18b once each with the expected primary, contributing and routed owners, and checks every mapped block is cited in its supplier's ticket evidence, registered in `claims.yml` and defined once. Items 14 (LDG-3070), 17 (LDG-3069) and 18b (routed to WS7, recorded by LDG-3071) are pending while their owners are open. Item 18a had no registered detector (LDG-3067 recorded the deletion in prose); LCL-0402/LTB-0412 adds one. |
| late-known lifetime hand oracle | LCL-0399/LTB-0409, including the cells decided by Cut 16 decision (29) below. |
| cross-surface agreement | LCL-0400/LTB-0410: run, sweep, explicit precompute, walk-forward test windows and pulse inspection, each through frame, matrix, scalar, vector and close reads, against one literal oracle at sessions 6-8. |
| named mutation families | C1-C7 in the mutation table: each fails its registered owner. |
| fixture lane and profiles | The fixture lane (`dev/bench/v0_2_2_real_data_scale/`, BASE `6f019c6b` against the candidate source copy, recorded with `--allow-dirty` because both arms are exports) reports 48 of 50 gated families identical and the identity family identical. The two differences, `momentum_valuation_summary` and `equal_weight_valuation_summary`, are the LDG-3081 `history_policy` rows added to `ledgr_valuation_summary()` (the recorder flattens them to three rows); every pre-existing field is identical. The fast and review profiles are run by the coordinator. |
| dividend units | LCL-0401/LTB-0411 and the Units, Price Basis And Universe contract text. No product defect: the adapter-authoring article already tells adapters to convert amounts to the bars' unit basis. |

### Cut 16 decision (29): feature history is a vintage view

LDG-3068 raised a `NEEDS_TYPE_2`: after a lifetime fact became known late, a
feature history read showed earlier cells with the values computed at their
own pulses (the accepted LTB-0313 rule) next to evidence resolved with the
cutoff's mask. The maintainer decided on 2026-10-20 (Cut 16 decision 29):
a feature history read returns each earlier cell as it was computed at its
own pulse, values and evidence alike; bar history reads remain restated with
the cutoff's knowledge; a fact that becomes known later changes feature
cells only from its knowledge pulse on.

Implementation (`R/history-frame.R`): `ledgr_history_feature_evidence()` now
takes its masks from `ledgr_history_vintage_planes()` instead of the
cutoff's. For an instrument with late-known lifetime or terminal facts, each
column takes the mask of the knowledge epoch its own pulse falls in, read
from the same memoised base and per-epoch overlay masks the bar reads use, so
nothing is recomputed per read; every other instrument's mask does not
depend on knowledge. `expected`, `is_missing`, `calculated`, `ready`,
`calculation_valid`, `missing_reason` and `barrier_reason` follow, and the
retained input-carry, output-carry, segment and reason planes were already
those of each cell's own preparation range. The bounded reach behind
`used_before_window` counts each cell's expected sessions under that cell's
own mask (`reach_seen`). The selection table and `na_action =
"drop_instruments"` read the same evidence. Bar reads are unchanged.

Fixture (LTB-0409): DDD closes 41, 43, -, 50, 55, 61, 68, 76; sessions 5-6
are a lifetime-inactive interval learned at session 7's open. A read at
cutoff 7 or 8 now returns, for DDD's SMA(2):

| Session | Value | expected | calculation_valid | missing_reason | bar close at the same read |
| --- | --- | --- | --- | --- | --- |
| 5 | 52.5 | TRUE | TRUE | | 55, inactive-interval print |
| 6 | 58 | TRUE | TRUE | | 61, inactive-interval print |
| 7 | 59 | TRUE | TRUE | | 68 |

52.5 and 58 are `(50 + 55) / 2` and `(55 + 61) / 2`, computed at sessions 5
and 6 before the interval was known; 59 is `(50 + 68) / 2`, computed at
session 7 with the interval known (the window spans it, decision 15).
LTB-0409 pins every one of the first six cells as identical to the session-6
read's cell, under the default policy, with input carry disabled and with
output carry alone. Mutation V1 (feature evidence resolved at the cutoff
again) fails it.

Seven-shape walk of the change: the new loop runs per read over requested
instruments with late-known facts and, within each, over the distinct
knowledge epochs that the window's columns fall in, indexing memoised masks;
it is the shape of the existing overlay loop in
`ledgr_history_cutoff_planes()` (WS42 close review F3) and builds no frame,
hashes nothing and scans no axis beyond the requested window. Instruments
without late facts take the base mask by index and one cumulative sum.

## Mutation table

Each mutation was applied to one file of a source copy made with
`git ls-files -z | tar --null -T - -cf - | tar -xf - -C <copy>` from the
Correction 2 commit `26ab8129`, the named blocks run in a fresh R
process, and the file restored byte for byte. The drivers and the result
are in `dev/bench/v0_2_2_history_proof/scripts/` and
`evidence/mutations.csv`. "error" means the block stopped. Two first
attempts are not in the table: C5b first named LTB-0298 as its required
detector, and that block passes because it compares the memoised read with
the whole-prefix primitive, which shares the mutated horizon (the carry
owner LTB-0292 fails, as recorded); C7 was first written as `FALSE && a ||
b`, which R parses as `(FALSE && a) || b` and so changed nothing. The whole
table was re-run on the decision (29) tree, adding V1, again on the
Correction 1 tree, adding Q1-Q6 and the reviewer's X5-X9, and again on the
Correction 2 tree (Correction 2 below lists the preflight rows it restated,
retired and added). The unmutated copy
passed every named block in the full suite run.

| ID | Mutation | File | Result |
| --- | --- | --- | --- |
| Q6 | sufficiency reads stale metadata | `R/history-frame.R` | LTB-0407 fails (3 failed) |
| X5 | named weights matched by the inverse permutation (review) | `R/history-frame.R` | LTB-0407 fails (1 failed) |
| X6 | excluded IDs ignore the requested flag (review) | `R/history-frame.R` | LTB-0407 fails (1 failed) |
| X7 | used_before_window counts the vintage row, not each cell's own mask (review) | `R/history-frame.R` | LTB-0413 fails (1 failed) |
| X8 | vintage epoch counts knowledge at the pulse instant as later (review) | `R/history-frame.R` | LTB-0413 fails (3 failed) |
| X9 | vintage terminal flag taken from the base mask (review) | `R/history-frame.R` | LTB-0413 fails (1 failed) |
| P1 | private-access branch removed from the tier decision | `R/strategy-preflight.R` | LTB-0371 fails (189 failed, error) |
| P4 | base environment functions not scanned | `R/strategy-preflight.R` | LTB-0371 fails (41 failed, error) |
| P6 | .history dropped from the private field list | `R/strategy-preflight.R` | LTB-0371 fails (4 failed) |
| D1 | horizon printed without its name | `R/valuation-summary.R` | LTB-0406 fails (4 failed) |
| D2 | History policy line dropped from print() | `R/valuation-summary.R` | LTB-0406 fails (2 failed) |
| D3 | History Policy section dropped from summary() | `R/valuation-summary.R` | LTB-0406 fails (3 failed) |
| D4 | plan print drops the Valuation and History lines | `R/availability-policy.R` | LTB-0406 fails (2 failed) |
| D5 | history fields always marked default | `R/history-policy.R` | LTB-0406 fails (5 failed) |
| D6 | experiment print drops the lines | `R/experiment.R` | LTB-0406 fails (1 failed) |
| D7 | history rows dropped from the plan assumptions | `R/availability-policy.R` | LTB-0406 fails (4 failed) |
| A1 | metadata accessor skips the consistency check | `R/history-frame.R` | LTB-0407 fails (1 failed) |
| A2 | unnamed weights assigned in reverse order | `R/history-frame.R` | LTB-0407 fails (6 failed) |
| A3 | length mismatch accepted | `R/history-frame.R` | LTB-0407 fails (0 failed, error) |
| A4 | excluded IDs dropped | `R/history-frame.R` | LTB-0407 fails (2 failed) |
| A5 | print footer dropped | `R/history-frame.R` | LTB-0407 fails (1 failed) |
| A6 | sufficiency defaults to the available lookback | `R/history-frame.R` | LTB-0407 fails (1 failed) |
| A7 | named weights matched by position | `R/history-frame.R` | LTB-0407 fails (2 failed) |
| O1 | an item dropped from evidence_owners | `inst/design/ledgr_v0_2_2_spec_packet/tickets.yml` | LTB-0408 fails (1 failed) |
| O2 | item 9 primary and contributing owners swapped | `inst/design/ledgr_v0_2_2_spec_packet/tickets.yml` | LTB-0408 fails (2 failed) |
| O3 | pending owner LDG-3069 closed without blocks | `inst/design/ledgr_v0_2_2_spec_packet/tickets.yml` | LTB-0408 fails (1 failed) |
| O4 | LTB-0305 citation removed from LDG-3064 evidence | `inst/design/ledgr_v0_2_2_spec_packet/tickets.yml` | LTB-0408 fails (1 failed) |
| O5 | mapped block LTB-0285 no longer defined | `tests/testthat/test-history-foundation.R` | LTB-0408 fails (1 failed) |
| L1 | late-known fact applied before its knowledge pulse (feature ranges not split) | `R/history-features.R` | LTB-0409 fails (14 failed) |
| L2 | history reads ignore later knowledge (first epoch only) | `R/history-frame.R` | LTB-0409 fails (8 failed) |
| L3 | bounded windows stop at a lifetime-inactive interval | `R/history-features.R` | LTB-0409 fails (8 failed) |
| L4 | output carry fills a warm-up cell | `R/history-features.R` | LTB-0409 fails (4 failed) |
| L5 | bar reads ignore a disabled input carry | `R/history-frame.R` | LTB-0409 fails (5 failed) |
| V1 | feature evidence resolved with the cutoff's mask (decision 29 reverted) | `R/history-frame.R` | LTB-0409 fails (13 failed) |
| S1 | every history read uses the previous session as cutoff | `R/history-frame.R` | LTB-0410 fails (0 failed, error) |
| S2 | matrix adapter reverses values | `R/history-frame.R` | LTB-0410 fails (15 failed) |
| S3 | inspection calculates features from its cutoff | `R/pulse-snapshot.R` | LTB-0410 fails (12 failed) |
| S4 | runner calculates features from its last pulse | `R/backtest-runner.R` | LTB-0410 fails (24 failed) |
| U1 | credited amount scaled by a split-like factor | `R/corporate-action-settlement.R` | LTB-0411 fails (4 failed) |
| U2 | bound quantity differs from the held quantity | `R/corporate-action-settlement.R` | LTB-0411 fails (6 failed) |
| U3 | cash posts one session later | `R/corporate-action-settlement.R` | LTB-0411 fails (3 failed) |
| H1 | deleted sweep feature-matrix helper reintroduced | `R/sweep.R` | LTB-0412 fails (2 failed) |
| C1 | continuous-carry: no window continuation | `R/walk-forward.R` | LTB-0303 fails (12 failed) |
| C2 | correction-chain: successor knowable before predecessor accepted | `R/availability-facts.R` | LTB-0285 fails (1 failed) |
| C3 | rolling-month: month-end clamp drifts to day 28 | `R/walk-forward-folds.R` | LTB-0305 fails (3 failed) |
| C4 | civil-date: a knowledge Date resolves to session close | `R/availability-facts.R` | LTB-0284 fails (6 failed) |
| C5a | carry: calculation horizon one session too long | `R/history-treatment.R` | LTB-0292 fails (8 failed) |
| C5b | carry: read-path horizon one session too long | `R/history-treatment.R` | LTB-0292 fails (3 failed); LTB-0297 passes (0 failed); LTB-0298 passes (0 failed) |
| C6 | indicator: bounded windows stop at lifetime-inactive intervals | `R/history-features.R` | LTB-0310 fails (1 failed) |
| C7 | rule-4 refusal: non-current history identity accepted | `R/history-policy.R` | LTB-0287 fails (3 failed); LTB-0290 passes (0 failed) |
| P2 | private-field extraction not scanned | `R/strategy-preflight.R` | LTB-0371 fails (11 failed, error) |
| P3 | carrier field names in strings not scanned | `R/strategy-preflight.R` | LTB-0371 fails (16 failed) |
| P5 | only the literal symbol ctx is checked | `R/strategy-preflight.R` | LTB-0371 fails (1 failed) |
| Q4 | any dot-prefixed extraction refused again | `R/strategy-preflight.R` | LTB-0371 fails (3 failed) |
| Q5 | every private field name refused in strings | `R/strategy-preflight.R` | LTB-0371 fails (1 failed) |
| W1 | carrier symbols (also inside quote()) not scanned | `R/strategy-preflight.R` | LTB-0371 fails (11 failed) |
| W2 | non-exported ledgr objects allowed as symbols and as ledgr::: references | `R/strategy-preflight.R` | LTB-0371 fails (7 failed) |
| W3 | body<-, formals<-, as.function() and unserialize() allowed | `R/strategy-preflight.R` | LTB-0371 fails (14 failed) |
| W4 | substitute() with an environment allowed | `R/strategy-preflight.R` | LTB-0371 fails (7 failed) |
| W5 | bquote() with where allowed | `R/strategy-preflight.R` | LTB-0371 fails (1 failed) |
| W6 | environment-reaching names handed to a functional allowed | `R/strategy-preflight.R` | LTB-0371 fails (29 failed, error) |
| W7 | environment-reaching members called allowed | `R/strategy-preflight.R` | LTB-0371 fails (7 failed) |
| W8 | member names checked against environment-reaching names again (R2 regression) | `R/strategy-preflight.R` | LTB-0371 fails (1 failed) |
| Y4 | @ extraction not scanned (re-review) | `R/strategy-preflight.R` | LTB-0371 fails (4 failed, error) |
| Y5 | rlang namespace getters dropped (re-review) | `R/strategy-preflight.R` | LTB-0371 fails (6 failed) |
| Y7 | functional string check for base names only (re-review) | `R/strategy-preflight.R` | LTB-0371 fails (4 failed, error) |
| Y10 | sufficiency consistency check for the wide layout only (re-review) | `R/history-frame.R` | LTB-0407 fails (1 failed) |

## Test changes and reasons

- LTB-0233, LTB-0234 and LTB-0246 (`test-pit-consistency.R`): the printed
  horizon text changes from `max sessions N` to `valuation stale-mark
  horizon N sessions (default|declared)` and the summary label from `Max
  sessions` to `Stale-mark horizon` (LDG-3081). Their subjects (default and
  declared horizon, universe kind, assumption labels) are unchanged.
- LTB-0180 (`test-selection-visibility.R`): the plan's `assumptions` table
  gains the three `history.*` rows after the valuation rows (LDG-3081).
- LTB-0269 fixture `tests/testthat/fixtures/schema-version-literal-census.csv`:
  the plan's `schema_version` literal moved from line 338 to 343 of
  `R/availability-policy.R` because the plan documentation grew; only the
  recorded line number changes (the full suite found it).
- `test-api-exports.R` (unregistered): the locked export list gains
  `ledgr_history_info` and `ledgr_history_weights`.
- LTB-0409 (new in this phase, not yet accepted): after Cut 16 decision (29)
  it pins the sessions 5-6 feature cells at cutoffs 7 and 8 (values 52.5 and
  58 with their at-pulse evidence) where it had asserted only that they were
  not valid, and the input-carry-disabled and output-carry cases pin their
  full value vectors; stated reason: the maintainer's decision.
- New: LTB-0371 (`test-strategy-private-context.R`), LTB-0406
  (`test-history-policy-disclosure.R`), LTB-0407
  (`test-history-api-bridge.R`), LTB-0408 to LTB-0412
  (`test-history-integrated-proof.R`), all review profile.
- Two new oracles were corrected while writing them, before any commit,
  because the hand derivation was wrong, not the product: LTB-0407's fill
  quantities (CCC is admissible and included at session 6, so each weight
  is 1/3, not 1/2) and LTB-0411's metadata types (JSON numbers decode as
  doubles).

## Routed, not changed here

- None from decision (29).
- Strategy preflight treats `x$name <- value` on a captured environment as a
  local assignment, so a strategy can hand its context to an outside
  environment at Tier 1 (the probe uses this to capture a context). This is
  a reproducibility gap, not a causal read (the copy holds only what the
  pulse already exposes, plus the carriers this ticket now refuses); proposed
  owner: the strategy-helper-bundle RFC or the next preflight ticket.
- `ledgr_signal_strategy()` wrappers are Tier 2 without analysing the inner
  signal function, which also receives the context; the private-access rule
  does not reach it. Proposed owner: the same.
- Phase B: LDG-3069 (resources), LDG-3070 (real data), LDG-3071 teaching,
  hello world and decision reconciliation.
- Phase-B teaching note (close review 44a N4): `excluded_ids` lists
  requested instruments the estimate left out. Under the default
  `instruments = "admissible"` a held instrument that is no longer admissible
  is not requested, so it is not listed; teaching on `keep` must get held
  IDs from the context (`ctx$vec$held`) or read with
  `instruments = "decision_axis"`.
- LDG-3069 (close review 44a N1, appended to its scope): the per-read cost of
  decision (29)'s vintage evidence, +14 percent at full lookback and +3
  percent at lookback 20 with 100 late-fact instruments in the review's
  probe; its size depends on the real-data late-fact count (LDG-3080,
  LDG-3070).

## Correction 1 (close review 44a, 2026-10-20)

`close_review_44a.md` (Type 1) returned CHANGES_REQUIRED: six findings over
fifteen phase-A acceptance items. Each is answered here.

- F1 (blocking), future-data routes. Two Tier 1 routes reached the carrier
  or the closure environments and read session-8 values at the first pulse:
  ledgr's internal namespace (`ledgr:::ledgr_history_context_view(ctx)`,
  `utils::getFromNamespace()`) and `environment` named as a string or
  reached as a member (`lapply(x, "environment")`, `match.fun()`,
  `baseenv()$environment`). The rule now also refuses:
  - a reference to a non-exported ledgr object (`ledgr:::name`), matching
    the contract's rule that only the exported namespace is
    Tier 1-compatible;
  - namespace and binding getters as environment-reaching functions:
    `asNamespace()`, `getNamespace()`, `.getNamespace()`,
    `loadNamespace()`, `getNamespaceInfo()`, `getFromNamespace()`,
    `getAnywhere()`, `get0()`, `mget()`, `dynGet()`, and `rlang::ns_env()`,
    `pkg_env()`, `ns_imports_env()`, qualified from base, utils, methods or
    rlang or not;
  - any environment-reaching function named in a string constant
    (`lapply`, `sapply`, `Map`, `match.fun`, `do.call`) or extracted as a
    member with `$`, `@`, `[[` or `[`.

  LTB-0371 adds the twelve reviewer probe bodies and now runs every refused
  body through `ledgr_run()`: each is refused with `ledgr_strategy_tier3`
  and no store row appears, so none reaches data at run time. The contract
  and `?ledgr_strategy_preflight` now list what static analysis still cannot
  see: names built at run time, positional extraction from or iteration over
  the context, a non-carrier private name held in a variable, environment
  access through packages other than base, utils, methods and rlang, and
  functions or objects supplied from outside the strategy body.
- F2 (blocking), tier changes. Extraction names are now matched against
  `ledgr_pulse_context_private_fields()` rather than any dot prefix, and
  string constants against the four fields that hold data beyond the pulse
  (`ledgr_pulse_context_future_carriers()`: `.history`, `.pulse_lookup`,
  `.feature_vector`, `.feature_table_current`). A strategy's own
  `list(.fitted = 1)$.fitted`, `data.frame(.pred = 1)$.pred`,
  `d[[".pred"]]`, `stats::lm(...)$.fitted` and the strings `".notes"` and
  `".positions"` are Tier 1 again, as at BASE; `ctx$.history` through an
  alias is still refused. On the reviewer's 61 probe bodies, the corrected
  rule refuses every body that reaches data beyond the pulse by a literal
  route and returns every other body to its BASE tier. A scan of every
  function taking `ctx` in tests, vignettes, roxygen examples and the README
  found one strategy whose tier changes against BASE: LTB-0055's test
  strategy called `ledgr:::ledgr_normalize_ts_utc()` inside its body (Tier 2
  at BASE through its captured fixture, Tier 3 now). The timestamp is now
  computed outside the strategy; the block's subject and oracle are
  unchanged (stated reason: a strategy may not reference non-exported ledgr
  objects).
- F3, stale sufficiency. `ledgr_history_sufficient()` runs
  `ledgr_history_require_consistent()` like the matrix adapter and refuses a
  filtered or column-dropped result with `ledgr_invalid_history_result`;
  LTB-0407 pins both (mutation Q6).
- F4, units. The contract now says `recipient_quantity_per_parent_unit`
  counts recipient shares in the recipient's own split-adjusted units, that
  the divide-by-the-split-factor rule applies to cash amounts (the parent's
  factor from the entitlement to the bars' adjustment reference), and that a
  recipient ratio in as-traded shares converts as that ratio times the
  recipient's factor divided by the parent's.
- F5, detectors. LCL-0403/LTB-0413 pins, against a hand oracle, a delisting
  learned exactly at a pulse instant (the session-8 cell is not expected,
  the session-7 cell keeps no terminal barrier), a relisting (warm-up at
  session 10, then 85 and 95), every cell equal to the cell read at its own
  pulse, and the bounded reach behind `used_before_window` (a three-session
  read whose 59 used session 4 reports `TRUE`). The reviewer's mutations X7,
  X8 and X9 fail it.
- F6, record. LDG-3068 is `review_pending`; item 5 waits for the
  coordinator's profile record. The fixture-lane disposition is recorded:
  48 of 50 families identical, and the two others differ only by the LDG-3081
  `history_policy` rows (an intended difference, not a pass).
- Notes. N2: LTB-0407 adds three cyclically named weights and an
  admissible-selector read whose unrequested CCC is not excluded (the
  reviewer's X5 and X6 fail it). N3: `?ledgr_history_weights` names
  `ledgr_invalid_strategy_type` for non-finite weights. N1 is appended to
  LDG-3069's scope and N4 to the phase-B notes (Routed). N5 to N9 need no
  change.

Test changes in Correction 1: LTB-0371 (new bodies, refusal through
`ledgr_run()`, the kept-tier bodies; `do.call("environment")` is now
reported as the string `"environment"`), LTB-0407 (stale sufficiency,
cyclic names, admissible selection), LTB-0408 (item 15 now also maps
LTB-0413), new LTB-0413, and LTB-0055 (strategy timestamp computed outside
the body, reason above). No accepted oracle changed. Tooling: the census
script's `call_name()` (`tools/check-codebase-contracts.R`) stopped on a
call whose head is itself a call result (`f(x)(y)`, now in LTB-0371's
bodies); it now names only `pkg::name` heads, and the census output is
otherwise unchanged (158 branch and 55 flow sites, findings 72).

## Correction 2 (focused re-review 1, 2026-10-21)

`close_review_44a_rereview_1.md` (Type 1) returned CHANGES_REQUIRED: three
findings over eleven re-reviewed items. The reviewer recommended a Type 2 on
the name-denylist approach; the maintainer decided on 2026-10-21 (Cut 16
decision 30): strategy preflight is a best-effort static check, not a
sandbox. It refuses accidental and common deliberate access to private
context carriers, non-exported ledgr internals and environment-reaching
functions, and the contract says plainly that R offers no private memory,
so a strategy that deliberately subverts evaluation is outside ledgr's
guarantee, as is one that reads a future-data file. ledgr guarantees that
its own public history, feature and fact APIs return only data known at the
decision time. LDG-3072's second acceptance item now reads "every such path
is refused by the same rule or listed in the contract as outside
preflight's static guarantee". Cutoff-bound context internals and a
separate-process strategy sandbox are a horizon entry (2026-10-21,
[execution]) with the trigger "ledgr needs to run untrusted strategies".

- R1 (blocking), the re-review's Tier 1 bypasses. Cheap literal rules only:
  - a future-bearing carrier (`.history`, `.pulse_lookup`,
    `.feature_vector`, `.feature_table_current`) or a non-exported ledgr
    object named as a symbol anywhere in the body, including inside
    `quote()`, `bquote()` and `substitute()`; this refuses
    `do.call(with, list(ctx, quote(.history)))`,
    `do.call(evalq, ...)`, `baseenv()$eval(quote(.history), ctx)` and a
    rebound body naming `ledgr_history_context_view`;
  - `body<-`, `formals<-`, `as.function()` and `unserialize()` (and rlang
    `fn_body<-`, `fn_fmls<-`) as environment-reaching functions, which
    refuses every body-rebinding route the re-review ran, including the
    S3-method and `unserialize()` copies;
  - `substitute()` or `bquote()` given an environment or list.

  LTB-0371 adds the re-review's bypass bodies and runs each through
  `ledgr_run()`: refused with `ledgr_strategy_tier3`, no store row. The
  contract (Reproducibility And Preflight, Pulse Data) and
  `?ledgr_strategy_preflight` replace the exhaustive limits list with the
  short decision (30) statement. Iteration over the context
  (`Filter()`/`Find()` over `as.list(ctx, all.names = TRUE)`) stays outside
  the static guarantee, as stated.
- R2 (medium), `environment` as data. Environment-reaching names are now
  refused only in call position: called, qualified, passed as a value,
  extracted and called (`baseenv()$environment(...)`), or named in a
  string or member handed to a functional (`lapply`, `sapply`, `vapply`,
  `mapply`, `Map`, `rapply`, `eapply`, `tapply`, `apply`, `outer`,
  `Reduce`, `Filter`, `Find`, `Position`, `match.fun`, `do.call`, `Recall`,
  `Vectorize`). `params$environment`, `scores$environment`,
  `d[["environment"]]` and an `"environment"` label are Tier 1 again (the
  re-review's `probe_names.R` and two kept-tier bodies in LTB-0371). Across
  all 632 `function(ctx, ...)` literals of BASE's tests, vignettes, roxygen
  examples and README (the re-review's `probe_scan.R`), the corrected
  preflight gives BASE's tier for every one.
- R3 (low), detectors. LTB-0371 adds `ctx@.notes`, `rlang::ns_env()` and
  `lapply(x, "fn_env")`; LTB-0407 adds a long-layout result filtered to one
  instrument. The re-review's Y4, Y5, Y7 and Y10 each fail their block.

Test changes in Correction 2: LTB-0371 (fourteen refused and two kept-tier
bodies; the reason fragments of the earlier bodies are unchanged) and
LTB-0407 (long-layout stale refusal). No accepted oracle changed. The
mutation table above was re-run on `26ab8129`: the preflight rows P2, P3,
P5, Q4 and Q5 are restated against the new rule's code, Q1-Q3 are retired
(their routes are now covered by W2, W6 and W7 together with the
non-exported-symbol rule), and W1-W8, Y4, Y5, Y7 and Y10 are added.

## Correction 3 (focused re-review 2, 2026-10-21)

`close_review_44a_rereview_2.md` returned CHANGES_REQUIRED (four findings
over eight items). The maintainer authorized this third round on
2026-10-21, verified by the coordinator without a further review; after it,
any newly found bypass is outside decision (30) unless the contract claims
to refuse it.

- S1, qualified and attached spellings. An assignment whose target is
  headed by `pkg::name` or `pkg:::name` is checked as `name<-`, so
  `base::body(f) <-`, `base::formals(f) <-` and `rlang::fn_body(f) <-` are
  refused. Free symbols are checked against the base and rlang lists
  together, so `env_get(fn_env(ctx$feature), ...)` with rlang attached is
  refused. The re-review's four bodies are in LTB-0371 and are refused by
  `ledgr_run()` with no store row.
- S2, functional arguments. A functional is inspected only in its function
  slot (`FUN`, `f` or `what`, matched with `match.call()` against the
  functional's formals), so `tapply(d$environment, ...)`,
  `sapply(s, "[[", "environment")`, `lapply(d[["environment"]], sqrt)` and
  `mapply(f, 1:2, params$environment)` keep their BASE tier (LTB-0371
  kept-tier body). `Recall` left the list: it has no function argument.
- S3, a strategy's own names. The non-exported-ledgr-name rule skips the
  member after `$` or `@` and names the body binds itself (assignment
  targets, `for` variables, formals of inner functions), so a local
  `config_hash`, `res$config_hash`, a local `compute_sharpe_ratio` helper and
  `snapshot_state` keep their BASE tier (LTB-0371 kept-tier body).
- S4, detectors. LTB-0371 adds `formals(f) <-` alone (Z4),
  `rlang::fn_body(f) <-` (Z5), `bquote(.(a), ctx)` (Z8) and a quoted
  `.feature_vector` (Z12).
- N1, splice. `bquote()` is refused only when `where` is supplied, by name
  or position (matched with `match.call()`); `bquote(..., splice = TRUE)`
  is Tier 1 again (LTB-0371 kept-tier body).
- Contract and help. The rule list in Reproducibility And Preflight and
  `?ledgr_strategy_preflight` now claims only what the code refuses, and the
  decision (30) limit names the re-review's remaining routes as examples: a
  function reached through an alias, parentheses or `getElement()`, another
  package's replacement function (`methods::functionBody<-`), `trace()`,
  runtime-built names and iteration over the context.
- Scan. Across the 632 `function(ctx, ...)` literals of BASE's tests,
  vignettes, roxygen examples and README (re-review 1's `probe_scan.R`),
  every literal keeps its BASE tier (506 Tier 1, 23 Tier 2, 65 Tier 3, 38
  errors in both arms). Re-review 2's `probe_c2.R` gives BASE's tier for
  every S2, S3 and splice body and Tier 3 for every S1 and S4 body; the
  routes listed under the limit stay Tier 1, as stated.

Test change in Correction 3: LTB-0371 adds seven refused and three
kept-tier bodies; earlier expectations are unchanged. No accepted oracle
changed. Mutations are verified by the coordinator; the committed
`make_specs.py` defines them (Z4, Z5, Z8, Z12; V2-V7 for the new rules; P4,
W2 and W5 restated for the new code).

## Verification record

Windows 11, R 4.6.1, every R process run sequentially.

On the Correction 3 commit `7d5b334b` (source copy, after the integration
merge `ba3d80db`):

- Full suite: 1,159 blocks, 19,234 expectations, no failure or error, one
  optional skip (quantmod); 679 s of block time. LTB-0258 passes on the
  merged CRAN DuckDB 1.5.6 golden.
- `tools/check-codebase-contracts.R --mode=check`: OK, 158 branch and 55 flow
  sites (unchanged), findings 72; `--self-test-mode-branches`: OK;
  `tools/check-fold-phase-contract.R .`: OK; `tickets.yml` and
  `tests/claims.yml` parse and the 327 claims resolve; `git diff --check
  6f019c6b` is clean.
- Mutations: not run here; the coordinator verifies them from the committed
  `make_specs.py`. The table above is the Correction 2 run.

On the Correction 2 commit `26ab8129` (source copy):

- Full suite (`pkgload::load_all('.')` then `testthat::test_local('.',
  reporter = 'summary', stop_on_failure = FALSE, load_package = 'none')`):
  1,159 blocks, 19,196 expectations, one failure, no error, one optional
  skip (`ledgr_snapshot_from_yahoo requires quantmod`); 689 s of block time.
  The failure is LTB-0258 (`test-schema-current.R`), whose golden schema
  fixtures record `duckdb_version` 1.5.6.9000: the host's user library now
  holds duckdb 1.5.6, installed at 2026-10-21 07:27 by something outside
  this work (no process of this workstream installs packages). The block
  passed on every earlier run of this workstream, its fixture is not
  changed here, and no product file it reads changed in Correction 2. Every
  other block passes.
- Mutations: 67 of 67 detected by their named blocks (table above).
- `tools/check-codebase-contracts.R --mode=check`: OK, 158 branch and 55 flow
  sites (unchanged), findings 72; `--self-test-mode-branches`: OK.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `tickets.yml` and `tests/claims.yml` parse; the 327 claims resolve against
  the control-plane preflight; `git diff --check 6f019c6b` is clean.
- The fixture lane was not re-run: Corrections 1 and 2 change strategy
  preflight (every lane strategy keeps its BASE tier), sufficiency refusals
  and records, none of which the lane's families record (inference). The
  decision (29) result stands: 48 of 50 families identical, the two others
  differing only by the LDG-3081 `history_policy` rows.

On the Correction 1 commit `3b8bd118`: full suite 1,159 blocks, 19,123
expectations, no failure; 58 of 58 mutations detected. On the decision (29)
commit `19b08d85`: full suite 1,158 blocks, 19,009 expectations, no
failure; 47 of 47 mutations detected; fixture lane 48 of 50 identical with
the disposition above. On the implementation commit `f61d6fca`: full suite
1,158 blocks, one failure (LTB-0269's moved line, see Test changes); 46 of
46 mutations detected.

Not run here, by instruction: the independent close review and the fast,
review and heavy profiles. `R/cpp11.R` and `src/cpp11.cpp` line-ending churn
from compilation is not committed.
