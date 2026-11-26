CHANGES_REQUIRED
Mode: Type 2 cut review; independent review of the proposed Cut 26, before implementation.

**Role:** record
**Status:** accepted
**Authority:** Non-binding review record. Its disposition is recorded in Cut 26 cut_review in tickets.yml.

Repository paths below are relative to C:/Users/maxth/ledgr-wt/cut26-review.
`packet/` means inst/design/ledgr_v0_2_3_spec_packet/; `rfc/` means
inst/design/rfc/. `pin/` means C:/Users/maxth/ledgr-wt/pin-src-d5b3a151/.
Probe paths are relative to C:/Users/maxth/ledgr-wt/cut26-review-out.

The maintainer's selector decision is sufficient authority to use the lean R
FIFO until WS14. No new maintainer choice is needed for the findings below.
The shipped identity claim of none is correct for this dev-only cut; it does
not discharge the switch's existing identity obligations.

R1. Required: amend the operative compiled rule, and preserve its remaining obligations.

Claim: decision 3 identifies the wrong rule to amend and leaves the switch
dependencies of the retained checks unspecified.

Evidence: packet/tickets.yml:4397 calls the quoted text R10. It is actually
the replacement R9 in rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md:527,
with the compiled-order text at :562. R10 at :567 concerns diagnostics.
The skeleton's earlier R9 also contains the compiled-order clause
(rfc/rfc_lean_core_skeleton_v0_2_3_synthesis.md:827). R12 at pulse-plumbing
:211 and lean-fold-core Section 3 (:154) already require R now and a separate
WS14 decision for future compiled execution; they need no reversal.
The deletion-readiness seed's Section 6 (:258) requires an inventory of
old-fold-only dependencies; macro_plan.md:1269 forbids deleting a helper
while a refusal path needs it. The proposed E checks depend on the native
binding and the handler's compiled-append capability even though neither
will execute accounting under the lean loop (pin/R/compiled-spot-fifo.R:68,
:80).

Consequence: an R10-only edit leaves contradictory operative R9 text. At the
switch, deleting an apparently unused compiled capability or native binding
can make the inert selector refuse every selected sweep.

Exact replacement for decision 3's amendment paragraph and LDG-3272's design acceptance:

> Append a dated Cut 26 amendment to the pulse-plumbing synthesis's D3-A R9,
> explicitly superseding its compiled-order sentences and the corresponding
> earlier R9 sentences, including the skeleton's appended R9, in pending
> lean-core scope. R10 is unchanged. The replacement is: "After the retained
> selector admission checks, the lean core uses its one R FIFO for NULL and
> spot_fifo alike until the separately authorized WS14 decision. It does not
> reproduce the old compiled arm's state-before-append order. LR-19 and D3-B's
> cumulative fill-only limit, P5 refusal boundary and committed-prefix rules
> remain binding. WS14 either installs one compiled FIFO and retires
> spot_fifo.cpp, or retires the selector and spot_fifo.cpp." Record the
> maintainer's 2026-11-26 decision and LR-25. Section 19.14 names the two
> retained admission helpers, their handler-capability and native-binding
> dependencies, and their disposition in the switch inventory under the
> deletion-readiness seed Section 6. R12 and lean-fold-core Section 3 remain
> authoritative; no new compiled family or default is authorized here.

R2. Required: split the compiled refusal proofs; successful parity does not prove admission or capacity.

Claim: the proposed durable witness cannot exercise the E-stage dispatch
check, and the combined variant can pass while that check is entirely absent.
"The compiled arm ran" also cannot be inferred from identical economic tables.

