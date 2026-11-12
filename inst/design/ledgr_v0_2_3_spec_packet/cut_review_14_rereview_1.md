CHANGES_REQUIRED
Mode: focused Type 2 re-review; independent fresh session.

Reviewed 9b47b8ed0dfd30c0d2dc5d4f0620d873b6804e96 and `git diff ff90fa3b 9b47b8ed`. References are relative to C:/Users/maxth/ledgr-wt/cut14-review; tickets.yml and macro_plan.md abbreviate inst/design/ledgr_v0_2_3_spec_packet/.

| First finding | Application and location |
| --- | --- |
| R1 | applied — tickets.yml:4632 |
| R2 | applied — tickets.yml:4633 |
| R3 | applied — tickets.yml:4634, tickets.yml:4635 |
| R4 | applied — tickets.yml:4658, tickets.yml:4659 |
| R5 | applied — tickets.yml:4652, tickets.yml:4661 |
| R6 | applied — tickets.yml:1608, tickets.yml:1623 |
| R7 | applied — tickets.yml:1672 |

All seven replacements retain their substance in the requested locations. None is reopened. The residual publication rule does not waive the below-10-percent acceptance gate (tickets.yml:4656, tickets.yml:4658). The production-only 900-line budget (tickets.yml:4636) excludes debug checks by the existing role count (tickets.yml:4607); it does not authorize weakening the frozen checks. No further conflict with macro WS16 or AGENTS.md was found. Neither finding below requires a maintainer design choice.

**N1 — required: define the strategy split's accounting and equivalence gate.**
Claim/evidence: tickets.yml:4660 does not define exclusive body time or validate its plain-list counterfactual. The actual body invokes context/state reads, hold() and ledgr_strategy_result() (dev/spikes/r_floor/fixture.R:15); state-patch validation runs in P5 (dev/lean_core/loop.R:755). Thus callback-inclusive time contains ledgr work, and the requested wrapper subtotal also reaches outside the callback. R4 requires exclusive accounting (tickets.yml:4658), but does not specify how this added split satisfies it.

Consequence: inclusive body and library timings can overlap; state validation can be counted in both P5 and the strategy subtotal. A plain-list benchmark using different pre-call state or warmed caches can pass without proving the requested comparison. Cross-shape differences alone do not isolate universe-size effects.

Exact replacement for tickets.yml:4660:

> For both arms on all four shapes, report inclusive strategy-body time, partitioned into exclusive strategy-owned work and ledgr callees (context/state reads, helpers and result construction); report outer call-wrapper/condition-handling time separately. Assign each cost once in the loop map; result checks remain in P2 and state-patch validation in P5. Any supplementary strategy-boundary subtotal references existing cells and is not added again. Reconcile body components and loop attribution to their stated totals, retaining residuals and sample counts. Separately benchmark the unchanged strategy on matched real-context and materialized plain-list inputs with identical features, holdings, pre-call state, parameters and helper results. Prepare inputs outside the clock, preserve fresh per-pulse cache behavior, byte-compile, warm and repeat both by the same method. Require identical complete returned targets and state updates before interpreting timings. Report us/pulse and us/pulse/instrument; label cross-shape growth descriptive. Missing cells, output mismatches or failed reconciliation fail this item; insufficient measurement resolution remains unresolved. Demonstrate rejection of a replay-output mismatch and a duplicated attribution cell.

**N2 — required: reconcile the cut summary with R2's retirement allowance.**
Claim/evidence: Cut 14 still requires all 23 variants to pass unchanged before and after (tickets.yml:1641), while the applied R2 permits documented retirement of an implementation-specific variant after shortcut deletion (tickets.yml:4633).

Consequence: a permitted retirement can still fail the cut-level requirement, encouraging retention of an obsolete shortcut or a meaningless mutant. Resolve the summary without changing R2.

Exact replacement for decision (1), tickets.yml:1641:

> (1) Restructure first, with no behaviour change: the frozen gate, batch-one and inert-hooks workloads retain their outputs and expected execution paths. Account for all 23 pre-cut variants under LDG-3220's variant acceptance: retained or retargeted variants demonstrate their intended faults; any implementation-specific retirement is explicit and preserves its contract witness, refusal oracle and modes.

Checked by read-only diff and source inspection; no R, timing window, full suite, parity run or vendor-data access. No tracked file edited; no commit made.
