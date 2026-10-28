Verdict: PASS_AFTER_PATCHES

Independent cut re-review, combined Type 1 and Type 2, 2026-10-28. Reviewed revision 2 of `inst/design/ledgr_v0_2_3_spec_packet/tickets.yml`, SHA-256 `a88da44015d792228f7c4664691e5f52dfbe5d38ed31ab67988d73f161de466a`. HEAD read during this review was `26f471ed0b84663aa7fabf88c3923d8b2858b600` on `release/v0.2.3`. Its committed differences from the cut's cited `5bd52cda` are M4 evidence/brief files, with no change to the reviewed execution code. Below, `tickets.yml:N` means the v0.2.3 packet's file.

This is the right WS1 cut. Apply required patches P1 and P2 below before accepting it; no further cut review is needed for those exact patches. They tighten evidence requirements without changing the design or ticket sequence. Revision 2 resolves F1, F3, F4, F5 and F7. F2 and F6 are substantially addressed but are not fully resolved as written.

## Required findings, ranked by severity

### P1 - P2 severity: F6 still permits public worker output to stand in for native-buffer evidence

**Evidence:** `tickets.yml:99-100`; prior `cut_review_1.md`, F6; `tests/testthat/test-availability-parity.R:554-581`; `dev/bench/v0_2_3_output_freeze/closeout.md`, "Open points for the WS1 cut", points 1 and 5; `dev/bench/v0_2_3_output_freeze/guts.R:85-91`; `R/sweep.R:1884-1920`.

The revised retirement map correctly covers every test block and matching replacement inputs/assertions. The remaining worker condition is weaker than the previous required change: "if no existing test executes the memory sink inside a worker, add one." An existing test already does that: "parallel availability sweeps return the same compact terminal evidence" runs with two workers, but asserts status, completion JSON and candidate IDs. Naming that test satisfies the revised acceptance without observing daemon-native event buffers.

**Failure scenario:** a worker-specific defect changes an event ID or typed event column while inline summary and compact completion remain correct. A0 observes native buffers only in-process; its two-worker lanes and the existing compact-evidence test do not inspect these columns. The cut can satisfy the literal worker gate without covering the missing surface. A private-environment R probe of the real memory handler confirmed that altering a native event ID changes event rows while leaving `completion()` identical. This was an in-process demonstration of the observation gap, not a daemon test.

**Exact required patch:** replace LDG-3131's worker scope sentence with:

> For worker-side evidence, require a named test that executes the production memory sink in a separate worker process and checks its native event columns and typed attributes, retained diagnostics and numbering, and completion against the same declared inputs in-process. Identify the worker execution and the asserted surfaces. Existing tests of public sweep rows or compact completion alone do not satisfy this requirement; add a focused worker test if no existing test covers these native surfaces. Demonstrate that changing a daemon-native event ID fails this witness even when public status and completion remain unchanged.

Replace its worker acceptance with:

> The named worker-executed native-buffer witness covers those surfaces and detects the daemon-native event-ID corruption; a skip is missing evidence.

Keep the existing recovery tests, in-process growth witness, claim-level coverage map and nonzero-fill semantic-equivalence witness. LDG-3132 already rejects a skip of the required worker witness; that requirement then attaches to a concrete surface.

### P2 - P2 severity: F2's new universal staging-mutant requirement is impossible for unrelated source assertions

**Evidence:** `tickets.yml:11,90`; `tests/testthat/test-ledger-writer.R:206-210,293-307`; `tests/testthat/test-corporate-action-recovery.R:202-207`.

The expanded migration allowance correctly includes captures, mocks, inspected owners and the export pin. But decision (5) says a relocated structural assertion must fail on an offending staging assignment, and LDG-3130 strengthens this to **each** relocated structural assertion. Only LTB-0188's staging predicates test that property. The diagnostic assertion rejects `MAX(diagnostic_seq)`; the memory-failure assertion rejects transaction/recovery operations. A staging assignment does not match either predicate.

