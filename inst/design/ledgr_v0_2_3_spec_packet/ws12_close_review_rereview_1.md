# Workstream 12 close review: re-review 1

- Reviewer: Codex, independent clean-context reviewer; neither implementation nor close-review author.
- Date: 2026-10-31.
- Mode: Type 1 against cut 5 and close-review F1-F7; LDG-3162 to LDG-3164, macro WS4a.
- Reviewed commit: `b7bffc0acc733e501292d05e08e39f77a4981d28`, branch `claude/ws4a-carrier`; corrections `c81c5087..b7bffc0a`.
- Verdict: **PASS_AFTER_PATCHES**. Apply blocking N1 and N2 exactly, including their additive controls; no further review is required. No item needs Type 2. O1/O2 are optional.

Authority: cut decisions and F4.01 amendment; synthesis Sections 3.4/4; design note Sections 1.6/8; contracts `contract-execution-fold-core`, `contract-execution-accounting-events`, `contract-execution-event-staging`, `contract-execution-compiled-accounting`; optimization manual's seven shapes. The budget, heap metric, timing deviations, amendment and LDG-3169 gates were not reopened.

Commands below were executed. `ROOT` denotes `C:/Users/maxth/ledgr-wt/ws4a-impl`; `S` denotes `C:/Users/maxth/AppData/Local/Temp/ws12-rereview-1`; substitutions were absolute paths in actual commands. All R invocations used plain `Rscript`. Scratch scripts remain available there.

| Key | Command and result |
| --- | --- |
| G | `git -C ROOT diff c81c5087 b7bffc0a`, inspected by file; `git -C ROOT rev-parse HEAD`; source reads and `rg -n` searches. |
| C | `Rscript ROOT/dev/bench/v0_2_3_ws4a/check.R --base=HEAD --out=S/cases`: exit 0; 23 cases identical, including C14a/b. |
| M | `Rscript ROOT/dev/bench/v0_2_3_ws4a/guts.R --base=HEAD --out=S/guts --guts=C3_tolerance_x10,C4_lifo,C5a_reorder_carried_openings,C5b_kahan_on_openings,C6_leave_one_live_lot,C9_drop_comp_in_unpack,C14a_book_by_reference,M3_drop_lot_fee,M5_positions_plus_delta,M7_drop_partial_remainder,M11_uncompensated_totals,M11_cumsum_total_basis,C14a_rename_by_reference`: exit 0; all 13 expected failures and invalid-base refusal. |
| T | `Rscript S/tests.R`: exact `test_local` filter `^ws4a-carrier$`, all pass. `Rscript S/changed-tests.R`: the ten other test files changed since `0883e079`, all pass (accounting-core-consolidation, availability-parity, corporate-action-disposition, cross-asset-corrections, execution-spec, fold-phase-contract, lot-accounting, risk-fold, sweep, terminal-outcomes). |
| P | `Rscript S/probe.R base` and `Rscript S/probe.R candidate`: same registered F1 test expression, eight successes each; drift example equal. Base library `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`; candidate loaded from ROOT. |
| X | `Rscript S/mixed.R base` and `Rscript S/mixed.R candidate`: base succeeds; candidate refuses N1's synthetic ledger. |
| D | `Rscript S/detectors.R`: actual D25 predicate misses callback control (0 hits); previous predicate catches it (1); proposed patch passes production (0) and catches call/inline controls (1/3). |
| F | `Rscript S/patch-probe.R`: namespace-local N1/O1 patches pass the registered applied-row, scalar/empty, aggregate and F1 controls (61 assertions), and X's ledger returns the base values. No production file edited. |

No timing windows, memory workloads, real-data workloads or full suite were run. Git required escalation past the sandbox ownership check; no Git configuration was changed. After each pkgload-using run, restored `R/cpp11.R` and `src/cpp11.cpp` with `git -C ROOT checkout -- R/cpp11.R src/cpp11.cpp`. Selected guts do not rewrite the base records; their tracked diff remains empty.

