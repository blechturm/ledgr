# Batch 12 Dense Timestamp Validation Evidence

Status: accepted after independent Stage M review and maintainer approval.

- Source base: `9414a5b214970cc22ca987aead4fad48b38af354` plus the uncommitted Batch 12 candidate.
- Fixture SHA-256: `0b183457b3fe720d63b02a90fe552e1202fdb31b4e967a75e91304f9d3e416fc`.
- Environment: R 4.6.1; ledgr 0.2.0.1; duckdb 1.5.2; collapse 2.1.8.
- Clock: complete public `ledgr_sweep()` workflow with snapshot preparation separated; validator timing is observed inside that call.
- Peak working set: external Windows process sampling every 200 ms; runs were serial with no intentional concurrent benchmark workload.

The first record attempt completed its measurements but stopped before
persisting evidence because the harness compared the random per-run
`sweep_id`. A small current/candidate smoke pair proved the corrected
comparison, and the complete 16-run protocol was then repeated from scratch.
That clean repetition excluded `sweep_id` and also omitted `candidate_row`
from returns while comparing it for trades. Independent review found the
asymmetry. It cannot mask a difference in this one-candidate protocol because
`candidate_row` is fixed at `1L` in every run. The retained harness now
compares it for both surfaces; the recorded timings did not require a rerun.
The results below come only from the clean full repetition.

## Gate Results

### canonical

- Validator median: 14.7800 s current, 0.0200 s candidate; ratio 0.0014 (limit 0.10).
- Public warm median: 48.31 s current, 34.11 s candidate; improvement 14.20 s versus 0.29 s current spread.
- Maximum peak working set: 852.9 MiB current, 949.7 MiB candidate; ratio 1.114 (limit 1.15).
- Gate disposition: `PASS`.

### compiled

- Validator median: 14.6400 s current, 0.0100 s candidate; ratio 0.0007 (limit 0.10).
- Public warm median: 32.28 s current, 17.43 s candidate; improvement 14.85 s versus 0.33 s current spread.
- Maximum peak working set: 931.7 MiB current, 947.7 MiB candidate; ratio 1.017 (limit 1.15).
- Gate disposition: `PASS`.

## Semantic And Structural Results

Current and candidate public returns, realized trades, status, and metrics were exact within each accounting engine across every run.
Canonical-versus-compiled public returns passed the existing `1e-8` floating tolerance and realized trades remained exact in both arms.
The focused suite covers the complete direct semantic/failure matrix, public sweep, precompute, walk-forward, and the availability bypass.
Its structural gate observes one vector-key call per axis, zero calls to the scalar formatter, rejects forbidden source tokens, and fails against a deliberate `vapply()` scalar-format mutant.

The scalar production path is removed. No option, arm stamp, fallback, alternate public method, schema, identity, or availability behavior is introduced. This is Stage M evidence, not the final Stage O record.
