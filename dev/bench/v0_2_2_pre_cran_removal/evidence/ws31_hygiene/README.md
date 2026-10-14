# Workstream 31 hygiene evidence

This checkpoint covers LDG-3037 through LDG-3040 on 2026-10-14. The
implementation commits are `7d2bf9a6`, `15bba2eb`, `997b8e7e`, `516ada54`,
`2c095a11`, `3126c692` and the control-plane correction `4d99a743`.

## LDG-3037: build boundary

- Before `7d2bf9a6`, `R CMD build --no-manual --no-build-vignettes` produced
  a 6,770,854-byte (6.457 MiB) tarball with 1,421 entries, 811 below
  `inst/design`.
- After `7d2bf9a6`, the same command produced a 1,958,849-byte (1.868 MiB)
  tarball with 611 entries and no `inst/design` entry. The final Workstream 31
  tarball is 1,972,750 bytes with 615 entries, no design tree and no
  checkout-only lint configuration.
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
`R CMD check --no-manual --no-build-vignettes`. The first final check exposed
that `.lintr` and `.lintr-semantic` would ship and create a hidden-file NOTE;
the build-boundary correction excludes both checkout-only CI configurations.
The repeated check has only the two expected vignette warnings caused by
`--no-build-vignettes`, no NOTE and no test error. All 24 vignette replay
checks run successfully.

## LDG-3032: one formatting pass and blocking lint

- Clean commit `15b12a85` applies styler 1.11.0 once to the exact 18 files
  carrying LDG-3023's 39 findings, with roxygen examples disabled. Commit
  `2011db66` records that exact hash in `.git-blame-ignore-revs`, documents
  the local Git configuration and makes only the formatting job blocking.
- The raw parser trees are exact for two files. The other 16 differ only
  because styler inserted 62 single-expression brace nodes while resolving
  the accepted `brace_linter` findings; it removed none. After unwrapping
  only those inserted nodes, all 18 parser trees are identical. The complete
  fixture ladder is 51/51 exact, including the
  identity family, and the owning focused tests pass.
- The formatting record moves from 39 advisory findings at `a8416492` to
  zero blocking findings. The advisory and blocking records are
  [`lint/`](../../lint/) and
  [`format_lint_blocking/`](../../format_lint_blocking/). Formatting lint
  remains independent of tests,
  package check, coverage and the semantic layer.

## LDG-3033: reconciled helper and condition debt

- Commit `8348bc4f` removes eleven genuinely uncalled private helpers. The
  refreshed source census at `114e5f62` has 1,629 helpers, no uncalled helper
  finding, 24 named test-only seams with real callers, 2,248 condition call
  sites and no undocumented statically recovered public class. Sixty-four
  dynamic or base-condition sites carry an explicit disposition.
- Every recoverable public class and parent has an alias and prose entry in
  the condition reference. The structural implementation additionally
  resolved the dynamic strategy wrapper and documented
  `ledgr_strategy_error`; no current condition class or message was renamed.
- `.lintr-semantic` contains exactly the accepted eight linters and the
  explicit undesirable list for `sapply`, `browser` and `debug`. The advisory
  record under [`semantic_lint_advisory/`](../../semantic_lint_advisory/)
  scans 335 files with zero findings.
  It changes no formatting, test, check or coverage outcome.

## LDG-3034: permanent structural and semantic gates

- Commit `b51f853e` adds fast-profile blocks LTB-0270 through LTB-0272 and
  claims LCL-0268 through LCL-0270. One cached parse derives 1,629 top-level
  helpers, their static and string-dispatch references, 357 literal or
  resolvable dynamic condition classes and the empty-census boundary. The
  focused block takes about two seconds after package load.
- Three disposable-worktree mutations fail as intended: a wholly uncalled
  helper fails LTB-0270 once; an undocumented child and parent fail LTB-0271
  twice; restoring unconditional `do.call(rbind, list())` fails LTB-0272
  three times. The report-only check independently passes with 69 connection,
  139 version, 80 run-config, 1,629 helper and 2,248 condition-call rows.
- `tools/check-semantic-lint-config.R` injects one violation for each of the
  eight rules and requires each named linter to fire. The separate semantic
  job is blocking and does not share an execution edge with formatting or
  package checks. [`semantic_lint_blocking/`](../../semantic_lint_blocking/)
  records 338 files and zero
  findings at `b51f853e`, with the same configuration as the advisory arm.

## LDG-3035: standing rules and package gates

- The Verification Contract names the exact opener, fingerprint, helper,
  condition and empty-census detectors. The optimization manual keeps its
  seven performance shapes unchanged and adds the broader helper criterion:
  a named contract or a second caller, with a named exception for test seams.
