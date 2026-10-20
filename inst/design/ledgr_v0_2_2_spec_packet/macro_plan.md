# ledgr v0.2.2 Macro Plan

**Status:** Maintainer planning record; accepted on 2026-10-03. Cuts 1 through
15 are complete and accepted. The WS3/WS4 history wave is the current work.
Its shared history-start decision replaces Cut 9's temporary rule.

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
- First, decide whether ledgr needs to keep computed features at all
  (maintainer, 2026-10-14). The in-process feature cache (`R/feature-cache.R`:
  an unbounded session registry keyed by snapshot, instrument, feature
  fingerprint, engine version and exact window, used only by committed runs)
  and the default `persist_features = TRUE` writes were specified early and
  never measured. Deletion is the default outcome. A probe keeps either one
  only if it clears all three conditions, set in advance:
  - its best case (repeated runs of one experiment in one session for the
    cache; a named reader of the stored rows for persistence) shows at least
    a ten percent end-to-end speedup;
  - the correctness cases are clean: a feature function whose behaviour
    depends on a captured variable (the fingerprint excludes captures), an
    engine-version change, and two snapshots with the same hash;
  - the memory it retains after a run is acceptable at Sharadar scale.

  The probe reads the existing `feature_cache_hits` and
  `feature_cache_misses` telemetry, and runs alternating fresh-process
  pairs with and without each mechanism on:
  - a single cold run;
  - the best case above;
  - a walk-forward;
  - a Sharadar-scale run, measuring retained memory.

  Results must stay byte-identical. What fails the conditions is removed in
  a pure-deletion ticket. Reuse keys are designed later in WS5-B only for
  what survives.
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
  churn, a memory budget and feature-cache lifetime (whether a cache exists
  to bound is decided first by the WS5 feature-keeping probe). It is
  scheduled as the next release's memory release (roadmap, "Post-v0.2.2
  memory optimization release"). v0.2.2 keeps Cut 5 and the WS5
  feature-persistence decision;
- plotting, print and CI polish unrelated to a release claim;
- broad optimization cleanup without a measured product-path cost; and
- the items deferred to the next release on 2026-10-14 (maintainer):
  - the defensive-code and complexity audit (`horizon.md`, the 2026-10-12
    architecture entry). The fold split was moved into v0.2.2 later the same
    day (Section 7, fold phase extraction);
  - a user-facing adoption item: the survivorship-bias article on synthetic
    data and a CRAN target date;
  - the decision on the v0.2.1.0 packet path
    (`ledgr_v0_2_0_2_spec_packet/`);
  - the install floor as an adoption barrier: `R (>= 4.6.0)` together with
    the hard DuckDB dependency. Lower the floor, or state the reason in the
    README;
  - the documentation surface, paired with the export census: 39 of 156
    help pages without examples, 6 using `dontrun`, and no `@inheritParams`
    across 495 hand-written `@param` blocks;
  - NEWS.md (1,544 lines) collapsed to one first-release entry, as part of
    CRAN preparation;
  - for the complexity audit: scattered numeric tolerances, the store-open
    retry helper (50 attempts with `gc()`, now behind the gate) and the five
    test files over 1,000 lines besides the documentation-contract test.

  The governance cut's roadmap rewrite groups them as deferred Section 5
  inputs in the next-release section; this section remains their detail.

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

## 7. Remaining order

Cut 15 is closed: Workstreams 32 through 39 are complete and accepted. The
WS35-plus-WS39 joint gate is satisfied, so the WS3/WS4 history wave is the
current work. Resume from the decision register's **Resume here** section.

1. Cut and implement the accepted v12 successor through H5 and H6.
2. Run WS7 product proof; WS6 proceeds independently only if its probe
   promotes it.
3. Finish WS8 residual performance work and integrated release evidence.

The history wave consumes the normalized governance record, final fold
structure and WS39 schema-120/rule-3 real-data evidence. Old schema-119 stores
remain unreachable evidence, not compatibility targets. `tickets.yml` alone
binds exact dependencies and status.

<a id="history-wave-execution-plan"></a>

### History-wave execution plan

This section sequences the wave; it does not restate its semantic decisions.
The [history-wave decision register](../rfc/rfc_history_wave_v0_2_2_decisions.md)
owns the completed H2 dispositions, the accepted v12 successor owns the
resulting history semantics, and `tickets.yml` owns implementation. V11
remains the immutable derivation record.

