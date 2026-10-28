Verdict: CHANGES_REQUIRED

Independent cut review, combined Type 1 and Type 2, 2026-10-28. Reviewed the uncommitted cut at HEAD `5bd52cda8f0e532fbdc232dc3e3d9c33dafaa403` on `release/v0.2.3`. Line references to `tickets.yml` below mean `inst/design/ledgr_v0_2_3_spec_packet/tickets.yml`.

The right workstream is cut: the accepted macro plan explicitly puts C6 and R3 together, before execution-core consolidation, with A0 byte identity and H6 remeasurement. A shared handler with DuckDB and memory sinks is a sound seam. The draft is not executable as written: two migration restrictions conflict with its deletion and test gates, and the final cut can inherit verification from an earlier product tree. Timing and retirement gates also need stronger definitions. No production change is authorized by this review.

## Required findings, ranked by severity

### F1 - P1: The allowed A0 adaptation cannot preserve the required gut gate

**Evidence:** `tickets.yml:10,78-79`; `dev/bench/v0_2_3_output_freeze/guts.R:78,109`; `dev/bench/v0_2_3_output_freeze/lib.R:334-344,448`; `dev/bench/v0_2_3_output_freeze/gut.R:39-59`.

The cut deletes the persistent constructor but permits changing only `a0_observe_memory()`. Two corruptions, `interrupted_telemetry` and `wf_warning`, patch `ledgr_persistent_output_handler` directly. `a0_with_patches()` resolves that binding before running their expression. Adapting the memory observer cannot repair these later persistent-path patches.

**Failure scenario:** after a correct constructor deletion, these corruptions stop with “object 'ledgr_persistent_output_handler' not found,” rather than reaching their telemetry/warning corruption. The gut runner requires the named table difference, so it fails. I reproduced that lookup failure by evaluating the actual patch helper and both actual corruption definitions against a private environment with the constructor removed. No package file or namespace was modified.

The memory corruptions also depend on representation: `guts.R:11,88-100` reaches `state` through `environment(handler$events)`, then edits `event_cols` and diagnostic parts. Their attachment point must follow the new ownership.

**Exact required change:** expand the explicitly allowed harness migration to the two persistent corruption attachment points and the memory-state observation/mutation adapter, as well as the memory factory observer. Preserve the 17 corruption identities, injected changes, expected tables/messages, control requirement, canonicalization, fixtures and recorded bytes. Require proof that each corruption reaches and alters its intended raw product surface. Require `gut.R` exit 0, including its control and named-difference checks. Do not retain old constructor aliases to make the harness work.

### F2 - P1: “Constructor calls only” excludes necessary test migrations

**Evidence:** `tickets.yml:9-10,78-79`; `tests/testthat/test-ledger-writer.R:207,293-307`; `tests/testthat/test-risk-fold.R:412-458`; `tests/testthat/test-availability-economics.R:1066-1086`; `tests/testthat/test-corporate-action-recovery.R:157-160,202-207`; `tests/testthat/test-api-exports.R:199`.

The tests do more than call constructors. They retain factory function objects, replace namespace bindings for fault injection, inspect constructor bodies, and assert export visibility. LTB-0188 explicitly inspects both old bodies for staging-buffer assignment shapes. These references cannot all disappear through edits to constructor calls.

The direct-call census is also wrong: there are **38**, not 37, in tests: **14** in test-ledger-writer.R, 9 in test-risk-fold.R, 7 in test-sweep.R, 6 in test-execution-spec.R and 2 in test-research-cycle-scale.R. This census excludes the additional non-call references above.

**Failure scenario:** keeping the promised diff restriction leaves missing-symbol failures. Broadening edits informally violates the accepted ticket evidence. Repointing every body inspection at a thin common constructor can also make negative source checks pass vacuously while the offending operation has moved into a sink.

**Exact required change:** replace “constructor calls/line only” with an enumerated migration allowance: constructor invocations and arguments, factory captures and mocked-binding names, inspected implementation owners, and the private-export pin. Name the affected tests, including the two omitted files above. Preserve fixtures, fault locations, expected conditions, numeric oracles and allocation bounds. For structural source assertions, inspect the new owner of the operation and demonstrate that an offending staging assignment still fails the detector; state that relocation as the test-change reason. Update the close-review diff rule accordingly, and correct the census.

