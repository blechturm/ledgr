# ledgr v0.2.3 Macro Plan

**Status:** Accepted by the maintainer on 2026-10-28 (revision 3, written by
Claude and amended by the maintainer). It is the within-release order for
uncut work. Revision 2 applies
the [Type 2 review](macro_plan_review.md) (RESTRUCTURE) as dispositioned in
the [response](macro_plan_response.md), the maintainer's scope answers of
2026-10-28 (Section 6) and the release-process proposal of the same day.
Revision 3 records the accepted typed-accounting synthesis of 2026-10-29 and
moves WS8 into one ordered cut with WS7 after WS4.
Inputs: the roadmap and the [inventory reconciliation](inventory_reconciliation.md).

**Release goal:** a coherent, readable path from declared features to
portfolio targets and inspectable results, on one consolidated and faster
execution core, with the debt deferred to this release paid and a release
process that certifies one candidate once.

This plan records dependency order and workstream boundaries. It does not
override contracts or accepted RFCs and authorizes no production change. Once
a cut is accepted, `tickets.yml` alone sequences it. Inventory IDs (C1, X3,
...) refer to the reconciliation.

## 1. Planning rules

1. **Two tracks.** Decided work is implemented now; the remaining RFCs run
   beside it. A design finishes before the code it governs, not before all
   code.
2. **Measure, cut, review, implement.** Each implementation workstream
   measures its baseline, writes its cut, gets a Codex cut review, then
   implements. Close reviews walk the seven optimization antipatterns and
   record an end-to-end timing.
3. **Hard edges are labelled.** Section 2 marks each edge as a technical
   prerequisite, a binding constraint, an evidence prerequisite or a
   preference. Only the first three block.
4. **Oracles before deletions.** Current native outputs are recorded before
   any handler or engine code changes. Dense-mode removal is checked against
   the peer suite's dense parity lane, those outputs and the frozen v0.2.2
   real-data reference.
5. **Identity is recorded per cut.** Each cut states its impact on snapshot
   content identity, run configuration identity and the store format
   fingerprint, and refuses incompatible artifacts when it lands. No reader
   keeps an old store usable. Development uses fresh fixtures; the private
   Sharadar lake is rebuilt once, at the final format/data freeze after the
   last identity-changing cut.
6. **Every cut is release-ready.** Each cut records its release-impact class
   (product tests, documentation, schema/identity, dependencies, performance
   records, none) and updates tests, examples, teaching and `NEWS.md` in the
   same cut.
7. **Teaching is acceptance.** The strategy API is accepted when its pattern
   article executes and every example passes the maintainer's cold read; a
   later cut that changes a taught behavior updates its example in the same
   cut.
8. **The release ends in promotion, not engineering.** A full release
   rehearsal runs before the final cut. The final cut contains only
   candidate preparation, certification and promotion; a product defect
   after certification rejects the candidate.
9. **CRAN is not assumed.** Work that only matters for the CRAN release
   (NEWS collapse, export-tiering timing) is conditional on v0.2.3 becoming
   that release (maintainer, 2026-10-28).
10. **Measure what is unknown, once.** Probes and spikes measure effects
    nobody knows yet. A cut cites an effect a spike already measured instead
    of measuring it again (maintainer, 2026-10-29, after cut 4).
11. **Measure while drafting the cut.** Before a cut is accepted it runs
    every oracle and checker it relies on against the unchanged base, on a
    later day than the recording when clocks can matter, and settles every
    surprise in the cut text, so implementation raises no new maintainer
    decision (maintainer, 2026-10-29, after cut 4).
12. **No separate A/A ticket.** An A/A timing run is needed only when the
    shared timing harness or the host changes; otherwise a gate's
    alternating pairs carry their own noise evidence (maintainer,
    2026-10-29, after cut 4).
13. **Proportional gates.** A timing gate covers the cells where the cut's
    changes carry real regression risk; an effect a spike already settled
    is cited, not gated (maintainer, 2026-10-29, after cut 4).

## 2. Dependency structure

