# ledgr v0.2.2 Macro Plan

**Status:** Maintainer planning record; accepted on 2026-10-03. Cuts 1 through
5 are complete and accepted. They close the design-memory, direct-performance,
exact-verification, regression-evidence and durable-preparation foundation.
Later macro workstreams remain pre-ticket.

**Date:** 2026-10-03

**Release goal:** Make long-window, point-in-time portfolio research genuinely
usable, then prove it with one public long-only estimator strategy operating on
explicit decision dates.

This document keeps the release coherent while its RFCs, probes and tickets
are developed. It records product scope and dependency order. It does not
override contracts or accepted RFCs, and it authorizes no production change.
Once tickets are cut, `tickets.yml` is the sole execution and sequencing
authority.

## 1. Planning decisions

1. Long-only portfolio research is the product target for v0.2.2. Shorting,
   leverage and market-neutral portfolio semantics remain later work.
2. ML-adjacent means estimators applied to causal point-in-time history on
   explicit decision dates. Trained-model lifecycle, fitting provenance and
   fitted imputers remain with the parked ML-architecture RFC.
3. Terminal outcomes without settlement evidence are on the critical path.
   EXP-0003 supplied no corporate-action facts, and every candidate stopped at
   the first held lifetime terminal. The user must be able to choose a declared
   refusal, write-off, haircut or qualifying-mark assumption, with every
   assumption-backed result disclosed. Exact-quantity settlement improves the
   fidelity of supplied corporate actions but does not solve this blocker.
4. The design-memory overhaul ships in v0.2.2 as a parallel governance
   workstream. It is not a dependency of the product hot path, so proven WS1
   optimizations may proceed alongside it. It must finish before several new
   RFC cycles add more decisions to the current mixed structure.
5. Direct optimizations may enter before the larger design work only when an
   existing spike or benchmark already establishes the mechanism, the public
   boundary stays unchanged and a failure-sensitive detector can protect it.
6. The release ends with one integrated product record. Component benchmarks
   inform tickets but do not substitute for a usable end-to-end result.
7. Residual costs exposed by WS1 are routed by their next honest lever, not
   automatically appended to the direct-optimization cut. Fact verification
   and sealed membership reads may proceed through the bounded WS5 candidates;
   reducing scalar feature-call count belongs to WS3; broader indicator work
   belongs to WS4; and remaining writer work is re-profiled in WS8.
8. Peak memory is an architectural constraint for history, estimators and
   parallel execution, not release polish. Before WS3 binds a history
   representation, it records the accepted current-tree phase baseline and a
   preregistered memory budget for one run and a representative parallel
   workload. New history or estimator capability may not materially exceed
   that budget without an explicit maintainer decision and a routed follow-up;
   equivalent matrices, per-instrument frames, wide frames and history panels
   are not retained together merely for convenience.

## 2. Dependency structure

The release has nine macro workstreams. These are planning units, not ticket
IDs. Ticket cuts may divide a workstream when its evidence and review claim are
genuinely independent.

```text
Scope lock
|-- design-memory overhaul -------- before new RFC cycles --------------|
|-- proven direct optimizations --------------------------------------|
|-- terminal, gap and execution usability ----------------------------|
|-- snapshot verification and artifact policy ------------------------|
`-- history and addressing <-> recursive indicator semantics ---------|
                                    `-> one public estimator strategy -|
                                                                       v
                                                  integrated record -> release
```

The critical join is the integrated record. The estimator strategy must consume
the package's public history surface; it must not reconstruct a private one.
Scheduler v2 is conditional work, not a dependency of that proof.

## 3. Macro workstreams

### WS0. Design-memory overhaul and scope lock

- Follow `design_memory_overhaul_plan.md` after its adversarial review and
  maintainer acceptance; the draft does not authorize migration by itself.
- Establish `contracts.md` as the normative current-release source only after
  the plan's bounded authority and outbound-reference census supports removing
  its stale packet handoffs.
- Register this packet and the active design authorities.
- Make `horizon.md` a parking lot: a cited or binding idea has graduated and
  moves to its durable authority rather than remaining authoritative there.