**Failure scenario:** a correct relocation preserves both assertions and their original claims, yet cannot demonstrate their failure on a staging assignment. Alternatively, an implementer edits their predicates to meet the new acceptance, violating the promise to preserve their oracles. The R predicate probe returned TRUE for detection of `state$pulse_fill_rows`-style staging storage using the actual `state\\$pulse_fill_rows` predicate, and FALSE for both unrelated predicates. The actual probe string was `state$pulse_fill_rows[[i]] <- row`; no test file was changed.

**Exact required patch:** replace the structural-demonstration sentence in decision (5) with:

> Each relocated structural assertion inspects the new owner of the operation and retains its original predicate and semantic claim. Demonstrate failure with a violation appropriate to that predicate: environment-held staging assignment for LTB-0188's forbidden-storage checks, loss of the required local staging write for its positive checks, a forbidden MAX(diagnostic_seq) query in the diagnostic owner, and a forbidden transaction/recovery operation in the memory owner. State owner relocation as the test-change reason; preserve fixtures, fault locations, expected conditions, numeric oracles and allocation bounds.

In LDG-3130's acceptance, replace "each relocated structural assertion is shown to fail on an offending staging assignment" with "each relocated structural assertion is shown to fail on a violation of its own original predicate, as specified in decision (5)." These are demonstrations against inspected source, not permission to alter registered product-test oracles.

## Verification of the previous findings

| Prior finding | Revision 2 disposition |
| --- | --- |
| F1: A0 adaptation too narrow | Resolved by `tickets.yml:11,69,89-90`. Both persistent corruption attachments and the memory observation/mutation adapter may migrate; identities, injected changes, expected differences, control, canonicalization, fixtures and records remain fixed. The close review reruns check and gut. No constructor alias is allowed. |
| F2: constructor-only test migration impossible | Migration allowance and census resolved at `:10-11,89-90`. Captures/mocks, inspected owners and export pin are included. The universal staging-mutant wording remains incorrect; P2 completes the resolution. |
| F3: stale pre-R3 verification | Resolved at `:109-110`, with final candidate digest, full tests/check, A0/gut, reference inventory and bindings comparison after product/test changes; required recovery/worker skips are missing evidence. Identity axes and release classes are explicit at `:11`. |
| F4: incomplete timing protocol | Resolved at `:59-60,109-110`. At least five alternating fresh-process pairs, matched warmup/snapshot policy, complete frozen matrix, full-precision seconds, ratio of medians, host/toolchain/tree identity, invalid-row rejection, missing-row/over-bound demonstrations and no automatic retries are bound before handler changes. Every cell must meet 1.03 or have a linked maintainer exception. |
| F5: R3 after its trigger and unscoped | Resolved at `:12,69-80,88`. The ticket IDs have been reassigned rather than reordered: LDG-3129 now owns R3 on current handlers; LDG-3130 replaces them afterward. Publication scope, unchanged planner/state/compiled arithmetic, leg-fee projection, contract disposition and focused writer tests are explicit. |
| F6: retirement by name | Claim-level inventory/replacements and nonzero-fill equivalence resolved at `:99-100`. Recovery/growth tests are explicitly retained and growth is correctly described as in-process. Worker native-buffer coverage remains unbound; P1 completes the resolution. |
| F7: capability-sensitive consumer omitted | Resolved at `:10,69-70,89-90`. The compiled guard is mapped, capability existence/return/side effects/failure are specified, unsupported callable stubs are forbidden, and buffered-DuckDB rejection plus positive memory/live-refusal tests are required. Minor citation corrections are listed under Optional. |

This verifies the revised brief, not future implementation evidence.

## Fresh assessment of the whole cut

**Boundary and grain.** The shared seam is supported by actual duplication: event column allocation/growth, pulse staging and flush order, diagnostic numbering and lifecycle bookkeeping. DuckDB owns transactions/interrupt reraising, durable and immediate writes, diagnostic sequence seeding/rollback refresh, telemetry and strategy-state persistence (`R/backtest-runner.R:280-350,471-595`). Memory owns typed metadata and inline equity/accounting projections, compiled append and summary diagnostic retention (`R/sweep.R:2091-2137,2188-2260,2396-2599`). These differences fit sinks/projections without a second fold core.

