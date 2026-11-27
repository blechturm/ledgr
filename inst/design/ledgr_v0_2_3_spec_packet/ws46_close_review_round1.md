CHANGES_REQUIRED
Mode: Type 1 close review of workstream 46 (Cut 26), round 1. Independent session; reviewed 2bd1a33e through 400c6a14c58c56f64a617b00b5588dd8998fcc81.

**Role:** record
**Status:** accepted
**Authority:** Non-binding review record. Its disposition is recorded in workstream 46 close_review in tickets.yml.

Two required harness corrections remain. I found no different public result table in the probes. Neither finding requires reopening the accepted selector decision, trust principle, checkpoint/db_live disposition or timing record.

F1. Required: an original E-stage refusal in a selected worker sweep is incorrectly reported as a broken worker channel.

Claim: the channel assumes every lean envelope entry either starts the pulse fold or falls back for uncovered coverage. A legitimate admission refusal fits neither category.

Evidence: dev/lean_core/loop_workers.R:95 counts the envelope entry, but :183 requires lean_folds + length(refused) == entries. The compiled admission calls at dev/lean_core/loop.R:246 and :248 precede hooks$fold_start() at :292; that hook increments lean_folds at dev/lean_core/loop_harness.R:68. An admission error therefore leaves entries = 1, lean_folds = 0 and refused empty. dev/lean_core/parity/loop_parity.R:766 turns the resulting worker fault into WORKER.

The probe public_boundaries.R composes the existing s5_compiled_event_kinds public fixture with two candidates and workers = 2, exercising stop_on_error FALSE and TRUE. It compares the pin and lean tables exactly and saves both arms. probe_results_check.txt:1 and :21 show, with debug off and on, the original FAILED rows and escaping ledgr_compiled_spot_fifo_unavailable/ledgr_invalid_fold_execution condition:

    Compiled spot-FIFO cannot execute pulse-plan economic event kind(s): CASHFLOW. Canonical R is required for every non-FILL economic event.

Every public table is identical. All four worker records have the correct origin, lean envelope, debug setting and harness hooks. Nevertheless probe_results_check.txt:18 and :38 report four faults, each of this form:

    worker 1|a: 0 lean folds and 0 refusals for 1 envelope entries

Consequence: a covered public composition that correctly preserves the pin's refusal cannot pass the worker gate. The existing serial admission witnesses and successful worker witnesses miss this intersection. This leaves LDG-3273's worker coverage and the close's refusal proof incomplete (tickets.yml:9150; interface Sections 19.2 and 19.14).

Fix: account explicitly for lean envelope exits before fold_start, including the retained admission refusals, while preserving one attributed outcome per observed entry. Keep the original conditions and keep detecting a pinned envelope, missing record and unexplained entry. Do not simply remove the equality or permit arbitrary unmatched entries. Register selected worker refusal witnesses in both stop_on_error forms and both debug settings, and retain the existing worker negative controls.

F2. Required: recorder/run.R resolves a relative --src after changing the working directory.

Claim: a valid source-pin argument can be refused because it is interpreted relative to the harness's new directory.

Evidence: dev/lean_core/recorder/run.R:60 calls lean_harness_workdir(); :250 first reads --src and :252 normalizes it. LDG-3271 expressly requires resolving user paths before the directory changes (tickets.yml:9103).

relative_src_probe.R runs the actual recorder from the authorized output directory with the installed pin, --workloads=avail_incomplete, absolute output paths and --src=../pin-src-d5b3a151. relative_src_probe.txt:2 confirms that source path exists at entry. The installed arm captures and replays 112 records with zero failures (:25), then the recorder exits 1 (:29):

    path[1]="../pin-src-d5b3a151": The system cannot find the file specified

Consequence: the explicit source-pin child route fails for a valid invocation. The saved absolute-path source capture does not establish the required relative-path handling.

Fix: read and normalize --src alongside lib/captures/out/manifests before lean_harness_workdir(), then pass that saved absolute path to the child. Keep the source-pin label and origin check. Add a small relative-source-path control; this needs no change to package worker loading.

Checked:

- Read Cut 26 decisions 1-10, workstream 46 and all four ticket acceptances/evidence; the cut-review chain, LR-25, the compiled-selector amendment and interface Sections 19.2/19.14. Traced the changed loaders, loop, hooks, channel, workloads, freeze and mutation machinery against the pinned worker, sweep, fold, compiled adapter, restart, walk-forward and output-handler paths. The admission helpers retain their arguments and order. The restart helper always returns start_idx = 1; terminal reopening/recovery stays outside the fold. The selector amendment and switch obligations are recorded as accepted.
- Verified HEAD and a clean worktree. The diff changes no R/, tests/, DESCRIPTION, NAMESPACE or vignettes files. The top-level lean R sources match the final-code evidence revision bc628409. Reviewed the small loop.R change against all seven optimization shapes: the new work is once in E, with no new growing-collection loop, row frame, repeated parse/JSON work, pairwise validator or environment-held buffer write.
- Re-ran seven registered workloads with debug off and on: s5_workers_failing, s5_workers_backstop_escape, s5_walk_forward_workers, s5_compiled_overflow, s5_compiled_capacity_over, s5_restart_opening and s5_recover_completion. Each run passed 108 tables and all seven frozen paths. Worker backstop escape reran on pin-only workers with the unseeded entry restored. The registered failing-candidate condition remained unchanged. Results are review_subset_debug0.csv and review_subset_debug1.csv.
- Independently composed selected overflow with two workers: both stop_on_error forms matched with debug off and on, four worker records per comparison and no channel fault. A feature-constructor failure beside a successful candidate likewise preserved DONE/FAILED rows and the escaping original class/message in both settings; see probe_results_check.txt:19 and :39. The selected corporate-action refusal composition exposed F1.
- Exercised channel merging directly: missing, duplicated, undispatched and foreign-attempt records, wrong origin, pinned envelope, wrong debug and wrong hooks all faulted. Whole-candidate store calls and backstop marks reached the parent. Additive counters summed and bounds took maxima. See bridge_and_channel.R/.txt. Source inspection and saved worker variants also cover the debug assertion, terminal durable write, sink, hold-hook transport, expansion bound and lowered capacity. The hold witness explicitly drives the hook because worker memory sinks do not encode implicit holds.
- Traced attempted-result discard, pin-only rerun and entry RNG kind/seed-or-absence restoration. The saved independent skipped-rerun and skipped-RNG variants fail for their named consequences on both backstop workloads. Consecutive sweeps and walk-forward training records use distinct sweep keys. F1 is the exception to the channel's otherwise successful checks.
- Recomputed committed records with audit_counts.R/.txt: LDG-3271 has 203 workloads/3,136 tables per debug setting; LDG-3272 has 18/306; LDG-3273 has 17/382 in each saved mode. Final gates have 227/3,452, batch one 67/914 and inert 36/485, each with zero different tables. Every approved frozen path matches. Gate worker records are 37 over 15 workloads; batch-one/inert records are 25 over nine, with the stated origins, envelope identities, debug/hooks and zero store calls. Reach checks reproduce 26/41/92 successes; planner records have 427 identical tables per setting. The direct cut18_witness run reproduced 145 cases times two settings with zero differences.
- audit_git.R/.txt verifies that historical freeze/variant rows are preserved. Cut 26 adds exactly 16 gate updates for the eight declared existing workloads, 48 new gate rows, 22 batch-one rows and 18 inert rows. Checkpoint rows remain unchanged. Four variant rows retire with explicit reasons: two walk-forward entry-guard rows and two worker-guard rows. Saved variants reproduce 149 manifest rows/87 variants at debug 0 and 103/52 at debug 1, all CAUGHT with reached markers. Inspected the new injections and intended signals. The restored-refusal signal remains separate from store/sink matching. Re-ran its two negative controls: UNRELATED and UNREACHED, each exit 1; the three older controls also have their expected saved failing verdicts.
- Checked feature_bridge.R's projection, feature-name resolution, axes and mapping against loop.R's setup and feature_fn. Re-ran --check on copies of the committed CSVs: 96 records per arm pass; the transferred-value and alias-mapping faults exit 1 with their stated component signals. The builds are named and the bridge remains distinct from the pin-only gate. The integrated lean/new-feature execution proof remains a switch obligation.
- Recomputed current and historical line counts using the committed counting function: loop.R 993 to 997 production lines; total production 2,665 to 2,657; debug 206 unchanged. All reported harness/workload/witness counts reproduce. Recomputed the 192 timing slots: 12 cells, eight pairs, all outcomes ok and arm work strings equal. Required pin ratios are below 1.0; the four slice-4 comparisons remain within 5 percent. The reported medians and paired changes reproduce. Inspected the candidate .lean_lib/.lean_home repair; it supplies loader state without relaxing a timing check. Accepted attempt-2 disposition was not reopened.
- Git comparison proves fifo_capture_tests.R exactly matches 98c76c92. The established test-rng-isolation.R exclusion remains; no crash-response test skip remains. Both saved outcomes report 230 files/1,327 tests, two schema-version assertion failures, zero errors and one ordinary package-test skip. The two populations agree and match Cut 22; fifo_check records its stated pass. The crash evidence supports its attribution: identical object files, duplicate/missing unwind entries in the failed DLL, the same refusal crash after a three-process rebuild, and three successful refusals after a single-process rebuild under the same dependency versions. No new kernel or dependency exception is justified by that crash.

Not checked: no full gate, variant driver, FIFO capture/check rerun, full package test suite, package check, timing window or crash/relink experiment was run. The broader results above are audits of committed evidence, not fresh execution claims. No final-feature library was loaded for integrated lean execution. No library under AppData/Local/Temp, vendor data, E: or ledgr-research was used. All R commands launched from the authorized output directory. No tracked file was edited and no commit was made; probes, outputs and this report are confined to that directory.
