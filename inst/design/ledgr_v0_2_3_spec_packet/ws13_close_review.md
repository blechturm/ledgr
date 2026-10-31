# Workstream 13 close review

- Reviewer: Codex, independent clean-context reviewer; author of none of the reviewed product.
- Date: 2026-10-31.
- Mode: Type 1 close review, maintainer-owned brief drafted by Claude; v0.2.3 cut 5, macro WS4a part 2.
- Reviewed commit: `807aeebd74696e6bb6bf79e63a54603f563ffba4`, branch `claude/ws4a-carrier`; final candidate `28ad2542`, product equal to `9b05538f`.
- Verdict: **NEEDS_TYPE_2**. F1 is a conflict in the accepted inputs. F2-F4 also prevent implementation acceptance; this is not PASS_AFTER_PATCHES.

Authority read in the requested order: `tickets.yml` cut 5 decisions/amendments and LDG-3165..3169; typed-fold-carrier synthesis Sections 3-5; `ws4a_carrier_design.md` censuses, obligations, migration list, detectors and Section 8; contracts; disposition/records; optimization style; prior WS12 and checkpoint reviews. Stable contract addresses: `contracts.md#contract-execution-fold-core`, `#contract-execution-fold-carrier`, `#contract-execution-event-staging`, `#contract-execution-accounting-events`, `#contract-execution-fills-and-lots`.

The settled performance, tooling-budget, F4.01, cached-net and coverage dispositions are not reopened. LDG-3165/3166 were checked for post-`cc0ea2e6` regressions; F1 additionally answers the expressly reopened item (a), rather than claiming a newly introduced checkpoint regression.

**Execution and evidence key**

`ROOT` = `C:/Users/maxth/ledgr-wt/ws4a-impl`; `S` = `C:/Users/maxth/AppData/Local/Temp/ws13-close-review`; `B` = `ROOT/dev/bench/v0_2_3_ws4a`; abbreviated `records/...` pointers are relative to B. Abbreviations in commands were expanded to absolute paths. R 4.6.1, serial plain Rscript jobs; base library `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`. Scratch scripts and captures remain in S. No source mutation from a probe was installed in the repository.

| Key | Executed command and result |
| --- | --- |
| G | `git -C ROOT diff 975c8add 807aeebd`; `git -C ROOT diff cc0ea2e6 807aeebd`, with focused file diffs/source reads. `git -C ROOT diff 9b05538f 28ad2542 -- R src man vignettes DESCRIPTION NAMESPACE` is empty. `git -C ROOT diff --name-only 28ad2542 807aeebd` lists evidence/planning files only. |
| N | `Rscript -e "pkgbuild::compile_dll('ROOT', force=TRUE, quiet=TRUE)"`: exit 0, normal native build replacing the instrumented build. |
| C | `Rscript B/check.R --base=HEAD --out=S/check`: exit 0, **23 cases identical**. This checks recorded expected outputs; HEAD is not an independent historical oracle. P supplies that comparison. |
| T | `Rscript -e "testthat::test_local('ROOT', filter='^(ws4a-carrier\|availability-diagnostic-production\|cost-model\|cross-asset-corrections\|derived-state\|execution-spec\|fill-model\|fold-phase-contract\|governance-report\|ledger-writer\|release-coverage-branches\|risk-fold\|runner\|sweep\|availability-economics)$', reporter='summary', stop_on_failure=TRUE)"`: exit 0, all 15 files pass; 14 expected final-bar warnings. |
| U | `Rscript B/guts.R --base=HEAD --out=S/guts --guts=C13a_swallow,C13c_swallow_append,C13c_swallow_fact,C13c_swallow_flush,C14c_reuse_staging,C14c_reuse_leg_staging,M2_reorder_pulse_fills,M3_drop_lot_fee,C16_force_fold_equity,C18_drop_split_tail,C18_retain_staging,C18_drain_unused_equity`: exit 0; **12/12 fail as expected**, invalid-base control refused. |
| P | `Rscript S/probe.R base`, then `Rscript S/probe.R candidate`: exit 0; synthetic sealed-snapshot public run/sweep comparisons and direct production-boundary/detector controls. Captures `S/probe-base.txt`, `S/probe-candidate.txt`. Findings below give the inputs and outcomes. |
| Q | `Rscript B/records/ldg3167/probe_multi.R base S/precedence-base.rds`, then the same with `candidate S/precedence-candidate.rds`: exit 0; 10/16 outcomes identical, six amendment-authorized differences, detailed below. |
| A | `Rscript S/audit.R`: exit 0; executable D10 counterexample, diagnostic patch controls, and AST comparison of every top-level function against `975c8add`. Census: `S/changed-functions.txt`, 92 added/changed/removed functions across 18 R files, including nested closures under their owners. |
| R | After each pkgload-using job: `git -C ROOT checkout -- R/cpp11.R src/cpp11.cpp`. Git needed owner-account execution because of sandbox ownership; no Git configuration changed. |

