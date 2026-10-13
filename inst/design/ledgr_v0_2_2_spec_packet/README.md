# ledgr v0.2.2 Spec Packet

**Status:** Cuts 1 through 13 are closed. Workstream 27's final focused Type 1
re-review returned `PASS` at `fa41283d`, and the maintainer accepted it on
2026-10-13. LDG-3019's rule-3 encoder and refusal boundary and LDG-3020's
process-local verification reuse are complete. The correction fast lane passes
566 of 566 blocks in 110.04 seconds. Final full-matrix run 38371833556 is green
on both Ubuntu jobs and Windows: the rule-3 roots, ordinary and isolated-CRAN
profiles, R CMD checks and the 87.25 percent coverage gate all pass. The
checked-in post-residue fast record keeps its 131.70-second loaded-host timing
miss; the reviewer's three alternating scratch pairs measured 108.04 seconds
at `fa41283d` against 107.84 seconds at the preceding tree. Workstream 28's
focused Type 1 re-review returned `PASS` at `901325af`, and the maintainer
accepted it on 2026-10-13. LDG-3021's singleton-fingerprint persistence,
reopen and promotion repair is complete. Its two correctness-clean
P-core-pinned record sets missed the unchanged 112-second gate by 1.91 and
3.05 seconds at their medians. The accepted exception keeps those records as
failures, leaves the bound unchanged and moves no tests ahead of next-version
fold-core unification. Final Cut 13 review accounting is 6 invocations over 3
tickets, 2.000 against the 0.5 gate, recorded as a historical breach.
Accepted Cut 14 now owns the pre-CRAN legacy-removal synthesis and the macro
plan's codebase-hygiene amendment. Its fourteen tickets across three
workstreams passed cut review after patches on 2026-10-13. Implementation
opens with the report-only LDG-3022 census.

This packet is the durable home for the v0.2.2 release plan. The release goal,
scope boundary and dependency structure are recorded in `macro_plan.md`. That
plan does not authorize implementation and does not replace an accepted RFC,
contract or research finding.

`tickets.yml` is the sole ticket and sequencing authority. Independent cut
review and maintainer acceptance open a cut's first workstream; this README
only summarizes the packet state and does not become a second editable ticket
ledger.

## Current artifacts

- `macro_plan.md`: maintainer-level release scope, dependency order, cut
  strategy and definition of done.
- `design_memory_overhaul_plan.md`: proposed Markdown architecture, lifecycle
  rules and migration plan for the v0.2.2 design-memory workstream. The
  maintainer accepted it for Cut 1 on 2026-10-03.
- `contract_census.md`: the bounded LDG-2923 migration input and LDG-2924
  reconciliation; it is evidence, not a replacement contract.
- `horizon_migration_reconciliation.md`: the LDG-2931 classification,
  obligation sweep and LDG-2932 body/redirect reconciliation; it is migration
  evidence, not authority or a backlog.
- `../roadmap_history.md`: the verbatim planning tail displaced when LDG-2933
  reduced the roadmap to its maintained sequence; it is historical context,
  not current scope or sequencing authority.
- `design_memory_overhaul_closeout.md`: the accepted LDG-2934 evidence
  reconciliation, least-machinery decision and six-scenario navigation walk.
- `decision_catalogue_reconciliation.md`: LDG-2925 row-by-row migration
  evidence for the two retired catalogues; it is not a decision index.
- `../README.md`: the LDG-2926 short front door for current authority and
  task-oriented routes.
- `../rfc/README.md`: the LDG-2929 current RFC pipeline for active, due,
  deliberately parked and accepted-obligation work.
- `tickets.yml`: sole ticket and sequencing authority. Cuts 1 through 13 are
  closed. Accepted Cut 14 contains Workstreams 29 through 31 and LDG-3022
  through LDG-3035. The preparatory Workstream 31 slice is complete through
  LDG-3023. A Type 1 checkpoint returned CHANGES_REQUIRED; commits d85ec87e
  and a8416492 correct the census and lint records, with confirmation folded
  into Workstream 29's close review. Workstream 29 is implementation-complete
  and awaits Type 1 review; its unchanged 112-second fast gate currently has
  a recorded 114.28-second P-core median and requires explicit adjudication.
- `terminal_outcomes_reconciliation.md`: LDG-2961 index mapping every
  terminal-outcomes synthesis rule and gate case to one ticket, block and
  contract section.
- `writer_scaling_closeout.md`: accepted Workstream 6 record for the shipped
  fill-event flush and diagnostic-sequence repair.
- `feature_accessor_scaling_closeout.md`: agent-provisional Workstream 7
  record for the accepted prepared feature accessors and exact explicit-map
  memoization.
- `current_store_format_closeout.md`: agent-provisional Workstream 29 record
  for schema 119, the marker-pair gate and strict catalogue validation.

