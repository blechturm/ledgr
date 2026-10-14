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

## LDG-3032: one formatting pass and blocking lint

- Clean commit `15b12a85` applies styler 1.11.0 once to the exact 18 files
  carrying LDG-3023's 39 findings, with roxygen examples disabled. Commit
  `2011db66` records that exact hash in `.git-blame-ignore-revs`, documents
  the local Git configuration and makes only the formatting job blocking.
- The raw parser trees are exact for two files. The other 16 differ only
  because the accepted `brace_linter` findings require removing redundant
  one-expression braces; after normalizing those braces, all 18 parser trees
  are identical. The complete fixture ladder is 51/51 exact, including the
  identity family, and the owning focused tests pass.
- The formatting record moves from 39 advisory findings at `a8416492` to
  zero blocking findings. Formatting lint remains independent of tests,
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
  record under `semantic_lint_advisory/` scans 335 files with zero findings.
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
  package checks. `semantic_lint_blocking/` records 338 files and zero
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
- The final source fingerprint has 22 members. That is intentionally one more
  than LDG-3036's 21-member research-lake rebuild because the later
  maintainer-added LDG-3039 classified and fingerprinted the persisted
  membership-universe schema. The 21-member store is truthfully stale; the
  existing later lake-rebuild owner must use the 22-member current build.