No full suite, coverage, benchmark timing/memory scripts, package check or real-data workload was run. T includes the existing registered tests in its named files; the accounting-core file containing LTB-0022's timing experiment was inspected, not rerun. Startup emitted four locale warnings. Historical broader gates are attributed below, not presented as independent reruns.

**Findings**

**F1 — blocking, NEEDS_TYPE_2: finite aggregate valuation is not an invariant of admitted finite inputs.**

Evidence: `R/fold-carrier.R:49` requires finite `positions_value`; `R/fold-engine.R:621` computes the run-order valuation and `:648` constructs the packet. `ws4a_carrier_design.md:655` F4.15 explicitly requires finiteness, while synthesis Section 3.1 preserves existing classed refusals. Command P: four daily synthetic bars at price 10, finite opening cash 1000, long quantity 1e308 at basis 1, first target 0, availability producer. Base run and sweep refuse with `ledgr_config_non_finite`; candidate run and sweep refuse earlier with `ledgr_internal_error`, message `Invalid internal decision packet: \`positions_value\` contains a non-finite value.`

This happens before P4, so `amendment_overflow` does not authorize it. Publicly admitted data are being called internal corruption. Keeping F4.15 and preserving the earlier refusal are incompatible on this input. An exact implementation-only patch cannot satisfy both. Type 2 must decide the derived-valuation boundary, class and precedence, and revise F4.15/its promoted contract accordingly. Recommendation: preserve the base boundary rather than extend the fill amendment to valuation; retain finite primitive position/mark checks. Do not silently accept the new internal-error class or merely change the oracle.

**F2 — blocking: the compiled fill path does not implement amendment_overflow.**

Evidence: `tickets.yml:215`; `R/fold-engine.R:1395`; `R/compiled-spot-fifo.R:161` native dispatch and `:194` unpack; `R/lot-accounting.R:562` canonical-only refusal. Command P, dense sweep with `compiled_accounting_model='spot_fifo'`: opening cash 1000, no position, target 1e308 at price 10 returns **DONE, final_equity NaN** on both base and candidate. Selling a long 1e308 at basis -1 for 1.5 returns DONE on the base but candidate FAILED with `ledgr_lot_state_invariant`, `Invalid typed lot book: book totals must be finite double scalars.` Neither is the decided fill refusal.

The amendment says fills in runs and sweeps, without a compiled exception. Native-code identity does not establish agreement with the newly amended canonical oracle. `contracts.md:716` accurately describes the implemented canonical scope but cannot authorize narrowing the amendment; `NEWS.md:10` and `ws12_disposition.md:92` claim more than is implemented. Implement the exact refusal and earlier-row precedence at the compiled boundary, with public compiled controls for opening-basis and closing-realized overflow. Keep the native freeze unless separately amended. A canonical-only disposition requires explicit Type 2 scope authority; documentation alone is not the fix. No small exact patch is certified here.

**F3 — blocking: diagnostic construction does not invoke its production predicate; the empty publication path also bypasses construction validation.**

