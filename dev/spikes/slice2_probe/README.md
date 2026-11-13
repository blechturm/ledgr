# Slice-2 probe (Cut 16 input, 2026-11-13)

A probe, not product code: does the lean loop reproduce the pin for costs,
the risk chain and the sizing helpers with small changes? Nothing in
`dev/lean_core/` was changed by it; Cut 16 builds slice 2 properly.

`probe.patch` is the probe's final diff against 21e89c27 (`dev/lean_core/loop.R`
and the probe workloads appended to `parity/loop_workloads.R`). The sizing
record in it grows by `c()`; Cut 16 replaces that with preallocated buffers.

Reproduce: a worktree at 21e89c27, `git apply` the patch, then
`loop_parity.R --lib=<pin library d5b3a151> --debug=0|1 --workloads=... --out=...`.

| File | Run | Result |
| --- | --- | --- |
| `a_debug1.csv` | refusals lifted and the pin's risk call, no sizing record, old implicit-row rule; ten p2 workloads, debug on | costs and risk identical; the sizing workloads differ in the diagnostics tables only; `p2_combo` fails closed (decoded coverage) |
| `b_debug1.csv` | implicit-row rule widened (LR-23), plus `p2_risk_bind`, `p2_sizing_risk`, `p2_hold_trim`; debug on | risk identical; sizing differs in diagnostics only |
| `c_oldpred.csv` | old rule restored for `p2_hold_trim` and `p2_risk_bind`; debug off | `p2_risk_bind` differs: LR-23's witness |
| `d_debug1.csv` | sizing record added; the four sizing workloads, debug on | identical |
| `e_debug0.csv` | final patch; 13 short p2 workloads, eight existing workloads (crossover_10x7200 included) and two 10 x 7,200 p2 workloads; debug off | 364 tables identical; whole collect 11.5 s (crossover), 11.5 s (cost chain), 11.6 s (chain and max_weight) |
| `f_gate0.csv` | final patch; the gate against `loop_freeze.csv` without `witness_error_cleanup_error` (47 of 48 workloads), debug off | 901 tables identical; PATH on `dense_cost` and `dense_risk_features` only (Cut 16 decision 4) |

The post-risk quantity recheck runs in production in the patch; Cut 16 makes
it debug-only (LR-16). Debug-on files belong to intermediate probe versions;
there is no final-patch debug-on record. Cut review 16 (R2) found that
`p2_hold_trim` makes no risk change, `p2_sizing_adjust` never liquidates the
instrument it exits, and `p2_risk_chain` stays below its cap; their names
overstate what they reach.
