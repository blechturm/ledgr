# LDG-3276: the overflow refusal at P4

Cut 27 decision 3 (maintainer, 2026-11-27). The pin `7f65733f` is in
`C:/Users/maxth/ledgr-wt/pin-lib-7f65733f`. Every run starts from
`C:/Users/maxth/ledgr-wt/cut27-scratch/run`, outside any source package.

## The change

`dev/lean_core/loop.R`, `lean_p4_apply()`, with two helpers in `fifo.R`:
- **Success:** a successful lot candidate checks all its fill rows with
  `lean_fill_deltas_finite()`, before the book is installed. It is one
  vectorised test.
- **Failure:** on a refused lot batch, `lean_lot_first_failure()` finds the
  first failing row j by prefix bisection, as the package's
  `ledgr_fold_fill_candidate()` does: about log2(n) kernel calls, on the
  refusal path only, with no per-fill loop. The rows before j are then
  checked, and j's lot condition is raised again unchanged.
- **The refusal:** it is the package's own `ledgr_accounting_event_error()`,
  so the class vector and message are the pin's.

## Witnesses (`parity/loop_workloads_overflow.R`)

Each witness keeps the run's tables and its escaping condition, the failed
sweep candidate's row (stop_on_error FALSE) and the stopping sweep's
escaping condition (stop_on_error TRUE). Its reach predicate, checked on
the pin's tables:
- the expected class is on all three;
- for a P4 refusal, the run's exception diagnostic is at stage
  "accounting" on the fill pulse, 2024-01-01T16:00:00Z.

| workload | case | refusal |
| --- | --- | --- |
| ovf_sell_1.9 | 1e308 sold at 1.9 | ledgr_invalid_accounting_event |
| ovf_hold_1.9 | held (control) | ledgr_config_non_finite, later |
| ovf_sell_10 | sold at 10 (control) | ledgr_invalid_lot_fill first |
| ovf_delta_then_lot | an earlier infinite cash delta before a later lot overflow | ledgr_invalid_accounting_event |
| ovf_lot_then_delta | the reverse | ledgr_invalid_lot_fill |

`ldg3276_witnesses_debug0.csv` and `_debug1.csv` (with their logs, run with
`--freeze`): 5 workloads, 90 tables, 0 different, PASS 5, 5 of 5 frozen
paths checked. The freeze rows (3 lean folds each, gate, both debug
settings) are in `loop_freeze_changes.R`.

`ovf_probe.txt` comes from `dev/spikes/switch_probe/ovf_probe.R`, extended
to assert. For all five cases, with debug off and on, the lean core's run
condition, stopping-sweep condition (complete class vectors) and failed
row equal the pin's, and each case refuses with its expected class:
OVERFLOW PROBE PASS, 0 failures.

## Variants (`loop_parity.R`, `loop_variant_changes.csv`)

| variant | fault | workloads | CAUGHT for |
| --- | --- | --- | --- |
| ovf_delta_check_omitted | both checks removed | ovf_sell_1.9, ovf_delta_then_lot | the lost accounting refusal; the new config and lot conditions declared |
| ovf_check_too_early | the whole batch checked before the lot kernel | ovf_sell_10, ovf_lot_then_delta | the lost lot refusal; the new accounting condition declared |
| ovf_earlier_rows_skipped | the rows before a failing lot row left unchecked | ovf_delta_then_lot | the lost accounting refusal; the new lot condition declared |

The variant driver (`loop_variants.R --workloads=<the four refusing
witnesses>`) gives:
- debug 0: 5 manifest rows, 3 variants, 0 failures, and the five negative
  controls fail closed (`ldg3276_variants_debug0.log`);
- debug 1: 5 rows, 3 variants, 0 failures.

The per-variant CSVs are in `variants/`. A first version of
ovf_delta_check_omitted declared no new conditions and came back
UNRELATED; its expected new conditions are now declared.

## No regression

`ldg3276_subset_debug0.csv` and `_debug1.csv` cover the LDG-3275 subset
plus crossover_10x300, s4_capacity_fill, s4_cash_overflow,
s5_compiled_overflow and dense_cost, run with `--freeze`. The result: 16
workloads, 265 tables, 0 different, PASS 16, every frozen path checked,
debug off and on. The full proof matrix reruns at LDG-3283.

## Documents

- The pulse-plumbing synthesis has the amendment "the overflow refusal
  (Cut 27, 2026-11-27)", with local notices after R4, on Section 4's LR-15
  row and on the candidate-failure boundary row.
- `contracts.md`, contract-execution-accounting-events, has the refusal
  and its precedence.
- `lean_core_rules_ledger.md` has LR-26 (contract), and LR-15 is narrowed
  by it.
- `lean_core_interface.md` has Section 19.15.