The method/capability map is necessary: identical method names do not imply identical retention, return or failure behavior. For example, buffer initialization resets persistent pending storage but preserves memory opening rows (`R/backtest-runner.R:396-410`; `R/sweep.R:2155-2163`). Shared bookkeeping must respect those differences. Existing required memory methods intentionally discard telemetry/state writes; preserving that documented discard policy is different from adding an unsupported optional compiled capability. The latter must remain absent on DuckDB.

The seven-ticket order is now honest: activation, frozen timing baseline, boundary/contract decision, R3, handler replacement, justified retirement, final verification/timing. R3 is independently implementable on current handlers and supplies the replacement; it no longer follows its own trigger. The replacement remains one large coherent ticket because separate sink implementations would risk preserving the duplicate mechanisms. Activation/design preparation do not need separate workstreams.

**R3 and contracts.** The publication formulas at `R/backtest-runner.R:132-137` and `R/ledger-writer.R:73-78` use the same arithmetic order. One canonical helper can serve buffered/memory payload construction and live writing without changing bytes. Memory can consume it through the payload builder; "all consumers call it" should not be implemented as a second calculation of the same fill. The live writer's earlier validation, NO_OP short circuit, event sequence selection and transaction behavior must stay intact (`R/ledger-writer.R:1-71,96-165`).

Leg fees already use `ledgr_fill_leg_fees()` (`R/lot-accounting.R:124-138`); the ticket should name and preserve that projection rather than invent new allocation arithmetic. Planner affordability and fold state deltas are explicitly outside this computation's scope. The narrow row-materialization clarification offered by LDG-3128 is consistent with synthesis Sections 5.6/11; it cannot relax the prohibition on resolving/reinterpreting economics in handlers under `contract-execution-accounting-events`. Choosing its exact sentence before implementation is an adequate manual design gate.

**Scope and decisions.** A0 identity is the correct oracle. Keeping the INCOMPLETE annualized-return difference until macro WS7 is sound: this cut does not merge result readers, and the future NA choice remains a recommendation. Diagnostic retention and the other recorded differences remain intentional sink/wording differences. The three identity impacts of none are plausible, with final bindings and A0 hashes/config/provenance evidence required; unchanged constants alone would not prove them. No old constructor alias, format migration or compatibility reader is justified. Historical experiments remain evidence; maintained A0 and the active peer benchmark migrate.

The brief authorizes no new execution-mode branch and preserves `contract-execution-fold-core`. Its no-new-element-loop requirement and seven-shape review cover moved sinks/projections as well as the shared constructor. Existing per-event metadata work must not be multiplied by making every sink construct every representation. Full tests/check, NEWS and measured performance evidence make this cut release-ready without pulling WS4, WS7 or WS8 into it.

**Timing.** Alternating base/candidate public-path measurements on the registered i9 host, High performance and inherited 0xFFFF affinity, are appropriate. A0's old rounded seconds and unpinned host are descriptive only. LDG-3127 must commit the actual larger workload, clock endpoints, retained surface and expected completion states before edits, not leave placeholders in the executable protocol. Its early baseline supports H6; LDG-3132 must measure the base again alongside the final candidate to supply the paired gate. A 3% per-cell no-regression threshold is demanding on small fixtures but valid with the declared protocol and explicit per-cell exceptions. It does not prove the roadmap's aspirational claim of closing "most" of H6.

## Can every gate fail?

| Ticket | Failure-sensitive gate and limitation |
| --- | --- |
| LDG-3126 | Reverting either default must fail its new regression test. A clean planned-ticket structural scan alone is vacuous as activation evidence: the current scan already returns zero findings. The draft now also requires the default-path witness. The RFC next-stage entry is a routing record, not acceptance of its future design. |
| LDG-3127 | Frozen protocol/commit chronology and complete raw records are inspectable. The checker must reject missing measurements and a ratio above 1.03 in demonstrations, in addition to the listed validity checks. |
| LDG-3128 | The design map and contract sentence are manual gates, intentionally prose. They fail on missing methods/consumers, false capability declarations or unresolved ownership. They are preparation, not proof of product parity. |
| LDG-3129 | A0 byte comparison and control/17 guts are executable. Focused BUY/SELL/fee/NO_OP and writer tests must detect perturbing the shared computation. Single ownership/contract agreement also require source review. |
| LDG-3130 | A0, bindings, negative dispatch and reference inventory can fail. Shared ownership needs source review; constructor deletion alone cannot reject a facade over duplicated sinks. Apply P2 to make all source-assertion demonstrations meaningful. |
| LDG-3131 | Every retired claim requires matching inputs and exact assertions/tables; a replacement name cannot pass. Nonzero fills prevent trivial equivalence. Apply P1 so existing public worker status/completion coverage cannot satisfy the native-buffer obligation. |
| LDG-3132 | Final-tree command exits, required-witness execution, identity evidence and every timing cell bind closure. Earlier evidence can be reused only for unchanged inputs; earlier timing cannot replace final paired measurements. |

