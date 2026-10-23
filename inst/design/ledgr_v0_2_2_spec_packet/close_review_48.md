# WS48 / LDG-3082, LDG-3083, LDG-3090 long-only minimum-variance proof close review (Type 1), `c79793e6..86621d5c`

## Verdict: CHANGES_REQUIRED (no defect in the estimator proof; one decision (17) scope gap and five small detector, teaching and robustness corrections)

What holds:

- The strategy is a correct proof of the constrained problem.
  - `quadprog::solve.QP(Dmat = sigma, dvec = 0, Amat = cbind(1, I),
    bvec = c(1, 0, ..., 0), meq = 1)` minimises `w' sigma w / 2` subject to
    `sum(w) = 1` (the one equality) and `w >= 0`.
  - The pairwise covariance is shrunk toward its own diagonal by `shrink`.
    A missing entry or a minimum eigenvalue at most `1e-10` of the maximum
    holds as `covariance_not_positive_definite`.
  - An independent projected-gradient solver on the probability simplex
    used its own pairwise covariance on the demo's 2019-11-01 pulse. It
    matches quadprog to 1.6e-15, the KKT residuals are about 1e-19, and the
    strategy's targets equal `floor(w * 0.95 * equity / close)` exactly
    (263, 341, 222, 189, 166).
  - That pulse has an interior solution. LTB-0435's oracle covers the case
    where the bound binds: active-set enumeration, CCC at zero, and clipping
    differs.
- The read order follows LDG-3082:
  - a lookback-2 axis read with no instruments;
  - a close read over `"admissible"` (default `na_action = "keep"`);
  - the threshold on `carried_input_share`;
  - a `return_1` read of the candidates with `na_action = "keep"`;
  - the `min_obs` screen on finite cells;
  - a second `return_1` read of exactly the estimated instruments;
  - alignment against that final read only.

  `carried_input_share` is never NA for a requested instrument
  (`R/history-treatment.R:565-569`), so the candidate subset cannot inject
  an NA ID.
- The month-start rule is causal and literal.
  - The axis is the prepared venue axis, cut off at the pulse
    (`R/history-frame.R:733-735`).
  - An independent rule on the session facts agrees on sampled demo
    sessions, the data start included.
  - A snapshot whose bars end on 2019-11-01 gives an identical decision on
    2019-11-01, so no input reads past the pulse.
- `held_excluded = setdiff(held, estimated)` over
  `ctx$universe[ctx$vec$position != 0]` covers everything decision (3) names:
  - threshold exclusions;
  - `min_obs` exclusions;
  - holdings that are not admissible (halted, restricted, held nonmembers),
    which are on the decision axis that `ctx$universe` spans.

  `keep` and `weights` cannot overlap.
- Every hold case returns `structure(ctx$hold(), outcome = ...)`, and the
  solver error, non-finite and negative-weight paths are caught.
- Decision (16) restatement:
  - the LDG-3082 scope, the LDG-3083 hold acceptance and LDG-3088's outcome
    list match the decision text;
  - LTB-0436 pins the INCOMPLETE stop and the edited-context safety net;
  - the Cut 17 decisions line is untouched on the branch.
- LDG-3090:
  - `ledgr_valuation_summary_add_stop()` is one set-based query;
  - `valuation_state` and the selection flags are unchanged, because
    `ledgr_assumption_flags_for_run()` reads only the evidence function;
  - print() and summary() show the STOPPED line;
  - the contracts.md bullet sits under `contract-result-corporate-actions`
    and states what the code does;
  - `test-terminal-reporting.R` (57 expectations) and
    `test-selection-visibility.R` (103) pass.
- Rules:
  - `R/` changes only in `valuation-summary.R`, so no engine threshold and
    no mode branch (census check 158 branch and 55 flow sites);
  - the census tables regenerated at HEAD into a scratch directory are
    byte-identical to the committed CSVs, which justifies the census commit;
  - the fold-phase checker passes;
  - `render-vignettes-gfm.R --check` verifies `minimum-variance.qmd`;
  - tickets.yml, claims.yml and _pkgdown.yml parse;
  - `git diff --check` is clean, and the committed blobs are LF and UTF-8;
  - new IDs are LCL-0421..0428 and LTB-0431..0438, inside the reservation.
- All eight blocks pass individually. The item 18b block uses a real
  crossing in both directions: CCC's share goes 0, 0.3, 0 at a fixed 0.2
  threshold, and the targets match an independent oracle each time.
  Moving the threshold to 0.35 flips the March decision.

What does not hold:

- F1 (should-fix, decision (17) and LDG-3090 acceptance 1). A run that stops
  INCOMPLETE with `terminal_mark_unavailable` prints "Valuation: CURRENT -
  every held mark was a current close". Here a known-inactive holding's
  terminal choice needs a permissible mark and none exists.
- F2 (minor, detector, decision (1)). The threshold boundary is unpinned:
  `share < threshold` survives every block.
- F3 (minor, detector, restated LDG-3083 hold acceptance). LTB-0436 does not
  observe "before the strategy is called".
- F4 (minor, teaching). The article says "five sessions for seven
  instruments", but six are estimated.
- F5 (nit, teaching). The demo run prints `Valuation: STALE`, and the
  article never explains it.
- F6 (nit, robustness). The post-clip weight sum can exceed the rebalance's
  leverage tolerance, which would make an uncaught error instead of a hold.

Review ratio: 6 findings over 19 in-scope acceptance items = 0.316
(LDG-3082 7, LDG-3083 8, LDG-3090 4). Per completed ticket, as
`rfc_cycle.md` defines the denominator: 6 over 3 = 2.000.

## Method

- I read:
  - AGENTS.md and the brief;
  - the Cut 17 entry and decisions (1)-(18) in the integration copy;
  - Workstream 48, and LDG-3082, LDG-3083, LDG-3090 and LDG-3088 on the
    branch;
  - `cut_review_17.md` R5 and R12 and `cut_review_17_rereview_1.md`;
  - macro_plan.md WS7;
  - the whole range diff;
  - the article as a first-time learner, with its rendered output;
  - `R/history-frame.R` (`ledgr_history_frame`, selection table,
    `ledgr_align_weights`, `ledgr_history_sufficient`);
  - `R/history-treatment.R` admission;
  - `R/strategy-helpers.R` (`ledgr_target_rebalance`);
  - `R/fold-engine.R` (`stop_valuation` and the valuation stops);
  - `R/valuation-summary.R`;
  - `R/backtest-results.R` (print).
- Scripts (all in `ws48_review/`) ran one R process at a time:
  - `run_blocks.R`: each WS48 block on the unmodified worktree;
  - `indep_check.R`: the independent solver, target, causality and
    month-start checks;
  - `mutate_review.R`: reviewer mutations on copies in `ws48_review/mut/`;
  - `other_stops.R`: the headline of the other valuation stops, on the
    LTB-0164 fixtures;
  - `article_probe.R`: the lookback-5 instrument count and the STALE
    source;
  - `before_call.R`: a counting strategy on LTB-0436's INCOMPLETE fixture;
  - `print_regress.R`, `rules.R` and `render_check.R`.
- I also ran the census check with `--output` to `ws48_review/census/`, so
  the worktree was not written, and the fold-phase checker.
- I did not run the full suite, R CMD check or timing.

## Findings

### F1 (should-fix; decision (17), LDG-3090 acceptance 1): a terminal missing-mark stop still prints CURRENT

Verified facts:

- `R/fold-engine.R:413-451` stops the run INCOMPLETE with
  `terminal_mark_unavailable` when a held, known-inactive instrument's
  terminal choice needs a qualifying mark and none exists.
- The LTB-0164 fixture (`AAA` closes 100, NA, 103; bankruptcy on day 2;
  `ledgr_valuation_stale(0, exhausted = "refuse")`; research preset) prints,
  by execution (`other_stops.R`):
  `Valuation: CURRENT - every held mark was a current close` in both print()
  and summary(), with `valuation_stop_reason` NA.
- The query in `ledgr_valuation_summary_add_stop()` filters
  `reason_code = 'valuation_horizon_exhausted'` only. Decision (17) reads "A
  run that stops INCOMPLETE for a missing mark printing 'Valuation: CURRENT'
  is a defect". LDG-3090 acceptance 1 says "a missing-mark INCOMPLETE run".
  The ticket scope, written on this branch, narrows this to
  `valuation_horizon_exhausted`.
- A `terminal_settlement_unsupported` stop also prints CURRENT. That stop is
  not a missing mark, so I record it only as context.

Inference: the same false headline survives under the sibling reason code.
The underlying situation is identical: a held instrument with no permissible
mark at the stop pulse. The only difference is that the instrument is known
inactive.

Smallest fix (the maintainer chooses at acceptance):

- (a) Widen. In `ledgr_valuation_summary_add_stop()`:
  - select `reason_code` too;
  - filter `reason_code IN ('valuation_horizon_exhausted',
    'terminal_mark_unavailable')`;
  - set `valuation_stop_reason` from the first row's `reason_code`.

  The headline already prints the reason. Then:
  - add an LTB-0438 case on the LTB-0164 no-mark fixture (testthat loads
    the `helper-terminal-outcomes.R` helpers for every test file),
    expecting `Valuation: STOPPED - 1 holding without a permissible mark at
    2020-01-02T16:00:00Z (AAA); the run is INCOMPLETE
    (terminal_mark_unavailable)` and no CURRENT line;
  - name both reasons in the contracts.md bullet and the roxygen paragraph,
    and regenerate the Rd;
  - mutation-check that the reason filter fails the new case.
