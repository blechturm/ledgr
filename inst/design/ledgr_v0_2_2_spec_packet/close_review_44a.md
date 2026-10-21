# WS44 phase A / LDG-3072, LDG-3081, LDG-3071 API, LDG-3068 close review (Type 1), `6f019c6b..b0b5990e`

## Verdict: CHANGES_REQUIRED (two preflight defects against LDG-3072's acceptance, one API refusal gap, three record or detector items)

What holds:

- LDG-3081: `print()`, `summary()`, `ledgr_experiment_plan()` and
  `print()` of an experiment name the valuation stale-mark horizon and
  disclose the history policy with markers. Dense output carries no policy
  line. The mode-branch census is unchanged (158 branch, 55 flow sites).
- LDG-3071 API items: `ledgr_history_info()` and `ledgr_history_weights()`
  behave as documented on every edge case I built: empty selection, all
  excluded, wide and long layouts, reordered long rows, length, name and
  shape mismatches, non-finite output. Both refuse a result that
  `dplyr::filter()` made stale.
- Decision (29) is implemented as decided. On my own fixture (two late
  lifetime facts, one learned exactly at a pulse instant, and a late-known
  relisting):
  - every feature cell read at a later cutoff equals the cell read at its
    own pulse (0 of 156 differ; BASE: 42 differ);
  - run, sweep and pulse inspection agree on every full feature and bar
    history read;
  - no non-valid cell lacks a reason, and no not-expected cell holds a
    value;
  - bar reads are identical to BASE.
- LDG-3068: the hand oracles are literal and independent of ledgr code paths.
  The cross-surface oracle fails all surfaces together (S1). The cash rule
  in the units contract is correct.
- The full suite, census check, mode-branch self-test, fold-phase checker,
  YAML parse and `git diff --check` pass. Each re-run of the implementer's
  mutations fails its claimed block.

What does not hold:

- F1 (blocking). Preflight still lets a Tier 1 strategy reach the private
  carrier and the closure environments, and so read future values. Two
  routes work:
  - ledgr's internal namespace:
    `ledgr:::ledgr_history_context_view(ctx)` and
    `utils::getFromNamespace()`;
  - `environment` named as a string or reached as an object member:
    `lapply(x, "environment")`, `match.fun("environment")` and
    `baseenv()$environment`.

  Both run, and at the first pulse they return session-8 values. The
  contract's stated limits do not cover either route.
- F2 (blocking). The rule refuses any dot-prefixed extraction on any object
  and any string `".notes"` or `".positions"`. Valid strategies therefore
  move from Tier 1 to Tier 3. For example, `predict(fit, new)$.pred` and a
  strategy's own `list(.fitted = 1)$.fitted` were Tier 1 at BASE and are now
  refused. LDG-3072's third acceptance item requires valid strategies to keep
  their tier.
- F3 (non-blocking). `ledgr_history_sufficient()` answers from stale
  metadata after `dplyr::filter()`, although the condition reference this
  diff rewrote says it refuses.
- F4 (non-blocking). The units contract gives the conversion for cash
  amounts only. For `recipient_quantity_per_parent_unit` it names the
  denominator and leaves out the recipient's own units.
- F5 (non-blocking). Three parts of the decision (29) implementation have no
  registered detector, and each mutation changes results:
  - `reach_seen` (used by `used_before_window`);
  - the epoch boundary when knowledge arrives at the pulse instant;
  - the vintage terminal plane.
- F6 (non-blocking, record). LDG-3068 is `complete`, but its fifth
  acceptance item (fast and review profiles) is not evidenced.

Review ratio: 6 findings over 15 phase-A acceptance items = 0.400.

## Method