Maintainer decision, 2026-10-16: Cut 15 removed feature retention, froze dense
mode, introduced schema 120 and identity rule 3, and replaced the old fold body
with envelope E and stages P1 through P5. The stage-3 carrier is therefore a
consolidated v12 synthesis rather than another narrow amendment layer over
v11. This does not restart the RFC cycle: the existing Type 2 work and this
register's stage-2 decisions remain its design inputs.

Progress, 2026-10-16: H0 and H1 are complete with final independent verdicts
PASS. H0 is the reviewed v11 current-tree drift map at `16f415cd`; H1 is the
reviewed `ledgr-research` aggregate evidence bundle at `e07e89d`. H2 is also
complete after its evidence wave and two focused peer-review passes. H3 and H4
are complete, and the maintainer accepted v12 on 2026-10-16. H5 is current.
This plan keeps only the sequence.

#### H0. Reconcile the current tree with v11

Produce one clause-level drift map with exactly four dispositions: retain,
rewrite for the current architecture, supersede by an accepted history-wave
decision, or retire because its mechanism was deleted. Cover at least:

- the proposed `ledgr_history_frame()` surface and its matrix adapter versus
  v11's `ctx$window()` contract;
- availability-only history, with full membership represented on that path,
  versus v11's two-mode assumptions;
- deletion of the feature cache, `persist_features`, durable feature rows and
  the features table;
- the fold envelope and P1-P5 ownership, including P2-local public frames and
  the prohibition on data-frame carrier state;
- schema 120, identity rule 3, snapshot hash rule 3 and refusal of older
  stored formats;
- current price-basis defaults, availability policy and condition vocabulary;
  and
- obsolete implementation anchors, measurements and ticket references.

The map changes no semantics. Any newly discovered semantic choice goes into
the decision register before v12 is drafted. Exit: every load-bearing v11
clause has one disposition and no deleted mechanism remains an operative
dependency.

#### H1. Complete the real-data inputs

Use the accepted WS39 schema-120 snapshot; do not design another lake or copy
private rows into package evidence. Extend its aggregate evidence with:

- gap-length distributions after the adapter drops carried zero-volume bars;
- fact refusals, delisting reasons and correction-chain shapes;
- the current history-preparation inputs and fold-phase time/RSS baseline for
  one run; and
- a representative local-worker memory baseline, including parent and worker
  RSS and materialization of immutable history inputs.

This stage supplies evidence for gap thresholds, Session E's resource budget
and Session F. It does not pretend to benchmark a public history API before
that API exists. End-to-end history-surface measurements belong to H6.

H0 and the non-private parts of H1 may proceed in parallel. The later
dividend-facts rebuild remains with the adapter and WS7 owners.

#### H2. Finish stage-2 decisions

**Complete 2026-10-16.** The H0 questions, Sessions D-F and every remaining
consider row now have an accepted decision, durable deferral, rejection or
named owner in the decision register. Two focused peer-review passes narrowed
the proposals without requesting another spike.

Decide Session D (bounded versus recursive indicator history, gap transitions,
readiness, identity and tolerance), Session E (representation, size guard,
single-run and worker memory budget, and decision-trace volume), and Session F
(correction chains informed by H1). Dispose of the remaining consider-level
rows in one final batch, including fold continuity, civil-date boundaries,
carried-price return semantics and mark/entitlement history.

Session E starts with two ordered, no-product-change spikes. The H1
two-candidate/two-worker measurement is already the current `mirai` baseline;
the first spike does not ask whether ledgr should adopt `mirai` again. It
attributes the existing executor's parent and worker cost by measuring task
size, serialized bytes, candidate-invariant payloads, promise retention,
dispatch and result transfer, and parent, daemon and process-tree memory. It
compares sequential execution, current `mirai` dispatch and an experimental
arm that stages immutable inputs once per persistent daemon.

The second spike uses that payload inventory to test `mori` only for the real
immutable ledgr substrate: bars, feature projection, availability facts and
pulse axes. It compares current `mirai`, staged-daemon `mirai` and
`mirai` plus `mori` on identical candidates. It records result and identity
parity, wall time, parent and per-worker memory, process-tree memory, private or
unique bytes where the host exposes them, materialization and copy-on-write,
and cleanup after success, interruption and worker failure. A Windows record
is binding for the observed H1 problem; a portable smoke record checks that a
candidate is not Windows-only.

Both spikes use private experimental hooks and add no public API, executor
abstraction or package dependency. The first closes with an attributable
payload map; the second closes with an adopt, reject or narrow verdict. A
shared-memory design is eligible only if it materially reduces unique peak
memory without changing results, identity or failure behavior and without
requiring disproportionate machinery. Session E then chooses the history
representation, size guard and worker-memory budget from those results. If
neither arm helps, the decision records the supported worker limit and routes
the remaining executor-memory problem rather than hiding it in the history
implementation.

