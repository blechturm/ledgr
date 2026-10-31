# Workstream 13 checkpoint: re-review 1

- Reviewer: Codex, independent clean-context reviewer; neither implementation nor checkpoint-review author.
- Date: 2026-10-31.
- Mode: focused Type 1 against cut 5 and checkpoint F1-F5/O1, after correction round 1; LDG-3165/3166.
- Reviewed commit: `92f03745a8a0e0748fd6b855add86d7cec540b1f`, branch `claude/ws4a-carrier`; correction diff `7a4f7b01..92f03745`, product `51be2bbf`.
- Verdict: **CHANGES_REQUIRED**. F2-F5 and O1 are resolved; F1 still changes two reachable public refusals. N1 below blocks acceptance. No NEEDS_TYPE_2 issue identified.

Authority: cut 5 decisions and three amendments; typed-fold-carrier synthesis Sections 3.1-3.3/4; `ws4a_carrier_design.md` Sections 1.8/3/5/6/8; `contracts.md#contract-execution-fold-core`, `#contract-execution-accounting-events`, `#contract-execution-cost-model`, `#contract-execution-compiled-accounting`, `#contract-availability-affordability`. No timing/memory gate, tooling-budget decision, F4.01 amendment or WS12 cached-net residual was reopened.

**Execution record**

`ROOT` = `C:/Users/maxth/ledgr-wt/ws4a-impl`; `S` = `C:/Users/maxth/AppData/Local/Temp/ws13-rereview1`. Commands used absolute paths, plain Rscript and serial R jobs. Base library: `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`. Windows/R 4.6.1 environment; no performance claim.

| Key | Command and observed result |
| --- | --- |
| G | `git -C ROOT diff 7a4f7b01 92f03745`, `rev-parse HEAD`, source/authority reads and `rg -n`; initial worktree clean. |
| C | `Rscript ROOT/dev/bench/v0_2_3_ws4a/check.R --base=HEAD --out=S/cases`: exit 0, all 23 frozen cases identical. |
| T | `Rscript S/tests.R`: `testthat::test_local(ROOT, filter="^(ws4a-carrier\|fill-model\|documentation-contracts\|cost-model\|ledger-writer\|cross-asset-corrections\|availability-economics)$", reporter="summary", stop_on_failure=TRUE)`: exit 0; 14 expected final-bar warnings. |
| P | `Rscript S/probe.R base`, then `Rscript S/probe.R candidate`, then `Rscript S/compare.R`: independent three-row grid, 615 planner scenarios and eight public scenarios; 603/603 ordering/warning cases match, four additional dense arithmetic planner cases differ, and two public cases differ (N1). Captures compare complete condition-class vectors, messages and warning messages. |
| D | `Rscript S/docs.R`: roxygen2 8.1.0 generates the condition reference in a minimal scratch package; the complete Fill seam section is identical to tracked Rd. Unrelated unresolved links are expected in that isolated package. |
| X | `Rscript S/probe.R patched`, then `Rscript S/verify.R`: N1's validator edits applied only to namespace function copies; all 615 planner condition/warning results and all eight public results match base. Also 32 single-field and two paired validator controls pass. |
| R | `Rscript S/regression-run.R candidate`, then `Rscript S/regression-run.R patched`: extracts the exact additive regression block printed below; candidate fails its two public refusal assertions, scratch-patched validator passes all five assertions. No repository code changed. |
| E | `Rscript S/verify.R` also verifies that the recorded 21-scenario outputs are identical and the correction A0 CSV has 295 PASS rows. Read `correction1/sequence.log` and its parent README. |

No timing, memory workload, real-data workload or full suite was run. No separate guts run was needed: T executes every newly added violating control, including the production handoff mutations. The full-suite/dense/A0/guts gate outcomes in the tickets remain attributed to the implementer's records, not independent reruns here. P's initial adapter permutation was corrected against the installed base function bodies before both final runs; an initial X scope-script parse error was corrected and rerun. Git required owner-account execution after sandbox ownership rejection; no Git configuration changed. After every pkgload-using job, including the failed scope script, ran `git -C ROOT checkout -- R/cpp11.R src/cpp11.cpp`. No tracked record was rewritten.

**Disposition of checkpoint findings**