- The first fast-profile attempt correctly refused an orphan file-level
  profile marker before running tests. After attaching a marker to each block,
  it exposed two stale source records caused by the accepted style and
  condition-documentation edits. The refreshed literal locations and the
  documentation-only snapshot-census row make those older detectors exact
  again; no runtime code changed.
- The final P-core-pinned ordinary fast record under `fast_profile/` executes
  567 of 567 blocks with no skip or failure in 101.25 seconds. The unchanged
  112-second gate passes. LTB-0270 through LTB-0272 account for three of those
  blocks and share one source parse.
- The complete review record under `review_profile/` executes 337 of 337
  blocks with no failure in 266.11 seconds. Its one skip is the pre-existing
  optional-package path. Two earlier attempts are excluded because child
  processes resolved DuckDB 1.5.2 from the user library; the recorded run
  pins the R 4.6 project library and resolves DuckDB 1.5.6.9000 in both parent
  and child processes.
- The final source fingerprint has 22 members. That is intentionally one more
  than LDG-3036's 21-member research-lake rebuild because the later
  maintainer-added LDG-3039 classified and fingerprinted the persisted
  membership-universe schema. The 21-member store is truthfully stale; the
  existing WS7 lake rebuild with dividend facts must use the 22-member current
  build.

## Close-review corrections

The independent Type 1 close review is preserved in
`inst/design/ledgr_v0_2_2_spec_packet/close_review_31.md`. Commits `3ab97b33`
and `c13eb5cc` close its five findings without changing a schema, identity,
stored row or public result:

- The shared fold entry is the sole execution `set.seed()` site. Seeded run
  and sweep boundaries restore an existing caller seed or remove a seed that
  did not exist before the call. Two sweeps started under different ambient
  seeds agree, and their recorded execution seed reproduces through
  `ledgr_run()`. Disabling shared-fold seeding makes the sweep arms diverge.
- All six census families now have declared typed empty schemas and use one
  summary implementation. Restoring an untyped empty bind makes the summary
  fail. The final check-mode record at `693a32dc` has 69 connection rows, 139
  version rows, 80 run-config rows, 1,627 helpers, 2,240 condition call sites,
  379 recovered classes and 64 recorded findings.
- The report and executable condition inventories share one scanner for
  literal, positional, builder and statically resolvable wrapper classes and
  must reconcile. Every retained test-only seam has a concrete named testing
  contract; adding a seam without one fails check mode. The dead
  `ledgr_fill_timing_not_comparable` reference was removed from source and
  generated help.
- The corrected implementation remains 51/51 exact against the pre-review
  candidate, including the identity family. The final ordinary fast record
  executes 567/567 blocks in 105.64 seconds against the unchanged 112-second
  bound. The review profile executes 337/337 blocks with no failure and the
  one pre-existing optional-package skip.
- The final formatting and semantic records each scan 338 files with zero
  findings; the semantic configuration self-check detects all eight rules.
  `R CMD check --no-manual --no-build-vignettes` passes every installed test
  and all 24 vignette replays. Its only two warnings are the expected missing
  prebuilt-vignette warnings caused by `--no-build-vignettes`.
- GitHub Actions run `38578216775` at `93d801a8` is green. Its independent
  blocking formatting and semantic jobs pass, and all three hosted ordinary
  fast-profile runs execute 567/567 blocks. Their advisory clocks are 176.3,
  172.6 and 171.7 seconds, with a 172.584-second median above the unchanged
  112-second bound. The binding fixed-host record is the local 105.64-second
  median. The Ubuntu package job passes its cold-start,
  historical-acceptance and `R CMD check` stages. Release-only, isolated-CRAN
  and coverage stages are correctly absent from this quick-tier branch run
  rather than counted as evidence.
- Commit `693a32dc` removes the unused v0.1.0 database-writing
  `ledgr_compute_features` engine, its now-unused feature-list validator, two
  test-only utilities and three tests that exercised only the dead engine.
  The live feature-series, precompute, availability and strict-feature suites
  pass. The final census has 23 contracted test seams; no seam was retained by
  inventing a contract for dead code. A final current-tree ordinary sample
  executes the resulting 564/564 fast blocks in 106.12 seconds. It is a
  correctness sample, not a replacement for the binding three-run
  105.64-second record.
- GitHub Actions run `38588320767` at `ae43629b` passes both blocking lint
  jobs, all three hosted 564-block ordinary fast runs and R CMD check. Its
  166.797-second hosted median remains advisory and above the unchanged local
  112-second bound; it is not relabelled as a timing pass.
