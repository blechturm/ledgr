# Workstream 12 close review

- Reviewer: Codex, independent clean-context reviewer; no implementation or earlier-review authorship.
- Date: 2026-10-31.
- Mode: Type 1; ledgr v0.2.3 cut 5, macro WS4a; LDG-3162 through LDG-3164.
- Reviewed commit: `bee6c02880bd4bdbdd77b7f4abaa72253db3c0dc` (`claude/ws4a-carrier`); acceptance base `0883e079`.
- Verdict: **CHANGES_REQUIRED**. The accepted direction can absorb these corrections; no NEEDS_TYPE_2 issue found. This is not PASS_AFTER_PATCHES: the refusal-order and predicate repairs require implementation and verification.

**Scope and execution**

Read the cut decisions/amendment, synthesis Sections 3.4/4, design note, seven shapes, and candidate README in the requested order. Applied the contract rule groups `contract-execution-fold-core`, `contract-execution-accounting-events`, `contract-execution-event-staging`, and `contract-execution-compiled-accounting`. Did not reopen the maintainer's budget, memory metric, timing deviations, F4.01 settlement, or decision (8).

Command keys below identify commands actually run. `Rscript` was `C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe`; all paths below are absolute. Scratch scripts and results remain under `C:/Users/maxth/AppData/Local/Temp/ws12-close-review/`.

| Key | Command / result |
| --- | --- |
| G | `git -C C:/Users/maxth/ledgr-wt/ws4a-impl diff 0883e079 bee6c028 -- R src tests NAMESPACE DESCRIPTION man`; corresponding `-- dev` changes inspected by file. `git ... diff --name-only df1b3b62 bee6c028 -- R src tests NAMESPACE DESCRIPTION man` is empty. |
| C | `Rscript C:/Users/maxth/ledgr-wt/ws4a-impl/dev/bench/v0_2_3_ws4a/check.R --base=HEAD --out=C:/Users/maxth/AppData/Local/Temp/ws12-close-review/cases`: exit 0, all 23 cases identical. |
| M | `Rscript C:/Users/maxth/ledgr-wt/ws4a-impl/dev/bench/v0_2_3_ws4a/guts.R --base=HEAD --out=C:/Users/maxth/AppData/Local/Temp/ws12-close-review/guts --guts=C3_tolerance_x10,C4_lifo,C5a_reorder_carried_openings,C5b_kahan_on_openings,C6_leave_one_live_lot,C9_drop_comp_in_unpack,C14a_book_by_reference,M3_drop_lot_fee,M5_positions_plus_delta,M7_drop_partial_remainder,M11_uncompensated_totals`: exit 0, eleven expected failures and invalid-base refusal. |
| T | `Rscript C:/Users/maxth/AppData/Local/Temp/ws12-close-review/tests.R`: `testthat::test_local` with exact file filter for ws4a-carrier and all ten changed existing test files; exit 0, all passed. |
| P | `Rscript C:/Users/maxth/AppData/Local/Temp/ws12-close-review/probe.R E:/ledgr-data/r-lib/ledgr-ws4a-df1b3b62`, then the same command with `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`: exit 0; counterexamples below. |
| D | `Rscript C:/Users/maxth/AppData/Local/Temp/ws12-close-review/detectors.R`: exit 0; evaluates the actual test predicates and actual `ws_legacy` definition, without modifying production. |
| X | `Rscript C:/Users/maxth/AppData/Local/Temp/ws12-close-review/differential.R <library> <scratch-output.rds>` for each of P's libraries; compared saved results with `identical()`: 1,260 synthetic fill transitions exactly equal, including every applied row, live FIFO, cached net/basis, totals and compensation. Candidate input books stayed identical after calls. |
| E | `Rscript C:/Users/maxth/AppData/Local/Temp/ws12-close-review/records.R`: reads existing records only; 295/295 A0 PASS, six real-data comparisons, replay memory ratios 0.9216785/0.8765807, reader ratios 0.4081263/0.4049598/0.9873245. |
| F | `Rscript C:/Users/maxth/AppData/Local/Temp/ws12-close-review/patch-probe.R`: exit 0; verifies F2's two exact product patches in local function copies. |