Evidence: `R/fold-carrier.R:774` builds diagnostic rows and `:800` returns raw `out`; `:820` stages them; `R/fold-engine.R:315` drains without validation. Command P creates `list(n=1L, reason_code=NA_character_)`, passes it through the actual row builder, staging writer and drain: all succeed, the writer receives NA, and n resets to zero. Calling `ledgr_carrier_problem()` separately correctly reports the violation. Thus U-3168/O3.09/F4.43 are not enforced where the data enter production. `tests/testthat/test-ws4a-carrier.R:3030` manually checks captured/mutated objects; that is not a production refusal witness. E initially checks empty staging, and stop validation does not cover ordinary drains.

Exact diagnostic patch, at the final expression of `ledgr_fold_diagnostic_rows()` only:

```diff
-  out
+  ledgr_carrier_new(out, "diagnostics", NA_integer_)
```

Command A applies that patch to a function copy: valid and typed-empty segments pass; NA reason, NA decision time and negative mark age refuse with `ledgr_internal_error`. Add these controls through `ledgr_fold_staging_add()` and assert no row was appended; keep the existing length-refusal class/message and capacity control. This validates the new segment once, not the accumulated prefix on every append.

Separately, `R/backtest-runner.R:121` returns a raw empty publication. P's `ledgr_fill_event_payload('review', NULL, integer(), character(), 0L)` returns `next_event_seq=0`; its own V-publication rejects that result. Route the empty result through construction validation too, preserving the normal numeric-to-integer sequence normalization and argument-refusal precedence. The nonempty path already does this. `contracts.md:250`'s universal construction claim and U-3167/U-3168 cannot be certified until both bypasses are closed.

**F4 — blocking: D9 and D10 are weaker than their stated representation predicates.**

Evidence: `tests/testthat/test-ws4a-carrier.R:2295`, `:3022`, `:3189`; design note `:891`, `:892`, Section 8 rows `:1023`/`:1024` and E5.07. P injects `staged <- lapply(seq_along(i), function(k) list(qty=fill$qty[[k]], fee=fill$fee[[k]]))` into the publication builder: **D9 reports zero hits**. It recognizes explicit list allocation/entry writes and extraction with `[[`, but not this equivalent list-building operation. D1 catches this particular control; that does not make D9's claimed predicate true.

A inserts `sink$equity <- list(n=0L, ts=numeric(1024L), cash=numeric(1024L))` immediately after the memory sink is initialized. The altered constructor executes and retains 1024 rows. **D10 static and runtime checks both report zero findings; a dense sweep completes.** Its static check relies on particular identifiers/assignment spelling; runtime sees service names and row counts, not the sink's extra storage. The existing `equity <- new.env()` control only covers one spelling.

Patch the detectors to recognize economic list construction through iteration and actual extra equity storage/writer ownership, including sink-held columns, rather than helper/variable names alone. Retain the routed metadata and fixed-field-list exemptions. Add the exact controls above, plus their passing controls, and demonstrate each detector's own failure. No product loop or extra record is alleged in the unmodified candidate; this is an acceptance/evidence defect, not a measured performance claim.

**O1 — optional: qualify D20's evidence strength.**

Evidence: `dev/bench/v0_2_3_ws4a/detectors.R:131` defines `sig()` from function formals; routes `:140` through `:145` use signatures for several named operations, and `:135`'s metadata regex is a selected assignment census. Command G/source inspection, against design D20 at `ws4a_carrier_design.md:901`. The twelve output witnesses and the two registered controls are real, but a signature comparison does not establish that every named operation is unchanged. Prefer operation-specific controls for R8.06-R8.10; describe the existing record as signatures/call shapes plus those witnesses. No additional current byte difference was found by C/T/P/Q.

**Recommended dispositions of the maintainer's open items**

