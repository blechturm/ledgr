# v0.2.3 Inventory Reconciliation

**Role:** planning input; first planning duty of the v0.2.3 packet README.
**Status:** provisional. Agent audit (Type 2) from a brief drafted by Claude for
the maintainer; it binds nothing until the maintainer has read brief and result
together. Every `proposed` disposition is a maintainer decision.
**Date:** 2026-10-27.

## Basis

- Product state is read at `refs/tags/v0.2.2` (`7539be45`). Between the tag and
  `v0.2.3` HEAD `59f36972` no file under `R/`, `tests/`, `man/`, `vignettes/`,
  `src/`, `tools/`, `NAMESPACE`, `DESCRIPTION`, `README.md` or `NEWS.md`
  differs, so product `file:line` citations hold at both.
- Design-document line numbers are at `59f36972`.
- Inputs:
  - roadmap "Current planning release";
  - v0.2.2 `macro_plan.md` Section 5 and the Section 7 next-version routes;
  - horizon entries and `rfc/README.md` rows naming the next release, v0.2.3
    or "after v0.2.2";
  - the two pending `decisions.md` rows.
- Archived horizon redirects with no current authority are excluded.
- Routes follow `rfc_cycle.md` "Routes": RFC, spike, direct ticket, audit,
  measurement or chore. "Type 2 at cut" marks a direct ticket whose workstream
  chooses public semantics or identity and so needs Type 2 review first.

## A. Carried commitments

| ID | Item | Source | State in v0.2.2 tree (evidence) | Proposed disposition | Route | Depends on |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | Execution-core consolidation onto the availability path: bars-only happy path with a disclosed implied calendar, removal of the WS40-42 branches and collapse primitives where profiled | roadmap:109-113; macro_plan:1048-1089 | Open. `availability_active` occurs 143 times in 14 R files, 48 in `R/fold-engine.R` and 30 in `R/backtest-runner.R`. The dense planner is still selected at `R/fold-engine.R:1096-1097`. Dense-only `ledgr_backtest()` is still exported (`R/backtest.R:86`, `NAMESPACE:99`). | included | direct tickets, Type 2 at cut (implied-calendar disclosure, dense identity bump, fate of `ledgr_backtest()`) | C6 (recommended first, not required); LDG-3074 branch census |
| C2 | Retire the `ctx` frame views (`ctx$bars`, `ctx$feature_table`, `ctx$features_wide`, `ctx$bar(id)`) | roadmap:114-115; rfc/README:106; macro_plan:696-698 | Open. Views are still built per pulse (`R/pulse-context.R:17-18`, `:329-340`). There is no seed in `rfc/`. | included | RFC (focused inspection-boundary seed) | Feature-map synthesis (accepted). Implementation needs the availability fast context, so it follows or joins C1. |
| C3 | Persisted-data execution placement and DuckDB boundary | roadmap:115-117, 125-127; rfc/README:87 | Open. No seed exists, and the pipeline row still says Parked although its trigger ("after v0.2.2") has fired. | included; change the row from Parked to Due (proposed) | RFC | none; it precedes any hashing, fact or projection move to DuckDB and feeds C5 |
| C4 | Cheap, versioned pulse-seed counter rule | roadmap:118-124; horizon:223-251 | Open. Every pulse runs `canonical_json` plus SHA-256 (`R/rng.R:21-31`, `:33-57`), called from `R/fold-engine.R:766`. | included | direct ticket, Type 2 at cut (changes stochastic results and identity) | Coalesce the identity bump with C1 and C11 to save one lake rebuild (horizon:610-614) |
| C5 | Structural memory reduction, phase-level measurement and parallel-worker budgets | roadmap:125-127, 185-188; macro_plan:699-704; horizon:744-777; history-wave register E6-E8 | Partly measured. One-/two-worker peaks are 1.89/4.46 GiB and four-/eight-worker diagnostic peaks are 5.94/8.71 GiB (`integrated_release_closeout.md:167`, `:187`). No structural reduction or worker budget exists. | included | measurement, then spike or direct tickets; worker defaults need Type 2 at cut | C3, C6, C1, C2 (views hold 6-8% of the R heap peak) |
| C6 | One output handler behind a sink interface | roadmap:128-136; horizon:517-525 | Open. Two handlers remain: `ledgr_persistent_output_handler` (`R/backtest-runner.R:252`) and `ledgr_memory_output_handler` (`R/sweep.R:1982`). | included | direct ticket | none; it triggers R3 |
| C7 | Typed P3-P5 execution batch | roadmap:137-153; horizon:253-287 | Not started. WS8 routed target planning (4.97 s) here (`integrated_release_closeout.md:162`). | included | measurement (no-fill, sparse and wide workloads), then direct tickets; compiled parts go to the compiled-envelope RFC | C6, C1, R3 |
| C8 | One result reader and print path | roadmap:154-161; horizon:531-534 | Open. Three reader families remain: `R/backtest-results.R` (1,393 lines), `R/availability-results.R` (896) and `R/corporate-action-results.R` (717). | included | direct ticket; byte-identical output or maintainer-decided differences | C1 |
| C9 | Explicit export tiering before CRAN | roadmap:162-171; horizon:119-148 | Open. 181 `export()` lines; the tier exists only as pkgdown grouping. | included | RFC (small Type 2 on the mechanism, amending the Internal Names rule group), then direct ticket | C10, H4, C8, H1, H3 |
| C10 | Core boundary measurement and ADR | roadmap:172-184; horizon:32-84 | Not started. `adr/` holds only `README.md`; the audit CSV input exists. | included | measurement (four inputs), then ADR (Type 2) | H4 informs it; it precedes C9 |
| C11 | Cross-asset price precision and tradability | roadmap:191-195; rfc/README:91; horizon:150-165 | Open. Prices are rounded to 8 decimals (`R/snapshot_adapters.R:123-127`, `R/availability-ingest.R:176-180`, `R/snapshots-hash.R:107`). Quantities are floored to whole units (`R/strategy-helpers.R:479`). | included | RFC | Identity bump coalesced with C1 and C4 |
| C12a | Affordability default and execution-policy vocabulary | roadmap:196-210; rfc/README:97 | Open. A fill is rejected whole in stable-ID order (`R/availability-economics.R:344-389`); the reason is recorded only in diagnostics. | included | RFC | C11 (quantity step for scaling); consumes D2's OMS questions Q16 and Q18 |
| C12b | Report existing refusals in `print()`, the summary and run completion | roadmap:206-207 | Open. The `insufficient_cash` reason is set only inside the affordability pass (`R/availability-economics.R:368-372`). | included | direct ticket (no RFC) | none; best landed on C8's merged print path or before it |
| C13 | Public `ledgr.crypto2` promotion proof | roadmap:211-217; rfc/README:90; horizon:167-191 | Evidence complete (`7a4a1025`); the adapter is private by design. | deferred again (proposed): a separate sister-package packet after the v0.2.3 core outcomes are accepted | separate packet | C10, C11 |

