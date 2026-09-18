# Availability Diagnostic Block Spike - Execution Inventory

Written for the independent Section 7 reviewer and the maintainer.

## Outcome

**GREEN.** The typed per-pulse diagnostic block preserved every registered
claim and completed the warm 757-pulse fold in a 24.93-second measured median,
inside both the 60-second wall envelope and the 1,024 MiB memory envelope. The
kill/recharter condition did not fire.

This is research evidence from the registered synthetic availability fixture,
not a public peer ranking or production-adoption decision.

## Partial-state audit and execution history

Execution resumed after the original executor exhausted its context. At that
point no R process was alive, no evidence directory or inventory existed, and
the registered protocol had not begun. The worktree contained a complete
syntactically valid runner (556 lines), checker (then 329 lines), and the two
package seam edits. That correct partial work was preserved rather than
reimplemented.

A temporary preflight ran all 16 semantic arm/scenario combinations in 165.1
seconds and both regression arms in 348.7 seconds. The first partial checker
run exposed one harness-only defect: its empty fill-reason requirement passed
`""` through `strsplit()`, producing `character(0)` and making that assertion
impossible to satisfy even though the persisted row was present. The checker
now stores required reason vectors directly. No package or evidence value
changed for that correction. The subsequent full run regenerated all recorded
evidence from the restored fork.

## Runnable fork

The one seam is `options(ledgr.internal.spike_diagnostic_block)`, read once per
fold behind the reviewed columnar writer. Both arms use the prepared provider
and the same bounded chunk writer.

- `current`: one `ledgr_availability_diagnostic_fields()` call and one writer
  append per diagnostic row.
- `block`: one typed diagnostic block per pulse, then one `append_block()` call
  which splits across the same chunk boundaries. Character columns use base
  replacement; numeric, integer, and POSIXct columns use vector writes.

The mode stamp is outside persisted values. The schema, reason vocabulary,
ordering, sequence assignment, transaction owner, exception row, provider,
and public readers are unchanged.

## Semantic evidence

Eight failure-derived scenarios ran under both arms: direct execution, direct
execution with a 4,096-row chunk, interruption and resume, injected rollback,
classed nonmember-increase rollback, resume then exception, early terminal
exit, and interruption/resume followed by early terminal exit. The ordinary
semantic chunk size was seven rows.

Every arm pair was identical for diagnostics, ledger events, equity, strategy
state, completion, and normalized run identity. Diagnostic order, types,
missingness, reason tokens, and continuous `diagnostic_seq` were preserved.
The 7-row and 4,096-row runs were identical. Reopened availability views and
`ledgr_run_explain()` were identical whichever arm served the reopen.

The persisted token census includes an unrestricted and restricted decision,
stale-mark risk, `execution_bar_missing`, `final_pulse_no_execution`, a fill
with an empty reason, affordability reconciliation, and the post-rollback
`fold_exception`. Both arms reached DONE, INCOMPLETE, and FAILED. The semantic
fixture did not itself emit an execution `trading_halted` no-fill; the existing
opening-halt and ordered `trading_halted|execution_bar_missing` regression
tests ran and passed under the block arm, as required by Charter Review L1.

The interrupted-then-resumed INCOMPLETE run still cannot be reopened because
terminal-evidence validation sees only the last invocation's rewritten equity
curve. That pre-existing package finding occurs identically in both arms and
remains outside this spike's scope.

The availability regression net ran 86 tests under each arm with zero failed,
errored, or skipped tests. The mirai-dependent parallel-sweep test was present
and ran separately under both arms with five passing expectations each.

## Registered measurements

The static fold has 563 instruments, a 505-member axis, 757 pulses, 60 complete
membership lists, 30,300 membership rows, complete bars, flat targets, zero
fills, and 383,042 persisted diagnostics. R 4.5.2, collapse 2.1.8, DuckDB
1.4.3, and testthat 3.3.1 were used throughout at HEAD `b0fe6b8`.