### F3 - P1: The final candidate can pass using pre-R3 package checks

**Evidence:** `tickets.yml:79,87-89,97-99,107-109`; `AGENTS.md:141-149` (ticket verification workflow); `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md:35-46` (identity and release-impact declarations).

Full tests, package check and store bindings are accepted in LDG-3129. LDG-3130 then changes production fill publication/writing, and LDG-3131 removes tests. LDG-3132 requires only earlier acceptance evidence plus timing. The close-review text reruns A0 and guts, but does not require final-tree full tests/package check.

**Failure scenario:** R3 breaks a writer validation or transaction case outside A0, while A0 and timing pass. LDG-3129's earlier check remains valid evidence for that ticket and the cut can close without testing the broken final tree.

**Exact required change:** LDG-3132 must require full package tests, `R CMD check --no-manual --no-build-vignettes`, A0 check and gut, constructor/reference inventory, and identity/binding comparison on the final candidate after all product and test changes. Record its SHA or exact source digest and commands. Explicitly declare all three identity axes and the cut's release-impact classes, as described below. Earlier evidence may be reused only when its declared inputs are unchanged; an R3 product change invalidates the earlier relevant checks. Treat skips of specifically required recovery/worker witnesses as missing evidence.

### F4 - P1: A 1.03 timing bound has no complete measurement or rejection protocol

**Evidence:** `tickets.yml:58-59,108-109`; `dev/bench/v0_2_3_output_freeze/timing.R:1-8,65-98`; `inst/design/manual/benchmark_methodology.qmd:168-194`.

Alternating live base/candidate arms on the registered host is appropriate. A0's stored seconds are explicitly descriptive, and its existing script alternates run/sweep inside one tree, defaults to three repetitions, and rounds recorded seconds to two decimals. The cut calls for a new comparison runner but does not bind repetitions, process isolation, warmup, clock endpoints, precision, completeness, or a retry rule. At the smallest A0 shapes a few milliseconds are already several percent.

**Failure scenario:** one favorable repetition, inconsistent warm states, omitted workload/path rows, or rounded medians can produce an apparent pass. The listed acceptance merely requires the bound to be “evaluated”; a record showing a miss could meet it without recording the required exception. An empty result set can satisfy a naive all-ratios check.

**Exact required change:** before any candidate timing, LDG-3127 must freeze the complete workload/path matrix (including the larger shape), inputs, seeds, candidate counts, retained result surface and clock endpoints. Use at least five alternating base/candidate pairs in fresh processes, with an identical declared untimed warmup and warm-snapshot policy in each arm; retain full-precision raw seconds and compute the stated ratio of medians. Verify actual inherited power plan/affinity and identify both source trees and toolchain. Reject missing, duplicate, non-finite or non-positive measurements, failed/incomplete executions where completion is expected, and unexpected skips. Add a checker with demonstrated failures for a missing row and a ratio above 1.03. Specify no automatic retries, or a fixed retry/disposition rule before measuring. LDG-3132 passes only when every required path/workload ratio is <= 1.03 or has an explicit, linked maintainer exception for that cell.

The 3% threshold is reasonable as a local no-regression target, subject to this protocol and explicit exceptions. It is not evidence of closing “most” of H6; the accepted macro gate wisely requires remeasurement, not a promised speedup.

### F5 - P2: R3 ownership starts after the first triggering edit and leaves its scope ambiguous

**Evidence:** `tickets.yml:68,78,87-89`; `inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md:324-345,493-504`; `inst/design/rfc/README.md:109`; `inst/design/contracts.md:344-351`.

The synthesis assigns R3 to the first ticket editing `write_fill_events` or `ledgr_fill_event_payload`. LDG-3129 replaces both handlers, including their `write_fill_events` methods, but R3 is deferred to its dependent LDG-3130. The earlier boundary note does not settle the contract disposition.