| Finding | Resolved? | Evidence and executed command |
| --- | --- | --- |
| F1 | **No, partial** | G/P/T: restored Inf-delta and `next_bar$open` witnesses pass; selector order and the recorded fee overflow are correct. NaN-producing cost arithmetic still refuses in P3 instead of accounting: N1. Commands P and T. |
| F2 | Yes | `R/compiled-spot-fifo.R:191` installs carried cash/position effects and ordered cash; native lot positions and C++ remain unchanged. T's `[WS4a D8 handoff]` passes four production paths; native cash-effect substitution fails exactly the compiled path. C covers ordinary multi-fill/reversal and compiled cases. Commands C/T. |
| F3 | Yes | `R/fold-carrier.R:263,281`: late missing price/epoch, impossible final-pulse present price/epoch, and every empty-plan economic kind are refused. Valid early/final rejections remain accepted. Each new constructor control in `[WS4a V-execution-view V-plan V-fill V-rejection U-3166]` executes successfully. Commands T/P. |
| F4 | Yes | `test-ws4a-carrier.R:1716,1821,1998`: D1 includes P3 and its callback mutation fails; D8 catches all four added inline arithmetic mutations. Runtime carried-cash perturbation crosses durable, db_live, canonical-memory and compiled publication; recomputation and native substitution break its predicate. Commands T/C. |
| F5 | Yes | `test-fill-model.R:173,234`: original BUY 10 at 100/101/99/100.5/100000 and SELL 5 at 101/102/99/100.5/100000 restored at surviving typed/frozen boundaries. Both crossed mappings and all ten corrupt-field controls fail their predicates. Earlier additional tests remain. Command T. |
| O1 | Yes | `R/condition-reference.R:23`, `man/ledgr_condition_classes.Rd:430`, design-note census: batch-seam wording and freeze-transition boundary are precise. Hand editing produced exactly the paragraph roxygen generates; documentation-contract tests pass. Commands D/T. |

**Four implementer choices**

