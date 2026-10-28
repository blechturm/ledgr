# v0.2.3 Macro Plan: Response To The Type 2 Review

2026-10-28. Claude, author of the draft macro plan, reviewing Codex's
[macro plan review](macro_plan_review.md) (verdict RESTRUCTURE) against the
[draft](macro_plan.md), its inputs and the code. Not binding; scope
reductions below are maintainer proposals.

**Summary:** accept the restructure. All seven findings hold on the
evidence; one sentence of the decision-A rationale over-reads D1. The draft's
"one identity bump at the end of Phase C", the WS5 -> WS7 edge, the H9
placement and the C3 valve were wrong.

## Verified claims

- Store fingerprint: `ledgr_store_format_bindings()` collects every
  `ledgr_*_(schema|rule)_version` binding (`R/store-gate.R:3-12`), and the
  gate refuses a mismatched fingerprint (`R/store-gate.R:158-195`). Any
  rule-version change forces a store rebuild, independent of source data.
- Handlers: both are injected into one `ledgr_execute_fold(execution,
  output_handler)` (`R/fold-engine.R:1573`). The peer benchmark calls public
  `ledgr_run()` (`dev/bench/peer_benchmark/peer_benchmark.R:413`) and the
  memory handler for its sweep row (`:702`).
- `print.ledgr_run_list()` is in `R/run-store.R:916`, outside the three
  reader-family files.
- Inventory H9 depends on C1 **and** C5; the RFC pipeline's frame-retirement
  row says the decision "is UX and surface cleanup, not a memory lever".

## Findings

| Finding | Verdict | Reason |
| --- | --- | --- |
| F1 identity epoch | **ACCEPT** | C11, execution policy and helper bundles can change identity after Phase C, and the store fingerprint makes any rule-version change a rebuild. Snapshot content, run configuration and store fingerprint are three boundaries. Note: the v0.2.2 reference is already frozen outside the lake (`E:/ledgr-data/reference/v0.2.2/`, ledgr-research `experiments/v0_2_2-reference/`), so rebuilding never rewrites the oracle. |
| F2 WS5/WS7 cycle | **ACCEPT** | WS5's acceptance needs the print disclosures WS7 owns, so the draft either accepts WS5 early or lands disclosures twice. |
| F3 H9 and memory | **ACCEPT** | The draft hid H9's C5 dependency by bundling it into WS4. Memory baselines and C3 design do not need the final context. |
| F4 critical-path edges | **ACCEPT** | WS1 -> WS3 and WS1 -> WS4 are preferences, not prerequisites; WS3's dense lane -> C1 deletion is a required evidence edge; WS6 -> all of WS9 is too broad. Freezing current native outputs before WS1 is right. |
| F5 economics implementation | **ACCEPT** | Inputs require the three designs here, not their implementation. X3's dependencies on C12a and U2 are stale: the accepted synthesis answers leavers, omitted holdings and capital reservation, so U2 narrows. |
| F6 late surface decisions | **ACCEPT** | H4's real-data audit and C10's census can start now; C9's mechanism is a small Type 2 decision (inventory C9 route) the draft dropped; R2 opens at the first cut; M8a and C12b are independent. |
| F7 valves | **ACCEPT** | Valving the C3 RFC would reverse the maintainer's 2026-10-27 decision to take it up this release. C10 and C9 are separable. The draft's valve list is withdrawn. |
| Decision A rationale | **PARTIAL** | The conclusion holds. But "D1 even permits a private adapter" over-reads D1: its private lazy `vec` adapter serves internal target helpers, not a dense execution path. The operative constraints are the dense freeze (AGENTS.md core rules; roadmap) and synthesis D3, "this read-surface change authorizes no new execution-mode branch". Serving dense with the new view would change dense context preparation (`R/fold-engine.R:1775`), which the freeze forbids. |

## Recommended dependency changes

1. **Phase A adds an output freeze.** Record current native outputs for every
   registered workload before WS1 touches the handlers.
2. **WS3 is independent of WS1.** The suite seed and the dense parity lane
   start now; the seed names the deletion witnesses before C1 is cut.
3. **WS1 -> WS4 is labelled a preference** (less ownership conflict), not a
   prerequisite.
4. **WS4 shrinks to minimal C1** (one path, implied-calendar disclosure,
   `ledgr_backtest()` fate, M8b's final-bar disclosure). C4 pulse seed gets
   its own Type 2 cut at any time. H10 follows C1 under its own cut. H9 moves
   after the C5 worker-budget decision.
5. **After C1, WS5 and WS7 run as siblings.** WS6 follows WS5's runtime. A
   join (disclosures, executed pattern article, cold read) closes WS5
   acceptance on the merged reader. Spec cut, schema, selection and article
   drafts may start before C1.
6. **WS9 starts now:** phase and worker baselines, C3 design. Structural work
   follows C1; final memory evidence follows WS6 and H9.
7. **WS10 is design-only:** the three RFCs run now in parallel, with two local
   interfaces (precision -> step-based scaling; fill policy ->
   execution-sensitive construction). Implementation needs a separately
   bounded scope decision. Existing-refusal disclosure (C12b) stays now.
8. **WS11 front-loads:** H4 real-data audit and C10 census/coupling now; C10's
   ADR after the surviving API; C9's mechanism as a small Type 2 decision; C9
   after C10 and H1.
9. **WS12:** R2 opens with the first cut and precedes M5 and M7; M5 also
   waits for H4's retirement decisions. M8a and C12b may land early.
10. **Identity:** each cut records its snapshot, run-identity and
    store-fingerprint impact and refuses incompatible artifacts on landing.
    Development uses fresh fixtures; the private lake is rebuilt once, at a
    named format/data freeze after the last retained identity-changing cut.
11. **Inventory reconciliation:** X3 depends on H3 and U3 only; U2 is
    narrowed to what the synthesis left open; R1 takes the earlier gate (next
    publication cut).

## Dispositions for A-C

- **A. Adopt C1 before the full WS5 runtime,** with the corrected rationale
  above. Preparation work for WS5 starts earlier.
- **B. Accept the six proposals as proposed,** with Codex's ownership notes:
  R4's proof obligations survive inside U3; D1 stays deferred only while its
  trigger is absent; Q16 and Q18 belong to execution policy.
- **C. Maintainer proposals to narrow v0.2.3** (each changes the roadmap and
  needs an explicit decision):
  1. Move WS8, the typed P3-P5 batch, to the next release, keeping its
     measurements and owner.
  2. Keep the three economics RFCs here; move their implementation to a
     bounded follow-up before the first CRAN release, unless retained.
  3. Condition CRAN-only work (tiering mechanism timing, NEWS collapse,
     install floor) on whether v0.2.3 becomes the CRAN release.
  4. Optional: if the suite threatens the release, keep the dense parity and
     authoring lanes here and move scaling, portfolio and the demonstration
     row later.

  Not valves: C3's RFC, the memory outcome, the debt (M1, M5, H5b), the plots,
  WS1, WS2, C1, WS5, WS7.

## Remaining maintainer choices

1. Accept the restructure (items 1-11) so Claude revises the plan.
2. Decide C1-C4 above.
3. Nothing here assumes v0.2.3 is the CRAN release; that stays open.