```text
Phase A (now, parallel)
|-- A0 record current native outputs (before WS1)
|-- WS1 one output handler ................ first cut
|-- WS2 RNG reproducibility
|-- WS3 peer suite seed -> dense lane -> baseline timing on the current tree
|-- WS13 release-candidate CI RFC -> install floor -> CI jobs -> rehearsal
|-- WS9a memory and worker baselines; C3 placement RFC
|-- C4 pulse-seed counter (own Type 2 cut)
|-- RFC track: frame retirement, asset precision, execution policy,
|   portfolio construction, docs roles, helper bundles, C9 mechanism,
|   typed-accounting boundary (field census, then focused RFC)
|-- WS11a H4 real-data audit; C10 census and coupling map
|-- WS5 preparation: spec cut, schema, selection, article drafts
`-- chores: roxygen pin, UX-brief reconcile, M8a, C12b
                              |
Phase B   WS4 minimal C1 consolidation
                              |
Phase C   WS5 runtime ---> WS6 frame retirement --.
          WS7 -> WS8 typed accounting cut --------+--> J: disclosures,
          H10 settlement state                         pattern article,
                                                       cold read
                              |
Phase D   WS9b structural memory -> worker budgets -> H9 daemon reuse
          WS10 economics implementation (as each RFC is accepted)
          WS3 full suite timing after WS4 and WS8
                              |
Phase E   WS11b C10 ADR, H1, C9   WS12 documentation and debt
          final format/data freeze -> one lake rebuild -> integrated record
          -> rehearsal -> final cut: certify, promote
