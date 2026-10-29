Verdict: CHANGES_REQUIRED

Role: record; independent clean-context review of WS1 Phase A.
Status: accepted; review recorded 2026-10-28, answered in 656ee7a5 and 143a4e9e.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Independent review of Phase A, 2026-10-28, branch claude/ws1-output-handler, range 07dbbc87..383545bc. HEAD: 383545bc9e5515d56ba79252d5e4c5f9e4bae9c9. Paths below are relative to the repository.

The shared-handler boundary is sound, and the timing runner is substantially ready for a baseline. Phase A is not yet a sufficient authority for LDG-3129 onward: the proposed contract conflicts with the unchanged compiled path, activation introduces governance findings, and the capability specification and dependency state need correction. The deliberately unrun baseline is missing evidence, not a failed measurement. Product edits must wait for LDG-3127.

## Required findings, ranked by severity

### F1 - P1: The R3 contract requires the excluded compiled path to use the new R helper

**Evidence:** inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md:184-190,200-211; R/fold-engine.R:1336; R/sweep.R:2211-2241; tickets.yml:13; contract rule group contract-execution-accounting-events.

Section 10 correctly excludes compiled typed deltas from R3. Its replacement contract then says that whenever a handler materializes a fill row, its deltas come only from ledgr_fill_publication_deltas() applied to the resolved fill. The memory handler also materializes compiled fill rows: append_compiled_spot_batch() writes batch$cash_delta and batch$position_delta directly into event columns. Those values do not pass through the proposed R helper.

**Failure scenario:** implementing LDG-3129 as designed while preserving compiled arithmetic leaves the new present-tense contract false. Making compiled publication obey the unqualified sentence would introduce redundant computation or change ownership outside the cut.

**Exact required change:** retain the first two quoted sentences prohibiting resolution, reinterpretation and rewriting of economics. Replace the remainder with:

> When a handler materializes a fill row from a resolved fill intent on the canonical R path, the row's cash and position deltas come only from the one publication computation, ledgr_fill_publication_deltas(), applied to the fill's resolved side, quantity, price and fee. On that path a resolved fee is split across the fill's close and open legs only by ledgr_fill_leg_fees(). These are row projections of the resolved fill, not a second economic computation. Compiled spot-FIFO batches supply the fold's already computed typed deltas and leg fees, which the handler publishes unchanged; this clarification changes neither compiled arithmetic nor its parity obligations against canonical R.

This makes the accepted scope distinction explicit without expanding compiled support. The proposed BUY/SELL formulas, coercions, operation order and indirect memory consumption through the payload are otherwise correct.

### F2 - P2: Activation cannot be declared clean by filtering findings to tickets.yml

**Evidence:** tickets.yml:46,51,54; tools/governance-report.R:1445,1472-1473,1583; tools/governance-report.R:1236-1250,1288-1295; missing inst/design/ledgr_v0_2_3_spec_packet/horizon_open_classification.md.

The old packet provides the horizon classification input. Changing both defaults removes it. On the same tracked inputs I independently reproduced 6 unclassified_horizon_open findings with v0.2.2 and 79 with v0.2.3. The current ticket-evidence scanner returns zero rows. These are different checks.

**Failure scenario:** previously classified Open entries become unclassified solely because activation changes the selected packet. Since these findings are sourced at horizon.md, restricting completion evidence to findings sourced at the cut's tickets.yml hides the activation regression. Report-mode exit 0 does not mean there are no findings.

Reading "no structural finding on this cut" as "no finding sourced at its ticket-evidence file" is insufficient for findings caused by this cut. It need not mean repairing all pre-existing header/link debt.

**Exact required change:** reconcile and add the current packet's horizon_open_classification.md with the scanner's exact schema and exact headings, preserving prior classification evidence and checking current Open entries against their actual disposition. Resolve the newly unclassified entries through that explicit record. Do not add an old-packet fallback or suppress the scan. Keep LDG-3126 incomplete until activation-caused structural findings are resolved, then replace its narrowed evidence with a before/after finding comparison. Identify unrelated existing debt separately. If the maintainer intends deferral instead, that needs an explicit amendment/disposition in tickets.yml; implementation evidence cannot amend acceptance.

