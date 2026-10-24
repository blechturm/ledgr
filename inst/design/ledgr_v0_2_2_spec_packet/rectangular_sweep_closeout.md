# Workstream 57 closeout: rectangular sweep inputs and readable candidates

## Outcome

LDG-3102 and LDG-3103 are implemented in `35456322`, with the final stored-row
parity witness recorded in the closeout commit. An ordinary rectangular data
frame or tibble is now a strategy grid: one row is one candidate and one column
is one strategy parameter. The pre-release `ledgr_param_grid()` surface is
deleted without an alias. Feature grids remain explicit, and only
`ledgr_grid_cross()` composes the feature and strategy namespaces.

Sweep, saved-sweep and review printing now put compact `strategy_params` and
`feature_params` summaries before `candidate_id`. Common scalar values are
visible in place. Longer values are abbreviated deterministically and point to
`ledgr_candidate()` for the complete object. Printing is presentation only and
does not mutate the sweep, its parameters or identity.

## Rectangular boundary

The rectangular form accepts non-empty, uniquely named columns of unclassed
logical, integer, double or character values. Values must be non-missing and
doubles must be finite. Row names have no meaning. One row with zero columns is
one empty-parameter candidate; zero rows refuse, and repeated rows, including
two zero-column rows, refuse before strategy preflight or candidate execution.

Factors, Date/POSIXt, list columns, complex, raw and other classed or unsupported
columns refuse through documented subclasses of `ledgr_invalid_grid`. The
conversion preserves primitive types and row order, computes canonical row
content once, and rejects a duplicate before the execution boundary.

The direct rectangular and `ledgr_strategy_grid()` forms are strategy-only.
Both place the row in `params`, keep `feature_params` exactly `list()`, and
produce identical candidate IDs, execution seeds, economics and candidate-table
persistence rows. A parameterized feature map therefore cannot accidentally
consume a same-named strategy column. Explicit feature candidates arise only
from `ledgr_feature_grid()` composed through `ledgr_grid_cross()`.

## Removed compatibility surface

`ledgr_param_grid()` and `print.ledgr_param_grid()` are absent from R code,
NAMESPACE, generated help, pkgdown reference entries, examples, current
vignettes and tests. LCL-0487/LTB-0496 assembles the retired identifier at run
time, checks the loaded namespace and scans those current product and teaching
surfaces. Historical design, audit and benchmark records are intentionally not
rewritten.

The package's former call sites were moved to current forms. Changes in test
files are mechanical constructor migrations except where a test deliberately
checks the new rectangular boundary, namespace split or executable-grid
representation. The rendered sweep article uses an ordinary tibble, explains
that `tidyr::crossing()` output has the same accepted shape, and uses the ledgr
composition helper only when feature parameters also vary.

## Readable presentation

LCL-0486/LTB-0495 pins empty, strategy-only, feature-only and composed
candidates at narrow and ordinary console widths. It covers live, reopened and
review surfaces, DONE, INCOMPLETE and FAILED rows, deterministic truncation with
an extraction hint, namespace order before `candidate_id`, and serialized
object identity before and after printing. A degraded tibble produced by a
column selection falls back to ordinary tibble printing instead of assuming
that hidden sweep parameter columns still exist.

## Identity and persistence

LCL-0485/LTB-0494 compares a public `tidyr::crossing()` grid with the
corresponding `ledgr_strategy_grid()` result. It pins row values and types,
candidate order, parameter namespaces, candidate IDs, seeds, economics,
save/reopen, promotion context and the complete candidate rows produced for
durable persistence. Row names are changed independently and have no effect.
The feature-map witness uses different values under the same name in the two
namespaces, so a restored plain-list feature fallback fails visibly.

## Seven-shape walk

1. Rectangular columns become row parameter lists once at the public sweep
   boundary; candidates do not reconstruct the source frame.
2. Canonical row content is computed once and reused for duplicate detection
   and deterministic labels.
3. Candidate tasks carry the prepared strategy and feature parameter lists;
   no invariant grid data is rebuilt in the pulse loop.
4. No database query, append, scalar writer or snapshot verification was added
   to grid conversion or printing.
5. No per-pulse or per-instrument loop was added. The only new loops are over
   grid columns, candidate rows or displayed result rows at their owning
   boundary.
6. Print summaries are temporary character columns on a display copy; they do
   not alter the result object or durable bytes.
7. No environment-held mutable grid, parameter, candidate or display cache was
   introduced.

The codebase census passes after regeneration. The whole-tree formatting lint
finds one brace issue in untouched `test-run-continuity-ii.R`; the same line is
present at the workstream base, so WS57 adds no formatting finding.

## Verification

- The final focused set passes `test-param-grid.R`, `test-sweep.R`,
  `test-sweep-review.R`, `test-sweep-parity.R`,
  `test-sweep-persistence-roundtrip.R`, `test-walk-forward-identity.R`,
  `test-api-exports.R`, `test-documentation-contracts.R` and
  `test-test-control-plane.R`.
- Every touched test file passed after migration. The only migration defect was
  one test reading the obsolete executable-grid storage shape directly; it now
  checks the current strategy namespace.
- Ordinary fast executes 577/577 blocks with no skips or failures in 111.13
  seconds. `check-test-gate.R` returns `LEDGR_TEST_GATE_OK` against 112 seconds.
- The sweep article renders and its checked-in Markdown passes the freshness
  checker.
- Source build succeeds. `R CMD check --no-manual --no-build-vignettes` passes
  installation, namespace, Rd, examples, tests and all executed vignettes. It
  reports only the established two no-built-vignette warnings and unqualified
  `head` note.
- Claims and ticket YAML parse, generated help matches roxygen source,
  `check-codebase-contracts.R --mode=check` passes and `git diff --check` is
  clean. No private data was used.