| Arm | Warm-up | Run 1 | Run 2 | Run 3 | Median | Raw spread |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Current wall (s) | 95.23 | 94.36 | 93.71 | 94.50 | 94.36 | 0.79 |
| Block wall (s) | 24.93 | 25.11 | 24.93 | 24.88 | 24.93 | 0.23 |
| Current loop (s) | 85.90 | 85.05 | 84.49 | 85.30 | 85.05 | 0.81 |
| Block loop (s) | 15.63 | 15.73 | 15.67 | 15.60 | 15.67 | 0.13 |

The raw spread is `diff(range(raw_wall_seconds))`. The block median is 69.43
seconds below the current median, far more than the current 0.79-second spread.
Measured block peaks were 764.8, 745.4, and 799.5 MiB, all below 1,024 MiB.
Every fold completed DONE. Current runs observed 383,042 scalar constructions
and no block; block runs observed 757 blocks and no scalar construction.

Cold sealing took 747.91 seconds. It is reported separately and excluded from
the warm comparison because the sealed snapshot was copied and reused. The
separate sealing probe has already attributed that cold cost to the quadratic
membership conflict validator; this spike neither changes nor excuses it.

## Persisted parity and lane attribution

One non-measured 757-pulse pair used one shared run ID in separate copied
stores. DuckDB multiset differences were empty for `runs`, completion,
383,042 diagnostics, zero ledger events, 757 equity rows, and 757 strategy
state rows. The run comparison excluded exactly `created_at_utc` and the two
embedded store locators. Top-level and embedded run IDs and `archived_at_utc`
were compared.

The profiled block run finished in 25.00 seconds. Captured in-loop samples put
valuation first at 67.6%, residual fold work second at 20.7%, diagnostics at
10.3%, and provider work at 1.4%. Diagnostic construction was 2.2%, block
retention 0.8%, DuckDB append 7.4%, and final bind zero. The bottleneck moved
from diagnostic construction and retention to valuation.

## Gut demonstration

After the clean evidence run, `append_block()` was temporarily gutted to loop
over the already-built block and call the scalar writer append once per row.
All semantic values and arm-pair comparisons still passed. The checker failed
the block-path `setv()` bound and consequently rejected GREEN: two failures,
exactly the mechanism assertion and final decision. Thus equality cannot hide
a row-wise fallback.

The gut was removed with the inverse patch. SHA-256 checks of the diagnostic
writer, fold engine, provider seam, and prepared provider exactly matched their
pre-gut values, and no gut marker remains. Recorded measurement CSVs were not
touched during the demonstration.

The restored clean checker then reran semantic and regression evidence in
512.5 seconds, reproduced all six deterministic CSVs byte-for-byte, validated
the measurements, parity, arm attestation, and scope, and exited with zero
failures.

## Demoted, deleted, and learned

- Demoted: the prerequisite's 0.30-second isolated block result remains a
  mechanism floor, not a fold forecast; profiler shares remain sampled lane
  attribution, not elapsed wall partitions.
- Deleted from the alternative hot path: 383,042 scalar field-list builds and
  383,042 per-row writer appends. The current arm remains intact as control.
- Learned: one typed block per pulse preserves durable evidence while reducing
  the registered warm fold by 73.6%, or 3.79x. The 25-40 second aspiration was
  reached at its lower edge. Valuation is now the clear next hot lane.
- Not learned: peer ranking, eventful full-population performance, cold seal
  performance after its separate fix, or production-release placement.

## Deliverables and reproduction

The authorized deliverables are `spike_runner.R` (556 lines),
`spike_checker.R` (334 lines), this inventory, and twelve CSVs under
`evidence/`. Runner plus checker plus 275 added seam lines total 1,165 R lines,
inside the 1,500-line budget. The correction was five net checker lines, below
the 500-line stop.

From the repository root:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/availability-diagnostic-block-write/spike_runner.R all
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/availability-diagnostic-block-write/spike_checker.R
```

The first command pays the cold seal once and then runs both measurement and
parity phases from that reusable template. The checker reruns deterministic
semantic and regression evidence into scratch, byte-diffs six CSVs, validates
the remaining evidence and envelope, and guards all package-scope changes.

Nothing is staged, committed, pushed, adopted into production, or added to the
RFC index. The next action is the independent Section 7 rerun, gut, and diff
review by an agent who did not execute this stage.