```

| Edge | Kind |
| --- | --- |
| A0 -> WS1 | evidence prerequisite |
| WS3 dense lane -> WS4 | evidence prerequisite (roadmap, inventory X4) |
| WS1 -> WS4 | preference (less ownership conflict; both handlers enter one fold) |
| WS4 -> WS5 runtime | binding constraint: dense is frozen and synthesis D3 authorizes no new execution-mode branch |
| WS4 -> WS7/WS8 cut | binding constraint (roadmap: merge readers after one run shape) |
| accepted typed-accounting synthesis -> WS7/WS8 cut | binding constraint: the synthesis binds the authoritative fields, typed replay boundary and ordered workstreams |
| WS5 -> WS6 | technical prerequisite (synthesis D1 fixes the input layout) |
| WS5, WS6, WS7 -> J | evidence prerequisite for WS5 acceptance |
| WS9b budget decision -> H9 | technical prerequisite (inventory H9) |
| each economics RFC -> its implementation | binding constraint |
| R2 -> M5, M7; H4 -> M5 | binding constraint |
| H4 -> C10 ADR -> C9 | binding constraint (inventory chain 2) |
| last identity-changing cut -> lake rebuild | binding constraint (rule 5) |

The critical path is A0 -> WS3 dense lane -> WS4 -> WS5 -> J. WS1 precedes
WS4 by preference.

## 3. Workstreams

### WS1. One output handler (C6, R3; H6 measured after)

One handler behind a DuckDB or memory sink replaces the persistent and memory
handlers and their parity suite. R3's fold-phase obligations ride here.
- **Route:** direct tickets; the first cut. **Gate:** byte-identical outputs
  against A0; committed-run versus sweep gap re-measured (H6).

### WS2. RNG reproducibility (X1, absorbs H8)

Pin the RNG kind wherever ledgr seeds; restore the caller's RNG with
`seed = NULL`; widen preflight RNG detection; one documented recipe.
- **Route:** direct tickets. **Gate:** 1- versus 2-worker equivalence for a
  strategy seeded from `ctx$pulse_seed`; the NMOF `LSopt` probe reproduces.
- **Amendment (maintainer, 2026-10-29):** widening preflight RNG detection
  leaves WS2 and is parked in the horizon ("Ambient RNG detection for
  strategies"); cut 3 decision (11) records why.

### WS3. Peer benchmark suite (X4, full scope)

Suite seed (lanes, workload contracts, parity oracles, timing boundaries,
deletion witnesses for C1). Then: dense parity lane and a **baseline timing on
the current tree**; authoring lane; scaling geometry, whole-universe portfolio
and the point-in-time demonstration row. All lanes are timed again after WS4
and WS8 so the release can see where it stands (maintainer, 2026-10-28). The
post-WS7/WS8 record includes warm result reads and full run-plus-results time,
so eliminating accounting representations is measured end to end.
- **Route:** RFC, then direct tickets per lane. **Rule:** no public
  performance claim until the suite exists and its results are accepted.

### WS4. Minimal execution-core consolidation (C1, M8b)

One execution path on the availability core, the disclosed implied calendar,
the fate of `ledgr_backtest()`, and the final-bar no-fill disclosure (M8b).
- **Route:** direct tickets, Type 2 at cut. **Gate:** dense parity lane, A0
  and the v0.2.2 reference unchanged, or each difference decided.
- C4 (pulse seed) and H10 (settlement state) have their own cuts; H9 waits
  for WS9b's budget decision.

### WS5. Strategy authoring API (X3; accepted synthesis)

Implement the [accepted synthesis](../rfc/rfc_strategy_authoring_api_v0_2_3_synthesis.md).
The spec cut resolves its Section 6 and registers its Section 4 evidence in
Phase A; schema, selection and article drafts may start then. The runtime
(flat `ctx`, position facts, verbs, declared state, schedule predicate,
required capital and costs) follows WS4. H3 is settled in this cut.
- **Acceptance:** at J, on the merged reader: rounding and refusal
  disclosures, the executed pattern article and the maintainer's cold read.

### WS6. Context frame retirement (C2)

Focused seed now; implementation after WS5's runtime, before J.

### WS7. One result reader and print (C8)

Merge the three reader families behind one chunked, typed accounting projection
and one print path, as WS5's sibling after WS4. The accepted
[typed-accounting synthesis](../rfc/rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md)
binds the authoritative fields and replay boundary. WS7 is the first
workstream of one cut with WS8: it leaves one typed carrier, may temporarily
extract typed evidence from current JSON, and may not leave parsed metadata as
a second authority. Gate: every public table and print is byte-identical or
each difference is decided. M8a and C12b may land earlier on the current path.

### WS8. Typed P3-P5 execution batch (C7)

WS8 is the second workstream of the same ordered cut as WS7, still after WS4.
It replaces the temporary extraction with direct typed publication on every
producer and durable write path, removes accounting-critical JSON, bumps the
store format to schema 125 with unconditional old-store refusal, and rebuilds
affected stores once after the cut. The compiled execution envelope is not
edited. Bounded no-fill, sparse-rebalance and wide all-fill comparisons remain
part of its evidence.
- **Gate:** the synthesis's Section 6 evidence, end-to-end runtime and an
  allocation gate named at the cut.

### WS9. Memory and worker budgets (C5, H9, H11; C3 RFC)

- **WS9a, now:** phase-level memory and worker baselines; the C3 placement RFC.
- **WS9b, after WS4:** structural reduction, then the worker-budget decision
  (defaults Type 2 at cut), then H9 daemon reuse. Final memory evidence
  follows WS6 and H9. The typed-accounting work must also prove that shared
  result reconstruction is chunk-bounded and report its peak RSS.

### WS10. Economics (C11, C12a, U2, X2): design and implementation

The three RFCs run now in parallel with two local interfaces: precision feeds
step-based scaling; fill policy feeds execution-sensitive construction. U2 is
narrowed to what the strategy synthesis left open (current weights, bands,
separate capital, NMOF as reference estimator). Each implementation follows
its accepted RFC after WS4, in its own cut (maintainer, 2026-10-28: in
scope). A cut that changes helper granularity, sizing or results updates the
affected taught examples and parity rows in the same cut.

### WS11. Surface and CRAN preparation (H4, H1, C10, C9, U3)

- **WS11a, now:** H4 real-data use audit (per-block decisions); C10 export
  census and coupling map; C9's mechanism as a small Type 2 decision; the
  helper-bundles RFC (U3, keeping R4's proof obligations).
- **WS11b, after J:** C10 ADR on the surviving API; H1 export repairs; C9
  tiering, its timing conditional on the CRAN release (rule 9).

### WS12. Documentation and debt (R2, M1, M5, M7, H5b, U1, M6)

Roxygen pin (H5b) and UX-brief reconcile (U1) now. R2 opens with the first
cut and precedes M5 and M7; M5 also waits for H4's decisions. M7: six plots,
each signed off. M1 audit after WS1 and WS4. M6 NEWS collapse only for the
CRAN release.

### WS13. Release-candidate certification (R1, M4)

The focused release-candidate RFC, seeded from the 2026-10-28 proposal: one
candidate = one commit SHA, one tarball hash, one declared toolchain; one
build fanning out to independent jobs (lint, Ubuntu current and minimum
dependencies, Windows/CRAN check, isolated-CRAN, coverage, documentation and
pkgdown, review profile, registered-record validation) ending in a candidate
certificate; promotion of that exact SHA to `main` and the tag without
rebuilding; site deployed from the built artifact.
- Registered-host timings and Sharadar real-data checks run locally when
  their declared invalidation set changes; CI validates their committed
  records, not their timings.
- M4 install-floor measurement comes first: it defines the
  minimum-dependency job.
- Process targets (certification critical path, release-day human time) are
  bound after the first rehearsal measures them.
- The playbook's release order is replaced once the RFC is accepted.

## 4. Cut strategy

- First cut: WS1, after A0. WS2, C4 and the Phase A chores may form a second
  small cut.
- Each later workstream gets its own cut; a cut may split one when its
  evidence is independent. The accepted typed-accounting synthesis is the
  named exception: WS7 and WS8 are two reviewed workstreams in one ordered
  cut and one store rebuild. Low-stakes choices are batched for the maintainer
  at acceptance.
- RFC-track work needs no cut; its implementation does.
- The final cut is the release cut of rule 8.

## 5. Explicit non-goals

Shorting and leverage; orders and the OMS (after PIT fundamentals); trained
model lifecycle; derivatives and FX; compiled-default changes; PIT
fundamentals (after CRAN); public `ledgr.crypto2` (separate packet); a cash
default (demand-driven); a decision-graph recorder; state-storage redesign
without a measured case; telemetry redesign (H7); vectorbt or LEAN rows.

## 6. Maintainer decisions recorded in this revision

- **A.** Consolidation precedes the strategy API runtime (dense freeze and
  synthesis D3); preparation starts earlier.
- **B.** Inventory proposals accepted as proposed: C13 separate packet; M3
  keep path; H4 per-block decisions; H7 deferred; R4 absorbed by U3 with its
  obligations; D1 and D2 deferred, Q16/Q18 to execution policy.
- **Scope, 2026-10-28:** WS8 stays; economics implementation stays; the full
  peer suite stays, with timings after WS4 and WS8; CRAN-only chores are
  conditional on v0.2.3 becoming the CRAN release.
- **Typed accounting, 2026-10-29:** the maintainer accepted the focused
  synthesis after Type 2 response and Type 1 final review. One wide typed
  ledger, cash authority, lot-derived position authority, one validator and
  replay, the named `inline_summary()` exception and schema-125 refusal bind.
  WS7 then WS8 form one cut after WS4 with one rebuild; WS3 and WS9 verify the
  full-workflow runtime and bounded-memory claims.

A, B and the scope answers were accepted with this plan on 2026-10-28.

## 7. Release definition of done

- Every accepted cut closed with its evidence in `tickets.yml`.
- One execution core, one output handler, one result reader, the typed batch.
- The strategy API implemented, its pattern article executed and cold-read.
- Economics RFCs accepted and implemented.
- RNG equivalence passing; memory and worker budgets set.
- Dense parity lane, A0 and the v0.2.2 reference reproduced or each
  difference decided; full peer suite timed after the consolidations.
- Debt M1, M5, H5b closed; plots signed off.
- Final format/data freeze, one lake rebuild, an integrated release record.
- A certified candidate promoted under the WS13 process.