## Cut 1: Design-memory authority and discoverability

Authority: the accepted `design_memory_overhaul_plan.md`, macro-plan WS0 and
the accepted governance synthesis D4 through D7.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 1 Contract authority baseline | LDG-2923-2924 | bounded contract census; safe header, reference and H2 navigation normalization | contracts can become the normative current-release source without losing a packet-only rule or making a code defect authoritative |
| 2 Front door and decision bridge | LDG-2925-2927 | one temporary bridge, short front door, pending and partial-supersession links | current and accepted-pending answers are reachable within two links without a second authority or state ledger |
| 3 RFC pipeline and obligation routing | LDG-2928-2929 | amend both stage-9 passages; pipeline active, due, parked and open-obligation work | every accepted unscheduled obligation has exactly one operational home and speculation remains non-binding |
| 4 Horizon migration | LDG-2930-2932 | search before moving; classify and route; then preserve bodies behind exact-heading redirects | nothing is deleted, every old link resolves and no binding obligation remains hidden in parking prose |
| 5 Current context and closeout | LDG-2933-2934 | compact roadmap and AGENTS context; reconcile consumers; scenario-based closeout | the repository describes one current state and its normal answers are human-discoverable without reconstructing history |

The workstreams are serial and each receives one Type 1 close review. Together
with the completed combined Type 1 and Type 2 cut review, the planned review
count is six invocations over twelve tickets, exactly 0.500. That review
returned `PASS_AFTER_PATCHES`; its bounded corrections are incorporated. A
correction review is recorded honestly rather than hidden by merging or
padding work.

The Workstream 5 close review was invocation seven and its focused re-review
was invocation eight. The actual count is therefore 8/12 = 0.667. The
historical breach is recorded rather than repaired by adding tickets or
combining reviews.

The maintainer accepted Workstream 5 and closed Cut 1 on 2026-10-03 after the
record-only correction at `79363fb`, without a ninth review invocation.

This cut changes no package behavior. Other v0.2.2 product, optimization and
RFC work remains outside it and may be cut separately after its own authority
is ready.

## Cut 2: Proven long-window optimizations

**Status:** Closed. Independent review returned `PASS_AFTER_PATCHES`; its
bounded ticket corrections are incorporated. The maintainer accepted Cut 2
on 2026-10-03 and accepted its last workstream on 2026-10-04. Workstream 9's
Linux DST repetition remains a pre-release confirmation on the next push.

Authority: macro-plan WS1 for all mechanisms; the maintained roadmap's opening
optimization row additionally authorizes the writer and accessor tickets but
not the strict-feature ticket. Evidence comes from the fold-writer/accessor
spike, the long-window scaling record and the accepted exact-parity
internal-optimization proof template.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 6 Writer scaling | LDG-2935-2937 | per-pulse fill flush; conditional constant-time diagnostic sequence; closeout | scale-growing writer work is removed with exact outputs, ordering, resume and existing failure behavior |
| 7 Feature-accessor scaling | LDG-2938-2940 | prepared scalar lookups; validate-once and exact run-local last-map memo; closeout | repeated accessor work disappears without changing values, errors, validation, workers or isolation |
| 8 Built-in strict-feature acceleration | LDG-2941-2942 | accelerated path for ledgr SMA and returns only; closeout | values and NA masks remain exact while repeated frame, validation and dispatch work is removed |
| 9 Availability fact scaling | LDG-2943-2945 | vector session construction; linear membership resolution; closeout | exact fact rows, evidence, errors, ordering and snapshot identity survive the scaling repair |

Workstream 8 implementation is `9bde734` plus the exact-SMA correction
`11bd294`; its agent-provisional record is
`strict_feature_acceleration_closeout.md`. The corrected reproducible
50-instrument by 500-pulse gate measured 34.7-40.7% cold-run savings and exact
public outputs. The first close review disproved the original
`rowMeans(embed())` identity claim. Its focused correction review is Cut 2
invocation 7/11 = 0.636, recorded as a historical review-gate breach.
The maintainer accepted the workstream after that `PASS`; no redundant eighth
review was counted.

Workstream 9 implementation is `b272967`, `de7f4e3`, `a5443f3` and the
bounded fast-witness correction `9f807ec`; its accepted record is
`availability_fact_scaling_closeout.md`. The 10,473-date session record
measured 13.62x in UTC and 30.39x in New York. Public membership resolution at
300,000 rows fell from 9.75 to 4.67 seconds with exponent 0.941 and exact
rows and evidence. The correction fast record passed 506/506 blocks in 89.03
seconds. Its Type 1 close review returned PASS and the maintainer accepted the
workstream on 2026-10-04. Shrinking the redundant semantic fixture explains
only about two seconds of the gate reduction; the 29 to 31 second anomaly in
the failed record disappeared for unknown reasons and is not attributed to
this workstream. Linux CI repetition remains external until the branch is
pushed.