“One function” also needs a scope: the publication duplicates are at `R/backtest-runner.R:132-137` and `R/ledger-writer.R:73-78`; independent planning/state arithmetic remains at `R/availability-economics.R:326-350` and `R/fold-engine.R:1382-1393`. Sharing one publication helper does not remove all arithmetic from the package. The compiled batch already supplies its own typed deltas.

**Failure scenario:** handler replacement lands while the triggered obligation is still unowned at the edit, or a common helper called from handlers is declared contract-compliant although the contract still forbids computing cash deltas there. Alternatively, “once” is interpreted as authority to widen this cut into planner/fold/compiled economics.

**Exact required change:** keep the implementation grain honest by putting R3 before handler replacement: LDG-3130 depends on LDG-3128, LDG-3129 depends on LDG-3130, and LDG-3131 depends on LDG-3129. Update the serial sequence. LDG-3128 must choose and state the R3 ownership/contract sentence before implementation. Bind one canonical computation for fill-row publication, shared by the current buffered, live and memory consumers; distinguish it from unchanged planner/state/compiled arithmetic. Name leg-fee allocation as projection of already resolved fee and lot quantities, preserving operation order and bytes. If choosing the permitted row-materialization clarification, explicitly preserve the prohibition on resolving/reinterpreting economics in handlers; do not offer an open-ended contract relaxation when code is inconvenient. Verify BUY, SELL, fees, NO_OP and the live writer's validation/transaction behavior in addition to A0. Close only the R3 portion of the pipeline row; its other future consumers remain open.

This obligation is achievable without changing A0 bytes: both publication formulas currently use the same arithmetic order. No numerical-rule or schema change is necessary.

### F6 - P2: Retirement can name a replacement that does not cover the retired claim

**Evidence:** `tickets.yml:98-99`; `tests/testthat/test-sweep-parity.R:203,300,364,410,449,513`; `tests/testthat/test-sweep-persistence-parity.R:192-259`; `tests/testthat/test-availability-parity.R:276,347,554-583`; `tests/testthat/test-ledger-writer.R:559-626`; `dev/bench/v0_2_3_output_freeze/closeout.md`, “Open points for the WS1 cut.”

These files contain promotion provenance, seeded reproduction, feature-factory warmup, metric-context, retained-series and completion/recovery claims, not just redundant handler equality. The retirement gate asks for a replacement name, not matching inputs and assertions. Its unnamed “worker-buffer” test is particularly unclear: test-ledger-writer.R:559 constructs both handlers in the current process; it launches no worker. The two-worker completion test compares public compact evidence, not daemon-native buffers.

**Failure scenario:** replacing a feature-factory/promotion assertion with the generic dense_cost record satisfies the table requirement while losing that guarantee. Retaining a single trivial semantic-equivalence test and deleting other distinct coverage also meets the literal acceptance.

**Exact required change:** require an inventory of every test block in the three files, retained or retired, with its distinct claims and the exact replacement assertions/record tables and matching input conditions for each retired claim. A name alone is insufficient. Keep promotion, reproduction-key, non-default metric context, candidate-varying features/warmup, retention and recovery claims unless equivalent coverage is identified. Name the worker evidence by test identifier and asserted surface. Either identify a real existing daemon-buffer witness, or explicitly require a new worker-executed sink test for the uncovered claim; do not describe the in-process growth test as one. Require the retained cross-sink equivalence witness to execute nonzero fills and compare event semantics, not only status or a zero-trade metric.

### F7 - P2: The boundary mapping omits a capability-sensitive consumer

**Evidence:** `tickets.yml:9,68-69`; `R/compiled-spot-fifo.R:54-82`; `R/fold-engine.R:1336,1668-1669`; `R/sweep.R:1884-1893,1919-1920`.

The compiled dispatch guard is a consumer outside the listed fold/run/sweep callers. It treats a callable `append_compiled_spot_batch` as support. The fold later calls that method directly. Likewise, sweep completion and diagnostics are direct calls, not optional guards. The source_table's blanket guarded-call statement is false.

