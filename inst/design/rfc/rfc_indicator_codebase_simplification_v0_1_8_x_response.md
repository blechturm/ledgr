# Response: Indicator Codebase Simplification RFC

**Status:** Reviewer response; binding only after accepted into spec or
v0.1.8.1 ticket cut.
**Respondent:** Claude Code
**Date:** 2026-05-22
**Responds to:** `inst/design/rfc/rfc_indicator_codebase_simplification_v0_1_8_x.md`

---

## Summary Verdict

Accept the RFC as written. Land Phase 1 (determinism extraction) in v0.1.8.1
as a focused refactor ticket. Treat Phase 2 (file naming and the
`indicator_dev.R` split) and Phase 3 (documentation alignment) as follow-up
work in subsequent v0.1.8.x patches, not as part of the same commit.

The three structural calls the RFC gets right and that should not be revisited
during implementation:

- `R/determinism.R` is the correct name, not `R/purity-guards.R`. The
  extracted set covers stable payload normalization, function signatures, and
  deterministic hash inputs, not only purity assertions.
- Built-ins are first-class public API. `ledgr_ind_sma()`, `ledgr_ind_ema()`,
  `ledgr_ind_rsi()`, and `ledgr_ind_returns()` are exported, used in
  `README.md`, used in vignettes, and used in tests. Any remaining design
  language that frames them as illustrative is stale and should be retired
  alongside Phase 3.
- `R/indicator_dev.R` must be split before any rename. The file owns both the
  indicator development session and `ledgr_pulse_snapshot()` plus
  pulse-context inspection helpers. Renaming the file to `indicator-repl.R` or
  `indicator-dev.R` without first extracting `R/pulse-snapshot.R` would
  mislabel the contents.

The remainder of this response narrows the acceptance criteria and takes a
position on the four open questions.

---

## Disposition By Proposal

| Proposal | Disposition | Notes |
| --- | --- | --- |
| A. Rename for consistency | Accept as Phase 2 polish | Single commit after Phase 1 has had a full CI cycle. Do not bundle with the determinism extraction. |
| B. Extract determinism scaffold | Accept as Phase 1 | Move functions without renaming. File name: `R/determinism.R`. |
| C. Built-ins are public API | Accept | No file moves required; only documentation alignment in Phase 3. |
| D. Rename `indicator_dev.R` | Accept, with required pre-split | Extract `R/pulse-snapshot.R` first; then rename remainder to `R/indicator-dev.R`. Avoid `indicator-repl.R`. |
| E. Do not merge kernel | Accept | `R/indicator.R` remains the contract and registry file. |

---

## Additions To Acceptance Criteria

The RFC's Section 8 criteria are correct but the fingerprint-stability
guarantee in 8.3 is currently aspirational. The current test inventory does
not include a dedicated test file that pins representative hashes. Without
one, "identical before and after" is checked by reviewer inspection, not by
CI.

Add the following acceptance criteria:

```text
8.8 A new tests/testthat/test-fingerprint-stability.R exists with two pin
    tiers.

    Hard pins (regression-only; any drift fails the test):
    - ledgr_ind_sma(20)
    - ledgr_ind_ema(20)
    - ledgr_ind_rsi(14)
    - ledgr_ind_returns(5)
    - ledgr_adapter_r(<closure defined in the test file>, id = "...", ...)
      Use a local closure, not stats::median. R-version churn would change
      the deparse of base R functions and produce false-positive drift.
    - ledgr_function_fingerprint() over a sample strategy closure defined
      in the test file.
    - ledgr_feature_engine_version() output (the feature-cache namespace
      hash; see R/feature-cache.R lines 3-30).

    Version-conditional pins (skipped or keyed to upstream version):
    - ledgr_ind_ttr("RSI", input = "close", n = 14)
    - ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
      The TTR adapter fingerprint already includes packageVersion("TTR")
      in its identity. Skip these pins when packageVersion("TTR") differs
      from the recorded version, or replace the pinned hash. Otherwise the
      test is asserting TTR's stability, not ledgr's.

    The pinned values are taken on the pre-refactor commit. The file lands
    as the FIRST commit of Phase 1, before any function moves.

8.9 The fingerprint-stability test is run in CI as a hard gate. A diff in
    any pinned hash blocks merge.

8.10 A feature-factory parity test runs end-to-end:
     - declare an experiment with
       features = function(params) list(ledgr_ind_sma(params$n))
     - sweep across two values of params$n
     - assert that pre-refactor and post-refactor candidate identities are
       identical
     This covers RFC Section 3 constraint #4 (indicator-parameter tuning
     remains load-bearing). Without this gate, a regression in how feature
     factories construct indicators across the move would not surface until
     a user reported it.
```

