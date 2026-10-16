# Pre-CRAN removal source census

This is the corrected Workstream 31 check-mode census after helper and
condition reconciliation. It is regenerated from the accepted implementation
plus the close-review corrections with:

```text
Rscript --vanilla tools/check-codebase-contracts.R --mode=check \
  --output=dev/bench/v0_2_2_pre_cran_removal/census \
  --source-commit=693a32dc
```

The command exits successfully because the current-only, connection,
hand-built run-config, helper and condition rules pass. The CSV files use
stable radix ordering and contain source file and line locations. Empty
families use the same typed schemas and summary arithmetic as populated ones.

## Baseline

- `connections.csv` contains 69 connection entries: one `ATTACH`, four direct
  connects, one path-opener call, 20 run-store opener calls, 27 cached or
  handle reads, six held-store borrows, two held-store registrations and
  eight exported caller-supplied connections. Every persistent-store entry
  reaches the accepted current-store guard.
- `versions.csv` contains 33 bindings, 25 convention-string occurrences, 80
  read comparisons and one retired-literal guard. It records no current-only
  violation. The sole reported inventory finding is the deliberately separate
  promotion-context version binding, which remains outside the format
  fingerprint and is checked for exact v2 equality by its reader.
- `run_configs.csv` contains 80 discovered config origins. Sixty-four supply
  both required identity fields. Sixteen bounded fixture/config-builder rows
  supply neither and are classified by the checker's accepted construction
  rules; no current run-config consumer violates the gate.
- `helpers.csv` contains 1,627 package functions: 168 exports, 84 registered
  S3 methods, one hook, 1,351 R-referenced private helpers and 23 test-only
  private helpers. No private helper is uncalled. Each retained test seam has
  a concrete one-line testing contract and a real test caller.
- `conditions.csv` contains 2,240 call-site records. The derived
  `condition_classes.csv` contains 379 recoverable classes: 366 documented
  public classes, one internal class and 12 non-public labels. Literal,
  positional, class-builder and statically resolvable package-wrapper forms
  agree with the executable scanner. The 63 unresolved dynamic or base
  condition sites remain visible with explicit dispositions.
- `summary.csv` reconciles the row and finding counts; `metadata.csv` records
  the mode, source commit, root and the 22-member format fingerprint.

These are evidence counts, not fixed acceptance targets. The permanent gates
derive their inventories from the current source and require the report and
test scanners to agree.

## Workstream 40 refresh

The source census was regenerated in check mode at correction commit
`88c5afc7` after the causal-fact and Date-boundary work. Check mode passed with
70 connection entries, 154 version rows, 80 hand-built run-config rows, 1,648
helpers and 2,272 condition call sites; `metadata.csv` names that commit.
Changes in row locations and the added helper are source-derived consequences
of the implementation, not new acceptance targets.

The final correction removes `ledgr_compute_features`, its now-unused
`ledgr_validate_feature_defs` helper and the three tests that exercised only
that obsolete database-writing engine. The production feature-series paths
remain covered by their existing tests. The source-derived census therefore
drops one R-referenced private helper and one test-only seam without adding an
allowlist or weakening a detector.

## Failure sensitivity

A typed zero-row instance of all six summary families produces six zero row
counts and six zero finding counts. Restoring an unconditional row bind at the
version call site fails LTB-0272. Wrapper, positional and builder class forms
are included in both inventories; making either inventory narrower fails
LTB-0271 or the check-mode reconciliation.