**Failure scenario:** a uniform handler exposes callable no-op methods for every sink. The existing guard now admits a buffered DuckDB handler to a compiled path that it previously refused, even though no compiled-envelope expansion is authorized. A0's compiled lane uses memory and does not test this negative capability case. A read-only probe of the actual guard showed that an absent append method refuses, while a callable stub passes when the compiled symbol exists.

**Exact required change:** include `ledgr_require_compiled_spot_fifo_dispatch()` in the mapping and specify the availability, return value, side effects and failure behavior of capability methods for each sink. Preserve absent/non-callable compiled append support for DuckDB, or bind an equally strict existing-seam check without adding an execution-mode branch. Add a negative buffered-DuckDB compiled-dispatch test and retain the positive memory and live-mode refusal tests. Do not expose a callable unsupported no-op capability. Correct the source_table guard descriptions.

## Assessment of the proposed seam and decisions

The shared responsibilities are event columns, growth, pulse staging/order, diagnostic numbering policy application and lifecycle bookkeeping. Sink differences are real: DuckDB transactions and interrupt reraising, durable append/checkpoints, existing diagnostic-sequence seeding and post-rollback refresh, immediate live writes, state/telemetry persistence; memory retains typed metadata, accounting/equity projections and summary diagnostics. See `R/backtest-runner.R:280-291,471-504,537-595` and `R/sweep.R:1982-2603`. A single handler must share the duplicated mechanisms rather than rename two implementations as sinks. Inline metrics, typed attributes and leg fees are projections of fold facts; sinks must not re-resolve fills or mutate fold economics. Keeping those projections internal for WS1 does not require taking over WS7.

The existing difference in INCOMPLETE annualized_return can remain frozen and be routed to WS7. This is consistent with A0 and the accepted reader-merge scope; “NA” remains a recommendation for that future decision. The cut should say “one metric difference,” since A0 closeout also documents diagnostic-retention, failure-ID wording and compiled-assumption differences.

Identity impact “none” is plausible and appropriate. Explicitly record **snapshot content identity: none; run configuration identity: none; store format fingerprint: none**, as macro rule 5 requires. Preserve final A0 hashes/provenance and compare final store bindings. Unchanged version constants alone are not a general proof that no serialized payload or config identity changed. Also name macro rule 6's release-impact classes: product tests and performance records; NEWS/documentation as applicable, with no taught-behavior or dependency change.

Leaving historical spikes and frozen bench records untouched is correct; the active A0 corruption adapters and peer benchmark remain maintained execution consumers. No old-constructor alias, legacy reader, migration or fallback is justified.

The draft introduces no second fold core or new execution-mode branch. Its seven-shape close review and no-new-data-scale-loop requirement are appropriate. The implementation review must include moved sink/projection helpers, not just the common constructor. Existing per-event JSON/materialization loops must not be multiplied by making all sinks populate every representation.

The seven-ticket sequence has one coherent claim, but activation and the design note are prerequisites rather than independent product outcomes. They need no added workstream. Measurement before handler edits and parity retirement after proven replacements are right. R3's current placement needs F5; no additional engine-consolidation or result-reader ticket belongs in this cut.

## Can the acceptance gates fail?

| Ticket | Gate assessment |
| --- | --- |
| LDG-3126 | Default-path activation can fail by checking both report entry-point defaults; a clean structural report alone is not proof of activation. The present draft already returns zero ticket-evidence structural findings because its tickets are planned. An explicit default-path assertion would strengthen this gate (see Optional). Naming the RFC's next stage is a record gate, not completion of its Type 2 decision. |
| LDG-3127 | Baseline metadata/H6 arithmetic are inspectable; runner and record completeness need F4. Lock the runner before candidate measurement. |
| LDG-3128 | The mapping is a legitimate manual review gate, not product-parity evidence. It can fail on missing methods/consumers or wrong capability placement. Include F5/F7 and review actual implementation against the map. |
| LDG-3129 | A0 is a strong executable byte oracle; its corruption gate is currently incompatible with deletion (F1). Test migration is also incompatible (F2). Bindings equality is a useful format check, with the identity limits above. |
| LDG-3130 | A0 can fail on changed bytes, but cannot establish a single computation owner or a correct contract sentence. Inspect all publication callers; use the focused delta/writer witnesses in F5. |
| LDG-3131 | “Table exists,” “replacement named,” and “a parity test remains” can pass with lost coverage. F6 makes these claim-level checks. |
| LDG-3132 | The ratio can fail numerically only with complete admissible records and an enforced outcome (F4). Evidence from previous tickets is insufficient final-tree validation (F3). |

