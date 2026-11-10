# Diagnostic Records D3 Synthesis: Final Review

- Reviewer: Claude (seed author; did not write the synthesis), 2026-11-10.
- Mode: Type 1 final review (verification, not design), RFC cycle stage 8.
- Target: [D3 synthesis](rfc_diagnostic_records_v0_2_3_synthesis_d3.md)
  (Codex, 2026-11-10, reviewed tree `87bbf154`).

Verdict: **PASS**, with one note for the implementing cut.

## Checked and correct

- Scope: D3 only; D1, D2, D4-D7 and seed Section 4 stay open, and nothing in
  the synthesis depends on them. Nothing in `R/`, the store format or a
  registered test changes at acceptance.
- The decision answers Cut 13 R3 as routed by the maintainer: no store write
  while pulses run, logical acceptance and commitment stay per pulse against
  the loop's own records, and bounded batches write the committed prefix
  after the loop inside the fold transaction. It keeps pulse-plumbing R9 and
  the Section 5 prefix protocol instead of replacing them, so the P5
  capacity refusal keeps its pulse, stage and class.
- `checkpoint_every`: the pinned default is `10000L` with a
  `control$checkpoint_every` override (`R/backtest-config.R:93,164-169,188-193`
  at `d5b3a151`); LR-20 already records the maintainer's 2026-11-06
  retirement (`lean_core_rules_ledger.md:39`). The dev adapter refusing a
  non-default value before the switch is consistent with that.
- Capacity: the detector is `R/fold-event-buffer.R:15-19`, called from the
  durable P5 flush (`R/output-handler.R:571-577`) and every memory append
  (`:699-705`); LR-19 (`lean_core_rules_ledger.md:38`) is the accepted
  cumulative fill-only rule.
- Transactions: the memory sink's `run_transaction` is `fn()`
  (`R/output-handler.R:690`), so discarding a failed candidate's handler,
  not SQL rollback, is the correct statement; the durable error path is
  `R/fold-engine.R:2057-2083`.
- Memory: no new ceiling, measured capacity and terminal peak per cut, and
  the 1 MiB preparation waiver correctly not extended.
- The supersession quotes match the pulse-plumbing synthesis text; the
  installation edits are complete for P, the interface Section 19, the RFC
  README and `decisions.md`.

## Note for the implementing cut

Slice 1's parity oracle is the pin, which still counts every memory-sink row
against `max(1, pulses x instruments)` (pre-LR-19). Slice 1 has at most one
fill per instrument per pulse, so the difference can appear only on a
memory-sink run in which almost every instrument fills on every pulse. If a
slice-1 workload reaches it, record it as the LR-19 difference in the parity
evidence; do not change the oracle.
