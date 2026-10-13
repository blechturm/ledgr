# Pre-CRAN removal source census

This is the report-only LDG-3022 baseline. It was produced from clean commit
`25ca9d6c` with:

```text
Rscript --vanilla tools/check-codebase-contracts.R --mode=report \
  --output=dev/bench/v0_2_2_pre_cran_removal/census \
  --source-commit=25ca9d6c
```

The command exits successfully while findings exist. It changes no package
code, schema, identity, public API or stored output. The CSV files use stable
radix ordering and contain source file and line locations. A second complete
run produced byte-identical copies of all eight CSV files.

## Baseline

- `connections.csv` contains 69 connection entries: one `ATTACH`, five direct
  connects, nine path-opener calls, four public-init calls, 20 run-store
  opener calls, 14 cached or handle reads, six held-store borrows, two
  held-store registrations and eight exported caller-supplied connections.
  Forty-six persistent-store entries have no current-store guard.
- `versions.csv` contains 220 binding, branch and equality records. It finds
  the two atomic version-like bindings outside the accepted fingerprint list:
  `ledgr_promotion_context_version` and
  `ledgr_snapshot_hash_rule3_version`.
- `run_configs.csv` contains all 36 hand-built `ledgr_run_config()` calls in
  `tests/` and `dev/bench/`. None supplies `identity_rule_version` or
  `data.snapshot_hash` in the call itself.
- `helpers.csv` contains 1,654 package functions: 168 exports, 83 registered
  S3 methods, one hook, 1,371 R-referenced private helpers, 20 test-only
  private helpers and 11 uncalled private helpers.
- `conditions.csv` contains 2,126 call-site records. The derived
  `condition_classes.csv` contains 363 distinct literal abort classes: 118
  documented public classes, 18 public classes with descriptions but no
  alias, 215 undocumented public classes, one internal class and 11
  non-public labels. Dynamic abort expressions, `stop()`, `warning()` and
  `rlang::warn()` remain visible in the call-site file.
- `summary.csv` reconciles the row and finding counts; `metadata.csv` records
  the mode, source commit, root and accepted fingerprint-member count.

These counts size the later reconciliation. They are not acceptance targets
for the permanent gates.

## Failure sensitivity

A minimal scratch repository was scanned with three inserted changes. The
report found the added version equality as `read_branch_or_equality`, the
unreferenced function as `uncalled_private`, and the unaliased condition as
`undocumented_public`. A hand-built config in the same fixture was reported
with both required identity fields absent. Report mode returned success.
