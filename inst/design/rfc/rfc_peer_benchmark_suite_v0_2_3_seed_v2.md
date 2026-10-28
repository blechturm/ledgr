# RFC Seed v2: Peer Benchmark Suite

**Status:** DRAFT, non-binding; Codex, 2026-10-28. No implementation cut,
contract amendment, publication or performance claim is authorized here.
**Owner:** v0.2.3 macro plan WS3, inventory X4;
[benchmark-methodology](README.md#benchmark-methodology).
**Cycle:** [v1](rfc_peer_benchmark_suite_v0_2_3_seed.md),
[Claude response](rfc_peer_benchmark_suite_v0_2_3_response.md),
[response review](rfc_peer_benchmark_suite_v0_2_3_response_review.md).
Next: maintainer disposition of Section 11, then synthesis by Claude.
**Authority inputs:** accepted [macro plan](../ledgr_v0_2_3_spec_packet/macro_plan.md)
revision 2 WS3/WS4; [roadmap](../ledgr_roadmap.md), Current planning release;
[horizon suite decisions](../horizon.md#2026-10-01-benchmark-a-suite-of-peer-workloads-not-one);
[benchmark manual](../manual/benchmark_methodology.qmd);
[spike protocol](../spike_protocol.md); accepted strategy-authoring synthesis.
Historical benchmark records remain evidence, not new parity claims.

## 1. Purpose and fixed scope

One suite supplies a C1 deletion oracle, fair peer comparisons, a scaling
cost map, familiar strategy examples and an externally shareable Quarto
report. It demonstrates results agreement and tests the speed hypothesis.
Readability comes first in the report and authoring lane.
Fixed: five lanes; quantstrat, PMwR, backtrader, bt, zipline-reloaded and
PyBroker v2; the full suite stays in this release. Each peer enters where
informative, without a Cartesian product. TradeStation/Pine/AmiBroker are
non-executed authoring references only; vectorbt and LEAN remain excluded.
Dense parity and current-tree timing precede C1, independently of WS1.
The full suite reruns after WS4 and WS8. No new execution engine, mode branch,
identity registry or private-data publication is authorized.
“Same results” always names its tested rules, peers and agreement level.

## 2. Executed evidence and limits

The [seed probe](../../../dev/spikes/peer_suite_seed/probe_findings.md)
produced 22 native fills; mutating one fill left the old equity-only parity
label unchanged. That label cannot protect deletion or establish trade parity.
The [response probe](../../../dev/spikes/peer_suite_response/probe_findings.md),
12 instruments by 90 sessions, was independently rerun for this revision:
all recorded CSVs reproduced and its gutted rule was detected.

| Executed observation | What the specification may consume |
| --- | --- |
| Data-start opening: 121 fills on both current paths agree by recording pulse, instrument, side, quantity, price and fee; execution stamps differ | Distinguish economic comparison from explicitly reviewed stamp representation. |
| Diagnostics: 0 dense, 1,291 fact-bearing rows | Do not assert whole-table equality across these two representations. |
| Session-30 opening: 87 dense versus 89 availability fills | History-start differences need an explicit disposition, not a numerical tolerance. |
| Six first-usable entries; first-state/transition-only timelines have 121/115 decisions | State the crossover's entry convention before comparing peers. |
| Native ledger-derived holdings reproduce position value within 2.1e-8 | Holdings are recoverable without a benchmark accounting engine. |

These are current-path observations, not proof of future C1 behavior,
peer equivalence, timing or memory. The accepted history-start distinction
is in [Scoring And Feature Start](../contracts.md#contract-execution-window-start).
The response did not execute peers; its proposed native adaptations require
qualification. The old unexplained trade gaps remain unexplained.

## 3. Lanes and native qualification

| Lane | Required purpose and initial assignment |
| --- | --- |
| Dense conventional | SMA crossover, momentum/filter, mean reversion and one recursive/TTR rule. Qualify next-open unit-quantity rows for backtrader, quantstrat, PMwR and PyBroker; retain existing zipline evidence with its actual execution rule. |
| Scaling | Same qualified rule and outputs across the four decided shape anchors plus narrow/long minute-labelled geometry. Choose peers per shape, before timing. |
| Whole-universe portfolio | First required new pair: ledgr/PyBroker top-N rotation, shared ranking/ties/cadence and affordable next-bar quantities. Other peers enter only after qualification. |
| Point-in-time demonstration | Public synthetic membership/listing/delisting; causal versus explicitly labelled survivor counterfactual. Show decisions/outcomes; never speed- or parity-rank it. |
| Authoring | Same readable paragraphs idiomatically across all six peers; build on the seven-rule bt/PMwR comparison and accepted ledgr grammar. Include setup and conceptual indirections. |

Before a row is timed, run its smallest native correctness example using
official documented public APIs and cite the pinned documentation/source.
Initial adapter hypotheses: quantstrat explicit open preference, PMwR OHLC
inputs and PyBroker explicit open fill; backtrader next-open market orders.
Do not treat these as measured parity. Existing daily zipline and bt workflows
may supply decision-only agreement; verify the precise pinned workflow before
declaring a limitation. No adapter-owned fills, funding or accounting.
A different native execution contract gets a separate labelled row; it
cannot acquire next-open parity through timestamp relabelling.
A meaningful completed native row for every selected peer is required for
suite completion; authoring execution counts as informative work, not proof
of matching balances. Every peer named in a numeric agreement claim needs
its own executed trade/balance-equivalent row. Unavailable remains incomplete.
Provision all six peers reproducibly: isolated pinned R libraries and Python
environments, public setup commands and environment sidecars; no dependence
on a vanished temporary library. Choose environment separation from tested
dependency compatibility, not version-range speculation.

## 4. Workload contracts and the crossover

Each assigned row declares bars/facts, UTC keys and authoritative sessions;
indicator definition, warmup and missingness; rule paragraph, tie order and
schedule; initial cash/holdings, quantity units, sizing price, costs and risk;
signal knowledge time, execution time/price and final-pulse behavior; required
outputs and comparison window. Calendar mappings are explicit and independently
validated; never silently zip two differently dated row sequences.
Use ample capital and fixed unit quantities for initial dense comparisons.
Cost/risk witnesses are controlled additions, not a full cross-product.
For portfolio rows bound prices/gaps and requests so buys are affordable even
without same-pulse sale proceeds. Otherwise classify a policy comparison.

Proposed new peer SMA rule: enter one share only when two consecutive usable
scores show fast moving from at/below slow to above; exit on the reverse
transition to at/below. No transition is inferred from an unknown prior score.
Freeze indicator values and decision timelines before price comparisons.
Keep the historical first-state recipe unchanged as a separate C1 witness.
Do not rewrite an existing deletion oracle to make the new recipe its history.
Top-N pins ties by an explicit deterministic ID order; observe and resolve
PyBroker's native tie behavior before accepting its adapter. Missing scores
and unbuyable candidates have declared policies, not implicit omission.

## 5. Internal deletion: preserve the native evidence

Reuse the completed A0 freeze and canonical writer where applicable; keep its
fixtures, full tables and scope intact. Add only genuinely missing dense
witnesses before deletion. Retain the v0.2.2 real-data reference separately.
Unchanged-meaning fields compare losslessly and exactly, including quantity,
price, fee, cash, equity, asset holdings and applicable state/terminal facts.
Preserve full native output, source/config identities and event order.
Economic projection may omit only declared non-economic identity fields;
this does not delete them from provenance or relax an existing A0 check.
Do not replace complete deletion evidence with compact report summaries.

For each witness declare economic keys, including decision/recording pulse,
instrument and within-pulse event order, plus all economic payload fields.
Check key uniqueness and preserve multiple fills; sorting or deduplication
must not conceal a changed execution sequence.
Execution timestamps and diagnostics remain checked. If C1 intends a new
representation, its cut specifies the exact mapping/expected trace and reason,
with independent checks of execution session, available price and event order.
A timestamp affecting entitlements or order timing is an economic change.
The probe does not decide C1's implied calendar or authorize stamp changes.

Keep a late-opening witness: the accepted availability history rule explains
why a difference may arise, but cannot silently exempt the row. WS4 records
its expected changed meaning and evidence before accepting deletion.
All unlisted differences fail closed. The macro gate remains “unchanged,
or each difference decided”; a failure never regenerates the old oracle.
API generations, precision and economics cuts declare their own changed fields
and receiving contracts; preserve earlier evidence instead of adding legacy
readers. C1 cannot drop a currently runnable shape or compiled diagnostic as
a neutral unavailable row: changed capability needs maintainer disposition.

## 6. Cross-peer agreement and attribution

Two plain-language labels, with disjoint headline counts:
- **Same decisions only:** common score/mask/selection and target-intent
  timelines agree, but execution or balances do not qualify as equivalent.
- **Same trades and balances:** decisions plus execution session, holdings,
  fills, fees, cash and equity satisfy the declared field contract.
Rows that qualify fully are not also counted in the “only” category.
Other statuses: classified residual, unsupported, unavailable, failed,
not run/censored. A classified difference is not an agreement pass.
Only “same trades and balances” rows enter comparable runtime ratios.

Axes, NA masks, discrete decisions and quantities are exact where common.
Before peer runs, fix numeric tolerances separately by field, units and
arithmetic/rounding justification. Use absolute plus relative bounds with
explicit zero/NA/Inf handling; cumulative balances need a justified error
budget. Do not derive every threshold from ledgr-versus-sweep equity spread.
No blanket percentage of capital, no tolerance for a different trade, and
no widening after a failing result. Unresolved numeric calibration blocks
that equivalence claim, not all other informative rows.
Locate the first divergence in scores/masks, then decisions, then fills and
balances, keyed by instrument/time. Warmup exclusions are declared prefixes;
no dropping interior rows. Attribute ledgr/peer/harness causes using evidence.
Retire the old tier label and unexplained “position size” fallthrough for new
claims; reuse exact comparators only after inspecting their field coverage.

## 7. Public lifecycle, clocks and memory

Proposed headline ledgr surface: `ledgr_run()`. Each ranked engine's warm
clock ends with required fills, equity, cash and asset holdings materialized
through public outputs in memory or on disk. Native ledger extraction may
derive holdings; its required materialization belongs inside the clock.
Match output scope, not persistence technology. Minimal-retention sweep and
PyBroker rows are separate workflow diagnostics, never headline substitutes.

Report cold public end-to-end, warm public iteration (primary), engine-only
diagnostics and amortized sessions separately. Cold includes import/native
preparation/first-use compilation through required results; disclose launch
and IO boundaries. Warm retains only safely reusable public preparation and
includes new experiment setup, execution and result materialization.
Qualify each engine's reuse boundary and independent-book reset by execution:
sealed snapshot; reusable frames/matrices/xts with rebuilt native backtests;
zipline ingestion versus run; PyBroker public caches and JIT lifecycle.
These are proposed boundaries, not permission for private lifecycle bypasses.
Data/fact changes invalidate preparation reuse. Warm JIT requires actual
warming in the measured process; a fresh process alone is not warm.
Unavailable phase clocks are unavailable, not zero. Record native preparation,
indicators, orchestration, engine/results and callback counts, using a separate
validation pass if counting perturbs timing.

Use isolated per-engine measurement processes; counterbalance engine order
and alternate before/after trees. Proposed ordinary rows: five measured
repetitions, warmup declared, median/min/max shown; no favourable rerun picking.
Each warm sample may prepare/warm its own process outside its clock.
Use High performance plan and inherited P-core affinity on the registered
host, record threads/background load, versions, retention and JIT state.
Reuse the existing timing protocol/checker where it fits these boundaries.
Sample each row's full child tree, including workers/daemons: cold preparation
and warm execution peaks plus retained baseline, working set and private bytes,
sampling interval and shared-page limitations. No combined multi-peer peak;
no summing working sets and calling it unique physical memory.

## 8. Geometry and resource proposals

Retain 10 by about 7,200, 500 by 1,260, 1,166 by 252 and separately budgeted
1,166 by about 7,200 instrument/bar anchors. Label daily long history apart
from minute-labelled geometry. Reuse public simulators and minimal explicit
transformations; author missing generation behavior only when necessary.
Proposed narrow/long row: 20 instruments, 60 synthetic sessions, exactly
390 minute-end labels 14:31 through 21:00 UTC: 23,400 pulses, 468,000 bars.
This tests geometry, not exchange-calendar or intraday product support.
Qualify supported peers before timing; no new mode branch to rescue a row.
A currently supported shape that C1 loses routes through Section 5.

Proposed limits: ordinary measurement attempts 20 minutes; stress 120 minutes
and 16 GiB private commit per engine tree. Stress is one descriptive repeat,
not a precise speed ranking. Predeclare a total host budget in each lane cut.
Measure sessions of 10/100/1,000 independent or varied public candidates
where feasible within that budget; otherwise report censored/not measured.
Arithmetic projections remain clearly labelled and never replace a feasible
measurement or appear as measured batch speed. Do not skip slow rows quietly.

## 9. Quarto report and durable evidence

Deliver `dev/bench/peer_benchmark/peer_suite.qmd` and portable self-contained
`peer_suite.html`; preserve old reports. Render a mandatory explicit accepted
record (`-P record:<id>`, `embed-resources: true`), never latest-file fallback.
Rendering reads evidence only: no benchmarking, dependency installs or network.
Commit compact report inputs under `records/<id>/`: predeclared assignments,
agreement/status and decisive residuals, timing repeats, memory phases,
environment, pinned dependencies and source/native identity. Use ordinary
record files and Git, not a parallel hash ledger. Keep complete deletion
tables separately reviewable/reproducible; private or bulky traces stay off
the main report path, never as a substitute for the oracle.

First screen: agreement coverage per peer, absolute warm runtimes and ratios
with repeat spread, compact memory, scope/versions/date/record identity.
Denominator is every predeclared required assignment for that peer, including
not-run/unavailable rows; also show attempted count. Distinguish both agreement
labels and missing/non-equivalent outcomes without one misleading pass score.
Predeclare a small headline set and required assignments before seeing times;
sort by workload, show slower ledgr rows equally, keep the full comparable
table close, and never pool mismatched sets into a universal speedup.
Short caveats cover cold/session cost, JIT, retention and execution differences.
Expandable methods hold phase tables, residuals, reproducible commands and
environments; a few readable strategy examples link to full source.
Figures/claims derive from the chosen evidence. Incomplete renders say
preliminary. External claim readiness requires the complete accepted suite
and reproducible render; matching decisions alone is never “same results”.
Missing peers cannot disappear from the scope or silently unblock completion.

## 10. Delivery, generations and budgets

Dense oracle and current-tree timing first, before C1; coordinate with A0
rather than duplicate its freeze. Remaining lanes proceed alongside release
work; full suite repeats after WS4 and WS8 with generations/differences named.
Current ledgr recipes use supported alias-aware `ctx$vec$feature()`; WS5
counterparts use accepted flat ctx. Retain source identities per generation
and prove unchanged economics; do not revive retired readers.
Authoring counts names, containers, registrations/shared stores/storage details
plus code/setup, using idiomatic documented workflows and maintainer cold reads.
The pattern article does not wait for all six environments.

Each bounded implementation cut has runner, scratch diff checker, gut and
inventory; initial dense work at most four rule families/ten detectors.
Later lanes require their own accepted scope/budget, not automatic per-file
budget resets. Stop and recharter at the protocol limits. Reuse A0
canonicalization, timing machinery and adapter/runtime pieces before new code.
No new benchmark execution engine or research-specific provenance subsystem.
The complete accepted suite gates external claims; internal baselines remain
useful before it is complete. This RFC changes no shipped semantics.

## 11. Proposed disposition and remaining authority

For acceptance: the new transition-only peer recipe (historical witness kept),
two agreement labels, full-run comparable-output headline and report contract.
No advance decision is needed to draft these proposals; they are not yet binding.
C1 implied-calendar/stamp/diagnostic changes and late-opening behavior must be
specified and decided in WS4 under the existing macro gate, with these probes
as evidence. This seed does not pre-accept them or change execution contracts.
Peer qualification, numeric tolerances, exact assignments, resource totals and
reproducible provisioning are bounded spec-cut obligations, not assumed passes.
Fixed peers/scope and unavailable-peer completion policy are not reopened.
Response-review dispositions F1-F11 preserve the rejected reasoning; v1 and
the response remain the disagreement record. After maintainer disposition,
Claude synthesizes; final review follows before implementation authority.
