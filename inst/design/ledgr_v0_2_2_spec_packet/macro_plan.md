# ledgr v0.2.2 Macro Plan

**Status:** Maintainer planning record; accepted on 2026-10-03. Cuts 1 through
13 are complete and accepted. Draft Cut 14 owns the accepted pre-CRAN legacy
removal and its codebase-hygiene amendment; its cut-review corrections await
focused re-review before implementation. The interim rule-3 lake rebuild and
one-execution-mode probe then precede the point-in-time history (WS3) and
recursive-indicator (WS4) implementation cut. Their shared history-start
decision replaces Cut 9's temporary rule.

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
- The WS3 amendment must bind that the matrix adapter operates only on an
  already-constructed history result. It is not a second reader and owns no
  cutoff, axis or missingness logic.
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

- Use the existing [long-window hashing measurements](../../../dev/bench/notes/long_window_scaling_findings.md#5-snapshot-hashing-spike),
  [DuckDB prototype](../../../dev/bench/long_window/hash_spike.R) and
  [binary-payload experiment](../../../dev/bench/notes/durable_path_observations.md#observation-5-the-hash-payload-could-be-bytes-instead-of-strings)
  to evaluate database-side canonicalization and hashing. Extend these probes
  only for missing correctness and end-to-end evidence; do not reopen the
  general feasibility question.
- A new hash-rule version is permitted; reproducing R serialization is not a
  requirement for that new rule. Decide the canonical encoding, text versus
  binary representation, and version dispatch or explicit migration for
  existing snapshots before implementation, with the corresponding contract
  amendments. Binary encoding and wholesale JSON removal are not release
  requirements.
- Separate faster full verification from scoped or reused verification.
  Faster full verification may proceed independently while preserving full
  coverage. For scoped or reused verification, decide the component boundary,
  trusted expected digests, dependencies and invalidation rules rather than
  repeatedly hashing every persisted fact on ordinary reads. Fast subset
  digest computation alone does not establish a verification guarantee.
- Decide whether feature persistence is requested, promotion-only or reusable
  by snapshot and feature identity. This is a stored-artifact policy decision,
  not a parity-only optimization. Finalize reuse keys and invalidation after
  WS3 and WS4 bind the relevant history, knowledge-cutoff, missingness and
  recursive-initialization semantics; snapshot and feature identity alone
  must not be assumed sufficient.
- Measure complete public operations: snapshot creation and sealing, opening
  and verification, membership and session-history reads, and a subsequent
  run on the same snapshot. Attribute hashing separately without presenting
  a component speedup as an end-to-end result; retain detecting integrity
  checks under the selected verification policy.
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

Measured input registered on 2026-10-10 (Cut 11 Workstream 22):

- [the per-run snapshot rehash](../../../dev/bench/notes/rehash_tax_findings.md):
  after Workstream 22 it is about half of a Sharadar momentum run (about 55 s
  per committed run), dense and point-in-time alike, dominated by R row
  formatting of bars; one rehash per walk-forward fold is probably most of
  the walk-forward, and `ledgr_backtest()` hashes twice.

Accepted authority registered on 2026-10-12 (WS5-A):

- the [snapshot-verification synthesis](../rfc/rfc_snapshot_verification_policy_v0_2_2_synthesis.md),
  accepted by the maintainer after a Type 1 final review, binds hash rule 3
  (R-owned column-major binary bytes, seed v2 Section 5), a PID-guarded
  process-local verified set, three read classes, refusal of missing-marker,
  rule-1 and rule-2 snapshots for content use, and two ordered direct
  tickets: the fast rule first with complete-verification coverage retained,
  proof reuse second from a source-derived consumer census. Its
  [conformance spike](../spikes/snapshot_hash_rule_3_conformance_spike/closeout.md)
  closed GREEN on Windows and Ubuntu. WS5-B feature-artifact policy stays
  after WS3 and WS4, as stated above. Sequencing is in the 2026-10-12
  routing amendment under change control.

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

Routed inputs (maintainer, 2026-10-14), found by close reviews and owned by
no ticket:

- three named optimization shapes, which enter by their growth shape (one
  growth probe each, before and after), not by the five-percent profile
  threshold:
  - sweep-candidate assembly subsets the full candidate-feature table once
    per candidate, quadratic in candidates (`R/sweep-persistence-schema.R`;
    WS28 close review). WS7's estimator sweeps make it material;
  - `ledgr_run_store_fetch()` subsets the full equity table once per run
    (WS30 close review);
  - `ledgr_fetch_latest_bars()` issues one query per instrument (WS27 close
    review);
- CI before the release: decide how often the review profile runs in CI and
  which host's timing binds, so that review-profile and cross-platform
  breakage stops surfacing only in nightly runs. The roadmap's "v0.2.2 CI
  strategy review" row has no ticket;
- fast-lane headroom: each cut close records the ordinary fast profile's
  margin against its 112-second gate beside the review ratio.

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
- plotting, print and CI polish unrelated to a release claim;
- broad optimization cleanup without a measured product-path cost; and
- the items deferred to the next release on 2026-10-14 (maintainer):
  - the defensive-code and complexity audit, and the fold split
    (`horizon.md`, the 2026-10-12 architecture entry);
  - a user-facing adoption item: the survivorship-bias article on synthetic
    data and a CRAN target date;
  - the decision on the v0.2.1.0 packet path
    (`ledgr_v0_2_0_2_spec_packet/`).

  The governance cut's roadmap rewrite lists them in the next-release
  section.

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

2026-10-03 maintainer amendment: WS5 explicitly consumes the existing DuckDB
hashing evidence, permits a new hash rule, separates faster full verification
from verification-policy changes, and binds public-operation measurements.
Feature reuse depends on the WS3/WS4 semantics. This clarifies the existing
workstream without adding release scope or authorizing implementation.

2026-10-08 maintainer amendment: the WS2 remainder is finished before the
WS3/WS4 cut. Cut 6 closed WS2's terminal-outcome half; the real-data stoppers
LFB-017 (an eligible member without a price is skipped for that rebalance and
recorded, not a run failure), LFB-023 (an explicit per-fold policy instead of
aborting walk-forward) and LFB-018 (an early exit ends `FAILED`, not
`CREATED`) are cut next. The WS3/WS4 design wave pauses in stage 2 of its
[decision register](../rfc/rfc_history_wave_v0_2_2_decisions.md), which holds
every decision so far and resumes the wave. Two clarifications of existing
scope, not new scope: WS4's exit means every supported built-in and TTR
indicator works on ragged and dense universes; and the WS8 integrated record
is an end-to-end Sharadar run over the full available S&P span, 1998-2026,
with the adapter dropping carried zero-volume bars (LFB-027). The memory budget
of decision 8 remains open in the register (Session E).

2026-10-08 maintainer amendment, after Cut 11 Workstream 21: a small
maintenance cut follows Cut 11 Workstream 22, before the WS3/WS4 cut. It holds
five unowned findings, each needing a ticket:
(1) dense `ledgr_state_reconstruct()` builds its close map by scanning every
bar once per pulse (`ledgr_derived_state_dense_close_map()`, moved verbatim by
LDG-2978), quadratic in pulses, a sibling of Cut 11 finding F1;
(2) the full local suite errors in "demo SMA crossover strategy fails through
active alias classes" (`tests/testthat/test-demo-strategies.R`), unowned since
Cut 10;
(3) LTB-0164 intermittently takes about 13 s instead of 3 s in the fast lane,
open since Cut 9; one stall nearly breaks the 112-second bound, so the cause
is investigated rather than the block moved;
(4) `tools/check-test-gate.R --records` refused three recorded ordinary runs
with "Timing gate requires 1 run(s), received 3", so the tool or
`tests/README.md` is wrong;
(5) walk-forward `experiment_hash` and `session_id` include the snapshot's
generated `snapshot_id`, so identical data sealed twice (same
`snapshot_hash`) yields different session IDs, while contracts.md (identity
layers) lists `snapshot_id` among locators that must not enter `session_id`;
the store path is correctly excluded. The cut decides whether the identity or
the contract wording changes.
Two further findings are routed elsewhere: `ledgr_folds_rolling()` month
arithmetic from the 31st and decision-trace diagnostic volume go to the
[decision register](../rfc/rfc_history_wave_v0_2_2_decisions.md) (Sessions B
and E). Carry over overlapping test windows, first parked in `horizon.md`, was
decided by the maintainer on 2026-10-09 (Type 2, after the Workstream 21 close
review) and implemented in Workstream 21: `carry_test_state` requires ordered,
contiguous test windows.

2026-10-09 maintainer amendment: a point-in-time universe audit runs before
the WS3/WS4 history wave resumes
([charter](../audits/v0_2_2_pit_universe_audit/charter.md)). It describes how
ledgr handles point-in-time universes today, checks that behavior for internal
consistency, and judges it against the accepted design and an external
yardstick. Its preparation (yardstick brief, shared fixture, schema) runs
alongside Cut 11 Workstream 22; its three stages run on one commit frozen
after Workstream 22 closes, each ending at a maintainer gate. Findings route
to tickets, the decision register, horizon or RFC questions; the audit itself
binds nothing.

2026-10-09 maintainer amendment, sequencing after Cut 11: (1) the five-item
maintenance cut recorded above is not cut on its own; it is held until the
audit's Gate 2 and cut together with the audit's Stage 2 defects and contract
corrections as one point-in-time consistency cut, one review cycle instead of
two (the snapshot_id identity item is an audit topic anyway). (2) The WS5
verification-policy design session (wave 2 of section 4) runs right after Cut 11
Workstream 22, not alongside it (maintainer, same day: sequential); it decides
when and what to verify, carrying the walk-forward
rehash finding, while feature-persistence reuse keys stay after WS3/WS4 as
WS5 already states. (3) The two unscheduled Due RFC items are placed:
documentation roles and pin reset with the release documentation work and the
non-gating plotting pass; context-frame retirement with the WS3 cut, which
changes the same strategy surface. The resulting order is: Workstream 22, the
WS5 verification session, Cut 11 close, audit Stages 1 to 3, the consistency
cut, the WS3/WS4 history wave and cut, WS7, the WS6 probe, WS8.

2026-10-10 maintainer amendment, after the point-in-time universe audit
(`inst/design/audits/v0_2_2_pit_universe_audit/`, Gates 1 to 3): the
consistency cut is Cut 12 "Point-in-time consistency" (Workstreams 23 to 26,
LDG-2993 to LDG-3012), including the audit's Stage 3 disclosure and price-basis
items. The history wave's scope widens by the register rows PIT-G-013 (v11
price-input carry must not feed zero returns into return and volatility
features), PIT-G-014 (whether a carry chain equals one continuous run) and
PIT-G-015 (the history start covers mark history and dividend entitlement),
and Session E trims the decision trace only where omitted rows are exactly
reconstructible. WS7 acceptance adds three checks: the estimator's sample on
carried inputs (G-013), the run's dividend status (G-016), and elapsed time
plus peak RSS for the one rule-3 lake rebuild. The memory number is evidence
for the persisted-data execution-placement RFC, not a WS7 optimization gate.
WS8 adds one
buy-and-hold reconciliation of the Sharadar build against the vendor's
dividend-adjusted close (G-025). The Sharadar adapter emits no corporate-action
facts, so every Sharadar result so far excludes dividends; emitting
`ordinary_cash_dividend` facts is a ledgr-research adapter task (G-016,
related LFB-013), and until it lands Sharadar results and the WS7 proof state
"dividends excluded" in their headline. The WS5 verification session was
moved after audit Stage 1 and is next after Cut 12's cut review.

2026-10-12 maintainer amendment, after the Workstream 25 reviews: one
pre-existing defect found by the Workstream 25 close review is routed to the
next ticket cut after Cut 12, where it needs a ticket: `ledgr_sweep_save()`
fails on a feature-map sweep whose candidates each resolve to a single feature
fingerprint (for example `ledgr_feature_map(signal =
ledgr_ind_sma(ledgr_param("n")))` with `ledgr_feature_grid(n = c(2L, 3L))`)
with "canonical_json() received a character input that is not valid JSON"
(`R/sweep-persistence-schema.R`); it reproduces on the pre-Cut-12 tree
be3aaf0a. The `test-demo-strategies.R` failure is already owned by Cut 12
LDG-3007.

2026-10-12 maintainer amendment, routing the accepted WS5-A synthesis:
(1) Cut 13 carries both ordered WS5-A tickets in one workstream and one Type 1
close review: rule 3 first, with complete verification retained, then the
PID-guarded verified set from a source-derived census of current consumers.
Later WS3/WS4 readers join that census when introduced; they do not delay the
accepted reuse mechanism. Cut 13 lands before the WS7 estimator proof and the
WS8 integrated record so that Sharadar evidence is recorded once under the
final snapshot identity, and the ledgr-research lake is rebuilt once under
rule 3 together with the dividend-facts adapter change (G-016). The mapping
that change needs (vendor facts to pin down, the exact fact-row fields, the
non-missing knowledge-time assumption, the split-unit check and the G-025
reconciliation) is parked, non-binding, in
[`horizon.md`](../horizon.md#2026-10-12-adapters-sharadar-dividend-fact-mapping-before-the-ws7-lake-rebuild);
the WS7 cut takes it up with LFB-013 when the rebuild is scheduled.
(2) The `ledgr_sweep_save()` defect routed above also belongs to Cut 13, but
in a separate workstream and close review because persistence correctness and
snapshot verification make different claims. (3) WS5-B is unchanged and
still follows WS3/WS4. The resulting order is: Cut 12 close, Cut 13, the
WS3/WS4 history wave and implementation cut, the lake rebuild under rule 3
with dividend facts, WS7, the WS6 probe, WS8.

2026-10-12 maintainer amendment, pre-CRAN legacy removal: ledgr carries no
backward compatibility before its first CRAN release, as the README already
states ("stored artifacts, database schemas, and APIs may change without a
deprecation cycle, so expect to rerun experiments after upgrading"). v0.2.2
removes the compatibility code that contradicts this: the experiment-store
migration and legacy schema path, the readers that tolerate unmigrated
stores, the saved-sweep schema 1 to 3 readers, identity rule 1, schema-1
valuation and corporate-action policy records, the legacy strategy-provenance
markers, the `fill_model` refusal argument, the `as_tibble(type =)` alias and
the unreachable metric-kernel fallback (an agent inventory on 2026-10-12
counts about 950 R lines and 1,700 test lines). A store, saved sweep, policy
record or identity whose version is not current is refused with one classed
condition that says to recreate it. The current schema is today defined only
inside the legacy path (the LDG-3016 template replays it), so removal starts
with one current-schema definition used by fresh stores, the validator and
the parity test. Route: a focused RFC, because it changes `contracts.md`
promises (older stores, rule-1 sessions, migration, pre-provenance tolerance)
and the accepted snapshot-verification synthesis's legacy-readability clause.
The direction is decided, so the seed skips the research input and the cycle
settles only the refusal gate, the schema authority and the contract text.
The RFC runs alongside Cut 13, which proceeds as accepted and adds no
compatibility beyond what its synthesis binds. The removal cut follows Cut 13
and precedes the WS3/WS4 history wave, so new history code meets only current
shapes. Maintainer, same day, on the RFC response: once no stored format is
kept compatible, the ledgr-research lake is rebuilt after every store-format
change, so the Cut 13 amendment's "rebuilt once" no longer holds. The first
rebuild follows the removal cut, under rule 3 without dividends, so the WS3/WS4
reviews keep their real-data lane. The rebuild is a scripted, timed step whose
time is recorded by the cut that forces it. The resulting order is: Cut 13,
the legacy-removal cut, an interim lake rebuild under rule 3, the WS3/WS4
history wave and implementation cut, the lake rebuild with dividend facts,
WS7, the WS6 probe, WS8.

2026-10-12 maintainer amendment, codebase hygiene in the legacy-removal cut:
the cut carries a third workstream, one claim and one Type 1 close review,
because its instruments are the ones the removal already needs and because
the WS3/WS4 code should land under gates rather than ahead of them.
Measured on 2026-10-12: 421 distinct classes are raised by `rlang::abort()`
and 131 are documented in `R/condition-reference.R`; 647 of 1,623 functions
have exactly one call site; about a dozen non-exported, non-S3 functions
have no caller (`ledgr_estimate_bars_per_year()` was cited as live by two
reviews this week); no lint or style configuration exists; 248 of 1,096
test blocks carry a registered claim. The workstream (1) adds
`tools/check-codebase-contracts.R`, report-only at first, whose census of
openers, version branches, uncalled functions and undocumented classes
serves Workstreams A and B; (2) after those workstreams land, turns the
first two checks into failing blocks of a `test-codebase-contracts.R` in
the fast profile, registered as claims with a structural-detector oracle
and a gut, following `test-documentation-contracts.R`: every non-exported,
non-S3 function has a call site, and every class raised by `abort()` is
documented in the condition reference or carries an internal prefix; (3)
adds a `.lintr` and a separate lint job to the CI workflow, advisory for one
cut and then blocking, and runs styler once in its own commit immediately
after the removal lands, when the tree has already been touched everywhere;
(4) adds one Verification Contract clause naming the structural detectors,
with a small Type 1 review because it defines claims; and (5) adds the helper
rule to `inst/design/manual/optimization_coding_style.qmd` as a review
criterion beside the seven shapes: a function exists because it has a
contract someone can name or a second caller. Deferred to the release after
v0.2.2, report-only until then: enforcing the export census (168 exports
and 84 S3 methods, those unused by any man example, vignette or article
become internal) and the test-oracle rule for the 848 unregistered blocks,
because both touch surfaces the execution-core consolidation changes.
Parked in `horizon.md` under the 2026-10-12 infrastructure entry, which
also holds one more item for this workstream: a documentation-generation
entry point that pins `LC_COLLATE` to `C` before `roxygen2::roxygenise()`,
after a regeneration from a differently collated shell reordered
`NAMESPACE` and 27 unrelated Rd files without content change (`90a701d1`).

2026-10-12 maintainer amendment, the one-execution-mode probe: the probe
shaped in `horizon.md` (the 2026-10-11 execution entry's addendum) runs in
v0.2.2, after the legacy-removal cut and its interim lake rebuild and before
the WS3/WS4 history wave resumes its implementation cut. It is a probe under
`spike_protocol.md` Section 1, not a spike with a charter: one script,
`dev/spikes/one_execution_mode/probe.R`, runs the registered dense fixtures
through the availability path with an implied calendar, full membership, no
facts and a never-stale valuation policy, diffs fills, ledger, equity,
positions and metrics against today's dense path, times the dense peer
fixture on both paths, and includes a dense fixture with one missing bar;
`probe_findings.md` is its one-page record. It binds nothing and changes no
product code. Its result routes: green, with the dense peer fixture not
materially slower, means the WS3/WS4 implementation cut builds history on
the availability path only and the post-v0.2.2 consolidation is a deletion;
a dense-only branch inside the fold, context or guard, or a material
slowdown, means the history cut serves both modes and the consolidation
opens as an RFC. The unification itself stays after v0.2.2 (roadmap row
"Post-v0.2.2 execution-core consolidation"). The resulting order is: Cut
13, the legacy-removal cut, the interim lake rebuild under rule 3, the
one-execution-mode probe, the WS3/WS4 history wave and implementation cut,
the lake rebuild with dividend facts, WS7, the WS6 probe, WS8.

2026-10-13 maintainer amendment, planning-document cleanup after the probe:
the roadmap no longer works as a planning document, and this plan's
change-control log has become the only place the current order lives, restated
by each amendment. One governance cut, after the one-execution-mode probe
and before the WS3/WS4 implementation cut, rewrites both together, scans
`horizon.md`, sweeps the central governance files, folds the probe result
in, and applies the governance-lifecycle synthesis
(`rfc/rfc_governance_lifecycle_v0_2_2_synthesis.md`, accepted 2026-10-14;
Sections 2 to 7 own the rules and Section 7 the wording). Its four
workstreams each carry one claim and one Type 1 close review:

1. Rules and guard: the accepted rules go into `rfc_cycle.md`, the design
   index and `AGENTS.md`, and the governance guard lands in report mode with
   its reviewed baseline. Check mode starts no earlier than the cut after
   this one, and only once workstream 4's header normalization and the
   reviewed baseline and fixtures exist (synthesis Section 6).
2. `contracts.md`: the present-tense pass and rule-group addresses, and
   reconciliation of the `decisions.md` bridge with its back-links.
3. Planning documents: the roadmap and remaining-order rewrites and the
   horizon scan.
4. Records: synthesis status headers, the packet `README.md` trim and the
   evidence form for open tickets.

Two parts of the synthesis do not wait for this cut. M1 (the 0.5 gate is
retired; the ratio of independent verdicts to completed tickets is recorded
at cut close and as a packet total; a third correction round on one
workstream goes to the maintainer) and M2 (a review that returns findings
writes a file in the owning packet) apply from the first review after
acceptance, so they govern the rest of Cut 14 (synthesis Section 5).
Acceptance preceded the history-wave amendment to v11, so that amendment
is the first supersession carrier under the synthesis's rules (Section 7);
the history wave owns it. The bullets below are the scope the cut inherits.

- Roadmap: the milestone table holds releases only, one row each, in release
  order. Shipped releases keep date, a one-sentence goal and the packet link.
  v0.2.2 gets one row with its goal and a link to this plan, without
  cut-by-cut status. A short next-release list names the themes already
  scheduled for it, and a few lines state later direction (paper trading,
  operations, small-scale live trading). The roughly thirty topic rows leave:
  done rows are deleted because their packets record them, parked rows move
  to `horizon.md` or the RFC pipeline, and each generic "v0.2.x Planned" row
  is checked (corporate actions shipped in v0.2.1.0 as equity corporate
  actions). A row is at most two sentences and changes only when a release
  opens or ships; a documentation-contract test may pin that.
- This plan: one current "Remaining order" section, each step with a
  one-line reason and its owner, becomes the only place the sequence lives.
  Each change-control amendment shrinks to one dated line naming its source,
  and the amendment narratives move to a history file, as
  `roadmap_history.md` did for the roadmap.
- Horizon scan (maintainer, 2026-10-13): every entry under `Open` in
  `horizon.md` (85 entries over about 4,100 lines) is classified against the
  shipped packets, `tickets.yml`, the RFC pipeline and `contracts.md` as
  shipped, superseded, promoted (owned by a ticket, an RFC row or this plan)
  or genuinely open, with the evidence for each class named. Shipped and
  superseded entries move to `horizon_archive.md` behind a redirect stub, a
  promoted entry keeps only a pointer to its owner, and the genuinely open
  entries stay. The scan records the classification table, so the
  maintainer can see in one page what has shipped and what is still open.
- Governance-file sweep (maintainer, 2026-10-13): each `decisions.md` row is
  checked against `contracts.md`, and a row whose rule a standing heading
  already holds leaves with that heading cited, which is the exit its own
  rule requires and which earlier closeouts skipped. Candidates include the
  four v0.1.9.5 batch rows, equity corporate actions, accounting-core
  consolidation, testing architecture and the feature-map read surface.
  The packet `README.md` is trimmed to its role, the design index
  `README.md` and `AGENTS.md` are checked for stale entry points, and the
  sweep records what it removed and where each item now lives. Stale
  synthesis status headers are corrected: historical-projection v10 still
  reads "ACCEPTED" although v11 replaced it, and the snapshot-verification
  synthesis does not show at its top that the accepted legacy-removal
  synthesis (Section 5) amends its legacy-readability rule, which the Cut 14
  ticket cut applies. The cut applies the accepted synthesis's header and
  notice rules to these records.
- Contracts present-tense pass (maintainer, 2026-10-13): after Cut 14 merges,
  `contracts.md` states each current rule in the present tense and moves
  release history out (41 lines cite release versions, plus schema-number
  history and about 24 legacy or historical mentions); history belongs in
  NEWS and the packets. Rewording can change a rule, so its workstream's
  Type 1 close review compares old and new text clause by clause, and the
  documentation-contract pins move with the sentences they pin.

Not a package design change. The contracts pass and the guard define
claims, so the work is a cut with close reviews, not a documentation chore
(maintainer, 2026-10-13, changed from the chore first scheduled). The
resulting order is: Cut 13, the legacy-removal cut, the interim lake rebuild
under rule 3, the one-execution-mode probe, the governance cut, the WS3/WS4
history wave and implementation cut, the lake rebuild with dividend facts,
WS7, the WS6 probe, WS8.
2026-10-14 maintainer amendment, unowned-debt routing: issues that no ticket
owned were routed. The identity-hashing collation defect and the
identity-type looseness go to Cut 14 LDG-3036 (`tickets.yml`). The store gate's
per-open cost is accepted as a component miss: about 1.1 ms per store open,
under 0.1 percent of any public call, with end-to-end clocks unchanged
(maintainer, 2026-10-14; recorded in the WS29 decisions). Three review-found
hot spots, CI cadence and fast-lane headroom go to WS8 (above), and the
audit, fold split, adoption item and packet path to the next release
(Section 5).