The reason this matters: `ledgr_indicator_fingerprint()` does NOT flow into
`ledgr_feature_id()` — feature IDs are returned directly from `indicator$id`
at `R/indicator.R` line 116, set at construction time. Fingerprints do flow
into:

- the feature-cache key in `R/feature-cache.R` (session-only, in-memory,
  per `R/feature-cache.R:36` "never persisted to DuckDB");
- precomputed-feature payload identity inside sealed snapshots (persistent);
- registered-run compatibility checks against indicator fingerprints recorded
  with the run;
- strategy provenance via `R/strategy-fn.R`.

A silent hash drift would therefore cause: current-session feature-cache
misses (slower, not wrong); precomputed-feature payload mismatch against
sealed snapshots (a real correctness problem); old run/registry fingerprint
mismatch (provenance discontinuity); inability to reproduce prior runs from
their recorded fingerprints. The feature cache itself is not persisted, but
the precomputed payload and run identity are, so drift breaks reproducibility
for any sealed snapshot whose features were precomputed before the drift.

---

## Implementation Notes For Phase 1

### Captures Flag

The RFC's correctness claim — that moving functions preserves fingerprints —
holds because `ledgr_function_fingerprint()` reads `body(fn)` and
`formals(fn)`, which are properties of the function object and not of its
defining file. The claim also depends on `include_captures` remaining `FALSE`
at every affected call site:

- `R/indicator.R`:
  - `ledgr_indicator_fingerprint()` calls `ledgr_function_fingerprint(fn,
    include_captures = FALSE, ...)` for both `fn` and `series_fn`.
- `R/indicator_adapters.R`:
  - `ledgr_adapter_r()` calls `ledgr_function_fingerprint(pkg_fn,
    include_captures = FALSE, ...)`.
- `R/feature-cache.R`:
  - verify each call site preserves the current `include_captures` value.
- `R/strategy-fn.R`:
  - verify each call site preserves the current `include_captures` value.

The Phase 1 commit must not change any `include_captures` argument. If a
later RFC needs to widen capture-aware fingerprinting, that is a separate
contract change that requires its own fingerprint-stability decision.

### Error Class Preservation

The RFC requires preserving error classes. The classes currently raised by
functions moving to `R/determinism.R` include:

- `ledgr_invalid_args`
- `ledgr_purity_violation`
- `ledgr_config_non_deterministic`

These are raised via `rlang::abort(... class = "...")` and the class strings
are part of the test API. The move must not rename these.

### Indicator-Prefixed Helpers In `R/determinism.R`

`ledgr_assert_indicator_fn_pure()` and `ledgr_assert_indicator_safe()` will
live in `R/determinism.R` after the move while still carrying the
`indicator_` infix in their names. This is correct for Phase 1 because
renaming them would change internal call sites in `R/indicator.R`,
`R/indicator_adapters.R`, and the test suite, and it would also produce
diffs in `man/*.Rd` that complicate review.

Phase 1 should accept the name mismatch as known debt. A header comment in
`R/determinism.R` should record that these two helpers retain the
`indicator_` prefix for backwards compatibility and may be renamed in a
later determinism-API ticket.

### Roxygen And `man/*.Rd`

Acceptance criterion 8.6 in the RFC says "Roxygen output is unchanged
except for source-file references if any are generated." Tighten this:

```text
Run devtools::document() before and after the move. Confirm the only diff
in man/*.Rd files is the unchanged @source / file-of-record fields if any.
No prose, signature, or example diffs.
```

If `devtools::document()` produces any unexpected `man/*.Rd` diffs, treat
it as a blocking issue and investigate before merging.

---

## Positions On The Open Questions

### Q1. Ticketing And Cycle Placement

Eligible for v0.1.8.1 only if explicitly added to the spec packet at
`inst/design/ledgr_v0_1_8_1_spec_packet/v0_1_8_1_spec.md`. Cycle placement
is a governance decision, not a fit assessment.

The current active v0.1.8.1 scope per `inst/design/README.md` is auditr UX
stabilisation and multi-output indicator bundle authoring. A
determinism-extraction ticket would be a scope amendment, not an automatic
addition.

Arguments for amending the spec packet to include Phase 1:

- The change is pure refactor with a hard fingerprint-stability gate.
- The architectural clarification (determinism becomes a visible package-level
  primitive) is internal debt that fits a stabilisation cycle.
- It is independent of the multi-output indicator bundle work and will not
  delay it.

Arguments for parking until v0.1.8.x:

- It touches the hash spine. Even with the gates above, that is non-trivial
  surface area and amending an active spec carries its own risk.
- The current packet is already mid-cycle; adding a refactor changes the
  scope of work that has already been planned.

Either path is defensible. Maintainer decision required.

Phase 2 (file naming and `R/pulse-snapshot.R` extraction) and Phase 3
(documentation alignment) are deferred to a later v0.1.8.x ticket regardless.
Phase 3 should be coordinated with the v0.1.8.1 feature lifecycle
documentation track flagged in the RFC's Section 5.

### Q2. Indicator-Prefixed Assertion Helpers

Defer renaming. The two `ledgr_assert_indicator_*()` helpers remain
indicator-named after the Phase 1 move. Renaming them is not worth the
internal call-site churn or the additional fingerprint risk during the same
ticket.

A later determinism-API ticket may rename them to package-level names
(`ledgr_assert_fn_pure`, `ledgr_assert_fn_safe`) alongside any other
internal cleanup. That ticket is not v0.1.8.x scope.

### Q3. Feature-Shape Normalization

Defer broader input support. Phase 3 documentation alignment should clarify
that:

- `ledgr_feature_map()` is the preferred authoring shape when the user plans
  to inspect feature values via `ledgr_pulse_features()`;
- `ledgr_experiment(features = ...)` accepts the broadest set of shapes
  because experiments must support sweep-time feature factories;
- `ledgr_pulse_snapshot(features = ...)` accepts a list or feature map by
  design.

Widening `ledgr_pulse_features()` to accept plain indicator lists is a
separate UX ticket that changes accepted inputs and error messages. Do not
fold it into the indicator simplification refactor.

### Q4. File Moves Bundling

Group Phase 2 file moves into a single polish commit, but only after Phase 1
has had at least one CI cycle confirming fingerprint stability. Bundling
Phase 1 and Phase 2 into the same commit would conflate the determinism
extraction (which has a hard correctness gate) with naming polish (which
has no behavior gate), producing a review with two distinct cognitive loads.

---

## Editorial Notes

### Section 5 Cross-Reference

Section 5 attributes the feature-shape normalization finding to "v0.1.8.1
auditr findings." The current spec packet
(`inst/design/ledgr_v0_1_8_1_spec_packet/`) describes this work as the
feature lifecycle documentation track. The RFC and the spec packet should
use the same name to make the cross-reference traceable. Recommend
adjusting either the RFC or the spec packet to match.

### Section 8 Tightening

Acceptance criterion 8.6 should be tightened as noted under "Roxygen And
`man/*.Rd`" above.

---

## Final Recommendation

```text
Cut a ticket (cycle TBD per Q1): LDG-IND-SIMPLIFY-PHASE-1.

Pre-conditions:
  - If v0.1.8.1 placement: amend the spec packet at
    inst/design/ledgr_v0_1_8_1_spec_packet/v0_1_8_1_spec.md to include
    this ticket explicitly. Otherwise park for v0.1.8.x.

Scope:
  - Add tests/testthat/test-fingerprint-stability.R with two-tier pins
    (hard pins + version-conditional pins; see 8.8 above).
  - Move ledgr_deparse_one, ledgr_static_function_signature,
    ledgr_stable_payload, ledgr_function_fingerprint,
    ledgr_are_params_deterministic, ledgr_assert_indicator_fn_pure,
    ledgr_assert_indicator_safe from R/indicator.R to R/determinism.R
    without rename.
  - Keep ledgr_indicator_fingerprint() in R/indicator.R.

Non-goals:
  - File renames beyond the new R/determinism.R file.
  - Public API changes.
  - Hash changes.
  - Documentation rewrite.
  - R/pulse-snapshot.R extraction.

Gates:
  - test-fingerprint-stability.R passes (hard pins exact; version-conditional
    pins either pass or are explicitly skipped for the recorded TTR version).
  - Feature-factory parity test passes: indicator-parameter sweep using
    features = function(params) list(ledgr_ind_sma(params$n)) produces
    identical candidate identities pre- and post-refactor (covers RFC
    Section 3 constraint #4).
  - Full indicator and feature-cache test suites pass.
  - devtools::document() produces no unexpected man/*.Rd diff.
  - API export lock tests pass.
```

That is the minimum useful Phase 1. It delivers the RFC's main architectural
benefit — `R/indicator.R` becoming the indicator contract and registry alone,
while determinism becomes a visible package-level primitive — without taking
any of the perception-level changes that have no behavior gate. Phase 2 and
Phase 3 follow once Phase 1 has shipped and CI has confirmed the
fingerprint-stability contract holds.