No timing windows, memory workloads, real-data workloads, or full suite were run. T includes the existing depth-scaling unit test. After each pkgload-using run, restored `R/cpp11.R` and `src/cpp11.cpp` with the stipulated `git checkout`. Git needed execution outside the sandbox's ownership check; no Git configuration was changed.

**Findings**

**F1 — blocking — replay changes caller-visible refusal precedence.**

Evidence: `R/accounting-replay.R:332`, `R/lot-accounting.R:532`, versus the base `R/lot-accounting.R:447`; commands G/P. Two prepared dispositions suffice. Give the first a fully closing quantity but an incorrect realized witness; give the second `quantity != abs(position_before)` while keeping its event fields/deltas consistent with its metadata. Base reports `DISPOSITION realized model PnL does not match canonical FIFO realization.` Candidate reports `DISPOSITION lot metadata is malformed.` Both are `ledgr_invalid_ledger_meta`, but the message changes. With the second row instead leaving a live lot, base still reports the first witness error; candidate reports `DISPOSITION must consume the position and every live lot exactly.` with `ledgr_lot_state_invariant`/`ledgr_invalid_state`: the class changes too.

Why: replay checks all disposition metadata before executing earlier rows; within a block the kernel checks all exhaustion failures before any witness failure. Synthesis 3.4 preserves existing semantic checks and the cut permits no condition-semantic change. This answers implementer item (b): reordering is observable, even though successful cases match.

Required repair: preserve the first failure in scalar event order, including metadata, consumption and witness checks. Compute vectorized predicates but select the earliest failing event with its original within-event precedence, or use the existing disposition barrier to preserve that precedence. Add both multi-error controls against the base. No isolated one-line patch is sufficient; do not solve this by changing expected conditions or abandoning block replay for fills.

**F2 — blocking — universal construction checks miss malformed scalars and empty operations.**

Evidence: `R/lot-accounting.R:65`, `:600`, `:602`; `tests/testthat/test-ws4a-carrier.R:74`, `:103`, `:129`; commands P/F. `total_cost_basis = c(0, 1)` with `realized_pnl = numeric()` passes V-book because concatenation still has length three. An integer `total_cost_basis = 0L` also passes after coercion by the other doubles. Conversely, opening/fill/disposition on correctly typed empty columns all throw `Invalid applied lot rows.`: `ifelse(logical(), ...)` yields logical empties. U-3164 and F4.13 require exact per-field types/lengths and typed empty groups, not these weaker tests.

Exact product patches (verified in F):

```diff
-  totals <- c(book$total_cost_basis, book$realized_pnl, book$realized_comp)
-  if (!is.double(totals) || length(totals) != 3L || !all(is.finite(totals))) {
+  totals <- list(book$total_cost_basis, book$realized_pnl, book$realized_comp)
+  if (!all(vapply(totals, function(v) {
+    is.double(v) && length(v) == 1L && is.finite(v)
+  }, logical(1)))) {
-      open_qty = ifelse(opening, 0, open_qty),
+      open_qty = as.numeric(ifelse(opening, 0, open_qty)),
-      realized_delta = ifelse(opening, 0, realized_delta),
+      realized_delta = as.numeric(ifelse(opening, 0, realized_delta)),
```

Add controls for each scalar's type/length independently and assert that all three empty operations return the unchanged book and eight double length-zero applied columns. The current empty-input test never exercises the output constructor.

**F3 — blocking — aggregate and applied-row checks are weaker than their promised invariants.**

Evidence: `R/lot-accounting.R:95`, `:111`, `:340`; `R/fold-phase-contract.R:101`; `tests/testthat/test-ws4a-carrier.R:88`, `:146`; design note F4.12/F4.36; command P. A book constructed with one lot of quantity `1e9` accepts a subsequently corrupted cached net of `1e9 + 1`. An arbitrary finite replacement cost basis also passes. On a pure close of 2 from a 3.5-unit holding, replacing the applied `(close_qty, open_qty)` with `(1, 1)` passes; the registered test only injects `(2, 1)`, which exceeds the fill quantity and therefore proves a weaker bound.