Evidence: pin/R/backtest.R:148-164 rejects public selected durable runs before
the envelope. review_probe.R and review_probe.txt:82 reproduce that refusal.
Corporate facts without availability activation do reach the event-kind check:
review_probe.txt:85 shows a CASHFLOW refusal, and gutting just that check changes
FAILED to DONE (:90). This is a usable witness; an availability-active case
instead refuses upstream at pin/R/sweep.R:178.
The dispatch check has independent capability and missing-native branches
(pin/R/compiled-spot-fifo.R:54-87). capacity_probe.txt:11 shows the pin refusing
a public selected sweep with the native binding unavailable; :18 shows a lean
arm with its compiled coverage guard lifted and no dispatch check returning
DONE. A corporate-action-only gut would not detect that omission.
The same probe exercises a lowered fill limit through a public sweep and
gets the capacity condition in both arms (:1-10). The existing witness_capacity
uses a durable workload, not selected or worker execution
(dev/lean_core/parity/loop_workloads.R:622). LR-19 and D3-B expressly distinguish
retained P5 capacity from removed memory/non-fill append refusals
(packet/lean_core_rules_ledger.md:38; pulse-plumbing synthesis:587).
The compiled adapter also arbitrates native refusals against the earliest
canonical lot failure (pin/R/compiled-spot-fifo.R:210-240); the two E checks
are not an inventory of all selected-fold economic refusals.

Consequence: the entire dispatch call, or selected-fold capacity enforcement,
can be lost while the named successful workloads and combined refusal variant
still pass. Blanket preservation of every old compiled append refusal would
also contradict the already accepted LR-19 difference.

Exact addition to decisions 3, 6 and 8 and LDG-3272 acceptance:

> Record the public durable refusal at ledgr_run entry and do not count it
> as an E-stage dispatch witness. Use a corporate-facts-only selected sweep
> to reach the E event-kind refusal and an availability-active selected
> sweep to prove the separate upstream refusal. Add a missing-native selected
> sweep, using a test-only binding seam, which independently fails when the
> E dispatch call is omitted. Cover the missing-handler-capability and
> non-buffered E predicates by direct boundary witnesses, or record their
> public unreachability and verify the retained call and its arguments by
> source comparison. Compare original conditions, including class and
> message; exercise the escaping condition as well as the failed-candidate
> row. Split compiled_refusals_skipped into independent dispatch and
> event-kind omissions. Observe the pin's native dispatch directly for the
> successful selected workloads; output equality is not its reach predicate.
> Map the compiled adapter's economic refusals, including earliest lot
> overflow, to existing lean FIFO refusal proofs; add a selected public
> overflow/competing-failure witness where that composition is not covered.
> Distinguish unreachable internal-shape assertions from retained product
> refusals under R1-R3 rather than silently dropping either category.
> Add a selected-sweep capacity witness with a lowered limit, an at-limit
> control and a later-pulse over-limit case. Prove the class, message, pulse,
> stage and P5 committed-prefix boundary at batch one and the normal bound;
> a removed or late capacity check must fail. Attribute any old compiled
> append-boundary difference to LR-19/D3-B, with its recorded pin outcome,
> rather than weakening the P5 rule or claiming that all old refusals stay.

R3. Required: distinguish fresh restart, terminal reopen and terminal recovery.

Claim: "restart is already covered" is sound only for fresh nonterminal
attempt replacement. LDG-3272's requirement that restart "replaces ... an
INCOMPLETE attempt" is false.

Evidence: packet/tickets.yml:4413 and :9022; pin/R/run-resume.R:55 does return
start_idx = 1L for fresh attempts. But pin/R/backtest-runner.R:508 returns an
achieved INCOMPLETE run after evidence validation, and :517, :713 perform
finalization-only recovery for RUNNING/FAILED rows with completion evidence.
These paths never enter the fold. This is also the shipped
contract-persistence-completion-evidence rule (inst/design/contracts.md:1591).
review_probe.txt:94-103 independently shows one fold across two INCOMPLETE
invocations, unchanged tables, and zero additional folds recovering a FAILED
row after an injected finalization failure; a callback configured to fail
on replay is not invoked.

Consequence: the acceptance item is impossible as written, and two recovery
routes remain unproved by the probe's FAILED-without-completion examples.

