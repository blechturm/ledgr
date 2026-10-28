Verdict: PASS

Role: record; independent clean-context review of WS1 Phase A.
Status: final review, 2026-10-28.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Reviewed branch `claude/ws1-output-handler`, range `07dbbc87..143a4e9e`, including correction commits `656ee7a5` and `143a4e9e`. Paths below are repository-relative.

Phase A is a correct and sufficient basis for the base measurement and the subsequent implementation design. There are no required findings. This is not completion of LDG-3127 or LDG-3128: both correctly remain in progress, and LDG-3129 must wait for their completion. The unrun baseline is deliberately outstanding evidence, not a failed measurement. No timing runner or smoke run was executed in this review.

## Verification of the previous required findings

| Finding in ws1_phase_a_review.md | Result and evidence |
| --- | --- |
| F1: R3 sentence incorrectly covers compiled batches | Resolved. `inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md:247` limits the publication-helper requirement to resolved fill intents on canonical R, then explicitly publishes compiled typed deltas and leg fees unchanged. This matches `R/fold-engine.R:1336` and `R/sweep.R:2188`. It preserves the economic-resolution prohibition in `contracts.md#contract-execution-accounting-events`, using the clarification explicitly permitted by LDG-3128/3129. |
| F2: activation findings hidden by filtering to ticket evidence | Resolved by an actual current-packet classification, not a filter or fallback. `inst/design/ledgr_v0_2_3_spec_packet/horizon_open_classification.md:5` identifies the source population, preserves prior evidence and records current receivers. Focused scans reproduce 6 unclassified entries on base inputs with v0.2.2, 79 on those inputs with v0.2.3 and no classification, and zero horizon structural findings on the corrected tree. `tickets.yml:51` now records the population change and unrelated debt separately. The twelve promotions are justified below. |
| F3: incomplete capability return/failure contracts | Resolved. `ws1_output_handler_design.md:64` supplies the failure rule and `:90` starts the complete per-method table. It now covers the non-WROTE return difference, memory's ignored transaction argument, accounting-fact rejection, equity/summary returns, empty compiled batches, NULL reads and unattributed empty event tables. The source census and focused memory probe agree. Optional wording precision is noted below. |
| F4: design marked complete before its measurement dependency | Resolved. `tickets.yml:59` and `:71` both say in_progress; `:74` preserves the LDG-3127 dependency and `:79` explicitly defers design completion until measurement and this re-review. LDG-3129 remains planned and depends on LDG-3128. The accepted serial sequence at `:13` is intact. |

LDG-3126's implementation also checks out independently. Both defaults changed at `tools/governance-report.R:1445` and `:1583`. Running the actual LTB-0514 block with private source environments produced: unchanged, 9 passed/0 failed/no error; first default reverted, a missing-tickets error; CLI default reverted, 4 failed expectations. Neither tool source nor test source was edited. LCL-0505 describes what this test actually detects. The RFC row at `inst/design/rfc/README.md:87` correctly records opening with decision (4), retains the Type 2 route and names its next stage as a seed; it does not pretend the page-role decision is finished.

The complete focused governance test file passed all three blocks: 168 + 29 + 9 = 206 expectations, zero failures, errors or skips. The real-tree report independently reproduced 874 structural findings, with zero findings sourced at this cut's tickets.yml. The focused horizon scanner and link scanner over horizon.md, horizon_archive.md and the new classification returned zero findings. The report is still report-mode evidence, not a globally clean governance certificate.

Reading "no structural finding on this cut" as merely "none sourced at tickets.yml" remains unacceptable for a finding caused by activation. A report-mode exit 0 alone is insufficient too. The corrected implementation no longer relies on that reading: it resolves the activation-caused horizon regression and separately identifies pre-existing packet/header/link debt. This does not require repairing every historical governance finding in WS1.

## F2: the twelve promotions and the size of the repair

The classification is correct against the accepted macro plan and inventory. It need not be narrowed to the WS1-related entry.

| Newly promoted IDs | Current receiving scope |
| --- | --- |
| H003 | H4 real-data use audit and per-block decisions, plus C10's companion-package/coupling decision in WS11. |
| H004 | H5a's export-census proposal is superseded by C9; H5b's collation pin belongs to WS12. The test-oracle question already has its testing-architecture disposition. |
| H005 | The four levers have WS4, WS1, WS6 and WS7 owners; the defensive-code/complexity audit is M1 in WS12. The fold split has shipped. |
| H012 | C5/H11 in WS9 own memory measurement, structural reduction and worker budgets. Promotion does not decide representation or shared-memory defaults. |
| H016 | X4/WS3 owns the full suite, with the benchmark-methodology RFC retaining its design/publication obligations. |
| H033 | U3/WS11 owns the helper-bundles RFC and consumes R4's obligations; no bundle syntax or implementation is selected here. |
| H074 | C4 has its own Type 2 cut, explicitly separated at `macro_plan.md:68` and `:143`. Its link to the WS4 section does not incorporate it into WS4 or WS1. |
| H075 | C7/WS8 owns the typed-R batch and comparison. Compiled widening remains with its existing RFC. |
| H080 | C10/WS11 owns the four measurements and core-boundary ADR. No package split is authorized. |
| H081 | Every audit finding has the inventory receiver stated in the row: H1, C1, M5 or H3. Its two referenced parked questions are themselves reconciled as H003/H004. |
| H082 | C9/WS11 owns tiering and its mechanism decision, retaining the macro plan's conditional CRAN timing. |
| H083 | C11/WS10 owns the precision/tradability RFC and subsequent implementation. |

