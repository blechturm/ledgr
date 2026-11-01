# Workstream 13 close review: focused re-review 1

- Reviewer: Codex, independent clean-context reviewer; author of neither the product nor the close review.
- Date: 2026-10-31.
- Mode: Type 1, maintainer-owned brief, v0.2.3 cut 5 / macro WS4a part 2, after correction round 1. No Type 2 decision reopened.
- Reviewed commit: `0cdbd244d7ad652bd47ebd89693beca74535b75c`, branch `claude/ws4a-carrier`; correction range `5210607f..HEAD`.
- Verdict: **PASS_AFTER_PATCHES**. Apply N2 and N3 below, including N2's regression. These exact patches suffice without another review. N1 is optional internal-validator tightening; the requested narrower predicate is supplied.

Authority: cut 5 and both clarified amendments; close-review F1-F4/O1; typed-fold-carrier synthesis Sections 3-5; design-note obligations; `contracts.md#contract-execution-fold-carrier`, `#contract-execution-event-staging`, `#contract-execution-fills-and-lots`, `#contract-execution-compiled-accounting`; the optimization manual's seven shapes. The amendments settle the public overflow outcomes. The remaining blocking implementation issue is a canonical refusal discarded by the new compiled wrapper, not a challenge to those decisions.

**Commands and evidence**

`ROOT` = `C:/Users/maxth/ledgr-wt/ws4a-impl`; `S` = `C:/Users/maxth/AppData/Local/Temp/ws13-rereview1`; `B` = `ROOT/dev/bench/v0_2_3_ws4a`; `R3` = `B/records/ldg3169/round3`. Command abbreviations below were expanded to absolute paths. R 4.6.1; all R jobs serial. Git identity checks used the owner account after the sandbox account's ownership refusal; no Git configuration changed.

| Key | Command run and result |
| --- | --- |
| G | `git -C ROOT diff 5210607f HEAD`, focused diffs/source reads, `rev-parse HEAD`, and status checks. Three product R files changed; no C++ change; only `test-ws4a-carrier.R` changed among tests. |
| C | `Rscript B/check.R --base=HEAD --out=S/check`: exit 0, **23 cases identical**, including C9's compiled fractional fills and carried compensation. This compares frozen case outputs, not HEAD against an independently installed base. |
| T | `Rscript -e "testthat::test_local('ROOT', filter='^ws4a-carrier$', reporter='summary', stop_on_failure=TRUE)"`: exit 0; all assertions pass, 14 expected final-bar warnings. |
| P | `Rscript R3/public.R base S`, then `Rscript R3/public.R candidate S`: exit 0 each; all eight rows of the recorded public-outcome table reproduced. Base library: `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`. Captures: `S/public-base.txt`, `S/public-candidate.txt`. |
| Q | `Rscript S/probe.R`: exit 0. Six ordinary wrapper results have identical serialized bytes to the wrapper at `5210607f`; six overflow/native-input precedence combinations; three refused P4 batches leave cash, positions, book and event sequence byte-identical and append zero batches. Also reproduces N2, the cash-domain gap and each detector's exact control. Capture: `S/probe.txt`. |
| E | `Rscript S/base-boundary.R`: the installed base's actual `ledgr_next_open_fill_proposal(0)` passed to `ledgr_fill_event_payload('review', ..., event_seq=0L)` returns `NO_OP`, `next_event_seq=0L`. |
| V | `Rscript S/trace-public.R base`, then `candidate`: exit 0 each. Abort traces locate hold-at-10 at P5 on both paths; sale-at-1.9 at fill metadata on runs and P5 on sweeps; sale-at-10 moves from those base sites to the canonical fill refusal. Captures: `S/trace-base.txt`, `S/trace-candidate.txt`. |
| K | `Rscript S/patch-check.R`: exit 0. Function-copy patches for N1/N2 pass their new domain/refusal controls and both existing valuation/compiled-overflow test blocks (12 successes each). No patched product installed. |
| R | After every pkgload-using job: `git -C ROOT checkout -- R/cpp11.R src/cpp11.cpp`. |

No timing, memory, real-data, coverage, full-suite or package-check run. The broad round3 gates remain implementer evidence. Only synthetic fixtures were examined; no Sharadar rows or identifiers were printed.

**Disposition of every close-review item**