Exact replacement for decision 4's restart explanation and the restart part of decision 6 / LDG-3272 acceptance:

> Delete the start_idx coverage check because every fold invocation starts
> at pulse one. Prove fresh replacement after FAILED without completion
> evidence and after a RUNNING max_pulses attempt, including opening events
> and a seeded strategy: the second invocation enters a fresh fold, resets
> strategy state and sequence, and replaces derived attempt output without
> duplicates. Separately prove achieved INCOMPLETE reopen and RUNNING/FAILED
> completion recovery after a terminal-finalization fault. Those cases
> validate or finalize existing completion evidence, enter no additional
> fold and invoke no strategy callback; use a callback that fails on replay
> and check completion, events, equity, diagnostics and final status. Reach
> predicates distinguish these routes rather than calling all of them
> replacement. Existing opening and carried-opening coverage remains the
> input boundary for fresh attempts and walk-forward test folds.

R4. Required: make the worker record and rerun claims independently falsifiable, including inert execution.

Claim: merging records is a sound direction, but the cut does not yet specify
the evidence needed to distinguish correct worker execution from silent
partial observation. Inert hooks cannot supply the record promised for gate
hooks.

Evidence: packet/tickets.yml:4420-4443 and :9038. Inert installation currently
binds only the envelope and context method (dev/lean_core/loop_harness.R:210),
so a worker-setup wrapper is not installed; inert fold_start does not count
folds (loop.R:54). Store detectors currently observe only live$in_pulses
(loop_harness.R:109), whereas a worker must not perform durable publication
after the loop either (lean_core_interface.md:1032). Existing detector
mutations are loaded only into the parent's lean environment
(loop_parity.R:427). Pin workers catch candidate errors and return rows;
stop_on_error rethrows later in the parent (pin/R/sweep.R:1505, :371).
A dropped whole record can be detected without proving that any individual
detector field, debug setting, reached marker or RNG state was transported.

Consequence: a channel can report fold counts while losing store/sink/hold
violations, mutations or backstop information. A skipped rerun can return the
same tables unless the witness forces a difference. An inert run can silently
use pin workers. A post-loop worker store write is outside the current detector.

Exact addition to decision 5 and LDG-3273 acceptance:

> Install worker loading and a harness transport wrapper in both gate and
> inert modes; inert fold hooks remain inert. Identify records by workload
> attempt, candidate and fold, retain error-path records before worker
> cleanup, and verify completeness against dispatched tasks and observed
> envelope entries. Missing, duplicate or foreign-attempt records fail
> closed. Merge additive counters by sum and bounds by maximum. Record
> actual namespace origin, envelope identity, debug and hook mode outside
> the inert hooks; inert zero detector counts alone are not execution proof.
> Transfer registered edits and reached markers to workers when running a
> worker mutation. Show a debug-only assertion firing in an actual worker
> with debug on, and the unchanged production result with debug off.
> Add worker-local faults for a store access, a terminal durable write, a
> sink call, hold expansion, append-bound violation and a lowered P5 fill
> limit. Their own signals must reach the parent even when public result
> tables match. Keep the worker's no-durable-write check active over the
> complete candidate execution, not only the pulse loop.
> A late worker backstop after earlier fills must rerun the complete public
> workload on pin-only workers, discard all attempted candidate results and
> restore the entry RNG kind and seed or its absence. The workload must
> consume and expose entry RNG state outside public calls so omission of
> restoration differs. Register independent skipped-rerun and skipped-RNG-
> restoration variants. Exercise a marked failure returned as a candidate
> row and propagated through stop_on_error, and an ordinary unmarked failing
> candidate; preserve original conditions. Prove fresh channel state across
> consecutive sweeps, including worker training sweeps within walk-forward.

R5. Required: give the restored-refusal variants an observable signal.

Claim: decision 8 requires compiled_selector_refused and walk_forward_refused
to be CAUGHT through a PATH difference, but the variant runner has no such
signal and can reject the intended witness as NOT RUN.