Evidence: `inst/design/ledgr_v0_2_3_spec_packet/horizon_open_classification.md:29`, `:38`, `:42`, `:59`, `:100` and `:106`; `macro_plan.md:113` through its WS12 sections; the corresponding inventory rows C4-C11, H1/H3-H6/H11, U3 and X4.

Crucially, the mixed-entry rule at `horizon_open_classification.md:17` is applied rather than discarded. H007 stays genuine because one connection per composite call is still unowned (M9); remeasuring H6 does not own that entire entry. H084 stays parked for a separate sister-package packet, and H085's advanced article is not silently scheduled by U2. Conceptual compression, LFB-028 and other unowned questions also remain Open. A promoted RFC input is owned pending design, not implemented or decided.

This is the v0.2.2 promotion mechanism, not a new one. `inst/design/ledgr_v0_2_2_spec_packet/tickets.yml:2232` requires classification against authoritative receivers, concise pointers for promoted entries and preserved unresolved debt; its accepted classification explains the same mixed-entry rule. The v0.2.3 repair preserves the 79 earlier IDs/evidence and adds the six later entries. All 85 headings occur once; the result is 67 genuine, 15 promoted, two shipped and one superseded. The six earlier non-genuine rows retain their existing dispositions/destinations, with relative links rebased to their original packet.

The twelve new redirects at `inst/design/horizon.md:3724` onward retain exact headings and link both receiver and archived body. Each corresponding body occurs once under `inst/design/horizon_archive.md:6660` onward. An independent comparison against base git blobs found every moved heading/body unchanged, allowing only boundary blank lines and the separate anchor preceding the next entry. This is preservation of about 608 lines of historical text, not 608 lines of newly operative design. The new source files' links resolve.

Adding this classification is a necessary LDG-3126 activation repair. Applying already accepted macro-plan dispositions while preparing its input is within that repair; it does not implement the other workstreams, sequence their tickets or amend their decisions. Merely copying all old genuine labels would leave accepted receiving scope represented as uncommitted parking. There is no reason to restore the twelve bodies to Open, and no broader horizon redesign is authorized.

## Timing protocol and A/A baseline

The frozen executable protocol satisfies LDG-3127 and cut_review_1.md F4:

- `dev/bench/v0_2_3_ws1_timing/matrix.R:58` declares nine workloads: all eight A0 timing workloads (including 20x252) and the additional 50x1260 workload, each through run and sweep: 18 cells.
- Eight adjacent, alternating pairs produce 288 fresh measurement processes. `runner.R:175` onward invokes a fresh Rscript for each row; `measure.R:63` onward constructs a fresh snapshot, warms with a sweep and one committed run per candidate, then runs gc() identically for both arms and paths.
- Inputs, seeds, candidate counts, expected DONE/INCOMPLETE statuses and retained surfaces are declared. INCOMPLETE is expected only for the named workload, not accepted as a substitute for DONE elsewhere.
- Each arm is installed separately from git archive. Commit/tree/product identity, toolchain, runner settings and each child's actual power-plan GUID/affinity are recorded. The accepted host settings are checked. No process retry or selective pair addition exists.
- Seconds are serialized with %.17g and retained as text through the parent CSV append. The statistic is median(candidate seconds) / median(base seconds) per cell, not a median of pair ratios.
- `check.R:90` constructs the complete expected grid. Empty/partial records cannot pass vacuously. Missing, duplicate and unexpected keys, invalid seconds, failed/skipped processes, wrong statuses/counts, host mismatches, incomplete/smoke records and changed protocol are rejected. Additional identity/order checks address the previous optional suggestion. A PASS checks internal consistency; provenance still requires inspection of the record and meta.csv.

The synthetic checker demonstration exited 0. The clean CLI case exited 0; missing-row and ratio 1.031 cases each exited 1. All eighteen corruptions were detected for their named reason; the linked exception case passed. These are checker tests, not execution or timing measurements.

The `Sys.time()` endpoints at `measure.R:86` and `:94` are sound for the declared warm public-call comparison. All committed calls and closes are inside the run interval; the complete sweep call and retained-result construction are inside the sweep interval. Snapshot preparation and post-call validation reads are outside both. Small wrapper/loop overhead is consistently included. This is neither a cold lifecycle clock nor an isolated fold clock, and H6 must be described under that boundary. An adjustable civil clock cannot guarantee 3% repeatability; protocol.md now acknowledges clock adjustments and preserves invalid/noisy attempts instead of retrying them.

An A/A base record with base = candidate = 07dbbc87, installed twice, is appropriate. It reports both arms' base H6 values and observed repeatability before any product change; it is not a bound on future noise or the final candidate gate.

