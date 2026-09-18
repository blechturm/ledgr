# Availability Hot-Path Representation - Spike Inventory

**Charter:** `rfc_availability_hot_path_representation_v0_2_0_x_spike_charter_v2.md`
(passed structural review). **Executor:** Claude. **Source:** branch `v0.2.0.1`,
commit `cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2`; R 4.5.2, collapse 2.1.7,
duckdb 1.4.3, same host as the lane profile. Nothing committed; the RFC index is
not advanced. Evidence review under `spike_protocol.md` section 7 belongs to a
reviewer who did not execute.

## What ran

One seam. `R/availability-diagnostic-writer.R` (new) selects, once per fold,
between mode `rows` (the production list-of-one-row-data-frames path moved
verbatim) and mode `columnar` (typed column buffers of 4,096 rows in an
environment; `collapse::setv()` for numeric, integer and POSIXct columns and
base replacement for character columns, the same split as the durable event
handler; one `data.frame()` per chunk flushed through the existing
`write_run_diagnostics()`, which still owns the transaction and assigns
`diagnostic_seq` at write time). `R/fold-engine.R` changed by +13/-24 lines:
the accumulator block, nine identical call-site rebinds to `diag_row(`, and the
final-bind block, which is now `diagnostic_writer$drain()`. The exception path,
the row constructor, the handler, schema, contracts, and public readers are
untouched. Mode is read from `options(ledgr.internal.spike_diagnostic_writer)`;
the default is `rows`, so arm 1 is the production code path.

Deliverables: `spike_runner.R` (fixtures, five semantic cases, sampled
measurement, envelope with external kill), `spike_checker.R` (semantic rerun
into scratch and byte-exact diff of the three deterministic CSVs; validation of
the measurement CSVs against the charter's repetition shape, median/spread
rule, envelope bounds, lane shares, and GREEN decision; package scope guard
over every tracked change type and every untracked path), this inventory, and
`evidence/` (`fixture.csv`, `cases.csv`, `diagnostics_40_rows.csv`,
`measurements_40.csv`, `envelope_757.csv`, `lanes_757.csv`).

## Case history (section 3: failures generated the cases)

The smallest fork, a tiny fixture with a 7-row chunk forcing mid-pulse flushes,
matched production on the first run. The first full fork run then failed on
nine of nine case rows; every failure was a harness fault, and each became a
correction rather than a writer change:

1. Tables carried `run_id`, so any case compared to the direct run differed;
   comparisons now drop `run_id`.
2. The reopen claim compared `ledgr_results()` output to a raw SQL frame; the
   two differ only by a reader-only `ledgr_result_type` attribute, now dropped.
3. Resume-then-exception swapped the strategy between invocations, which
   changes `config_hash`, and ledgr correctly refused to resume. One strategy
   source is kept and interruption or failure is injected through options, as
   `test-availability-economics.R:815` does.
4. A resumed run's `equity_curve` holds only the finalizing invocation's rows
   (`run-finalize.R:422-424` deletes and rewrites it), so per-invocation tables
   are compared to the rows arm rather than to the direct run.
5. A failed invocation has no reader handle; the session-reader flag is `NA`
   for it rather than a comparison against the earlier invocation's output.

Final cases (`cases.csv`, both arms unless noted): C1 direct; C2 direct with a
100-row chunk (columnar only); C3 interrupt at pulse 20 and resume; C4 injected
exception at pulse 25; C5 interrupt at pulse 10, resume, exception at pulse 25.
Every arm-parity flag is TRUE: diagnostics, events, equity, strategy state and
completion identical to the rows arm in all cases; C1-C3 diagnostics identical
to the direct run (clean-versus-resumed equality); reopen through the public
reader and `ledgr_run_explain()` at three cells identical across arms; C4
leaves exactly one error row in both arms after three flushed chunks rolled
back; C5 keeps the 5,060-row committed prefix plus one error row with a
continuous sequence in both arms.

## Measurements

40 pulses, one unmeasured warm-up and three measured runs per arm, fresh
process and store per run, medians with run-to-run spread:

| arm | wall around `ledgr_run()` | `t_loop` | peak working set |
| --- | ---: | ---: | ---: |
| rows | 51.59 s (spread 0.44) | 49.49 s | 786.5 MiB (spread 121.2) |
| columnar | 22.14 s (spread 0.32) | 20.08 s | 369.6 MiB (spread 2.6) |

757 pulses, envelope 1,800 s wall around `ledgr_run()` and 4,096 MiB working
set, enforced by the external sampler from the child's run-start marker:

| arm | outcome | run elapsed | peak WS | store |
| --- | --- | ---: | ---: | --- |
| rows | killed at the wall ceiling | 1,800.3 s | 3,104.8 MiB | `RUNNING`, 0 diagnostics |
| columnar | finished within the envelope | 523.4 s | 900.8 MiB | `DONE`, 383,042 rows |
| columnar, profiled | finished within the envelope | 518.3 s | 934.5 MiB | `DONE`, 383,042 rows |

Host note: the maintainer reported another heavy computation running on this
host during the session. The 40-pulse rows medians match the uncontended lane
profile (`t_loop` 49.49 s against 49.47 s), so that phase appears clean; the
757-pulse columnar wall figures are upper bounds until the section 7 reviewer
reruns them on a quiet host. Semantic evidence records no timings.

Profiled columnar run at 757 pulses, share of in-loop samples:
provider status/lifetime 55.6%, provider membership 27.0%, diagnostic append
11.2%, diagnostic construction 3.1%, valuation 2.1%, residual 0.7%, DuckDB
append 0.2%, final bind 0.0%. Grouped: provider 82.7%, diagnostics 14.6%.

## Outcome

GREEN under the charter's measurement boundary. The alternative preserves
every bounded evidence claim, removes the diagnosed mechanism (no retained row
list, no final `rbind`; the 757-pulse bind lane has zero samples), and is
materially lower on both wall and peak memory at 40 pulses by far more than the
current path's spread. At 757 pulses the current path breaches the envelope and
the alternative completes at 29% of the wall ceiling and 22% of the memory
ceiling, so the kill/recharter condition does not fire. The profile after the
correction names provider resolution as the leading lane, with membership cost
now visible at 60 headers, as the charter anticipated for a later question.

## Gut demonstration

Gutted path: `flush()` in the columnar writer with its `reset()` removed, so
the buffer index is not returned to zero after a chunk is written. On the
tiny fixture (8 instruments, 6 members, 5 pulses, chunk 7), the rows arm
completed with 35 diagnostics and the gutted columnar arm failed loudly: the
next append wrote past the buffer capacity, `collapse::setv()` raised an error,
the fold exception path rolled the transaction back, and the run halted
(`R/fold-engine.R:1128`). The writer was restored from its backup and verified
by checksum (`20708b8b33c8a944136c4339b9f17ba7`, no `# GUT` residue); the same
comparison then reported every table identical and the sequence continuous.

Checker: the first evidence review (Codex, section 7) reproduced `fixture.csv`,
`cases.csv`, and `diagnostics_40_rows.csv` byte-identically in an independent
1,623 s run and required three checker corrections: M1, the diff was tolerant
(`all.equal()`) and omitted `fixture.csv`, now byte-exact over all three
deterministic CSVs; M2, the scope guard read only porcelain `M` and `??` rows,
now every tracked change from HEAD by status (renames as delete plus add) plus
every untracked path, with Git failures fatal; M3, the measurement checks were
structural only, now the charter's repetition shape, median/spread rule,
envelope bounds and stop labels, lane-share consistency, one largest grouped
lane, and the GREEN and kill-condition clauses. The corrected checker reports
37 of 37 checks passed on a full run (rerun byte-identical), and fails as
intended on perturbed copies: a `1e-9` change or a missing rerun file, swapped
arm timings, a killed or over-ceiling columnar run, diagnostics as the largest
lane, inconsistent shares, an altered fixture, staged add/delete/rename and
working-tree delete in package scope, and a non-Git location.

## Demoted, deleted, learned

Demoted: the ten-cell `ledgr_run_explain()` sample became three cells, because
each call rebuilds the full availability table; the five harness comparisons
above were demoted from claims to definitions. Deleted: nothing from the
package; the `session_reader` fallback and the strategy swap were deleted from
the harness. Learned about the package: `ledgr_run_explain()` rebuilds the
availability table per call; sealing the 757-pulse fixture (426,191 bars) takes
about nine minutes before `ledgr_run()` starts; a resumed run's `equity_curve`
covers only the finalizing invocation; Windows `Rprof()` samples about 64% of
`t_loop` on this path; and with 60 complete lists the membership lane grows from
1.7% to 27% of in-loop samples while status/lifetime resolution stays the
largest single lane. Execution notes: a temp-directory sweep must not run while
a child process is alive; one checker run was restarted for that reason. The
scope-guard gut test was meant to run in a scratch clone; the clone's checkout
failed on Windows path length, the simulated changes landed in the working
repository, and were reversed file by file (the three affected files are
identical to HEAD, nothing staged, seam checksums unchanged). The concurrent
full checker run caught every one of them, and was rerun on the clean tree.

## Reproduction

```text
Rscript dev/spikes/availability-hot-path-representation/spike_runner.R all
Rscript dev/spikes/availability-hot-path-representation/spike_checker.R
```