- (b) Narrow. Record in the LDG-3090 evidence that decision (17) covers only
  `valuation_horizon_exhausted`. Route the terminal stops' CURRENT headline
  to an owner, for example WS8's routed inputs.

### F2 (minor, detector; decision (1) "excludes instruments above a strategy threshold"): the threshold boundary is unpinned

Verified facts:

- Mutation R3 (`carried_input_share <= threshold` changed to
  `< threshold`) passes LTB-0431 to LTB-0436 (`mutate_review.R`).
- LTB-0432 tests shares 0 and 0.3 against thresholds 0.2 and 0.35 only.
  The article's parameter text says "the largest share ... may have ... and
  still be estimated", which is `<=`.

Smallest fix: in LTB-0432, add a 1 March decision with
`threshold = 0.3`, where CCC's share is exactly 3/10, which equals the
literal 0.3 in double precision. Expect `"solved"`, `CCC > 0`, and targets
within one share of the four-instrument oracle. Record the reason
(strengthening a detector, not a fixture change) in the LDG-3083 evidence,
and record R3 as the new mutation.

### F3 (minor, detector; restated LDG-3083 hold acceptance "stops INCOMPLETE ... before the strategy is called")

Verified facts:

- LTB-0436's last run asserts only `completion_status` and `stop_reason`.
  If the stop came after the decide stage at the same pulse, the block
  would still pass, because the strategy holds on the data start anyway.
- A counting strategy on the same fixture (`before_call.R`) records 0 calls,
  so the behaviour holds today.

Smallest fix: in that run, use a wrapper that counts calls in an
environment, as LTB-0162 does with `seen`. For example, `calls <-
new.env(parent = emptyenv()); calls$n <- 0L; counted <- function(ctx,
params) { calls$n <- calls$n + 1L; ctx$hold() }`, then assert
`calls$n == 0L`.

### F4 (minor, teaching): "five sessions for seven instruments"

Verified facts (`article_probe.R`):

- On 2019-11-01 with `lookback = 5`, DEMO_05's carried share is 0.6, so it
  is excluded.
- Six instruments are estimated, each with 5 valid returns.
- `minimum-variance.qmd:417-419` says "With five sessions for seven
  instruments the sample covariance is singular".

Smallest fix: change the text to "With five sessions for six instruments"
and re-render `minimum-variance.md`. LTB-0437 does not pin this sentence.

### F5 (nit, teaching): the STALE line in the demo run is unexplained

Verified facts:

- The rendered `bt` prints `Valuation: STALE - 1 holding valued at a
  permitted stale close (longest age 1 session)`.
- All 130 stale held instrument-sessions are DEMO_05, 2019-06-04 to
  2019-11-29: its thin stretch while it was held.
- The paragraph after the output explains only the corporate-action line.

Smallest fix: add one sentence after the run, for example: "The valuation
line reads STALE because `DEMO_05` was held through its thin stretch: on
every second session it was valued at its previous close, which the default
valuation policy permits for up to five sessions."

### F6 (nit, robustness; LDG-3083 "a solver failure returns ctx$hold() rather than an error")

Verified facts (reading `minimum-variance.qmd:185-189` and
`R/strategy-helpers.R:368`):

- The strategy accepts `abs(sum(solution) - 1) <= 1e-8` and weights
  `>= -1e-8`, then sets negatives to zero.
- `ledgr_target_rebalance()` aborts with the uncaught
  `ledgr_levered_weights` when `sum > 1 + sqrt(.Machine$double.eps)`
  (about 1 + 1.49e-8).
- A sum of 1 + 1e-8 plus one clipped -1e-8 weight would therefore error
  instead of holding. quadprog meets the equality to about 1e-15, so this
  is latent.

Smallest fix: after clipping, add `solution <- solution / sum(solution)`,
or tighten the sum tolerance to `1e-10`.

## Mutations

Reviewer-designed, on copies under `ws48_review/mut/`. Each strategy
mutation ran against LTB-0431 to LTB-0436; the R/ mutation ran against
LTB-0438 with the original restored afterwards (and passing again).