Both defaults themselves are correct. LTB-0514/LCL-0505 is failure-sensitive: unchanged it passes; reverting line 1445 produces a missing-tickets error; reverting line 1583 produces four failed expectations. Private in-memory source mutations reproduced this without editing the tool. The RFC row at inst/design/rfc/README.md:87 correctly records opening, retains the Type 2 route, and names the seed as next stage.

### F3 - P2: The capability table does not specify all promised return/failure semantics

**Evidence:** ws1_output_handler_design.md:67,70-77; LDG-3128 scope/acceptance at tickets.yml:75-76; R/backtest-runner.R:299-308,471-504,511-546; R/sweep.R:2108-2146,2396-2527,2554-2599.

Several cells state side effects without success returns: status/completion writes, state writes, diagnostic writes and compiled append. The inline projection row combines three different return contracts and gives only an accounting-fact rejection return. There is no general failure-propagation rule. The typed-event row also states five attributes unconditionally, whereas materialize_events() returns ledgr_empty_event_table() before adding them when there are no events.

**Failure scenario:** a replacement follows the written table while returning different values, adding attributes to empty events, or swallowing a projection error. A method-name witness still passes. LDG-3128 expressly requires existence, return, side effects and failure per capability/sink.

**Exact required change:** complete Section 4 before closing LDG-3128. State that errors propagate unless an explicitly documented existing catch changes that behavior, and state successful returns for every method. In particular:

- Status/evidence writes, event/state appends, strategy-state writes, schedule/session writes and successful diagnostic writes return invisible(TRUE). Preserve telemetry's strict/non-strict failure behavior.
- Memory write_fill_events() returns its payload result and stages it when WROTE, including when its ignored use_transaction argument is TRUE; memory strategy-state writes return invisible(TRUE).
- record_accounting_fact() returns invisible(FALSE) for an invalid/non-WROTE result or when neither a staged nor buffered event exists; otherwise invisible(TRUE). It updates the latest staged entry or last buffered event and stages/adds close/open legs in that order.
- record_equity_fact() returns invisible(TRUE); inline_summary() returns list(equity, fills, metrics, final_equity), with final_equity = NA_real_ when no equity facts exist.
- Compiled append returns invisible(TRUE), including for an empty batch. Completion/diagnostic reads preserve their object/NULL results. Event reads preserve the empty table without added memory attributes when empty, and the attributed memory-event table when nonempty.

These are specification completions from current code, not permission to change registered test oracles.

### F4 - P2: LDG-3128 is marked complete before its incomplete dependency

**Evidence:** tickets.yml:12,59,62-64,71,74,84-87; AGENTS.md dependency and ticket-workflow rules.

LDG-3127 is in_progress without baseline/H6 evidence. LDG-3128 depends on it but is complete; LDG-3129 depends on LDG-3128. Drafting and reviewing the note now is useful, but its recorded completion contradicts the accepted serial sequence.

**Failure scenario:** following the sole ticket authority starts R3 before measurement, defeating the prerequisite that the baseline precede handler edits.

**Exact required change:** return LDG-3128 to in_progress, retain its design evidence and state that completion awaits LDG-3127 and the design corrections above. Produce and record the unchanged base-tree measurement before completing LDG-3127; then complete LDG-3128 and start LDG-3129. Preserve the accepted dependency chain. This review ran no timing.

## Timing and A/A assessment

The executable protocol meets the substantive cut-review F4 measurement requirements: nine workloads including 20x252 and 50x1260, both public paths (18 cells), eight pairs (288 measurement processes), adjacent alternating arms, fresh R processes, identical snapshot/sweep/run warmup plus gc(), full-precision seconds, ratio of medians, separate commit installations, commit/tree/product identities, toolchain metadata and actual runner/child power plan and affinity. Failed processes are recorded without retries. Every final cell remains subject to <= 1.03 or an explicit linked maintainer exception.

The checker cannot pass on an empty or partial matrix: it constructs the complete expected key grid and rejects empty/missing/duplicate/unexpected rows before accepting ratios. It rejects invalid seconds, errors/skips, unexpected statuses/candidate counts, wrong host settings, smoke/unfinished records and changed protocol. check_demo.R exited 0; missing-row and 1.031 CLI cases each exited 1, and its other named mutations were detected. Provenance still requires review; the checker does not authenticate a record (see Optional).