Evidence: packet/tickets.yml:4460; loop_parity.R:611-622 defines seen without
a path-change signal. :625 computes freeze agreement, but the mutation arm
does not use it as a signal and :645 reuses path_ok for store/sink matching.
:646 returns NOT RUN for a pre-pulse refusal with zero lean folds. The variant
driver's subprocess invocation does not pass --freeze
(loop_variants.R:51). The new walk-forward-only witness normally has no other
parent fold to satisfy that guard.

Consequence: these acceptance items cannot pass for their stated reason
without changing the checker. Counting any table difference instead would
miss a restored refusal that correctly reruns on the pin.

Exact addition to decision 8 and LDG-3274 acceptance:

> Add a distinct execution-path mutation signal, comparing the mutated
> record with the applicable approved freeze including Cut 26 changes.
> Pass that freeze to variant subprocesses. Keep this comparison separate
> from the store/sink path predicate. A reached restored-refusal edit is
> eligible with zero lean folds when the observed refusal is its intended
> fault. Require the expected refusal/path change and identical public
> tables for compiled_selector_refused and walk_forward_refused. An
> unrelated refusal and an unreached restored-refusal edit must not be
> CAUGHT; retain the existing negative controls as well.

R6. Required: repair all active lean-harness worker launch routes, not only the loop runner.

Claim: the diagnosis is right for an installed pin launched from a package
working directory, but the proposed repair does not cover every active runner
included in the cut's proof chain.

Evidence: pin/R/parallel-workers.R:244 first checks namespace origin, then
falls back to getwd(); :293 emits the worker load action. review_probe.txt:1-3
independently confirms the fallback returns the review source directory while
the parent namespace is the installed pin, and returns NULL outside it.
loop_parity.R:512, parity/plan_parity.R:153 and recorder/run.R:60 all call
a0_run_workload(); that shared helper starts sweep_w2 without changing
working directory (dev/bench/v0_2_3_output_freeze/lib.R:489). Only
witness_sweep_workers explicitly moves outside the package
(loop_workloads.R:570). Decision 2 / LDG-3271 name only loop_parity.R and
loop_variants.R, while decision 10 still requires the planner suite.

Consequence: the loop gate can be fixed while the active planner differential
and recorder/FIFO capture inputs still load release source on workers. A
source-pin recorder invocation also takes the namespace-origin branch; changing
getwd() cannot make that invocation an installed-pin comparison.

Exact replacement for decision 2's repair scope / LDG-3271 scope:

> Repair the active lean-harness worker launch routes: loop_parity.R,
> loop_variants.R, plan_parity.R and recorder/run.R, including their child
> drivers. Use a shared harness boundary where practical. Resolve user paths
> before changing working directory. In both comparison arms and all modes,
> verify every started worker's actual namespace origin against the arm's
> declared pin origin; a source-package cwd control must fail with WORKER.
> Installed-pin comparisons run outside a ledgr source package. Explicit
> source-pin captures are separately labelled and checked against that source
> pin, never represented as installed-library comparisons. Inventory the
> earlier affected worker-table records and their demonstrated launch
> directories; mark unrecorded directories unknown. Preserve historical
> records. No package worker-loading behavior changes in this ticket.

R7. Required: preserve the checkpoint freeze rows and state the actual remaining refusals.

Claim: decision 8's fixed list of ten updates contradicts decision 7; the
remaining-refusal claim also omits the still-present db_live refusal.

Evidence: packet/tickets.yml:4450 says to update the probe's ten changed paths.
Two of those ten are witness_checkpoint_control and witness_checkpoint_null
(dev/spikes/slice5_probe/a_baseline_debug1.csv:8-9 and g_gate_debug0.csv;
review_probe.txt:53-66). Their paths changed only because the probe lifted the
checkpoint guard; the cut explicitly keeps it. The default-valued control
witness already sets 10000L (loop_workloads.R:435); the NULL witness is also
explicit. D3 Section 2 refuses either key, not just non-default control values
(rfc_diagnostic_records_v0_2_3_synthesis_d3.md:159). loop.R:77 still refuses
non-buffered execution, and interface Section 19.2 (:885) lists db_live until
its switch retirement. The cut does not authorize lifting that check.