| ID | Change | Result |
| --- | --- | --- |
| baseline | unmutated copy | LTB-0431..0438 all pass |
| R1 | shrinkage direction swapped (`shrink * sigma + (1 - shrink) * diag`) | LTB-0435 fails (2); others pass, because shrink 0.5 is symmetric |
| R2 | `valid > min_obs` (off by one) | LTB-0433 fails (1) |
| R3 | `carried_input_share < threshold` | survives all (F2) |
| R4 | `setdiff(held, candidates)`: `min_obs` exclusions liquidated | LTB-0433 (2) and LTB-0436 (2) fail |
| R5 | decide on the first two sessions of each month (lookback 3) | LTB-0431 (4) and LTB-0434 (1) fail |
| R6 | positive-definiteness check `min(eigen) < 0`, no relative tolerance | LTB-0436 fails (1) |
| R7 | `held_excluded` restricted to admissible holdings (equivalence probe) | survives all; equivalent, because the rebalance preserves restricted holdings anyway |
| R8 | the stop also rewrites `valuation_state` to `"stopped"` (copy of `R/valuation-summary.R`) | LTB-0438 fails (1) |

R1, R2 and R4-R6 and R8 are not in the implementer's list (D1-D3, T1-T3,
O1-O2, K1-K2, S1-S2, F1-F5, A1-A8, V1-V5). R3 exposes F2. R7 supports
provisional default 4.

## Provisional defaults

1. Article under Going Deeper, after strategy-authoring-tools: sound.
   `_pkgdown.yml` has no strategy group. Going Deeper is the
   strategy-companion group, and both causal-history and
   strategy-authoring-tools hand off to the article.
2. `keep_excluded`: sound. It is a strategy parameter, not API, and it is
   the only way to run the required keep counterfactual through a public
   `ledgr_run()` without editing the function.
3. `shrink` 0.5, `min_obs` 60 and `equity_fraction` 0.95, uncalibrated:
   sound for this cut. Decision (11) asks for a fixed, stated shrinkage, and
   the ticket asks for stated defaults. 0.5 is a strong pull. WS50's G-013
   report (LDG-3088) is where real-data adequacy shows, so do not calibrate
   here.
4. "Excluded by the history" read as "not admissible" under
   `na_action = "keep"`: sound.
   - A keep read never drops a requested instrument
     (`R/history-frame.R:750-754`).
   - `ledgr_target_rebalance()` preserves and reserves restricted holdings
     and held nonmembers either way (`R/strategy-helpers.R:389-403`).
   - Mutation R7 is equivalent on every block.
5. STOPPED wording, at most three holdings: sound. Widen it, or route the
   terminal stop, per F1.
6. LTB-0438 in the review profile: sound. Optionally the maintainer may move
   its first case (one short run) to the fast lane, since the defect sits on
   every user's print path. This is not required.

## Seven-shape walk

- `R/valuation-summary.R`:
  - one parameterised query per `ledgr_valuation_summary()` call, on a
    result-reader boundary;
  - vectorised `unique()` and filtering;
  - no loop, per-row formatting or JSON;
  - run lists and sweeps do not call it (`ledgr_assumption_flags_for_run()`
    uses the evidence function), so no per-run query is added to selection
    surfaces.

  No shape instance.
- Strategy per pulse:
  - off-decision work is one lookback-2 read with no instruments, constant
    in run length;
  - decision work is three windowed reads bounded by `lookback`, one
    covariance, one eigen decomposition and one `solve.QP`;
  - there is no loop and no growing collection.

  Observation only: the empty read still builds the selection table over
  the whole decision axis (`R/history-frame.R:863-898`), so off-decision
  cost scales with the decision-axis width, not with run length. It is
  vectorised, so no shape applies. It is worth noting for the WS50 timing
  on the Sharadar universe.

## Verified by execution versus by reading

- By execution:
  - all eight blocks;
  - the independent solve, the KKT check, the target arithmetic, causality
    by truncation, and the month starts;
  - eight reviewer mutations;
  - both other valuation stops' headlines;
  - the lookback-5 count;
  - the STALE source;
  - zero strategy calls before the stop;
  - the existing print test files;
  - the census check (counts and byte equality of the tables);
  - the fold-phase checker;
  - the article freshness check;
  - YAML parses, `git diff --check`, encoding and IDs.
- By reading:
  - the `solve.QP` parameterisation;
  - `carried_input_share` never NA;
  - `keep` and leverage semantics in `ledgr_target_rebalance()`;
  - the fold's stop order;
  - the contract bullet's accuracy;
  - the decision (16) restatement against the decision text;
  - the capability-gap routes (G1 and G3 match inputs already listed in
    `rfc/README.md#portfolio-construction`, and G2 matches
    `#strategy-scheduler`);
  - F6.
- Not run: the full suite, R CMD check and timing. The implementer's
  evidence covers them, and the brief excludes them.