## Source-table fact check

The R census independently confirmed 21 persistent and 27 memory methods, 19 shared, two persistent-only (`terminal_status_written`, `set_schedule_counts`) and eight memory-only (`append_compiled_spot_batch`, `record_accounting_fact`, `record_equity_fact`, `inline_summary`, `completion`, `diagnostics`, `typed_events`, `events`). The fold references 17 distinct members; that is a reference census, not a universal shared-method interface.

Direct constructor calls are two in R, 38 in tests (14/9/7/6/2 in the five named files), and one at the active peer benchmark's line 702. Factory captures, mocks, source inspections and the export pin are correctly identified. Both constructor ranges (252-599 and 1982-2603), construction sites (793 and 1706), payload definition (103), fold entry (1573), guarded fact calls (584/1370), sweep optional summary/typed calls (1884-1891), direct completion/diagnostic calls (1919-1920), formula locations and governance defaults (1445/1583) agree with the source.

A0 declares eight workloads (`fixtures.R:250-267`) and 17 corruptions. The named persistent patches and memory state access are real. The 1.47 ratio is correctly attributed to the recorded descriptive 20x252 timing, not a new measurement. The three parity files contain 26 test blocks (6/5/15), including substantive claims beyond handler equality.

## Optional

- Correct `tickets.yml:10`: `R/compiled-spot-fifo.R:54-83` is the complete guard function; `R/fold-engine.R:1668-1669` selects/calls the **dispatch guard**, while `:1336` calls `append_compiled_spot_batch`. The admission policy and negative test requirements are already correct.
- When the cut is accepted, update the design front door's stale "no macro plan yet" statement (`inst/design/README.md:43` vicinity) through the normal planning upkeep. It is not authority to override the accepted macro plan.
- Keep timing, coverage map and final verification evidence in one location each; the short disposition should link them.

## Verification limits and workspace

Used read-only source inspection, YAML parsing, a source/method census, the planned-ticket structural scanner and private-environment R probes. No A0 workloads, full test suite, worker daemons, timings, build or package check were run; this review does not certify their future results. The native-buffer probe used a hand-built write-result input to exercise the actual handler, not a new product oracle or changed fixture. R 4.6.1 emitted locale startup warnings.

The workspace had unrelated generated binding changes and RFC/peer-suite work. Those files were neither edited nor reverted. The peer_suite_seed contents were ignored. Only this review file was written; no commit was made.

## Commands and exit codes

Each entry is one shell invocation. PowerShell pipelines below are single commands. Tool-based creation/verification of this review is not a shell invocation. The initial three reads preceded the automated command log and are included explicitly.

1. Exit 0.

```powershell
Get-Content -LiteralPath 'C:\Users\maxth\Documents\GitHub\ledgr\AGENTS.md'
```

2. Exit 0.

```powershell
git -C C:/Users/maxth/Documents/GitHub/ledgr status --short --branch
```

3. Exit 0.

```powershell
Get-Content -LiteralPath 'C:\Users\maxth\Documents\GitHub\ledgr\inst\design\ledgr_v0_2_3_spec_packet\cut_review_1.md'
```

4. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml
```

5. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/cut_review_1.md -TotalCount 115
```

6. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md
```

7. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/closeout.md
```

8. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml | Select-Object -Skip 90
```

9. Exit 0.

```powershell
rg -n -A 18 -B 4 'One output handler|\| C6 |\| H6 |\| R3 ' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_roadmap.md C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/inventory_reconciliation.md
```

10. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_2_spec_packet/tickets.yml -TotalCount 105
```

