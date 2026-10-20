# Cut 16 Workstream 44 phase A closeout: history proof and API bridge

Role: record; Workstream 44 phase A implementation evidence (LDG-3072,
LDG-3081, the LDG-3071 API items and LDG-3068).
Authority: non-binding. `tickets.yml` owns status and `contracts.md` owns
behaviour.
Status: LDG-3072 and LDG-3081 are complete. LDG-3071 stays `open` (phase B
owns its teaching and reconciliation); its three API items are implemented.
LDG-3068 stays `open` on one `NEEDS_TYPE_2` question (below); every other
acceptance item is evidenced, the fast and review profiles excepted, which
the coordinator runs. Workstream 44 stays `open`.

BASE is `6f019c6b` (`integrate/cut15-v0.2.2`, accepted Workstreams 40-43, 46
and 47). Branch `ws44/history-proof`; the implementation is `f61d6fca` and
this record with the ticket evidence follows it.

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
- One open question for the maintainer: after a lifetime fact becomes known
  late, a later history read shows feature values computed before the fact
  was known next to evidence computed after it (NEEDS_TYPE_2 below).

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

The rule (`R/strategy-preflight.R`,
`ledgr_strategy_private_context_access()`) makes Tier 3 any of: a `$`, `@`,
`[[` or `[` extraction of a literal dot-prefixed name on any object (a
context is easily aliased); a string constant naming a private context
field (`ledgr_pulse_context_private_fields()`, which catches `getElement()`,
`.subset2()` and a name held in a variable); and closure, call or frame
environment introspection: `environment()`, `environment<-`,
`parent.env()`, `parent.frame()`, `sys.function()` and the other `sys.*()`
frame functions, `as.environment()`, `topenv()`, and the `rlang`
equivalents (`fn_env`, `get_env`, `env_parent`, `caller_env`,
`current_env`, ...), whether called, qualified, passed by name or named in
`do.call()`. The reason names each access. The private carrier keeps its
runtime role; `ledgr_history_frame()` still reads it.

Stated limits (contract and help): dynamically constructed names
(`paste0(".", "history")`), positional extraction from the context
(`ctx[[15]]`) and iteration over it (`lapply(ctx, ...)`) are outside static
analysis, as the contract already says of dynamic dispatch.

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
| late-known lifetime hand oracle | LCL-0399/LTB-0409, with the scope limited by the NEEDS_TYPE_2 below. |
| cross-surface agreement | LCL-0400/LTB-0410: run, sweep, explicit precompute, walk-forward test windows and pulse inspection, each through frame, matrix, scalar, vector and close reads, against one literal oracle at sessions 6-8. |
| named mutation families | C1-C7 in the mutation table: each fails its registered owner. |
| fixture lane and profiles | The fixture lane (`dev/bench/v0_2_2_real_data_scale/`, BASE `6f019c6b` against the candidate source copy, recorded with `--allow-dirty` because both arms are exports) reports 48 of 50 gated families identical and the identity family identical. The two differences, `momentum_valuation_summary` and `equal_weight_valuation_summary`, are the LDG-3081 `history_policy` rows added to `ledgr_valuation_summary()` (the recorder flattens them to three rows); every pre-existing field is identical. The fast and review profiles are run by the coordinator. |
| dividend units | LCL-0401/LTB-0411 and the Units, Price Basis And Universe contract text. No product defect: the adapter-authoring article already tells adapters to convert amounts to the bars' unit basis. |

### NEEDS_TYPE_2: features read after a late-known lifetime fact

Fixture (LTB-0409): DDD closes 41, 43, -, 50, 55, 61, 68, 76; sessions 5-6
are a lifetime-inactive interval learned at session 7's open.

A history read at cutoff 7 or 8 returns, for DDD's SMA(2):

| Session | Value | expected | calculation_valid | missing_reason |
| --- | --- | --- | --- | --- |
| 5 | 52.5 | FALSE | FALSE | not_expected |
| 6 | 58 | FALSE | FALSE | not_expected |
| 7 | 59 | TRUE | TRUE | |