Item (a) needs a distinction: no tolerance is applied between fold positions and book net; that equality check is omitted, as the F4.01 amendment requires for imports. The `sqrt(eps)` tolerance is instead a relative check of cached book net against re-summed live lots, also used at compiled unpack and stop validation. The amendment does not relax this separate F4.12 invariant. Incremental arithmetic can differ from a fresh reduction, so simply demanding exact equality would also be wrong; the chosen tolerance has no arithmetic-error justification and permits material corruption on a simple one-lot book. A second `sqrt(eps)` allowance is used for applied quantity splits.

Required repair: preserve canonical incremental values and imported positions, but justify/test the validation error bound against canonical accumulation and add a sensitive corruption control; cover cost-basis derivation at the appropriate construction/transition boundary. Add a production before/after predicate for the actual pure-close/open split, with the balanced `(1, 1)` control failing. These changes need an arithmetic argument and verification, not an arbitrary smaller epsilon patch.

**F4 — blocking — D3, D11 and D25 do not implement their design-note predicates; D12a and M11 are incomplete.**

Evidence: `tests/testthat/test-ws4a-carrier.R:233`, `:296`, `:337`, `:465`; `dev/bench/v0_2_3_ws4a/guts.R:187`; design note Section 6/8; commands D/G/M. The actual predicates report zero hits for these violations:

- D3: `book$net_by_inst[["synthetic"]]`. It recognizes a short list of variable spellings, not character indexing; `match()` lookup is also unchecked. Its examined functions omit the opening builder, chunked reader, handler and walk-forward consumers rather than explicitly locating their boundary regions.
- D11: `fold_state$positions <- planned`. Only `+`/`-` assignments are forbidden; the positive check merely requires `net_by_inst` somewhere in any examined function. It cannot establish that each touched position comes from the book.
- D25: `for (k in seq_along(pos)) book$lot_qty[book$offset[pos[k]] + 1L] <- qty[k]`. It only forbids calls to five lot functions inside loops, allowing inline per-instrument consumption/append/growth. Requiring a Kahan call somewhere in the aggregate loop does not delimit that loop's allowed work.
- D12a hashes frozen C1 JSON and changes that fixture as its control. It does not exercise current production configuration construction or store bindings. The current C1 case separately passes, but does not replace the missing own production predicate/control in this test.
- M11 is registered as `cumsum totals`, but its implementation only replaces Kahan with uncompensated addition. Its expected failure does not prove that vectorizing total-basis updates to `cumsum` would be caught.

Why: passing labels are not substantive completion of the owning ticket. Expand the named parse regions and check actual index/write provenance; restrict independent lot work outside an explicitly identified ordered aggregate scan. Add the listed violating controls, a production store/configuration control, and a real total-basis `cumsum` mutation. No exact local edit fixes this collection of predicate gaps; retain existing controls as well.

**F5 — blocking — C14's projection weakens within-candidate ownership evidence.**

Evidence: `dev/bench/v0_2_3_ws4a/lib.R:160`, `cases.R:411`, `:425`, `:441`; commands D/C/M. `ws_legacy` is reasonable for comparing the new layout with frozen base fingerprints. However, C14 also compares capture versus end only through that projection. Changing a typed column's names is hidden by `setNames`; changing an empty segment's offset is hidden entirely. Both raw retained values change while the projected value remains identical. The existing by-reference gut catches a quantity mutation, not all retained-book mutations. This answers item (c): the projection hides actual representation changes that the ownership case should witness.

Exact additive harness patch: retain the existing frozen projected comparison, and in `ws_keep`, after storing `env$value[[name]]`, add:

```r
if (name %in% c("book_handout", "compiled_input", "corporate_action_view")) {
  env$raw[[name]] <- serialize(value, NULL)
}
```

At the start of `ws_retained`, add:

```r
ws_need(all(vapply(names(env$raw), function(k) {
  identical(env$raw[[k]], serialize(env$value[[k]], NULL))
}, logical(1))), "retained native book representation unchanged")
```

Add a control for a projection-invisible mutation. This adds a native before/after invariant without changing frozen base bytes. It must be exercised on C14a/b; unlike F2, this proposed patch was not run through the full case harness in this review.

**F6 — blocking — the enumerated boundary list is incomplete.**

Evidence: `tickets.yml:1248`, `R/lot-accounting.R:689`, `R/accounting-replay.R:268`, `:318`, `R/terminal-outcomes.R:141`, `R/walk-forward.R:1205`, `:1292`; command G and `rg -n` for `match`, `position_index`, and the named functions. No surviving named-list FIFO or per-fill instrument-name lookup was found in R/src. But the evidence list omits actual name-keyed boundaries: `ledgr_lot_book_from_opening`, `ledgr_prepare_accounting_events`, replay's initial-position/result boundary, and the walk-forward opening/carry functions. Disposition also maps IDs to positions inside `ledgr_disposition_post`. `ledgr_lot_book_live` is positional and does not itself account for those mappings.

Required patch: enumerate these exact functions/sites and their import, replay, settlement or result roles in the ticket evidence/design census; specify whether the settlement boundary includes `ledgr_disposition_post`. Make D3's allowlist match that enumeration. The algorithms need no new adapter wrappers solely to rename existing boundaries. Acceptance item 1 explicitly requires the complete enumeration.

**F7 — optional — make the candidate evidence reference immutable.**

Evidence: `tickets.yml:1249`, `dev/bench/v0_2_3_ws4a/records/ldg3164/README.md:3`; commands G/E. Replace the literal `(commit on claude/ws4a-carrier)` with `(record commit bee6c028; product candidate df1b3b62)`. The current branch description is not an immutable revision. Correct the substantive detector/boundary claims under F4/F6 when their repairs land, and record the new tested product identity after F1-F3.

**Acceptance and kernel assessment**

| LDG-3164 acceptance item | Assessment |
| --- | --- |
| Single FIFO, positional consumers, enumerated boundaries | Old named-list helpers and callers removed; src unchanged. Positional product implementation passes inspection; completeness blocked by F4/F6. |
| Opening Kahan detector and typed LIFO mutation | Pass: D7 counts even discarded Kahan calls and preserves nonzero compensation; C4 LIFO and C5b/M6 fail as required. |
| Exact public/real-data oracles | C reproduced 23 cases. Maintainer records establish A0 295/295, nine dense arms and six real-data comparisons on the same product bytes. C14 ownership evidence needs F5. |
| Replay timing/memory decision (6) | Settled on consecutive blocks. Existing ratios independently recomputed in E pass; deferred fold/sparse/marginal/forward gates remain at LDG-3169. |
| Full suite | Maintainer `sequence.log:9` records exit 0; not rerun. T independently passed eleven targeted files. This does not discharge F1-F6. |

Section 8 coverage: D7, D12b/c/e, D15, D17, D18, D19, D23 and the F4.35 opening caller cash witness have production checks and failing controls. D3/D11/D12a/D25 and M11 have F4's gaps. V-state is installed at construction and stop paths; U-3164/V-book/V-applied-row have F2/F3's gaps. V-lot-input checks typed inputs and duplicate positions, but its empty-input PASS does not imply empty-operation PASS. The remaining owned mutations M1/M3/M5/M6/M7/M12 ran through their typed attachments and failed their cases.

FIFO head consumption, partial remainders, fee subtraction/leg split, openings without Kahan, ordered total-basis/Kahan facts, distinct-instrument wrappers, ordinary copy-on-modify, gather growth/compaction, and compiled pack/unpack agree with the accepted arithmetic on inspected code, T, C, M and X. The block split is conservative: once an instrument repeats within a run it can split more often than necessary, but no block repeats an instrument or reorders a row. No new second execution engine or C++ change was introduced. Refusal behavior and construction guarantees are the exceptions above.

