CHANGES_REQUIRED

Mode: focused Type 1 re-review 1 of workstream 44's close, Cut 24 stage 3, dropped; independent fresh session, 2026-11-26. Reviewed 8098c752..23ee4504 at detached HEAD 23ee45047b0507cecea3c624f1aa31ad091a77b4.

F1 and F3 are resolved. F2 is substantially corrected but still uses an unverified original figure as measured planning input. The new close-review summary also overstates what round 1 independently reproduced. These are record corrections; the accepted negative timing evidence, DROP disposition and product rollback remain undisturbed. No further timing attempt or product change is requested.

Repository references are relative to C:/Users/maxth/ledgr-wt/ws44-close-rereview. Below, tickets.yml and macro_plan.md mean the files in inst/design/ledgr_v0_2_3_spec_packet/; round1 means inst/design/ledgr_v0_2_3_spec_packet/ws44_close_review_round1.md; P means dev/bench/v0_2_3_cut24_feature/probes_ldg3265/. Historical source references name their commit explicitly.

F1: RESOLVED.

The original named exception at tickets.yml:8330 is byte-for-byte unchanged from 8098c752. The corrected result at tickets.yml:8333 distinguishes the required-field finiteness pass and per-definition reduction from the knowledge-range, expected-session and terminal checks that stayed inside the instrument/range loops. The disposition at tickets.yml:8338 explicitly says the full admission matrix was neither implemented nor measured and grounds the drop in decision 7's simplify-or-drop authority and the three valid failing records. The qualification also appears in workstream 44's close_review at tickets.yml:4407.

That description matches b56eaee9:R/history-features.R:425-439 (field finiteness and definition reduction), :564-566 (one matrix before the loop), :572-577 (ranges and masks inside the loop), :580-584 (final admission), and :417-418 (expected coverage and terminal assertion checks).

The added zero-cell reading is correct and explicitly labelled "Reading ... (not a measurement)" at tickets.yml:8338. The fixture removes the middle bar from every instrument (dev/bench/timing/protocols/cut24-feature-1/workloads.R:85-103); its SMA definitions require close (:57-60). Each definition's full-slice finiteness is therefore false under b56eaee9's reduction. The cited :579-584 is the correct range for the short-circuit guard and gate call: no zero-fixture instrument reaches the gate. A custom-only preparation skips the matrix at :563-566 and the gate at :580. This reading does not say mask construction vanished: masks are still built at :577 for the general path. It establishes no component timing.

F2: NOT FULLY RESOLVED. Required remainder: distinguish unsupported first-session observations from the fresh measurements and stop routing the former as measured input.

The new record meets the record rule's identification requirements (inst/design/rfc_cycle.md:304-308): P/README.md:12-25 names fixtures, library/source identities, environment and clock; :29-32 gives the command and run date; P/host.txt:1-4 records the timestamp, R/platform and power plan. The four scripts explain and implement the probes: P/run_probes.R:25-29 dispatches them; P/pieces.R:17-22 defines its block medians; P/zero_components.R:19-48 defines component timing and scope; P/swap.R:20-40 loads the named historical function sets and :49-60 implements twelve rounds of five calls. The record honestly says these are fresh runs of equivalent scripts, with the original scratch outputs unavailable (P/README.md:6-8). The links from tickets.yml:8329, :8332 and :8335, macro_plan.md:700, and dev/feature_parity/evidence/ldg3266/shapes.md:13 reach that record.

The committed fresh results support the replacement figures:

| Quoted result | Supporting output |
| --- | --- |
| Zero compute: base 0.583-0.600 s, candidates 0.583-0.590 s; custom compute: base 0.400-0.417 s, candidates 0.417-0.423 s | P/pieces.txt:1-12; summaries in P/README.md:36-39 |
| Finiteness about 2 ms, gate over 500 instruments about 7 ms, masks about 97 ms, ranges about 3 ms | P/zero_components.txt:1-5; P/README.md:42-45 and tickets.yml:8329, :8332 |
| Swapped-function zero compute: base/candidate/hybrid 0.583/0.599/0.592 s; custom 0.436/0.433/0.427 s | P/swap.txt:2-4; P/README.md:46-49 and tickets.yml:8329 |

The 16 ms zero difference reasonably supports the explicitly descriptive "about 15 ms" reading in P/README.md:55-59. The gate/finiteness figures are measurements on ffe19415, not measurements of b56eaee9's zero-cell gate execution. The record correctly keeps the cause unproved and the custom cause unexplained (tickets.yml:8329, :8335; shapes.md:10-15). The cross-library A/A is now described as a control on its sampled cells, without a causal exclusion claim (tickets.yml:8329). All three failed records and DROP remain at tickets.yml:8327-8338.

The 570/590 ms interpretation is withdrawn in the current evidence: tickets.yml:4407, :8329 and P/README.md:40-41. It is gone from the current macro-plan and shapes figures. Its remaining occurrence in round1:21-27 records the historical finding and need not be rewritten.

The unresolved part is narrower:

- Claim: the first session measured about 80 ms for masks, and the fresh record establishes the routed range of 80-100 ms. P/README.md:44-45 and tickets.yml:8332 retain the first-session figure; macro_plan.md:699-701 and shapes.md:16-17 use 80-100 ms as a descriptive measured planning input.
- Evidence: P/README.md:6-8 says the original outputs were not kept. The committed component output has one mask result, 96.66667 ms (P/zero_components.txt:4). It does not establish an observed 80-100 ms range. P/README.md:50-51 also introduces the old zero 0.593/0.606/0.594 and custom 0.437/0.431/0.435 figures as corroborating a "same pattern", although P/swap.txt:2-4 contains only the fresh figures. These original observations are not explicitly marked unverified. Round1:27 expressly requires that treatment when the original record is unavailable; calling a number descriptive does not supply its missing provenance.
- Consequence: the fresh measurements are independently reviewable, but an unverified historical component figure still feeds the future-work record. The original custom/zero numbers also appear as empirical corroboration without their original record. This does not affect the drop.
- Exact change: mark all retained first-session component/swap figures as "unverified original observations; original record unavailable", and remove their use as corroboration or established measurements. Alternatively, omit those figures. In macro_plan.md:699-701 and shapes.md:16-17 replace "80 to 100 ms" with "about 97 ms on ffe19415 in the fresh descriptive probe, with compute about 0.6 s" and retain the probe pointer. In tickets.yml:8332 keep the supported fresh 97 ms result and either remove the 80 ms parenthesis or label it unverified. No new measurement is needed.

I reran zero_components.R once against the named read-only ldg3265-ffe19415 library. It emitted all component results: finiteness 0 ms at this clock resolution, gate 6.666667 ms, masks 83.33333 ms, ranges 6.666667 ms. This supports the order of magnitude and the stated coarse-resolution limitation, not a reproducible exact 2 ms finiteness cost. The output is C:/Users/maxth/ledgr-wt/ws44-close-rereview-out/zero_components_review.txt. Locale startup warnings were captured and PowerShell reported exit 1 despite the complete numeric output; I did not repeat the run or treat it as a clean exit. This review observation does not replace the missing original committed record.

The review rerun used the unchanged script at 23ee4504, its elapsed proc.time() block-median clock and debug-off setting, on this Windows host. The power plan was observed as Balanced after the run and was not changed by this review. Command:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" C:/Users/maxth/ledgr-wt/ws44-close-rereview/dev/bench/v0_2_3_cut24_feature/probes_ldg3265/zero_components.R --lib=C:/Users/maxth/ledgr-wt/cut24-scratch/libs/ldg3265-ffe19415 --repo=C:/Users/maxth/ledgr-wt/ws44-close-rereview > C:/Users/maxth/ledgr-wt/ws44-close-rereview-out/zero_components_review.txt 2>&1
```

F3: RESOLVED.

All current descriptions of the retained harness make the requested distinction: tickets.yml:8359, dev/feature_parity/evidence/ldg3266/COMMANDS.md:28-34, dev/feature_parity/README.md:156-168, and the new close_review at tickets.yml:4407. gate_expected, calculated_count and the 63 added corpus cases are active. Only direct-path gate/shadow observations, prep_direct work and the conditionally skipped stage-3 faults are described as inactive. The README preserves the explanation of empty observations and skipped faults. I found no remaining blanket "inert" description in the current close evidence; round1's quotation of the old wording is historical evidence.

N1. Required new finding: the close-review summary overstates independent reproduction.

Claim: round 1 confirmed the rollback with "every proof reproduced" (tickets.yml:4407, newly added).

Evidence: round1:51 explicitly says the full-suite/check scripts and saved outputs were read, not rerun. Round1:53 also says the complete fault driver and rejected candidates' full parity/debug/gut runs were not rerun. Round1:39, :43, :45 and :47 identify the statistics, identity/count/census and final differential checks that were independently reproduced. The report supports substantial independent verification, not the universal claim.

Consequence: the authoritative review summary attributes stronger independent execution evidence to round 1 than that review records. This is a reporting inconsistency, not a new failure of the saved proofs.

Exact change: replace "every proof reproduced" at tickets.yml:4407 with "timing statistics and focused final-library proofs independently reproduced; full-suite/package-check and some candidate/fault evidence inspected from saved records". Leave the round-1 report unchanged.

N2. Advisory new finding: clarify what the piece probe compares.

Claim: "engine version and projection equal" (P/README.md:39).

Evidence: P/pieces.R:32-39 records their execution times, without comparing version strings or projection objects. P/pieces.txt:1-12 reports version timings of 0.0230-0.0250 s and projection timings of 0.0067-0.0100 s. Those timings are broadly comparable at the declared coarse resolution, not literally equal. The phrase also invites an unintended claim about engine identity.

Consequence: the result summary is ambiguous about whether it establishes equal identities, equal values or comparable costs.

Exact change: replace the phrase with "engine-version computation and projection costs are broadly comparable at this probe's resolution". No additional probe is needed.

What I checked: the complete correction diff; the round-1 exact changes; workstream 44's new close_review and LDG-3265/3266 evidence; all nine files in P; the named harness descriptions, shapes record, macro-plan bullet, historical b56eaee9 source, relevant ffe19415 mask helper, shared fixture definitions and the record rule. I independently checked that the original exception text is unchanged and that the diff contains no product or test changes. The fresh diagnostic inputs are appropriate for these component claims; they are not new retention gates. The new probe pointers in tickets.yml, macro_plan.md and shapes.md resolve to committed files. Git reported no tracked or staged changes at the end. Git's ownership check was handled with a separate config in the output directory, without changing repository or user configuration.

What I did not check: I did not reopen round 1's confirmed retention statistics, rollback, identities or public semantics. I did not run the timing harness, swap.R, the whole probe driver, parity/fault suites, new memory measurements, the full test suite or R CMD check. I did not access E:, ledgr-research or vendor data. Installed libraries were read only. No tracked file was edited and no commit was made; review helpers and output were written only under C:/Users/maxth/ledgr-wt/ws44-close-rereview-out.