The identity/release-class declarations above belong in F3's final-candidate evidence.

## Verified source facts

- HEAD matches the draft's 5bd52cda. Handler ranges 252-599 and 1982-2603, construction sites 793 and 1706, payload line 103, fold entry 1573, and peer benchmark call 702 are correct.
- There are 17 distinct handler members referenced in fold-engine.R. This includes memory-only fact/compiled callbacks; it is not a 17-method interface shared in full by both constructors.
- The persistent constructor defines 21 methods, the memory constructor 27: 19 shared names, two persistent-only lifecycle/schedule methods, eight memory-only methods. The eight memory additions listed in the draft are correct.
- Direct constructor calls: two in R/, 38 in tests/, one in the active peer benchmark. The extra test references listed in F2 must also migrate.
- Guards at fold-engine.R:584 and :1370 and sweep.R:1884/:1890 are real. Compiled append is guarded by the dispatch validator in compiled-spot-fifo.R, then called directly; completion/diagnostics at sweep.R:1919-1920 are direct.
- Governance default locations 1445 and 1583 are correct.
- A0's recorded inventory has eight workloads and 17 corruption definitions. Its closeout reports 1.47 for the 20 x 252 timing row; these are descriptive recorded results, not timings independently rerun here.
- The recovery tests at availability-parity.R:276 and :347 and the growth test at ledger-writer.R:559 are correctly located. The latter does not verify worker execution.

## Optional

- Add an LDG-3126 default-path regression test for both report entry points: a malformed completed v0.2.3 ticket in a test fixture should be detected without a current_packet override.
- Merge activation and boundary-note chores into implementation preparation if the maintainer wants fewer ticket states. Do not split the shared handler into per-sink workstreams.
- Prefer ticket evidence plus one concise workstream disposition over duplicating all evidence in a long ws1_closeout essay. Preserve the retirement coverage map and empirical timing record once.
- A small source-level deletion/ownership witness can help catch a facade wrapping duplicated buffers. Human ownership review remains necessary.

## Verification limits and workspace

I used read-only source inspection and R 4.6.1 probes that source definitions into private environments. I did not run A0 workloads, the full test suite, timing, a package build or package check, and do not claim those gates pass. The probes made no disk or persistent-store changes. R emitted locale startup warnings. The first R command failed because PowerShell's native argument quoting removed R string quotes; the subsequent stdin here-string probes succeeded.

The workspace initially had modifications to R/cpp11.R and src/cpp11.cpp plus unrelated untracked files. By the final status read, another process had also changed rfc/README.md and added the peer-suite seed. Those changes were neither made nor reverted here. The peer_suite_seed directory was ignored. Only this review file was written; no commit was made.

## Commands and exit codes

The following log lists the exact shell commands executed, including read-only probes and unsuccessful commands. Long multi-line entries are single PowerShell commands. Tool-based creation of this review is not a shell command.

1. Exit 0.

```powershell
git -C C:/Users/maxth/Documents/GitHub/ledgr status --short --branch
```

2. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/AGENTS.md
```

3. Exit 0.

```powershell
Get-ChildItem -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet -Filter 'cut_review_1*' | Select-Object -ExpandProperty Name
```

4. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml
```

5. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md
```

6. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/closeout.md
```

7. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md -TotalCount 110
```

8. Exit 0.

```powershell
rg -n -A 16 -B 6 'One output handler|\| C6 |\| H6 |\| R3 ' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_roadmap.md C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/inventory_reconciliation.md
```

9. Exit 0.

```powershell
rg -n -A 45 -B 6 '^### 5.6|^## 11|contract-execution-fold-core|contract-execution-accounting-events' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md C:/Users/maxth/Documents/GitHub/ledgr/inst/design/contracts.md
```

10. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_2_spec_packet/tickets.yml -TotalCount 100
```