- Move binding scope and contract decisions to `contracts.md`, an accepted
  synthesis or the owning packet; move measured findings to research, audit or
  benchmark records. The wound-down ADR process is not revived.
- Make the RFC index a pipeline for active, due, parked and accepted cycles
  with open obligations. Register each obligation once with its exact source,
  trigger and owning route.
- Use a single decision bridge for accepted choices not yet consolidated into
  standing authority, and explicit `Superseded by` links where ambiguity would
  otherwise remain.
- Keep state-bearing records grep-readable. After migration, consider only a
  bounded local-link check; do not add a metadata or prose-conformance gate.
- Preserve historical RFCs, reviews, closeouts and stable anchors. Compress or
  redirect their index entries rather than rewriting their evidence.
- Reconcile stale version names and clearly superseded planning statements.
- Confirm the long-only boundary and the exclusions in section 5 before ticket
  cut.

Exit: a maintainer and an executor can find every operative authority and open
obligation from the indexes; no binding decision lives only in `horizon.md`;
and the new RFC cycles have one documented place to write each kind of memory.

### WS1. Proven long-window optimizations

Land already measured, bounded improvements before building more consumers:

- per-pulse fill-event block writes;
- prepared scalar feature accessors;
- validate-once or run-local memoization for explicit feature maps;
- a vectorized strict path for ledgr's own bounded indicators, with exact
  feature-value and NA-mask parity and unchanged error behavior;
- vectorized session construction;
- linear membership resolution; and
- constant-time diagnostic sequence tracking.

Each item needs its own current-tree probe, semantic parity witness and
failure-sensitive scaling detector. Re-measure rather than inheriting a speed
claim from an older implementation.

Exit: the proven costs that would multiply later long-window work are removed
or explicitly rejected by current-tree measurement. Custom and external
indicator semantics remain with WS4.

### WS2. Terminal, gap and execution usability

- Gather the named prior art and run an RFC on terminal outcomes for holdings
  whose lifetime ends without settlement evidence.
- Keep refusal as an explicit policy choice rather than the only outcome, and
  disclose every assumption-backed write-off, haircut or qualifying mark.
- Resolve the ordinary-gap helper pipeline so documented, bounded missingness
  does not require strategy-specific reconstruction.
- Decide how incomplete candidates count as trials and participate in sweep
  and walk-forward reporting and selection.
- Repair the pre-loop interruption path so a failed feature computation cannot
  leave a run in `CREATED`.
- Close the execution-intent decisions needed by a long-only strategy: dense
  short and negative-cash behavior, and held-position intent during halts.
- Include availability-aware state reconstruction only if a vendor-neutral
  reproducer confirms the remaining gap.

Primary research inputs include LFB-011, LFB-017, LFB-018, LFB-019 and LFB-023
in the research findings register.

Exit: the long-window fixture crosses held lifetime terminals under a declared
assumption, ordinary gaps do not abort the helper pipeline, incomplete trials
remain visible, and interruptions become resumable or classed failures.

### WS3. Point-in-time history and feature-map addressing

- Use the [research strategy UX brief](research_strategy_ux_brief.md) as the
  non-binding cross-RFC product direction. The owning feature, history,
  indicator and scheduler syntheses decide which proposed surfaces survive.
- Consume the completed
  [cross-method UX exercise](portfolio_method_ux_exercises.md): eight
  materially different portfolio methods reused the same proposed history,
  identity, exclusion and target boundary without earning a method-specific
  ledgr type.
- Implement the accepted historical-projection direction from synthesis v11.
- Provide a two-clock history representation that preserves observation and
  knowledge time.
- Resolve feature-map addressing so aliases, concrete feature IDs and
  whole-universe historical reads are coherent.
- Remove the need for active-alias strategies to loop over instruments for a
  whole-universe feature read. The prepared scalar accessor is retained as a
  valid narrow read; do not spend another internal ticket shaving its remaining
  proportional per-feature work before this call-count reduction is measured.
- Bind missingness treatment, disclosure and numerical correctness at the
  history boundary.
