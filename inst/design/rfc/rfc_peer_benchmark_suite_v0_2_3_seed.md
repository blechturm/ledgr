# RFC Seed: Peer Benchmark Suite

**Status:** DRAFT, non-binding. Prepared at the maintainer's request,
2026-10-28; next stage is Type 2 response. No implementation cut or public
performance claim is authorized here.
**Owner:** v0.2.3 macro plan WS3, inventory X4;
[benchmark-methodology](README.md#benchmark-methodology).
**Inputs:** the accepted [macro plan](../ledgr_v0_2_3_spec_packet/macro_plan.md)
revision 2; [roadmap](../ledgr_roadmap.md), Current planning release;
[suite decisions](../horizon.md#2026-10-01-benchmark-a-suite-of-peer-workloads-not-one)
and their memory/parity/PyBroker addenda; the existing
`dev/bench/peer_benchmark/` record; strategy-grammar peer evidence;
[benchmark manual](../manual/benchmark_methodology.qmd) and
[spike protocol](../spike_protocol.md).

## 1. Question and scope

What small set of shared workload contracts makes peer parity useful for
trust, gives C1 a deletion oracle, exposes ledgr's cost across shapes, and
shows an R user how familiar portfolio rules read in ledgr?

This is one suite with five lanes, not every engine crossed with every case.
It serves internal regression/measurement and an externally shareable report
demonstrating where ledgr gets the same results as peers and whether it is
faster on comparable work (maintainer addition, 2026-10-28). The report leads
with informative headline figures and keeps detail available without flooding
the reader. Public performance claims still require the accepted suite;
matching results and any speed advantage must be demonstrated, not assumed.

### Fixed inputs, not questions for this RFC

- Peers: quantstrat, PMwR, backtrader, bt, zipline-reloaded and PyBroker v2.
  Each enters the lanes where its native public model is informative.
- TradeStation, Pine and AmiBroker are a non-executed authoring reference
  table only. vectorbt and LEAN are out of scope.
- Freeze current native outputs before handler or engine deletion. The dense
  lane precedes C1; it does not wait for the new output handler.
- Measure the current tree before rewrites, then repeat the full suite after
  WS4 and WS8. The full suite, not just its first lane, remains in this release.
- Report time and per-engine memory. Warm public research iteration is the
  primary speed comparison, with cold, diagnostic and amortized views adjacent.
- The durable public reproducer lives in this repository under
  `dev/bench/peer_benchmark/`; private data and bulky raw traces need not.
- A rendered Quarto report is a required output, designed for external readers.

## 2. Prerequisite executed before this seed

`dev/spikes/peer_suite_seed/probe.R` runs the current public TTR SMA 5/10
crossover on a sealed 2-instrument, 120-bar fixture: 22 native fills. Mutating
one published fill quantity leaves the existing `peer_parity()` attribution
at “passes Tier 1 tolerance” because its equity input is unchanged. An exact
native-fill comparison detects the mutation. The scratch rerun and gutted
detector are checked by `check.R`; see its one-page `probe_findings.md`.

This is evidence for separating two comparison contracts, not a new peer
result or proof that A0/C1 coverage is complete. The old benchmark's public
run path, four measured phases, pinned adapters and residual-attribution
machinery are reusable. Its one equity-level label is not the new gate.

## 3. Proposed workload lanes

| Lane | Purpose and initial contracts | Proposed peer assignment |
| --- | --- | --- |
| Dense conventional parity | Familiar daily rules with exact timelines: existing SMA crossover; time-series momentum/filter; mean reversion; one recursive/TTR indicator case. Fixed unit quantities first, with costs/risk/terminal witnesses attached to the relevant rule. | quantstrat, PMwR, backtrader, zipline-reloaded, PyBroker where the contract is natively expressible. |
| Scaling geometry | Hold rule and outputs fixed while varying instruments, pulses and lookback. Separate daily long-history, narrow/long intraday-like geometry, wide/short cross-section and the separately budgeted wide/long stress row. | Selected dense-lane peers; no mandatory Cartesian product. |
| Whole-universe portfolio | First new rule: top-N rotation with common ranking, ties, rebalance dates, next-bar fills and holdings. It exposes per-symbol versus whole-universe callback costs. | PyBroker v2 and ledgr required first; add PMwR, backtrader or zipline where a native adapter proves the same contract. |
| Point-in-time demonstration | One synthetic membership/listing/delisting example, with causal membership versus an explicitly labelled fixed-survivor counterfactual. Show decisions and outcomes; never rank speed or parity. | ledgr reference; other native workflows only where informative, with unsupported fact handling stated. |
| Authoring | The same paragraphs written idiomatically in each framework: fixed mix, trend filter, rank/rotate, preservation and memory. Start from the seven-rule bt/PMwR experiment and the accepted ledgr patterns. | All six peers; closed-source reference table kept separate from executed rows. |

Assignments are proposals to validate, not claims that each adapter already
exists. bt begins in authoring; it is not forced into next-open parity by
replacing its native execution with a benchmark-owned simulator. Every selected
peer needs a completed informative native row before the suite is called
complete; unavailable peers remain visible pending resolution.

Retain the decided non-Cartesian shape anchors: 10 instruments by about 7,200
bars, 500 by 1,260, 1,166 by 252, and a separately budgeted 1,166 by about
7,200 stress row. Label daily long-history and minute-labelled geometry
separately; a frequency label is not an additional bar count. The seed's
response must settle the exact narrow intraday row and required assignments.
No first-class intraday calendar, fill or metric support is implied by a
geometry experiment. Unsupported shapes get an explicit result, not a new
execution-mode branch or a silent daily substitute.

## 4. One explicit contract per comparison

Before implementation, each chosen workload states:

1. Input bars/facts, UTC axis, sessions, missingness and deterministic generator;
   feature definition, lookback, warmup and usable-score convention.
2. The paragraph and native implementation; selection/tie rules, cadence,
   initial holdings/cash, target quantity/weight units and sizing price.
3. Signal knowledge time, execution time/price, final-bar behavior, costs,
   cash treatment, risk and quantity rounding.
4. The common measurement window and required outputs: equity/cash, holdings
   by asset, fills with execution keys and costs, and applicable trade results.

Dense unit-share cases use explicit ample capital and zero costs initially;
nonzero costs and risk are separate controlled witnesses. Portfolio fixtures
must avoid accidental cash-shortfall policy comparisons: bound prices/gaps
and budget requests so all buys are affordable even before sale proceeds,
or explicitly classify the row as a different policy comparison.

Use each framework's documented public workflow. Small adapters translate
native outputs and target/order conventions; they do not implement fills,
funding or accounting. Record unavoidable semantic differences instead of
quietly changing a paragraph to fit a peer. Authoring comparisons may express
the same idea under different execution semantics, but do not inherit a
numeric-parity or speed-ranking claim from that similarity.

## 5. Two distinct correctness comparisons

### 5.1 Internal ledgr regression and deletion

Freeze current native tables and their exact extraction rules before WS1/C1
delete implementations. C1's unchanged-meaning results compare exactly, not
within the old peer equity tolerance. Keep fills, equity/cash, asset holdings,
diagnostics and applicable state/accounting evidence; do not substitute a
position-value proxy for holdings by asset. Normalize only declared irrelevant
identity labels, never a differing bar, quantity, fee or missing row.

The dense deletion witnesses cover common calendars, sparse/missing bars,
warmup, final-pulse no-fill and controlled cost/risk cases as well as the
familiar recipes. The frozen v0.2.2 real-data reference remains separate.
A failure blocks deletion unless the maintainer decides an identified semantic
difference; do not regenerate an old oracle from the candidate to make it pass.
If a currently runnable bars-only shape or explicit compiled selector becomes
unsupported after C1, that is a changed capability requiring a maintainer
disposition, not a neutral missing benchmark row. Preserve the existing
compiled diagnostic where applicable without authorizing compiled expansion.

Later API, precision or fill-policy cuts may intentionally change schemas or
results. Name those changes and their receiving contracts; preserve the old
C1 evidence. Do not require an obsolete public grammar to survive as a
compatibility reader merely so a historical benchmark script still runs.

### 5.2 Cross-framework parity

Require exact asset/time axes, NA masks and discrete trade decisions where
the declared contract makes them common. Predeclare field-level numeric
tolerances for harmless floating arithmetic; no account-level percentage
tolerance can hide a different fill, holding or cash path.

Align by declared timestamps/asset keys, not row position. Any calendar mapping
must be explicit and independently validated. Warmup exclusions are declared
prefixes, not a retained-row allowance that can conceal a missing interior bar.
Check indicator values and decisions before interpreting aggregate returns.

Report: equivalent under the declared numeric contract; classified semantic
residual/non-comparable; or unsupported/unavailable/failed with reasons.
Attribute differences to ledgr, peer or harness before accepting a comparison.
Classified non-equivalent rows may be useful descriptions, but do not enter
a shared speed ranking. Keep reasons and the first decisive divergence.

## 6. Timing, reuse and memory

Each engine/workload runs in its own process on the same declared host budget.
Pin versions, dependency environments and native settings. Counterbalance
order, repeat measurements and show spread; do not promote a favourable rerun.
Record threads, JIT state, output retention and process-launch treatment.

- **Cold public end to end:** raw common input through comparable required
  results, including native preparation and compilation where first-use pays it.
- **Warm public research iteration (primary):** supported reusable native
  preparation retained, but a real experiment/candidate is constructed, run
  and its required results materialized. Rebuilt per-run work stays inside.
- **Engine-only diagnostic:** attribution only, never the public headline.
- **Session cost:** one preparation followed by a predeclared sequence of
  public experiments/candidates, initially 10/100/1,000 where feasible. Distinguish
  measured batches from arithmetic projections; reset strategy/book state
  between independent experiments and preserve intentional candidate variation.

Peers get equivalent supported reuse. A framework without safe public reuse
reports that limitation; the adapter does not secretly bypass its lifecycle.
Report preparation, indicators, orchestration, engine, results, instrument-bars
and actual callback counts. If counting perturbs timing, obtain counts in a
separate labelled validation pass. Missing subclocks are unavailable, not zero.

Sample each row's complete process tree, including native daemons and child
processes. Report cold-preparation and warm-execution memory separately, with
the platform measure and sampling interval; RSS is not interchangeable with
private commit. A single combined six-engine peak is not per-engine memory.
State baseline retained memory and phase peaks rather than subtract unrelated
process peaks. PyBroker has separate cold-JIT/warm-JIT and minimal-output/
comparable-retention rows; do not headline minimal retention against rich results.

Resource limits for the stress row and expensive batches are declared before
launch. Time/memory limits produce explicit censored outcomes, not zeros or
successes. Use the registered-host rules for promoted timing; the small seed
probe is not such a record. Data/fact changes invalidate preparation reuse.

## 7. Authoring evidence and API generations

Count conceptual indirections alongside code: labels, containers, registration,
shared stores and storage details a reader resolves before recognising a rule.
Readability judgments are informed observations and maintainer cold reads,
not novice scores. Include setup and native costs of reproducing the paragraph.
Document native idioms and every adaptation needed for comparable semantics.

The current-tree baseline uses the shipped API. The corrected read row uses
its supported alias-aware vector read; after WS5, the counterpart uses flat
`ctx` columns and the accepted grammar. Keep names/generations distinct and
strategy economics fixed. The old pipeline's `ctx$features()` correction note
must be reconciled with the accepted flat surface, not treated as a requirement
to revive a retired accessor. Migration guides consume this lane; WS5's pattern
article and cold-read acceptance do not wait for all peer environments.

## 8. Rendered report: headline evidence first

Deliver Quarto source and a portable, self-contained HTML artifact under
`dev/bench/peer_benchmark/` (`peer_suite.qmd` / `peer_suite.html`). Preserve
historical reports. Render an explicitly selected accepted record; do not run
benchmarks, install dependencies or silently choose the latest record during
rendering. The HTML must be useful without a checkout, service or notebook.

The first screen answers: which tested rules produced equivalent results,
how warm public runtime compares, and what the comparison covers. Lead with
parity coverage and compact runtime figures, including absolute times and
repeat spread. Give per-peer denominators and visible non-equivalent,
unsupported and unavailable counts. An authoring-only peer is not numerical
equivalence evidence; every peer named in a results-agreement claim needs a
completed matching numeric example. Resolve that requirement in lane assignment.

Use a small predeclared headline set, with warm runtime ratios by workload
and a compact memory view. Include slower ledgr results as prominently as wins;
show the full comparable-row table within easy reach. Do not average different
comparison sets into a universal speedup or select highlights after seeing times.
Cold/session costs, JIT/retention differences and brief interpretation sit
beside the headline. Equivalence means the declared trade/holdings/numeric
contract, not merely a similar return curve.

Keep full method, residual traces, per-phase tables, environments and runnable
commands in expandable detail/appendices. Show a few readable strategy examples
and link full source; keep raw logs off the main reading path. Versions, host,
date and source identity are visible, with the exact limits of each headline.
Figures and tables come from the selected evidence, never hand-entered claims.

Internal incomplete renders are labelled preliminary. External claim readiness
requires accepted suite results and a reproducible render; the narrative follows
the measurements even if the speed hypothesis fails. This RFC authorizes the
reporting work, not publication of unmeasured superiority.

## 9. Delivery order and publication boundary

1. Dense lane and current native baseline/timing first, before C1 deletion.
   This does not wait for WS1; A0 records are coordinated, not duplicated.
2. Authoring and remaining lanes proceed alongside implementation. The full
   suite repeats after WS4 and WS8 on the same unchanged contracts/inputs;
   disclose any accepted intentional economic or API changes as separate rows.

Keep workload source, native adapters, lockfiles, public synthetic generators,
compact promoted evidence and method report under `dev/bench/peer_benchmark/`.
Large raw records may remain local, but the complete deletion oracle must be
reviewable and reproducible; a digest alone is not its replacement. Git and
native snapshot/config identity supply provenance; no parallel hash ledger,
registry or benchmark execution engine is introduced. No private Sharadar data
or proprietary platform result is published as an executed peer row.

Each implementation cut supplies a runner, scratch diff checker and meaningful
gut demonstration. Start the dense cut with at most four rule families and
no more than ten initial detectors; budget later lane work separately rather
than build the whole cross-product harness first. The RFC needs neither a
new product API nor permission to move existing package semantics.

The full suite's accepted results are the publication prerequisite. A smoke
row, a missing peer, a tiny geometry case or a fast engine-only time cannot
discharge it. Internal phase baselines remain useful before publication.

## 10. Questions for the Type 2 response

1. Are the proposed assignments sufficient for the chosen peer set, especially
   a native numeric example for each peer claimed equivalent, bt's authoring
   role and the first ledgr/PyBroker rotation, without forcing non-native
   next-open workflows into a numeric ranking?
2. Which minimal dense deletion witnesses and required outputs protect C1
   beyond the existing SMA record? Where must exact comparison stop because
   an accepted workstream intentionally changes meaning or schema?
3. What exact narrow intraday geometry and separately budgeted stress/batch
   limits are defensible without making a new intraday-support commitment?
4. Which field-level tolerance/calibration and first-divergence rules separate
   benign arithmetic from changed decisions? Reject the old equity-only label
   as the deletion gate; do not tune tolerances after a wrong fill appears.
5. Which public prepared-data/reuse and retained-result boundaries can each
   peer actually supply, and which need an explicit unavailable result before
   timing implementation? What repetitions/host budget should the first cut pin?

The six peers, full release scope, parity-first policy, five lanes, required
before/after timing and external-facing Quarto artifact are settled inputs.
The response evaluates contracts, report clarity and practical boundaries;
it does not reopen those choices.
