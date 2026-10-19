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

## Workstream 41 refresh

The census was regenerated in check mode at correction commit `9c1e352e`
after the causal history substrate correction. Check mode passes with 71
connection entries, 158 version rows, 80 hand-built run-config rows, 1,712
helpers and 2,333 condition call sites. The two history-substrate connections,
new treatment seams and shifted source locations are source-derived results of
the implementation. `metadata.csv` names the correction commit; no current-only
or run-config gate was relaxed.

## Workstream 46 execution-mode branch census

LDG-3074 (Cut 16 decision 17) adds two tables. `mode_branches.csv` has one
row per execution-mode switch site in `R/`, keyed by file, top-level
function, kind (`branch` for an `if`/`ifelse` whose condition holds a switch,
`flow` for a switch passed on or assigned), switch and context text, with an
occurrence number for repeated keys and no line numbers, so unrelated edits
do not churn it. `mode_branch_counts.csv` totals functions, branch sites and
flow sites per file. The switch forms and the alias rule are documented above
`ledgr_mode_branch_scan()` in `tools/codebase-structure.R`.

Check mode reads the committed `mode_branches.csv` before writing any table
and stops with `LEDGR_MODE_BRANCH_CENSUS_FAILED` when the source has a site
the record lacks or the record keeps a site the source no longer has. A
branch is therefore added or removed only by regenerating this record in
report mode, which shows in review. Because keys carry no line, a site added
beside equal sites is reported as that key's last occurrence. Adding
`if (availability_active)` to `ledgr_sweep_impl()` without regenerating the
record makes check mode stop with `unrecorded=1 stale=0` before any table is
written. `--self-test-mode-branches` proves the
check refuses one added branch, and LTB-0331 runs the same comparison in the
fast profile.

Regenerated on branch `ws46/history-simplification` from `9b0b304d`: report
mode wrote the new tables, then check mode passed with 74 connection entries,
158 version rows, 80 hand-built run-config rows, 1,768 helpers, 2,381
condition call sites and 217 mode-branch sites (162 branch, 55 flow) in 56
functions across 29 files. The six existing tables are unchanged;
`metadata.csv` records check mode.

The merge of the accepted Workstream 43 (`804e9be2`, BASE `b9d098c8`)
regenerated the record in report mode because Workstream 43 removed four
sites (one in `ledgr_config()`, one in `ledgr_run_fold_impl()`, two in
`ledgr_precompute_payload()`) and added none; check mode then passed with
213 sites (158 branch, 55 flow) in 55 functions across 29 files. LDG-3075
and LDG-3077 change no mode-branch site; their removals of private helpers
only move the helper, condition and connection tables, which are
regenerated with them.

Mutations, each applied to the working tree, run against
`test-codebase-contracts.R` in one `pkgload::load_all()` session (R 4.6.1,
Windows) and restored byte for byte (checked by MD5):

| Mutation | LTB-0331 |
| --- | --- |
| Add `if (availability_active) invisible(NULL)` to `ledgr_sweep_impl()` without regenerating the record | errors (check refuses `unrecorded=1`) |
| Stop recognising `availability$active` in `ledgr_mode_branch_switch_at()` | errors (stale rows) |
| Return no stale rows from `ledgr_mode_branch_compare()` | fails (removed-site expectation) |
| Replace the check-mode comparison with a no-op | fails (structural order assertion) |
| Drop function-local alias detection | errors (stale alias rows) |

The unmutated block passes 11 expectations before and after the run.

## Failure sensitivity

A typed zero-row instance of all six summary families produces six zero row
counts and six zero finding counts. Restoring an unconditional row bind at the
version call site fails LTB-0272. Wrapper, positional and builder class forms
are included in both inventories; making either inventory narrower fails
LTB-0271 or the check-mode reconciliation.