- Preserve the included instrument IDs, excluded instrument IDs and exclusion
  reasons in the classed history result. An identity-preserving matrix adapter
  exposes only the included estimation sample without requiring callers to
  remove a time column or reconstruct names.
- Provide a structural-completeness query for requested lookback and minimum
  instrument count. Keep it distinct from WS4 indicator readiness and from
  current execution admissibility.
- Narrow expected sessions by instrument where the evidence requires it.
- Use the same substrate in run, sweep and walk-forward paths.
- Register a current-tree phase-memory baseline and an implementation budget
  before choosing the representation. Measure live size, peak temporary
  allocation and representative worker multiplication separately; do not
  accept a representation whose peak exceeds the budget without an explicit
  maintainer decision and a routed memory obligation.
- Run one bounded local-worker spike against the existing `mirai` path using
  `mori` shared memory for immutable prepared bars and feature matrices.
  Compare setup and elapsed time, parent and worker RSS as worker count grows,
  worker restart and cleanup, and whether history-frame, `collapse` and
  indicator operations materialize private copies. The spike covers same-host
  sharing only: it does not share DuckDB connections or mutable run state and
  does not choose a dependency. Promote the mechanism only if public outputs
  remain identical and the representative parallel workload shows a material
  memory reduction.
- Share ownership with WS4 for the history-start boundary: run-window warmup,
  walk-forward hydration and recursive history must use one causal rule.

No optimizer or estimator may assemble a private history panel from scalar
accessors.

Measured input, 2026-10-04, non-binding: building a frame on demand from
prepared matrix columns with `collapse::qDF()` or a bare data-frame
constructor costs about 12-28 µs per 600-instrument frame and reproduces the
prebuilt pulse views exactly
([`dev/spikes/ctx_frame_views/probe_findings.md`](../../../dev/spikes/ctx_frame_views/probe_findings.md)).
History-panel design may use that pattern: one prepared representation, with
frames built on request. A follow-up attribution
([`churn_findings.md`](../../../dev/spikes/ctx_frame_views/churn_findings.md))
found that peak memory is the highest of the run's phases: live state plus
the churn of preparation and the fold. History preparation adds a phase, so
WS3 measures that phase's peak alongside its time and avoids per-instrument
data-frame construction during preparation.

Exit: a strategy can request causal multi-instrument history through one public
surface with stable identity, explicit inclusion and exclusion evidence,
structural completeness and missingness semantics.

### WS4. Recursive indicator semantics and strict-feature acceleration

Start with a public-API probe, then settle the recursive-indicator design:

- distinguish bounded-window and recursive-history indicators;
- separate first-valid output from convergence or readiness;
- define gap transitions, including whether recursive state resets;
- define walk-forward hydration and scoring behavior;
- add prefix-invariance and scalar/series equivalence checks where applicable;
  and
- expose per-instrument readiness rather than a universe-wide all-or-nothing
  gate.

The vectorized built-in bounded path belongs to WS1 because exact parity is
already measurable. Any equivalent shortcut for custom or external indicators
waits for these semantics. Do not let a speed implementation choose the
meaning of gaps or convergence implicitly.

After those semantics are bound, re-profile the exact built-in SMA at long
lookbacks. Its retained `mean()`-per-window implementation is deliberately
O(rows x lookback) because the measured rolling alternatives changed exact
floating results. Consider another accelerator only if a current public path
still attributes at least five percent to that implementation and the candidate
preserves exact values, NA masks and failure behavior. Built-in returns is
already linear and has no planned second optimization.

Exit: native, external and custom indicators have an explicit causal contract
and availability behavior, and the strict path is tractable at long-window
scale.

### WS5. Snapshot verification and artifact policy

- Decide the verification policy and component-hash boundary rather than
  repeatedly hashing every persisted fact on ordinary reads.
- Decide whether feature persistence is requested, promotion-only or reusable
  by snapshot and feature identity. This is a stored-artifact policy decision,
  not a parity-only optimization.
- Apply direct long-window optimizations that remain material after WS1 through
  WS4.