11. Exit 0.

```powershell
rg -n -A 26 -B 3 '^### 5\.6|^## 11|contract-execution-fold-core|contract-execution-accounting-events|\| H6 |\| R3 ' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md C:/Users/maxth/Documents/GitHub/ledgr/inst/design/contracts.md C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/inventory_reconciliation.md
```

12. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R -TotalCount 605
```

13. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R | Select-Object -Skip 1981 -First 625
```

14. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/ledger-writer.R -TotalCount 210
```

15. Exit 0.

```powershell
rg -n -A 5 -B 5 'output_handler\$|ledgr_execute_fold <-' C:/Users/maxth/Documents/GitHub/ledgr/R/fold-engine.R
```

16. Exit 0.

```powershell
rg -n -A 7 -B 5 'ledgr_memory_output_handler|output_handler\$|handler\$inline_summary|handler\$typed_events' C:/Users/maxth/Documents/GitHub/ledgr/R/sweep.R
```

17. Exit 0.

```powershell
rg -n 'ledgr_(persistent|memory)_output_handler\s*\(|current_packet|default_packet' C:/Users/maxth/Documents/GitHub/ledgr/R C:/Users/maxth/Documents/GitHub/ledgr/tests C:/Users/maxth/Documents/GitHub/ledgr/tools/governance-report.R C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/peer_benchmark/peer_benchmark.R
```

18. Exit 0.

```powershell
rg -n -A 5 -B 5 'ledgr_memory_output_handler|ledgr_persistent_output_handler|a0_observe_memory|trace|assignInNamespace|patch' C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/lib.R C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/guts.R C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/gut.R
```

19. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/timing.R
```

20. Exit 0.

```powershell
rg -n '^test_that|^testthat::test_that|ledgr_.*output_handler|mock|local_mock|worker|buffer' C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-sweep-parity.R C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-sweep-persistence-parity.R C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-availability-parity.R C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-ledger-writer.R
```

21. Exit 0.

```powershell
rg -n -A 8 -B 6 'terminal_status_written|set_schedule_counts|output_handler <-|output_handler\$' C:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R
```

22. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-ledger-writer.R | Select-Object -Skip 90 -First 250
```

23. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/gut.R
```

24. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/guts.R -TotalCount 125
```

25. Exit 0.

```powershell
rg -n 'ledgr_(persistent|memory)_output_handler|environment\(.*\$(events|buffer|write)|event_cols|pending_cols|pulse_fill|deparse\(body' C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat
```

26. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/lib.R -TotalCount 75
```

27. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/manual/optimization_coding_style.qmd -TotalCount 260
```

28. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/README.md -TotalCount 95
```

29. Exit 0.

```powershell
rg -n -A 8 -B 4 'record rule|Records|finding|pre-CRAN|Pre-CRAN' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc_cycle.md
```

30. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml | ForEach-Object -Begin { $line = 0 } -Process { $line++; '{0}: {1}' -f $line, $_ }
```

31. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-corporate-action-recovery.R | Select-Object -Skip 140 -First 80
```

32. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-availability-economics.R | Select-Object -Skip 1040 -First 85
```

33. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-risk-fold.R | Select-Object -Skip 340 -First 140
```

34. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tools/governance-report.R | Select-Object -Skip 1071 -First 120
```

35. Exit 0.

```powershell
rg -n -A 8 -B 3 '0xFFFF|repetition|fresh process|warm|alternat|registered|host' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/manual/benchmark_methodology.qmd
```

36. Exit 0.

```powershell
rg -n 'ledgr_(persistent|memory)_output_handler|ledgr_fill_event_payload|ledgr_write_fill_events|ledgr_store_format_bindings|execution_engine_version|engine_digest' C:/Users/maxth/Documents/GitHub/ledgr/R
```

37. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-sweep-parity.R | Select-Object -Skip 195 -First 330
```

38. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-sweep-persistence-parity.R -TotalCount 260
```

39. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_output_freeze/timing.R | Select-Object -Skip 65 -First 150
```