- Read AGENTS.md; Cut 16 decisions (1)-(29), evidence_owners and
  contract_receivers; LDG-3068, LDG-3071, LDG-3072 and LDG-3081 with their
  acceptance items; the approved brief;
  `history_proof_phase_a_closeout.md`; the touched `contracts.md` groups
  (Units, Price Basis And Universe; Plan And Result Disclosure; Strategy
  Preflight; Reproducibility And Preflight; Pulse Data And Axis-Aligned
  Accessors); `research_strategy_ux_brief.md` (history identity and bridge)
  and `ledgr_ux_decisions.md` (family-first naming); the style manual's seven
  shapes; the whole product, test, claims and record diff.
- I built three source copies with `git ls-files` (candidate, mutation copy)
  and `git archive 6f019c6b` (BASE), compiling each once, sequentially. Every
  R process ran sequentially.
- Probes are in the scratchpad (`ws44a_review/`):
  - `probe_preflight.R`: 61 strategy bodies, on BASE and on the candidate;
  - `probe_runtime.R` and `probe_runtime2.R`: bypass candidates actually run
    in `ledgr_run()` on the WS42 fixture;
  - `probe_late.R`: 12 sessions; DDD has an inactive interval at sessions
    3-4 learned at session 5's open, a delisting from session 7 learned
    exactly at session 8's close, and a relisting from session 10 learned at
    session 11's open. It records SMA(2) and return features and close
    history at every pulse through run, sweep and inspection;
  - `probe_ubw.R`: a `used_before_window` case;
  - `probe_api.R`: edge cases of the new API;
  - `probe_perf.R`: feature-read cost, BASE against the candidate.
- I re-ran 9 of the implementer's mutations (one per claimed detector, plus
  C2), added 11 of my own and one unmutated control, each restored byte for
  byte. The mutation copy was diffed against the candidate afterwards.
- Full suite once on the candidate copy. Census `--mode=check` and
  `--self-test-mode-branches`, `tools/check-fold-phase-contract.R`, YAML
  parse, `git diff --check`.

## Findings

### F1 (blocking, LDG-3072 acceptance 1 and 2): Tier 1 routes to the private carrier and to closure environments remain

Verified facts, candidate copy (`probe_preflight.R`, `probe_runtime.R`,
`probe_runtime2.R`):

| Strategy fragment | Preflight | Run on the WS42 fixture, first pulse 2021-01-04 |
| --- | --- | --- |
| `v <- ledgr:::ledgr_history_context_view(ctx); v$service$substrate$bars$close` | tier_1 | runs; reaches all 8 sessions, AAA's session-8 close 18 |
| `utils::getFromNamespace("ledgr_history_context_view", "ledgr")(ctx)` | tier_1 | same |
| `e1 <- lapply(list(ctx$feature), "environment")[[1]]; e2 <- lapply(list(e1$feature_vector), "environment")[[1]]; e2$feature_values` | tier_1 | runs; AAA's SMA for all 8 sessions (NA, 11.5, ..., 17.5) |
| `match.fun("environment")(ctx$feature)` | tier_1 | runs; the closure environment (9 objects) |
| `baseenv()$environment(ctx$feature)` | tier_1 | runs; the same |
| `sapply(..., "environment")`, `Map("environment", ...)`, `asNamespace("base")$environment`, `getNamespace("base")[["environment"]]` | tier_1 | not run (same mechanism) |

Causes:

- `ledgr_strategy_package_is_tier1()` (`R/strategy-preflight.R:529-533`)
  makes every `ledgr::` and `ledgr:::` call Tier 1. The contract makes only
  ledgr's exported namespace Tier 1-compatible (`contracts.md:1651`).
- `ledgr_strategy_private_context_access()` (`R/strategy-preflight.R:406-453`)
  checks environment functions only as symbols, as qualified calls and as
  `do.call()` targets. It does not check a string literal naming one, or one
  extracted from an object with `$` or `[[`.