- Capture a phase-level memory profile before changing representation solely
  to reduce memory. A first R-heap attribution exists
  ([`dev/spikes/ctx_frame_views/probe_findings.md`](../../../dev/spikes/ctx_frame_views/probe_findings.md),
  757 pulses × 600 instruments). Peak is 634 MiB of `gc()` max used against at
  most 379 MiB live, so about 40% of peak is preparation and fold churn.
  Hydration alone reaches 530 MiB, the dead hydration intermediates targeted by
  Cut 5 are the largest live block, and the precomputed `ctx` views are 6-8%.
  [`churn_findings.md`](../../../dev/spikes/ctx_frame_views/churn_findings.md)
  attributes the churn by phase:
  - fold: 231 MiB above live; per-pulse asset-state normalization, diagnostic
    JSON and context helpers;
  - features: 189 MiB; `ledgr_strict_builtin_kind()` re-fingerprints the
    built-ins on every instrument call;
  - hydration: 253 MiB;
  - run start: 314 MiB, mostly the snapshot re-hash, which stays below the fold
    peak at this shape.

Measured inputs registered on 2026-10-04:

- [exact fact-integrity verification](../spikes/fact_integrity_verification_spike/closeout.md)
  passed independent review with a hash-identical 5.28x candidate at 300,000
  membership rows, subject to a low-repetition no-regression gate and stronger
  timestamp corruption witnesses; and
- [DuckDB membership resolution](../spikes/duckdb_membership_resolution_spike/closeout.md)
  measured a conditional 1.63-1.66x candidate, but independent review
  invalidated exactness because SQL and R ordered tied mixed-case set IDs
  differently.

The spikes bind nothing. Cut 3 owns exact verification only. Correct the SQL
boundary under the retained resolver's ordering, add a too-late gut and narrow
the scope guard, then remeasure one candidate path after Cut 3. Do not invent a
small-history fallback unless that rerun measures a regression. A later SQL
ticket remains eligible only while hash bytes, verification policy, schema and
resolver authority remain unchanged.

Exit: verification remains fail-closed and reproducible without dominating
ordinary long-window runs.

### WS6. Conditional scheduler v2

- Measure the cost of held pulses before choosing an implementation.
- Proceed in v0.2.2 only if that probe shows material product-path cost;
  otherwise defer the scheduler without blocking the release.
- Consume the WS2 execution-intent decisions for held and halted positions.
- Define a scheduler that can skip strategy callback, context and feature work
  on held pulses while still honoring fills, cash and disposition events,
  valuation ageing and availability boundaries.
- Consider event-to-event stepping only if a spike proves the state transitions
  remain complete.

Exit if promoted: scheduled strategies pay strategy and feature cost on
decision dates, not blindly on every market pulse. A deferred result is also a
valid exit when the measured cost is immaterial.

### WS7. One public long-only estimator strategy

- Implement one representative estimator-to-weight strategy, such as long-only
  minimum variance, through the public history surface and existing target
  helpers.
- Run it only on explicit decision dates; `ctx$hold()` is sufficient unless
  WS6 independently earns promotion.
- Bind only the affordability, risk, identity and failure behavior required by
  this one public proof.
- Keep the implementation ordinary enough to expose missing public capability
  rather than hiding it in strategy-specific plumbing.
- Exercise a frontier-shaped acceptance case: causal observations-by-assets
  input, an identity-preserving matrix boundary, identified long-only weights
  and target conversion. Schur complementary allocation is evidence for this
  shape, not a required dependency or the estimator that must ship.
- Treat the completed method cards as design evidence, not as a substitute for
  this runnable proof. Black-Litterman's upstream views and the paper-level DRO
  adapter are explicitly outside the proof.
- Make the behavior of an admissible held instrument omitted from the
  estimation sample explicit in the proof. Do not let absence from a weight
  vector silently choose between keep, liquidation and refusal.

Exit: at least one nontrivial long-only portfolio strategy runs without private
engine access, private history construction, research-side accounting or a
model-management system, and its estimation exclusions cannot silently become
execution decisions.

### WS8. Residual performance pass and integrated release evidence

