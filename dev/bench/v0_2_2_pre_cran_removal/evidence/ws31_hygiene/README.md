# Workstream 31 hygiene evidence

This checkpoint covers LDG-3037 through LDG-3040 on 2026-10-14. The
implementation commits are `7d2bf9a6`, `15bba2eb`, `997b8e7e`, `516ada54`,
`2c095a11`, `3126c692` and the control-plane correction `4d99a743`.

## LDG-3037: build boundary

- Before `7d2bf9a6`, `R CMD build --no-manual --no-build-vignettes` produced
  a 6,770,854-byte (6.457 MiB) tarball with 1,421 entries, 811 below
  `inst/design`.
- After `7d2bf9a6`, the same command produced a 1,958,849-byte (1.868 MiB)
  tarball with 611 entries and no `inst/design` entry. The final checkpoint
  tarball is 1,961,184 bytes with 613 entries and no `inst/design` entry.
- The checkout documentation-contract suite and LTB-0267 pass. In an
  extracted built package, adding `inst/design/mutation.md` makes LTB-0267
  fail both the installed-directory and `system.file()` absence assertions.
- The CI `inst/design/**` quick-tier path filter is unchanged. The shipped
  `man/figures/logo.svg` remains in the tarball, and `/src/*.gcda` is ignored.

## LDG-3038: RNG ownership

- `R/backtest-runner.R` has the one run/fold `set.seed()` site;
  `R/fold-engine.R` has none. A seeded public run restores the caller's
  existing `.Random.seed`, or removes the seed when the caller had none.
- Removing only the on-exit restoration makes both LTB-0268 restoration
  assertions fail in a disposable worktree.
- The complete public-cycle comparison from `7d2bf9a6` to `15bba2eb` reports
  51 of 51 families identical and the informational identity family
  identical (`SCALE_CHECK_OK`). The changed boundary keeps only fixed-size
  seed state and introduces none of the seven scale-growing shapes.

## LDG-3039: schema-version classification

- `tests/testthat/fixtures/schema-version-literal-census.csv` records all 17
  current inline schema-version writers, defaults and validators. One is
  persisted by ledgr: the membership-universe rule in
  `run_configs.config_json`. The other 16 are memory-only inspection, plan,
  simulation, validation or objective metadata.
- The persisted rule now uses
  `ledgr_universe_rule_schema_version = 1L`, which is the twenty-second
  member of the literal store-format oracle. Config validation requires its
  exact value. A preceding fingerprint refuses and names this binding.
- Comparing the post-RNG record with the schema-version checkpoint reports
  51 of 51 families identical and the informational identity family
  identical. There are therefore no fixture-family changes to name.
- The accepted aggregate research store was created under the preceding
  21-member fingerprint. It is deliberately stale and will refuse until a
  fresh store is built; no private store was opened or migrated for this
  checkpoint.

## LDG-3040: helper names and source census

- Git detects all three helper changes at 100 percent similarity:
  `helper-snapshot-timestamp-reference.R`,
  `helper-fact-integrity-fixtures.R`, and
  `helper-availability-fact-matrix.R`. The helper bodies did not change.
- The timestamp-branch and fact-integrity suites pass. Benchmark references
  and the committed census use only the new paths.
- `tools/check-codebase-contracts.R --mode=check` passes with 69 connection
  rows, 139 version rows, 80 run-config rows, 1,640 helpers, 2,267 condition
  call sites and a 22-member format fingerprint.

## Package gates

The checkout documentation-contract, build-boundary, RNG, schema-literal,
store-gate, timestamp-reference, fact-integrity and control-plane suites pass.
The final source tarball passes every installed test under
`R CMD check --no-manual --no-build-vignettes`. The check status is two
expected vignette warnings caused by `--no-build-vignettes` and the existing
`.lintr` hidden-file NOTE; it has no test error. All 24 vignette replay checks
run successfully.
