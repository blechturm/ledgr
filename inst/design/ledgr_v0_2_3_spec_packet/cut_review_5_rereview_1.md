# Cut 5 focused independent re-review, revision 2

- Reviewer: Codex, independent clean-context reviewer; authored neither the cut nor round 1.
- Date: 2026-10-30.
- Mode: Type 1 against the accepted synthesis and F1-F10; Type 2 limited to defects introduced by revision 2.
- Reviewed commit: `cae549b1cb50dcb36d023c891749fafd30782ae2`, `release/v0.2.3`; revision diff `95a838c4..cae549b1`, `tickets.yml` only.
- Verdict: **PASS_AFTER_PATCHES**.

Revision 2 resolves nine findings, including optional F10. F2 retains one concrete consumer-handoff gap, detailed as N1 below. N1's exact patches suffice without another focused re-review of these repairs. This verdict approves the repaired preparation brief only: decision (9) still requires completed LDG-3162/3163, a subsequent independent cut review and maintainer acceptance before LDG-3164. Missing preparation records are not findings at this stage.

Citation keys: `T` = this packet's `tickets.yml`; `S` = `inst/design/rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md`; `M` = this packet's `macro_plan.md`. Lines refer to the reviewed commit.

| Round-1 finding | Resolved? | Evidence and substantive assessment |
| --- | --- | --- |
| F1: acceptance before preparation | Yes | `T:422-429,453-465,488-491` makes preparation and a passing subsequent review prerequisites to acceptance. `T:1091-1116` assigns every bound obligation, construction validation, ownership and cold-read verification; an open design question cannot count as acceptance. This implements `S:329-330` and `M:66-70`. |
| F2: producer/consumer handoffs | No, partially resolved | `T:1172-1177,1200-1205,1231-1235,1283-1286` moves positions/book validation, observation consumers, compiled input and plan validation into the introducing tickets. However, LDG-3166's new prohibition on recreating per-fill objects leaves the canonical handler's required fill-intent input without an explicit migration owner; see N1. |
| F3: overbroad structural gates | Yes | `T:1178` limits name-lookup detection to the typed kernel/migrated book consumers and enumerates boundary adapters. `T:1262,1287` explicitly accepts routed metadata and retained diagnostic chunks, while requiring injected economic staging and cross-pulse staging to fail. These distinguish retained output from transient carriers as required by `S:213-228`. |
| F4: impossible test-migration exception | Yes | `T:353-358,429-443,1107-1116` permits individually registered representation and source-predicate replacements, names the affected tests, preserves economic inputs/oracles and fault boundaries, and requires a failing demonstration. It no longer requires predicates naming deleted representations to survive literally. |
| F5: ratio mistaken for absolute bound | Yes | `T:374,380-392,1132-1135,1149` separates the fixed ratio from the candidate marginal median's absolute 40 us bound, rejects invalid marginals, and requires 45 us rejection/30 us acceptance controls. `dev/bench/timing/protocol.R:4-7` accepts a workload-defined clock; `dev/bench/timing/check.R:245-269` returns its candidate median. A marginal clock can therefore feed the small checker without modifying the shared mechanism or using the earlier base as an absolute-bound proxy. |
| F6: missing dense cells/replay contradiction | Yes | `T:372-380` covers both producers' run/sweep shapes and separates fills/trades replay cells from equity reads. `T:408-421,1170-1178` explicitly gates replay timing and memory at LDG-3164; other timing may wait for LDG-3169. |
| F7: unsupported peak-live claim | Yes | `T:393-408,1138-1140,1149` requires a validated instrument, declared memory domains/boundaries, separate forward/replay budgets and a controlled live-storage excess before acceptance. Heap high-water, RSS and cumulative allocation cannot silently substitute. The metric must return to the maintainer if it cannot be measured; this is a preparation requirement, not a claim that measurement already exists. |
| F8: post-failure timing waiver | Yes | `T:1310` requires every frozen timing bound, including the absolute check, to pass; a miss leaves the workstream open. A linked exception cannot certify PASS. This preserves `S:349-352`. |
| F9: unregistered real-data inputs | Yes | `T:318-328` names separate absolute library/state paths and conditions fresh-candidate readiness on registered identities, commands and controls. `T:1141-1149` owns that evidence and an unchanged/cost-mutant demonstration. The brief no longer claims the inputs are beside the saved outputs or already validated. |
| F10: final source identity (optional) | Yes | `T:1303-1309` puts contract/NEWS edits before the final package check, records tested identity and later evidence-only differences, invalidates affected gates after product edits and keeps generated artifacts outside the tracked tree. |