The four workstreams are independent after cut acceptance. Each candidate
starts with a current-tree baseline, semantic oracle, failure-sensitive
structural detector and preregistered materiality threshold. A candidate that
misses its gate closes as measured and rejected; it does not acquire production
changes merely because an older spike looked promising.

One combined Type 1 and Type 2 cut review plus four Type 1 close reviews is five
planned invocations over eleven tickets, 0.455 against the 0.5 gate. Without
the four owned evidence closeouts it would be 5/7 = 0.714; the closeout tickets
are retained because each produces the independently reviewable evidence for
one workstream, not to pad the denominator. Correction reviews count and any
breach is recorded rather than repaired by padding.

The cut authorizes no public API, schema, run or snapshot identity, snapshot
hash, tolerance, default, persistence contract, verification-policy or
failure-semantics change. The availability feature-engine provenance digest
must change when its implementation body changes; that expected digest update
and its compatibility disclosure are not a public identity change. The cut
excludes custom, external and TTR indicator semantics, db_live and compiled
accounting behavior, snapshot-verification redesign and every candidate that
fails its gate.

## Cut 3: Exact fact-integrity verification

**Status:** Closed after independent Type 1 `PASS` and maintainer acceptance
on 2026-10-04. LDG-2946 committed the pre-change exact-byte, identity, reopen
and corruption oracles. LDG-2947's internal, public and calibrated
low-repetition gates all passed; LDG-2948 implemented and reverified the
bounded candidate at all three gates. LDG-2949's accepted record is
`fact_integrity_verification_closeout.md`. Independent spike review passed
the fact-integrity result and invalidated the DuckDB membership result.

Authority: macro-plan WS5, the reviewed fact-integrity spike and the accepted
exact-parity internal-optimization proof template. The corrected membership
spike is future evidence rather than authority for this cut.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 10 Exact fact-integrity verification | LDG-2946-2949 | commit cross-family byte and corruption oracles; register internal, public-path and calibrated low-repetition gates; deduplicate timestamp formatting; close exact-parity evidence | canonical fact, bundle and rule-2 snapshot bytes and corruption failures remain exact while public resolution becomes materially faster without materially regressing low-repetition families |

The DuckDB workstream was removed rather than patched inside this cut. Its
candidate chose tied complete headers under SQL byte collation while the
retained resolver uses R locale ordering, so the exactness premise failed. A
corrected spike must choose the boundary under the resolver's ordering, use a
too-late gut, narrow its scope guard and rerun after Workstream 10. It may then
support a later cut; no small-history fallback is presumed without evidence.

One cut review plus one workstream close review is two planned invocations over
four real tickets, exactly 0.500. The completed independent spike review is
evidence qualification rather than a ticket-review invocation. No separate
cut evidence essay is planned. The pre-implementation split is substantive
only because LDG-2946 commits its own tests, claim and machine-readable oracle
record before LDG-2947 begins.

The close review returned `PASS` at `ff995ae`; the maintainer accepted the
workstream without a correction round. The actual count is 2/4 = 0.500.

Cut 3 changes no public API, schema, canonical bytes, hash or identity rule,
verification policy, condition class, provider-run behavior or resolver
authority. It adds no index and authorizes no general migration to DuckDB.
It also does not absorb the other WS1 residuals: whole-universe alias reads
remain with macro WS3, post-semantics indicator work with WS4, and a newly
measured direct typed fill-payload spike with WS8.

## Cut 4: Long-window regression evidence

**Status:** Closed and accepted by the maintainer on 2026-10-04. The first
Type 1 close review returned `CHANGES_REQUIRED`; the focused re-review passed
all four corrections.

Authority: macro-plan WS8's early long-window baseline and regression-suite
item, the accepted Cut 3 tree and
`long_window_cut3_baseline.md`.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 11 Long-window regression evidence | LDG-2950 | fixed local availability shapes; exact outcome and structural detectors; paired 10% comparison; one release-only large shape | later optimization cuts cannot silently regress long-window semantics, scaling shape or accepted host-relative timing |

The accepted-tree rerun removed the dominant cold strict-feature cost rather
than moving it elsewhere. Across 252 to 6,056 pulses, cold momentum runs are
2.76x to 11.67x faster than the 2026-10-02 record; warm runs and the flat
fact, terminal and width controls are stable or faster. A four-candidate sweep
fell from about 156 to 39 seconds and three-fold walk forward from 313 to 110
seconds. The current profile is led by fold execution, snapshot hashing,
persistence and finalization. Those observations route later work; Cut 4 does
not optimize them.

