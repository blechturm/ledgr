PASS
Mode: Type 1 focused re-review 1 of workstream 46 (Cut 26). Independent session; reviewed 400c6a14 through 9d60a0ee03b110f1088ea74c51e2912ae858e408.

**Role:** record
**Status:** accepted
**Authority:** Non-binding review record. Its disposition is recorded in workstream 46 close_review in tickets.yml.

Both required findings are resolved. I found no weakened acceptance check, different public answer, wrong refusal, missing exactness proof or irreproducible total. N1 is an advisory limitation of the new inert-mode diagnostic.

F1. Resolved.

With harness hooks, the wrapper snapshots the fold/refusal counters for each entry, observes errors through a calling handler, and records a prefold class only when the entry unwinds without returning and neither counter advanced (dev/lean_core/loop_workers.R:105). Task reset and recording include prefold (:137, :145). The parent retains the equality, now requiring lean folds + coverage refusals + prefold outcomes = entries, and separately rejects NA outcomes (:202, :206).

The executable wrapper/task/merge probe rereview_channel.R uses those committed functions, with installation and namespace rebinding stubbed. Its output, rereview_channel.txt, establishes:

- A fold, a coverage refusal and an escaping error before the fold each contribute one outcome.
- An ordinary return without a fold still faults on the equality. A non-error unwind before the fold records NA and faults explicitly.
- A locally caught error contributes no prefold outcome, including when the function subsequently returns without a fold; that unexplained return faults.
- An error after fold start, or after a recorded coverage refusal, contributes no second outcome.
- The escaping condition is identical to the original object, including its full class vector, message, call and extra field. The outer calling handler receives that same object once.

The same probe rechecks missing, duplicated, undispatched and foreign-attempt records, wrong origin, pinned envelope, wrong debug and wrong hooks. Each faults. Whole-task store calls and backstop marks still reach the parent; additive counters sum and bounds take maxima. The corresponding parent checks and transports remain in dev/lean_core/loop_workers.R:186 through the merge. Fresh worker parity also preserves the failing-candidate condition, backstop rerun and walk-forward routes.

The new witness uses two candidates, two workers and both stop_on_error forms (dev/lean_core/parity/loop_workloads_slice5.R:503). Its predicate requires four dispatched tasks, two FAILED rows with CASHFLOW messages, and the escaping CASHFLOW message (:603). Condition tables are compared exactly with the pin; the predicate is not the only condition check. The six new freeze rows correctly declare zero folds and empty coverage-refusal/backstop columns for all three modes and both debug settings. Existing freeze rows are unchanged (loop_freeze_changes.R:324; loop_freeze_changes.csv:626).

Fresh runs pass this witness at debug 0 and 1 in gate, batch-one and inert modes: 11 identical tables and four attributed E-stage refusals each. The mutation replaces only the prefold recording statement with its reached marker (loop_parity.R:456; loop_variant_changes.csv:250). Both fresh mutation runs are CAUGHT on the worker signal: all four entries are unexplained, all 11 tables remain identical, and no new public error appears. See rereview1/variant_debug0.csv and variant_debug1.csv.

F2. Resolved.

dev/lean_core/recorder/run.R:50 reads and normalizes src before lean_harness_workdir() at :64. The child receives that saved absolute path at :256. The declared-build label and worker-origin check remain at :55, :65 and :198; their helpers in load.R are unchanged.

The actual recorder ran from the authorized output directory with --src=../slice5-scratch/pin-archive, --workloads=avail_incomplete and absolute captures/out/manifests beneath rereview1/recorder. It exited 0. The installed arm replayed 112 records and the source-pin history child 180, all passing. The log names the correct installed pin and source pin. See rereview1/recorder_relative_src.log and rereview_fresh_audit.txt.

N1. Advisory: prefold does not identify the error stage under inert hooks.

Claim: an error after fold start can be labelled prefold in inert records. The new exactly-one-outcome prose in interface Section 19.14 also needs the harness-hook qualification used in the correction README.

