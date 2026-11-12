CHANGES_REQUIRED
Mode: Type 1 close review of workstream 31; independent fresh session, verification, no implementation authorship.

Reviewed 6e84e602..718b49c9 (8c233cca, 41691197, 968931ff, 718b49c9), with 4a3e08b8 as the loop baseline and d5b3a151 as the package oracle. Repository-relative citations below resolve under C:/Users/maxth/ledgr-wt/ws31-close; probe files and logs resolve under C:/Users/maxth/ledgr-wt/ws31-close-out. Neither ticket meets every acceptance item. No wrong answer was found in the original candidate on the small covered workloads executed here. The findings concern implementation of the accepted proof and measurement requirements. No new design decision requiring NEEDS_TYPE_2 was identified.

1. The variant aggregate runner accepts an unsuccessful subprocess.

   Claim: LDG-3220 requires subprocess failures to fail the aggregate, but the runner checks only the resulting CSV.

   Evidence: inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:4637; dev/lean_core/parity/loop_variants.R:45 invokes system2(), then :49 checks file existence and :55 checks only workload/verdict. It never examines attr(log, "status"). contract_probes.R evaluates the actual aggregate-loop expressions against one synthetic manifest row and a simulated child that writes CAUGHT and returns status 1. contract_probes.log reports: `1 manifest rows, 1 variants, 0 failures` and `Aggregate runner returned normally; failures = 0`. No full manifest or real failing subprocess was needed for this probe. The same reader also accepts this synthetic CSV without mutation, batch-bound or expectation columns.

   Consequence: a failure after writing a CSV can be accepted; the aggregate does not enforce the promised complete manifest-row identity.

   Classification: missing acceptance item; the checklist's failed-subprocess guarantee is false. This does not establish that any committed manifest execution actually failed.

   Smallest fix: reject nonzero subprocess status independently of CSV contents, and validate result keys and expectations against the complete requested manifest rows. Controls should require their intentional nonzero status and declared verdict, while ordinary variants require status zero.

2. A store-path variant can be CAUGHT by a different detector path.

   Claim: the strengthened verdict still does not require the declared store primitive to execute or be detected.

   Evidence: dev/lean_core/parity/loop_parity.R:64 gives every store variant the generic `store` expectation. :147 inserts the same Boolean marker at every edit, including preparation outside the pulses. The verdict uses any store_access and that shared marker, without a variant-specific detector-path expectation. wrong_store_path_control.R evaluates the runner with an explicitly adversarial variant in memory: its declared dbBind call is under `if (FALSE)`, and dbExecute writes instead. Fixtures and the equality oracle are unchanged. wrong_store_path.log reports `CAUGHT`, identical tables, exit 0, and only `duckdb:::rapi_prepare; duckdb:::rapi_execute; duckdb:::rapi_release`; no rapi_bind. Compare variant_bind.log, where the unmodified registered variant correctly reports rapi_bind.

   Consequence: the dbBind detector proof can pass without exercising dbBind. The existing unrelated-error and unreached-patch controls do not establish the full intended-fault requirement for these multi-edit variants.

   Classification: missing acceptance item and a false general fail-closed claim, rather than a demonstrated bad product result or proof that the committed store_bind sample used the wrong path.

   Smallest fix: declare and require the intended backend detector path for each store variant. Track the execution of each required fault operation separately from preparation, with markers inside the operation's execution branch. Add this wrong-path substitution as a negative control.

3. Two edits name an enclosing function instead of their lexical function.

   Claim: the lexical-function requirement is not implemented for nested functions.

   Evidence: dev/lean_core/parity/loop_parity.R:93 and :96 name lean_loop_publish for batch_fault and fault_before_append. Their anchor belongs to nested tick(), at dev/lean_core/loop.R:866. dev/lean_core/parity/loop_edits.R:37 searches the parent's entire line span, including descendant function bodies. contract_probes.log confirms `Parent-named edit accepted inside nested child: TRUE` using a minimal parent/child example. This conflicts with tickets.yml:4637's explicit lexical-function requirement.

   Consequence: naming a parent does not enforce the promised lexical anchor boundary; these two current registry entries do not satisfy it.

   Classification: missing acceptance item.

   Smallest fix: name tick for those edits and require the anchor's innermost lexical function to equal the declared function. Keep the existing missing-function and unique-anchor refusals.