## B. Research UX completion

| ID | Item | Source | State in v0.2.2 tree (evidence) | Proposed disposition | Route | Depends on |
| --- | --- | --- | --- | --- | --- | --- |
| U1 | Reconcile the Research Strategy UX Brief with the shipped tree | roadmap:92-94 | Its Section 7 table is stale. It lists the alias-aware read and the schedule decorator as "proposed" (`research_strategy_ux_brief.md:445`, `:449`), but both shipped (feature-map synthesis; Cut 21). The history-to-selection bridge shipped as `ledgr_align_weights()` (LDG-3099). Only rows `:451-453` remain parked. | included | chore | none |
| U2 | Bounded portfolio-construction gaps: Momento transitions, omitted holdings, index leavers, no-trade band, current weights, idle cash | roadmap:95-105; rfc/README:95 | Open. The row's trigger ("after the public historical surface ships") fired with v0.2.2, but the row still says Parked. A rebalance still liquidates unnamed holdings unless they are in `keep` (rfc/README:95). | included; change the row from Parked to Due (proposed) | RFC (no optimizer catalogue) | C12a, C11. The advanced teaching article (horizon:193-222) follows it. |
| U3 | Declared strategy-helper bundles | rfc/README:96; horizon:1819-1851 | Due; not started. | included | RFC | absorbs R4 |
| U4 | Scheduling gap exposed by the estimator article | roadmap:102 | Done by Cut 21 and Cut 22. The article uses `ledgr_strategy_schedule(ledgr_schedule_month_start())` (`vignettes/minimum-variance.qmd:289-291`). LFB-035 stays research-side. | completed | none | none |