Evidence status (2026-10-16): Sessions D, E0, E1 and F completed their
registered probes and independent reviews. The indicator census binds no
numeric class threshold; the correction-chain matrix exposes the exact
constructor/runtime policy choices; staged ordinary-R daemon inputs reduced the
sampled two-worker burden; and mori was rejected for the current two-worker
shape because its structural ceiling is only one avoidable 44.9 MB copy, about
3--4% of the measured total. The closeouts are the durable evidence inputs in
`inst/design/spikes/history_indicator_conformance_spike/`,
`history_mirai_payload_attribution/`, `history_mori_feasibility/` and
`history_correction_chain_spike/`. Their proposals were adjudicated into the
register; no product implementation starts from a spike verdict alone.

Session E was decided on 2026-10-16 after focused peer review. One immutable
prepared substrate replaces `bars_by_id`, `bars_mat` and
`static_bars_views`; staged ordinary-R inputs serve each sweep daemon; `mori`
is not adopted; and the supported availability-history claim covers one and
two local workers without making worker count part of identity. The segment
guard is `max(4 * facts, 16)`, subject to the full Sharadar census. The memory
gate is a paired H6 comparison against the current tree, not a fixed limit
copied from the coarse H1 record. The full logical decision trace remains;
H6 measures its read-side cost.

Exit: every register row has an accepted decision, durable deferral with a
trigger, rejection with a reason, or named downstream owner. No implementation
choice is left to select history semantics accidentally. Session E closed only
after both spike verdicts and their consequences were recorded.

#### H3. Write the consolidated v12 synthesis

**Accepted 2026-10-16.** The
[v12 synthesis](../rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md)
is the single proposed successor built from the completed register and drift
map. Its formal H4 review returned eight Type 1 document findings; the focused
confirmation returned `PASS_AFTER_PATCHES`, the two bounded patches are
applied and the maintainer accepted the synthesis. It is the implementation
authority for Cut 16.

V12 carries forward the still-valid two-clock, causality, missingness,
barrier, disclosure and numerical-correctness rules from v11; incorporates
the accepted register decisions; and describes the post-Cut 15 architecture
directly. It binds the public history object, on-demand frame and matrix
adapter, one history-start rule, indicator-history classes, preparation and
fold-stage ownership, identity inputs, resource guards and detecting evidence.

V12 must not recreate feature retention, promise dense-mode implementation,
make factor/prediction capture part of WS3, or add model lifecycle, scheduling
or optimizer catalogues. Acceptance makes v12 operative and leaves v11 as the
derivation record.

#### H4. Run the final design review

**Complete 2026-10-16.** The formal review returned `CHANGES_REQUIRED` with
eight Type 1 document findings and no Type 2 question. Focused confirmation
returned `PASS_AFTER_PATCHES`; its two bounded patches are applied.

Run one adversarial Type 1 review of v12 against the drift map, the completed
decision register, current contracts and the current tree. A new product
choice returns to the maintainer as Type 2; a fidelity or ownership defect is
patched in place. Exit: every retained rule and implementation obligation has
one owner and a failure-sensitive oracle.

#### H5. Cut WS3/WS4 implementation

**Cut 16 drafted 2026-10-16.** Workstreams 40 through 44 and LDG-3057 through
LDG-3071 are the executable H5 plan. The cut starts with the factual and
identity prerequisite, then one shared substrate, then permits bounded
parallel product work:

```text
WS40 causal facts and rule-4 identity
  `-- WS41 single causal substrate and staged worker inputs
        |-- WS42 public history and continuous windows
        `-- WS43 indicator history semantics
              `-- WS44 integrated H6 proof and teaching
```

WS44 also depends on WS42; ticket LDG-3068 names both branch-end
dependencies. The diagram shows ownership, not permission to skip that join.

**Amended 2026-10-18 (Cut 16 decision 17): simplify before proving.** WS41
and WS42 were accepted with their scale defects corrected, but the
[Cut 16 antipattern review](cut16_antipattern_review.md) showed complexity
accumulating: facts held twice in the
substrate, unread bar planes, five membership compilation paths, eager
evidence in every history read and a growing count of availability/dense
branches. WS46 therefore runs after WS43 and before WS44, so WS44 measures and
proves one simplified system rather than proving the current shape and
re-proving after a later cleanup. WS45 collects the WS40 fact-pipeline
follow-ups and is independent of the history branches.

```text
WS42 (accepted) --.
                  +-- WS46 history representation simplification