**Seven-shapes walk**

Scope walked: all changed functions in `lot-accounting.R` (book constructor/problem/validate/extend/restrict/live-count/live; dust-row, Kahan, cash scan, side; input/applied/apply; three operation wrappers; blocks/apply-blocks; opening/events/as-of builders); accounting prepare/replay including scatter; fills reader; run setup; compiled pack/unpack/batch; carrier import/settlement/install/result; fold observe/decide/plan/apply/envelope and state validator; handler accounting fact; sweep candidate setup; disposition posting; both walk-forward opening/carry functions. Also traced unchanged resume/result replay and terminal recovery/finalisation callers through the shared replay. Deleted helpers were checked for remaining callers.

| Shape | Result across that scope |
| --- | --- |
| One-row frames / bind at end | No new per-row frames in lot work; applied columns are preallocated. Existing handler row/leg staging remains explicitly owned by LDG-3167; result/carry frames remain boundary work. |
| Full-table subset inside ID loop | Replaced lot lists/ID traversal with indexed segments, gathers and prepared replay indices. Name conversions at boundaries need F6's complete census. No new repeated table subset found. |
| Per-element parse/format | Kernel uses primitives; replay prepares timestamps once. Existing fill/publication conversions remain with LDG-3166/3167. No new parsing loop introduced. |
| Repetitive JSON | Existing event metadata preparation and disposition publication retained under WS7/WS8 routes. Added typed fields are projected in the existing preparer loop; no new JSON path. |
| Recomputed/discarded work | Cached net/basis retained, compiled pack gathers, readers share replay. E/stop book validation has its stated boundary purpose; terminal recovery's repeated replay is unchanged and routed to WS7. |
| Quadratic validators | Book checks use vector predicates/rowsum; replay position history uses sorting/cumulative indices. No new pairwise validator. F2/F3 concern what validators prove, not quadratic shape. |
| Scalar writes into environment-held vectors | Lot columns are local copy-on-modify values. New cash/aggregate scans write local typed vectors; replay writes by block. P4 singleton installation is explicitly allowed until LDG-3167; output staging retains its existing owner. |

New data-growing loops all have stated reasons: FIFO depth (`lot-accounting.R:395`), scalar event-order cash (`:241`) and totals (`:571`), and consecutive dependent replay blocks (`:663`). Fixed-column/argument loops do not grow with data. No new unjustified growing-collection loop found. D25 nevertheless must reject reintroducing one (F4).

**Test migration, evidence and independent input challenge**

Every changed existing test block/helper is on design Section 5's migration list: LTB-0019/0022, lot-accounting's two blocks, LTB-0497/0498, execution-spec helpers and LTB-0006, LTB-0278, LTB-0137, disposition helper/LTB-0050, sweep opening summary, LTB-0024 and LTB-0171. Inputs, numeric oracles, fault location and thresholds were preserved; the explicitly accepted unnamed-position inversion was used. No product-test fixture/oracle was weakened to hide a failure. F5 is a separate harness ownership-witness weakening, not an authorized change to successful economics.

LDG-3162/3163 evidence points to frozen preparation commits and the named register/records; those pointers resolve (including `7c23d41e` base/detector/mutation/memory/real-data records). Their historical preparation claims do not certify today's production attachments. LDG-3164's recorded numeric outcomes are supported by E and the maintainer README/sequence log; the D3 and boundary-completeness claims overstate the evidence (F4/F6), and F7 corrects one revision pointer. Full-suite/dense/real-data claims here remain attributed to the maintainer, not presented as independent reruns.

Independently, a single positional, copy-on-modify lot implementation is the right seam: the base differential and distinct-instrument block execution preserve scalar economic order while removing the former repeated ID resolution. Keeping metadata architecture and finalisation selection outside this ticket is consistent with the contract boundaries. The frozen oracles are valuable but cannot alone establish structural invariants, malformed-input precedence or native handout isolation; the accepted design already requires those additional checks. These are repairable implementation/evidence failures, not grounds to renegotiate the accepted design or its deferred gates.