## C. Macro-plan Section 5 deferred maintenance

| ID | Item | Source | State in v0.2.2 tree (evidence) | Proposed disposition | Route | Depends on |
| --- | --- | --- | --- | --- | --- | --- |
| M1 | Defensive-code and complexity audit, including tolerances, the store-open retry and large test files | macro_plan:708-710, 723-725; horizon:567-602 | Open; there is no audit file in `audits/`. The retry still makes 50 attempts with `gc()` (`R/public-api.R:10-33`, `R/store-gate.R:246-256`). Eight test files besides the documentation contracts exceed 1,000 lines, up from five; the largest are `test-history-substrate.R` (2,640) and `test-strategy-schedule.R` (1,933). | included; run after C6 and C1 so it does not audit code they delete (proposed) | audit | C6, C1 |
| M2 | Adoption item: survivorship-bias article on synthetic data, plus a CRAN target date | macro_plan:711-712 | The article exists (`vignettes/survivorship-bias.qmd:102`, added `562e1196` on 2026-09-12). No release is named as the first CRAN release. | article completed; CRAN target date included as a maintainer decision (proposed) | chore (decision) | It gates M4, M6 and the R1 publication cut |
| M3 | v0.2.1.0 packet path (`ledgr_v0_2_0_2_spec_packet/`) | macro_plan:713-714 | Unchanged; the path exists. Cut 23 decision (3) declines mass renames (`tickets.yml:358`); the roadmap Boundary forbids redirect trees. | included as a one-line decision: keep the path (proposed) | chore | none |
| M4 | Install floor: `R (>= 4.6.0)` plus a hard DuckDB dependency | macro_plan:715-717 | Open. `DESCRIPTION:18` and `:26` require DuckDB `>= 2.0.0`, raised at release by decision 12. `README.md:69` states the floor without a reason. | included | measurement (lowest passing R and DuckDB), then chore | M2, R1 |
| M5 | Documentation surface, paired with export-audit F7 and F9 | macro_plan:718-720; export audit F7, F9 | Worse than when deferred: 40 of 159 Rd pages lack `\examples` (was 39 of 156), 9 use `dontrun` (was 6), and `@inheritParams` appears in 1 R file. Family topics are still named after one member (audit F9). | included | chore | R2, C9, C10 |
| M6 | Collapse NEWS.md into one first-release entry | macro_plan:721-722 | Open; NEWS.md has 1,938 lines (was 1,544). | included if v0.2.3 is the CRAN release, otherwise deferred again (proposed) | chore | M2 |
| M7 | Plotting pass: six plots, each signed off by the maintainer | macro_plan:705; roadmap:185-188; roadmap row added in `7aad7e1f` | Not done. `ggplot(` appears only in the four pre-existing articles (metrics-and-accounting, survivorship-bias, sweeps, walk-forward). The six-plot list survives only in commit `7aad7e1f`. | included (proposed) | chore, with per-plot sign-off at the cut | R2 |
| M8a | Print chore: the run-list footer "INCOMPLETE metrics describe the achieved prefix only" prints even when no run is INCOMPLETE | roadmap:185-188 ("print/result-reader"); roadmap row at `7aad7e1f` | Open; the footer line is unconditional (`R/run-store.R:934-940`). Chore (1) of that row, readable sweep parameters, was completed by LDG-3103. | included | direct ticket | C8 |
| M8b | Print chore: one named `LEDGR_LAST_BAR_NO_FILL` warning per run | same | Open in dense mode only. The sole caller is the dense planner (`R/fold-engine.R:161`, selected at `:1096-1097`); the availability planner never calls the warning. | superseded by C1 (proposed). C1 must state how the surviving path discloses a final-bar no-fill. | direct ticket within C1 | C1 |
| M9 | The other Section 5 non-goals: shorting/leverage, model lifecycle, fitted imputation, exact-quantity settlement, portfolio scaffolding/Schur, one store connection per composite call, derivatives/FX, compiled default or expansion, historical-RFC rewrites, broad optimization cleanup | macro_plan:684-706; roadmap:189-190 | Unchanged; each keeps its pipeline row. The one-store-connection item has no pipeline row, only horizon:645-647. Scheduler v2 (macro_plan:690) was completed by Cut 21. | deferred again by the existing roadmap decision (no new proposal); scheduler v2 completed | named RFC rows | none |