**Early item: long-window baseline and regression suite (after Cut 3 is
accepted).** Most WS1 and Cut 3 gains are on the availability path: strict
built-ins, fact construction and verification, and diagnostics. The dense peer
benchmark exercises only the fill flush, because its strategy reads
`ctx$features_wide`, so it cannot catch availability regressions. Each
workstream gated its own piece, but nobody has remeasured the long-window shape
end to end. Before further optimization cuts:

1. **Baseline.** Rerun the 2026-10-02 drivers in `dev/bench/long_window/` on
   the accepted Cut 3 tree, cold and warm, at the recorded shapes, with a phase
   profile. The record states what remains of the EXP-0003 cold run and which
   phases now lead.
2. **Internal regression suite.** Promote a fixed set of those synthetic
   availability shapes (sessions, membership churn, terminals, gaps, returns
   and SMA features) into a registered local suite:
   - shapes that run in minutes;
   - one large shape run only at release;
   - paired-arm comparison against the last accepted record, flagging any
     registered shape that is more than 10% slower.

   It runs locally at each optimization-cut close and before each release, not
   in hosted CI, whose timing is too noisy to gate on.
3. **Structural detectors in CI.** Catch complexity regressions in CI with
   counters rather than clocks:
   - every accepted hot-path optimization keeps its counter detector;
   - small scaling tests assert that counted work grows linearly.
4. **Release-scale record.** One synthetic record at the EXP-0003 scale per
   release, so research on vendor data confirms numbers rather than
   discovering them.

The suite is internal evidence. It is separate from the peer-workload suite,
needs no peer parity and supports no public performance claim. Cut it as one
chore ticket after the baseline exists.

Re-profile after the architectural work. Reconsider only costs still material:

- per-fill payload and JSON work. The WS1 block flush reduced measured fill
  writing from 11.8 to 6.2 seconds at 68,201 fills but deliberately retained
  one-row payload construction. If the current public run still attributes at
  least five percent to it, run one bounded spike comparing that path with
  direct typed pulse-column construction. Require exact ledger events, fills,
  equity and trades plus durable failure atomicity before cutting a ticket;
- the availability pulse context. Availability runs build accessors through
  the general per-pulse helper path, because the fast context is prepared once
  for a fixed universe (`use_fast_context <- !availability_active`). So the
  WS1 prepared-accessor gains do not reach them. Spike an availability-aware
  fast context (prepared lookups plus a per-pulse decision-axis mask) only if
  the baseline profile attributes at least five percent of an availability
  run to context construction or accessor calls. Non-member and off-axis reads
  must keep their current failures or `NA` results at every pulse;
- availability fill-timing matching;
- strategy-state serialization;
- `db_live` writes;
- availability result and recovery replay; and
- peak working memory.

Do not promote `ledgr_fill_row_buffer_add_many()` alone from the old
three-percent compiled-sweep observation. Re-measure it only as part of the
writer profile. Likewise, do not reopen scalar accessor micro-optimization
here: WS3 first removes avoidable per-instrument calls, and WS4 owns any
post-semantics indicator residual.

Promote a remaining candidate only when the current product path, not a private
harness, shows the cost. Then run one integrated long-window record covering:

- run, sweep and walk-forward behavior;
- interruption and resume;
- terminal-assumption and ordinary-gap cases;
- historical and recursive-indicator semantics;
- one long-only estimator strategy on explicit decision dates; and
- scheduler behavior only if WS6 was promoted by measurement.

Run the standardized peer workload as release evidence. Do not make a public
performance claim, including a same-host version-over-version speedup claim,
until the broader peer-workload suite is defined and run. Building that suite
is not itself a v0.2.2 product goal.

Exit: the release goal is demonstrated end to end and all release claims name
the measured boundary.

## 4. Cut strategy

Tickets should be cut in dependency waves rather than all at once:

0. Governance foundation: WS0. It may run alongside WS1 but finishes before
   the terminal, history, indicator and verification RFC cycles open.
1. Direct performance foundation: WS1, then the bounded WS5 exact-verification
   cut (Cut 3). Once Cut 3 is accepted, take the early WS8 long-window baseline
   and cut its regression-suite chore, so later optimization and design cuts
   start from a current availability-path measurement.
