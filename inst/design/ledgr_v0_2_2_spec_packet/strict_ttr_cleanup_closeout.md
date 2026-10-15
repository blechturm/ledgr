# Workstream 37 Closeout: Strict TTR Constant-Factor Cleanup

**Status:** Implementation complete; Type 1 review and maintainer acceptance pending.
**Date:** 2026-10-15
**Implementation commit:** `ee5fd7497e055debb4613036c8537cc3f11e70fd`
**Accepted comparison commit:** `1cbc51661df5d7691aa5668e94d3d551513d2f41`
**Ticket:** LDG-3051

## Outcome And Necessity

The availability strict-feature loop now computes
`ledgr_strict_complete_window_mask()` once per instrument-feature series. It
skips the per-window `series_fn` self-comparison only for the exact
constructor-shaped TTR SMA scalar and series wrappers: their body fingerprints
match current `ledgr_ind_ttr()` templates, they share one environment, that
environment's parent is the ledgr namespace, and it locally binds none of the
call symbols used by either template. Source labels have no authority.

The growth-shape record identified two value-neutral linear constant factors:
the strict loop rebuilt the same OHLC completeness decision per window and the
package-owned TTR SMA wrapper called `ledgr_ttr_call()` twice on each eligible
window to compare a scalar with itself. The existing public strict API was
sufficient for values and execution; it lacked only an internal way to
distinguish that exact package wrapper from user-owned dual-function
indicators. The smallest addition is one named certification predicate, one
internal parity flag and reuse of the existing mask. The predicate has one
production caller because its reviewable contract is the safety boundary, and
LTB-0276 calls it directly with hostile environments. It can be removed if a
future constructor supplies an unforgeable native route or if later
segment-level execution replaces the scalar path. No manifest, registry,
schema, cache or orchestration layer was added.

Custom strict indicators still run scalar/series parity. TTR EMA, RSI and MACD
remain uncertified. Gap, warmup, recursion, convergence and window semantics
are unchanged. Segment execution remains later work. No public API or
`contracts.md` text changed.

## Acceptance Results

1. **Exact values and refusals: PASS.** LTB-0276 retains the pre-cut scalar
   window oracle and compares byte-identical TTR SMA and custom outputs on
   complete and leading/internal/trailing-gap inputs through the runtime and
   strict precompute callers. Warmup and eligibility masks are exact. TTR EMA,
   RSI and MACD still have no strict contract. Existing LTB-0074 passed through
   the supported installed-package worker path.
2. **Certification boundary: PASS.** A TTR-labelled mismatched wrapper raises
   `ledgr_indicator_gap_parity`; a body-identical wrapper in distinct
   environments performs two calls per eligible window; and a shared
   namespace-child environment locally binding `ledgr_ttr_call` also performs
   two. Local bindings for `as.numeric` and `::` refuse certification. A genuine
   package wrapper performs one call per eligible window.
3. **One completeness mask: PASS.** The counter observes exactly one mask call
   on empty, short, complete, leading/internal/trailing, all-missing and every
   single-position-missing series. An independent copy of the pre-cut
   per-window decision agrees on every fixture.
4. **Failure sensitivity: PASS.** Restoring parity produces three failures and
   doubles the observed TTR helper calls from five to ten. Restoring inline
   completeness produces 21 failures. Adding one to the scalar result produces
   nine failures across TTR/custom, runtime/precompute and provenance. The
   machine-readable record is
   [`mutations.csv`](../../../dev/bench/v0_2_2_strict_ttr_cleanup/evidence/mutations.csv).
5. **Paired clocks: PASS.** Five alternating fresh-process pairs at each of 250
   and 1,000 bars passed on the initial attempt. Strict-preparation median
   candidate/baseline ratios are 0.5128 and 0.4928, improvements of 48.7 and
   50.7 percent. Public `ledgr_run()` median ratios are 0.9231 and 1.0048, both
   at or below 1.05. All ten strict hashes and all ten economic hashes are
   exact. The preregistered complete retry did not run.
6. **Provenance and consumers: PASS.** The dense engine digest remains
   `80d1ae6d2165196044db3f0d1944d69f21b76e264d2df16df49e23f448a7c681`.
   The availability digest changes from
   `6bd61d705a94f2cd955b5eab2a526f65e36419393de0baef4d95c64718658a76`
   to
   `9ffede2b67d9ea4d1651eae7f2862ec2a819867e1588ac8069f449e73d5821dd`.
   LTB-0276 pins the runtime projection caller in `ledgr_run_fold_impl()`, the
   strict payload caller in `ledgr_precompute_payload()`, and the sweep caller
   in `ledgr_sweep_impl()`. Walk-forward reuses the existing sweep and run
   machinery. The availability-only digest binds the new predicate and changed
   strict bodies; dense provenance is byte-identical.