The corrected agent-provisional record compares `d08c8f4` with `ff04a32` in
five live alternating pairs per ordinary shape. It finishes in 627.47 seconds;
all six cold/warm median paired ratios are between 0.985 and 1.024 and all
normalized semantic outputs match. The feature-gap run records 1,347 fills
and 671 trades, and the two sweep candidates have distinct outcomes. The
accepted orientation arm reproduces 300 fills, 757 equity rows, 379,873
diagnostics and 757 decoded state rows. These are local regression facts, not
a public performance claim; maintainer acceptance has not occurred.

The ticket deliberately keeps machine clocks local. Hosted CI owns stable
semantic outcomes, the existing detector inventory and one missing public
linear-growth witness; it does not own absolute wall time. Performance compares
at least five live candidate/accepted pairs in alternating fresh processes,
with cold and warm gated separately. A ratio above 1.10 reruns once and stands
only if the retry also exceeds 1.10. Stored seconds are orientation, not the
denominator, and phase clocks diagnose movement without becoming thresholds.

The ordinary set is limited to about three availability shapes, including a
fact-heavy public resolver call and a two-candidate sweep. It uses never-held
terminals and in-budget gaps for `DONE` outcomes; held terminals and exhausted
gaps remain owned by the terminal-outcome decision. The full ordinary paired
suite has a 20-minute reference-host budget. EXP-0003 scale and walk forward
require an explicit release-only entry point and cannot be invoked from tests
or hosted workflows. Once accepted, the ordinary suite runs at every later
optimization-cut close and both suites run before release.

The cut review and two close-review invocations give 3/1 = 3.000, above the
0.5 review gate. The macro plan explicitly asks for one chore ticket, so the
record keeps the historical breach visible instead of manufacturing tickets
to improve the ratio.

## Cut 5: Durable-run preparation memory

**Status:** Accepted by the maintainer on 2026-10-04; Workstream 12 is
`review_pending`. The original one-ticket cut review returned
`PASS_AFTER_PATCHES`. On 2026-10-04 the maintainer adopted every patch and
widened the cut with LDG-2952. A focused review of that broadened draft
returned `CHANGES_REQUIRED`; its four bounded corrections are incorporated.
The readiness review returned `PASS_AFTER_PATCHES`; its three required wording
patches and recommended SMA/returns kind witness are incorporated here.
Implementation waits for maintainer acceptance and accepted Workstream 11.

Authority: macro-plan WS5's phase-memory prerequisite, WS8's residual
peak-working-memory item, macro-plan decision 5 for direct exact optimizations,
the partially promoted horizon entry
`2026-10-04 [infrastructure] Long-window memory and parallel workers`, and the
`dev/spikes/ctx_frame_views/` probe and churn findings.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 12 Durable-run preparation memory | LDG-2951, LDG-2952 | LDG-2951: the per-phase memory runner and trading plus dense oracles; release six dead hydration intermediates at their last read; skip the full-range persistence slice copy and the unused finalization read. LDG-2952: resolve strict built-in dispatch once per feature definition instead of once per instrument | a durable run stops retaining and recomputing preparation work with no remaining use; phase peaks are measured and attributed, LDG-2951 lowers peak child RSS by at least 10%, and LDG-2952 does not regress feature-phase peak or elapsed time; outputs and contracts are unchanged apart from the recorded availability feature-engine digest |

The churn attribution after the cut review found that peak memory is the
highest of the run's phases, not one block. At 757 sessions the fold reaches
593 MiB, feature series 529, hydration 452 and the run-start re-hash 427.
`ledgr_strict_builtin_kind()` re-fingerprints the built-in definitions on
every per-instrument call: about 1.26 GiB of allocation and about 12% of
sampled run time. LDG-2952 removes that. Per-pulse fold churn and the snapshot
re-hash stay with their owners, the next-release memory pass and the WS5
verification session.

The exploratory current-tree probe used 1,514 sessions, 600 physical
instruments, 500 members and three returns features. In two clean
fresh-process comparisons without forced collection, baseline peak child RSS
was 1,219.2 and 1,223.9 MiB; the lifecycle-only candidate measured 1,048.4
and 1,050.3 MiB, about 14% lower. Elapsed time was effectively unchanged.
Explicit garbage collection provided no further benefit and is excluded.

The exploratory runner had a post-run assertion defect after `ledgr_run()`
returned; reopening confirmed `DONE`. The draft therefore treats those clocks
as qualification evidence, not the accepted record. LDG-2951 first commits a
corrected runner, exact public-result oracle and preregistered thresholds. It
may change production only if source liveness and the current-tree gates pass.
The peak-RSS and elapsed gates use unmarked runs. Phase peaks use separate
paired marked runs with the same method in each arm, or non-perturbing external
RSS sampling aligned to phase timestamps. The persistence-on and
persistence-off variants must each pass the registered memory and runtime
gates.
The full-range projection slice and unused availability ledger read also have
call or query counters: restoring either discarded operation must fail its
detector even though public outputs would remain equal.

