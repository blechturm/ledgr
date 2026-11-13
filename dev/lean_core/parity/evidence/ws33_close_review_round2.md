PASS
Mode: Type 1 close review of workstream 33, round 2; focused verification of 85944ebf..97848c96, not design. Independent session; I wrote none of the reviewed implementation.

Both round-1 findings are fixed as their smallest fixes state. I found no new wrong answer, false evidence or unmet acceptance item in this correction set. No Type 2 concern arose.

Repository references below are relative to C:/Users/maxth/ledgr-wt/ws33-review2, verified at 97848c968281939b35282c5958eb8931e2a78deb. Unqualified parity script names are under dev/lean_core/parity/. Probe scripts and outputs are in C:/Users/maxth/ledgr-wt/ws33-close-out/round2. Evidence CSV references are under dev/lean_core/parity/evidence/.

1. Round-1 finding 1: the fee-basis assertion is fixed.

   - Claim: every fee must equal the fixed 1 plus 5 bps of quantity times the transformed unrounded price, in the pin's arithmetic order; the earlier transform checks must remain.
   - Evidence: loop_workloads_slice2.R:124 matches each fill to its source open; :127 applies the BUY/SELL multiplier; :128 retains both sides, matched opens, buys above open and sells below open; :129 uses identical() on the complete fee vector. The expression preserves the resolver's zero initialization, fixed addition, quantity-price multiplication, bps multiplication and final division (R/cost-model.R:409 and :412 through :433). This follows inst/design/contracts.md:621, rule group #contract-execution-cost-model.
   - Execution: predicate_probe.R, output predicate_probe.txt, independently rebuilds the resolver arithmetic and calls the actual resolver from the requested pinned library. All 313 fees match exactly (158 BUY, 155 SELL), and the resolver also reproduces the public rounded prices. The registered predicate holds on both the round-1 dump and the fresh pin dump. Replacing either side's transformed fill prices with source opens is rejected. Altering a single fee at either end of the vector is rejected.
   - Consequence: the assertion now establishes the required unrounded fee basis while keeping the earlier transform checks.
   - Classification: resolved missing acceptance item and overstated evidence from round 1; no remaining finding or product wrong answer observed.
   - Smallest fix: none further.

2. The new basis control and corrected-predicate parity evidence are supported.

   - Claim: the control must actually change fees and require rejection; the corrected predicate must pass the pin/lean comparison and frozen path.
   - Evidence: slice2_reach_cross.R:41 recomputes fees from rounded public prices; :42 counts actual numeric changes; :43 requires rejection; :47 makes ok depend on both rejection and a positive change count. The committed slice2_reach_cross.csv:27 records TRUE, 312, 0, "312 of 313 fees changed", TRUE. The control does not substitute a generic cross-workload failure for the fee-basis check.
   - Execution: predicate_probe.txt reproduces that committed control row exactly: 312 of 313 fees change, maximum absolute difference 2.4924506902834764e-12, and the predicate rejects them. First fee: pin 1.0323546020013925, rounded basis 1.0323546020000001. run_cross.R executes the unchanged committed cross-check on six existing pin dumps: reach_sample.log reports seven checks, seven ok, including the basis control. evidence_probe.txt confirms both committed loop_gate_cost_chain_r1_debug0.csv and _debug1.csv have 16 identical tables, branch TRUE, PASS and paths matching the freeze after its declared changes are applied. run_cost.R reruns only s2_cost_chain at debug 1: cost_sample.log reports 16 tables, zero different, PASS 1 and one of one frozen paths checked. Its CSV agrees with the committed debug-1 record apart from incidental clocks.
   - Consequence: ok is justified, and the stronger assertion introduces no false failure on this covered workload.
   - Classification: no wrong answer, false evidence or missing acceptance item found.
   - Smallest fix: none.

3. Round-1 finding 2 and the changed ticket evidence are corrected.

   - Claim: both rollback variants change 13 of 16 tables, with run_promotion_context, run_provenance and run_tags unchanged.
   - Evidence: evidence_probe.R reads loop_mutations.csv and loop_mutations_debug1.csv. evidence_probe.txt confirms exactly that count and unchanged-table set for sizing_rows_after_decisions and raw_notice_with_evidence at both debug settings; all four groups are reached and CAUGHT. inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:5212 now states these results instead of "every table differs". No variant implementation or mutation result changed.
   - Ticket audit: :5176 describes the exact rebuilt fee assertion, the 312-of-313 rejected control and the two focused parity records, and distinguishes those records from the earlier full gate. :5230 retains the historical close-set identity and explicitly attributes the added control to the round-1 fix. Workstream 33's close_review at :2319 preserves CHANGES_REQUIRED and both rejection reasons while recording the corrections; it does not claim an independent round-2 PASS. These are the four changed ticket fields, and their technical claims match the committed files and probes.
   - Consequence: the revised evidence accurately states the observed rollback differences and the scope of the new verification.
   - Classification: resolved false evidence wording; no remaining finding.
   - Smallest fix: none further.

4. The correction stays within the authorized scope.

   - Claim: 97848c96 changes only parity harness code, evidence and tickets.yml.
   - Evidence: git_audit.txt records HEAD and the complete 85944ebf..97848c96 diff: two parity R files, four evidence files (including the retained round-1 report) and tickets.yml. No dev/lean_core execution source, R/ or tests/ file changes. final_audit.txt confirms no working-tree or staged changes.
   - Consequence: product execution remains unchanged; the correction strengthens verification and repairs its evidence.
   - Classification: no scope violation, wrong answer, false evidence or missing acceptance item found.
   - Smallest fix: none.

What I checked: the complete correction diff; both round-1 findings and smallest fixes; the relevant cost contract and source resolver; the registered predicate and control by reading and execution; both new committed parity CSVs and their applied frozen paths; one fresh debug-on cost-chain run; both mutation evidence CSVs; all four changed ticket fields. All R calls used C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe and the requested lib-d5b3a151 library. Reproduce the focused runs by calling that executable with the absolute paths to run_cost.R, predicate_probe.R, run_cross.R and evidence_probe.R in this round2 directory. The reused and fresh pin fills are identical; the complete cross-session dumps differ in runs.config_json, so I do not claim complete dump identity across sessions. R emitted locale startup warnings; the successful probes and subprocesses exited zero.

What I did not check: no timing or performance assessment, full gate, full variant manifest, test suite, package check, or repeat of the broader round-1 implementation review. The 25-predicate committed cross-check was inspected; execution sampled six dumps rather than all 26 workloads. Debug-off parity and rollback variants were audited from committed evidence rather than rerun. I did not touch E:, ledgr-research or vendor data. All new probes, outputs and this report are under round2; no tracked file was edited and no commit was made.