Evidence: dev/lean_core/loop.R:55 makes inert fold_start a no-op. The counter comparison in loop_workers.R:109 therefore cannot distinguish an E-stage error from a later strategy error. The committed review_r1/inert_debug0_workers.csv:19 and :22 label the failing candidate's ledgr_strategy_error as prefold, although loop_workloads_slice5.R:430 raises it during the day-3 strategy call. A fresh --inert=1 --debug=0 --workloads=s5_workers_failing run reproduces this in rereview1/inert_failing_debug0_workers.csv:2 and :5: both failures have prefold=ledgr_strategy_error. All 11 public tables are identical and the run is PASS*. Section 19.14's unqualified outcome statement is at lean_core_interface.md:1630.

Consequence: inert prefold classes cannot establish where an error occurred. This is advisory because the equality at loop_workers.R:202 is explicitly limited to harness hooks; the mislabel changes no verdict or public result and invalidates none of the asserted parity totals. The required F1 accounting remains effective with harness hooks.

Fix: limit prefold stage attribution to harness hooks and qualify Section 19.14 accordingly; do not present an inert escaping error as evidence that no fold started. Keep the existing inert envelope/origin checks and public parity checks.

Checked:

- Read the round-1 report first and retained its Checked list except where this diff required renewed verification. Confirmed HEAD and a clean worktree before and after. The diff changes no R/, tests/, DESCRIPTION, NAMESPACE or vignettes file. Of the top-level lean R files, only the harness loop_workers.R changes; production loop.R remains unchanged.
- Independently checked proof inputs against the changed execution sites: the wrapper/task code runs in sweep workers, and the changed parent checks/table projection run per worker record. Serial workloads take none of those changed statements. This supports the worker-only parity rerun scope; the recorder correction has its separate executable proof.
- Recomputed committed proof totals and workload membership against the previous final-code worker records. In each debug setting: gate has 16 workloads, 333 identical tables, PASS 15/PASS* 1 and 41 worker records; batch-one has 10 workloads, 121 identical tables, PASS 9/PASS* 1 and 29 records; inert has 10 workloads, 121 identical tables, PASS* 10 and 29 records. Every frozen path is checked. Origins, actual worker debug settings, hooks, envelope identities and zero store calls agree. See rereview_audit.txt.
- Recomputed variant manifest/result keys: debug 0 has 17 rows/15 variants; debug 1 has 18 rows/16 variants. Every requested row is present, reached and CAUGHT. The five debug-0 negative controls have their declared failing verdicts and status 1. The initial failed debug-0 driver invocation and successful later log are accurately disclosed.
- Executed the actual variant driver's manifest/filter expressions without launching its subprocess loop. Default, single-workload, mixed-debug and eight-worker-workload selections retain exactly the requested manifest keys; unknown names refuse. Checking names before debug filtering correctly permits s5_workers_sizing to contribute only at debug 1. Controls remain outside the workload filter and retain their existing debug-0/default scheduling. See rereview_filter.txt.
- Fresh parity at both debug settings covered s5_workers_compiled_refused, s5_workers_failing, s5_workers_backstop_escape and s5_walk_forward_workers: 49 identical tables per setting. Also ran the new witness in batch-one and inert modes, the new mutation in both settings, the relative-source recorder, and the additional inert failing-candidate probe. rereview_fresh_audit.txt checks the saved outputs.
- Recomputed every lines_r1.csv row: loop_workers.R 163 to 177; loop_workloads_slice5.R 509 to 527; loop_parity.R 659 to 662; loop_variants.R 87 to 92; loop_freeze_changes.R 235 to 239; recorder/run.R 203 to 203. The ldg3274 README head note correctly identifies the worker-channel exception to bc628409. Production counts are unaffected. Section 19.14 describes the correction correctly for harness hooks, subject to N1's inert qualification.

Not checked: no full gate, full variant driver, FIFO capture/check, timing window, package test suite or package check was run. Broader committed totals were audited, not claimed as fresh full execution. No accepted design decision was reopened. All R commands launched from C:/Users/maxth/ledgr-wt/ws46-close-review-out; source-archive loading was sequential. No library under AppData/Local/Temp, E:, vendor data or ledgr-research was used. No tracked file was edited and no commit was made. Review scripts, saved outputs and this report are in the authorized output directory.
