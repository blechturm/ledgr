# LDG-2670 Return-Panel Entry Point: Design

Status: Approved by maintainer 2026-06-28. Binding design for LDG-2670; implement
against this. Decided in a four-step design review with Claude + Codex.

## Locked decisions

1. Explicit classed panel object, built on the existing `ledgr_sweep_returns_panel`
   contract (not a new shape). Diagnostics accept panel-or-sweep, normalize
   immediately, reject raw matrices.
2. Source-neutral `panel_hash` over normalized evidence; sweep provenance additive /
   nullable; the hash is evidence-only, never execution identity.
3. Wide-primary plus tidy-long input, clean period returns, optional ordering labels,
   fail-loud candidate ids.
4. Drop the `sweep_` prefix from the diagnostics; record a dated naming amendment.

## Public surface

```r
# Constructor -- the on-ramp for raw returns
ledgr_return_panel(returns, ts = NULL, value = "returns")
#   returns : wide matrix/data.frame (cols = candidates, rows = periods),
#             OR tidy long tibble (candidate_id, period_return, optional ts_utc)
#   ts      : optional Date/POSIXct row labels (wide input); NULL -> "period_000001"...
#   -> a `ledgr_return_panel` (existing panel shape + a source-neutral panel_hash)

# Sweep accessor -- same return type, sweep-specific name retained
ledgr_sweep_returns_panel(sweep, ...)   # returns a `ledgr_return_panel`

# Diagnostics -- renamed; accept panel-or-sweep
ledgr_pbo(x, S, ...)
ledgr_dsr(x, effective_trials = NULL, ...)
ledgr_min_track_record(x, reference_sharpe = 0, ...)
ledgr_effective_trials(x, ...)          # was ledgr_sweep_cluster()

# Internal
ledgr_return_panel_resolve(x, candidates = NULL)   # panel|sweep -> panel
```

## Panel object and hash

- Generalizes the existing panel: `long`, `matrix`, `ts_utc` / ordering labels,
  `candidate_ids`, `value`, first-row handling, complete flag -- plus `panel_hash`
  and a `source` tag.
- `panel_hash = digest::digest(canonical_json(payload), algo = "sha256")` over
  **normalized evidence only**: schema tag `ledgr_return_panel_v1`, `value`, ordered
  `candidate_ids`, ordered ts / ordering labels (post first-row), and the return
  matrix in that exact row/column order. Excludes source, `sweep_id`, snapshot /
  cost / risk / metric hashes, completed / excluded ids, and `first_row_dropped`. A
  sweep-built and a user-built panel with identical final evidence + labels hash
  identically.
- Reuses the existing canonical-hash path, consistent with config / cost / risk /
  metric-context / feature / walk-forward hashes.
- Documented as evidence provenance only; must not participate in run, sweep, config,
  walk-forward session, candidate, or promotion identity.

## Input contract

- Returns, not equity. Clean `T` returns for `T` periods, no leading `NA`; the
  constructor owns the structural-first-row convention. Sweep panels drop their
  structural first row before hashing.
- Timestamps optional. Omitted -> deterministic labels `period_000001...` (not
  pretend-`ts_utc`); supplied -> `Date` / `POSIXct` canonicalized to UTC labels.
  Labels are in the hash, so undated and dated panels with the same returns hash
  differently (intentional).
- Shape detection is strict: a data frame with `candidate_id` + `period_return`
  (+ optional ts/period-label column) -> long; a matrix or data frame without those
  columns -> wide; ambiguous shapes fail with a classed error naming how to
  disambiguate.
- Candidate ids are fail-loud: required on data frames and matrices; missing -> a
  classed error. (A permissive matrix-only deterministic auto-name is available if
  ergonomics is ever preferred over strictness, but the default is fail-loud.)

## Provenance on diagnostic results

- `panel_hash` present uniformly on every result.
- Existing sweep columns (`sweep_id`; DSR/effective-trials' `metric_context_hash` /
  `cost_model_hash` / `risk_chain_hash`) kept present-but-`NA` for user panels -- no
  branching on source.
- `source` is one of `"retained_sweep_returns"` / `"user_return_panel"`;
  `input_identity` is omitted / `NULL` for user panels; `schema_version` unchanged.

## Worked example (the win)

```r
returns <- tibble::tibble(
  conservative = c(0.004, -0.011, 0.006, ...),
  balanced     = c(0.009, -0.004, 0.012, ...),
  aggressive   = c(0.021, -0.030, 0.018, ...)
)
panel <- ledgr_return_panel(returns)
ledgr_pbo(panel, S = 4)
ledgr_dsr(panel)
```

Three readable lines replace the hidden 34-line `make_retained_sweep()` the rejected
vignette relied on.

## Naming amendment

Recorded as a dated maintainer amendment to the validation-toolkit synthesis (Section
15): the diagnostics rename `ledgr_sweep_{pbo,dsr,min_track_record,cluster}` ->
`ledgr_{pbo,dsr,min_track_record,effective_trials}`. Rationale: the v0.1.9.5
sweep-family lean was recorded, not bound, and was conditioned on the retained sweep
being the evidence container; LDG-2670 makes the container a return panel, so the
condition no longer holds. `ledgr_sweep_returns_panel()` keeps its prefix (genuinely
sweep-specific). No deprecated aliases (pre-release, zero consumers). A future K-Ratio
diagnostic (LDG-2664) follows the same unprefixed convention (`ledgr_k_ratio()`).

## Blast radius (pre-release, acceptable)

`R/validation-*.R`, S3 classes / methods, `NAMESPACE`, Rd, `_pkgdown.yml`, validation
tests, API-export tests, doc-contract tests, `selection-integrity.qmd/.md`, `NEWS.md`,
`contracts.md`, and active packet / spec references. Archival v0.1.9.6 records are not
churned except where active docs describe the rename.

## Non-goals (v1)

No equity input; no raw-matrix polymorphism on diagnostics; no general clustering API;
`panel_hash` is not execution identity.