The cut preserves the execution-spec field set and changes no representation,
feature-persistence policy, cache, schema, run identity, hash, numerical rule
or failure behavior. The availability feature-engine digest changes, and
LDG-2952 records it as expected provenance, as Cut 2 did. Static pulse views
(scheduled for the next release), per-pulse fold churn, sweep and
walk-forward retention, parallel workers and worker defaults remain outside
this cut. LDG-2952 compares the committed post-LDG-2951 tree with a candidate
that differs only by the dispatch hoist. Three cut-review invocations and one
planned close review over two tickets is 4/2 = 2.000. That historical breach
is recorded rather than repaired by padding.

LDG-2951 is complete. Its five-pair record compares `55e817d` with `f8080a7`.
Median peak-child-RSS ratios are 0.8566 with persistence off and 0.8683 with
persistence on, while elapsed ratios are 0.9981 and 0.9991. Exact public
outputs and the dense witness match, the fast profile passed 513 blocks in
85.61 seconds, and the ordinary Workstream 11 suite remained below its 1.10
timing ceiling. LDG-2952 now uses this committed post-LDG-2951 tree as its
isolated baseline.

LDG-2952 is complete. Its isolated five-pair record compares `9896a71` with
`5f327a8`. Median elapsed ratios are 0.9466 with persistence off and 0.9504
with persistence on; separately marked feature-phase peak ratios are 0.9570
and 0.9568. Exact public outputs and the dense witness match. The availability
feature-engine digest changes as expected, while the dense digest and built-in
indicator fingerprints do not. The final fast profile passed 514 blocks in
87.22 seconds, and the ordinary Workstream 11 suite remained below its 1.10
ceiling. These records were submitted to the single Type 1 workstream close
review.

That Type 1 close review returned `PASS` at `26ac946` after independently
reproducing both gains, exact outputs, source-liveness and dispatch mutations.
Its required record correction narrows LCL-0155 to the two boundaries its
detector observes. The evidence now also names the fold as the peak-setting
phase and refreshes the LDG-2951 summary under the current checker. The actual
review count is 4/2 = 2.000. The maintainer accepted Workstream 12 and closed
Cut 5 on 2026-10-04 after record correction `4edd4b3`.

## Cut 6: Terminal outcomes and frozen holdings

**Status:** Closed on 2026-10-06 after maintainer acceptance of Workstream 15.
The terminal-outcomes synthesis was accepted by the
maintainer on 2026-10-05 after Type 1 final review returned
`PASS_AFTER_PATCHES` and both precision patches were applied. The combined
Type 1 and Type 2 cut review returned `PASS_AFTER_PATCHES` on 2026-10-05, and
its patches C1-C4 and P5 are incorporated (see `tickets.yml`, Cut 6). Stored
schema-1 runs stay readable but cannot be resumed, rerun or promoted under
schema 2. The Sharadar claim gate is now a standing release condition
(macro-plan Section 6, item 9). The maintainer accepted the cut on 2026-10-05
and Workstream 13 opened. Workstreams 13 and 14 were accepted on 2026-10-05 after their Type 1 reviews; the Workstream 14 review led to the maintainer's Type 2 amendment on scheduled corporate-action evidence (decision 9).

Authority: the accepted
`rfc/rfc_terminal_outcomes_v0_2_2_synthesis.md`, macro-plan WS2 and the current
contracts for shipped behavior until each accepted change is implemented and
consolidated.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 13 Terminal and valuation policy identities | LDG-2953, LDG-2954 | version-2 corporate-action and valuation policies; exact-label terminal maps; ordinary and frozen terminal defaults; frozen versus refuse exhaustion identity | both accepted policy surfaces are closed, versioned and identity-complete before execution consumes them |
| 14 Terminal and freeze execution economics | LDG-2955-LDG-2958 | lifetime-terminal dispositions and typed stops; freeze, resume and no-fill state machine; strategy reservation; frozen-terminal fallback; memory, durable and resume parity | a terminal or exhausted mark changes economic state only under the declared model and a known-dead holding never freezes |
| 15 Terminal outcome reporting and selection visibility | LDG-2959-LDG-2961 | terminal and valuation summaries, warnings and bounds; attempted and excluded candidate visibility; unchanged DSR panels; contract consolidation and conditional Sharadar claim gate | every assumption and refusal remains conspicuous through selection while completed-panel mathematics and the upstream adapter boundary remain honest |

The cut is deliberately serial. Workstream 13 closes identity before execution
stores or interprets it. Workstream 14 closes economic behavior before results
summarize it. Workstream 15 then binds ordinary reporting, evaluation and
standing contracts. The cut review plus three planned Type 1 close reviews is
four invocations over nine substantive tickets, 0.444 against the 0.5 gate.