The Sys.time() endpoints are suitable for the declared warm public-call comparison: committed calls and handle closes are inside the run clock; the complete sweep call and retained-result construction are inside the sweep clock. Preparation, snapshot creation and result-validation reads are outside both. Small wrapper/loop overhead is included consistently. This is not the methodology's full cold lifecycle clock or an isolated fold timer. Sys.time() is an adjustable civil clock; finer precision does not remove scheduler noise or clock adjustments.

An A/A record with base = candidate = 07dbbc87, installed twice, is appropriate for base H6 and an observed repeatability check. It is not a statistical bound on future noise. Keep both arm H6 values and all raw rows. If an otherwise valid small A/A cell exceeds 1.03:

1. Keep the record and checker failure. Do not retry until green, select pairs, increase pair count, round, or change the threshold.
2. Separate record validity from the candidate ratio gate. An A/A miss shows variability, not a product regression. LDG-3127 requires valid base/H6 evidence, not a candidate no-regression victory.
3. Record affected cells and maintainer disposition before proceeding. Keep the final paired gate unchanged; each over-bound final candidate cell still needs its own linked exception. A baseline exception must not silently exempt that cell forever.
4. If noise requires a different protocol, obtain disposition before product edits, version/freeze the revision and take a new baseline under it. Preserve the first attempt.

Add this disposition to protocol.md before measuring to remove the ambiguity. It does not authorize automatic retries.

## Design/source assessment beyond the findings

The method map covers all 29 unique names exactly once: 21 persistent, 27 memory, 19 shared, two persistent-only and eight memory-only. The fold references 17 members. The constructor census is correct: two production calls, 38 test calls (14/9/7/6/2 in the named files), and one in the active peer benchmark. Each required consumer group has one map row; pulse inspection and event posters cover additional internal use. Walk-forward delegates through run/sweep.

Capability existence is correctly preserved. Existing required memory discard policies for telemetry/state/flush are legitimate policies, not newly advertised optional support. DuckDB must have no callable append_compiled_spot_batch; the unchanged guard refuses it before the compiled-symbol check. Memory admission and live refusal keep their current conditions. The planned buffered-DuckDB negative test covers the missing negative case in A0.

The A0 plan is within decision (1): factory observation, two persistent corruption wrappers and the memory-state mutation adapter are precisely the allowed attachment changes. Active bindings can write through to closure-local diagnostic retention and shared event columns. Thus Section 12's storage move need not alter either corruption. Prove the adapters modify actual owners rather than copies using the named-difference gut checks. Preserve the control, 17 identities, mutations, fixtures, canonicalization and recorded bytes. The old closeout's observer-only allowance does not override the accepted cut's expanded allowance.

Section 12's three local byte-identical repairs are within scope. They address shapes 1/7 in code already moving and support the mandated seven-shape review; they do not authorize broader optimization. Preserve timestamp/class/column order at state persistence, NULL/empty distinctions, numbering/retention, allocation bounds and A0 bytes. Recorded JSON debt is not a claim that all seven shapes are clean.

R3 needs no economic-rule change. Preserve the live writer's validation order, early NO_OP return, event-sequence choice and transactions. Memory consumes the shared helper indirectly through the payload; adding a second direct calculation violates "once." Close only R3 in the pipeline row.

Phase A does not discharge the final-tree full tests/check, A0/control/guts, identity/reference inventory, claim-level retirement, nonzero-fill equivalence, recovery or worker-native-buffer gates. Public two-worker status/completion comparisons cannot replace the native-buffer witness; required skips remain missing evidence. No new engine, mode branch, store compatibility reader or changed oracle is authorized.

## Optional

- Harden check.R metadata validation: require well-formed arm commit/tree/product identities and nonempty toolchain/host fields, and check the declared sequence against alternating order. The demo's clean synthetic metadata omits arm identities and still passes; its single PID and synthetic paths show why checker PASS alone cannot certify provenance/process isolation. The actual runner supplies that evidence.
- Put default_packet_revert_demo.R inside a function/local scope, or use private-source mutation. Its line 10 on.exit() is top-level and does not install the promised cleanup; an error/interruption after the mutation write can leave a default reverted. A read-only R probe confirmed top-level on.exit() does not run on normal script completion. I did not run this mutating demo.
- Update the design front door's stale "no accepted cut" statements through normal upkeep.
- State clock-adjustment rejection/disposition if retaining Sys.time(); do not describe clock resolution as a guarantee of 3% repeatability.

