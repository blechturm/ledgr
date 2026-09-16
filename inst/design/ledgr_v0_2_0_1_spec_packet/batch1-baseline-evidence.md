# Batch 1 Baseline Evidence

**Tickets:** LDG-2720 and LDG-2721
**Baseline:** `b60c9ac4f50012d93b040551e4ffc83aa29c6e08`
**Runtime:** R 4.6.1, duckdb 1.5.2, testthat 3.3.2, collapse 2.1.7
**Status:** Complete after independent re-review and maintainer acceptance.

## Durable witnesses

The reviewed spike semantics are now owned by package tests rather than by the
spike harness alone:

- `test-availability-provider-witnesses.R` covers complete and partial lists,
  interval assertions, status precedence and supersession, lifetime and
  terminal events, backward re-seek, repeated and shuffled cutoffs, the empty
  status-row default, and public `ledgr_facts_resolve()` membership agreement;
- `test-availability-fold-witnesses.R` runs the eight registered diagnostic
  cases against both baseline arms, including 7-row and 4,096-row chunks,
  interruption, resume, rollback, classed nonmember increase, early terminal
  exit, and the held-instrument missing-bar token; and
- `tests/testthat/fixtures/availability-v0-2-0-1/` freezes the direct case's
  diagnostics, events, equity, strategy state, completion, and normalized run
  identity plus the complete scenario summary.

Run identity removes exactly `created_at_utc`, `config_json.db_path`, and
`config_json.data.snapshot_db_path`. It retains the run ID, archive time,
configuration hash, and every other persisted field. Each expected-value
surface has a deliberate mutation test that fails closed.

The frozen rows were produced from the baseline seams after their Section 7
evidence review by Codex. The Batch 1 commit names that reviewer explicitly.

## Baseline checker rerun

The evidence prefixes are the tracked directories shown below; the checkers
read those files and reproduce their deterministic subsets in scratch stores.

| Checker | Evidence prefix | R 4.6.1 result |
| --- | --- | --- |
| columnar writer | `dev/spikes/availability-hot-path-representation/evidence/` | semantic rerun and all three byte-exact diffs passed; after the Git environment correction, the no-rerun continuation passed 33/33 checks, for 37/37 checker assertions across the two-stage transition run |
| prepared provider | `dev/spikes/availability-provider-preparation/evidence/` | full rerun passed 54/54 checks, including 3,676 cutoff queries, seven fold scenarios, 85 deterministic regression tests per arm, and the separately reported optional test |
| diagnostic block | `dev/spikes/availability-diagnostic-block-write/evidence/` | full rerun passed 54/54 checks, including eight scenarios under both arms, 85 deterministic regression tests per arm, and byte-exact deterministic evidence |

The writer checker's first R 4.6.1 invocation reached and passed its semantic
and byte-diff checks before its Git subprocess rejected the repository as
unsafe. The correction makes all three checkers temporarily inherit
`USERPROFILE` as `HOME` for Git and teaches their scope guards to validate the
reviewed seam at its committed introduction range. No semantic evidence or
measurement CSV was rewritten for that correction.
The four assertions not repeated after the correction were the semantic rerun
and its three byte-exact diffs. The correction cannot affect those assertions:
the writer runner records no Git output in any of the three deterministic
files they compare.

## Test-only references

`tests/testthat/helper-availability-v0-2-0-1-references.R` owns copies of:

| Reference | Installed baseline source |
| --- | --- |
| pairwise status conflicts | `ledgr_fact_validate_source_conflicts()` |
| pairwise membership conflicts | `ledgr_fact_validate_membership_conflicts()` |
| pairwise lifetime conflicts | `ledgr_fact_validate_lifetime_conflicts()` |
| current provider and per-pulse resolvers | `ledgr_availability_provider_build_current()` and its old resolver helpers |
| scalar diagnostic fields | `ledgr_availability_diagnostic_fields()` |
| row-list writer | `ledgr_row_list_diagnostic_writer()` |

The helper is sourced only by testthat. Tests prove these reference names are
absent from the installed namespace and compare their present behavior with
the baseline implementations.

## LDG-2726 source-guard draft

The retirement guard must reject these installed production remnants:

- options `ledgr.internal.spike_availability_provider`,
  `ledgr.internal.spike_diagnostic_writer`,
  `ledgr.internal.spike_diagnostic_chunk_rows`, and
  `ledgr.internal.spike_diagnostic_block`;
- arm observations `spike_arm` and `spike_diagnostic_mode`;
- `ledgr_availability_provider_build_current()`,
  `ledgr_availability_members_at()`, `ledgr_availability_status_at()`,
  `ledgr_availability_lifetime_at()`, and
  `ledgr_availability_terminal_event_at()`;
- `ledgr_row_list_diagnostic_writer()` and
  `ledgr_availability_diagnostic_fields()`; and
- the row-list final bind shape `do.call(rbind, diagnostic_rows)`.

The guard must retain and permit `ledgr_membership_resolve_at()` and
`ledgr_membership_evidence()`, together with the inspection helpers they need,
because they remain the independent public engine behind
`ledgr_facts_resolve()` and `ledgr_facts_history()`. Provider, fold, result,
and reopen consumers must not call those retained inspection helpers.

## Package verification

Under R 4.6.1, the focused availability regression net passed all 14 matching
test files with zero failures, warnings, or skips. The documentation-contract
file also passed with the two Batch 1 tickets in `review_pending` and every
later ticket still `pending`.

After the independent review found leaked spike options, the corrected
availability net passed again in 305.9 seconds. The provider, writer, chunk,
and block options were `NULL | NULL | NULL | NULL` both before and after the
complete 14-file run, so later files execute under their declared defaults.