4. The shortcut experiment rotates seven arms instead of alternating comparison pairs.

   Claim: the shortcut observations do not follow the paired alternation required by R3 and tickets.yml:4638.

   Evidence: dev/lean_core/parity/loop_shortcuts.R:150 rotates the entire seven-arm order; :168 pairs observations afterward by round. audit_evidence.log reconstructs order from the committed raw CSV. For shortcuts versus ctx_dollar the seven pair orders are `S-D, D-S, S-D, S-D, S-D, S-D, S-D`; for gross they are `S-D, D-S, D-S, D-S, D-S, D-S, D-S`. These are not alternating pairs. The evidence at tickets.yml:4646 honestly calls the method rotated rounds, but that is not the accepted method.

   Consequence: order and drift are imbalanced within the individual comparisons, including gross exposure near the two-percent threshold. Correct arithmetic on these observations does not satisfy the prescribed deletion experiment.

   Classification: missing acceptance item, not an arithmetic error in the shortcut CSVs.

   Smallest fix: measure each all-shortcuts/delegation comparison in at least five pairs, reversing the two-arm order each pair, with the other specified conditions retained. Recompute decisions from those observations. No timing was run during this review.

5. Missing cost cells are reported as zero instead of unresolved or failing.

   Claim: the cost map's strategy split accepts missing cells, contrary to LDG-3221's explicit missing-cell and resolution rules.

   Evidence: tickets.yml:4671; dev/bench/v0_2_3_lean_tuning_profile/cost_map.R:299 substitutes zero for an absent cell. check_cells() at :235 checks duplication and sums, but no required-cell census or measurement resolution. The committed cells.csv lacks strategy: call wrapper for lean 1166x252 and pin 1166x252/500x1260; strategy_split.csv:3, :7 and :9 publish zero for it. Lean 1166x252 also lacks P1 and E advance samples, and lean 500x1260 lacks E advance. contract_probes.log shows that a map containing only P3, with every strategy cell and other stage absent, returns `check_cells = ok`. The summary calls the 26-sample wide lean result rough, but does not mark these cells unresolved.

   Consequence: the requested complete strategy split and per-stage measurements are not established on all shapes. An unobserved cost is presented as a measured zero; normalization of the cells that remain makes the sum check insufficient.

   Classification: missing acceptance item and unsupported zero-valued evidence. The inclusive-body arithmetic for observed own-work and ledgr-callee cells does reconcile.

   Smallest fix: define the required cells for each arm, retain zero sample counts explicitly, and distinguish an unresolved estimate from a structural zero. Fail the item on missing cells as specified, or record insufficient resolution as unresolved. Obtain adequate observations before claiming a complete map.

6. One published loop residual exceeds the acceptance limit.

   Claim: publishing the residual does not satisfy the below-ten-percent item.

   Evidence: tickets.yml:4667 requires unattributed loop time below 10 percent. inst/design/ledgr_v0_2_3_spec_packet/cut_review_14_rereview_1.md:16 expressly retains that gate despite the residual-publication rule. dev/bench/v0_2_3_lean_tuning_profile/results/cost_map/reconcile.csv:7 reports 0.170212765957447 for pin 1166x252, or 17.0213 percent. summary.md and tickets.yml:4677 disclose it correctly. contract_probes.log confirms that the committed map nevertheless passes check_cells().

   Consequence: this measurement acceptance item remains open. Honest disclosure is necessary but is not a waiver.

   Classification: missing acceptance item, not false reporting of the residual.

   Smallest fix: attribute enough of that residual to reach the accepted limit and retain the remainder, or leave the item open for an explicit maintainer disposition. Do not absorb it into E.