The upstream Sharadar problem is not smuggled into ledgr. Until accepted
research-side evidence establishes how zero-volume carried rows are represented
and an end-to-end record passes, v0.2.2 may not claim that the reference
workflow ages those marks or prevents fills. The package behavior can still be
implemented and tested with vendor-neutral missing-bar fixtures.

No ticket adds a second execution engine, terminal-policy authority, valuation
plane or DSR rule. Queueing exits, OTC continuation, shorts and leverage,
exact-quantity settlement, fair-value models, assumption sweeps, stale-robust
statistics and a default stale horizon remain outside this cut.

## Cut 7: Feature-map read surface

**Status:** `PASS_AFTER_PATCHES` on 2026-10-06; all four cut-review patches are
incorporated and the maintainer accepted the cut. The feature-map read-surface
synthesis was accepted by the maintainer after Type 1 final review and its four
in-place patches. This cut is the first bounded implementation slice of
macro-plan WS3; point-in-time history remains outside it.

Authority: the accepted
`rfc/rfc_feature_map_read_surface_v0_2_x_synthesis.md`, macro-plan WS3 and the
current Strategy and Context contracts until LDG-2965 consolidates the
accepted changes.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 16 Feature-map read surface | LDG-2962-LDG-2965 | alias-first singular resolver; explicit-map refusal; mapped pulse-view identity; parameterized inspection; warnings, contracts and evidence | one prepared naming rule governs every singular read and explicit maps cannot silently redefine names, without adding a plural plane or changing feature values, identity or eligibility |

The workstream is serial. LDG-2962 establishes the runtime resolver and
warning boundary. LDG-2963 applies the explicit-map and wide-view rule.
LDG-2964 reuses the same resolution path for inspection. LDG-2965 then
consolidates contracts and teaching and closes the parity and performance
record. One cut review plus one planned Type 1 close review is two invocations
over four tickets, exactly 0.500 against the review gate.

The performance record is deliberately narrow. Three alternating triplets at
500 instruments by 1,260 pulses compare the pre-cut alias-bundle loop, the
candidate bundle loop and one singular plane read on the candidate tree.
Outputs must be exact. The preregistered candidate plane/loop ratio is at most
0.90 and the candidate/pre-cut loop ratio at most 1.05. The existing
Workstream 11 `feature_gaps` comparison remains the availability no-regression
gate. None is a general engine-speed claim.

Implementation through `de3180b` supplies the singular resolver, explicit-map
guard, parameterized inspection, standing contracts, public teaching and
checked-in performance records. Exact outputs hold across all three timing
arms. The preregistered retry passes at 0.625 for candidate plane over
candidate loop and 1.023 for candidate loop over pre-cut loop. The ordinary
Workstream 11 record passes all three shapes, with cold ratios from 1.000 to
1.045 and warm ratios from 0.994 to 1.037 against the 1.10 bound.

The first final fast series remains recorded as a failed gate: its 119.51
second median exceeded the unchanged 112 second bound, while a same-host
accepted pre-cut control took 140.55 seconds. A subsequent shape audit found
three bounded workstream costs: repeated character-map resolution, duplicate
inspection validation and an unnecessary full-run negative warning detector.
Commit `de3180b` removes them and adds failure-sensitive counters. Its justified
corrected-tree fast run passed all 530 blocks in 105.46 seconds, and the gate
checker passed run 1 against 112 seconds. The workstream is ready for Type 1
close review; neither timing record is presented as a general speed claim.

That review returned `CHANGES_REQUIRED`: quiet pairs showed the accepted retry
had hidden a roughly 6% bundle-loop regression, and the memo contract still
named concrete feature-map objects only. Commit `d72a73b` removes redundant
singular resolution inside bundles, self-disables warning accounting after its
one run-level warning and corrects the contract. A new three-triplet record
passes on its first attempt: pre-cut bundle 34.72 seconds, candidate bundle
36.06 and candidate plane 27.43, for ratios 1.039 and 0.761 with exact outputs.
The review's availability-rebuild observation remains owned by LDG-2967.
The corrected-tree fast profile also passes 530 of 530 blocks in 104.97
seconds against the unchanged 112-second bound. Focused Type 1 re-review
returned `PASS`: five independent mutations were detected, C1 and C2 were
closed, and C3 remained correctly owned by LDG-2967. The maintainer accepted
Workstream 16 on 2026-10-06. Three review invocations over four tickets is
0.750, a historical review-gate breach recorded rather than padded.

No ticket implements historical projection, recursive-indicator semantics,
missingness, scheduling, context-frame retirement or a plural or subset
feature-plane API. The conditional `ctx$feature_at()` shortcut remains in the
strategy-callback follow-up route because no measurement yet requires it.

## Cut 8: Audited antipattern repairs

**Status:** Workstream 17 and Cut 8 are closed and accepted.