Consequence: following the prescribed ten updates changes frozen expected
checkpoint behavior and conflicts with the retained witnesses. Claiming only
two remaining refusals is false for the code the cut authorizes.

Exact replacement for decisions 7 and 8's freeze sentence / LDG-3274's first acceptance:

> The adapter continues to refuse a non-default engine.checkpoint_every and
> every explicit control$checkpoint_every key, including 10000L and NULL,
> before the first pulse. Preserve both existing checkpoint witnesses and
> their frozen refusal rows. The remaining coverage guards are this control,
> db_live/non-buffered execution until R8's switch retirement, and pulses
> outside the prepared axis. Update freeze rows only for the eight existing
> workloads whose worker, compiled-selector or walk-forward path changes,
> plus any independently explained record-schema effect; add every new
> workload with its reason. Record the final path counts, including merged
> worker folds, from final-code execution. Do not copy the probe's ten-row
> update list, which includes the two checkpoint paths deliberately excluded
> from this cut.

R8. Required: retain WS16's quick timing close obligation.

Claim: decision 10's appeal to macro rule 16 does not authorize omitting timing.

Evidence: packet/tickets.yml:4470; macro_plan.md:173 explicitly excepts WS16
from rule 16's general deferral. Its compact-state point 3 (:945) requires
each slice's quick timing run, carrying forward the family gate at :876.
Cut 21 used this method (tickets.yml:3198). Selector coverage also changes
which accounting implementation a selected workload executes; unchanged
per-pulse source is not unchanged execution cost.

Consequence: LDG-3274 can close without a required slice-close record or a
recorded disposition of its bounds.

Exact replacement for decision 10's "No timing record" sentence and addition to LDG-3274 acceptance:

> Close with the WS16 quick paired timing record through dev/bench/timing/,
> using the existing reference shapes and inherited floor/no-regression
> rules, stated before measurement. Record the pin comparison and the
> comparison against the accepted slice-4 lean baseline for previously
> covered runs. Report one representative selected and worker workload
> descriptively beside it, separating harness worker-loading cost. Any
> required-bound miss is fixed or explicitly disposed of under WS16's
> existing rule. No new optimization or full milestone benchmark is added.

R9. Required: separate reproducible measurements from uncommitted worker-log claims.

Claim: the CSV totals are traceable, but the worker-process and per-worker
execution claims in measured_input are not supported by the committed result
files.

Evidence: packet/tickets.yml:4340 and :4350 claim 12 worker processes and
every worker fold lean with no detector violations. The patch writes those
observations to Sys.getenv("LEAN_PROBE_WORKER_LOG")
(dev/spikes/slice5_probe/probe.patch:56-91); that log is absent from the
committed probe directory. e_workers_debug1.csv:2 records zero parent lean
folds and PASS* for witness_sweep_workers. The full gate similarly has no
per-worker identity or record columns. These CSVs establish table equality,
not worker execution. The detailed attempt statuses/events are also described
as pin-table observations without committed raw pin tables; the patch explains
their construction, but the summary CSV does not contain those values.
review_probe.txt:4-81 independently recomputes the quoted workload/table totals,
zero differences and the twelve PATH workloads from all a-g files.

Consequence: the input attributes stronger reach to a saved measurement than
another reviewer can verify. The cut is meant to repair precisely this gap.

Exact replacement for measured_input's worker-reach claims:

> The committed worker and full-gate CSVs establish table equality and the
> parent's recorded paths. The probe author additionally reported twelve
> worker processes per full-gate mode and successful per-worker lean
> execution from an external LEAN_PROBE_WORKER_LOG; that log is not committed,
> so these are unverified author observations, not measured reach established
> by the saved CSVs. The detailed restart-status/event observations likewise
> require their raw pin tables for independent verification. LDG-3271 and
> LDG-3273 commit their own final-code worker-origin, per-fold and condition
> records; LDG-3272 commits the restart pin tables and reach predicates.

