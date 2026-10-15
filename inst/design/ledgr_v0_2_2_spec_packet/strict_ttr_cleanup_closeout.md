# Workstream 37 Closeout: Strict TTR Constant-Factor Cleanup

**Status:** Implementation and correction round 1 complete; maintainer acceptance pending.
**Date:** 2026-10-15
**Corrected implementation commit:** `f7706c7e51871d82f2ea804f62b8421c67243f83`
**Initial implementation commit:** `ee5fd7497e055debb4613036c8537cc3f11e70fd`
**Accepted comparison commit:** `1cbc51661df5d7691aa5668e94d3d551513d2f41`
**Ticket:** LDG-3051

The independent Type 1 close review returned `PASS_AFTER_PATCHES`. Its faithful
M2 artifact is [`close_review_37.md`](close_review_37.md). Correction round 1
closes F1 through F4 without expanding the product scope; `accepted` remains
null for the maintainer.

## Outcome And Necessity

For any availability strict-feature series long enough to contain a window,
the loop now computes `ledgr_strict_complete_window_mask()` once. A shorter
series preserves the pre-cut all-NA return before attempting OHLC coercion. It
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
2. **Certification boundary: PASS.** Independent hostile fixtures isolate the
   exact-body and namespace-parent guards. With a shared namespace-child
   environment, changing only the scalar body retains the parity error;
   removing its guard makes both the classification and behavioral error
   witnesses fail. With exact bodies in one shared environment whose parent is
   not the namespace, the retained path makes 20 TTR calls; removing that guard
   certifies the wrapper and reduces the count to 10. Distinct environments and
   local bindings for `ledgr_ttr_call`, `as.numeric` and `::` also refuse. A
   genuine package wrapper performs one call per eligible window.
3. **One completeness mask: PASS.** The counter observes zero mask calls for
   empty and short inputs and exactly one for every series that can contain a
   window: complete, leading/internal/trailing, all-missing and every
   single-position-missing. An invalid short OHLC list-column input returns the
   exact all-NA result without coercion. An independent copy of the pre-cut
   per-window decision agrees on every ordinary fixture.
4. **Failure sensitivity: PASS.** Restoring parity produces three failures and
   doubles the observed TTR helper calls from five to ten. Restoring inline
   completeness produces 19 failures. Adding one to the scalar result produces
   nine failures across TTR/custom, runtime/precompute and provenance. Removing
   either the body or namespace-parent certification guard produces three
   failures with the independent behavioral witness. Adding a respelled
   per-window `anyNA` scan while retaining the mask produces two failures via
   the parsed call-symbol detector and provenance. Moving the short return
   after mask construction triggers the exact invalid-list-column error. The
   machine-readable record is
   [`mutations.csv`](../../../dev/bench/v0_2_2_strict_ttr_cleanup/evidence/mutations.csv).
5. **Paired clocks: PASS.** Five alternating fresh-process pairs at each of 250
   and 1,000 bars passed on the initial attempt. Strict-preparation median
   candidate/baseline ratios are 0.5000 and 0.4783, improvements of 50.0 and
   52.2 percent. Public `ledgr_run()` median ratios are 0.9383 and 0.9694, both
   at or below 1.05. All ten strict hashes and all ten economic hashes are
   exact. The preregistered complete retry did not run.
6. **Provenance and consumers: PASS.** The dense engine digest remains
   `80d1ae6d2165196044db3f0d1944d69f21b76e264d2df16df49e23f448a7c681`.
   The availability digest changes from
   `6bd61d705a94f2cd955b5eab2a526f65e36419393de0baef4d95c64718658a76`
   through the initial implementation digest
   `9ffede2b67d9ea4d1651eae7f2862ec2a819867e1588ac8069f449e73d5821dd`
   to corrected digest
   `25d86252352ea2228c9b49cade9eb482e21adf41d01f1ec5ce4a8a7db5809281`.
   LTB-0276 pins the runtime projection caller in `ledgr_run_fold_impl()`, the
   strict payload caller in `ledgr_precompute_payload()`, and the sweep caller
   in `ledgr_sweep_impl()`. Walk-forward reuses the existing sweep and run
   machinery. The availability-only digest binds the new predicate and changed
   strict bodies; dense provenance is byte-identical.

## Paired Clock Record

The correction record compares the accepted and corrected commits above, not
two modes in one loaded namespace. Before measurement, the hardened harness
resolved each supplied commit to its worktree HEAD, required empty
`git status --porcelain=v1 --untracked-files=all`, and recorded the Git tree
hash: baseline `fe79fb38c09fee5cab21cf6aa34a8f1933973f25`, candidate
`1283f772e024fdfbd27e48c0bed85502558a2c80`. Each row is a fresh R 4.6.1
process, processes run one at a time, odd/even pairs reverse arm order, and each
process constructs the same seed-3051 availability fixture with one TTR SMA-20
feature. TTR is 0.24.4. The strict clock includes kind resolution plus strict
series preparation. The end-to-end clock surrounds public `ledgr_run()` after
snapshot construction.

| Bars | Pairs | Strict ratio | `ledgr_run()` ratio | Exact | Verdict |
| ---: | ---: | ---: | ---: | --- | --- |
| 250 | 5 | 0.5000 | 0.9383 | yes | PASS |
| 1,000 | 5 | 0.4783 | 0.9694 | yes | PASS |

Every individual end-to-end pair also remains below 1.05; the registered
decision denominator is still the five-pair median. No retry was triggered.
Inputs, source commits, tree hashes, environment, every raw child row, pair
ratios and summaries are under
[`evidence/`](../../../dev/bench/v0_2_2_strict_ttr_cleanup/evidence/).

The initial record used the same seed, script and fresh-process pairing, and
its exact outputs and gates were valid, but its `source_commit` column was a
caller-supplied label: it did not verify worktree cleanliness or record a tree
hash. F4 is preserved as that record-only limitation rather than rewritten.
The corrected record above was rerun with the hardened preflight; no claim is
made that the initial record performed checks it did not perform.

Reproduce from clean Git worktrees at the accepted commit and this candidate:

```text
Rscript dev/bench/v0_2_2_strict_ttr_cleanup/run_record.R \
  --baseline <accepted-tree> --candidate <candidate-tree> \
  --baseline-commit 1cbc51661df5d7691aa5668e94d3d551513d2f41 \
  --candidate-commit f7706c7e51871d82f2ea804f62b8421c67243f83 \
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

- LTB-0276: 1 block, 76 expectations, zero failures or skips;
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

No performance exception or design disposition is requested. The independent
Type 1 review is preserved with verdict `PASS_AFTER_PATCHES`, all four findings
are corrected, and the only open maintainer action is acceptance of Workstream
37.