40. Exit 1.

```powershell
Rscript -e 'root <- "C:/Users/maxth/Documents/GitHub/ledgr"; cat(R.version.string, "\n"); files <- list.files(file.path(root, "tests/testthat"), pattern = "[.]R$", full.names = TRUE); n <- vapply(files, function(f) sum(grepl("ledgr_(persistent|memory)_output_handler[[:space:]]*[(]", readLines(f, warn = FALSE))), integer(1)); print(n[n > 0]); cat("TOTAL direct calls:", sum(n), "\n"); fold <- readLines(file.path(root, "R/fold-engine.R")); refs <- regmatches(fold, gregexpr("output_handler[$][A-Za-z_]+", fold)); print(sort(unique(unlist(refs)))); cat("unique fold handler members:", length(unique(unlist(refs))), "\n")'
```

41. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/Documents/GitHub/ledgr"
cat(R.version.string, "\n")
files <- list.files(file.path(root, "tests/testthat"), pattern = "[.]R$", full.names = TRUE)
n <- vapply(files, function(f) sum(grepl("ledgr_(persistent|memory)_output_handler[[:space:]]*[(]", readLines(f, warn = FALSE))), integer(1))
print(n[n > 0])
cat("TOTAL direct calls:", sum(n), "\n")
fold <- readLines(file.path(root, "R/fold-engine.R"))
refs <- regmatches(fold, gregexpr("output_handler[$][A-Za-z_]+", fold))
print(sort(unique(unlist(refs))))
cat("unique fold handler members:", length(unique(unlist(refs))), "\n")
source(file.path(root, "R/backtest-runner.R"), local = TRUE)
source(file.path(root, "R/sweep.R"), local = TRUE)
members <- function(fn) sort(unique(unlist(regmatches(deparse(body(fn)), gregexpr("handler[$][A-Za-z_]+[[:space:]]*<-", deparse(body(fn)))))))
cat("Persistent method definitions:\n"); print(members(ledgr_persistent_output_handler))
cat("Memory method definitions:\n"); print(members(ledgr_memory_output_handler))
'@ | Rscript --vanilla -
```

42. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/fold-engine.R | Select-Object -Skip 1210 -First 175
```

43. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/store-gate.R -TotalCount 35
```

44. Exit 0.

```powershell
rg -n -A 12 -B 4 'cash_delta|position_delta' C:/Users/maxth/Documents/GitHub/ledgr/R/availability-economics.R
```

45. Exit 0.

```powershell
rg -n -A 6 -B 3 'documentation-roles-pin-reset|fold-execution-phase-ownership' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc/README.md
```

46. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-ledger-writer.R | Select-Object -Skip 552 -First 78
```

47. Exit 0.

```powershell
rg -n -i 'worker.{0,40}buffer|buffer.{0,40}worker|mirai|workers' C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-ledger-writer.R C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-availability-parity.R C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-parallel-workers.R C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-sweep.R
```

48. Exit 0.

```powershell
rg -n -A 12 -B 3 'use_compiled_spot_fifo|append_compiled_spot_batch' C:/Users/maxth/Documents/GitHub/ledgr/R/fold-engine.R C:/Users/maxth/Documents/GitHub/ledgr/R/execution-spec.R
```

49. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/R/fold-engine.R | Select-Object -Skip 1378 -First 43
```

50. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc_cycle.md -TotalCount 165
```

51. Exit 0.

```powershell
git -C C:/Users/maxth/Documents/GitHub/ledgr rev-parse HEAD
```

52. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/Documents/GitHub/ledgr"
product <- new.env(parent = globalenv())
sys.source(file.path(root, "R/backtest-runner.R"), product)
harness <- new.env(parent = globalenv())
harness$asNamespace <- function(x) product
lib <- parse(file.path(root, "dev/bench/v0_2_3_output_freeze/lib.R"))
wanted <- vapply(lib, function(x) is.call(x) && identical(x[[1]], as.name("<-")) && is.symbol(x[[2]]) && as.character(x[[2]]) == "a0_with_patches", logical(1))
eval(lib[wanted], harness)
sys.source(file.path(root, "dev/bench/v0_2_3_output_freeze/guts.R"), harness)
rm("ledgr_persistent_output_handler", envir = product)
for (name in c("interrupted_telemetry", "wf_warning")) {
  result <- tryCatch(harness$a0_with_patches(harness$a0_guts[[name]]$patch, TRUE), error = conditionMessage)
  cat(name, ":", result, "\n")
  stopifnot(is.character(result), grepl("ledgr_persistent_output_handler", result, fixed = TRUE))
}
gov <- new.env(parent = globalenv())
sys.source(file.path(root, "tools/governance-report.R"), gov)
findings <- gov$governance_scan_ticket_evidence(root, "inst/design/ledgr_v0_2_3_spec_packet")
cat("Draft ticket evidence structural findings:", nrow(findings), "\n")
cat("Timing empty-row all() example:", all(numeric() <= 1.03), "\n")
'@ | Rscript --vanilla -
```

53. Exit 1.

```powershell
rg -n -A 60 -B 4 '^ledgr_require_compiled_spot_fifo_dispatch' C:/Users/maxth/Documents/GitHub/ledgr/R/compiled-accounting.R C:/Users/maxth/Documents/GitHub/ledgr/R/compiled-spot-fifo.R
```

54. Exit 0.

```powershell
rg -n 'ledgr_memory_output_handler|ledgr_persistent_output_handler' C:/Users/maxth/Documents/GitHub/ledgr/R C:/Users/maxth/Documents/GitHub/ledgr/dev/bench C:/Users/maxth/Documents/GitHub/ledgr/tools
```

55. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/README.md -TotalCount 65
```

56. Exit 0.

```powershell
rg -n -A 18 -B 3 '^### WS1|record rule|Record rule' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc_cycle.md
```

57. Exit 1.

```powershell
rg -n 'compiled_accounting_model|compiled_spot_fifo' C:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R C:/Users/maxth/Documents/GitHub/ledgr/R/run.R C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-execution-spec.R
```

58. Exit 0.

```powershell
rg -n '^#|ledgr-test-profile|skip' C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-ledger-writer.R
```

59. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/tests/testthat/test-execution-spec.R | Select-Object -Skip 455 -First 105
```

60. Exit 0.

```powershell
rg -n -A 18 'record|finding' C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc_cycle.md | Select-Object -First 80
```

61. Exit 0.

```powershell
@'
root <- "C:/Users/maxth/Documents/GitHub/ledgr"
e <- new.env(parent = globalenv())
sys.source(file.path(root, "R/compiled-spot-fifo.R"), e)
e$asNamespace <- function(x) {
  stub <- new.env(parent = emptyenv())
  stub$ledgr_cpp_spot_fifo_batch <- function(...) NULL
  stub
}
execution <- list(compiled_accounting_model = "spot_fifo", event_mode = "buffered")
without <- tryCatch(e$ledgr_require_compiled_spot_fifo_dispatch(execution, list()), error = function(cnd) class(cnd)[[1]])
with_stub <- e$ledgr_require_compiled_spot_fifo_dispatch(execution, list(append_compiled_spot_batch = function(...) invisible(TRUE)))
cat("Absent compiled capability:", without, "\n")
cat("Callable stub compiled capability:", with_stub, "\n")
stopifnot(identical(without, "ledgr_compiled_spot_fifo_unavailable"), isTRUE(with_stub))
'@ | Rscript --vanilla -
```

62. Exit 0.

```powershell
git -C C:/Users/maxth/Documents/GitHub/ledgr status --short --branch
```

63. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/AGENTS.md | Select-Object -Last 20
```

64. Exit 0.

```powershell
Get-Content -LiteralPath C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/cut_review_1.md -TotalCount 8
```

65. Exit 0.

```powershell
rg -n 'Ticket Workflow|Run targeted tests|governance_report <-|current_packet = ' C:/Users/maxth/Documents/GitHub/ledgr/AGENTS.md C:/Users/maxth/Documents/GitHub/ledgr/tools/governance-report.R
```


