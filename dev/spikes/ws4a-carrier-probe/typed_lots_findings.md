# WS4a typed R lots addendum

W/P = wide / partial-heavy; seconds unless stated. Additional measurements; original verdict unchanged.

| Arm | Sweep us/fill W/P | Lot core (+adapter) s W/P | Sweep Rprofmem GB W/P | Durable median/floor s W; P |
| --- | ---: | ---: | ---: | ---: |
| Canonical R + indexed | 50.50 / 51.20 | 1.78 (+0.00) / 1.82 (+0.00) | 7.46 / 7.52 | 12.71/7.67; 12.86/7.66 |
| Native + indexed | 24.81 / 23.54 | 0.10 repeat (+0.00) / 0.09 (+0.00) | 6.14 / 6.19 | 10.94/7.73; 11.00/7.81 |
| Typed R lots + indexed | 27.17 / 27.07 | 0.38 (+0.17) / 0.33 (+0.20) | 6.22 / 6.28 | 11.34/7.75; 11.09/7.61 |

| Lot-state column | Type | Axis | Unit | Invariant |
| --- | --- | --- | --- | --- |
| offset, capacity | integer | instrument | slot/count | Prefix offsets; allocated segments disjoint |
| head, tail | integer | instrument | relative slot | Live bounds in capacity; empty = 1/0 |
| lot_qty | double | allocated lot slot | signed units | FIFO authority; dead slots NA |
| lot_price | double | allocated lot slot | USD/unit | Live finite; dead slots NA |
| net_by_inst | double | instrument | units | Derived from lots; read once/pulse |
| cost_basis_by_inst | double | instrument | USD | Canonical FIFO basis and dust handling |
| total_cost_basis | double | scalar | USD | Canonical ordered old/new basis updates |
| realized_pnl, realized_comp | double | scalar | USD | Canonical Kahan event order |

Codex, 2026-10-30; R 4.6.1, archive `145cc93b`, addendum to `7d14ebe0`. Five alternating fresh-process own-floor/workload pairs; unchanged partial-warm boundaries. Wide has 67,725 fills; partial has 67,963, 49.6% reductions. Typed R is GREEN on both sweep shapes under the original <=40 us/fill plus strict-identity clause; RED remains >80 or required semantic change. Original 42.23 us/fill remains INCONCLUSIVE. The 75-line base-R kernel uses unnamed positional columns and copy-on-modify; FIFO depth and global cash/basis/Kahan updates retain canonical floating-point order. Adapters stay in marginal clocks. Typed sweep plan/lot/payload/event seconds W;P: 0.41/0.38/0.07/0.37; 0.46/0.33/0.08/0.43. Payload is separate for WS8; durable JSON stays exact. [Component rows](typed_components.csv) cover all arms/workflows; [allocation rows](typed_allocations.csv) report explicit-size cumulative Rprofmem bytes/pulse/fill (sweep only; not RSS/native malloc). [Clock rows](typed_arms.csv) include own floors; durable marginals do not determine verdicts. No-fill context/validation/remaining-decide seconds per 1,260 pulses W;P: 0.51/0.44/1.09; 0.39/0.30/0.90; [floor split](typed_floor_components.csv). Fresh checker byte-diffs ledger/JSON, equity, strategy state and final lots/cash/positions/P&L across nine original cases plus partial; LIFO, reorder and dropped-fee guts fail identity. Generated sweep_id excluded; product scope unchanged. [Host qualifications](typed_host.csv): 151 accepted, 0 excluded; external R CPU <0.5 s/run, IDs recorded. [Other host activity](typed_other_host.csv) records surviving-process CPU deltas; Task Manager and terminal were active. Native wide core: qualified [repeat](typed_component_repeat.csv) 0.10 s after a quantized 0.00; wall clocks unchanged. RFC input is bounded R cost and ordering, with no product/default decision. Reviewer: Max Thomasberger, independent review pending.
