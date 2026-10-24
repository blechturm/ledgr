# Workstream 55 Type 1 close review

Verdict: **NEEDS_TYPE_2**

Review range: `727d11e9..478a37c0`.

## Findings

1. **High / design boundary: a normal base value transform can retain and pass
   the original history identity.** `R/history-frame.R:1056-1074` validates a
   matrix by class, dimensions and dimnames, while the identity-dropping
   methods at `R/history-frame.R:1197-1224` cover `[`/replacement, `Ops` and
   `Math`. Base `pmax()` is not one of those dispatches and copies the first
   argument's attributes. On a real direct history matrix,
   `y <- pmax(x, max(x) + 1)` changed every value while retaining
   `ledgr_history_matrix` and `ledgr_history`; both `ledgr_history_info(y)` and
   `ledgr_align_weights(..., y)` accepted it. This contradicts LDG-3099's
   accepted rule that identity-aware helpers refuse a transformed object.
   The accepted inputs do not decide whether to pay for a value seal/check or
   narrow the guarantee to enumerated S3-dispatched operations; that tradeoff
   also meets LDG-3100's no-cell-rescan readiness rule, so it needs a Type 2
   decision rather than a silent Type 1 redesign. If the existing guarantee
   stands, the smallest repair is an internal value-identity mechanism checked
   by matrix adapters and identity-aware helpers, while
   `ledgr_passed_warmup()` still reads recorded readiness without scanning
   cells, plus a `pmax()` regression.

2. **Medium / failure sensitivity: LCL-0479 and LCL-0480 do not detect three
   explicitly required regressions.** LTB-0488 checks `direct + 0`, one column
   subset and replacement at
   `tests/testthat/test-history-api-cleanup.R:71-76`, but a mutation that lets
   `Math.ledgr_history_matrix` retain identity passed, as did a mutation that
   retained identity only for row subsets. LTB-0489 checks a missing
   `lookback` only on `ledgr_history_matrix()` and checks only removal of
   `na_action` from the frame formals
   (`tests/testthat/test-history-api-cleanup.R:139-145`); restoring
   `lookback = Inf` on `ledgr_history_frame()` passed LTB-0488/0489, the older
   frame and bridge suites, and documentation contracts. Add an attribute-
   preserving `Math` case, separate row and column subset cases, and a missing-
   lookback refusal for both public output forms.

3. **Low / teaching accuracy: the causal-history article names a reason the
   current admission API no longer emits for an ordinary shortfall.** At
   `vignettes/causal-history.qmd:212-214`, ordinary missingness is described as
   `missing_required_input`; the new admission code emits
   `insufficient_observations`, matching `inst/design/contracts.md:1928-1933`.
   Replace that stale reason and clarify that `structural_exclusion` and
   `carry_expired` remain the more specific reasons where applicable, then
   rerender the article.

## Verified clean

- Direct context and wide/long adapter matrices agreed exactly, including
  `0 x N` and `N x 0`; indexing, `stats::cov()` and the minimum-variance
  `quadprog` witness accepted the ordinary double matrix.
- The shared request/read-plan path performs one read and creates no public
  frame on the direct path. Dense-shaped and availability-aware run, sweep,
  explicit-precompute, public walk-forward and pulse-inspection coverage
  passed.
- Finite-value admission, input/output carry counting, defaults for finite and
  infinite lookback, zero-observation retention, readiness-only
  `min_instruments`, explicit strategy hold and old vector/context-vector
  warmup behavior passed the focused and inherited oracles. Inspection of the
  treated planes confirmed warmup, ordinary missing, non-finite calculation,
  inactive/structural and expired-carry cells are non-finite, while admitted
  input/output carry cells are finite.
- `ledgr_history_sufficient` and `na_action` are absent from exports, current
  package code, help, vignettes, examples and active benchmark calls. Remaining
  matches are historical evidence, source-census rows, mutation specifications
  or the negative API test.
- The seven-shape walk found no new data-sized R loop, repeated growing-table
  subset, per-cell parse, per-row JSON, discarded recomputation, quadratic
  validator or environment-held scalar write in the changed helpers.
- Benchmark CSV arithmetic reproduces 252 by 500 in all six alternating arms,
  elapsed medians 0.0190 versus 0.0320 seconds/read (ratio 0.59375), heap
  medians 97.2 versus 97.1 MB and retained sizes 1,164,664 versus 10,554,672
  bytes. The runner excludes fixture/context preparation, keeps frame and
  matrix live only in the adapter arm, and makes no heap-saving claim.

## Probes, mutations and verification

- Passed: `test-history-api-cleanup.R`, `test-history-integrated-proof.R`,
  `test-documentation-contracts.R`, `test-test-control-plane.R`,
  `test-history-frame.R`, `test-history-api-bridge.R`,
  `test-minimum-variance-proof.R` and `test-api-exports.R` (focused run: 58.2
  seconds, no failures).
- Killed by LTB-0488/0489: frame-then-matrix, a second causal-plan read,
  readiness rescan, wrong output-carry finite count, retained identity after
  `Ops`/column subset, and optional matrix lookback.
- Survived: retained identity after `Math`, retained identity only after row
  subsetting, and optional frame lookback. The independent `pmax()` probe also
  demonstrated the live product failure in finding 1.
- YAML inputs parse, `git diff --check 727d11e9..478a37c0` is clean, and older
  economic/history oracles passed without weakening. No production code was
  changed by this review.

## Necessity judgment

The inputs otherwise justify the feature: the direct public matrix removes the
frame/evidence retention and measured adapter overhead while reusing the native
causal plan, and recorded requirements replace the duplicate sufficiency
surface without adding execution behavior. Finding 1 is the one unresolved
input: "immutable identity after ordinary-matrix use" needs an enforceable
boundary before Workstream 55 can close.