## Verification limits and workspace

No timing runner/smoke, A0 workloads/guts, worker daemons, build/check or full package suite ran. The focused governance file passed all three blocks with its actual helper loaded and no skips. Initial helper-free file attempts stopped because ledgr_test_system2() was unavailable; the invocation was corrected without changing a test. Standalone LTB-0514 private mutations and the synthetic timing checker demo passed. R emitted locale startup warnings.

The committed range changes no R/, src/, DESCRIPTION or NAMESPACE files. At entry R/cpp11.R and src/cpp11.cpp were modified; their ordinary diff was empty with line-ending warnings. They were left untouched. Plain git discovery failed ownership checks here, including per-command safe-directory attempts; subsequent read-only commands specified the worktree git directory and work tree. No global git configuration changed. Only this review file was written in the repository; no commit was made.

## Commands and exit codes

The ledger includes exploratory failures. Temporary fixture/checker files used normal temporary directories. Tool discovery and writing this review are not shell commands. An initial test invocation yielded without a captured final status; the controlled helper-loaded rerun is definitive.

<details>
<summary>Full command ledger</summary>

1. Exit 1.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler status --short
```

2. Exit 1.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler diff --stat 07dbbc87..383545bc
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
git -c safe.directory=C:/Users/maxth/ledgr-wt/ws1-output-handler -C C:/Users/maxth/ledgr-wt/ws1-output-handler diff --stat 07dbbc87..383545bc
```

6. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml
```

7. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/cut_review_1.md
```

8. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/cut_review_1_rereview_1.md
```

9. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md
```

10. Exit 0.

```powershell
Get-Command git | Format-List Source,CommandType,Definition
```

11. Exit 0.

```powershell
Get-ChildItem -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing
```

12. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/cut_review_1.md
```

13. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/cut_review_1_rereview_1.md
```

14. Exit 1.

```powershell
git -c safe.directory='*' -C C:/Users/maxth/ledgr-wt/ws1-output-handler diff --stat 07dbbc87..383545bc
```

15. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/protocol.md
```

16. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/check.R
```

17. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/.git
```

18. Exit 1.

```powershell
git -c safe.directory=C:\Users\maxth\ledgr-wt\ws1-output-handler -C C:/Users/maxth/ledgr-wt/ws1-output-handler status --short
```

19. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/runner.R
```

20. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/measure.R
```

21. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/matrix.R
```

22. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/check_demo.R
```

23. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/manual/benchmark_methodology.qmd
```

24. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/manual/optimization_coding_style.qmd
```

25. Exit 0.

```powershell
git -c safe.directory=* -C C:/Users/maxth/ledgr-wt/ws1-output-handler config --show-origin --get-all safe.directory
```

26. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml | Select-Object -Skip 46 -First 56
```

27. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_output_freeze/closeout.md
```

28. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler --work-tree=C:/Users/maxth/ledgr-wt/ws1-output-handler diff --stat 07dbbc87..383545bc
```

29. Exit 0.

```powershell
rg -n -A 30 -B 8 'LTB-0514|LCL-0505|current_packet =|unclassified_horizon_open' C:/Users/maxth/ledgr-wt/ws1-output-handler/tests/testthat/test-governance-report.R C:/Users/maxth/ledgr-wt/ws1-output-handler/tools/governance-report.R
```

30. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/governance_guard/default_packet_revert_demo.R
```

31. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/R/backtest-runner.R -TotalCount 600
```

32. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md -TotalCount 66
```

33. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler --work-tree=C:/Users/maxth/ledgr-wt/ws1-output-handler diff 07dbbc87..383545bc -- tools/governance-report.R tests/testthat/test-governance-report.R inst/design/rfc/README.md tests/claims.yml
```

34. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/R/sweep.R | Select-Object -Skip 1981 -First 315
```

35. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/R/sweep.R | Select-Object -Skip 2296 -First 308
```

36. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/R/ledger-writer.R -TotalCount 214
```

37. Exit 0.

```powershell
rg -n -A 8 -B 6 'output_handler\$|handler\$completion|handler\$typed_events|handler\$inline_summary' C:/Users/maxth/ledgr-wt/ws1-output-handler/R/fold-engine.R C:/Users/maxth/ledgr-wt/ws1-output-handler/R/run-finalize.R C:/Users/maxth/ledgr-wt/ws1-output-handler/R/run-registration.R C:/Users/maxth/ledgr-wt/ws1-output-handler/R/run-resume.R
```

38. Exit 0.

```powershell
rg -n -A 18 -B 3 'contract-execution-accounting-events|contract-execution-fold-core' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/contracts.md
```

39. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/tools/governance-report.R | Select-Object -Skip 1236 -First 53
```

40. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/manual/optimization_coding_style.qmd -TotalCount 150
```

41. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/manual/benchmark_methodology.qmd | Select-Object -Skip 162 -First 80
```

42. Exit 0.

```powershell
Rscript --vanilla C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_ws1_timing/check_demo.R
```

43. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/README.md -TotalCount 95
```

44. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/cut_review_1_rereview_1.md -TotalCount 160
```

45. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md | Select-Object -Skip 315 -First 40
```

46. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/peer_benchmark/peer_benchmark.R | Select-Object -Skip 690 -First 60
```

47. Exit 0.

```powershell
Rscript --vanilla -e "print(formals(testthat::test_file)); print(formals(testthat::with_reporter))"
```

48. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler --work-tree=C:/Users/maxth/ledgr-wt/ws1-output-handler status --short --branch
```

49. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler --work-tree=C:/Users/maxth/ledgr-wt/ws1-output-handler log --format=oneline 07dbbc87..383545bc
```

50. Exit 0.

```powershell
rg -n -A 10 -B 3 '^ledgr_sweep <-|workers = |^a0_retain|^a0_sink_state|memory_diagnostic|memory_factory|diagnostic_parts' C:/Users/maxth/ledgr-wt/ws1-output-handler/R/sweep.R C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_output_freeze/lib.R C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_output_freeze/guts.R
```

51. Exit 0.

```powershell
Rscript --vanilla -e "print(testthat::test_file); print(testthat:::test_files); print(testthat::test_path)"
```

52. Exit 0.

```powershell
rg -n -A 7 -B 5 'governance_population <-|classification_source <-|Governance|horizon' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/rfc/rfc_governance_lifecycle_v0_2_2_synthesis.md
```

53. Exit 1.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
path <- file.path(root,"tests/testthat/test-governance-report.R")
tool <- file.path(root,"tools/governance-report.R")
original <- readLines(tool, warn=FALSE)
hits <- grep("inst/design/ledgr_v0_2_3_spec_packet", original, fixed=TRUE)
stopifnot(length(hits)==2L)
results <- lapply(c(0L,hits), function(line) {
  probe <- new.env(parent=globalenv())
  probe$sys.source <- function(file,envir,...) {
    txt <- original
    if(line > 0L) txt[[line]] <- sub("ledgr_v0_2_3_spec_packet","ledgr_v0_2_2_spec_packet",txt[[line]],fixed=TRUE)
    eval(parse(text=txt,keep.source=FALSE),envir=envir)
  }
  result <- as.data.frame(testthat::test_file(path,desc="[LTB-0514]",env=probe,load_helpers=FALSE,reporter="silent"))
  data.frame(mutated_line=line, failed=result$failed,error=result$error,skipped=result$skipped)
})
out <- do.call(rbind,results)
print(out)
stopifnot(out$failed[1L]==0L,!out$error[1L],!any(out$skipped),all(out$failed[-1L]>0L | out$error[-1L]))
cat("Private-source mutation: unchanged passes; each reverted default fails. No repository write.\n")
'@ | Rscript --vanilla -
```

54. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
path <- file.path(root,"tests/testthat/test-governance-report.R")
tool <- file.path(root,"tools/governance-report.R")
original <- readLines(tool, warn=FALSE)
hits <- grep("inst/design/ledgr_v0_2_3_spec_packet", original, fixed=TRUE)
stopifnot(length(hits)==2L)
results <- lapply(c(0L,hits), function(line) {
  probe <- new.env(parent=globalenv())
  probe$sys.source <- function(file,envir,...) {
    txt <- original
    if(line > 0L) txt[[line]] <- sub("ledgr_v0_2_3_spec_packet","ledgr_v0_2_2_spec_packet",txt[[line]],fixed=TRUE)
    eval(parse(text=txt,keep.source=FALSE),envir=envir)
  }
  result <- as.data.frame(testthat::test_file(path,desc="[LTB-0514] both governance report entry points default to the v0.2.3 packet",env=probe,load_helpers=FALSE,reporter="silent"))
  data.frame(mutated_line=line, failed=result$failed,error=result$error,skipped=result$skipped)
})
out <- do.call(rbind,results)
print(out)
stopifnot(out$failed[1L]==0L,!out$error[1L],!any(out$skipped),all(out$failed[-1L]>0L | out$error[-1L]))
cat("Private-source mutation: unchanged passes; each reverted default fails. No repository write.\n")
'@ | Rscript --vanilla -
```

55. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
g <- new.env(parent=globalenv())
sys.source(file.path(root,"tools/governance-report.R"),g)
git <- function(...) system2("git",c("-C",root,paste0("--git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler"),paste0("--work-tree=",root),...),stdout=TRUE)
tracked <- git("ls-files")
for(packet in c("inst/design/ledgr_v0_2_2_spec_packet","inst/design/ledgr_v0_2_3_spec_packet")) {
  sources <- g$governance_population(tracked,packet)
  h <- g$governance_scan_horizon(root,sources,packet)
  cat(packet,"\n")
  print(table(h$kind))
  cat("classification exists:",file.exists(file.path(root,packet,"horizon_open_classification.md")),"\n")
}
t <- g$governance_scan_ticket_evidence(root,"inst/design/ledgr_v0_2_3_spec_packet")
print(t)
cat("HEAD:",git("rev-parse","HEAD"),"\n")
cat("Product difference paths in reviewed range:\n")
print(git("diff","--name-only","07dbbc87..383545bc","--","R","src","DESCRIPTION","NAMESPACE"))
'@ | Rscript --vanilla -
```

56. Exit 0.

```powershell
rg -n 'ledgr_(persistent|memory)_output_handler|\$buffer_event\(' C:/Users/maxth/ledgr-wt/ws1-output-handler/R C:/Users/maxth/ledgr-wt/ws1-output-handler/tests C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/peer_benchmark/peer_benchmark.R
```

57. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/tests/testthat/test-ledger-writer.R | Select-Object -Skip 195 -First 130
```

58. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/tests/testthat/test-corporate-action-recovery.R | Select-Object -Skip 140 -First 72
```

59. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/tests/testthat/test-governance-report.R -TotalCount 34
```

60. Exit 0.

```powershell
rg -n 'test-governance-report|LTB-0514|LCL-0505' C:/Users/maxth/ledgr-wt/ws1-output-handler/tools C:/Users/maxth/ledgr-wt/ws1-output-handler/tests
```

61. Exit 1.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ledgr_v0_2_3_spec.md -TotalCount 10
```

62. Exit 0.

```powershell
Get-ChildItem -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet -Filter ws1_phase_a_review*.md
```

63. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/R/compiled-spot-fifo.R -TotalCount 86
```

64. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md -TotalCount 115
```

65. Exit not captured (tool yielded; not relied on).

```powershell
Rscript --vanilla -e "result <- as.data.frame(testthat::test_file('C:/Users/maxth/ledgr-wt/ws1-output-handler/tests/testthat/test-governance-report.R',load_helpers=FALSE,reporter='summary')); stopifnot(!any(result\$failed > 0),!any(result\$error),!any(result\$skipped))"
```

66. Exit 1.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
r <- as.data.frame(testthat::test_file(file.path(root,"tests/testthat/test-governance-report.R"),load_helpers=FALSE,reporter="silent"))
print(r[c("test","failed","error","skipped")],row.names=FALSE)
bad <- r$failed>0 | r$error
for(i in which(bad)) print(r$result[[i]])
quit(status=if(any(bad)) 1L else 0L)
'@ | Rscript --vanilla -
```

67. Exit 0.

```powershell
rg -n 'ledgr_test_|::|baseline|system2' C:/Users/maxth/ledgr-wt/ws1-output-handler/tests/testthat/test-governance-report.R
```

68. Exit 0.

```powershell
rg -n '^ledgr_test_system2 <-' C:/Users/maxth/ledgr-wt/ws1-output-handler/tests/testthat
```

69. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/ledgr-wt/ws1-output-handler/tests/testthat/helper-fixtures.R | Select-Object -Skip 266 -First 78
```

70. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
e <- new.env(parent=globalenv())
sys.source(file.path(root,"tests/testthat/helper-fixtures.R"),e)
r <- as.data.frame(testthat::test_file(file.path(root,"tests/testthat/test-governance-report.R"),env=e,load_helpers=FALSE,reporter="summary"))
print(r[c("test","failed","error","skipped")],row.names=FALSE)
quit(status=if(any(r$failed>0 | r$error | r$skipped)) 1L else 0L)
'@ | Rscript --vanilla -
```

71. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
e <- new.env(parent=globalenv())
for(f in c("backtest-runner.R","sweep.R")) sys.source(file.path(root,"R",f),e)
methods <- function(fn) {
  s <- deparse(body(fn))
  x <- unique(unlist(regmatches(s,gregexpr("handler[$][a-z_]+[[:space:]]*<-",s))))
  sort(sub("[[:space:]]*<-$","",sub("handler[$]","",x)))
}
p <- methods(e$ledgr_persistent_output_handler); m <- methods(e$ledgr_memory_output_handler)
note <- readLines(file.path(root,"inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md"))
a <- grep("^## 5[.]",note); b <- grep("^## 6[.]",note)
rows <- note[(a+1):(b-1)]
map <- sub("^\\| [\x60]([a-z_]+)[\x60].*$","\\1",grep("^\\| [\x60]",rows,value=TRUE))
cat("persistent / memory / shared / method map:",length(p),length(m),length(intersect(p,m)),length(map),"\\n")
stopifnot(setequal(map,union(p,m)),!anyDuplicated(map))
files <- list.files(file.path(root,"tests/testthat"),pattern="[.]R$",full.names=TRUE)
n <- vapply(files,function(f)sum(grepl("ledgr_(persistent|memory)_output_handler[[:space:]]*[(]",readLines(f,warn=FALSE))),integer(1))
print(n[n>0]); stopifnot(sum(n)==38)
s <- readLines(file.path(root,"R/fold-engine.R"))
members <- unique(unlist(regmatches(s,gregexpr("output_handler[$][a-z_]+",s))))
cat("fold members:",length(members),"\\n")
stopifnot(length(members)==17L)
for(section in c("^## 4","^## 8","^## 10","^## 12")) cat(section,grep(section,note),"\\n")
cat("Method map exactly covers the union once.\\n")
'@ | Rscript --vanilla -
```

72. Exit 0.

```powershell
rg -n 'id: "LDG-312[6789]"|status:|dependencies:|no structural|unclassified_horizon|in_progress|complete' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml
```

73. Exit 0.

```powershell
Rscript --vanilla -e "on.exit(cat('TOP_LEVEL_CLEANUP_RAN')); cat('REACHED_END');"
```

74. Exit 0.

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler --work-tree=C:/Users/maxth/ledgr-wt/ws1-output-handler diff -- R/cpp11.R src/cpp11.cpp
```

75. Exit 1.

```powershell
Get-CimInstance Win32_Process -Filter "name = 'Rscript.exe'" | Select-Object ProcessId,CommandLine
```

76. Exit 0.

```powershell
rg -n 'Status:|publication|compiled|state|diagnostic|capabilit|returns|return' C:/Users/maxth/ledgr-wt/ws1-output-handler/inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md
```

</details>

Final artifact verification (exit 0):

```powershell
@'
root <- "C:/Users/maxth/ledgr-wt/ws1-output-handler"
p <- file.path(root,"inst/design/ledgr_v0_2_3_spec_packet/ws1_phase_a_review.md")
x <- readLines(p,encoding="UTF-8",warn=FALSE)
stopifnot(identical(x[[1L]],"Verdict: CHANGES_REQUIRED"),all(validUTF8(x)),length(grep("^### F[1-4] - P[12]:",x))==4L)
cat("Review verified:",length(x),"lines; UTF-8 valid; four ranked required findings.\n")
'@ | Rscript --vanilla -
```

Final workspace check (exit 0):

```powershell
git -C C:/Users/maxth/ledgr-wt/ws1-output-handler --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler --work-tree=C:/Users/maxth/ledgr-wt/ws1-output-handler status --short
```