| Item | Resolved? | Evidence and command |
| --- | --- | --- |
| F1 | **Yes for the amended behavior; optional N1.** | P/V/T: `positions_value` accepts Inf, -Inf and arithmetic NaN, refuses ordinary NA, and retains finite primitive checks. Availability holds at 10/1.9 and sale at 1.9 retain `ledgr_config_non_finite`; dense hold at 1.9 completes with Inf equity. Sale of the 1e308 long, basis 1, at 10 refuses as `ledgr_invalid_lot_fill` on both run and sweep, exactly as clarified. |
| F2 | **Not fully; N2 required.** | P/T/Q: both public compiled overflows refuse correctly; ordinary bytes and native-input precedence hold. Detected refusals occur before installation/publication. The new wrapper can nevertheless discard an earlier non-overflow canonical refusal and return a later overflowing batch. |
| F3 | **Yes.** | T: construction validates diagnostic rows; NA reason, NA decision time and negative mark age append no row; typed empty passes and the unvalidated-builder control fails. E/Q establish that empty sequence-zero refusal is new internal validation, not base behavior; authority is explained below. |
| F4 | **Yes.** | T/Q: D9 independently reports one hit for the exact `lapply(... list(qty=..., fee=...))` control; D10 independently reports one for `sink$equity <- list(n=0L, ts=numeric(1024L), cash=numeric(1024L))`. Both report zero on their production regions. Registered renamed-storage, additional-owner and passing controls pass. |
| O1 | **Yes.** | G: design D20 and disposition now distinguish signatures/call shapes plus twelve witnesses from operation-level equality. No stronger independent D20 claim is made here. |

**Residual questions**

The P3 cash domain is finite doubles, ordinary NA for dense, and positive infinity. Starting from finite cash, an accepted cash-generating effect can produce +Inf. A negative effect is accepted only if the resulting cash meets the affordability floor. -Inf cannot satisfy that check; arithmetic NaN cannot become returned `virtual_cash` through its conditional. Thus `any` is broader than necessary. The precise predicate, after scalar-double validation, is `!is.nan(v) && (is.na(v) || is.finite(v) || v == Inf)`. No existing token expresses exactly this domain. `na` already admitted NaN before this correction; newly admitting -Inf is an unnecessary expansion, but neither value is a newly observed public outcome. N1 tightens it without changing economic behavior.

The compiled non-finite-fee residual is **accepted as pre-existing**: native input validation still raises `simpleError`, "`fill_fee` must be finite >= 0." The unchanged C++ validates the fee before that row's arithmetic. Q/T verify an earlier overflow wins over a later native fee refusal, while an earlier or same-row native refusal keeps its original condition. The amendments do not require converting every native input error to the overflow condition. The checkpoint prose must distinguish canonical fee refusals (N3).

The opposing-lot residual is **not acceptable**. Q's book passes `ledgr_lot_book_problem(..., reduction=FALSE)` yet contains a zero live head lot. Canonical row 1 refuses opening through that head; row 2 buys 1e308 at 10. The wrapper returns successfully with cash -Inf and the second basis snapped to zero. This is an internal valid-predicate counterexample, not a claim that ordinary public openings create zero lots. Once the suspicion path observes a canonical refusal, discarding it violates the normative-oracle/fail-closed rule. Preserve that earlier condition; do not relabel it as an overflow or claim the later fill was safely checked. N2 fixes the new fallback without changing native code or adding a normal per-fill R loop.

The empty-payload sequence-zero refusal is **not the base behavior** (E). It is authorized internal construction validation: synthesis Section 3.1, close-review F3, design F4.02 and `contracts.md#contract-execution-fold-carrier` require valid sequence state and construction checks. The fold initializes at 1 and rejects state below 1 (`R/fold-phase-contract.R:30,111`); this probe supplies invalid internal state directly. Applying the existing argument check before constructing the empty block needs no new public-refusal amendment. Nonempty fill validation still precedes the sequence check; ordinary numeric sequences normalize to integer.

**N1 — optional: narrow the expected-cash validator.** `R/fold-carrier.R:111,343`. Exact patch: retain `double:scalar:any`, and insert this at the start of the `plan = {` branch. K verifies permitted and refused values.

```r
      if (is.nan(x$expected_final_cash) || identical(x$expected_final_cash, -Inf)) {
        return("`expected_final_cash` must be finite, NA or positive infinity")
      }
```

Add this independent control in `tests/testthat/test-ws4a-carrier.R` (new test, no existing oracle changed):

```r
testthat::test_that("[WS4a expected cash domain] only finite, NA and positive infinity pass", {
  p <- ws4a_3166_plan()
  for (v in list(NA_real_, Inf, -1, 0, 1, NaN, -Inf)) {
    p$expected_final_cash <- v
    testthat::expect_identical(ws4a_refuses_plan(p), is.nan(v) || identical(v, -Inf))
  }
})
```