WS43 -------------'     (map, one fact representation, one membership compiler)
                          `-- WS44 integrated H6 proof and teaching
WS45 WS40 fact-pipeline follow-ups (independent; before Cut 16 closes)
```

Rules adopted with the amendment: a new fast path needs a differential test
against its canonical path and a stated removal or merge condition (recorded
in `optimization_coding_style.qmd` by LDG-3074); the codebase census counts
execution-mode branches so additions are visible in review; and parallel
workstreams reserve disjoint LCL/LTB ID ranges in their briefs.

The common substrate owns the two clocks, cutoff, axis, missingness evidence,
identity and inclusion/exclusion reasons. The public adapter is not a second
reader. Indicator tickets may not invent another hydration rule. The cut also
owns the already-routed rolling-month, carry-window, mark-history and
entitlement fixes that depend on the common start boundary.

#### H6. Close the history wave

The implementation must demonstrate:

- causal history on both changing- and full-membership availability paths;
- parity across run, sweep, pulse inspection and walk-forward evaluation;
- supported built-in, external and custom indicators under their declared
  bounded or recursive contracts;
- completion of the full 1998-2026 Sharadar workload without history-related
  stops;
- a full-build segment census showing that the default guard accepts the
  Sharadar reference build and reports aggregate and maximum counts by family;
- a structural single-copy check showing that the prepared payload and worker
  tasks do not retain parallel `bars_by_id`, `bars_mat` and
  `static_bars_views` representations;
- a fail-closed staged-identity check in which a missing or altered invariant
  is refused by the daemon;
- paired current-tree and history-enabled memory records on the same H1
  workload, host and approximately 0.2-second sampler, with three repeats and
  preparation and fold peaks separated. Single-run parent peak, two-worker
  parent peak and summed parent-plus-daemon private commit must each stay
  within 10%, or receive an explicit maintainer exception and routed limit;
- the post-substrate `mori` trigger calculation,
  `(workers - 1) * staged_invariant_bytes / total_private_commit`, with shared
  memory reopened only at or above 10%;
- read-side peak memory for `ledgr_results(bt, "diagnostics")` and
  `ledgr_run_explain()` on the full logical decision trace, with a material
  problem routed to WS8; and
- teaching of the final history-to-estimator-to-weights-to-target workflow.

Durable factor evidence, trained-model lifecycle, scheduling, generic
portfolio constructors, dividend-facts work, broad RAM restructuring and the
execution-core consolidation keep their existing owners. They do not expand
the history cut merely because they consume history later.

<a id="execution-core-consolidation"></a>

### Execution-core consolidation

The later accepted release-line decision in commit `4397f58f` supersedes Cut
15 decision 9's earlier both-modes wording for current planning. History is
built on the availability path only; dense mode is frozen to fixes with no new
features or branches; execution-core consolidation is committed before the
first CRAN release. "Dense universes" in history design means full-membership
shapes on the availability path. Historical probe evidence and the original
Cut 15 decision remain unchanged as evidence of the decision sequence.

**Inputs recorded during Cut 16 (2026-10-18).** The history wave adds
availability/dense branches that consolidation must remove rather than
re-justify: WS41 and WS42 representation switches in the fold engine,
runner, sweep, walk-forward and precompute (counted per file by the census
from LDG-3074), the walk-forward `is.null(history_substrate)` split (the one
semantic branch, bound by Cut 16 decision 16), and the WS40 Date-boundary
branches in experiment, window and precompute construction. Consolidation
should start from the LDG-3074 representation map and branch census.

**collapse primitives (maintainer, 2026-10-20).** When consolidation merges
the two carry implementations (C-1 vector, C-2 matrix; audit
`cut16_architecture_audit.md`), use the collapse path, including
`na_locf(set = TRUE)` where an in-place fill avoids a copy. Then check the
hot paths it touches for collapse primitives ledgr does not use yet
(`fmatch()`/`%iin%` for base `match()`/`%in%`, `whichv()`/`whichNA()`,
`ss(check = FALSE)`, `setop()`), following the collapse developer guidance
(`fastverse.org/collapse/articles/developing_with_collapse.html`). Adopt one
only where a profile shows the call in a hot path and the result stays
byte-identical under `ledgr_with_collapse_deterministic()`; no blanket swap.
History frames already use the article's manual list-to-data-frame
construction, so `qDF()` brings no speed gain there.

<a id="deferred-history-simplification"></a>

### Deferred history simplification

Cut 16 decision (17) routes these beyond WS46:

- **Lazy evidence in history reads.** A full-lookback `ledgr_history_frame()`
  read materializes every evidence plane eagerly (about 8.6 times its value
  bytes at the H1 shape). Making evidence lazy changes the v12 Section 3
  result and needs a maintainer decision, probably a short RFC. LDG-3069
  supplies the measurements; implementation is not scheduled before that
  decision.
- **Corporate-action settlement state as data.** The carried walk-forward
  chain rebuilds the previous window's settlement plan from its ledger.
  Carrying that state as an explicit object is considered with LDG-3073 if
  settlement code changes there, otherwise at execution-core consolidation.
- **Availability/dense branch removal** belongs to execution-core
  consolidation above.

<a id="post-gate-live-routes"></a>

### Post-gate live routes

- **Dividend facts:** LFB-013 supplies adapter interpretation; the later
  dividend-facts lake rebuild and WS7 own carried-input G-013, dividend-status
  G-016, build-time, and peak-RSS checks. WS8 owns G-025. Until those facts
  pass end to end, the headline explicitly excludes dividends.
- **Growth shape:** WS8 owns custom-function indicator slicing, result/trade/
  print replay, and sweep/walk-forward phase timing in its regression suite.
- **Availability core:** the WS3/WS4 cut decides optimization placement. WS4
  owns strict TTR work per gap-bounded segment; it is not a generic TTR layer.
- **Run telemetry:** WS8 decides whether detailed per-pulse telemetry
  (`ledgr_backtest_bench()`, `execution$telemetry_stride`, the session
  registry) stays, becomes opt-in or goes, and how `t_pre`, `t_loop` and
  `t_post` reach their consumers (maintainer, 2026-10-15). Inputs: the WS38
  stage profile and the history wave's use of the components; consumers
  include the compiled-accounting probe and the Sharadar stage bench.
  Telemetry is unchanged until then, so history-wave baselines stay
  comparable. A change to the contract or public surface is RFC work,
  scheduled when WS8 opens.

<a id="7-change-control"></a>

## 8. Amendment redirects

The superseded sequencing narratives remain content-addressed in
[macro-plan history](macro_plan_history.md). These dated lines are historical
navigation, not a second current order.

- Base policy — [change-control scope before dated amendments](macro_plan_history.md#base-change-control-policy).
- 2026-10-03 — [WS5 consumes the DuckDB projection design](macro_plan_history.md#amendment-2026-10-03-1).
- 2026-10-08 — [WS2 remainder precedes the history wave](macro_plan_history.md#amendment-2026-10-08-1).
- 2026-10-08 — [post-Workstream-21 sequencing](macro_plan_history.md#amendment-2026-10-08-2).
- 2026-10-09 — [point-in-time universe audit insertion](macro_plan_history.md#amendment-2026-10-09-1).
- 2026-10-09 — [post-Cut-11 five-item sequence](macro_plan_history.md#amendment-2026-10-09-2).
- 2026-10-10 — [post-audit correctness gate](macro_plan_history.md#amendment-2026-10-10-1).
- 2026-10-12 — [Workstream-25 review routing](macro_plan_history.md#amendment-2026-10-12-1).
- 2026-10-12 — [WS5-A synthesis routing](macro_plan_history.md#amendment-2026-10-12-2).
- 2026-10-12 — [pre-CRAN legacy-removal cut](macro_plan_history.md#amendment-2026-10-12-3).
- 2026-10-12 — [codebase hygiene](macro_plan_history.md#amendment-2026-10-12-4).
- 2026-10-12 — [one-execution-mode probe placement](macro_plan_history.md#amendment-2026-10-12-5).
- 2026-10-13 — [planning-document cleanup](macro_plan_history.md#amendment-2026-10-13-1).
- 2026-10-14 — [unowned-debt routing](macro_plan_history.md#amendment-2026-10-14-1).
- 2026-10-14 — [fold phase extraction](macro_plan_history.md#amendment-2026-10-14-2).
- 2026-10-14 — [feature-keeping probe placement](macro_plan_history.md#amendment-2026-10-14-3).
- 2026-10-14 — [one-execution-mode result](macro_plan_history.md#amendment-2026-10-14-4).
- 2026-10-14 — [growth-shape matrix result](macro_plan_history.md#amendment-2026-10-14-5).
- 2026-10-14 — [feature-keeping result](macro_plan_history.md#amendment-2026-10-14-6).
- 2026-10-14 — [Cut 15 ownership and design-tree decision](macro_plan_history.md#amendment-2026-10-14-7).