Sessions 5 and 6 carry the values feature preparation computed at their own
pulses, before the fact was known (`(50 + 55) / 2` and `(55 + 61) / 2`,
using the prints now known to be inactive), while their evidence comes from
the cutoff's mask. This follows the accepted LTB-0313 rule ("earlier pulses
keep their earlier answer", WS43 re-review 1 R4), and `ledgr_history_frame()`
bar reads follow the cutoff's mask throughout. v12 Sections 4-6 read the
other way for the same cells: the mask is cutoff-resolved, a print inside a
knowable inactive interval "enters no indicator computation segment", and a
bounded window counts the cutoff-resolved expected sessions. Under that
reading sessions 5 and 6 would read missing at cutoffs 7 and 8.

The question for the maintainer: at a cutoff after a lifetime or terminal
fact is known, should a feature history read return

- A. each cell as computed at its own pulse, values and evidence alike
  (vintage; the evidence would then say expected and valid at sessions 5-6,
  disagreeing with the bar read of the same cutoff);
- B. each cell as the cutoff's knowledge computes it (revised; sessions 5-6
  missing as `not_expected`, and any later window that reached into the
  interval recomputed); or
- C. the current mix (vintage value, revised evidence)?

Scalar and vector reads are unaffected (they read only the cutoff column,
where all three agree), and so is every cell computed at or after the
knowledge pulse (session 7 reads 59 under all three). LTB-0409 therefore
pins every other value, mask and reason and asserts only that sessions 5-6
are not `calculation_valid` after knowledge (true under B and C); it pins no
value for them. LDG-3068 stays open until the maintainer decides; B would be
a product change owned by a follow-up, A or C a contract sentence.

## Mutation table

Each mutation was applied to one file of a source copy made with
`git ls-files -z | tar --null -T - -cf - | tar -xf - -C <copy>` from the
committed tree plus the ticket evidence, the named blocks run in a fresh R
process, and the file restored byte for byte. The drivers and the result
are in `dev/bench/v0_2_2_history_proof/scripts/` and
`evidence/mutations.csv`. "error" means the block stopped. Two first
attempts are not in the table: C5b first named LTB-0298 as its required
detector, and that block passes because it compares the memoised read with
the whole-prefix primitive, which shares the mutated horizon (the carry
owner LTB-0292 fails, as recorded); C7 was first written as `FALSE && a ||
b`, which R parses as `(FALSE && a) || b` and so changed nothing. The
unmutated copy passed every named block in the full suite run.