| Item | Disposition |
| --- | --- |
| (a) Availability valuation of the 1e308 long | **Type 2 required, F1.** Reproduced against the base on run and sweep. Preserve the distinction between a valuation overflow and a fill-accounting overflow; decide the former explicitly. |
| (b) Compiled fills; openings; dispositions | **Split.** Compiled fills are a blocking amendment implementation gap (F2). Openings and dispositions are not fills, so their exclusion does not itself violate this amendment. Record those separately for typed-accounting design; this review does not authorize new refusals for them or claim their extreme-value semantics are certified. |
| (c) Inf supposedly cannot reach used-row checks | **Reject the blanket belief; preserve allowed values.** P uses dense bars at 1.9, long 1e308 at basis 1 and unchanged target: both base and candidate complete, sweep final_equity Inf. The new equity prefix accepts Inf (`R/fold-carrier.R:148`, `:873`), correctly preserving this result. Add that public regression. Diagnostic numeric fields have different provenance (validated targets, quantities, prices); do not infer their finiteness from finite inputs alone. Install/test their predicate under F3. No new blanket finite-equity rule is justified. |

**Acceptance assessment and failure boundaries**

| Scope | Assessment |
| --- | --- |
| LDG-3167 / Section 8 | Batched canonical application, indexed publication, retained blocks, W1, C13a-c, C14c, M2/M3 and nonempty V-publication/V-leg pass C/T/U/Q. U-3167's empty construction and D9 prevent complete acceptance (F3/F4). |
| LDG-3168 / Section 8 | Capacity, drain, stop installation/counting, frozen equity prefix, producer selection, D2, F4.49, C16/C18 and equity/stop controls pass C/T/U. Diagnostic construction and D10 prevent complete acceptance (F3/F4). |
| Overflow amendment | Canonical finite-input overflow controls, exact class/message and earlier-row precedence pass T/Q. The three precedence-oracle edits are authorized. Compiled coverage is materially incomplete (F2); (a) is outside this amendment. |
| LDG-3169 | Identity and ordinary output evidence are supported within their tested scope. Promotion and NEWS are not yet wholly accurate (F1-F3). All prior broad gate counts remain historical evidence, not proof against these new counterexamples. |

P4 (`R/fold-engine.R:1339`): distinct instruments make a row depend on its own lots and preceding aggregate updates. The failure-only bisection retains the error from the shortest failing prefix. It then constructs earlier publications with `stage=FALSE` before raising that error, preserving an earlier durable metadata refusal. The probe's six differences are exactly pub1_lot2 and pub1_lot2_live **sweeps**, and lot1_pub2/lot_only **run and sweep**; all now use the amended invalid-fill refusal. The earlier publication error still wins in the durable pub1 cases. The three changed assertions in `[WS4a 3167 precedence]` are justified by this amendment alone.

On success, canonical P4 installs book, publishes the block, advances sequence, records legs, then installs positions from net and cash from the ordered effects scan (`R/fold-engine.R:1455`). W1 checks this order with destructive controls. Candidate errors leave book/cash/positions/sequence and handler buffers unchanged (C13b); append, accounting-fact and flush errors reach the enclosing pulse rollback (C13c, LTB-0280, U). Boundary binding precedes candidate computation as before; the unchanged-state claim concerns the named fold/buffer fields, not an assertion that no service method ran. Compiled P4 retains its prior book/sequence-before-append ordering; it is not interchangeable with the canonical overflow behavior (F2). These tests establish the specified pulse failure boundary, not arbitrary DB-fault equivalence for a publication which stage=FALSE deliberately does not execute.

Publication (`R/backtest-runner.R:112`, `R/output-handler.R:27`, `:561`, `:699`): IDs use one vector format over each contiguous block; meta field order, NULL realized-P&L entry, canonical JSON bytes, cash/position auxiliaries and CLOSE-before-OPEN fee splitting are retained. Memory keeps routed metadata and typed leg blocks; retained-block mutations fail C14c. E6 nonfill rows parse metadata once at the adapter and write columns by index. db_live still performs one scalar INSERT per fill (`R/output-handler.R:117`, `R/ledger-writer.R:19`), with its transaction/exception boundaries. It is an explicit retained boundary, not evidence that all publication is now one database operation.

Diagnostics/equity (`R/fold-carrier.R:766`, `:805`, `:849`; `R/fold-phase-contract.R:185`): staging is allocated at max(5N+3, Q_pulse), refuses capacity overflow, emits exactly its used prefix, resets n, and lets the existing writer split chunks. E alone applies a stop, including its count and diagnostic rows; F4.49's doubled-application control fails. P1 writes once per valued pulse; E slices fresh frozen columns. Availability durable finalisation uses the prefix even when empty; dense durable finalisation still replays (`R/run-finalize.R:455`); memory summary reads the supplied prefix. The memory filter at `R/output-handler.R:339` and sequence numbering before filtering are unchanged; C18 checks the gaps. The defects are F3/F4, not a discovered normal trace, counting or finalisation-byte change.