## Paired Clock Record

The record compares the accepted and candidate commits above, not two modes in
one loaded namespace. Each row is a fresh R 4.6.1 process, processes run one at
a time, odd/even pairs reverse arm order, and each process constructs the same
seed-3051 availability fixture with one TTR SMA-20 feature. TTR is 0.24.4. The
strict clock includes kind resolution plus strict series preparation. The
end-to-end clock surrounds public `ledgr_run()` after snapshot construction.

| Bars | Pairs | Strict ratio | `ledgr_run()` ratio | Exact | Verdict |
| ---: | ---: | ---: | ---: | --- | --- |
| 250 | 5 | 0.5128 | 0.9231 | yes | PASS |
| 1,000 | 5 | 0.4928 | 1.0048 | yes | PASS |

The 1,000-bar third pair had a noisy end-to-end ratio of 1.110; its five-pair
median is 1.0048 and is the preregistered decision denominator. No retry was
triggered. Inputs, source commits, environment, every raw child row, pair
ratios and summaries are under
[`evidence/`](../../../dev/bench/v0_2_2_strict_ttr_cleanup/evidence/).

Reproduce from a source extraction of the accepted commit and this candidate:

```text
Rscript dev/bench/v0_2_2_strict_ttr_cleanup/run_record.R \
  --baseline <accepted-tree> --candidate <candidate-tree> \
  --baseline-commit 1cbc51661df5d7691aa5668e94d3d551513d2f41 \
  --candidate-commit ee5fd7497e055debb4613036c8537cc3f11e70fd \
  --out dev/bench/v0_2_2_strict_ttr_cleanup/evidence \
  --lengths 250,1000 --pairs 5
```

## Seven-Shape Walk

1. **One-row frame per element, bound at the end.** The retained strict loop
   still slices the existing bounded window required by scalar semantics; it
   adds no row-frame collection or final bind.
2. **Full-table subset inside a loop over ids.** Runtime and precompute still
   resolve kind once per definition and pass one instrument frame to the
   strict helper. The change adds no table subset by instrument or pulse.
3. **Per-element parsing or formatting where a vectorised call exists.** OHLC
   coercion and completeness now run once over each input column through the
   existing vector mask instead of once per window.
4. **Per-row JSON on repetitive strings.** The path performs no JSON parsing,
   formatting or hashing per row. Fixed-size body fingerprints occur once at
   definition dispatch.
5. **Work computed and discarded, or recomputed on every call.** This is the
   targeted shape: one completeness mask replaces repeated window scans, and
   certified package wrappers do not recompute the same TTR terminal value for
   parity. User-owned dual functions retain the validation because its result
   is not determined.
6. **Quadratic validators.** No pairwise or nested growing validator is added.
   Call-symbol and body checks are fixed by two bounded template functions.
7. **Scalar writes into an environment-held vector.** Output remains a local
   numeric vector written by index. The new predicate reads environments but
   does not mutate an environment-held growing vector.

The new helper meets the separate helper criterion: its named certification
contract is the safety boundary, and hostile direct tests exercise it.

## Test-Change Ledger And Verification

- `tests/testthat/test-strict-ttr-cleanup.R`: one new review-profile block,
  LTB-0276, covering the new load-bearing value, structure, provenance and
  operation-count claim.
- `tests/claims.yml`: one new claim, LCL-0274, registering LTB-0276.
- `tests/testthat/test-strict-feature-acceleration.R`: no block-count change;
  the availability digest pin and semantic-helper census change because the
  strict body and its certification predicate now enter provenance.
- No existing test moved profile or weakened an expectation. Registered block
  count changes by +1 in review and +0 in fast.

Focused verification on Windows x64 with R 4.6.1 and DuckDB 1.5.6.9000:

- LTB-0276: 1 block, 70 expectations, zero failures or skips;
- strict-feature acceleration: 3 blocks, 52 expectations, zero failures or
  skips;
- test control plane: zero failures or skips;
- availability features through an isolated installed package library, with
  that library inherited by its two-worker child: 93 expectations, zero
  failures or skips;
- selected-file blocking lint: clean;
- `tests/claims.yml` parse: clean;
- `git diff --check`: clean.

An earlier source-only availability invocation could not load `ledgr` in its
parallel worker. It is not treated as a product result. Installing this exact
tree into an isolated library and placing that library plus DuckDB 1.5.6.9000
on `R_LIBS_USER` exercised the supported worker path and passed.

No performance exception or design disposition is requested. The only open
maintainer action is the planned Type 1 review and acceptance of Workstream 37.