1. **Inf fee:** P independently confirms the stated finite-input witness: target 2, price 10, fixed fee 1e308 plus notional fee 1e308 bps. Base and candidate dense runs raise `ledgr_invalid_lot_fill: Invalid fill input for lot accounting.` Availability completes with zero fills and `insufficient_cash` (plus the ordinary final-opportunity rejection). Section 4 says fill values are valid resolved values, unlike the explicitly finite state; Sections 3.1/3.3 preserve current refusals. Carrying arithmetic overflow until its original consumer refuses is consistent with that preservation rule; it does not authorize publishing a successful invalid fill.
   The new exception is field-bounded: only fee +Inf and cash +/-Inf pass; negative-infinite fee, all other infinite fill fields, NA and NaN fail (E's 32 controls). Those Inf categories can arise from base arithmetic; no blanket group exemption was introduced. But it is **not an exact characterization of base's intermediate arithmetic domain**: base also carries NaN fee/cash in N1. Thus the specific Inf fix is sound, the complete overflow-preservation claim is not.
2. **Refusal selector:** P independently enumerates two faulty rows plus an ordinary row inserted before/between/after, two context-to-run mappings, and whole/subsecond epochs: 600 cases across both producers. Faults include delta overflow, NaN/zero/missing open, short exposure, and combined faults. Three additional final-pulse cases move the overflowing delta through each row. All match base classes/messages/warnings: first failing decision row, then delta/open/epoch on dense; delta/epoch/short after the availability missing-bar gate; final dense warnings only for preceding valid rows. The shared selector's fixed-check loop is justified. These checks do not claim equivalence for arbitrary injected custom resolver errors, whose batch seam was already accepted.
3. **Availability public delta overflow:** true for supported finite public state/targets. The recorded negative-opening attempt alone was insufficient proof. P additionally starts with +1e308 units valued at 0.5 and requests -1e308: both versions refuse short exposure before P3; dense reaches the delta refusal. `ledgr_opening_normalize_positions()` rejects negative openings; availability validates finite targets and prevents opening/enlarging shorts before planning. Reachable nonnegative finite positions and targets cannot overflow their subtraction. An injected negative internal state is a planner test, not a supported public counterexample; this does not reopen F4.01.
4. **Hand-edited Rd:** D proves exact generated-section equality, including wrapping and code markup. T proves the documentation contracts pass. Regenerating that paragraph would make no change.

**N1 — blocking: F1 still refuses arithmetic NaN at the wrong boundary**

Locations: `R/fold-carrier.R:89,161,235`; `tests/testthat/test-ws4a-carrier.R:2140`; `tickets.yml:1343` (all packet-relative ticket references mean `inst/design/ledgr_v0_2_3_spec_packet/tickets.yml`). This is an incomplete repair of the existing F1 defect, not a new design choice.

P uses fresh synthetic public snapshots, initial cash 1000, no opening position, and entirely finite inputs. Dense target -1e308 at price 10 with fixed/notional fees 1e308 creates `fee=Inf`, `cash_delta=Inf-Inf=NaN`; target +1e308 with `ledgr_cost_notional_bps_fee(0)` creates `fee=Inf*0=NaN`. Base raises the accounting class/message above for both. Candidate raises `ledgr_invalid_pulse_plan` with respectively ``fill: `cash_delta` contains a missing value`` and ``fill: `fee` contains a missing value``. Neither result is an accepted semantic/fault-boundary change. The 21 recorded scenarios and new registered tests omit both cases.

Exact proposed product patch (X executes these predicates in memory). Keep NA refused, allow arithmetic NaN only in the two already exceptional columns, and retain the original lot-input refusal. Do not raise the accounting class prematurely in P3 or replace NaN with zero:

```diff
--- a/R/fold-carrier.R
+++ b/R/fold-carrier.R
@@
-# (doubles must otherwise be finite), `inf` refuses NA but admits an infinite
-# double (a fee that overflowed, refused at accounting as in the base) and
+# (doubles must otherwise be finite), `inf` admits Inf and arithmetic NaN
+# only in resolved fee/cash columns, but refuses ordinary NA; accounting
+# retains the base refusal for non-finite fees, and
@@
-    if (parts[[k]][[3L]] %in% c("none", "inf") && anyNA(v)) {
+    if ((identical(parts[[k]][[3L]], "none") && anyNA(v)) ||
+        (identical(parts[[k]][[3L]], "inf") && any(is.na(v) & !is.nan(v)))) {
@@
-      if (any(x$qty <= 0) || any(x$price <= 0) || any(x$fee < 0)) {
+      if (any(x$qty <= 0) || any(x$price <= 0) || any(x$fee < 0, na.rm = TRUE)) {
@@
-      if (!identical(x$position_delta, x$side * x$qty)) {
+      if (any(is.nan(x$cash_delta) & is.finite(x$fee))) {
+        return("an undefined cash effect requires a non-finite fee")
+      }
+      if (!identical(x$position_delta, x$side * x$qty)) {
```

Exact additive regression block for `test-ws4a-carrier.R` (existing fixtures retained):

```r
testthat::test_that("[WS4a F1 arithmetic NaN] dense costs retain accounting refusals", {
  fx <- ws4a_3166_fixture(FALSE)
  on.exit(ledgr_snapshot_close(fx$snap))
  cases <- list(
    list(target = -1e308, cost = ledgr_cost_chain(ledgr_cost_fixed_fee(1e308), ledgr_cost_notional_bps_fee(1e308))),
    list(target = 1e308, cost = ledgr_cost_notional_bps_fee(0)))
  for (i in seq_along(cases)) {
    exp <- ledgr_experiment(fx$snap, function(ctx, params) {
      t <- ctx$hold(); t[["AAA"]] <- params$target; t
    }, cost_model = cases[[i]]$cost, opening = ledgr_opening(cash = 1000))
    testthat::expect_error(ledgr_run(exp, params = list(target = cases[[i]]$target),
      run_id = paste0("ws4a-nan-", i), seed = 1L),
      "^Invalid fill input for lot accounting[.]$", class = "ledgr_invalid_lot_fill")
  }
  for (field in c("fee", "cash_delta")) {
    p <- ws4a_3166_plan(); p$fill[[field]][1L] <- NA_real_
    testthat::expect_true(ws4a_refuses_plan(p))
  }
  p <- ws4a_3166_plan(); p$fill$fee[1L] <- 0; p$fill$cash_delta[1L] <- NaN
  testthat::expect_true(ws4a_refuses_plan(p))
})
```

Exact evidence correction at `tickets.yml:1343`: replace `Product 51be2bbf repairs F1-F5 and applies O1` with `Product 51be2bbf resolves F2-F5 and applies O1; F1 remains incomplete for arithmetic NaN (ws13_checkpoint_rereview_1.md N1)`. Preserve the historical recorded gate outcomes. After implementation, add the new product/verification identity separately. X/R support this localized repair, including the exact proposed regression block; they do not establish that the tracked product is repaired or that the remaining registered controls pass after implementation.

**N2 — optional: loop census sentence omits the new fixed-check loop**

Location: `tickets.yml:1335`, contradicted by `R/fold-engine.R:206`. The detector correctly allows it; only the evidence sentence is inaccurate. Exact replacement: `the only loops are the affordability scan, the cost-step loop and the per-target final-bar warning` → `the allowed loops are the affordability scan, the cost-step loop, the per-target final-bar warning and the refusal selector's fixed-check loop`. No product change needed.

**Correction safety and evidence truth**

No newly introduced production defect, weakened oracle or unjustified growing-collection loop found. N1 is a remaining earlier refusal defect. Seven-shapes review of the correction: no per-row frames/lists, per-ID table scan, per-element parsing, new repetitive JSON, quadratic validator or environment-held scalar buffer writes. The selector iterates fixed checks; dense warning iteration retains observable warning order; the compiled wrapper's existing scalar cash scan preserves dependent addition order. Its native arithmetic remains frozen as required, while publication reads the carried columns. Test/harness iteration is not a new production hot path. F5 restores rather than substitutes the registered economic witnesses.

The input challenge is that ordinary output identity plus a few overflow examples cannot establish refusal preservation: finite public operands can yield either Inf or NaN. The independent arithmetic controls expose this without changing the accepted architecture, adding a mode branch or reopening a maintainer decision.

Stable evidence pointers resolve: immutable product `51be2bbf`, evidence `92f03745`, the named test blocks, and the directory `dev/bench/v0_2_3_ws4a/records/ldg3166/`: `README.md`, `correction1/sequence.log`, `correction1/a0-compare.csv`, `correction1/probe_f1.R`, `correction1/f1-probe-base.txt` and `correction1/f1-probe-candidate.txt`. The 21-scenario equality and 295 PASS rows are true; 126 added probe lines explain 2,022 → 2,148. C/T independently support the permitted correctness subset. Historical numeric test-line pointers are qualified by the design-note migration rows and product identities. The corrected F2/F3/F4/F5 evidence is substantiated within its stated fixtures; the blanket F1 closure at line 1343 is false (N1), and the loop sentence needs N2. No ticket or product file was edited; only this report was added, with no commit.
