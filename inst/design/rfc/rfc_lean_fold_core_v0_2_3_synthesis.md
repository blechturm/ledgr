# Lean Fold Core: Decision Synthesis

- Mode: Decision synthesis, RFC cycle stage 7; Codex; 2026-11-03.
- Status: accepted by the maintainer on 2026-11-03 with the
  [acceptance amendment](#amendment-maintainer-2026-11-03-acceptance-conditions)
  (four maintainability rules; Q5 decided as no cap). The independent stage
  8 [final review](rfc_lean_fold_core_v0_2_3_final_review.md) returned
  PASS_AFTER_PATCHES; its patch P1 is applied. This document starts no
  implementation.
- Baseline: `release/v0.2.3`, `df7ad1aeac0d0a939b19310b092e9282b6635ada`.
- Read in order: [historical v1](rfc_lean_fold_core_v0_2_3_seed.md),
  [response](rfc_lean_fold_core_v0_2_3_response.md),
  [response review](rfc_lean_fold_core_v0_2_3_response_review.md),
  [v2](rfc_lean_fold_core_v0_2_3_seed_v2.md).
- Citation aliases: `macro` = `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`;
  `floor/` = `dev/spikes/r_floor/`; `fifo/` = `dev/spikes/lean_fifo/`.
  Other R paths are repository-relative. Source citations use this baseline.
- Final-review revision (2026-11-03): added the acceptance amendment's
  addressed supersession table and local notices; decisions unchanged.

## 1. Decision And Its Evidence

**Amended 2026-11-03:** the [acceptance amendment](#amendment-maintainer-2026-11-03-acceptance-conditions)
retains family-sized reviewed growth and replaces this section's aggregate-cap
qualification with Q5's no-cap decision.

**ADOPT bounded B with the constraints below:** grow a lean R core under
`dev/lean_core/`, review it in family-sized workstreams against a pinned current
core, and promote it with one atomic package switch. Do not ship a partial second
engine, an option selecting cores, or a fallback to the retired core.
V2 is the chosen direction; it is not an authorization for uncapped growth.

The response's prerequisite has advanced: the new context seam exercises changing
axes/history with fresh views, and the FIFO spike prices actual lot transitions.
That justifies proceeding beyond the original binary-position floor.
It does not prove stage structure causes the overhead, that option A cannot reach
the same result, or that a complete lean engine will attain the spike timings.
B is selected to optimize the whole data flow without temporary production
adapters. Its integration risk remains real; finite parity is never exhaustive.

The response review is adopted on ownership, exact parity, interaction/failure
coverage, bounded development and explicit plan changes. Two qualifications remain:
the new seams cover selected surfaces, and bounded preparation is not yet proved.
V2's Section 3 fixed-basket row still inherits the original mixed clock boundary
(`floor/run.R:39`, `:47`, `:57`); it is not a matched complete-engine estimate.

Local verification, R 4.6.1/collapse 2.1.8/DuckDB 2.0.0, Windows,
source loaded with compilation disabled; no new timing or native build:

| Existing probe rerun | Observed |
| --- | --- |
| 30 x 250 P2, history off and on | Zero selected-field differences over 250 pulses each; serialized retained view unchanged |
| 30 x 250 P1/P3-P5 seam | 2,717 fills; its ten fill and four equity fields identical |
| FIFO random streams, 12 instruments, seeds 1-5, 400 blocks each | Zero book/eight-applied-field differences; zero canonical fallbacks |
| Same FIFO streams, existing plain-sum gut | 395, 397, 399, 399, 398 differing blocks |

These reproduce meaningful positive and negative evidence. They do not certify
the switch, the private reference, openings/dispositions in the lean kernel, or
memory at scale. P2 compares un-named selected fields (`floor/run3.R:26`);
the equity comparator selects four fields (`floor/seam_p35.R:94`), excluding
public `running_max` and `drawdown` on this build. V2's "every equity column"
must be read as every compared column, not whole-schema conformance.
The recorded 2.2-2.5x FIFO gain and profiled stage shares remain spike evidence.
No compiled/quickr experiment was rerun. Reproduction is embedded below because
the brief permits only this synthesis file.

## 2. Binding Boundaries (D1)

The [typed-fold-carrier synthesis](rfc_typed_fold_carrier_v0_2_3_synthesis.md)
Sections 3.1-3.6, [durable-records synthesis](rfc_per_pulse_durable_records_v0_2_3_synthesis.md)
Sections 2-7, and [strategy-authoring D2](rfc_strategy_authoring_api_v0_2_3_synthesis.md#d2-position-facts-follow-the-canonical-book)
remain binding. This synthesis does not weaken them or create a new public API.

Keep one immutable causal-history owner, positional run/context axes, P1-only
substrate access, a cutoff-bound P2 view without execution data, exclusive mutable
buffers, frozen retained public views, and unchanged stop/publication ordering.
The current separation is `R/fold-engine.R:1884` and `:1917`.
Flattening code does not abolish these semantic boundaries. Carrier construction
and callback-output validation still apply; trusted inputs may avoid duplicate
checks, but mutable/new inputs are checked at their introducing boundary.

Use the existing snapshot sealing/verification, registration, preflight, feature,
cost/risk, publication, reader and orchestration services. Preparation storage may
change inside the common substrate's implementation; its identity, ownership and
history semantics may not. Do not duplicate those services to make a fast harness.
Fixed baskets use prepared constants in the same semantics, not another mode.
The real strategy callback, parameters, helper/state contracts and RNG behavior
must work; a stubbed strategy-result constructor is not the production boundary.

Keep WS15's exact logical diagnostics, irreducible instruction presence and
sizing/intent evidence, logical sequence positions and filtered read behavior.
No strategy/cost/risk/indicator code executes on result reads. Retire resume only
as WS15 decides: preserve run idempotence and completion-based publication recovery.
No schema/identity change is authorized here beyond accepted changes in its
owning RFC; any additional requirement returns for explicit disposition.
Pre-CRAN format changes bump the version/fingerprint and refuse older stores;
there is no migration, compatibility argument, old-format reader or silent repair.

## 3. FIFO And Position Facts (D2; Q4)

The maintainer's FIFO/no-new-dependency decisions at `macro:832` are adopted
as requirements, not reopened choices: one lean R FIFO implementation, typed
in-fold books, ordinary copy-on-modify, validation at trusted boundaries.
No compiled stage or dependency is added in this cycle. quickr remains parked.
A future compiled FIFO, only after the separate WS14 decision, uses existing
cpp11/C++, `-ffp-contract=off`, and retires `spot_fifo.cpp` in that change.

Promote an extension of the spike's arithmetic, not its two-kernel wrapper.
`fifo/kernel.R:18`, `:22`, `:103` fall back to today's canonical kernel.
Those fallbacks establish no independent lean refusal proof. Before promotion,
openings, fills, dispositions, replay, imports and recovery use the same R
implementation; the old kernel survives only in the external reference build.
Shared validators/refusal helpers are permitted; a retained old arithmetic
engine for difficult rows is not.

Preserve all input and applied-row checks and refusal precedence at their named
boundary (`R/lot-accounting.R:278`, `:323`, `:549`). The trusted block must
prove distinct instrument positions, valid shape/types, bounds, signs, quantities,
prices and fees. Callback, imported and deserialized state cannot skip validation
because the ordinary fixture passed. Retain dynamic overflow/invariant refusals.

Openings append signed lots with finite basis, make no cash or Kahan update, and
preserve prior compensation. Dispositions may use zero price and must exhaust
lots, retaining replay witnesses. Repeated openings remain separate ordered
operations, not one combined row. FIFO dust snaps, cached basis/net values,
close/open fee splits, event-order total basis and compensated realized PnL remain
bit-identical (`R/lot-accounting.R:525`, `:706`; carrier Section 3.4).
The required scalar ordered scan is not replaced by `sum()`/`cumsum()`.

**Q4: no lazy-lot probe on this switch's critical path.** Keep the canonical book
current at every accounting event, including non-fill changes. Preserve D2's
recording-bar entry/exit indices, unknown opening provenance, partial-sale ages,
carry provenance and dust classifications. `entry_price` reads current FIFO basis
(`R/position-facts.R:216`, `:240`); event transitions update the anchors
(`:197`; `R/fold-engine.R:1371`). A last holding mask or delayed lot update
cannot substitute for that event history. Lazy lots is speculative future work,
reopened only after a measured residual bottleneck and its own design review;
this synthesis creates no obligation to investigate it.

## 4. Memory And Family Order (D3; Q1)

**Amended 2026-11-03:** [A1 and Q5](#amendment-maintainer-2026-11-03-acceptance-conditions)
add the maintainer-reviewed skeleton/first-family prerequisite and replace
the cap reference below. Memory and kernel prerequisites remain gates.

**Q1: the first growth checkpoint has separate memory-preparation and complete
kernel operation/refusal workstreams; next is P1 settlement/valuation/terminal
barriers on declared sessions.** This next family exercises the non-fill operations
and D2 facts before more complex target planning can hide their errors.

Windowed preparation is a physical tiling of one run's common substrate, not new
scoring windows. No chunk resets strategy state, pulse seeds, schedule position,
calendar indices, FIFO/Kahan state, marks/ages, entitlement bindings, frozen
holdings or feature history. Retained views cannot alias recycled window buffers.
History still begins at the data start
(`contracts.md#contract-execution-window-start`, `contracts.md:353`), not at
the tile's start. Later facts stay unavailable to earlier decisions.

Prove exact cross-boundary feature/history values using existing feature services.
A fixed overlap based on `requires_bars` does not justify restarting a recursive
or history-dependent feature; TTR rounding already falsified that simplification
in the spike. No new incremental feature API or general callback-state serializer
is authorized. Supported requests spanning tiles must continue to work; if an
exact bounded implementation cannot do so, stop for maintainer disposition,
rather than truncate history, refuse an existing valid request or restart it.

Correct v2's unqualified "peak bounded by the window": bound execution's prepared
working tiles and buffers; separately account for reusable source/history,
feature payloads, live lots, retained user views and requested result output.
Their legitimate size can grow with history/output. Count all resident memory
in parent/worker/process-tree peaks; moving a full-run allocation to "preparation"
does not remove its cost. The spike builds whole-history matrices
(`floor/seam_p2.R:108`), so its plane-byte estimate is not a memory proof.

The memory workstream must demonstrate chunk-boundary parity on a portable fixture
and a registered Sharadar-scale shape before further family growth is authorized.
Measure varying history length with fixed tile width and worker count, reporting
each resident component and total peak. Keep the existing paired history
resource gate (`contracts.md:3351`, including its 1.10 limits and exception route).
WS9b owns the integrated worker/batching boundary before switch; no new transport
or dependency is implied. Failure stops/recharters within the maintainer's cap.

After P1, take family-sized reviewed workstreams in this order: full P2
authoring/state/sizing/risk; P3 restriction/cost/affordability order with P4/P5
publication; schedules and RNG; continued carry windows; sweep/worker/promotion
integration. Each close rechecks already-covered interactions. Costs/risk and
other services are reused, not independently reimplemented.
Full WS15 residual/decoder conformance is exercised throughout, not added last.
These are ordered evidence claims, not a charter for one giant multi-stage spike.

## 5. Reference And Switch Proof (D4; Q2)

**Amended 2026-11-03:** [A3](#amendment-maintainer-2026-11-03-acceptance-conditions)
adds the rules ledger and its pre-switch disposition requirement; the
reference-pin and correctness-change rules below remain binding.

**Q2: pin the accepted WS7/WS8/WS15 close**, including its complete evidence gates,
as the initial normative reference build for this replacement. Record its exact
commit/toolchain and reuse its canonical records. Today's `df7ad1ae`, the original
floor build, and an unaccepted working tree are not substitutes. Earlier dev
evidence is provisional until rebased. Existing open private-reference gates in
the packet remain open; this synthesis closes none by declaring a future pin.

A later accepted correctness/semantics change advances the pin only by explicit
maintainer decision, with the old range and reason retained and all affected
candidate proofs rerun. No automatic "latest current core" oracle.
Contracts prevail over an oracle defect; independently disposition/fix defects
rather than teach the new core accidental behavior or rewrite expected values.

Before switch, exact ordered comparisons cover the entire ledger/fills schema,
lot books/applied fields, realized/unrealized PnL, equity including running maximum/
drawdown, full and filtered diagnostics, sequence positions, feature identity,
point/history explanations, summaries, completion/stops, seeds and identity,
close/reopen, selection/promotion and walk-forward outputs. Use the same run/input
identity where needed. Ignore only enumerated inherently variable clock metadata;
never sort away event order, round values or drop fields to obtain parity.

Required families include WS15's seven, accepted A0 successor records, private
Sharadar reference, both execution clocks, reordered/changing/empty axes and held
nonmembers; late-known facts and pre-scoring history; restricted exit/hold;
stale/frozen/terminal and corporate-action priority; exact/guarded/unavailable
sizing; stable-ID affordability versus decision-order publication; chained costs,
dust/reversals/repeated lots; continued final fills; schedule settlements; seeded/
unseeded RNG and caller restoration; worker-count equivalence; stage-specific
INCOMPLETE prefixes, exceptions, append/flush failure and publication recovery.
Apply future-perturbation, ownership, conservation and registered mutation
witnesses while both implementations exist. Public parity plus independent
invariants and negative witnesses is evidence, not a claim of exhaustive proof.

Switch entry requires every owning workstream accepted, first-workstream memory
proof, complete parity/negative/resource records, and two independent holistic
WS14a reviews of the integrated entry/preparation/fold/publication/finalization/
reader path. Full tests/package checks and registered release gates remain
required; baseline failures need explicit disposition, not a silent pass.
No private-data access or memory results are claimed by the local probes here.

## 6. Tests, Plan Amendment And Promotion (D5; Q3)

**Amended 2026-11-03:** [A4](#amendment-maintainer-2026-11-03-acceptance-conditions)
adds subtraction review and same-workstream correction at every family close.
The remap, isolation and atomic-promotion constraints below remain binding.

**Q3: no blanket test-file exemption.** Only references to retired private
helper names, internal call sites or representation-only shape detectors may be
mechanically remapped. Every remap needs an explicit before/after block and claim,
its representation reason, replacement detector, and evidence that the same
registered negative/mutation witness still fails, recorded in `tickets.yml`.
The maintainer approves each listed remap at cut/review; independent Type 1 review
verifies the mapping before switch. Any semantic assertion change needs its
own design disposition. The implementing agent cannot approve its own weakening.

Inventory candidates in `tests/testthat/test-ws4a-carrier.R`,
`test-fold-phase-contract.R` and `test-execution-spec.R`; their filenames do
not confer permission. Lot validation, no opening Kahan step, ownership, P2
isolation, canonical substrate shape, failure boundaries and shared run/sweep
execution are binding tests, not obsolete helper details
(e.g. `test-ws4a-carrier.R:413`, `test-fold-phase-contract.R:113`,
`test-execution-spec.R:942`). Fixtures, semantic oracles and mutation strength
stay fixed. Make approved remaps explicit before the frozen switch run.
The later contract-based suite rebuild retains WS14a's proof-before-retirement
rule; it is not permission to postpone correctness evidence until after deletion.

Upon acceptance, amend the macro plan explicitly: WS7/WS8/WS15 first; bounded dev
workstreams with memory/worker evidence before switch; both holistic reviews
retained; WS14a's product subtraction cut becomes the atomic replacement cut;
its product-frozen test rebuild follows; full WS14 checkpoint follows the final
execution-sensitive shape. Defer incompatible WS10 changes until switch, or
explicitly rebase/reprove against each accepted change before continuing.
No final WS14 performance claim precedes the economics that changes its workload.

Temporary AGENTS permission is narrowly for `dev/lean_core/` experiment runners,
excluded from packages (`.Rbuildignore:4`). Nothing in R/ imports, calls, selects,
falls back to or dispatches workers to it. At promotion, install the one accepted
core and remove the old core/kernel and temporary permission in the same cut;
each installable revision retains one package engine. Keep the old build outside
the runtime for comparison, not as a dormant mode. Runtime dispatch is never a
way to ship partial family parity. A maintainer-selected A workstream must land
release-ready in the current core and trigger an explicit candidate rebase or
termination, not create a hybrid fallback architecture.

## 7. Objectives, Cap And Escalation (D6; Q5)

**Amended 2026-11-03:** [A2 and Q5](#amendment-maintainer-2026-11-03-acceptance-conditions)
add per-family speed/line budgets and supersede the Q5 paragraphs below:
there is no aggregate cap or current-core release alternative. Record "none"
under macro WS14 as decided by the maintainer. The initial re-estimate is a
progress report; memory/kernel failures and a third correction round still
stop the affected work for maintainer disposition. The aspirations and
baseline-derived measurement requirements below remain binding.

Adopt 50/150 us quiet-pulse, 100 ms outside-loop and PMwR 1.5x narrow/parity-wide
figures only as aspirations for defined, semantically matched workloads.
Retain the durable/ephemeral approximately 2x aspiration and existing WS14
marginal-fill objective; v2's omission does not retire them.
Set acceptance budgets/noise from the pinned baseline before candidate scoring,
through the shared timing harness and phase/profile attribution; report warm
and cold boundaries, durable and memory lanes, result-read cost and peak memory.
Cumulative spike layer deltas are not independent production-stage budgets.
No speed claim is authorized by this synthesis.

**Q5: maintainer decision REQUIRED before post-acceptance lean-core growth.**
The cap's form may be effort or calendar time; only the maintainer chooses its
unit, amount, start point and covered work. Record those values and the check-in
rule in a dated "Lean-core cap" paragraph under macro WS14, the single cap-value
authority; link it from this synthesis's acceptance header. Once work is cut,
`tickets.yml` references that decision and
records consumption/remaining scope at workstream closes; no parallel cap ledger.
The requested value is pending in this synthesis; elapsed silence is not a cap.

Re-estimate after the initial memory/kernel checkpoint and at each close. Reaching
the cap, failing that prerequisite, or needing a third correction round stops
growth for maintainer disposition. The maintainer may explicitly extend the cap
to finish, assign bounded A work, or ship v0.2.3 on the accepted current core.
There is no automatic extension, automatic A insertion, relaxed parity gate or
calendar estimate inferred from microsecond timings. Until the cap is recorded,
this is a proposed route, not an operative uncapped implementation authorization.

## 8. Rejections And Remaining Routing

**Amended 2026-11-03:** [Q5](#amendment-maintainer-2026-11-03-acceptance-conditions)
is decided as no cap. References below to its pending escalation or a bounded
aggregate plan are historical; the rejection reasons and other routing remain.

| Rejected direction | Consequential reason |
| --- | --- |
| V1's 100x benefit / stage boundaries as the cause | Different clocks and restricted semantics; A remains technically viable. B is a development choice. |
| One giant stage-3 charter / an exhaustive oracle | New seam evidence supports bounded growth; missing interactions and memory still require owned proof. |
| Spike canonical fallback surviving promotion | Would leave two R arithmetic implementations and unproved lean refusals. One kernel serves fill/opening/disposition/replay. |
| A mutable context, lost sizing rows or inference by strategy replay | Conflicts with carrier ownership and WS15's exact read-only logical trace. |
| Literal total-memory-independent-of-history promise | Confuses execution tiles with required history, lots and explicit result size. Measure all resident components. |
| Lazy lots before switch | Adds another unproved state boundary; D2 and non-fill accounting require current authoritative books. |
| quickr, a new dependency or compiled stages here | Maintainer already decided R/copy-on-modify now; future cpp11 escalation has its own gate. |
| Broad structural-test waiver or redefining expected output | Would weaken registered guarantees; remaps are individually justified and independently checked. |
| Arbitrary later reference / cap chosen by the synthesis author | A moving oracle and invented authority undermine the bounded plan. Q5 belongs to the maintainer. |

**Open Questions Promoted To Spec-Cut:** tile width/storage/index implementation,
exact producer validation placement and physical carrier layout consistent with
the binding syntheses, field-comparison clock allowlist, performance/noise budgets,
and the per-block mechanical remap inventory. Q1-Q4 are settled; Q5 alone is
escalated to the maintainer. No new public history or strategy form is implicit.
**Future Obligations Recorded:** no new unconditional RFC duty. Existing WS14
compiled escalation remains conditional; lazy lots and other speculative
optimizations remain unplanned. After acceptance, record the narrow AGENTS/macro
amendments, owner/review map and references in their owning files/tickets.
Only this synthesis file is written now; stage 8 must be independent.

## Reproduction Of Local Verification

Run via `C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe -` on stdin.
Existing spike functions only, scratch snapshot/store; no implementation or timing.

```r
pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr",quiet=TRUE,compile=FALSE)
root<-"C:/Users/maxth/Documents/GitHub/ledgr"
source(file.path(root,"dev/spikes/lean_fifo/kernel.R"))
source(file.path(root,"dev/spikes/lean_fifo/streams.R"))
RNGkind("Mersenne-Twister","Inversion","Rejection")
for(seed in 1:5) {
  b<-r_lean_fifo_random_blocks(12L,400L,seed)
  options(r_lean_fifo.gut=NULL);r_lean_fifo_stats$fallbacks<-0L
  good<-r_lean_fifo_compare(12L,b,r_lean_fifo_fill);fb<-r_lean_fifo_stats$fallbacks
  options(r_lean_fifo.gut="plain_sum")
  cat(seed,good,fb,r_lean_fifo_compare(12L,b,r_lean_fifo_fill),"\n")
}
options(r_lean_fifo.gut=NULL)
for(f in c("axes_fixture.R","seam_p2.R","seam_p35.R"))
  source(file.path(root,"dev/spikes/r_floor",f))
local({
  fx<-r_floor_axes_fixture(30L,250L);on.exit(ledgr_snapshot_close(fx$snapshot))
  for(hist in c(FALSE,TRUE)) {
    rec<-r_floor_p2_record(fx,hist,paste0("synth_p2_",hist))
    p<-r_floor_p2_prepare(fx,rec$fills)
    pulse<-match(rec$ts,format(p$ts,"%Y-%m-%dT%H:%M:%SZ",tz="UTC"))
    bad<-0L;kept<-r_floor_p2_lean_view(p,pulse[20],hist);saved<-serialize(kept,NULL)
    for(k in seq_along(pulse)) {
      lv<-r_floor_p2_lean_view(p,pulse[k],hist);lv$targets<-r_floor_p2_rule(lv)
      rv<-rec$views[[k]]
      bad<-bad+sum(!vapply(names(rv),function(f) identical(unname(lv[[f]]),unname(rv[[f]])),TRUE))
    }
    cat(hist,length(pulse),bad,identical(saved,serialize(kept,NULL)),"\n")
  }
  rec<-r_floor_p35_record(fx,"synth_p35");p<-r_floor_p2_prepare(fx,rec$fills)
  z<-r_floor_p35_fold(p,fx,rec);ref<-r_floor_p35_ledgr_frames(rec)
  print(c(fills=nrow(ref$fills),fills_equal=identical(z$fills,ref$fills),
    equity_projection_equal=identical(z$equity,ref$equity)))
  print(names(rec$equity))
})
```

## Amendment (maintainer, 2026-11-03): acceptance conditions

The maintainer accepted this synthesis on 2026-11-03, choosing "correct and
fast" over an earlier release, with the conditions below. They bind with
Sections 1 to 8; where they differ, they prevail.

| Target artifact | Addressed section / group | Disposition | Replacement or retained authority |
| --- | --- | --- | --- |
| This synthesis | Section 1, aggregate-cap qualification | Amended | This amendment, Q5; family-sized reviewed growth retained |
| This synthesis | Sections 2-3, binding boundaries and FIFO | Unchanged | Sections 2-3 |
| This synthesis | Section 4, growth prerequisites and cap reference | Amended | This amendment, A1 and Q5; Section 4 memory/kernel gates retained |
| This synthesis | Section 5, correctness-rule disposition | Amended | This amendment, A3, together with Section 5's pin/change rules |
| This synthesis | Section 6, family-close review | Amended | This amendment, A4; Section 6 test/promotion rules retained |
| This synthesis | Section 7, family budgets | Amended | This amendment, A2, together with Section 7's measurement requirements |
| This synthesis | Section 7, Q5 cap, cap-stop and release alternatives | Superseded | This amendment, Q5; memory/kernel and correction-round escalations retained |
| This synthesis | Section 8, Q5 pending routing and aggregate-bound framing | Amended | This amendment, Q5; other Section 8 rejections/routing retained |

**A1. A deliberately written skeleton.** The lean core's skeleton and its
first family are written by the maintainer, or under a tight maintainer
brief with line-by-line maintainer review, before any agent extends them.
Later workstreams follow that structure. Agents copy the first code they
see; the first code is the code meant to be copied.

**A2. Speed and size budgets at every family close.** Each family workstream
is cut with a microsecond budget, set from the pinned baseline under Section
7, and a line budget for the code it adds. Its close reports per-function
profile sample counts and the line count against both. Exceeding either is a
review finding that is fixed or explicitly accepted by the maintainer, never
only recorded.

**A3. A rules ledger.** Every ledgr rule a parity failure surfaces is
recorded in one ledger, starting with the eleven in
`dev/spikes/r_floor/README.md`. Before the switch, each entry is either
written into `contracts.md` as intended behavior, or changed deliberately
with a recorded oracle difference and its reason (Section 5: contracts
prevail over an oracle defect). The lean core is specified, not only equal
to its predecessor.

**A4. Subtraction at every close.** Each family review first asks what the
family's code can lose: duplicated helpers, validation repeated after a
trusted boundary, a second representation of one concept. Findings are
fixed in the same workstream.

**Q5 decided: no cap.** v0.2.3 ships with the lean core however long it
takes. This replaces Section 7's cap requirement; the "Lean-core cap"
paragraph under macro WS14 records "none" with this reason. The quality
escalations remain: failing the memory or kernel prerequisite, or needing a
third correction round on any workstream, stops that work for maintainer
disposition. The re-estimate after the first memory and kernel checkpoint is
a progress report, not a gate.
