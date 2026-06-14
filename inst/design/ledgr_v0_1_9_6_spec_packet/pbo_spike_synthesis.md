# ledgr v0.1.9.6 PBO/CSCV Spike Synthesis

Status: Implementation complete; awaiting Claude review and maintainer acceptance.
Ticket: LDG-2650
Date: 2026-06-14

## Verdict

Gate verdict: green for adding a native PBO/CSCV implementation ticket to
v0.1.9.6 after this synthesis passes review and maintainer acceptance.

Adapter verdict: yellow for using the CRAN `pbo` package as the runtime
foundation. `pbo` is useful as a reference and optional cross-check, but the
public ledgr diagnostic should be native and deterministic over ledgr return
panels.

No public PBO/CSCV implementation is included in LDG-2650.

## Method Shape

Probability of Backtest Overfitting (PBO) uses Combinatorially Symmetric Cross
Validation (CSCV) over a `T x N` trial matrix:

- `T`: ordered observations;
- `N`: candidate strategies or model configurations;
- `S`: an even number of contiguous subsets that evenly divides `T`;
- each CSCV case chooses `S / 2` subsets as in-sample and the complement as
  out-of-sample;
- a metric function scores each candidate on the in-sample and out-of-sample
  slices;
- the in-sample winner's out-of-sample rank is converted to a relative rank
  `omega_bar`;
- `lambda = log(omega_bar / (1 - omega_bar))`;
- PBO is the fraction of CSCV cases where `lambda <= 0`.

For ledgr, the natural evidence object is the retained completed-candidate
return panel from LDG-2648/LDG-2649. The diagnostic asks whether the candidate
selected by in-sample evidence often ranks poorly out of sample across symmetric
subpartitions of the retained return history.

## Package Audit

Source: CRAN package manual and locally installed CRAN binary, verified on
2026-06-14.

- Package: `pbo`
- Version: 1.3.5
- Date/Publication: 2022-05-26 14:40:02 UTC
- License: MIT + file LICENSE
- NeedsCompilation: no
- Depends: R >= 4.0.0
- Imports: utils, lattice, latticeExtra, foreach
- Suggests: PerformanceAnalytics, grid, testthat, doParallel, parallel, knitr,
  spelling
- Runtime install status: installed locally during the spike for verification;
  package load warns that the binary was built under R 4.5.3 while this
  workspace uses R 4.5.2.
- Public API checked: `pbo(m, s = 4, f = NA, threshold = 0, inf_sub = 6,
  allow_parallel = FALSE)`.
- Input contract: `m` is a `T x N` data frame of returns; `s` is the number of
  CSCV subsets and must evenly divide the rows; `f` is required and must return
  one performance score per candidate column.
- Output contract: object of class `pbo`, a list with fields `results`,
  `combos`, `lambda`, `phi`, `rn_pairs`, `func`, `slope`, `intercept`, `ar2`,
  `threshold`, `below_threshold`, `test_config`, and `inf_sub`.

Observed implementation notes:

- `pbo()` uses `stopifnot(is.function(f))` but does not expose ledgr-style
  classed conditions.
- `s` divisibility is documented but should be prevalidated by ledgr before any
  adapter/native computation.
- `results` is a matrix/list structure with vector-valued `R` and `R_bar`
  entries, not a user-facing tidy return shape.
- `allow_parallel = FALSE` is deterministic for the fixed reference fixture.

Package posture:

- Do not add `pbo` to `Imports`.
- A future ledgr implementation may use `pbo` in tests or optional comparison
  scripts when installed.
- Do not expose a public ledgr result whose correctness depends solely on
  `pbo`'s unclassed validation, list-shaped output, or optional package
  availability.

## Reference Evidence

Reference script:

```text
inst/design/ledgr_v0_1_9_6_spec_packet/pbo_spike_reference.R
```

The script builds a fixed `12 x 4` returns data frame with `s = 4` and a
column-wise mean-return metric. It compares `pbo::pbo(..., allow_parallel =
FALSE)` against an independent manual CSCV calculation for the same fixture.

Expected values pinned by the script:

- `n_star`: 1, 2, 4, 3, 4, 4
- `n_max_oos`: 4, 4, 3, 4, 2, 1
- `os_rank`: 1, 2, 3, 1, 1, 3
- `omega_bar`: 0.25, 0.50, 0.75, 0.25, 0.25, 0.75
- `lambda`: -1.09861228866811, 0, 1.09861228866811,
  -1.09861228866811, -1.09861228866811, 1.09861228866811
