# Pre-CRAN removal source census

This is the corrected report-only LDG-3022 baseline. It was produced from
clean commit `a8416492` with:

```text
Rscript --vanilla tools/check-codebase-contracts.R --mode=report \
  --output=dev/bench/v0_2_2_pre_cran_removal/census \
  --source-commit=a8416492
```

The command exits successfully while findings exist. It changes no package
code, schema, identity, public API or stored output. The CSV files use stable
radix ordering and contain source file and line locations. A second complete
run produced byte-identical copies of all eight CSV files.

## Baseline

- `connections.csv` contains 82 connection entries: one `ATTACH`, five direct
  connects, nine path-opener calls, four public-init calls, 20 run-store
  opener calls, 27 cached or handle reads, six held-store borrows, two
  held-store registrations and eight exported caller-supplied connections.
  Only the CSV scratch connection and schema-template connection are
  in-memory. Fifty-one persistent-store entries have no current-store guard.
- `versions.csv` contains 34 bindings, 27 convention-string occurrences and
  72 exact comparison expressions. The convention rows cover 22 distinct
  `..._vN` labels. The record finds the two atomic version-like bindings
  outside the accepted fingerprint list:
  `ledgr_promotion_context_version` and
  `ledgr_snapshot_hash_rule3_version`.
- `run_configs.csv` contains 36 `ledgr_run_config()` consumers, 12
  `ledgr_run_fold()` consumers and 18 stand-alone hand-built config builders
  in `tests/` and `dev/bench/`. It follows symbols, pass-through helpers,
  `ledgr_config()` and run-derived config values to their origins. Nineteen
  rows supply both required fields, 43 omit at least one and four remain
  explicitly indeterminate.
- `helpers.csv` contains 1,654 package functions: 168 exports, 83 registered
  S3 methods plus the quoted `[` method, one hook, 1,371 R-referenced private
  helpers, 20 test-only private helpers and ten uncalled private helpers.
- `conditions.csv` contains 2,261 call-site records. The derived
  `condition_classes.csv` contains 385 recoverable classes: 122 documented
  public classes, 16 public classes with descriptions but no alias, 234
  undocumented public classes, one internal class and 12 non-public labels.
  Literal elements of mixed vectors and classes propagated through package
  abort wrappers are retained. Unresolved dynamic expressions, `stop()`,
  `warning()` and `rlang::warn()` remain visible in the call-site file.
- `summary.csv` reconciles the row and finding counts; `metadata.csv` records
  the mode, source commit, root and accepted fingerprint-member count.

These counts size the later reconciliation. They are not acceptance targets
for the permanent gates.

## Failure sensitivity

A minimal scratch repository with no connection calls still emitted every
typed record and returned success. It reported an added version equality and
`fixture_v1` convention, an unreferenced helper, literal parent and child
classes propagated through an abort wrapper, a quoted `[` S3 registration,
and both factory-built and literal configs with supplied identity fields. An
`expect_s3_class()` string did not turn the unreferenced helper into a call.