## D. Horizon and macro-plan Section 7 next-release routes

| ID | Item | Source | State in v0.2.2 tree (evidence) | Proposed disposition | Route | Depends on |
| --- | --- | --- | --- | --- | --- | --- |
| H1 | Export audit F1-F4 and F6 (result-reader and symbol surface) | horizon:99-103; export audit Section 6 | Open. Present: `ledgr_sweep_returns_*` (`R/sweep-retention.R:291`, `:413`, `:494`, `:510`, `:528`); `ledgr_pulse_features`/`_wide` (`R/feature-inspection.R:348`, `:556`); the promotion-context pair (`R/promotion-context.R:295`, `:319`); `ledgr_run_fills` (`R/backtest-fills.R:57`); the always-aborting `ledgr_opening_from_broker` (`R/experiment.R:695`, `NAMESPACE:180`). | included | direct tickets, Type 2 at cut (public removals that move contract sentences) | C8 for F1 and F4; H4 for the earn-its-keep part of F1. Precedes C9. |
| H3 | Export audit F8: three verb-first helpers outside the R1 allowlist | horizon:110-112; export audit F8 | Open. The contract allowlist (`contracts.md:45-48`) omits `ledgr_select_top_n`, `ledgr_passed_warmup` and `ledgr_align_weights`, all exported. | included | RFC (contract amendment decision; option (a) is the smallest) | Precedes C9 |
| H4 | Prove or retire the thinly used product surfaces on real data | horizon:411-448; named in roadmap:163-164 | Open. All seven files remain: `validation-pbo.R`, `business-objective.R`, `sweep-review.R`, `sim-pit-inputs.R`, `indicator-dev.R`, `signal-strategy.R`, `walk-forward-inspection.R`. | included; each removal is a separate maintainer decision (proposed) | audit (real-data use in ledgr-research, then a per-block decision) | Precedes C9 and informs C10; may make D1 moot |
| H5a | Export-census gate (unused export becomes internal) | horizon:460-463 | Never built; no export-census tool in `tools/` or `tests/`. | superseded by C9 (the tier enters the export lock test) | none | C9 |
| H5b | Pin roxygen collation with a `tools/document.R` entry point | horizon:476-490 | Not done; `tools/document.R` is absent. The v0.2.2 hygiene workstream did not take it. | included (proposed) | chore | none; land it before M5's Rd regeneration |
| H6 | Gap between committed run and ephemeral sweep | horizon:623-660 | Re-measured on the v0.2.2 peer record: durable 30.02 s against public sweep 18.30 s cold (`integrated_release_closeout.md:135-136`), down from about 3x. Lever 1 (rehash) landed with WS5-A. | superseded by C6, with lever 3 under the compiled-envelope RFC | measurement after C6 | C6 |
| H7 | Run-telemetry redesign (`ledgr_backtest_bench()`, `telemetry_stride`) | macro_plan:1367-1381; `integrated_release_closeout.md:168` | Kept unchanged by WS53; its trigger is "after fold, output-handler and context unification". | deferred again (proposed), unless C1, C6 and C2 land early in the cycle | RFC | C1, C6, C2 |
| H8 | With `seed = NULL`, save and restore the caller's RNG around worker start and stop (maintainer: yes, 2026-10-22) | macro_plan:1302-1310 | Open. Cut 19, the cleanup cut the decision named, did not take it. The RNG is restored only when `!is.null(seed)` (`R/sweep.R:157-174`); `ledgr_parallel_mirai_start/stop` save nothing (`R/parallel-workers.R:329-338`). | included | direct ticket | none; ride C6 or any sweep-backend cut |
| H9 | Reuse walk-forward daemons across folds | macro_plan:1311-1316 | Open. Each fold calls `ledgr_sweep_window` (`R/walk-forward.R:565`), which starts and stops daemons per sweep (`R/sweep.R:224-225`). | included | direct ticket (owner C1) | C1, C5 |
| H10 | Corporate-action settlement state carried as data | macro_plan:1317-1323 | Open; listed out of scope in `tickets.yml:283`. | included | direct ticket, Type 2 at cut (fold-output and carried-opening identity) | C1 |
| H11 | Reopen shared memory (E6) | macro_plan:1291-1301; register E6 | Measured. The 8-worker peak of 8.71 GiB stays below the 12 GiB trigger, so shared memory stays deferred (`integrated_release_closeout.md:167`). | deferred again by the existing WS53 decision; folded into C5 | measurement inside C5 | C5 |
| H12 | Pre-CRAN API cleanup (macro_plan:1093-1154): remove `ledgr_param_grid`, inspect a pulse by session date, print sweep parameters | macro_plan:1100-1109 | Done. LDG-3102 removed `ledgr_param_grid` (absent from `NAMESPACE`), and LDG-3103 prints the parameters. A `Date` cutoff resolves to the session close (`R/pulse-snapshot.R:437-439`, `R/experiment.R:363-392`). | completed | none | none |
| H13 | Lazy evidence in history reads | macro_plan:1278-1290 | Replaced by the manifestation correction (LDG-3105, complete). | superseded by LDG-3105 | none | none |