Contract (`contracts.md:1648-1650`) and help state the residual limits as
"dynamically constructed names, positional extraction from the context and
iteration over it". The routes above are literal and are none of these, so
the second acceptance item ("every such path is refused by the same rule or
documented as unreachable") is not met. The first acceptance item is not
met for the carrier reached through `ledgr:::`.

Smallest fix:

- make a non-exported `ledgr:::` reference Tier 3 (or at least the history
  carrier accessors), and refuse `getFromNamespace`/`asNamespace`/
  `getNamespace` the same way;
- treat a string constant naming an environment function, and a `$`/`[[`
  extraction of such a name, as the rule treats private field names;
- add these bodies to LTB-0371 and update the stated limits.

### F2 (blocking, LDG-3072 acceptance 3): valid strategies change tier

Verified facts (`probe_preflight.R` on BASE and on the candidate):

| Body | BASE | Candidate |
| --- | --- | --- |
| `r <- list(.fitted = 1); r$.fitted` | tier_1 | tier_3 (`$.fitted`) |
| `d <- data.frame(.pred = 1); d$.pred` | tier_1 | tier_3 |
| `d[[".pred"]]` | tier_1 | tier_3 |
| `m <- stats::lm(...); m$.fitted` | tier_1 | tier_3 |
| `msg <- ".notes"` | tier_1 | tier_3 |
| `lbl <- c(".positions", "x")` | tier_1 | tier_3 |

Dot-prefixed columns are the normal output of `broom::augment()` (`.fitted`,
`.resid`) and tidymodels `predict()` (`.pred`). Such a strategy was Tier 2
and is now refused before any run.

The cause is `R/strategy-preflight.R:418-420`, which flags any literal
dot-prefixed name on any object. The comment says this is because "a context
is easily aliased". But restricting the check to the names in
`ledgr_pulse_context_private_fields()` keeps the aliasing coverage, and
LTB-0371's source scan keeps that list complete. The full suite and the
vignettes contain no such strategy, which is why "every existing strategy
keeps its tier" holds in-repo.

Smallest fix: match extraction names against
`ledgr_pulse_context_private_fields()`, keep the string-constant check, add
one valid dot-column body to LTB-0371's tier-kept set, and reword
`contracts.md:1639` and `?ledgr_strategy_preflight`.

### F3 (non-blocking, LDG-3071 API): sufficiency answers stale metadata

`ledgr_history_sufficient()` (`R/history-frame.R:1237-1238`) reads the
metadata through `ledgr_history_require_result()`, not
`ledgr_history_require_consistent()`. Verified (`probe_api.R`):

- `dplyr::filter(fast, ts_utc == max(ts_utc))` keeps the class and the
  attribute and leaves one session. `ledgr_history_sufficient()` (default
  lookback 2) returns `TRUE`, while `ledgr_history_info()`,
  `ledgr_history_weights()` and `ledgr_history_matrix()` refuse with
  `ledgr_invalid_history_result`.
- A long result filtered to AAA returns `TRUE` for
  `min_instruments = 2L`.

`R/condition-reference.R:75-77` (rewritten in this diff) says
`ledgr_invalid_history_result` refuses a sufficiency query on a value that
"no longer matches". The contract defines sufficiency on "returned sessions".
The explicit-lookback path was already like this at BASE. The new default
reads the same stale field.

Smallest fix: call `ledgr_history_require_consistent()` in
`ledgr_history_sufficient()`, and add a filtered-result refusal to LTB-0407.

### F4 (non-blocking, LDG-3068 acceptance 6): the units rule is incomplete for recipient quantities

`contracts.md:778-786` says `gross_cash_per_parent_unit` and
`recipient_quantity_per_parent_unit` are "per split-adjusted parent share",
and an as-traded amount "must be divided by the cumulative split factor".

- For cash this is correct and complete. The divisor is the parent's split
  factor after the entitlement, in the bars' adjustment reference. LTB-0411
  witnesses it (5 against 10).
- For `recipient_quantity_per_parent_unit` the numerator counts recipient
  shares. Under `split_adjusted` these must be in the recipient's own
  split-adjusted units: the as-traded ratio times the recipient's later
  split factor, divided by the parent's. The text does not say so, and
  "divided by the cumulative split factor" is wrong for that term.

Today the term feeds only `estimated_contractual_consideration`
(`R/corporate-action-results.R:318`, times the recipient's adjusted close),
because quantity effects refuse. The impact is a diagnostic.

Smallest fix: one sentence stating the recipient-side units and that the
divisor rule applies to cash terms.

### F5 (non-blocking, detector): three decision (29) components are unpinned

Mutations on the mutation copy (see Mutations): X7, X8 and X9 pass all 20
registered blocks in six history and indicator files. My probes show each
changes results:

- X7: `used_before_window` counts the vintage row instead of each cell's own
  mask. In `probe_ubw.R` (no prints at sessions 5-6, interval learned at 7,
  `price_carry = NULL`, `lookback = 3` at session 7), SMA 59 uses session 4.
  `used_before_window` is `TRUE` on the candidate and `FALSE` under X7.
  `reach_seen` is the new code behind the closeout's sentence on the bounded
  reach. V1 reverts it only together with the masks.
- X8: knowledge at the pulse instant counted as later (`left.open`). In
  `probe_late.R` the session-8 cell becomes `expected` with no
  `missing_reason`, which breaks decision (21). The drop reason also changes
  from `structural_exclusion` to `missing_required_input`.
- X9: the vintage terminal plane is taken from the base mask. Session 7's
  cell, computed before the delisting was known, reads `barrier_reason =
  "terminal"`.

LTB-0409's fixture has one inactive interval learned at a session open and no
`used_before_window` assertion. The implementation is right on my fixture;
only the detectors are missing.

Smallest fix: extend LTB-0409, or add a block, with:

- a late terminal fact learned at a pulse instant;
- a relisting;
- the `probe_ubw.R` window, with its literal `used_before_window`.

### F6 (non-blocking, record): LDG-3068 is complete while acceptance item 5 is unevidenced

Item 5 requires "the fixture lane and fast/review profiles pass on the
merged product tree". The evidence says "The fast and review profiles are
run by the coordinator". The brief says to set `complete` "only when
evidenced". The fixture lane also reports 2 of 50 families different (the
intended `history_policy` rows). That is explained, but it is a record
difference, not a pass.

Smallest fix: keep LDG-3068 `open`, or record the coordinator's profile
results and the fixture-lane disposition before acceptance.

### Notes (no change required)

- N1, perf disclosure (route to LDG-3069). Decision (29) adds per-read work
  for every late-fact instrument whose window spans an earlier epoch: a
  `findInterval`, an epoch loop and a cumsum per instrument and epoch. Before,
  instruments past their last epoch needed none. `probe_perf.R`
  (100 instruments, each with one late interval, 250 sessions, SMA(5), hold
  strategy, BASE and candidate alternating, two rounds of 3 runs):
  - `lookback = Inf`: medians 2.30/2.30 s on BASE against 2.63/2.64 s
    (+14%);
  - `lookback = 20`: 2.70/2.73 s against 2.83/2.80 s (+3%).

  This is the existing overlay-loop shape. It has a stated reason, and full
  lookback is already discouraged (decision 17). But the closeout's
  seven-shape walk has no number, and the real-data late-fact count (LDG-3070
  and LDG-3080) decides its size.
- N2, detector strength. X5 (named weights matched by the inverse
  permutation) and X6 (`excluded_ids` ignoring `requested`) survive LTB-0407.
  A two-instrument swap is its own inverse, and the fixture's selector makes
  every row requested. The code is right. A three-instrument cyclic order
  and an `"admissible"` selection would pin both.
- N3, documentation. Non-finite solver output refuses with
  `ledgr_invalid_strategy_type` from `ledgr_weights()`.
  `?ledgr_history_weights` says "finite" but names no class.
- N4, teaching (phase B). `excluded_ids` is "requested but not included".
  Under `instruments = "admissible"` a held inadmissible instrument is not
  requested, so it is not listed, although the help calls `excluded_ids` the
  list to consult for `keep`.
- N5. The `ledgr_valuation_summary()` return value gains a `history_policy`
  field. This is the documented and intended fixture-lane difference.
- N6. A value-equal declaration is marked `default`, including the ticket's
  `price_carry = 5L` example. This is consistent with constructor identity
  and stated in the contract.
- N7. LTB-0411's fixture has no split row, because no split acts on a
  position under the contract. The split is narrative and the witness pins
  the held-quantity rule. This is adequate for the acceptance item.
- N8. LTB-0410 reads SMA with `lookback = 1`, so it does not cross-check the
  decision (29) cells across surfaces. `probe_late.R` shows run, sweep and
  inspection agree on full feature history at all 12 cutoffs.
- N9. `with(ctx, .history)`, `evalq()` and `local(envir = ctx)` are already
  Tier 3 as unresolved symbols, and `eval(parse())` as `eval`. A function in
  `params` is refused by params canonicalisation.

## Acceptance items

| Item | Result |
| --- | --- |
| 3072-1 ctx$.history directly or through service, substrate or bars refused before side effects | Not met: refused through `ctx`, aliases, `[[`, `getElement` and the rest, but reachable at Tier 1 through `ledgr:::ledgr_history_context_view()` (F1). Side-effect-free refusal verified (LTB-0371 table counts). |
| 3072-2 probe of closure environments; every path refused or documented | Not met: string-named and member-extracted `environment` reach future values at Tier 1 and are not among the stated limits (F1). The probe itself is sound. |
| 3072-3 valid strategies, public reads and history frame keep tier and results; removing the rule fails a detector | Partly met: in-repo strategies keep tier (full suite), but valid strategies with dot-prefixed columns or strings move from Tier 1 to Tier 3 (F2). P2, X1-X3 fail LTB-0371. |
| 3072-4 contract and teaching state the rule | Met, apart from the limits text (F1, F2). |
| 3081-1 print, summary and plan name the horizon and show the policy with markers | Met: literal lines verified; experiment print too; dense shows none. |
| 3081-2 registered block fails on unnamed horizon or omitted policy | Met: R-D1 and X4 fail LTB-0406. |
| 3081-3 docs and examples updated | Met: no remaining "max sessions" text in R, man, vignettes, README or contracts. |
| 3071-8 (API part) unnamed solver output to ledgr_weights without colnames, refusing a length mismatch; accessor named in the print footer | Met (edge cases in `probe_api.R`); N2 and N3. |
| 3071-9 (API part) sufficiency defaults to the finite requested lookback and refuses Inf | Met for the default and Inf; stale-result gap (F3). |
| 3068-1 evidence-owner check | Met: text-derived; R-O2 and X10 fail LTB-0408. |
| 3068-2 late-known hand oracle, input carry off, output carry alone, immutability | Met for the fixture as decided by (29); components outside the fixture unpinned (F5). |
| 3068-3 cross-surface agreement with independent oracles | Met: literal oracle; R-S3 fails it; my probe extends it to full feature history (N8). |
| 3068-4 named family mutations fail their owners | Met: R-C2 re-run fails LTB-0285; the recorded table is consistent. |
| 3068-5 fixture lane and fast/review profiles | Not evidenced for the profiles (F6). |
| 3068-6 dividend witness and unit contract | Met for cash; recipient-unit text incomplete (F4). |

## Mutations (mutation copy, restored byte for byte)

`R-` re-runs one of the implementer's mutations per claimed detector on
`b0b5990e`; `X` are mine.

| ID | Mutation | Block | Result |
| --- | --- | --- | --- |
| M0 | none (comment) | LTB-0371, 0406-0412 | 74, 22, 58, 177, 68, 90, 10, 5 expectations; none failed |
| R-P2 | dot-prefixed extraction not scanned | LTB-0371 | fails (16) |
| R-D1 | horizon printed without its name | LTB-0406 | fails (4) |
| R-A2 | unnamed weights reversed | LTB-0407 | fails (5) |
| R-O2 | item 9 owners swapped | LTB-0408 | fails (2) |
| R-V1 | feature evidence at the cutoff's mask | LTB-0409 | fails (13) |
| R-S3 | inspection features from its cutoff | LTB-0410 | fails (12) |
| R-U1 | credited amount halved | LTB-0411 | fails (4) |
| R-H1 | deleted helper reintroduced | LTB-0412 | fails (2) |
| R-C2 | correction-chain successor known early | LTB-0285 | fails (1) |
| X1 | `do.call()` target not checked | LTB-0371 | fails (4) |
| X2 | `rlang::` environment functions not checked | LTB-0371 | fails (4) |
| X3 | single-bracket extraction not scanned | LTB-0371 | fails (1) |
| X4 | price and output carry values swapped in disclosure | LTB-0406 | fails (8) |
| X5 | named weights matched by the inverse permutation | LTB-0407 | survives (N2) |
| X6 | `excluded_ids` ignores `requested` | LTB-0407 | survives (N2) |
| X7 | `used_before_window` counts the vintage row | 20 blocks in six history files | all pass; result changes (F5) |
| X8 | vintage epoch counts knowledge at the pulse instant as later | same 20 | all pass; result changes (F5) |
| X9 | vintage terminal plane from the base mask | same 20 | all pass; result changes (F5) |
| X10 | item 6 contributing owner changed | LTB-0408 | fails (1) |

## Decision (29) and LDG-3068 details

- `ledgr_history_vintage_planes()` (`R/history-frame.R:248-277`): columns of
  a late-fact instrument take the memoised overlay mask of the epoch their
  pulse falls in (`findInterval(axis, epochs)`, the same `<=` rule as the
  cutoff planes and as preparation, verified at the pulse-instant boundary in
  `probe_late.R`). Final-epoch columns keep the base mask. `reach_seen` is
  each cell's own-mask count from the window start. No mask is rebuilt per
  read (overlays go through `ledgr_history_memo_value()`).
- Bar evidence still uses `ledgr_history_cutoff_planes()`. `probe_late.R`
  bar output is identical between BASE and the candidate.
- Selection and `drop_instruments` follow the vintage evidence. In
  `probe_late.R`, at cutoffs 5-6 DDD is now included over a window holding
  its at-pulse cells; BASE excluded it.
- The LTB-0409 oracle values (52.5, 58, 59, 72 and the strict and
  output-carry vectors) are hand-derived in the block comments and match my
  own derivation. The evidence-owner check (LTB-0408) parses `tickets.yml`,
  `claims.yml` and the test sources; its item-to-block map is hand-written,
  which is appropriate since no source records it.

## Verification record

Candidate source copy of `b0b5990e`, Windows 11, R 4.6.1, sequential:

- Full suite: 1,158 blocks, 19,009 expectations, 0 failed, 0 errors, one
  optional skip (quantmod), 735 s of block time.
- `tools/check-codebase-contracts.R --mode=check`: OK, 158 branch and 55 flow
  sites, findings 72; `--self-test-mode-branches`: OK.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `tickets.yml` and `tests/claims.yml` parse; `git diff --check 6f019c6b
  b0b5990e` is clean.
- New IDs are within the reserved ranges (LCL-0361/LTB-0371; LCL-0396..0402,
  LTB-0406..0412).
- Test changes: LTB-0233, LTB-0234 and LTB-0246 change only the horizon
  text, LTB-0180 adds the three history rows, LTB-0269's fixture moves one
  line number, and `test-api-exports.R` gains the two exports. Each has a
  stated reason and none weakens its subject.
