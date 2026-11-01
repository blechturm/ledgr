# Cut 6 evidence reconciliation

Role: pre-acceptance input check for Cut 6 / macro WS4b.
Base: `release/v0.2.3` at `b5622f09`.
Date: 2026-11-01.

## Necessity judgment

No new execution is required before accepting the cut. The questions Cut 6
decides have already been measured by accepted spikes, frozen oracles and
registered tests. Re-running those workloads would reproduce evidence rather
than answer an unknown question, contrary to macro rule 10 and the repository
complexity gate.

This reconciliation identifies the existing evidence and separates it from
candidate verification. Exact candidate differences, deletion witnesses,
real-data parity and milestone timing remain acceptance work for LDG-3170
through LDG-3178; they cannot be measured before a candidate exists.

## Evidence map

| Cut 6 rule | Existing evidence | What it establishes | Candidate owner |
| --- | --- | --- | --- |
| Bar-native fixed-basket clock and next-pulse timestamp | `dev/spikes/one_execution_mode/probe_findings.md`, peer and long-window rows | Economic values match while the current session path changes only execution timestamps; no declared session can reproduce a midnight bar without inventing a clock | LDG-3171, LDG-3172 |
| Strict rectangular fixed-basket coverage | Same spike, `gap_held`, `gap_held_default`, `gap_free`, `gap_exec` | The dense guard refuses every missing requested bar; availability policies intentionally behave differently | LDG-3171 |
| One canonical execution semantics (Option B) | Same spike; `dev/bench/peer_benchmark/dense/inventory.md`; contracts and registered claims cited in `cut_review_6.md` | Dense and availability differ in history start, carry, affordability, shorts, evidence, corporate-action failure, feature engine, context, equity source and non-finite valuation; these are real rather than hypothetical differences | LDG-3172-LDG-3174 |
| History from data start | Dense oracle `historical_start_dense` and `historical_start_facts`; LCL-0298/LCL-0300 | Both current rules and their first divergence are frozen | LDG-3172 |
| Continuous walk-forward carry | `dev/bench/v0_2_3_output_freeze/records/walk_forward/`; `contract-execution-walk-forward-folds` | Current memory, durable and carried-fold evidence is frozen | LDG-3172 |
| Affordability and supported-target boundary | Registered availability affordability and target tests cited by the first cut review; `contract-availability-affordability` and `contract-availability-targets` | Overspending rejection and new/enlarged-short refusal already have failure-sensitive tests | LDG-3173, LDG-3174 |
| Common decision, reconciliation, completion and state evidence | A0 records and `closeout.md`; dense oracle diagnostic counts | Current absence/presence and memory-retention boundaries are frozen | LDG-3174 |
| Corporate-action typed stop | A0 `dense_dividend_state`, `avail_terminal_resume`, failure records; Cut 5 cases | Corporate-action economics and stop boundaries are independently frozen | LDG-3174 |
| Segmented feature engine and preparation cost | One-execution-mode TTR and built-in arms; Cut 5 feature-carrier cases | The semantic difference and the old strict-TTR hotspot are known. Its post-unification cost is a candidate measurement, not a design prerequisite | LDG-3172, LDG-3177, LDG-3178 |
| Common strategy context; remove `ctx$availability_active` | Registered context/helper tests and source census cited by the focused review | The field and all helper branches are enumerable; under Option B it is constant and therefore removed | LDG-3173 |
| Fold equity and non-finite valuation | Cut 5 C16/D10 and `dev/bench/v0_2_3_ws4a/records/ldg3169/`; `amendment_valuation` | Equity ownership and the exact non-finite refusal point are accepted evidence | LDG-3174, LDG-3177 |
| Final-pulse structured non-execution | Dense oracle `cost_final`; one-execution-mode peer row; A0 conditions and diagnostics | Current warning, final target and diagnostic behavior is frozen | LDG-3174 |
| Remove `ledgr_backtest()` constructor | Public/export/source census in the first review; result-class contract and registered result tests | Constructor and result-handle responsibilities are separable; no behavioral experiment is required | LDG-3175 |
| Delete dense branches | LTB-0331 source census, Cut 5 D12d/D13, dense oracle and A0 | The current branch surface and deletion detectors already exist | LDG-3170, LDG-3176 |
| Identity rule 5 and old-store refusal | Cut 4 identity pattern; Cut 5 `identity.csv`; `R/store-gate.R` binding census | Changing the rule changes the store fingerprint while snapshot content identity remains unchanged | LDG-3174 |
| Performance milestone | One-execution-mode clocks; WS4a timing records; current peer-suite records and shared harness | Existing costs and baselines are known. Only the finished unified candidate can answer the milestone question | LDG-3178 |

## Gaps disposition

The one-execution-mode spike lists routes and edges it did not execute:
sweep and walk-forward entry points, the old constructor, corporate-action
snapshots, unpriced rebalance members, irregular/intraday bars and richer
final-pulse targets. None is an unresolved design input now:

- the entry routes and constructor are enumerable ownership questions;
- corporate actions, unpriced holdings and walk-forward carry have independent
  accepted controls;
- irregular and same-date pulses are explicit LDG-3171 fixtures;
- the final-pulse matrix is an LDG-3174 detecting test.

Those witnesses must fail on a wrong implementation, but running them before
that implementation exists would not validate the cut.

## Result

The Cut 6 inputs are adequate. No existing evidence is copied or regenerated.
No new manifest, harness or frozen intermediate is introduced. The accepted
evidence remains immutable at its source, and each candidate-only question has
one ticket owner.

This reconciliation closes the pre-acceptance evidence gate. A product change
to the base after `b5622f09` invalidates this conclusion and requires a focused
input-delta check, not an automatic replay of every workload.