## E. RFC pipeline and decisions bridge

| ID | Item | Source | State in v0.2.2 tree (evidence) | Proposed disposition | Route | Depends on |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | Release candidate, CI gate and evidence reuse | rfc/README:85; packet README duty 3 | Due; no seed. Publication took about 8 hours (`release_gate_closeout.md:236-241`). The fast lane ran 113.35 s against its 112 s threshold and was accepted as an exception, and the local Ubuntu gate was unavailable (`tickets.yml:2981`). | included | RFC | Precedes the next publication cut; feeds M4 |
| R2 | Documentation roles and pin reset, including the TR-1 contradiction in `ttr-indicators` | rfc/README:86 | Due; its trigger is the first v0.2.3 cut. TR-1 was routed, not fixed (`release_documentation_coherence_closeout.md:98`). The audit input is unreviewed. | included | RFC (Type 2 decision), then direct tickets TR-2 to TR-6 | Precedes M5 and M7 |
| R3 | Fold-phase obligations: fill-delta unification and leg-fee projection | rfc/README:108 | Obligations open; C6 (or the compiled envelope) triggers them. | included | direct ticket inside C6 or C7 (no new RFC) | C6 |
| R4 | External-helper preflight boundary | rfc/README:105 | Obligations open; same surface as U3. | superseded by U3 (proposed: U3 consumes it) | none | U3 |
| D1 | Objective-filtered walk-forward identity | decisions.md:26 | No owner; the trigger has not fired (no workflow lets an objective select). | deferred again (proposed) | RFC when triggered | H4 may retire its surface |
| D2 | OMS order lifecycle | decisions.md:27 | No owner. | Q16 and Q18 superseded by C12a; the rest deferred again (proposed), behind PIT fundamentals in the long-term order | RFC | C12a |

## Dependency chains, duplicates and unowned items

- **Chain 1, execution core:** C6 (with R3), then C1 (with H9, H10, M8b), then C7. C8 follows C1, and C12b and M8a ride C8.
- **Chain 2, export surface:** H1, H3, H4 and C10 finish before C9 starts.
- **Chain 3, economics:** C11, then C12a, then U2.
- **Chain 4, identity bumps:** C1, C4, C11 and H10 share one format and identity bump, so the private lake is rebuilt once.
- **Chain 5, documentation and memory:** R2 precedes M5 and M7. The M2 CRAN decision gates M4, M6 and R1. C5 measures after C3, C6, C1 and C2.
- **Duplicates, part 1:** macro Section 5's context-frame and memory items repeat C2 and C5. Six horizon entries repeat carried rows (export tiering, core boundary, pulse seed, typed batch, asset precision, crypto).
- **Duplicates, part 2:** export audit F5 sits in C1, and F7 and F9 sit in M5. R4 duplicates U3, H11 duplicates C5 and H6 duplicates C6.
- **No owner:** the roadmap's "plotting" (M7) and "print/result-reader" (M8a, M8b) have no item list in any current document; it survives only in commit `7aad7e1f`.
- **No owner:** the H8 seed-RNG decision missed the cut it named.
- **No owner:** no release is named as the first CRAN release (M2), although C1, C9 and C12a are bound to precede it.