**N2 — blocking: propagate the earliest canonical refusal on suspicion.** `R/compiled-spot-fifo.R:220,239,241`. Q reproduces silent acceptance; K verifies the refusal patch and existing public/precedence controls. Exact code patch:

```diff
-    overflow <- if (!is.null(oracle$failed) && inherits(oracle$error, "ledgr_invalid_lot_fill")) {
+    failure <- if (!is.null(oracle$failed)) {
       oracle$failed
     } else {
       n + 1L
     }
@@
-      if (failed <= overflow) stop(error)
+      if (failed <= failure) stop(error)
@@
-    if (overflow <= n) {
-      rlang::abort(
-        "Invalid fill input for lot accounting.",
-        class = "ledgr_invalid_lot_fill"
-      )
-    }
+    if (failure <= n) stop(oracle$error)
```

Replace the comment at `R/compiled-spot-fifo.R:212` through the sentence "Nothing is installed or published for a refused batch." with: "On suspicion, retain the canonical operation's earliest refusal and its condition. A native input refusal wins when its row is earlier or the same. If canonical evaluation succeeds, retain the native outcome. Nothing is installed or published for a refused batch."

Append this inside the existing compiled-overflow test, after its four wrapper assertions at `tests/testthat/test-ws4a-carrier.R:3006`; its local `state` and `fills()` are reused. The fixture is a new control, not a replacement of a registered one:

```r
  z <- ns$ledgr_lot_book(2L)
  z$capacity <- c(1L, 0L); z$offset <- c(0L, 1L); z$tail <- c(1L, 0L)
  z$lot_qty <- 0; z$lot_price <- 1
  testthat::expect_null(ns$ledgr_lot_book_problem(z, reduction = FALSE))
  state$lot_state <- z
  testthat::expect_error(
    ns$ledgr_run_compiled_spot_fifo_batch("w", fills(c(1, 1e308), c(0, 0)), state, c("A", "B"), 1L),
    "Lot accounting cannot open through an unconsumed opposing lot.",
    fixed = TRUE, class = "ledgr_lot_state_invariant"
  )
```

**N3 — blocking documentation reconciliation, exact replacements.** `contracts.md:729` and `ws12_disposition.md:122` currently say the wrapper asks only for the earliest *overflowing* fill. After N2, replace that phrase with "earliest failing fill, preserving any earlier canonical transition refusal and its condition" in both places. This explains why the opposing-lot case refuses without broadening the overflow amendment.

At `ws12_disposition.md:143`, replace "Public refusals keep the base class, message and order:" with "The canonical R refusals checked by that checkpoint keep the base class, message and order:". This removes the false implication that the compiled non-finite-fee input already has the canonical class. At `ws12_disposition.md:172`, replace "the sale's realized P&L overflows; the maintainer's decision names `ledgr_config_non_finite` for it, so this reading is flagged for confirmation." with "the sale's realized P&L overflows, as the maintainer explicitly clarified in `amendment_valuation` after correction round 1." Leave round3's historical flag intact; it predates that clarification, and its outcome table is correct.

With N2/N3, NEWS's overflow and valuation claims match the implementation within the existing compiled envelope (memory sweeps only; durable compiled dispatch remains unsupported). As reviewed, the blanket compiled-refusal claim is incomplete because of N2, and the disposition's confirmation flag is stale. The contract's construction claim is now supported by F3. No snapshot, configuration, store or public API identity change was found.

**Correction scope and seven shapes.** The product delta is the field table, two construction boundaries, one vectorized suspicion helper and the native wrapper. No new per-row frames/binds, repeated ID subsets, scalar parsing, JSON work, pairwise validators or scalar environment-vector writes were introduced (shapes 1-4, 6-7). Shape 5: the bound adds a vector pass over already packed lots/fills; canonical recomputation and native prefix bisection occur only on suspicion/refusal. The new growing `while` is justified by earliest-row error precedence, not ordinary execution. Test-detector AST walks concern source syntax, not execution-scale collections. No unjustified growing product loop or second execution engine found.

G confirms existing registered fixtures and numerical/refusal oracles were not rewritten; tests were added and detectors strengthened. T's construction bypass and suspicion-off controls still fail for their intended reasons. The domain overbreadth in N1 and discarded refusal in N2 are the remaining implementation qualifications; no other correction-induced defect was found in the inspected scope.

Review accounting: close-review chain now two independent reviews and one correction round; checkpoint reviews remain a separate chain. This invocation writes only this report, makes no commit, and restores generated bindings. Required patches are review instructions, not applied product changes.