The disposition at `protocol.md:152` is correct if a small A/A cell exceeds 1.03: keep the red record and raw rows, report the affected cells and both H6 values, and obtain maintainer disposition before product edits. A valid baseline can establish H6 without an A/A ratio victory. Do not retry until green, select pairs, add pairs, round away the miss or carry a baseline disposition forward as an automatic final-cell exemption. If the measurement protocol needs revision, version/freeze it and take a new baseline before product edits, preserving the first attempt. Every over-bound final candidate cell still needs its own linked exception.

The committed range changes none of R/, src/, DESCRIPTION, NAMESPACE, A0 or the active peer benchmark. The frozen-before-product-change requirement holds. LDG-3127's measurement acceptance remains to be fulfilled.

## Handler design and implementation constraints

The method census agrees with Section 5 exactly: 21 persistent methods, 27 memory methods, 19 shared names and 29 unique method rows, each once. The fold references 17 members. The constructor census is also exact: two production calls, 38 test calls distributed 14/9/7/6/2 across the named files, and one active peer call. Section 6 has one row for every requested consumer group, including the compiled guard, plus the additional pulse-inspection/event-poster uses. Walk-forward delegates through the public run/sweep routes.

Sections 3-4 correctly separate shared event buffering, staging/growth, lifecycle bookkeeping and diagnostic numbering from sink differences. Existing required memory discard/retain policies remain callable because those are their supported semantics today. Unsupported optional capabilities remain absent. In particular, DuckDB has no append_compiled_spot_batch binding; the unchanged `R/compiled-spot-fifo.R:54` guard still refuses it, admits memory only within the current envelope and refuses live mode. No new execution-mode branch or second fold core is proposed. The buffered-DuckDB refusal test remains necessary because A0's compiled lane uses memory.

The R3 arithmetic at `ws1_output_handler_design.md:219` matches both current publication implementations: numeric coercions, BUY -(qty * price + fee), SELL +(qty * price - fee), and signed quantity, with the same operation order. The payload is the buffered DuckDB and memory consumer; the live writer is the other direct consumer. Memory must not add a second computation beside the payload. The existing leg-fee helper remains a projection of resolved fee/lot quantities. Preserve the live writer's validation and NO_OP ordering, event-sequence selection, transaction behavior and its existing JSON encoder. Planner affordability, fold-state arithmetic and compiled arithmetic remain outside this ticket. Close only R3's pipeline obligation.

Section 8's A0 factory wrapper, memory-state adapter and two persistent corruption wrappers are precisely the attachment points permitted by decision (1). Active bindings can expose the actual shared event environment and closure-local sink diagnostics for reading and mutation. A0's old observer-only prose does not override the accepted expanded allowance. Implementation must prove the adapters alter those actual owners: the control and all 17 named-difference corruptions remain required, with unchanged fixtures, canonicalization, injected changes and recorded bytes.

Section 12's three repairs are within this cut, provided they remain the stated local representation changes in code moving into sinks:

- `R/backtest-runner.R:528`: replace per-pulse state frames and final binding with typed state columns.
- `R/sweep.R:2475`: replace environment-held equity-fact list growth/repeated extraction with typed columns.
- `R/sweep.R:2548`: move retained diagnostic chunks to closure-local storage.

These repair shapes 1/7 in the very owners the cut must move and review. They do not change persistence policy, economics, retention or format and do not authorize WS9 or package-wide cleanup. Preserve timestamp classes, row/column order, NULL/empty distinctions, diagnostic numbering, allocation-bound oracles and all A0 bytes. The explicitly retained per-row JSON debt is not a claim that every seven-shape issue has been eliminated.

Phase A does not replace the LDG-3130/3131/3132 gates: predicate-appropriate structural mutants after owner relocation; claim-by-claim parity retirement; real worker-native event/attribute/diagnostic/completion evidence and its event-ID corruption; retained recovery/growth and nonzero-fill equivalence witnesses; final-candidate full tests/check, A0/control/guts, deleted-reference inventory, store-binding/identity evidence and unchanged paired timing protocol. No skip of a required worker/recovery witness is a pass.

## Optional

1. **P3 - Finish the front-door correction.** `inst/design/README.md:10` still says no cut is open and `:81` repeats that claim, although its table now names accepted Cut 1. A reader can still route implementation incorrectly. Replace those statements with "v0.2.3 Cut 1 is open; its tickets.yml is the sole ticket and sequencing authority." The previous optional front-door suggestion is only partially resolved.

2. **P3 - Tighten the transaction wording.** `ws1_output_handler_design.md:68` says rollback occurs on "any condition." An ordinary warning is also an R condition and does not imply rollback in the existing wrapper. Say "on an error or interrupt" and preserve warning propagation. This is wording precision, not authorization to change DBI behavior.

3. **Optional checker hardening.** `check.R:159` compares n_trades strings without first requiring finite nonnegative numeric counts. If all rows of a cell contain NA, that work-equality check alone passes. Reject missing/invalid counts explicitly if this auxiliary check is strengthened. The required measurement-grid/seconds/status checks are not vacuous, and the actual runner still supplies trade counts.