The audit in `../audits/v0_2_2_antipattern_audit.md` walked every R and src
change since `refs/tags/v0.2.1.0` against the seven shapes in the optimization
coding-style manual. It found three introduced shapes. The writer's per-pulse
fill staging copies its whole list on each write, which is minor at 500
instruments but material when thousands of names trade in one pulse. Two
smaller ones are a per-pulse rebuild of two lookup environments on the
availability path and a per-frozen-run read loop under run lists and
comparison. It also found that v0.2.2 closeouts walked a locally restated
checklist that omits two of the manual's shapes.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 17 Audited antipattern repairs | LDG-2966, LDG-2967 | copy-free fill staging; prepared availability lookups; batched run flags; closeout walk bound to the manual | the three shapes are gone with every public output exact, and closeouts walk the manual's shapes verbatim |

One planned close review over two tickets is 0.500 against the review gate.

LDG-2966 landed at `f318453`. Pulse fill rows and memory fill legs are now
closure-owned rather than copied through environment-held lists. LTB-0188
rejects the old shape and pins constant allocation at capacities 256 and
8,192. A three-pair 5,000-fill pulse record measured a 0.319 median
candidate/pre-cut ratio with exact event and fill hashes. The ordinary
Workstream 11 comparison passed all three shapes without retry: cold ratios
0.984 to 1.003 and warm ratios 0.992 to 1.015 against the 1.10 gates.
LDG-2967 now owns the two remaining code shapes and the closeout walk.

LDG-2967 landed at `16e660b`. Availability folds now prepare their physical-
axis hashed lookup once and enforce the changing decision axis through the
pulse lookup. LTB-0189 counts one fold preparation for both a durable run and
a sweep candidate; restoring the per-pulse build produces six and fails four
assertions. Frozen exposure for run lists and comparisons now uses a constant
four DBI reads independent of frozen-run count. LTB-0190 compares several
frozen runs with their individual valuation summaries, preserves repeated IDs
and dense typed-missing flags; restoring the old reader raises the count from
four to six.

The final ordinary Workstream 11 record passed all three shapes without retry:
cold ratios 0.984 to 1.003 and warm ratios 0.992 to 1.004. Exact semantic
hashes, the 757-pulse orientation and checker self-test pass. The fast profile
passed 531 of 531 blocks in 104.51 seconds against 112. The closeout walks the
manual's seven shapes verbatim for all seven changed production functions.
The Type 1 close review returned `CHANGES_REQUIRED` at one invocation over two
tickets. Commit `682b84b` adds the missing shrinking-decision-axis detector,
preserves the three pre-cut invalid-input conditions, and gives the two frozen
runs distinct exposure. The two requested mutations fail LTB-0191 twice and
LTB-0190 three times. Its correction fast record passes 531 of 531 blocks in
103.39 seconds against 112. The focused Type 1 re-review returned `PASS` on
2026-10-07 after independently reproducing all four corrections and mutation
families. The maintainer accepted Workstream 17 and closed Cut 8 the same day.
The final count is two reviews over two tickets, 1.000, recorded as a
historical gate breach rather than padded.

## Cut 9: Scoring boundaries and temporary feature starts

**Status:** Independent cut review returned `PASS_AFTER_PATCHES`; all seven
patches are incorporated. The maintainer accepted the cut on 2026-10-07.
LDG-2968 registered the oracle at `0589741`/`06e20b9`; LDG-2969 enforced the
scoring boundary at `ae5c27b` and closed four agent-review gaps at `d9a4776`.
The maintainer accepted Workstream 18 on 2026-10-07 on the strength of an
agent-run adversarial review and focused re-review. LDG-2970 extended the
oracle with the feature-start arms at `878fe93`, including a recursive TTR EMA
witness, because `ledgr_ind_ema()` is a bounded four-bar filter. LDG-2971
applies the temporary rule: every entry point starts feature state at its
scoring start, omitted hydration is stored as the scoring start, an earlier
hydration start refuses, and the oracle's value group turns green. The
maintainer accepted Workstream 19 on 2026-10-07 on the strength of an
agent-run adversarial review and focused re-review, and Cut 9 closed. One cut
review and four agent close-review invocations over four tickets is 1.250,
recorded rather than padded.

Preparation for macro-plan WS3 exposed a present correctness mismatch rather
than merely an unanswered history-design question. On the same ten-bar SMA(3)
fixture, a dated durable run and explicit windowed run begin on day 6 and
finish at 1001, while ordinary and windowed sweeps consume earlier history
and finish at 1006. A public `ledgr_walk_forward()` fold records hydration on
day 1 and training scoring on day 6; its training arm finishes at 1004 while
the day-9 test arm restarts and finishes at 1000. Its training time in market
is 0.625, five of eight pulses, directly showing that metrics include pulses
before the declared day-6 scoring start.