| ID | Mutation | File | Result |
| --- | --- | --- | --- |
| P1 | private-access branch removed from the tier decision | `R/strategy-preflight.R` | LTB-0371 fails (68 failed) |
| P2 | dot-prefixed extraction not scanned | `R/strategy-preflight.R` | LTB-0371 fails (16 failed) |
| P3 | private field names in strings not scanned | `R/strategy-preflight.R` | LTB-0371 fails (12 failed) |
| P4 | base environment functions not scanned | `R/strategy-preflight.R` | LTB-0371 fails (20 failed) |
| P5 | only the literal symbol ctx is checked | `R/strategy-preflight.R` | LTB-0371 fails (4 failed) |
| P6 | .history dropped from the private field list | `R/strategy-preflight.R` | LTB-0371 fails (5 failed) |
| D1 | horizon printed without its name | `R/valuation-summary.R` | LTB-0406 fails (4 failed) |
| D2 | History policy line dropped from print() | `R/valuation-summary.R` | LTB-0406 fails (2 failed) |
| D3 | History Policy section dropped from summary() | `R/valuation-summary.R` | LTB-0406 fails (3 failed) |
| D4 | plan print drops the Valuation and History lines | `R/availability-policy.R` | LTB-0406 fails (2 failed) |
| D5 | history fields always marked default | `R/history-policy.R` | LTB-0406 fails (5 failed) |
| D6 | experiment print drops the lines | `R/experiment.R` | LTB-0406 fails (1 failed) |
| D7 | history rows dropped from the plan assumptions | `R/availability-policy.R` | LTB-0406 fails (4 failed) |
| A1 | metadata accessor skips the consistency check | `R/history-frame.R` | LTB-0407 fails (1 failed) |
| A2 | unnamed weights assigned in reverse order | `R/history-frame.R` | LTB-0407 fails (5 failed) |
| A3 | length mismatch accepted | `R/history-frame.R` | LTB-0407 fails (0 failed, error) |
| A4 | excluded IDs dropped | `R/history-frame.R` | LTB-0407 fails (2 failed) |
| A5 | print footer dropped | `R/history-frame.R` | LTB-0407 fails (1 failed) |
| A6 | sufficiency defaults to the available lookback | `R/history-frame.R` | LTB-0407 fails (1 failed) |
| A7 | named weights matched by position | `R/history-frame.R` | LTB-0407 fails (1 failed) |
| O1 | an item dropped from evidence_owners | `inst/design/ledgr_v0_2_2_spec_packet/tickets.yml` | LTB-0408 fails (1 failed) |
| O2 | item 9 primary and contributing owners swapped | `inst/design/ledgr_v0_2_2_spec_packet/tickets.yml` | LTB-0408 fails (2 failed) |
| O3 | pending owner LDG-3069 closed without blocks | `inst/design/ledgr_v0_2_2_spec_packet/tickets.yml` | LTB-0408 fails (1 failed) |
| O4 | LTB-0305 citation removed from LDG-3064 evidence | `inst/design/ledgr_v0_2_2_spec_packet/tickets.yml` | LTB-0408 fails (1 failed) |
| O5 | mapped block LTB-0285 no longer defined | `tests/testthat/test-history-foundation.R` | LTB-0408 fails (1 failed) |
| L1 | late-known fact applied before its knowledge pulse (feature ranges not split) | `R/history-features.R` | LTB-0409 fails (6 failed) |
| L2 | history reads ignore later knowledge (first epoch only) | `R/history-frame.R` | LTB-0409 fails (0 failed, error) |
| L3 | bounded windows stop at a lifetime-inactive interval | `R/history-features.R` | LTB-0409 fails (0 failed, error) |
| L4 | output carry fills a warm-up cell | `R/history-features.R` | LTB-0409 fails (4 failed) |
| L5 | bar reads ignore a disabled input carry | `R/history-frame.R` | LTB-0409 fails (5 failed) |
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

- NEEDS_TYPE_2 above (maintainer).
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

## Verification record

On a source copy of the implementation commit `f61d6fca` plus the ticket
evidence (product code identical to the final tree), Windows 11, R 4.6.1,
run sequentially:

- Full suite (`pkgload::load_all('.')` then `testthat::test_local('.',
  reporter = 'summary', stop_on_failure = FALSE, load_package = 'none')`):
  1,158 blocks, 19,001 expectations, one failure, no error, one optional
  skip (`ledgr_snapshot_from_yahoo requires quantmod`); 679 s of block time.
  The failure was LTB-0269, whose literal census records the plan's
  `schema_version` line; the line moved (Test changes) and the block passes
  after the recorded line is updated. Every new block passes.
- After the final record edits (claims text, the LTB-0269 line, tickets and
  this record; no R change): the integrated-proof, schema-literal,
  control-plane, governance, documentation-contract, current-only,
  project-metadata and codebase-contract files pass (49 blocks, no failure), and `tests/claims.yml` resolves against the control-plane preflight (326 claims; the eight new blocks are review profile).
- Mutations: 46 of 46 detected by their named blocks (table above).
- Fixture lane: 48 of 50 families identical, the two differences explained
  above.
- `tools/check-codebase-contracts.R --mode=check`: OK, 158 branch and 55 flow
  sites (unchanged), findings 72; the regenerated census tables (line
  references, the new helpers and condition class) are committed;
  `--self-test-mode-branches`: OK.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `tickets.yml` and `tests/claims.yml` parse with `yaml::read_yaml()`;
  `git diff --check 6f019c6b` is clean.
- Not run here, by instruction: the independent close review and the fast,
  review and heavy profiles. `R/cpp11.R` and `src/cpp11.cpp` line-ending
  churn from compilation is not committed.