7. The timed H1 bare arm differs from the computation checked for equality on short eligible runs.

   Claim: the code can admit an eligible input for which its timed bare arm omits an SMA that its checked arm and the pin compute.

   Evidence: dev/bench/v0_2_3_lean_tuning_profile/features_h1.R:81 classifies a single usable run as simple without a minimum length. The checked bare_row() at :98 computes each SMA when length >= that SMA's n. The timed bare_simple() at :127 instead computes both only when length >= 10. Thus an eligible run of length 5 through 9 passes the SMA5 value check but does no SMA5 work in the timed bare arm. R/history-features.R:374 uses each definition's own stable_after. The committed aggregate features_h1.csv does not report counts by eligible run length. Whether any of its 582 simple instruments has this shape is unverified; the private script and inputs were not executed or accessed.

   Consequence: the equality check does not certify the computation actually timed for every input allowed by the script's classification. The effect on the committed 0.17-second timing is unverified.

   Classification: missing matched-computation acceptance item; no demonstrated wrong answer on the committed private workload.

   Smallest fix: use independent length guards for SMA5 and SMA10 in the timed arm, preferably sharing the checked calculation. Have the authorized executor report an aggregate short-run count and refresh affected timings if that count is nonzero.

8. The final timing evidence gives an incorrect improvement range.

   Claim: the stated upper bound of 1.4 percent does not match the cited median clocks.

   Evidence: tickets.yml:4647 says `0 to 1.4 percent faster on every clock and shape`. dev/lean_core/parity/evidence/loop_final_summary.csv:2 gives whole-run medians 3.45 versus 3.51 seconds: (3.51 - 3.45) / 3.51 = 1.7094 percent. :4 gives 3.83 versus 3.89, or 1.5424 percent. audit_evidence.log recomputes all nine median improvements from the committed values.

   Consequence: the narrative range is false, although the clocks support the no-regression conclusion.

   Classification: false numerical evidence.

   Smallest fix: correct the range to approximately 0-1.7 percent when describing ratios of those medians; keep this distinct from median paired savings.

Checked:

- Read Cut 14, workstream 31, both tickets and LDG-3219 context, all three cut-review files, WS16 compact-state points 1-6, interface Section 19, the checklist, relevant strategy/reproducibility/feature contracts, governance rules and the seven optimization shapes. Independently checked the measurement inputs against the fixture, production strategy/context code and production history-feature calculation. The accepted portable crossover shapes, fixed pin and separate private empirical classification are appropriate inputs for this measurement scope; the findings above concern execution of that accepted method.
- Read the whole requested diff. Compared 4a3e08b8's loop.R statement by statement with the candidate. Valuation, callback/error handling and precedence, target checks, planning/affordability stop, fill application, capacity/commit/reconciliation/state-update ordering, max_pulses, transaction handling and terminal transfer are preserved through the extraction. No original semantic statement or debug obligation was found lost or reordered. New stage-local bindings and return lists carry the old values between stages. run_loop holds orchestration. The interface structure paragraph matches. loop.R has no harness record or variant branch. Reproduced loop_moves.R: all six debug sites remain debug-only, moving to P2/P3/P5 as recorded; all twelve hooks sites remain in their original named owners. Reproduced the role count: 989 code lines = 880 production + 109 debug, and 217 harness lines.
- Compared the 106 freeze rows and 128 variant manifest rows with the pre-cut records: exact matches, 23 variants, no retirement. Important provenance detail: the evidence for code 4a3e08b8 was committed in 5ffedb96 and is present at 6e84e602; the evidence files literally stored at commit 4a3e08b8 are older. No loop, harness, workload or parity code changed between 4a3e08b8 and 6e84e602. Compared all committed gate, batch-one and inert paths against that freeze: 43 workloads/843 tables in each debug mode, 14/216 at batch one, and 6/92 inert, all identical with matching paths. The 128 variant rows are present and say CAUGHT; registry faults, witnesses and recorded conditions were inspected. These counts reproduce, subject to findings 1-3 about what the gate proves.
- Executed small original-candidate parity samples with the pinned library: debug off crossover_3x40, witness_state_container and witness_zero_pulses (60 tables); debug on, batch bound one, crossover_3x40, witness_capacity, witness_prefix_reads and witness_state_refusal (60 tables); inert debug-on crossover_3x40 (16 tables). All were identical. Reproduced fill_price_ulp, hold_position and store_bind on crossover_3x40: each CAUGHT for its intended fault. Reproduced both controls: UNRELATED and UNREACHED, each exit 1. Reproduced the inert fill-price demonstration: 13 of 16 tables differ with the accounting refusal; it exits 1 as NOT RUN because inert hooks record zero folds, as the evidence already explains. This is a detector demonstration, not a passing manifest invocation.
- Read all shortcut/delegation arms and clocks. They use the specified pin delegation, compilation, debug-off setting, inert hooks, fresh snapshot copies, warm-up and GC policy. The pulse clock is one outer clock excluding setup/transfer. Recomputed every saving, threshold count and decision from the committed raw CSVs. The five keep decisions and state-view unresolved decision follow the implemented resolution rule. State-view counts 6/7, 7/7 and 5/7 below two percent are reported correctly; no deletion or retirement occurred. The final comparison loads both baseline files from 4a3e08b8 in the same process and, with two arms, does alternate order. All final clock medians reproduce and show no median regression or displaced regression. No historical performance was independently remeasured.
- Read cost_map.R, cost_rank.R, features_h1.R and summary_check.R. Cost-map fixture, seed, fresh store history, warm-up, debug and compilation policy match between arms; initial verified snapshot open is clocked separately. Unprofiled clocks are separate from Rprof attribution. Stack attribution assigns one cell per sample, takes strategy work out of P2, leaves result checks in P2 and state validation in P5, and does not add the strategy subtotal twice. Both normalizations and their separately published loop-estimate/clock ratios reproduce. All 32 clock medians reproduce from clock_raw.csv, with one result digest per shape across arms/repetitions. The pin's loop clock includes per-pulse writes, as disclosed. Replay uses the unchanged strategy, fresh real contexts, plain values materialized outside the timed call, unchanged pre-call state and parameters, and complete target/state-return comparison; committed replay rows all report identical returns.
- Ran cost_map.R --selftest=1 on its small 3x40 shape. First attempt failed before the rejection checks because the lean profile captured zero loop samples (cost_selftest.log). A fresh retry completed and rejected both the replay mismatch and duplicate cell (cost_selftest_retry.log). That retry also accepted a zero lean loop clock and an infinite estimate/clock ratio; it is a rejection demonstration, not usable timing evidence. Ran summary_check.R: `23 table rows checked, 0 missing; H1 sentence ok`. Manually checked the remaining summary aggregates, percentages, replay figures and historical floor figures. Summary table numbers reproduce; finding 5 limits the interpretation of missing cells.
- Inspected H1 classification against production bounds, expected masks, usable runs, carry and terminal handling. Both full-row SMA/NA checks precede interpretation of the simple-row comparison; full-H1 pin timing is separate, and omitted evidence/causality work is named. The aggregate CSV is internally consistent: 1,166 instruments = 582 simple + 527 terminal exclusions + 57 carried-input exclusions; sessions, bounds, pass flag and timings match the summary. The switch from W1/953338df to the LDG-3215-prep store and claimed rebuild-required reason are explicitly disclosed in the ticket and summary. Actual private input identity, that refusal, private timings, cleanup and all private console/scratch output are unverified.
- Scope is contained: no R/, tests/, DESCRIPTION, NAMESPACE, dependency, store-format or public behavior change in the diff; no tuning or new production coverage. No vendor data, package archive, Rcheck tree, coverage.html or Rplots.pdf was added in the reviewed diff. The seven-shape walk found no new loop over growing product collections or new frame/JSON/validator shape introduced by the extraction; the existing operations and buffers remain. No tracked file was edited and no commit was made.

Not checked: no timing window, shortcut timing run, full parity gate, full variant manifest, full cost map, test suite, package build/check, new memory measurement or private H1 execution. No E:, ledgr-research or vendor-data access. Historical timing truth beyond code/CSV consistency, runtime affinity and the exact dirty working-tree bytes used for the old cost-map run were not independently verified. Probe commands, exit statuses and outputs are retained in this output directory; all R scratch output was redirected beneath it.