The cut keeps two claims separate:

| Workstream | Tickets | Claim |
| --- | --- | --- |
| 18 Scoring-boundary correctness | LDG-2968, LDG-2969 | scoring is the sole temporary evaluation, execution and result boundary; run, backtest, sweep, promotion and walk-forward agree on it |
| 19 Temporary feature-start contract | LDG-2970, LDG-2971 | until WS3/WS4 binds causal hydration, every feature state restarts at scoring and no persisted hydration clock is ignored |

The temporary feature rule is an explicit product decision, not neutral
cleanup. Fixed-window and recursive features re-warm in each scoring window.
Omitted execution and hydration starts normalize to scoring start; any explicit
different value refuses rather than being recorded and ignored. The fields
remain future identity seams for the joint WS3/WS4 design, but this cut gives
no meaning to targets between distinct clocks.

The maintained checker has two named groups. Workstream 18 turns the boundary
group green using each public surface's real observables; sweep evidence is its
scoring metadata, candidate metrics and retained-return timestamps, not fills
or events that the surface does not expose. The value group remains red until
Workstream 19 aligns feature starts and makes run, sweep and promotion values
agree. The matrix includes `ledgr_backtest(start = ...)`, and the recursive
witness is `ledgr_ind_ema()` on data whose result changes with its start.

Cut 9 consumes the unfinished substance of archived v0.1.9.4 LDG-2615 without
editing that released packet. It does not design permanent hydration,
recursive-indicator convergence, point-in-time history, missingness or the
two-clock carrier. After Cut 9, WS3 remeasures the current-tree memory baseline
and sets its representation budget.

One cut review and two planned workstream close reviews are three invocations
over four tickets, 0.750. This is chosen rather than inherent: one combined
workstream would meet 0.500, but would combine a present defect with a distinct
temporary product-semantic decision. The cut records that cost rather than
adding ceremonial work.

## Cut 14: Pre-CRAN legacy removal and structural hygiene

**Status:** Accepted by the maintainer on 2026-10-13 after independent cut
review and focused re-review. Every required patch is incorporated, and
implementation opens with LDG-3022.

Authority is the accepted pre-CRAN legacy-removal synthesis, its Type 1 final
review, and the macro plan's 2026-10-12 legacy-removal,
interim-lake-rebuild and codebase-hygiene amendments. The cut consolidates the
synthesis's contract changes now, removes its RFC-pipeline obligation, and
amends the temporary legacy-readability clauses in the accepted WS5-A
synthesis. `tickets.yml` remains the sole execution and sequencing authority.

The cut has three claims:

| Workstream | Tickets | Claim |
| --- | --- | --- |
| 29 One current schema and one store gate | LDG-3024 to LDG-3027 | every persistent ledgr store is created or opened through schema 119, one marker-pair gate and one strict catalogue authority |
| 30 Current-only records and public surfaces | LDG-3028 to LDG-3031 | no supported record or call surface retains a legacy branch, current outputs stay exact, and the private lake is rebuilt under the final format |
| 31 Structural codebase hygiene | LDG-3022, LDG-3023, LDG-3032 to LDG-3035 | the measured helper and condition backlog is reconciled before the source census becomes two failure-sensitive gates, lint moves from advisory to blocking, and the helper rule becomes standing review guidance |

The sequence deliberately crosses Workstream 31 once. LDG-3022's report-only
census and LDG-3023's advisory lint land before product deletion. Workstream 29
then centralizes schema and opening, Workstream 30 removes record and call-form
compatibility and rebuilds the research lake, and Workstream 31 finishes with
the isolated style pass, explicit backlog reconciliation, blocking lint,
structural tests and standing rules. This lets the same source-derived evidence
guide removal and later detect its regression without combining the three
review claims.

The spec-cut choices are closed. `ledgr_db_init()` keeps its public name and
means create-empty-or-open-current. The store marker holds version 119 and
typed canonical JSON written by a dedicated radix-order serializer over an
independent literal oracle of the enumerated format constants. The rebuild
condition has a closed five-cause vocabulary. Existing public validator errors
stay exact. Existing condition classes are documented rather than renamed. No
migration, legacy reader, missing-marker fallback, public diagnostic opener or
compatibility alias is authorized.

One cut review, one focused re-review and three planned Type 1 workstream close
reviews is five invocations over fourteen tickets, 0.357 against the 0.5 gate.
The added backlog-reconciliation ticket is sized by the cut review's 228
undocumented classes and helper census; it is not review padding.

## Expected later artifacts

- accepted design records or explicit references to their existing locations;
- rendered packet status and closeout evidence as implementation proceeds.

The roadmap remains the compact cross-version index and points here. Detailed
v0.2.2 planning belongs in this packet so that the roadmap and the packet do
not become competing copies of the same plan.