11. Exit 0.

```powershell
rg -n -A 43 -B 3 '^### 5\.6|^## 11|contract-execution-fold-core|contract-execution-accounting-events' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md C:/Users/maxth/Documents/GitHub/ledgr/inst/design/contracts.md
```

12. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/manual/optimization_coding_style.qmd -TotalCount 270
```

13. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/README.md -TotalCount 80
```

14. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_2_spec_packet/tickets.yml -TotalCount 72
```

15. Exit 0.

```powershell
rg -n -A 33 -B 2 '^### 5\.6|^## 11|contract-execution-fold-core|contract-execution-accounting-events' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md C:/Users/maxth/Documents/GitHub/ledgr/inst/design/contracts.md
```

16. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R -TotalCount 600
```

17. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R | Select-Object -Skip 1981 -First 624
```

18. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/ledger-writer.R -TotalCount 210
```

19. Exit 0.

```powershell
rg -n -A 6 -B 4 'ledgr_memory_output_handler|output_handler\$|handler\$inline_summary|handler\$typed_events' C:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R
```

20. Exit 0.

```powershell
rg -n -A 5 -B 4 'output_handler\$|ledgr_execute_fold <-' C:/Users/maxth/Documents/GitHub/ledgr/R/fold-engine.R
```

21. Exit 0.

```powershell
rg -n 'ledgr_(persistent|memory)_output_handler|current_packet = ' C:/Users/maxth/Documents/GitHub/ledgr/R C:/Users/maxth/Documents/GitHub/ledgr/tests C:/Users/maxth/Documents/GitHub/ledgr/tools/governance-report.R C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/peer_benchmark/peer_benchmark.R
```

22. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-ledger-writer.R | Select-Object -Skip 195 -First 142
```

23. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-availability-parity.R | Select-Object -Skip 270 -First 135
```

24. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-corporate-action-recovery.R | Select-Object -Skip 140 -First 83
```

25. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-sweep-persistence-parity.R -TotalCount 265
```

26. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/timing.R
```

27. Exit 0.

```powershell
rg -n -A 10 -B 3 '\| R3 |fold-execution-phase-ownership|documentation-roles-pin-reset' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/inventory_reconciliation.md C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc/README.md
```

28. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/manual/benchmark_methodology.qmd | Select-Object -Skip 135 -First 95
```

29. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/compiled-spot-fifo.R -TotalCount 90
```

30. Exit 0.

```powershell
rg -n -A 18 -B 3 'worker|mirai' C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-availability-parity.R
```

31. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/lib.R | Select-Object -Skip 323 -First 134
```

32. Exit 0.

```powershell
rg -n '^ledgr_(event_buffer_checked_capacity|fill_row_buffer|fill_leg_fees)|^`%\|\|%`' C:/Users/maxth/Documents/GitHub/ledgr/R
```

33. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/guts.R -TotalCount 140
```

34. Exit 0.

```powershell
rg -n -A 16 -B 3 'record rule|record-rule|Findings|finding-bearing|Pre-CRAN' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc_cycle.md
```

35. Exit 0.

```powershell
Get-ChildItem -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet -Filter 'cut_review_1*' | Select-Object -ExpandProperty Name
```

36. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tools/governance-report.R | Select-Object -Skip 1438 -First 40
```

37. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc_cycle.md -TotalCount 112
```

38. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml | ForEach-Object -Begin { $line = 0 } -Process { $line++; '{0}: {1}' -f $line, $_ }
```

39. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-sweep.R -TotalCount 215
```

40. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/Documents/GitHub/ledgr"
cat(R.version.string, "\n")
e <- new.env(parent = globalenv())
for (f in c("backtest-runner.R", "sweep.R", "compiled-spot-fifo.R")) sys.source(file.path(root, "R", f), e)
methods <- function(fn) {
  lines <- deparse(body(fn))
  sort(unique(sub("[[:space:]]*<-$", "", unlist(regmatches(lines, gregexpr("handler[$][A-Za-z_]+[[:space:]]*<-", lines))))))
}
p <- methods(e$ledgr_persistent_output_handler); m <- methods(e$ledgr_memory_output_handler)
cat("Method counts persistent / memory / shared:", length(p), length(m), length(intersect(p,m)), "\n")
cat("Persistent only:", setdiff(p,m), "\nMemory only:", setdiff(m,p), "\n")
files <- list.files(file.path(root, "tests/testthat"), pattern = "[.]R$", full.names = TRUE)
n <- vapply(files, function(f) sum(grepl("ledgr_(persistent|memory)_output_handler[[:space:]]*[(]", readLines(f, warn=FALSE))), integer(1))
print(n[n > 0]); cat("Direct calls in tests:", sum(n), "\n")
fold <- readLines(file.path(root,"R/fold-engine.R"))
refs <- sort(unique(unlist(regmatches(fold, gregexpr("output_handler[$][A-Za-z_]+", fold)))))
cat("Fold handler members:", length(refs), "\n"); print(refs)
parsed <- parse(file.path(root,"R/compiled-spot-fifo.R"), keep.source=TRUE)
i <- which(vapply(parsed,function(x) is.call(x) && identical(x[[2]], as.name("ledgr_require_compiled_spot_fifo_dispatch")),logical(1)))
print(attr(parsed,"srcref")[[i]])
g <- new.env(parent=globalenv()); sys.source(file.path(root,"dev/bench/v0_2_3_output_freeze/guts.R"), g)
cat("Corruptions:",length(g$a0_guts),"\n")
t <- yaml::read_yaml(file.path(root,"inst/design/ledgr_v0_2_3_spec_packet/tickets.yml"))
cat("Ticket ids:",vapply(t$tickets, `[[`, character(1), "id"),"\n")
gov <- new.env(parent=globalenv()); sys.source(file.path(root,"tools/governance-report.R"),gov)
findings <- gov$governance_scan_ticket_evidence(root,"inst/design/ledgr_v0_2_3_spec_packet")
cat("Planned-ticket structural findings:",nrow(findings),"\n")
stopifnot(length(p)==21L,length(m)==27L,length(intersect(p,m))==19L,sum(n)==38L,length(refs)==17L,length(g$a0_guts)==17L)
'@ | Rscript --vanilla -
```

41. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R | Select-Object -Skip 780 -First 32
```

42. Exit 1.

```powershell
rg -n -A 4 -B 3 'skip|profile|LEDGR_TEST' C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/helper*.R C:/Users/maxth/Documents/GitHub/ledgr/tools/run-test-profile.R
```

43. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/fold-engine.R | Select-Object -Skip 1656 -First 20
```

44. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/lot-accounting.R | Select-Object -Skip 118 -First 30
```

45. Exit 0.

```powershell
git -C C:/Users/maxth/Documents/GitHub/ledgr rev-parse HEAD
```

46. Exit 0.

```powershell
git -C C:/Users/maxth/Documents/GitHub/ledgr diff 5bd52cda HEAD --stat
```

47. Exit 0.

```powershell
git -C C:/Users/maxth/Documents/GitHub/ledgr log -4 --oneline
```

48. Exit 0.

```powershell
rg -n -g 'helper*.R' 'skip|profile|LEDGR_TEST' C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat
```

49. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/fold-event-buffer.R -TotalCount 95
```

50. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/fold-reconstruction.R -TotalCount 45
```

51. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/Documents/GitHub/ledgr"
e <- new.env(parent=globalenv())
e$`%||%` <- function(x,y) if(is.null(x)) y else x
for (f in c("fold-event-buffer.R","fold-reconstruction.R","sweep.R")) sys.source(file.path(root,"R",f),e)
h <- e$ledgr_memory_output_handler("native-probe", .event_initial_capacity=1L)
h$init_buffers(1L)
row <- list(event_id="native-probe_00000001",run_id="native-probe",ts_utc=as.POSIXct("2020-01-02",tz="UTC"),event_type="FILL",instrument_id="AAA",side="BUY",qty=1,price=100,fee=1,meta_json="{}",event_seq=1L)
res <- structure(list(status="WROTE",row=row,cash_delta=-101,position_delta=1,meta=list(fee=1,cash_delta=-101,position_delta=1,realized_pnl=NULL)),class="ledgr_ledger_write_result")
h$buffer_event(res)
h$write_run_evidence(data.frame(status="INCOMPLETE"),NULL)
before <- h$typed_events(); completion_before <- h$completion()
state <- get("state",envir=environment(h$events))
e$ledgr_event_buffer_setv(state$event_cols,"event_id",1L,"corrupted-worker-event")
after <- h$typed_events()
stopifnot(!identical(before$event_id,after$event_id),identical(completion_before,h$completion()))
cat("Native event_id corruption changes event rows while completion is identical: TRUE\n")
staging <- "state$pulse_fill_rows[[i]] <- row"
cat("Staging mutant detected by staging predicate:",grepl("state\\$pulse_fill_rows",staging),"\n")
cat("Staging mutant detected by MAX predicate:",grepl("MAX\\(diagnostic_seq\\)",staging),"\n")
cat("Staging mutant detected by transaction predicate:",grepl("begin_transaction|commit_transaction|rollback|reopen",staging,perl=TRUE),"\n")
p <- parse(file.path(root,"R/compiled-spot-fifo.R"),keep.source=TRUE)
i <- which(vapply(p,function(x) is.call(x) && identical(x[[2]],as.name("ledgr_require_compiled_spot_fifo_dispatch")),logical(1)))
cat("Compiled dispatch function first/last line:",as.integer(attr(p,"srcref")[[i]])[c(1,3)],"\n")
'@ | Rscript --vanilla -
```

52. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/fold-engine.R | Select-Object -Skip 1377 -First 43
```

53. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/availability-economics.R | Select-Object -Skip 320 -First 34
```

54. Exit 0.

```powershell
rg -n '^testthat::test_that|^test_that' C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-sweep-parity.R C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-sweep-persistence-parity.R C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-availability-parity.R
```

55. Exit 0.

```powershell
rg -n '^a0_workloads|^  [a-z_]+ = list|^ledgr_fill_event_payload|^ledgr_persistent_output_handler|^ledgr_memory_output_handler|^governance_report|current_packet = ' C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/fixtures.R C:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R C:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R C:/Users/maxth/Documents/GitHub/ledgr/tools/governance-report.R
```

56. Exit 0.

```powershell
git -C C:/Users/maxth/Documents/GitHub/ledgr diff -- R/backtest-runner.R R/sweep.R R/fold-engine.R R/ledger-writer.R R/compiled-spot-fifo.R tools/governance-report.R tests
```

57. Exit 0.

```powershell
rg -n 'MAX\\|handler_source|pulse_fill_rows|pulse_fill_legs|begin_transaction\|commit_transaction|terminal_status_written|state\$completion|record_run_status|write_telemetry <-|buffer_strategy_state <-' C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-ledger-writer.R C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-corporate-action-recovery.R C:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R
```

58. Exit 0.

```powershell
Get-ChildItem -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet -Filter 'cut_review_1*' | Select-Object -ExpandProperty Name
```

59. Exit 0.

```powershell
git -C C:/Users/maxth/Documents/GitHub/ledgr status --short --branch
```

60. Exit 0.

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml
```

61. Exit 0. Final read-only verification; appended to this log afterward.

```powershell
@'
root <- "C:/Users/maxth/Documents/GitHub/ledgr"
f <- file.path(root,"inst/design/ledgr_v0_2_3_spec_packet/cut_review_1_rereview_1.md")
x <- readLines(f,encoding="UTF-8",warn=FALSE)
stopifnot(identical(x[[1]],"Verdict: PASS_AFTER_PATCHES"),all(validUTF8(x)),any(grepl("## Commands and exit codes",x,fixed=TRUE)))
hash <- digest::digest(file=file.path(root,"inst/design/ledgr_v0_2_3_spec_packet/tickets.yml"),algo="sha256")
stopifnot(identical(hash,"a88da44015d792228f7c4664691e5f52dfbe5d38ed31ab67988d73f161de466a"))
cat("Review exists, verdict/UTF-8/command log valid; reviewed tickets unchanged.\n")
'@ | Rscript --vanilla -
```