- `phi`: 2 / 3
- `below_threshold`: 0.333

Local verification run:

```text
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" inst/design/ledgr_v0_1_9_6_spec_packet/pbo_spike_reference.R
```

Result:

```text
pbo reference check passed
version: 1.3.5
phi: 0.6666667
below_threshold: 0.333
```

This is a reference-value fixture, not a published known-answer fixture. It is
sufficient to verify adapter shape, deterministic execution, the `pbo` output
schema, and the native CSCV skeleton for a tiny case. A public PBO ticket should
turn this into package tests and add at least one known-direction example with
an obviously overfit or obviously non-overfit candidate family.

## ledgr Panel Contract

The ledgr input to PBO/CSCV is the retained-return panel, not fills, positions,
or reconstructed trades.

Required public implementation gate:

- call `ledgr_sweep_returns_panel()` / projection helpers over retained returns;
- use only completed candidates with retained return evidence;
- drop the structural first timestamp after verifying first-row
  `period_return` is `NA_real_`;
- require a complete timestamp grid for selected candidates;
- fail closed with `ledgr_sweep_returns_incomplete_panel` and the compatibility
  alias `ledgr_validation_pbo_incomplete_panel` for ragged panels;
- report `candidate_ids`, `completed_candidate_ids`, and
  `excluded_candidate_ids`;
- prevalidate that `S` is even and divides the number of return rows after
  first-row removal;
- carry panel metadata into the PBO result object.

No identity hash changes are needed for the spike. A future public diagnostic
should carry evidence metadata and schema/version fields in its result, but it
must not mutate retained sweep artifacts or committed run identity.

## Adapter vs Native Decision

Bind native implementation for any v0.1.9.6 public PBO/CSCV surface.

Rationale:

- The core CSCV/PBO calculation is small and deterministic.
- Native code can expose ledgr condition classes, stable typed output, evidence
  metadata, and a method-teachable result object.
- Native code avoids a hard dependency on an optional package with a list-shaped
  output contract and unclassed argument validation.
- `pbo` remains valuable as an optional reference implementation and package
  compatibility check because its input API matches the ledgr retained-return
  panel shape.

Fallback conditions:

- If the native implementation cannot be reference-verified during v0.1.9.6,
  defer public PBO/CSCV to v0.1.9.7+.
- If a future adapter route is added, it must be optional and must fail closed
  with classed ledgr conditions when `pbo` is missing, API-incompatible, or
  produces an unexpected output schema.
- Do not ship adapter-only PBO as the ledgr public diagnostic.

## What PBO Cannot Prove

Required teaching surface before any public PBO result ships:

- PBO estimates selection-integrity risk for a declared candidate family over
  the observed return panel.
- It is evidence about the selection process, not proof of future profitability.
- It does not fix bad data, survivorship bias, point-in-time universe mistakes,
  global preprocessing leakage, or revised-data leakage.
- It does not make a weak strategy good; it can only show that the in-sample
  winner often fails out of sample under CSCV recombination.
- It depends on a meaningful candidate family. If the candidate set is too small,
  too correlated, or mined before the declared sweep, interpretation weakens.
- It depends on enough observations and valid `S` partitions. Short panels and
  high autocorrelation produce wide uncertainty.
- It does not replace DSR, MinTRL, purging/embargo, CPCV, or business-objective
  constraints; these are complementary evidence layers.

## Conditional v0.1.9.6 Follow-Up

If Claude review and maintainer acceptance approve this synthesis, v0.1.9.6 may
add one or more atomic public PBO/CSCV implementation tickets with these bounds:

- native implementation only for the public surface;
- optional `pbo` cross-checks only in tests or spike/reference scripts;
- input is the LDG-2648 retained-return panel;
- no business-objective, winner-picking, promotion, walk-forward identity, or
  automatic selection is mixed into the PBO ticket;
- method documentation must satisfy the Methodological Diagnostics styleguide.

If review rejects the reference evidence or the native route, PBO/CSCV and the
dependent business-objective layer defer to v0.1.9.7+.

## Sources

- CRAN manual: `https://cran.r-project.org/web/packages/pbo/pbo.pdf`
- GitHub repository: `https://github.com/mrbcuda/pbo`
- Binding synthesis:
  `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`
- v0.1.9.6 spec:
  `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md`