4. **Optional implementation witness.** When doing Section 12's typed equity/state repairs, exercise growth beyond the initial capacity and compare values/classes/order across the boundary. Small A0 rows alone do not force those new buffers to grow. Keep the existing event allocation bounds and registered oracles unchanged.

The prior optional metadata/order hardening, scoped cleanup for default_packet_revert_demo.R and civil-clock disposition were addressed. I inspected the now function-scoped demo but did not run its on-disk mutations; the independent in-memory mutation probe above supplies the requested evidence.

## Verification limits and workspace

No timing runner/smoke, A0 workload/gut execution, worker daemon, full package suite, build or package check ran. The tests executed here are the governance file, private-source default mutations and synthetic timing-checker demonstration. R emitted locale startup warnings.

At entry R/cpp11.R and src/cpp11.cpp were already marked modified; their ordinary diff is empty with LF/CRLF warnings. They were left untouched. Git's normal worktree discovery rejected ownership even with per-command safe-directory arguments; read-only commands then used the worktree's explicit git directory. No global configuration was changed. git diff --check on the reviewed range exits 1 solely for the previous review's extra blank line at EOF, not a product defect.

Only ws1_phase_a_review_2.md was written in this repository. No commit was made.

## Commands and exit codes

The ledger includes exploratory command/probe failures. The first body-comparison attempt needed UTF-8 tagging on git output; the second also included the next entry's separate anchor. The final comparison fixes those harness boundaries and passes all twelve bodies. Neither failed probe indicated a product text change. Long read/search output was sometimes truncated by the tool; focused follow-up reads supplied the cited sections. Temporary files were confined to normal test/checker temporary directories.

<details>
<summary>Command ledger</summary>

1. Exit 1.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler status --short
```

2. Exit 1.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler diff --stat 07dbbc87..143a4e9e
```

3. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/AGENTS.md
```

4. Exit 1.

```powershell
git -c safe.directory=C:/Users/maxth/ledgr-wt/ws1-output-handler -C C:/Users/maxth/ledgr-wt/ws1-output-handler status --short
```

5. Exit 1.

```powershell
git -c safe.directory=C:/Users/maxth/ledgr-wt/ws1-output-handler -C C:/Users/maxth/ledgr-wt/ws1-output-handler diff --stat 07dbbc87..143a4e9e
```

6. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_phase_a_review.md
```

7. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml
```

8. Exit 0.

```powershell
Get-Command git | Format-List Source,CommandType,Definition
```

9. Exit 1.

```powershell
git -c 'safe.directory=C:/Users/maxth/ledgr-wt/ws1-output-handler' -C 'C:/Users/maxth/ledgr-wt/ws1-output-handler' rev-parse HEAD
```

10. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/cut_review_1.md
```

11. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/cut_review_1_rereview_1.md
```

12. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/horizon_open_classification.md
```

13. Exit 1.

```powershell
git -c safe.directory=* -C C:/Users/maxth/ledgr-wt/ws1-output-handler diff --stat 07dbbc87..143a4e9e
```

14. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md
```

15. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/.git
```

16. Exit 0.

```powershell
git -c safe.directory=* -C C:/Users/maxth/ledgr-wt/ws1-output-handler config --show-origin --get-all safe.directory
```

17. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/protocol.md
```

18. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md
```

19. Exit 0.

```powershell
git --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler --work-tree=C:/Users/maxth/ledgr-wt/ws1-output-handler diff --stat 07dbbc87..143a4e9e
```

20. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/horizon_open_classification.md -TotalCount 48
```

21. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/manual/benchmark_methodology.qmd
```

22. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler status --short
```

23. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/manual/optimization_coding_style.qmd
```

24. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_output_freeze/closeout.md
```

25. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/cut_review_1_rereview_1.md
```

26. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler log -7 --oneline
```

27. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_output_freeze/closeout.md
```

28. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_2_spec_packet/horizon_open_classification.md -TotalCount 48
```

29. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler diff 07dbbc87..143a4e9e -- tools/governance-report.R tests/testthat/test-governance-report.R tests/claims.yml inst/design/rfc/README.md inst/design/README.md inst/design/ledgr_v0_2_3_spec_packet/README.md
```

30. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/check.R
```

31. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/governance_guard/default_packet_revert_demo.R
```

32. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/runner.R
```

33. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/measure.R
```

34. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/matrix.R
```

35. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/R/backtest-runner.R -TotalCount 610
```

36. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/inventory_reconciliation.md
```

37. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/R/sweep.R | Select-Object -Skip 1981 -First 630
```

38. Exit 0.

```powershell
rg -n -A 670 '^## v0.2.3|v023-reconciled-open-bodies' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/horizon_archive.md
```

39. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/check_demo.R
```

40. Exit 0.

```powershell
Rscript --no-init-file C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/check_demo.R
```

41. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
tool <- file.path(root, "tools/governance-report.R")
original <- readLines(tool, warn=FALSE, encoding="UTF-8")
hits <- grep('current_packet = "inst/design/ledgr_v0_2_3_spec_packet"', original, fixed=TRUE)
stopifnot(length(hits)==2L)
for (variant in c(0L,hits)) {
  mutated <- original
  if (variant) mutated[[variant]] <- sub("ledgr_v0_2_3_spec_packet", "ledgr_v0_2_2_spec_packet", mutated[[variant]],fixed=TRUE)
  scope <- new.env(parent=globalenv())
  scope$sys.source <- local({ txt <- mutated; function(file,envir,...) eval(parse(text=txt), envir=envir) })
  result <- as.data.frame(testthat::test_file(file.path(root,"tests/testthat/test-governance-report.R"), desc="[LTB-0514] both governance report entry points default to the v0.2.3 packet", env=scope, reporter="silent", stop_on_failure=FALSE))
  cat("variant", variant, "passed",result$passed,"failed",result$failed,"error",result$error,"skipped",result$skipped,"\n")
  stopifnot(if(variant==0L) all(result$failed==0L & !result$error & !result$skipped) else any(result$failed>0L | result$error))
}
stopifnot(identical(original,readLines(tool,warn=FALSE,encoding="UTF-8")))
cat("PASS: actual LTB-0514 detects each reverted default using private source environments; no source file changed.\n")
'@ | Rscript --vanilla -
```

42. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/tools/governance-report.R | Select-Object -Skip 1190 -First 150
```

43. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/horizon_archive.md | Select-Object -Skip 6930 -First 131
```

44. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml -TotalCount 28
```

45. Exit 0.

```powershell
rg -n 'git|governance_scan_|sources <-|current_packet|tracked' C:/Users/maxth/ledgr-wt/ws1-output-handler/tools/governance-report.R
```

46. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
g <- new.env(parent=globalenv()); sys.source(file.path(root,"tools/governance-report.R"), g)
report <- g$governance_report(root, file.path(root,"dev/governance_guard/baseline.yml"), file.path(root,"tests/claims.yml"))
f <- report[startsWith(report,"FINDING\t")]
cat("Total findings:", length(f), "\n")
cat("Structural findings:",sum(grepl("severity=structural\t",f,fixed=TRUE)),"\n")
cat("Horizon findings:",sum(grepl("horizon",f,fixed=TRUE)),"\n")
cat("Ticket evidence findings:\n",paste(f[grepl("source=inst/design/ledgr_v0_2_3_spec_packet/tickets.yml\t",f,fixed=TRUE)],collapse="\n"),"\n")
cat(paste(tail(report,8),collapse="\n"),"\n")
'@ | Rscript --vanilla -
```

47. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/R/ledger-writer.R -TotalCount 190
```

48. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/R/compiled-spot-fifo.R -TotalCount 110
```

49. Exit 0.

```powershell
rg -n 'output_handler\$|ledgr_(persistent|memory)_output_handler' C:/Users/maxth/ledgr-wt/ws1-output-handler/R C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/peer_benchmark/peer_benchmark.R
```

50. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
g <- new.env(parent=globalenv()); sys.source(file.path(root,"tools/governance-report.R"),g)
tracked <- g$governance_read_tracked(root)
packet <- "inst/design/ledgr_v0_2_3_spec_packet"
sources <- g$governance_population(tracked,packet)
f <- g$governance_scan_horizon(root,sources,packet)
cat("Current horizon structural findings:",nrow(f),"\n"); print(f)
links <- g$governance_scan_links(root,intersect(sources,c("inst/design/horizon.md","inst/design/horizon_archive.md",paste0(packet,"/horizon_open_classification.md"))),tracked)
print(links)
'@ | Rscript --vanilla -
```

51. Exit 1.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
gd <- "C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler"
g <- new.env(parent=globalenv()); sys.source(file.path(root,"tools/governance-report.R"),g)
blob <- function(path, rev="07dbbc87") system2("git",c("-C",shQuote(root),paste0("--git-dir=",gd),"show",paste0(rev,":",path)),stdout=TRUE)
hpath <- "inst/design/horizon.md"; apath <- "inst/design/horizon_archive.md"
oldh <- blob(hpath); olda <- blob(apath)
p22 <- "inst/design/ledgr_v0_2_2_spec_packet"; p23 <- "inst/design/ledgr_v0_2_3_spec_packet"
base_read <- g$governance_read_lines
for (packet in c(p22,p23)) {
  overrides <- setNames(list(oldh,olda),file.path(root,c(hpath,apath)))
  g$governance_read_lines <- function(path) if(path %in% names(overrides)) overrides[[path]] else base_read(path)
  sources <- c(hpath,apath,if(packet==p22) paste0(p22,"/horizon_open_classification.md"))
  f <- g$governance_scan_horizon(root,sources,packet)
  cat("Base inputs /",packet,":",nrow(f),"findings\n"); print(table(f$kind))
}
g$governance_read_lines <- base_read
classify <- g$governance_horizon_classification(readLines(file.path(root,p23,"horizon_open_classification.md"),encoding="UTF-8"))
oldclass <- g$governance_horizon_classification(blob(paste0(p22,"/horizon_open_classification.md")))
moved <- classify[classify$class=="promoted" & !(classify$heading %in% oldclass$heading[oldclass$class!="genuine"]),]
archive <- readLines(file.path(root,apath),encoding="UTF-8",warn=FALSE)
trim <- function(x) {while(length(x)&&!nzchar(tail(x,1))) x<-head(x,-1); x}
counts <- integer()
for (i in seq_len(nrow(moved))) {
  h <- paste0("### ",moved$heading[[i]])
  a <- which(oldh==h); b <- which(archive==h)
  stopifnot(length(a)==1,length(b)==1)
  end_a <- which(seq_along(oldh)>a & grepl("^#{1,3} ",oldh)); end_b <- which(seq_along(archive)>b & grepl('^<a id="v023-',archive))
  abody <- trim(oldh[a:(if(length(end_a)) end_a[[1]]-1L else length(oldh))])
  bbody <- trim(archive[b:(if(length(end_b)) end_b[[1]]-1L else length(archive))])
  cat(moved$id[[i]],"body unchanged:",identical(abody,bbody),"lines:",length(abody),"\n")
  if(!identical(abody,bbody)) print(setdiff(abody,bbody))
  stopifnot(identical(abody,bbody))
  counts <- c(counts,length(abody)-1L)
}
cat("Classification:"); print(table(classify$class)); cat("Moved entries:",nrow(moved),"body lines excluding headings:",sum(counts),"\n")
'@ | Rscript --vanilla -
```

