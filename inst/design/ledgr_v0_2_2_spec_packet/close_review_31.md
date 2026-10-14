# Workstream 31 close review

**Mode:** Type 1 close review
**Ranges:** `646c3266..a5f41864`, `7d2bf9a6..d6a59a53`, `d6a59a53..0d04f22f`
**Candidate:** `0d04f22f`
**Verdict:** `CHANGES_REQUIRED`
**Date:** 2026-10-14

The build boundary, schema-literal classification, helper renames, helper
removals, style pass and both lint layers hold. One high finding breaks a
shipped contract: LDG-3038 removed the only seeding site that a seeded
`ledgr_sweep()` reached. Four medium findings show that the structural gates
and records are narrower than their claims. Every fix fits the accepted
design, so this is not NEEDS_TYPE_2.

## Findings

1. **F1 (high): seeded sweeps no longer seed the ambient RNG.**
   `15bba2eb` deleted `set.seed(execution_seed)` from `ledgr_execute_fold()`
   (`R/fold-engine.R`, before line 307) as a duplicate. It was a duplicate
   only for `ledgr_run()`. `ledgr_sweep()` calls `ledgr_execute_fold()`
   directly (`R/sweep.R:1508`, `1518`) and never passes through the remaining
   site in `ledgr_run_fold_impl()` (`R/backtest-runner.R:718-733`). A Tier 2
   strategy that calls `runif()` now draws from whatever RNG state the caller
   has, so a sweep row no longer matches `ledgr_run(seed = execution_seed)`
   or `ledgr_promote()`. This breaks the Execution Contract's "random-state
   semantics" rule and the Sweep Promotion Contract's exact stochastic
   replay.
   Probe on a 30-bar series: at `7d2bf9a6`, `set.seed(1)` and `set.seed(2)`
   before `ledgr_sweep(seed = 123L)` both give final equity 1000001, the same
   as the promoted run. At `0d04f22f` they give 1000194 and 1000649, and the
   run gives 1000001. Run on its own, the heavy block
   `test-sweep-parity.R:364` ("seeded stochastic sweep promotion reproduces
   the selected candidate") fails nine assertions at `15bba2eb` and
   `0d04f22f` and passes at `7d2bf9a6`. It passed inside the full-heavy
   protocol only by chance: its fixture has four bars, so an unseeded draw
   can produce the same trades. The fast and review records, the R CMD check
   run and the 51/51 ladder do not include a seeded ambient-RNG sweep.
   Smallest fix: put the save, seed and restore in one place at the shared
   fold-core entry (`ledgr_execute_fold()`) and delete the runner copy. Then
   rerun LTB-0268 and the 51/51 ladder. Add a registered witness, in the
   review profile or below, showing that a seeded sweep's rows do not depend
   on the caller's RNG and equal `ledgr_run(seed = execution_seed)`.
   Strengthening the existing heavy block's fixture would also work, but its
   oracle change then needs its own stated reason.

2. **F2 (medium): the census still crashes on zero-row families.**
   `ledgr_census_bind_rows()` (`tools/codebase-structure.R:1-9`) returns
   all-character columns. The summary then calls
   `sum(version_rows$outside_fingerprint)`
   (`tools/check-codebase-contracts.R:1379`), and `sum(character())` errors.
   A scratch root with one documented condition class and no version rows
   stops with `invalid 'type' (character) of argument`. With no condition
   classes, it stops earlier, at line 1365, because the `empty_frame()`
   columns are also character. This is the Workstream 29 residue that
   LDG-3033 named ("zero persisted version rows produce an empty census").
   LTB-0272 checks only the names and row count of the binder's output. So
   it misses this crash. It also misses a call site that goes back to an
   unconditional `do.call(rbind, version_rows)`: that mutation crashes the
   tool on an empty root while LTB-0272 passes. LCL-0270 ("every census
   family") and the Verification Contract's "valid typed table" claim more
   than this.
   Smallest fix: give the binder and `empty_frame()` declared column types.
   Then either make the fast block run the census summary on a typed empty
   frame, or narrow LCL-0270 and the contract sentence to the binder.

3. **F3 (medium): the condition gate is narrower than the census, and
   their inventories disagree.**
   `ledgr_structure_condition_classes()` (`tools/codebase-structure.R:73-76`)
   reads only a named `class =` argument of a call named `abort` or `warn`.
   It misses classes passed through in-package wrappers, which the census
   already resolves as `abort_wrapper_class`. It also misses a positional
   class argument. At HEAD the census has 365 public classes and the scan
   has 356. Ten are in the census only, for example
   `ledgr_invalid_ledger_meta`, `ledgr_fact_invalid_subtype` and
   `ledgr_snapshot_fact_timestamp_invalid`; `ledgr_strategy_error` is in the
   scan only.
   Mutations on a scratch copy each pass the LTB-0271 logic with an
   undocumented class:
   `ledgr_accounting_event_error("x", "ledgr_zz_new")`;
   `ledgr_assert_whole_second_utc(v, label = "x",
   class = c("ledgr_zz_child", "ledgr_zz_parent"))`;
   `rlang::abort("x", "ledgr_zz_positional")`.
   This misses the LDG-3034 criterion "the report-only tool and test blocks
   produce the same inventories". LCL-0269 claims "every statically
   recoverable public ... class element".
   Smallest fix: reuse the census wrapper resolution in the shared scanner
   (or recover the wrapper argument by the same rule), handle the positional
   `class`, and assert that the scan and census public sets are equal.

4. **F4 (medium): the 24 test-only seams have no recorded purpose.**
   `test_only_seams.csv` fills `testing_contract` with
   `paste0("direct_test_seam:", helper)`
   (`tools/check-codebase-contracts.R:1296`), which only repeats the name.
   LDG-3033 requires "a named testing contract and a real test caller", and
   the manual's helper criterion repeats that requirement. The callers are
   real; the sampled seams are called directly from tests. But several seams
   are production-shaped functions with no package caller, for example
   `ledgr_compute_features()`, `ledgr_check_no_lookahead()`,
   `ledgr_equity_from_events()` and `ledgr_fills_from_events()`. For these,
   the question of whether a test oracle or dead code is being tested is
   still open.
   Smallest fix: record a one-line contract per seam, or remove the seam
   together with its test.

5. **F5 (low): the condition reference documents a class that nothing can
   raise.** `8348bc4f` removed
   `ledgr_comparison_assert_fill_timing_comparable()`, the only raiser of
   `ledgr_fill_timing_not_comparable`. `R/condition-reference.R:90-91` and
   `:501` still describe that class as raised by fill-equivalence validation.
   This is the defect class of Workstream 30 F9. Remove the alias and prose
   and regenerate the help with roxygen2.

## Evidence corrections

- The style pass inserted 62 single-expression brace nodes; it removed none.
  A directional parse comparison of the 18 files shows each post-style tree
  equals its pre-style tree after unwrapping inserted `{x}` nodes, and two
  files are raw-identical. The substance holds. The evidence README, the
  Workstream 31 `scope_change` and the LDG-3032 acceptance wording should say
  "inserted" rather than "removed".
- `dev/bench/v0_2_2_pre_cran_removal/census/README.md` still describes the
  `46a761be` Workstream 30 census: 1,640 helpers, 11 uncalled helpers and 230
  undocumented classes. The committed CSVs record 1,629 helpers, no uncalled
  helper and no undocumented class at `8348bc4f`. A check-mode rerun at
  `0d04f22f` reproduces the CSVs byte for byte apart from the mode and
  commit fields in `metadata.csv`.
- LDG-3035 asks the packet to record the lint interval, advisory from
  LDG-3023 through LDG-3031 and blocking from LDG-3032, with links to both
  records. The evidence README gives the chronology. Neither it nor the
  packet README links `lint/` and `format_lint_blocking/`.

## Hosted CI

No hosted run exists at `0d04f22f`, and the branch has no runs. LDG-3032
and LDG-3034 make a hosted formatting-lint run and a hosted semantic-lint run
with zero findings acceptance criteria, and both jobs are new. The local
records cover the other gates. The hosted run therefore remains a required
evidence item; it is not something that can be inferred.

## Checked clean

- The tarball has 615 entries: 600 tracked files plus 15 directories. It has
  no `inst/design`, `.lintr`, `.lintr-semantic` or `.Rbuildignore`, and it
  keeps `man/figures/logo.svg`. A local rebuild is 1,969,511 bytes, within
  0.2 percent of the recorded 1,972,750; the difference is tar-header and
  mtime variation. Installing the built package with an added
  `inst/design/mutation.md` fails both LTB-0267 absence assertions. The
  push path filter is unchanged.
- One seeding site remains on the run path. Removing the restore makes
  LTB-0268 fail twice.
- The schema-literal census has 17 sites. One is persisted through a named,
  fingerprinted constant that config validation requires. The literal oracle
  has 22 members. The preceding fingerprint refuses and names the new
  binding. No migration or compatibility reader was added.
- The three helper renames are `R100`, and no old path remains. All eleven
  removed helpers had no `R/` or test caller; one dev spike script still
  calls `ledgr_sweep_feature_matrix_from_precomputed()`.
- `15b12a85` is the only hash in `.git-blame-ignore-revs`. README documents
  the blame setting. `git diff --check` is clean on all three ranges.
- Formatting lint (338 files) and semantic lint (338 files) each report zero
  findings. `tools/check-semantic-lint-config.R` prints
  `rules=8 injected=8`. The eight linters and the undesirable-function list
  match the ticket. Both lint jobs depend only on `plan`.
- `tools/check-codebase-contracts.R --mode=check` passes. LTB-0270 flags an
  inserted orphan. Its known blind spots are a self-recursive orphan, a pair
  of orphans that call each other, and `name = function` definitions; none
  of these occurs in `R/` today. The scanner is tool code, not a hot path.
- Targeted suites pass: codebase-contracts, test-control-plane,
  documentation-contracts, build-boundary, schema-literal and RNG. The
  full-heavy protocol passes 189/189, but see F1. R CMD check on the
  rebuilt tarball passes installed tests and the R code from all 24
  vignettes, with only the two expected `--no-build-vignettes` warnings and
  no NOTE. DuckDB 1.5.6.9000 loaded in every run.
- The optimization manual keeps its seven shapes unchanged and separates the
  executable floor from the review rule. Workstream 31 is open, and LDG-3035
  is `review_pending`.

## Review accounting

This is the first close-review verdict on Workstream 31 after the
preparatory checkpoint. Under M1, no ratio is computed or used as a gate.