## N1. LDG-3166's new scalar bridge still reaches a removed fill-intent interface

Classification: residual F2 handoff defect exposed by revision 2's explicit no-reconstruction rule; no challenge to the accepted carrier design.

Evidence: `T:1231-1235` migrates P4/P5 plan readers and compiled input, allowing a scalar loop but forbidding a list/S3 object per fill. `T:1251-1258` assigns indexed publication to LDG-3167. The canonical loop calls `write_fill_events(fill_intent = fill)` at `R/fold-engine.R:1364-1368`; `R/output-handler.R:561-572` forwards that object to either `ledgr_fill_event_payload()` or the live sink. Both buffered/memory and live payload paths explicitly require a list inheriting `ledgr_fill_intent` (`R/backtest-runner.R:117-118`; `R/ledger-writer.R:40-41`). The buffered payload also recomputes publication deltas at `R/backtest-runner.R:132-134`, although LDG-3166 now computes them in P3 (`T:1219-1220`).

Why it matters: changing only the enumerated readers cannot leave LDG-3166 green. It must reconstruct the prohibited fill intent, silently enlarge its scope into handler/live inputs, or postpone its required effects reuse. Existing publication result/staging lists also need an explicit lifetime through LDG-3167 rather than being accidentally forbidden by the scalar-loop sentence. A future consumer map can locate this boundary, but the cut should settle its owning ticket now, as it did for compiled input. The repair preserves `S:139-140,194-218` and `contracts.md#contract-execution-fold-core`; it imports no WS8 schema, JSON or reader work.

Exact patch 1: replace LDG-3166 scope from "Migrate the P4 and P5 plan readers" through "Constructors validate the new plan groups now" (`T:1231-1235`) with:

> Migrate the P4 and P5 plan readers and the compiled wrapper's input to the fill and rejection columns here. This ticket also migrates the canonical handler's fill-input boundary, ledgr_fill_event_payload(), and the db_live sink/writer input from fill-intent objects to typed columns plus an index, or primitive scalar arguments. These consumers reuse P3's computed publication effects; they do not reconstruct a fill intent or recompute cash/position deltas. Preserve sink behavior, metadata bytes, condition semantics and append/flush boundaries. An indexed scalar application loop through the single typed lot implementation may remain until LDG-3167. Existing publication result objects and event/leg staging may remain until that ticket; no per-fill plan or fill-intent object is reconstructed. Constructors validate the new plan groups now. Register the affected internal test migrations under decision (10).

Exact patch 2: append this acceptance item to LDG-3166 (`T:1236`):

> Buffered durable, memory and db_live publication consume the typed plan without constructing a fill-intent object or recomputing its publication effects; the applicable identity and condition witnesses pass, and an injected reconstruction or duplicate effect computation fails its detector.

Exact patch 3: replace LDG-3167's sentence beginning "This ticket owns candidate batching" (`T:1256-1258`) with:

> This ticket owns candidate batching and indexed event and leg publication, including removal of the publication result/staging objects retained at LDG-3166; plan, handler and live-writer input migration is already complete in LDG-3166.

## Review limits

Read the required sources before follow-up inspection. Confirmed HEAD and branch, inspected the revision diff, and traced the disputed interfaces in production code. The timing feasibility conclusion follows from the shared clock/result interface, not a measured performance claim. No timing, oracle, R process, package check or private-data rerun was needed or performed. No empirical PASS from round 1 is newly certified here. No additional scope intrusion or unowned obligation was found: Section 8 routes remain deferred, with route verification owned by LDG-3169. Only this review file was added; no commit was made.
