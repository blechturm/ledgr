# Workstream 37 Type 1 close review

**Verdict:** PASS_AFTER_PATCHES

The strict-TTR product change is correct and remains inside the accepted
scope. The exact values, current refusal boundary, provenance changes and
paired performance gates all hold. One registered-evidence gap and one
short-history edge regression require bounded correction; a structural
detector should also be strengthened.

## Findings

### F1. Two certification checks lack independent behavioral witnesses

The hand-built hostile fixture combines a mismatched body with a non-namespace
environment parent. Removing either classifier check still refuses because the
other defect remains; only the broad availability-digest pin fails. Add two
orthogonal fixtures:

- exact shared environment and namespace parent with a mismatched `fn` body;
- exact bodies and shared environment with a parent other than the ledgr
  namespace.

Each must classify as uncertified and exercise the retained parity path. A
mutation removing either classifier check must fail behaviorally rather than
only through the digest.

### F2. Completeness detector catches only literal restoration

A respelled per-window completeness scan can coexist with the one-mask call and
escape the current `vapply(window` source pin and mask counter; only the broad
digest changes. Inspect the parsed loop body for `is.finite`, `anyNA`,
`complete.cases` or equivalent per-window completeness work so alternate
spellings fail without relying on one exact source string.

### F3. Short-history input validation changed

The candidate computes the complete-window mask before returning when
`n < width`. An invalid short OHLC list column now errors while the base returns
an all-NA vector. Move the short-history return before mask construction, add an
edge witness, and repin the two availability engine digests. Dense provenance
must remain unchanged.

### F4. Benchmark harness trusts caller-supplied provenance

The harness records `source_commit` from its argument and does not verify the
loaded tree is clean or record an input hash. Both arms still used the same
seed and script, so the current comparison is valid. This is a record-only
limitation, not a blocker; future runs may verify commit and cleanliness.

## Acceptance assessment

1. Exact TTR SMA and custom outputs, runtime/precompute parity and current
   EMA/RSI/MACD refusals pass.
2. The product certification boundary is correct, but F1 makes its registered
   evidence incomplete.
3. One complete-window mask matches the prior decision on 17 fixtures and is
   called once per series.
4. The required literal mutations fail, with the detector limitation in F2.
5. All registered performance gates pass.
6. Dense provenance is unchanged; availability provenance changes once; all
   consumers are pinned.

## Tests and mutations

- LTB-0276 passed 70 expectations; strict-feature acceleration passed 52;
  fingerprint, control-plane, availability-feature and availability-parity
  suites passed without failures or skips.
- Restoring certified parity caused three failures. Restoring per-window
  completeness under alternate spellings changed only the digest. Removing
  body or namespace-parent checks changed only the digest; removing shadow or
  shared-environment checks produced behavioral failures.
- A public availability run reached the optimized strict scalar helper with
  `check_series_parity = FALSE` once.
- YAML parsed, `git diff --check` was clean and scope remained limited to the
  strict feature implementation, tests, evidence and ticket record.

## Performance reconciliation

Five alternating fresh-process pairs at each size reproduced these medians
against base `1cbc5166` and candidate `ee5fd749`:

| Bars | Strict ratio | End-to-end ratio |
| ---: | ---: | ---: |
| 250 | 0.5128 | 0.9231 |
| 1000 | 0.4928 | 1.0048 |

All rows kept identical strict and economic hashes; no retry ran. The direct
gate of 0.95 and public-path gate of 1.05 both pass. The seven-shape walk is
clean: the existing scalar loop loses work, the new mask is one bounded vector,
and classification is once per definition rather than per pulse.

No maintainer decision is required.