Validator/detector coverage: T executes every registered WS4a V-/U- block and D1-D13, D15-D19, D21-D25, with their controls. Publication/leg checks include storage, length, bounds, typed empty, sequence ordering, tokens, metadata presence and OPEN P&L. Equity/stop checks include used bounds, time order, missingness and stop shape. D1/D3/D6/W1 have production-source/order witnesses; D2 and F4.49 have runtime mutation witnesses. F3/F4 explain why green registered tests do not satisfy the stronger construction and detector obligations. D20 was read with its recorded witnesses/control results, not independently rerun.

**Seven shapes, function census and clarity**

Command A derives the census from parsed definitions, rather than searching only helper names. All 92 entries were included in G's review; removed functions were checked at their replacements. The 18 files with changed functions and the condition-reference data change exhaust the R-file diff. The following owner groups cover nested methods as well as top-level functions; suffixes below omit `ledgr_`.

| Function coverage | Inspection result |
| --- | --- |
| All 31 changed/new `fold-carrier.R` functions: generic/group validators and constructors; segment helpers; provider/execution/P2 adapters; `plan_*` resolution/refusal/groups; diagnostic staging/rows/write/add/block/capacity; equity record/append/prefix | Aligned vectors, prepared positions and fixed schemas; F1/F3 concern validity, not hidden alternative execution. Segment-text iteration is over the bounded reason dictionary. |
| All 19 `fold-engine.R` entries: warning and dense planner; four input-refusal helpers; kind validation; drain; P1-P5; skip decision/plan; candidate; E; two removed pulse-plan accessors | Column handoffs and one E pulse loop. Ordered behavior is visible at stage boundaries. Candidate failure bisection is justified; no normal per-fill dispatch loop remains. |
| `availability-economics.R` planner/affordability and four retired helpers; both cost resolver functions; risk application and replacement post-risk quantity validator; four retired fill-model helpers | Vector costs in fixed step order, cash-dependent affordability scan, one strategy normalization. Dense warning repetition preserves one warning per target. Retired object builders are not relocated to another hot path. |
| `fill_event_payload`, `fill_meta_rows`, `run_fold_impl`, retired fill-row builder; compiled batch wrapper; `fill_publication_deltas`, live writer, input check; `fill_leg_fees`, `lot_apply` | Indexed publication and canonical ordered accounting. Native wrapper retains carried effects; F2 is its uncovered refusal boundary. Metadata/live SQL are the explicit residuals. |
| `fill_leg_block`, both output sinks and every changed handler closure; `fill_row_buffer_add_many`; removed event-row buffer writer | Column blocks and indexed writes, fixed-field loops, fresh retained slices. The memory sink's former equity writer/storage is actually deleted. |
| State constructor/validator, stop constructor/application, retired equity accumulator; removed diagnostic block builder; three finalisation/recovery functions; sweep candidate; retired timestamp helper | One owned equity record, producer-specific finalisation, vector timestamp boundaries. Terminal-recovery per-pulse replay remains explicitly routed to WS7. |