| Finding | Resolved in substance? | Evidence / command |
| --- | --- | --- |
| F1 | Yes | Replay truncates before malformed disposition and executes earlier rows first; kernel chooses earliest failed row with within-row precedence. P reproduces both multi-error pairs, separate-block variants, reversals and exhaustion-before-witness on base and candidate. T/C/M pass. |
| F2 | Yes | Independent scalar type/length/finite checks; all three empty operations preserve the book and eight double empty columns. T executes each malformed scalar and the combined length-2/length-0 control. |
| F3 | Partial; N1 required | Aggregate judgement below accepts the stated residual. T/P prove exact opening checks, corruption refusals, valid historical drift and balanced split refusal. X finds a new false refusal in the split check; F verifies N1. |
| F4 | Partial; N2 required | T executes literal-index/match/new-boundary D3 controls, planned-position/arithmetic D11 controls, inline/aggregate-scan D25 controls, and production-store/config D12a controls. M's actual cumsum mutation fails C3. D finds callback coverage lost from D25. |
| F5 | Yes | Native serialized captures are checked alongside unchanged projected fingerprints. C passes C14a/b; M catches both quantity mutation and projection-invisible names mutation with the required native-witness message. |
| F6 | Yes at boundary-function level | G/T: Section 1.6 names opening/replay imports, replay result, settlement including disposition mapping, result/recovery and walk-forward boundaries. No additional boundary function or per-fill ID lookup found; qualification below on the detector's lexical reach. |
| F7 | Yes for the reported pointer | Historical README evidence is pinned to record `bee6c028` and product `df1b3b62`; full-suite claims now name that product. G verifies these revisions and unchanged historical records. O2 would additionally pin the correction harness. |

**F3 arithmetic judgement.** The implementer's position is sound and the remaining aggregate gap is acceptable inside the accepted design. P produces cached net `0.10000002384185791` and live quantity `0.10000000000000001` on both implementations after buys of `1e9`, `0.1` and a sale of `1e9`, all at price 1. The former `sqrt(eps)` check rejects it. Incremental subtraction retains error from consumed lots; their magnitudes and update count are absent from the book. Current live size/depth therefore cannot supply a useful general historical-error bound. Cost basis has the same history dependence, including multiplication, ordered changes and dust snapping.

Synthesis Section 4 explicitly binds cached aggregates to canonical updates, **not reduction recomputation**. Exact FIFO reductions at known opening construction and exact flat net elsewhere are sound. Residual: fold-state, fold-entry and compiled-unpack validation accept arbitrary finite non-flat cached-net/basis corruption, including `1e9 -> 1e9 + 1`; they cannot distinguish provenance from the current book alone. The default reduction validator and opening constructor reject that corruption. V-applied-row checks splits, not the entire aggregate history. A stronger historical certificate would require additional provenance/error state or replay; that is not necessary to preserve the accepted arithmetic and is not silently added here. N1 concerns a separate new split predicate, not this accepted residual.

**N1 - blocking: the split check assumes all live lots share a sign.** `R/lot-accounting.R:377` and `:656`. X replays signed openings `+2 @ 10`, `-1 @ 10`, then `SELL 2 @ 10`. Base returns net `-1`, close `2`, open `0`; candidate raises `ledgr_lot_state_invariant: Invalid applied lot rows.` The remaining head already has the sell sign; no lot was appended. Signed openings and successive opening rows are accepted by synthesis 3.4, the preparer and V-book. The public carried-opening positivity guard does not constrain this accepted replay input. Rejecting it changes existing accounting semantics.

Exact product patch: capture tail after compaction/growth and before append, then witness the actual increment. This adds call-local validation evidence, not a carrier field. Update the comment at `:341` to say a positive opening part requires an append and a final head on the operation's side.

```diff
-      (open_qty[cons] > 0) == (lots$after[cons] == input$side[cons])
+      (open_qty[cons] > 0) == lots$appended[cons] &
+      (open_qty[cons] == 0 | lots$after[cons] == input$side[cons])
@@
-  a <- which(appending)
+  tail_before_append <- tail
+  a <- which(appending)
@@
-      lots = list(steps = steps, before = before, after = head_sign(head, tail, off))
+      lots = list(steps = steps, before = before, after = head_sign(head, tail, off),
+        appended = tail > tail_before_append)
```

Add this control inside the existing `[WS4a V-applied-row]` test, retaining every existing split control; its reason is preserving the base's accepted signed-opening semantics:

```r
b <- ns$ledgr_lot_book_from_opening("S", lots = list(
  instrument_id = c("S", "S"), qty = c(2, -1), price = c(10, 10)))
out <- ns$ledgr_lot_fill(b, 1L, -1L, 2, 10)
testthat::expect_identical(out$book$net_by_inst, -1)
testthat::expect_identical(c(out$applied$close_qty, out$applied$open_qty), c(2, 0))
```

**N2 - blocking: D25 drops previously enforced callback-loop coverage.** `tests/testthat/test-ws4a-carrier.R:640-641`. The replacement scans only `for`, `while`, `repeat`; the prior `ws4a_loop_bodies` also examined `lapply`, `vapply`, `sapply`, `Map`, `mapply`. D injects `lapply(seq_along(pos), function(k) ledgr_lot_fill(book, pos[k], 1L, quantity[k], 1))` into the production kernel: new predicate passes, old predicate fails. This is a weakened oracle for forbidden per-instrument dispatch, despite the required explicit-loop controls passing.