52. Exit 1.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
gd <- "C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler"
g <- new.env(parent=globalenv()); sys.source(file.path(root,"tools/governance-report.R"),g)
blob <- function(path, rev="07dbbc87") system2("git",c("-C",shQuote(root),paste0("--git-dir=",gd),"show",paste0(rev,":",path)),stdout=TRUE)
hpath <- "inst/design/horizon.md"; apath <- "inst/design/horizon_archive.md"
oldh <- blob(hpath); olda <- blob(apath)
Encoding(oldh) <- "UTF-8"; Encoding(olda) <- "UTF-8"
p22 <- "inst/design/ledgr_v0_2_2_spec_packet"; p23 <- "inst/design/ledgr_v0_2_3_spec_packet"
base_read <- g$governance_read_lines
for (packet in c(p22,p23)) {
  overrides <- setNames(list(oldh,olda),file.path(root,c(hpath,apath)))
  g$governance_read_lines <- function(path) if(path %in% names(overrides)) overrides[[path]] else base_read(path)
  sources <- c(hpath,apath,if(packet==p22) paste0(p22,"/horizon_open_classification.md"))
  f <- g$governance_scan_horizon(root,sources,packet)
  cat("Base inputs /",packet,":",nrow(f),"findings\n"); print(table(f$kind))
}
g$governance_read_lines <- base_read
classify <- g$governance_horizon_classification(readLines(file.path(root,p23,"horizon_open_classification.md"),encoding="UTF-8"))
oldclass <- g$governance_horizon_classification(blob(paste0(p22,"/horizon_open_classification.md")))
moved <- classify[classify$class=="promoted" & !(classify$heading %in% oldclass$heading[oldclass$class!="genuine"]),]
archive <- readLines(file.path(root,apath),encoding="UTF-8",warn=FALSE)
trim <- function(x) {while(length(x)&&!nzchar(tail(x,1))) x<-head(x,-1); x}
counts <- integer()
for (i in seq_len(nrow(moved))) {
  h <- paste0("### ",moved$heading[[i]])
  a <- which(oldh==h); b <- which(archive==h)
  stopifnot(length(a)==1,length(b)==1)
  end_a <- which(seq_along(oldh)>a & grepl("^#{1,3} ",oldh)); end_b <- which(seq_along(archive)>b & grepl('^<a id="v023-',archive))
  abody <- trim(oldh[a:(if(length(end_a)) end_a[[1]]-1L else length(oldh))])
  bbody <- trim(archive[b:(if(length(end_b)) end_b[[1]]-1L else length(archive))])
  cat(moved$id[[i]],"body unchanged:",identical(abody,bbody),"lines:",length(abody),"\n")
  if(!identical(abody,bbody)) print(setdiff(abody,bbody))
  stopifnot(identical(abody,bbody))
  counts <- c(counts,length(abody)-1L)
}
cat("Classification:"); print(table(classify$class)); cat("Moved entries:",nrow(moved),"body lines excluding headings:",sum(counts),"\n")
'@ | Rscript --vanilla -
```

53. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
gd <- "C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler"
g <- new.env(parent=globalenv()); sys.source(file.path(root,"tools/governance-report.R"),g)
blob <- function(path, rev="07dbbc87") system2("git",c("-C",shQuote(root),paste0("--git-dir=",gd),"show",paste0(rev,":",path)),stdout=TRUE)
hpath <- "inst/design/horizon.md"; apath <- "inst/design/horizon_archive.md"
oldh <- blob(hpath); olda <- blob(apath)
Encoding(oldh) <- "UTF-8"; Encoding(olda) <- "UTF-8"
p22 <- "inst/design/ledgr_v0_2_2_spec_packet"; p23 <- "inst/design/ledgr_v0_2_3_spec_packet"
base_read <- g$governance_read_lines
for (packet in c(p22,p23)) {
  overrides <- setNames(list(oldh,olda),file.path(root,c(hpath,apath)))
  g$governance_read_lines <- function(path) if(path %in% names(overrides)) overrides[[path]] else base_read(path)
  sources <- c(hpath,apath,if(packet==p22) paste0(p22,"/horizon_open_classification.md"))
  f <- g$governance_scan_horizon(root,sources,packet)
  cat("Base inputs /",packet,":",nrow(f),"findings\n"); print(table(f$kind))
}
g$governance_read_lines <- base_read
classify <- g$governance_horizon_classification(readLines(file.path(root,p23,"horizon_open_classification.md"),encoding="UTF-8"))
oldclass <- g$governance_horizon_classification(blob(paste0(p22,"/horizon_open_classification.md")))
moved <- classify[classify$class=="promoted" & !(classify$heading %in% oldclass$heading[oldclass$class!="genuine"]),]
archive <- readLines(file.path(root,apath),encoding="UTF-8",warn=FALSE)
trim <- function(x) {while(length(x)&&(!nzchar(tail(x,1)) || grepl("^<a id=",tail(x,1)))) x<-head(x,-1); x}
counts <- integer()
for (i in seq_len(nrow(moved))) {
  h <- paste0("### ",moved$heading[[i]])
  a <- which(oldh==h); b <- which(archive==h)
  stopifnot(length(a)==1,length(b)==1)
  end_a <- which(seq_along(oldh)>a & grepl("^#{1,3} ",oldh)); end_b <- which(seq_along(archive)>b & grepl('^<a id="v023-',archive))
  abody <- trim(oldh[a:(if(length(end_a)) end_a[[1]]-1L else length(oldh))])
  bbody <- trim(archive[b:(if(length(end_b)) end_b[[1]]-1L else length(archive))])
  cat(moved$id[[i]],"body unchanged:",identical(abody,bbody),"lines:",length(abody),"\n")
  if(!identical(abody,bbody)) print(setdiff(abody,bbody))
  stopifnot(identical(abody,bbody))
  counts <- c(counts,length(abody)-1L)
}
cat("Classification:"); print(table(classify$class)); cat("Moved entries:",nrow(moved),"body lines excluding headings:",sum(counts),"\n")
'@ | Rscript --vanilla -
```

54. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
e <- new.env(parent=globalenv())
for(f in c("backtest-runner.R","sweep.R")) sys.source(file.path(root,"R",f),e)
methods <- function(fn) {x<-deparse(body(fn)); sort(unique(sub('.*handler\\$([A-Za-z_]+)[[:space:]]*<-.*','\\1',grep('handler\\$[A-Za-z_]+[[:space:]]*<-',x,value=TRUE))))}
p <- methods(e$ledgr_persistent_output_handler); m <- methods(e$ledgr_memory_output_handler)
d <- readLines(file.path(root,"inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md"),encoding="UTF-8")
start <- grep('^## 5[.]',d); end <- grep('^## 6[.]',d)
rows <- grep('^\\| `', d[(start+1L):(end-1L)],value=TRUE)
map <- sub('^\\| `([^`]+)`.*','\\1',rows)
stopifnot(length(p)==21L,length(m)==27L,length(intersect(p,m))==19L, length(map)==29L,!anyDuplicated(map),setequal(map,union(p,m)))
cat("Methods: P",length(p),"M",length(m),"shared",length(intersect(p,m)),"unique map",length(map),"exactly once: TRUE\n")
files <- list.files(file.path(root,"tests/testthat"),pattern="[.]R$",full.names=TRUE)
n <- vapply(files,function(f) sum(grepl('ledgr_(persistent|memory)_output_handler[[:space:]]*[(]', readLines(f,warn=FALSE))),integer(1))
print(n[n>0]); stopifnot(sum(n)==38L)
x <- readLines(file.path(root,"R/fold-engine.R")); refs <- unique(unlist(regmatches(x,gregexpr('output_handler[$][A-Za-z_]+',x))))
cat("Fold members:",length(refs),"\n");stopifnot(length(refs)==17L)
for(f in c("fold-event-buffer.R","fold-reconstruction.R","lot-accounting.R")) sys.source(file.path(root,"R",f),e)
e$`%||%` <- function(x,y) if(is.null(x)) y else x
h <- e$ledgr_memory_output_handler("review")
stopifnot(identical(h$buffer_event(NULL),TRUE),identical(h$flush_pending(),TRUE),identical(h$pending_event_count(),0L),is.null(h$completion()),is.null(h$diagnostics()))
stopifnot(!inherits(h$typed_events(),"ledgr_memory_events"),is.null(attr(h$typed_events(),"ledgr_event_cash_delta")))
cat("Memory non-WROTE, retain/no-flush, NULL reads and empty-event attributes match Section 4.1.\n")
'@ | Rscript --vanilla -
```

55. Exit 0.

```powershell
rg -n -A 55 -B 3 'contract-execution-(fold-core|accounting-events)' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/contracts.md
```

56. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md | Select-Object -Skip 307 -First 43
```

57. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md | Select-Object -Skip 485 -First 40
```

58. Exit 0.

```powershell
rg -n -A 25 -B 6 'LDG-3046|classification|promot' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_2_spec_packet/tickets.yml
```

59. Exit 1.

```powershell
rg -n -A 16 -B 2 'id: "LDG-3046"' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_2_spec_packet/tickets.yml
```

60. Exit 0.

```powershell
rg -n -A 8 -B 3 'mixed|horizon|promot' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/rfc/rfc_governance_lifecycle_v0_2_2_synthesis.md
```

61. Exit 1.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler diff --check 07dbbc87..143a4e9e
```

62. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler diff --exit-code 07dbbc87..143a4e9e -- R src DESCRIPTION NAMESPACE dev/bench/v0_2_3_output_freeze dev/bench/peer_benchmark
```

63. Exit 0.

```powershell
rg -n -A 12 -B 2 'id:.*LDG-3046' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_2_spec_packet/tickets.yml
```

64. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_phase_a_review.md | Select-Object -Skip 110 -First 52
```

65. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/R/backtest-runner.R | Select-Object -Skip 537 -First 63
```

66. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_output_freeze/lib.R | Select-Object -Skip 324 -First 64
```

67. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_output_freeze/guts.R -TotalCount 125
```

68. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_phase_a_review.md | Select-Object -Skip 78 -First 34
```

69. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/tests/testthat/test-governance-report.R -TotalCount 95
```

70. Exit 0.

```powershell
rg -n -g 'helper*.R' '^ledgr_test_system2|coverage' C:/Users/maxth/ledgr-wt/ws1-output-handler/tests/testthat
```

71. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
scope <- new.env(parent=globalenv())
sys.source(file.path(root,"tests/testthat/helper-fixtures.R"),scope)
r <- as.data.frame(testthat::test_file(file.path(root,"tests/testthat/test-governance-report.R"), env=scope, reporter="summary", stop_on_failure=FALSE))
print(r[c("test","nb","failed","skipped","error","passed")],row.names=FALSE)
stopifnot(all(r$failed==0L & !r$error & !r$skipped))
'@ | Rscript --vanilla -
```

72. Exit 0.

```powershell
rg -n '^##|^###|Failure rule|\| `write_run|canonical R path|Compiled spot|three existing|Status:|Completion awaits' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md
```

73. Exit 0.

```powershell
rg -n 'H00[3457]|H012|H016|H033|H07[45]|H08[0-5]|mixed|Reconciliation' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/horizon_open_classification.md
```

74. Exit 0.

```powershell
rg -n 'One output handler|Open|Historical redirects|v023-h|Classification' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/horizon.md
```

75. Exit 0.

```powershell
rg -n '^### WS|C4|rules|Every cut|Authority' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md
```

76. Exit 0.

```powershell
rg -n 'rollback on any|any condition|trades <- unique|finished_utc|pair count|excepted <-|seq_no <-' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/check.R
```

77. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler diff -- R/cpp11.R src/cpp11.cpp
```

78. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/README.md -TotalCount 65
```

79. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/README.md -TotalCount 85
```

80. Exit 0.

```powershell
rg -n 'No v0.2.3 cut|no implementation cut|state\$pending_states\[\[|state\$equity_facts\[\[|state\$diagnostic_parts\[\[' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/README.md C:/Users/maxth/ledgr-wt/ws1-output-handler/R/backtest-runner.R C:/Users/maxth/ledgr-wt/ws1-output-handler/R/sweep.R
```

81. Exit 0.

```powershell
rg -n 'ws1_timing_workloads <-|Base record|If the A/A|record validity|t0 <-|t1 <-|for \(pair|for \(arm|write_run_evidence|current_packet' C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/matrix.R C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/protocol.md C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/measure.R C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/runner.R
```

Final-file verification: the initial R -e command below failed because PowerShell stripped its string quotes; the equivalent here-string check then passed.

82. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler status --short
```

83. Exit 0.

```powershell
rg -n 'Verdict:|clock.*endpoints|Sys.time|Optional|undefined|matrix.R:|protocol.md:|^Authority:' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_phase_a_review_2.md
```

84. Exit 1.

```powershell
Rscript --vanilla -e 'p <- "C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_phase_a_review_2.md"; x <- readLines(p, encoding="UTF-8", warn=FALSE); stopifnot(identical(x[[1]],"Verdict: PASS"), all(validUTF8(x)), any(x == "## Commands and exit codes"), tail(x,1) == "</details>"); cat("Review verdict, UTF-8 and command ledger verified.\n")'
```

85. Exit 0.

```powershell
@'
p <- "C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_phase_a_review_2.md"
x <- readLines(p, encoding="UTF-8", warn=FALSE)
stopifnot(identical(x[[1]],"Verdict: PASS"), all(validUTF8(x)), any(x == "## Commands and exit codes"), tail(x,1) == "</details>")
cat("Review verdict, UTF-8 and command ledger verified.\n")
'@ | Rscript --vanilla -
```

</details>