2. Product and cost-policy decisions: WS2, plus the WS5 verification and
   persistence decisions. Their implementations need accepted authorities.
3. History and indicators: WS3 and WS4 in one design wave, sharing the
   history-start and hydration decision before either implementation is cut.
4. Product proof: WS7. WS6 proceeds independently only if its probe promotes
   it.
5. Integrated evidence and release gate: WS8.

A later wave may be drafted while an earlier one executes, but it may not
assume an unresolved representation or semantic decision. Ticket granularity
should follow one shared correctness or evidence claim, not file ownership.

## 5. Explicit non-goals

The following do not gate v0.2.2:

- shorting, leverage and market-neutral portfolio semantics;
- trained-model lifecycle and model registry behavior;
- fitted imputation policy;
- exact-quantity settlement for recipient shares and basis transfer;
- generic portfolio scaffolding, the weight-strategy wrapper, a method
  catalogue and solver-specific adapters such as Schur;
- scheduler v2 unless its held-pulse probe shows material product-path cost;
- one store connection per composite public call;
- exact derivatives, margin and multi-currency accounting;
- compiled execution becoming authoritative or the default;
- broad compiled-path expansion;
- rewriting or deleting historical RFCs, reviews and closeouts;
- retiring the precomputed `ctx` frame views in favour of explicit frame
  helpers. The maintainer scheduled this for the next release on 2026-10-04
  ([RFC pipeline](../rfc/README.md#ctx-frame-retirement));
- the broader memory optimization pass: per-phase memory gates, per-pulse fold
  churn, a memory budget and feature-cache lifetime. It is scheduled as the
  next release's memory release (roadmap, "Post-v0.2.2 memory optimization
  release"). v0.2.2 keeps Cut 5 and the WS5 feature-persistence decision;
- plotting, print and CI polish unrelated to a release claim; and
- broad optimization cleanup without a measured product-path cost.

These are not rejected capabilities. They stay visible in the roadmap or
horizon and require their own evidence and design route.

## 6. Release definition of done

v0.2.2 is ready for its release gate only when:

1. operative decisions and open obligations are discoverable without treating
   `horizon.md` as a binding authority;
2. a long-window availability-aware run crosses a held lifetime terminal
   without settlement evidence under a declared and disclosed assumption, and
   crosses supplied corporate actions under the research policy without
   becoming incomplete;
3. run, sweep and walk-forward consume the same point-in-time history
   substrate;
4. bounded and recursive indicators have explicit readiness and gap contracts,
   and the strict feature path is practical at the registered scale;
5. one long-only estimator strategy consumes causal history on explicit
   decision dates and runs end to end through public APIs;
6. snapshot, configuration and result integrity remain fail-closed and
   reproducible under the chosen verification policy;
7. an interruption before the pulse loop cannot leave an ambiguous `CREATED`
   run, and resume preserves the same economic and historical result;
8. the integrated record states its clocks, workload, exclusions and public
   boundary without extrapolating component speedups; and
9. no release note, README, article or record claims that the reference
   Sharadar workflow ages halted or untraded carried prices, or prevents fills
   on them, unless accepted upstream untraded-bar evidence (ledgr-research
   LFB-027) and a passing end-to-end record are linked. Otherwise the release
   states the exclusion explicitly. Registered on 2026-10-05 from the
   terminal-outcomes synthesis Section 6 and the Cut 6 cut review; LDG-2961
   pins it with a documentation-contract test; and
10. history preparation and the public estimator proof report live and peak
    memory for one run and a representative parallel workload against the
    preregistered WS3 budget. A breach is either corrected before release or
    accepted explicitly with its user-visible limit and a durable follow-up;
    it is not hidden inside the integrated runtime record.

## 7. Change control

This plan is intentionally easier to change than a specification. A scope or
dependency change is recorded here and summarized in the roadmap until ticket
cut. After ticket cut, changes to executable scope or ordering belong in
`tickets.yml`, with this document updated only when the release-level story
itself changes.
