# Pre-CRAN removal source census

This is the Workstream 30 check-mode census after the current-only correction.
It was produced from clean implementation commit `10c8b444` with:

```text
Rscript --vanilla tools/check-codebase-contracts.R --mode=check \
  --output=dev/bench/v0_2_2_pre_cran_removal/census \
  --source-commit=10c8b444
```

The command exits successfully because the current-only, connection and
hand-built run-config rules pass. It changes no package code, schema,
identity, public API or stored output. The CSV files use stable radix ordering
and contain source file and line locations. Helper and condition findings are
measured inputs for Workstream 31 rather than Workstream 30 failures.

## Baseline

- `connections.csv` contains 69 connection entries: one `ATTACH`, four direct
  connects, one path-opener call, 20 run-store opener calls, 27 cached or
  handle reads, six held-store borrows, two held-store registrations and
  eight exported caller-supplied connections. Every persistent-store entry
  reaches the accepted current-store guard.
- `versions.csv` contains 32 bindings, 25 convention-string occurrences and
  79 read comparisons. It records no current-only violation. The sole
  reported inventory finding is the deliberately separate promotion-context
  version binding, which remains outside the format fingerprint and is now
  checked for exact v2 equality by its reader.
- `run_configs.csv` contains 80 discovered config origins. Sixty-four supply
  both required identity fields. Sixteen bounded fixture/config-builder rows
  supply neither and are classified by the checker's accepted construction
  rules; no current run-config consumer violates the gate.
- `helpers.csv` contains 1,640 package functions: 168 exports, 84 registered
  S3 methods, one hook, 1,352 R-referenced private helpers, 24 test-only
  private helpers and 11 uncalled private helpers.
- `conditions.csv` contains 2,267 call-site records. The derived
  `condition_classes.csv` contains 379 recoverable classes: 119 documented
  public classes, one public alias-only class, 16 public description-only
  classes, 230 undocumented public classes, one internal class and 12
  non-public labels.
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