| Optimization shape | Walk result across the census |
| --- | --- |
| 1. Per-element frames bound at end | Removed from the migrated planner/publication/diagnostic/equity paths. Frames remain at public context, writer and result boundaries. No new unjustified per-row frame loop found. |
| 2. Full-table subsets per ID | Run/context positions are prepared at adapters; fill and lot work gathers by integer index. Dense/provider internals are retained scope, not silently reimplemented. |
| 3. Scalar parsing/formatting | Execution epochs and IDs handled in columns; fixed-schema coercions are not data-sized loops. db_live's scalar timestamp/INSERT work is the stated retained exception. |
| 4. Repeated JSON | Routed fill meta/JSON and nonfill metadata parsing remain (`backtest-runner.R:150`, `output-handler.R:712`); P4 itself introduces no encoder. P5 state, reconciliation, intent/stop/exception detail are named routes, not removed work. |
| 5. Discarded/repeated work | Risk compilation validation moves to E; equity has one writer; producer selection avoids accidentally replacing dense replay. Canonical candidate recomputation occurs only on error. Dense replay and recovery replay are explicitly retained, not a new optimization claim. |
| 6. Quadratic validators | Generic validation iterates fixed field sets; row alignment, bounds and ordering are vector checks. No new pairwise data-sized validator found. F3 is a missing invocation; F4 is insufficient detection. |
| 7. Scalar environment-vector writes | Event/leg/diagnostic/equity buffers use indexed `setv`; public/retained prefixes are sliced before reuse. Fixed-column concatenation of a second pending block is bounded by the publication protocol; it is not a newly growing run-long list. |

Allowed growing-collection iteration is explicit: E's sequential pulse loop; affordability's dependent cash scan (`availability-economics.R:344`); FIFO depth and scalar event-order aggregate/Kahan updates (`lot-accounting.R:447`, `:531`); the existing cash scan; error-only prefix bisection; repeated final-bar warnings; db_live INSERTs; routed metadata and terminal-recovery replay. Fixed cost/risk steps and field/dictionary loops are bounded by schemas/plans. **No new unjustified growing-collection loop found.** Clarity: constructors and named adapters have identifiable contracts/callers; the failure path is explainable without relying on the design prose. F3 and the name-dependent detector predicates weaken that clarity at validation boundaries.

**Cold read from code and carrier contract (macro rule 15)**

- **E:** prepare the run axis, imports, services, compiled/risk dispatch, pulse opportunities and epochs; allocate/lock fold state, diagnostic capacity and equity capacity; run pulses in order. E handles skips and is the sole stop installer, then emits completion/frozen result state. Mutable services and returned carrier values have different owners.
- **P1:** settle cash and due dispositions, resolve lifetime/frozen exposure, re-observe and value in run order; update the valuation clock and append equity. Availability returns separate decision packet, current decision data and execution packet. P2 receives no next-bar packet. Dense retains its existing observation/context preparation.
- **P2:** create the public context from current data and cutoff-bound history, call strategy, normalize its full named return once, apply compiled risk steps and check transformed values. Return positional decision columns and opaque state update; stage decision/risk diagnostics. A scheduled skip avoids strategy and planning.
- **P3:** resolve execution opportunities, vector costs and publication deltas; perform ordered affordability admission where applicable; restore accepted rows to decision order. Return typed fill/rejection groups and declared economic kinds, stage diagnostics, or return a typed reconciliation stop before application. Planned positions are diagnostic, not the accounting state.
- **P4:** bind the next corporate-action boundary. Canonical path computes a private candidate book and per-event applied facts; on refusal bisect and check prior publication refusals; on success install/publish/advance/record/install in the order above. Compiled path dispatches its retained native batch and wrapper. Neither path calls strategy or history.
- **P5:** flush publication, advance execution time and reconcile actual cash/gross values, stage/drain diagnostics, normalize/encode/persist the raw strategy-state update, then progress, telemetry and checkpoint in order. Finalisation consumes the producer-appropriate equity source. Valuation time and execution time remain distinct.

Every stage is explainable. This cold read does not erase the nonfinite boundary conflict or imply compiled/canonical refusal parity.

**Test migrations, contracts and evidence truth**

G inspected all changed registered tests against the migration list and the post-checkpoint diff. No unapproved fixture, numerical oracle or refusal-oracle weakening was found. The three amended overflow expectations are the explicit authorized exception; their earlier-row witnesses remain. The four final-candidate infrastructure repairs are justified individually:

| Repair | Evidence and judgment |
| --- | --- |
| d1 profile placement | `tests/testthat/test-accounting-core-consolidation.R:38`; G's `0ec90fee..28ad2542` diff. Moves the declaration next to LTB-0019, preserving its executable fixture/assertions. Repairs discovery, not product behavior. |
| d2 duplicate stable ID | `tests/testthat/test-governance-report.R:1152`, `tests/claims.yml:4595`. Renumbers the distinct later claim to LTB-0522 and updates the mapping. No assertion changes; T passes. |
| e1 LTB-0188 | `tests/testthat/test-ledger-writer.R:323`. Only the exact deparsed-source assertion is guarded outside covr; normal assertion and semantic/allocation checks remain. Instrumented source text is not the asserted ordinary source. T exercises the normal assertion. |
| e2 LTB-0022 | `tests/testthat/test-accounting-core-consolidation.R:223`; `dev/bench/v0_2_3_ws4a/records/ldg3169/README.md:104`. Coverage-only skip is justified by the recorded asymmetric instrumentation effect; ordinary 0.30 bound and mutant are unchanged. The recorded minimum margin 0.055 is thin, not a reason to loosen the oracle. No timing rerun here. |

Existing contract addresses are preserved; the fold-carrier group is additive. Event-staging and carried accounting-effects wording match the implementation, including dense replay and retained adapters. However the universal validation promotion is premature (F3), and NEWS's unqualified refusal/unchanged-results claim fails F1/F2. Its historical sentence also needs “could fail later or complete with non-finite accounting”, since the clarified amendment expressly includes base runs completing with Inf realized P&L. After the scope decision, rewrite NEWS and disposition together; do not use a canonical-only adjective to silently settle F2.

| Evidence claim | Stable pointer and result of audit |
| --- | --- |
| LDG-3167 / LDG-3168 historical gates and migrations | `tickets.yml` entries LDG-3167/3168; `dev/bench/v0_2_3_ws4a/records/ldg3167/README.md`, `records/ldg3168/README.md`, their sequence/migration/gut records. The commands/results have concrete records; C/T/U/Q independently reproduce the selected ordinary/failure witnesses. The stronger construction/detector acceptance claims need F3/F4 corrections. |
| Overflow record and changed oracles | `tickets.yml:1439`, `records/overflow/README.md`, `records/overflow/probe-candidate.txt`; Q reproduces the stated 10 equal/six different outcomes. The statement about “a fill” must be qualified by the unresolved compiled omission until fixed. |
| Final source/gate identity | `ws12_disposition.md:35`, `records/ldg3169/README.md:112`, `records/ldg3169/round2/sequence.log`. G confirms final product equality and evidence-only later changes. Broad counts (36 guts, dense nine arms, A0 295, suite/check) are supported as recorded runs, with their covr-build limitation; not independent reruns here. |
| Snapshot/configuration/store identity declarations | `records/ldg3169/identity.R`, `records/ldg3169/identity.csv:2`, `ws12_disposition.md:45`. Sixteen PASS rows compare 953338df/0ec90fee: hashes, seeded/unseeded IDs, engine JSON, 28 bindings/fingerprint, base-store open and promotion. Product equality carries this evidence to 28ad2542. No identity change found; this does not promise unchanged error behavior. |
| D20 | `records/ldg3169/d20.R`, `records/ldg3169/d20-routes.csv`, `records/ldg3169/d20.log`; recorded signature/route and witness outcomes support their bounded claims, subject to O1. |
| Contracts/NEWS “nothing unimplemented” | `tickets.yml:1442`, `contracts.md:250`, `NEWS.md:10`: not wholly true; F1-F3 prevent closeout. Do not overwrite the historical runs; amend the acceptance conclusions and add corrective evidence. |
| Real-data and coverage | `records/ldg3169/realdata/realdata.txt`, `records/ldg3169/README.md:135`, `tickets.yml:1444`. Six comparisons are maintainer evidence only; no sensitive rows were read/printed. Coverage is explicitly not obtained, non-blocking by the supplied disposition; no figure or proven daemon root cause is asserted. |

Review ratio for this close review: one review, zero correction rounds; checkpoint chain remains its separately recorded three reviews/two corrections. This review adds only this report, makes no commit, and leaves tracked records and generated bindings unchanged. F1 requires the maintainer's Type 2 brief; F2-F4 require corrective evidence and re-review, not automatic acceptance from the ordinary green gates.