Alternatively commit the original logs/raw tables and cite their exact rows;
do not generate a later run and label it as the original measurement.

R10. Required: discharge the "new feature path" prerequisite without moving the oracle.

Claim: sequencing after the feature cuts does not itself establish the
integration required by macro item d.

Evidence: macro_plan.md:1108 places slice 5 "on the new feature path" because
sweep precompute, splitting and reconstruction may change. load.R:26-57
requires the frozen d5b3a151 package and sources only dev/lean_core files;
therefore both the probe and the proposed main gate use that pin's old feature
preparation. The worker-origin repair will consistently enforce that choice.
The final feature oracle provides useful independent producer evidence
(dev/feature_parity/README.md:71-85; LDG-3270 evidence at tickets.yml:8980),
but the cut does not connect it to the lean consumer or name the remaining
integration proof.

Consequence: the prerequisite can be declared met while the new preparation
and the lean worker consumer have never met at a checked boundary.

Exact addition to LDG-3273 acceptance and Section 19.14:

> Keep d5b3a151 as the unchanged main parity oracle. Add a bounded bridge
> proof for macro item d using the final feature build: prepare the same
> feature-bearing sweep inputs through implicit preparation and explicit
> precompute/reuse, including two-worker reconstruction, and check their
> values, NA masks, indexed planes, axes and feature mapping at the lean
> consumer boundary. Reuse the accepted feature oracle's comparisons and
> declared differences rather than replacing its expectations. Demonstrate
> a changed transferred value or mapping failing the lean-consumption check.
> Name each process's build and distinguish this bridge from the pin-only
> gate. Record the remaining full integrated product proof as a switch
> obligation; do not claim that gate execution on the pin exercised the new
> package feature path.

Checked: Cut 26, workstream 46 and all four ticket acceptances; Cut 21's
method and workstream evidence; both probe READMEs, the slice-5 patch and every
saved a-g CSV; interface Sections 19.2, 19.6 and 19.13; LR-19/LR-20;
macro WS16, item d, WS14/WS14a; D3, pulse plumbing R9-R12, lean-fold-core FIFO,
durable-record resume retirement and deletion-readiness routing. Traced the
pinned envelope, compiled adapter, worker setup and candidate error transport,
restart/opening/finalization paths, walk-forward train/test/carry routes and
the active lean loaders/runners/freezes/variant checker. Walk-forward adds
orchestration of already covered sweep, committed-run and carried-opening
operations; costs/risk and worker training need integration witnesses, not
another fold engine. Keeping the checkpoint control refused is exactly D3's
pre-switch disposition. The selector decision does not authorize changing
R12's future compiled gate, shipped identity or the frozen oracle.

Independently executed review_probe.R and capacity_probe.R against the
read-only installed pin, from the output directory with an explicit
--workloads= argument. These use the runner's setup helpers without running
its gate. They recompute saved-file totals, test source-path selection,
exercise and gut the corporate-action refusal, test selected capacity and
missing-native admission, and test terminal reopen/recovery with replay
forbidden. Their scripts and outputs are beside this review. The first probe
also corrected my initial suspicion that all corporate-facts sweeps were
availability-active: the tested facts-only sweep reaches the E check.

Not checked: implementation that does not yet exist; full gate, variant suite,
full tests, package check, timing windows, large memory measurements, private
or vendor data. No worker processes were started by these review probes;
worker transport conclusions above follow the source and saved evidence, not
a claimed new worker experiment. Git status/revision commands were refused
by Git's repository-ownership check, including command-local safe.directory
attempts; the supplied detached revision was not independently verified.
No tracked file was edited and no commit was made; writes were confined to
the authorized output directory.