Exact patch inside D25: add the following helper beside `check`; change `check`'s existing return from `unlist(lapply(...))` to `c(callback_check(e), unlist(lapply(...)))`, leaving its explicit-loop checks unchanged. D verifies this composition.

```r
callback_check <- function(e) {
  callbacks <- Filter(function(x) ws4a_head(x) %in%
    c("lapply", "vapply", "sapply", "Map", "mapply"), ws4a_calls(e))
  unlist(lapply(callbacks, function(x)
    unlist(lapply(ws4a_loop_bodies(x), lot_work))))
}
```

Add both controls beside the existing inline control, retaining all earlier controls:

```r
for (stmt in c(
  "lapply(seq_along(pos), function(k) ledgr_lot_fill(book, pos[k], 1L, quantity[k], 1))",
  "lapply(seq_along(pos), function(k) book$lot_qty[book$offset[pos[k]] + 1L] <- quantity[k])"
)) testthat::expect_gt(length(ws4a_hits(
  list(kernel = ws4a_inject(fns$ledgr_lot_apply, stmt)), check)), 0L)
```

**O1 - optional: avoid failure-selection work on ordinary successful calls.** `R/lot-accounting.R:487-507`. The reported 115.5/108.0 us ratio is about 1.069; I did not rerun or promote it to a timing gate. Some overhead is avoidable without removing F1 or F3 checks. Exact changes, verified together with N1 in F:

1. Replace `fail <- integer(m)` with `bad_through <- integer()`; replace `fail[through[is.na(front) | front != side[through]]] <- 1L` with `bad_through <- through[is.na(front) | front != side[through]]`.
2. Replace `d <- which(op == .ledgr_lot_disposition & fail == 0L)` with `d <- which(op == .ledgr_lot_disposition)`.
3. Wrap the existing disposition checks and earliest-failure dispatch, ending immediately before `appending <- opening | open_qty > 0`, in `if (length(bad_through) > 0L || length(d) > 0L) { ... }`. At its start insert `fail <- integer(m); fail[bad_through] <- 1L; d <- d[fail[d] == 0L]`.

This skips the failure-code allocation and failure scan when no through failure or disposition exists. It preserves vectorized predicates, scalar precedence, all head/split observations and checks. No speedup magnitude is claimed. Further removal of the split witness would weaken F3.

**Census, records and scope.** Section 1.6 correctly enumerates the boundary functions; the handler's fee-name access is distinguished from instrument lookup. Compiled, reader and P4 book operations are positional. D3's literal/match controls pass, but its spelling heuristic is not a general character-index proof: for example recovery's `positions[present]` and `positions[held]` are inside the listed recovery boundary yet absent from its lexical hit list. This is a qualification of the claim that *any* other lookup is detected, not an unlisted boundary or a new product lookup.

Keeping `records/mutations.csv` mapped to the base M11 gut is correct historical record handling. It describes the LDG-3163 run, not today's registry. `guts.R` now maps M11 to `M11_cumsum_total_basis`; M verifies C3 failure. The old uncompensated gut remains independently useful. Rewriting the historical CSV to claim a cumsum run would falsify that evidence. README accurately explains the distinction and confines old timing/memory/full-suite results to `df1b3b62`.

**O2 - optional immutable correction-harness pointer.** `dev/bench/v0_2_3_ws4a/records/ldg3164/README.md:67-68`: replace "the harness, design note and evidence follow in the next commit" with "the harness, design note and evidence are in b7bffc0a". In `inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:1254`, replace "product commit 03aed8b7 (" with "product commit 03aed8b7; harness/evidence commit b7bffc0a (". Product identity is already immutable; these edits remove ambiguity about which harness exercised it. Dense/A0 and heavyweight results remain implementer/maintainer evidence, not independent reruns here.

Seven-shapes review of the correction diff found no new frames/subsetting/parsing/JSON loops, pairwise validators or environment-held scalar writes. The new opening-validation loop traverses FIFO depth across instruments to repeat the required ordered arithmetic exactly; that is a stated, justified sequential dependency. The added step counter lives in the existing depth loop; scalar total/Kahan and replay block loops remain the accepted ones. O1 identifies avoidable success-path work (shape 5). N2 weakens a detector but does not establish a current production dispatch loop. No second engine, mode branch, frozen-oracle edit or identity change was introduced. The single typed kernel remains an appropriate seam; these two corrections fit its accepted design.
