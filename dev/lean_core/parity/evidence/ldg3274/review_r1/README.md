# Workstream 46 close review round 1: corrections and proofs

The round-1 review is `inst/design/ledgr_v0_2_3_spec_packet/ws46_close_review_round1.md`
(CHANGES_REQUIRED at 400c6a14). It made two required findings, both in the
harness, and found no public table that differs.

## F1: an E-stage refusal on a worker read as a channel fault

**The fault.** The worker channel required every lean envelope entry to
end in a lean fold or a coverage refusal. A selected worker sweep that the
pin refuses at E (the corporate CASHFLOW admission check) is neither. Its
tables were identical to the pin's, yet each worker record faulted:
"0 lean folds and 0 refusals for 1 envelope entries".

**The correction** (`dev/lean_core/loop_workers.R`; Section 19.14):
- The worker's envelope wrapper notes the class of an error that ends an
  entry before its fold starts, when there was no coverage refusal. A
  calling handler takes the class and an exit hook stores it, so the
  condition passes on unchanged.
- The record carries these classes (`prefold`).
- With harness hooks, the parent requires lean folds + coverage refusals +
  errors before the fold = envelope entries.
- An entry that leaves before its fold without an error records NA, and
  the parent faults it.
- The other channel checks are unchanged.

**Witness.** `s5_workers_compiled_refused` (`loop_workloads_slice5.R`) is a
selected sweep with two candidates on two workers. Every worker entry is
refused at E. The sweep returns FAILED rows (stop_on_error FALSE) and an
escaping `ledgr_compiled_spot_fifo_unavailable/ledgr_invalid_fold_execution`
(TRUE). Its reach predicate checks:
- four dispatched tasks;
- both rows FAILED with the CASHFLOW message;
- the escaped CASHFLOW condition.

The witness has freeze rows with 0 lean folds in gate, batch-one and inert
modes (`loop_freeze_changes.R`). `s5_worker_sweep()` now passes further
arguments on to `ledgr_sweep()`; the existing callers pass none.

**Variant.** `worker_prefold_unrecorded` (`loop_parity.R`,
`loop_variant_changes.csv`) replaces the recording line with its marker.
The channel then names all four entries unexplained, and the variant is
CAUGHT with debug off and on, with identical tables.

## F2: the recorder's relative --src

`recorder/run.R` now reads and normalises `--src` with the other path
arguments, before `lean_harness_workdir()` changes the working directory.
The child run gets the absolute path. The source-pin label and origin
check are unchanged.

## Proofs (`run_r1.R`, `run_r1.log`)

**Scope.** The changed channel code runs only in sweep workers (the
envelope wrapper and the task record). In the parent it runs once per
worker record, so a workload with no workers takes none of it. The parity
steps therefore rerun:
- every workload that dispatches workers, taken from the worker records of
  the committed final-code runs (`../*_debug0_workers.csv`);
- the new witness;
- each mode at debug 0 and 1, with the approved freeze, from a directory
  outside any source package.

| run | result |
| --- | --- |
| `gate_debug0`, `gate_debug1` | 16 workloads, 333 tables, 0 different; PASS 15, PASS* 1; 16 of 16 frozen paths checked |
| `batch1_debug0`, `batch1_debug1` | 10 workloads, 121 tables, 0 different; PASS 9, PASS* 1; 10 of 10 frozen paths checked |
| `inert_debug0`, `inert_debug1` | 10 workloads, 121 tables, 0 different; PASS* 10; 10 of 10 frozen paths checked |
| `variants_debug1` | every variant row on the eight worker workloads that carry variants: 18 manifest rows, 16 variants, 0 failures |
| `variants_debug0` | the same rows at debug 0: 17 manifest rows, 15 variants, 0 failures; the five negative controls fail closed (control_unrelated UNRELATED, control_unreached UNREACHED, control_wrong_store_path MISSED, control_unrelated_refusal UNRELATED, control_unreached_refusal UNREACHED, each status 1) |
| `recorder_relative_src` | `--src=../pin-archive` from the work directory: the installed arm 112 records, 0 fail; the source-pin child, labelled "source pin", 180 history-fixture records, 0 fail; exit 0 (the review's probe exited 1) |

The variant driver gains `--workloads=`, which keeps only the manifest
rows on the named workloads; the negative controls still run. Its first
debug-0 run (`run_r1.log`, status 1) refused before running anything. The
filter checked the names after the debug filter, and `s5_workers_sizing`
carries a variant at debug 1 only. The check now comes first. The step
was rerun with the same arguments, which `variants_debug0.log` records.

## Lines

`lines_r1.csv` (`lines_r1.R`; the definition of `../lines_harness.csv`,
whose 400c6a14 counts it reproduces) counts non-blank, non-comment lines:

| file | change |
| --- | --- |
| `loop_workers.R` (harness) | 163 -> 177 |
| `loop_workloads_slice5.R` (workload) | 509 -> 527 |
| `loop_parity.R` (workload) | 659 -> 662 |
| `loop_variants.R` (witness) | 87 -> 92 |
| `loop_freeze_changes.R` (witness) | 235 -> 239 |
| `recorder/run.R` (harness) | 203 -> 203 |

Production lines are unchanged. The round changes none of the production
files that `cut19_lines.R` counts, and `loop.R` stays at 997.
