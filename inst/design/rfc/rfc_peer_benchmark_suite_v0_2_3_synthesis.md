# Synthesis: Peer Benchmark Suite

Role: record; RFC-cycle synthesis and durable decision record.
Status: accepted
Authority: accepted synthesis; binds only its stated scope.
It authorizes no implementation cut,
contract amendment, peer installation, publication or performance claim.

**Status:** Accepted by the maintainer on 2026-10-28 after Claude's correction
round 1 and Codex's focused Type 1 final review PASS (round 2).
Written by Claude after Codex handed over seed v2 at the maintainer's request.
**Date:** 2026-10-28
**Author:** Claude
**Source baseline:** `07dbbc87` on `release/v0.2.3`. The response probe ran
on this commit and Codex reran it, with CSV diff and gut, before v2.
**Synthesizes:** [seed v2](rfc_peer_benchmark_suite_v0_2_3_seed_v2.md),
[response](rfc_peer_benchmark_suite_v0_2_3_response.md) and
[response review](rfc_peer_benchmark_suite_v0_2_3_response_review.md);
[seed v1](rfc_peer_benchmark_suite_v0_2_3_seed.md) is history.
**Owner:** v0.2.3 macro plan WS3, inventory X4; pipeline row
[benchmark-methodology](README.md#benchmark-methodology).
**Authority inputs:** accepted [macro plan](../ledgr_v0_2_3_spec_packet/macro_plan.md)
revision 2 WS3 and WS4 with its gate; [roadmap](../ledgr_roadmap.md) Current
planning release (peer set, lanes, publication rule);
[horizon suite entry](../horizon.md#2026-10-01-benchmark-a-suite-of-peer-workloads-not-one)
with its memory, parity and PyBroker addenda;
[Scoring and feature start](../contracts.md#contract-execution-window-start);
[benchmark manual](../manual/benchmark_methodology.qmd);
[spike protocol](../spike_protocol.md); accepted strategy-authoring synthesis
D1; [A0 closeout](../../../dev/bench/v0_2_3_output_freeze/closeout.md).
**Stages:** 2, 3, 4, 5, 7 ran; the maintainer approved proceeding from v2's
three proposals in place of a separate stage 6; 8 returned CHANGES_REQUIRED
(round 1), then PASS on focused re-review (round 2); 9 was recorded at
maintainer acceptance. Research input
was skipped because the horizon entry, its addenda and the historical record
supply the prior art. Seed "v1" and "v2" name artifact revisions; the suite
has no v1 milestone.
**Revision:** correction round 1, Claude, 2026-10-28, after the Codex Type 1
[final review](rfc_peer_benchmark_suite_v0_2_3_final_review.md) FR1-FR3;
Section 9 lists the patches and subsequent acceptance record.
**Accepted amendment:** [Amendment 1](#peer-suite-amendment-1) records the
maintainer's 2026-10-28 direction: fresh peer harness, independent A0 and
later retirement of the old peer driver. It supersedes the affected D11
construction guidance only; implementation still requires an accepted cut.

## 1. Decision

Accept seed v2's architecture as this cycle's agreement. Three proposals the
maintainer approved on 2026-10-28 are carried forward and not reopened:

1. Two disjoint agreement labels: same decisions only, and same trades and
   balances. Only the second enters comparable runtime ratios.
2. Headline timing on public `ledgr_run()` with fills, equity, cash and asset
   holdings materialized for every ranked engine; minimal-retention rows are
   separately labelled workflow diagnostics.
3. A transition-only crossover for the new peer recipe, with the historical
   first-state recipe retained unchanged as a separate C1 witness.

Fixed by prior authority, not by this synthesis: six executed peers, five
lanes, full release scope, dense oracle and current-tree timing before C1,
reruns after WS4 and WS8, an external-facing headline-first self-contained
Quarto artifact, and the rule that no public performance or comparative
memory claim precedes the complete accepted suite. No new execution-mode
branch, compatibility layer, benchmark engine, identity or provenance
registry.

The response's Type 2 challenge was right where v2 absorbed it: the old
equity-only label is not a deletion oracle, the recipe's entry rule was
undeclared, one "equivalent" count would misreport peers with a different
native execution contract, the headline ledgr row retained less than the
peers, and the report, provisioning, memory and generation gaps are real.
The synthesis sides with v2 and the review on the three places the response
overreached: C1 is not assumed to change every timestamp; the historical
oracle is not refrozen under a changed rule; and no single count or single
derived tolerance stands in for per-field, per-peer evidence (Section 7).

Choices made here, beyond v2: the economic projection's minimum keys and
payload are bound while each witness's exact field list stays with the cut
(D4); measurement counts and limits bind as defaults a lane cut changes only
with a recorded reason (D7, D9); the exact comparator is retained and the
tolerant equity helper is excluded from unchanged-meaning checks (D6); new
records do not extend the old parity-history registry (D10); and no
`decisions.md` row is created (Section 4). This synthesis changes no shipped semantics, no contract rule
group and no accepted decision.

## 2. Evidence and its limits

**Executed.** The seed probe (`dev/spikes/peer_suite_seed/`): 22 native
fills; one mutated fill left the old Tier 1 label unchanged, so that label
cannot protect deletion. The response probe
(`dev/spikes/peer_suite_response/`, 12 instruments by 90 sessions, source
`07dbbc87`, reproduced by Codex): at the data start both current paths agree
on 121 fills by recording pulse, instrument, side, quantity, price and fee,
while execution stamps differ (bar time versus session open) and diagnostics
differ (0 versus 1,291 rows); opening at session 30 gives 87 dense versus 89
availability fills; six of twelve instruments enter on the first usable score;
first-state and transition-only timelines have 121 and 115 decisions with a
first divergence at 2020-01-14T21:00Z; ledger-derived holdings reproduce
position value within 2.1e-8.

**Verified in source or documentation.** The old label reads equity only
(`dev/bench/peer_benchmark/peer_benchmark.R:1724-1727`) and the classifier
ends in an unexplained `position_size_differs` fallthrough (`:1856`); the
recipe reads `ctx$features_wide` and seeds no prior state (`:189`,
`:203-205`); the quantstrat adapter passes no `prefer` (`:863-864`); the
minimal sweep row writes `NA` cash and holdings (`:1095-1097`);
`peer_equity_parity()` (`:1159-1215`) compares its floating columns with
`all.equal` at a default `tolerance = 1e-8` (`:1160`, `:1183-1188`), and its
three harness call sites are ledgr-versus-ledgr equity surfaces (`:1244`,
`:1324`, `:1756`); `peer_exact_surface()` (`:1217-1224`) requires
`identical`; the phase clocks (`:245-340`) exist; the report falls back to
the latest status
file (`peer_benchmark.qmd:99-112`); the memory sampler sums `WorkingSet64`
over one process tree (`run_record.ps1:46-77`). The dense path reports a
final-bar no-fill as a warning (`R/fold-engine.R:112-124`, called at `:161`).
Fills carry `recording_pulse_ts_utc` (`R/backtest-fills.R:5`, `:19`);
`ledgr_state_reconstruct()`, `ledgr_sim_bars()` and `ledgr_sim_pit_inputs()`
are exported; simulated bars are weekday daily (`R/sim-bars.R:44`); top-N
ties break in C-locale instrument-ID order (`R/strategy-helpers.R:204-206`).
backtrader 1.9.78.123 and zipline-reloaded 3.1.1 are uv-pinned; the isolated
quantstrat library under `C:/tmp` is gone (`peer_benchmark/README.md:43`,
`:128`); no PMwR, bt or PyBroker provisioning exists in the repository. A0
froze eight workloads over sixteen handler paths with `config_json` and
`strategy_hash` embedded, re-recordable only on `20034e00`. The v0.2.2 record
shows backtrader at -238 and zipline at -682 trades over 1,250 diverging
bars, attributed 99.99% and 80% to "position size".

**Hypotheses, not executed.** Native next-open unit-quantity rows for
backtrader (next-open market orders), quantstrat (`prefer = "Open"`), PMwR
(OHLC price list) and PyBroker (`buy_delay = 1`, `PriceType.OPEN`); daily
zipline filling at the next close and bt at the current close; PyBroker's
tie order; any Python environment split. Each needs D5 qualification.

**Future implementation, not built.** The transition-only recipe, the
economic projection and representation checks, provisioning recipes, the
per-row memory sampler, `records/<id>/`, `peer_suite.qmd`, the minute
geometry, the portfolio row, the point-in-time demonstration and the
authoring articles.

**Limits.** Nothing above is C1 behavior, peer parity, timing or memory. The
probe compared today's dense and fact-bearing paths, not an implied-calendar
adapter. The historical trade gaps remain unattributed: six first-state
entries on a small fixture do not establish their cause. No peer was
installed or executed in this cycle, and no number in this synthesis is a
performance result.

## 3. Bound Design

### D1. Fixed scope and completion

Five lanes: dense conventional, scaling geometry, whole-universe portfolio,
point-in-time demonstration, authoring. Six executed peers: quantstrat, PMwR,
backtrader, bt, zipline-reloaded, PyBroker v2; TradeStation, Pine and
AmiBroker are non-executed authoring references; vectorbt and LEAN stay out.
Each peer enters the lanes where it is informative; no Cartesian product of
peers, lanes, costs and risks. The whole-universe portfolio lane's first
required row is one new ledgr/PyBroker pair: top-N rotation with a common
ranking, an explicit deterministic tie order, the same rebalance cadence,
affordable next-bar quantities and compared holdings; other peers enter that
lane only after D5 qualification and are optional for it. The dense oracle
and current-tree timing precede C1 independently of WS1 and are the suite's
only C1 prerequisite; the full suite reruns after WS4 and WS8. The suite is
complete only when every selected peer has a completed informative native
row; an unavailable peer leaves it incomplete and stays in every
denominator. "Same results" always names its tested rules, peers and
agreement level.

### D2. Two disjoint agreement labels

- **Same decisions only:** common score, mask, selection and target-intent
  timelines agree; execution or balances do not qualify as equivalent.
- **Same trades and balances:** decisions plus execution session, holdings,
  fills, fees, cash and equity satisfy the declared field contract.

A fully qualifying row is counted once, under the second label. Other
statuses: classified residual, unsupported, unavailable, failed, not run or
censored. A classified difference is never an agreement pass. Only
same-trades-and-balances rows enter comparable runtime ratios; decision-only
rows sit beside them with their named execution difference.

### D3. Workload contracts and the crossover

Each assigned row declares bars or facts, UTC keys and authoritative
sessions; indicator definition, warmup and missingness; rule paragraph, tie
order and schedule; initial cash and holdings, quantity units, sizing price,
costs and risk; signal knowledge time, execution time and price, final-pulse
behavior; required outputs and comparison window. Calendar mappings are
explicit and independently validated; differently dated row sequences are
never zipped positionally. Initial dense comparisons use ample capital and
fixed unit quantities; cost and risk witnesses are controlled additions.

The new peer SMA rule: enter one share only when two consecutive usable
scores show fast moving from at-or-below slow to above; exit on the reverse
transition; no transition is inferred from an unknown prior score. Indicator
values and decision timelines are frozen before any price comparison. The
historical first-state recipe stays unchanged as a separate C1 witness; no
existing deletion oracle is rewritten to make the new recipe its history.
Top-N rows pin ties by an explicit deterministic ID order (ledgr: C-locale
instrument-ID order); PyBroker's native tie behavior is observed and resolved
before its adapter is accepted. Missing scores and unbuyable candidates have
declared policies. Portfolio rows bound prices, gaps and requests so buys are
affordable without same-pulse sale proceeds; otherwise the row is classified a
policy comparison.

### D4. Internal deletion oracle: full native evidence, fail-closed differences

The dense parity lane freezes native outputs on a recorded commit before any
handler or engine change, reusing A0's canonicalization, fixtures, full
tables and checks where applicable and adding only genuinely missing dense
witnesses; the v0.2.2 real-data reference stays separate. Full native
tables, source and config identities and event order are preserved. Three
checks apply to every witness:

1. **Economic projection.** Declared keys, at least decision or recording
   pulse, instrument and within-pulse event order, with uniqueness checked
   and multiple fills preserved; and all economic payload fields, at least
   quantity, price, fee, cash, equity, asset holdings and applicable state
   or terminal facts, compared losslessly and exactly, by identity and never
   through a tolerant helper (D6). The projection omits only declared
   non-economic identity fields and omits nothing from stored provenance or
   an existing A0 check.
2. **Representation.** Execution stamps and diagnostics remain checked. A cut
   intending a new representation specifies the exact mapping, expected
   trace and reason before implementation, with independent checks of
   execution session, available price and event order. A stamp affecting
   entitlements or order timing is economic.
3. **Late-opening witness.** Kept. The accepted history-start rule explains
   why a difference may arise; it does not exempt the row. WS4 records the
   expected changed meaning and evidence before accepting deletion.

All unlisted differences fail closed. The gate is "unchanged, or each
difference decided"; a failure never regenerates the oracle. The probe decides
nothing about C1's implied calendar, stamps or diagnostics; WS4 owns each
decision. Losing a runnable shape or compiled diagnostic is a maintainer
disposition, not a neutral unavailable row. API-generation, precision and
economics cuts declare their own changed fields and receiving contracts.

### D5. Native qualification before timing

Before a row is timed, its smallest native correctness example runs through
official documented public APIs with pinned documentation or source cited.
The Section 2 adapter hypotheses are not parity. No adapter-owned fills,
funding or accounting; a different native execution contract gets its own
labelled row and cannot acquire next-open parity through timestamp
relabelling. Existing daily zipline and bt workflows may supply decision-only
agreement; a limitation is declared only after the precise pinned workflow is
verified. Every peer named in a numeric agreement claim has its own executed
trade/balance-equivalent row. All six peers are provisioned reproducibly from
the repository: isolated pinned R libraries and Python environments, public
setup commands, environment sidecars; environment separation follows tested
dependency compatibility, not version-range speculation. Each peer's recipe
lands with the lane cut that first executes that peer; the six recipes
together are a suite-completion obligation (Section 6), not a prerequisite of
the dense oracle, the current-tree baseline or WS4.

### D6. Numeric agreement and attribution

Axes, NA masks, discrete decisions, quantities and execution session are
exact where common. Before peer runs, the cut fixes numeric tolerances per
field with units and arithmetic or rounding justification: absolute plus
relative bounds, explicit zero, NA and Inf handling, a justified error budget
for cumulative balances. No blanket percentage of capital, no tolerance for a
different trade, no widening after a failing result; unresolved calibration
blocks that equivalence claim and nothing else. First divergence is located
in scores and masks, then decisions, then fills and balances, keyed by
instrument and time; warmup exclusions are declared prefixes. Causes are
attributed to ledgr, peer or harness with evidence. The old tier label and
the unexplained position-size fallthrough are retired for new claims.
`peer_exact_surface()` compares by `identical` and is reusable for exact
checks. `peer_equity_parity()` compares its floating columns with `all.equal`
at a default tolerance of 1e-8 (Section 2): it is tolerant, so it is excluded
from every unchanged-meaning deletion check under D4, which compares exactly,
and it supplies no per-field peer tolerance. It survives only for labelled
ledgr-versus-ledgr diagnostics outside the oracle; peer rows use the
field-specific checks fixed under this rule.

### D7. Headline lifecycle and clocks

The headline ledgr surface is public `ledgr_run()`. Each ranked engine's warm
clock ends when required fills, equity, cash and asset holdings exist through
public outputs, in memory or on disk; native ledger extraction may derive
holdings inside the clock. Output scope is matched, not persistence
technology. Four views are reported separately: cold public end-to-end
(import, native preparation and first-use compilation through required
results, launch and IO boundaries disclosed); warm public iteration (primary:
only safely reusable public preparation retained, with new experiment setup,
execution and materialization inside); engine-only diagnostics; amortized
sessions. Each engine's reuse boundary and independent-book reset is
qualified by execution; data or fact changes invalidate reuse; warm JIT needs
actual warming in the measured process; unavailable clocks are unavailable,
not zero. Isolated per-engine processes, counterbalanced engine order and
alternating before/after trees. Defaults: five measured repetitions, declared
warmup, median with min and max, no favourable rerun selection. The host
records High performance plan, inherited P-core affinity, threads, background
load, versions, retention and JIT state. The existing timing protocol and
checker (`benchmark_methodology.qmd:175-191`) are reused where they fit;
callback and phase counts use a separate validation pass if counting perturbs
timing.

### D8. Memory

Each row samples its own full child tree, workers and daemons included:
cold-preparation and warm-execution peaks plus the retained baseline, as
working set and private bytes, with sampling interval and shared-page limits
labelled. No combined multi-peer peak; no summed working sets presented as
unique physical memory. One sampler implementation replaces the tree-wide
sum; no per-adapter sampler.

### D9. Geometry and limits

Anchors: 10 by about 7,200; 500 by 1,260; 1,166 by 252; a separately budgeted
1,166 by about 7,200 stress row. Narrow and long: 20 instruments, 60 synthetic
sessions, exactly 390 minute-end labels 14:31 through 21:00 UTC (23,400
pulses, 468,000 bars), testing geometry only, not exchange calendars or
intraday product support. Daily long history is labelled apart from
minute-labelled geometry. Public simulators and minimal explicit
transformations come first; generation behavior is authored only when
necessary. Defaults: ordinary measurement attempts 20 minutes; stress 120
minutes and 16 GiB private commit per engine tree, one descriptive repeat and
no precise ranking. Each lane cut predeclares a total host budget. Sessions
of 10, 100 and 1,000 are measured where feasible, otherwise censored or not
measured; projections are labelled and never replace a feasible measurement
or appear as measured batch speed. No quiet skipping; no mode branch to
rescue a row; a shape C1 loses routes through D4.

### D10. Report and records

`dev/bench/peer_benchmark/peer_suite.qmd` renders a portable self-contained
`peer_suite.html` from one explicit accepted record (`-P record:<id>`,
`embed-resources: true`); no latest-file fallback; old reports are preserved.
Rendering reads evidence only: no benchmarking, installs or network. Compact
inputs are committed under `records/<id>/`: predeclared assignments,
agreement and status with decisive residuals, timing repeats, memory phases,
environment, pinned dependencies and source/native identity, as ordinary files
in Git. No parallel hash ledger; new records do not extend the old
`parity_history/` registry, which remains historical evidence. Complete
deletion tables stay separately reviewable and reproducible; bulky or private
traces stay off the main path and never substitute for the oracle.

First screen: agreement coverage per peer over every predeclared required
assignment, attempted count shown too, both labels and missing or
non-equivalent outcomes visible without one pass score; absolute warm runtimes
and ratios with repeat spread; compact memory; scope, versions, date and record
identity. The headline set and required assignments are predeclared before any
time is seen; rows sort by workload, slower ledgr rows show equally, the full
comparable table sits adjacent, and no mismatched sets pool into a universal
speedup. Short caveats cover cold and session cost, JIT, retention and
execution differences; expandable methods hold phase tables, residuals,
commands, environments and linked strategy examples. Incomplete renders say
preliminary. External claim readiness requires the complete accepted suite
and a reproducible render; matching decisions alone is never "same results";
missing peers never disappear from scope.

### D11. Delivery, generations and budgets

Construction and retirement guidance is amended by
[Amendment 1](#peer-suite-amendment-1); other D11 obligations remain intact.

Dense oracle and current-tree timing come first, coordinated with A0 rather
than duplicating its freeze; they are the whole of WS3's C1 prerequisite
(macro plan Section 2, `WS3 dense lane -> WS4`). The dense lane's peer rows,
the remaining lanes, peer provisioning and the report proceed alongside
release work and are not part of that prerequisite; full reruns after WS4
and WS8 name generations and differences. Current
recipes use alias-aware `ctx$vec$feature()`; WS5 counterparts use the
accepted flat `ctx`; the old recipe's `ctx$features_wide` is a generation
label, not an accessor to revive. Source identities are retained per
generation with unchanged economics proven; no retired reader returns.
Authoring counts names, containers, registrations, shared stores and storage
details plus code and setup, with idiomatic documented workflows and
maintainer cold reads; the pattern article does not wait for all six
environments. Each bounded cut has a runner, scratch diff checker, gut and
inventory under the spike-protocol budgets; initial dense work is at most
four rule families and ten detectors; later lanes need their own accepted
scope and budget, never an automatic reset. Reuse A0 canonicalization, the
timing machinery and the adapters' output shape and uv runtime after
checking fit. No new benchmark execution engine, mode branch, compatibility
layer or research-specific provenance subsystem.

## 4. Contract and accepted-decision impacts

- **`contracts.md`:** none. No rule group is added, amended or consolidated.
  History start (`contract-execution-window-start`) is consumed to classify
  the late-opening witness and is not reopened.
- **Accepted decisions:** none changed. Consumed unchanged: macro plan WS3's
  route (RFC, then direct tickets per lane) and WS4's gate; the A0 freeze,
  whose fixtures, tables, scope and checks stay intact; strategy-authoring
  D1 for the WS5 generation; the horizon suite decisions on lanes, peers,
  shapes, timing views and memory; the roadmap publication rule.
- **`decisions.md`:** no bridge row. Nothing here awaits contract
  consolidation; the rules bind benchmark evidence, not shipped behavior.
  The pipeline row is the home of the obligations.
- **Pipeline row:** `benchmark-methodology` is recorded as Obligations open,
  with this synthesis as source and the WS3 lane cuts as route; the horizon
  entry points here (documentation chore).
- **Benchmark manual:** unchanged now. The first lane cut that lands new
  clocks or labels updates it under review, because it defines claims and
  clocks.
- **Release definition of done:** already requires the dense parity lane,
  A0 and the v0.2.2 reference reproduced or decided, and the full suite timed
  after the consolidations. The per-peer completed-native-row item is
  registered in the packet's `tickets.yml` with an owner when the dense lane
  is cut, as a release-gate item rather than a dense-oracle deliverable.

## 5. Open questions promoted to the bounded cuts

Each item binds its D-rule constraint and any default; the owner resolves it
at ticket cut, not by a new RFC.

- **Dense lane cut, C1 prerequisite (before WS4):** exactly the dense oracle
  and ledgr's baseline timing on the current tree; WS4 waits for nothing else
  from this suite (D1, D11). The exact economic key and payload list per
  witness, including the event-order key (D4 minimum); the rule families and
  detectors within four and ten: the new transition-only SMA, the historical
  first-state witness, momentum/filter, mean reversion, one recursive TTR
  case, cost and risk witnesses, final-pulse no-fill and warmup rows, the
  late-opening witness, internal calendar and missing-bar rows; exact
  comparison for ledgr-versus-ledgr, never through `peer_equity_parity()`
  (D6); the freeze commit and generation label (D11); ledgr's reuse boundary
  and reset qualified by execution, repetitions (default five), per-row limit
  (default 20 minutes) and host budget on the public `ledgr_run()` clocks, so
  the reruns after WS4 and WS8 compare like with like (D7); whether the
  existing timing protocol and checker fit or need adaptation.
- **Dense lane cut, assigned peer comparisons (same lane; sequenced by
  `tickets.yml`; not part of the WS4 prerequisite):** native qualification of
  the backtrader, quantstrat, PMwR and PyBroker next-open rows, and the
  retained zipline evidence with its actual execution rule, its pinned
  workflow verified before any limitation is declared (D5); the recipes for
  the peers this lane executes, with environment separation from tested
  compatibility (D5); per-field tolerances with justification for those peer
  rows (D6); peer reuse boundaries and resets qualified by execution, and
  engine-order counterbalancing (D7); the one child-tree sampler (D8). The
  pinned bt workflow is verified by the lane cut that first uses it (D5).
- **Scaling lane cut:** peers per shape, chosen before timing; minute-geometry
  generation by public simulators and minimal transformations; the stress
  budget (defaults 120 minutes, 16 GiB, one repeat); session batches of 10,
  100 and 1,000 with censoring rules (D9).
- **Portfolio lane cut:** the first required row is the ledgr/PyBroker top-N
  rotation pair bound in D1: one common ranking with its missing-score
  policy; ties pinned by an explicit deterministic ID order on both sides,
  ledgr's being C-locale instrument-ID order, with PyBroker's native tie
  behavior observed and resolved before its adapter is accepted; one
  rebalance cadence; next-bar quantities bounded on prices, gaps and requests
  so buys are affordable without same-pulse sale proceeds, with the
  unbuyable-candidate policy declared; and holdings compared together with
  fills, cash and equity under D2's labels. Other peers enter only after D5
  qualification and are optional for this lane (D1, D3, D5).
- **Point-in-time demonstration cut:** the synthetic membership, listing and
  delisting fixture from `ledgr_sim_pit_inputs()`; the labelled survivor
  counterfactual; decisions and outcomes shown, never ranked (D1).
- **Authoring lane cut:** the idiomatic six-peer paragraphs built on the
  seven-rule bt/PMwR comparison and the accepted ledgr grammar; the
  non-executed reference table; setup and conceptual indirections; counts and
  cold reads (D11).
- **Report (owned by the lane cuts that produce records; not a dense-oracle
  deliverable or part of the WS4 prerequisite):** the `records/<id>/` layout
  and compact inputs; the predeclared headline set and required assignments;
  render parameters (D10). Each lane cut commits its records; the first
  render comes from the first lane cut with records to show, as
  `tickets.yml` sequences it.
- **WS4 cut, outside this RFC:** the implied calendar, execution stamp,
  diagnostics trace, late-opening behavior and final-bar no-fill disclosure,
  each unchanged or decided and listed before implementation. This synthesis
  pre-accepts none of them.

## 6. Future obligations and routes

Accepted obligations (RFC pipeline, state Obligations open, until a cut owns
each or the maintainer drops it with a reason):

1. The dense oracle and current-tree timing land before WS4 (evidence
   prerequisite, macro plan Section 2); WS4 consumes them under its gate.
   They are the suite's whole C1 prerequisite: peer environments, peer rows,
   the other lanes and the report are not part of it.
2. The full suite reruns after WS4 and WS8 with generations and differences
   named; WS5 migrates the suite's ledgr strategy source to the flat `ctx`
   once, labelled, with unchanged economics proven.
3. Every selected peer gets a completed informative native row, a named
   release-gate item with an owner; unavailable never discharges it. Its
   reproducible recipe lands with the lane cut that first executes it (D5).
4. External claim readiness is the complete accepted suite plus a
   reproducible render; the publication rule stays in force until then.
5. The benchmark manual is updated with the first lane cut that changes
   clocks or labels; historical reports and records remain evidence.

Speculative deferrals, non-binding, preserved in one horizon entry at
acceptance only if the maintainer wants them kept: exchange-calendar and
intraday product support beyond the geometry row; a native zipline minute
bundle; a user-facing migration guide distilled from the authoring lane;
stateful, corporate-action and multi-feature-family workloads beyond the
initial rule families. This synthesis authorizes none of them.

## 7. Rejected alternatives

| Alternative | Decision and reason |
| --- | --- |
| One "equivalent" count per peer (v1) | Rejected: permanently misreports peers whose native execution differs; two disjoint labels instead. |
| One undifferentiated exact whole-table oracle including stamps and diagnostics (v1) | Rejected: today's two paths already differ in representation; economic projection plus checked representation, fail-closed, instead. |
| Assume C1 changes every dense execution stamp to the session open (response F1) | Rejected: depends on the uncut implied calendar; WS4 decides each field. |
| Change the historical recipe's rule, then refreeze (response F2) | Rejected: erases the historical witness; the new recipe is a separate row. |
| Attribute the historical 238 and 682 trade gaps to first-state entries | Rejected as unproven: six entries on a small fixture do not establish cause; new rows attribute by evidence. |
| Reuse `peer_parity()` tiers or the classifier fallthrough for new claims | Rejected: equity-only label; unexplained residuals labelled position size. |
| Reuse `peer_equity_parity()` for unchanged-meaning deletion checks (synthesis draft, FR2) | Rejected: `all.equal` at a default 1e-8 tolerance is not exact; D4 compares by identity, and the helper survives only for labelled diagnostics. |
| All-six provisioning and the first report render as dense-cut deliverables before WS4 (synthesis draft, FR1) | Rejected: the C1 prerequisite is the oracle and the current-tree baseline; recipes and the report belong to the lane cuts that need them. |
| Minimal-retention sweep as the headline ledgr row | Rejected: `NA` cash and holdings and no fills; not comparable to peers' materialized outputs. |
| One tolerance derived from the ledgr-versus-sweep spread (response answer 4) | Rejected as default: per-field bounds with units and arithmetic justification; the spread may inform, not define. |
| Attempted-only denominators (response F6) | Rejected: conceals missing coverage; predeclared required assignments count. |
| Predeclare zipline unsupported on minute geometry, or next-open impossible for a framework (response F3, F9) | Rejected: hypotheses until the pinned workflow is verified; unsupported is an executed finding. |
| Infer a Python environment split from version ranges (response F7) | Rejected: tested compatibility decides. |
| Project 1,000-run sessions from 100 by default (response F9) | Rejected: measure where feasible; projections labelled and never substitutes. |
| A benchmark-owned seeded generator as first resort (response F9) | Rejected as default: public simulators and minimal transformations first. |
| Exclude strategy source and hash from stored provenance (response F8) | Rejected: excluded from the economic projection only. |
| Adapter-owned fill simulation or timestamp relabelling to reach next-open parity | Rejected: a different native contract is its own labelled row. |
| Cartesian peers by lanes by costs by risks | Rejected: each peer where informative; controlled witnesses. |
| Latest-file render fallback, parallel hash ledger or new parity registry | Rejected: explicit record, ordinary files and Git. |
| Combined multi-peer memory peak or summed working sets | Rejected: per-row child tree, two peaks, labelled limits. |
| A new benchmark engine, execution-mode branch, compatibility layer or provenance registry | Rejected: fixed non-negotiables; reuse A0, timing protocol and adapters. |
| Whole-suite framework budget or automatic per-file budget reset (response F11) | Rejected: budgets per bounded cut; stop and recharter at the limits. |

## 8. Sequence

1. Completed: Codex Type 1 final review (round 1 returned CHANGES_REQUIRED;
   patched in place, Section 9); focused re-review PASS (round 2).
2. Accepted by the maintainer, 2026-10-28: pipeline row to Obligations open
   with the lane-cut route; no `decisions.md` row; horizon pointer.
3. Cut the dense lane with its runner, diff checker, gut and inventory;
   Codex cut review; implement; freeze the oracle on a recorded commit before
   WS4; record the current-tree timing. WS4 waits for those two deliverables
   only; the lane's peer rows and their recipes follow under the same cut's
   tickets outside that prerequisite.
4. Remaining lanes alongside release work, each under its own accepted scope
   and budget, each provisioning the peers it executes and committing its
   records; the first report render follows the first records; reruns after
   WS4 and WS8.
5. First external-facing render only from a complete accepted suite.

No production code, test, ticket, contract, environment or publication change
is authorized before synthesis acceptance and ticket cut.

## 9. Revision note

- **2026-10-28, draft.** Claude wrote the synthesis in a tool call whose shell
  write failed; its session then hit the CLI limit. Codex recovered the text
  verbatim from that call without editing its substance (final review,
  handoff note).
- **2026-10-28, correction round 1.** The Codex Type 1 final review returned
  CHANGES_REQUIRED with FR1-FR3; Claude patched in place without reopening
  design. FR1: the dense lane's C1 prerequisite is bounded to the oracle and
  ledgr's current-tree baseline, and all-six provisioning and the report move
  to the lane cuts that need them (D1, D5, D11, Sections 4, 5, 6, 7, 8).
  FR2: `peer_equity_parity()` is excluded from unchanged-meaning deletion
  checks and kept only for labelled diagnostics, with its tolerance verified
  in source (Sections 1, 2, D4, D6, Section 7). FR3: the first required
  ledgr/PyBroker top-N rotation pair is bound explicitly, consistent with
  seed v2 Section 3 and the horizon PyBroker addendum (D1, Section 5). Status
  remains proposed, pending focused re-review and maintainer acceptance.
- **2026-10-28, acceptance.** Codex's focused Type 1 re-review passed with
  FR1-FR3 closed; the maintainer then explicitly accepted the corrected
  synthesis. Codex recorded acceptance and routed Section 6 in the pipeline,
  with pointers from the horizon and roadmap. No shipped behavior, contract
  or implementation ticket was changed by recording acceptance.

<a id="peer-suite-amendment-1"></a>
## Amendment 1. Fresh peer harness and independent A0

**Authority:** maintainer direction, 2026-10-28, during cut 2 review.
The maintainer requested a fresh harness and retirement of the old one once
replaced, then explicitly confirmed the separation: replace the peer harness;
keep A0 independent; the new suite's dense results also serve C1 regression.
This is a recorded change of construction direction after the first two cut
reviews, not acceptance of cut 2 or a reset of review history.

| Affected area | Operative replacement | Unchanged |
| --- | --- | --- |
| D11 executable code reuse | Build the peer harness fresh against public ledgr/native facts. Do not import, copy infrastructure from, or automatically invoke either old harness. Historical strategy bodies may remain attributed fixtures. | One canonical execution engine; no benchmark-owned fills/accounting or compatibility layer. |
| D11/A0 relationship | Reuse A0's frozen evidence and coverage pointers, not its helper implementation. A0 remains separately owned and checked under WS1/WS4 authority. | A0 fixtures, records, checks and cut 1's migration allowance. |
| D11 budget application | The normal 1,500-line allowance applies to the fresh harness and all its R helpers/children. No 299/533-line reserve from loading A0: the new harness does not load or invoke it. No new work may be hidden in A0. | Other protocol limits, runner/scratch diff/gut obligations, four-family/ten-detector initial scope and timing/resource rules. |
| Section 6 replacement obligation | The final WS3 replacement cut retires the old active peer driver once replacement coverage and consumers are reviewed. | Historical evidence retained; no extra C1 prerequisite; no automatic A0 retirement. |

The fresh dense recorder retains complete native data losslessly and provides
readable evidence/diff CSVs. Standard data serialization is sufficient; no
general-purpose framework, manifest registry or old-format reader is required.
The first cut still supplies only the dense oracle and current-tree baseline.
Other lanes, native peer qualification and the Quarto report remain later
suite work. Their absence does not become a new C1 prerequisite.

**Retirement gate and route:** the maintainer holds this obligation in the
pipeline until the final WS3 replacement/retirement cut owns it. Inventory
legacy peer commands and maintained consumers; map useful comparisons and
measurements to equivalent/improved new coverage or a reviewed retirement
reason; then retire active commands and redirect maintained documentation and
callers. Merely writing the first dense runner does not discharge this gate.
Do not retain a permanent parallel peer execution driver or a compatibility
shim. Old reports and result records remain evidence. A0 is not the old peer
driver and remains independently active; this amendment changes no accepted
cut 1 obligation or execution contract.
