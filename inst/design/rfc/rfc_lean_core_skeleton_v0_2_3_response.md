# Lean core skeleton brief review

> Renamed 2026-11-04 from `inst/design/ledgr_v0_2_3_spec_packet/lean_core_skeleton_brief_review.md` when the
> skeleton brief became the lean core skeleton RFC. "B" and the brief paths
> below refer to the seed v1 text at 1b69c7e9. The review prompt was drafted by Claude, a seed
> co-author; this review stays provisional until the maintainer rereads prompt
> and review together (`rfc_cycle.md`, Briefs).

- Mode: **Type 2**, independent peer review requested by the maintainer.
- Reviewed: `inst/design/ledgr_v0_2_3_spec_packet/lean_core_skeleton_brief.md` at **1b69c7e9** (`1b69c7e98c626d960cf251c8b80e5870b4c1e5bf`), with the accepted synthesis, amendment, final review, WS16/WS14a, rules ledger, contracts, source and cited probes.
- Ran: read-only Git/source checks and R 4.6.1 with `pkgload::load_all("C:/Users/maxth/ledgr-wt/skeleton-review", compile = FALSE, quiet = TRUE)`. `C:/Users/maxth/ledgr-wt/skeleton-review-probes/source_probe.R` passed checks of the existing admission helper, context refusal, opening compensation and the SMA overlap example (150 differing values; maximum `4.973799e-14`). Its output is `source_probe.txt` beside it. The separate `review_probe.R` public-history probe stopped at missing native symbol `_ledgr_ledgr_cpp_history_gap_runs`; its output is `review_probe.txt`. Public-history behavior below is therefore source/contract evidence, not a successful end-to-end rerun. No compilation, full tests, package check, private-data access or benchmark rerun.

## Verdict: REVISE

Time-major compact tiles are a reasonable candidate, but this is not yet a tight A1 implementation brief. It substitutes an unbounded resident tile collection for the required bounded working set, underspecifies cutoff-dependent history, and contains shortcuts that can change admission, repeated target execution and public context behavior. The complete FIFO checkpoint and its acceptance boundaries are missing. Principle 0 cannot resolve these contradictions for an implementer; the specific rules below must be corrected first.

Paths below are repository-relative; **B** means the reviewed brief, **S** means `inst/design/rfc/rfc_lean_fold_core_v0_2_3_synthesis.md`, and **C** means `inst/design/contracts.md`. `macro_plan.md` is in the same packet as B. Unqualified layout probe filenames refer to `dev/spikes/data_layout/`.

## Findings

### P1 — High: bound resident working data, not each allocation

**Evidence:** B:139-148, :233-242; S:159-180; C:3351-3373 (`contract-verification-release-gates`). The existing feature service allocates full-run matrices at `R/history-features.R:447-460`; the payload then splits them at `R/history-substrate.R:376-406`. `dev/spikes/data_layout/README.md:95` explicitly excludes preparation peaks from its measurements.

A list holding every tile still grows with history. A per-tile cap does not bound that list, and letting lookback override the cap removes even the local bound. Public lookbacks are supplied on each read, not declared before execution (C:2266-2288); they may exceed any chosen tile width. The four-times multiplier is an unmeasured heuristic. The promised peak of “tiles plus one instrument's series” also omits source data, treatment/evidence, temporary copies, lots, views and workers. Reusing the current feature service unchanged cannot produce the claimed direct-to-tile peak.

**Patch:** Replace B:144-148 with:

> Tile width is a storage choice within a declared resident working-set budget, not a limit on public history requests. Any finite lookback and `Inf` may span any number of tiles. Neither a request nor `requires_bars` overrides that budget. Before acceptance, specify the resident-tile limit, backing/history access, eviction and retained-view ownership. If exact supported reads cannot fit the proposed working-set design, stop for maintainer disposition.

Replace Section 6 items 3-5 with:

> The first memory checkpoint chooses and measures tile residency and storage before further family growth. Preserve the existing feature algorithm and evidence while changing its allocation/output boundary; do not build a second feature engine. Report source/history, feature payload, working tiles, summaries, transient copies, lots, retained views and output separately, plus parent/worker/process-tree peaks. Vary history length at fixed tile width and worker count on the portable and registered scale shapes required by synthesis Section 4. The existing paired 1.10 resource gate remains binding. Direct-to-tile preparation and its peak are hypotheses until measured.

### P2 — High: one pulse timeline cannot replace two-clock history

**Evidence:** B:57-68, :139-158; C:2281-2319 and :2584-2630 (`contract-context-pulse-data`, `contract-context-strict-features`). `R/history-substrate.R:1306-1377` resolves observation intervals against knowledge time. `R/history-frame.R:207-284` distinguishes cutoff-restated bars from vintage features. `R/history-features.R:329-427` preserves calculation segments and late-knowledge ranges.

“Alive” is undefined: membership, observed first/last bar and knowable lifetime are different. Dropping a nonmember can remove explicitly requested history; dropping after the last print can lose LR-08 carry; dropping a known-inactive instrument can lose readable flagged prints. A single prepared treated plane cannot represent a past bar that changes at a later knowledge cutoff. Computing one uninterrupted “whole life” also loses required gap/relisting restarts. A tile boundary must preserve these dependencies, including carry sources outside the tile, rather than create a new calculation boundary.

**Patch:** Replace principle 5 with:

> Prepare features with the existing service from data start through calculation end, preserving its required-field treatment, knowledge ranges, segment restarts, readiness, arithmetic order and vintage evidence. Tile boundaries introduce no restart or recalculation. “Whole life” does not mean one uninterrupted indicator call or use of final lifetime knowledge.

Add after the prepared-run table:

> Tile inclusion is a physical storage rule, never membership or history admission. Omitted columns must reconstruct exactly the values and evidence the common substrate would return, including inactive prints, carried values and explicit off-axis requests. Keep raw OHLCV distinct from treated history and vintage feature values. Preserve carry source, age and lifetime/terminal barriers across tiles, and cutoff-indexed treatment for late-known facts. Retain sparse segment, reason and carry evidence. Change points retain effective and knowledge boundaries, resolver precedence and witnesses; pulse-current vectors are only execution cursors, not the history authority. Re-entering instruments retain their global identity. Test joins with changed tile column order, entry/exit, carry expiry, relisting and late knowledge on either side of an edge.

Replace the table's “list of (pulse, instrument, new value)” with “flat typed segment/change-point columns with instrument offsets, effective and knowledge boundaries, state codes and witnesses”. This also removes the per-record list ambiguity under optimization shape 1.

### P3 — High: a trailing valid run is not general history admission

**Evidence:** B:150-158, :201-202, :245-248; C:2360-2381 (`contract-context-pulse-data`) and :1931-1943 (`contract-strategy-decision-axis`); `R/history-frame.R:770-826`, :1043-1067, :1114-1150.

For values `21, 22, NA, NA, 25`, `lookback = 5, min_observations = 3` admits the instrument although the trailing run is one. Carried finite values count even when `observed` is false. `calculation_valid` is also not interchangeable with finite returned values. The default complete-window case is only a subset of the API; LR-07's shorthand does not override that API. Selection order, zero lookback, early windows, `Inf`, exclusion reasons and panel warmup still need exact answers.

**Patch:** Replace B:150-158 with:

> History selection follows `contract-strategy-decision-axis`. Admission counts finite values in the returned treated plane against `min_observations`, including input/output carry, with the defaults and empty-window behavior of `contract-context-pulse-data`. A trailing-run count may optimize the complete-window case only; general requests use an exact window-count method. Bar summaries must use the read cutoff's treatment; feature summaries use vintage cells. Preserve exclusion precedence, selection counts and `min_instruments` warmup. No past-membership plane is needed, but observation flags alone never decide admission.

In Section 4 replace “Admission comes from the valid-run count” with “Admission uses the exact request-specific count above”. Replace Section 6 item 7's final sentence with:

> Measure the complete lean public read, including general admission and required metadata, before setting its baseline-derived P2 budget under A2; a slice timing is only a component target.

### P4 — High: repeated intent and non-fill events still require work

**Evidence:** B:80-83; C:1899-1909 (`contract-strategy-decision-axis`); `R/fold-engine.R:1064-1073`, :1094-1135, :360-420; S:122-135.

“Whose target changed” can mean changed since the previous pulse. That loses a repeated zero target after a halted exit failed: the same target must be attempted again when execution becomes possible. The current predicate compares the post-risk target with current position. “FIFO touches instruments that filled” omits openings and dispositions, including settlement before P2.

**Patch:** Replace principle 7's second and third sentences with:

> Each due pulse validates the full strategy return and applies risk. Planning selects post-risk targets differing from current settled holdings by the canonical actionable threshold, not targets differing from the prior request. Repeated unmet requests are attempted again. The one lot kernel updates the book for every opening, fill and disposition in event order; position facts advance at those same boundaries. WS15 compresses storage while preserving every required logical row and instruction/sizing witness.

### P5 — High: limit plain representations to the private kernel

**Evidence:** B:71-74, :95-101, :162-170; C:2226-2257, :2320-2391 (`contract-context-pulse-data`), :1315-1325 (`contract-availability-context-and-state`). See `R/pulse-context.R:100-202` and `R/history-frame.R:1198-1216`, :1402-1452, :1659-1688. The optimization manual explicitly permits names, classes and frames at strategy/result boundaries (`inst/design/manual/optimization_coding_style.qmd:256-258`).

A plain list returns `NULL` for an unknown field; current `ctx` raises `ledgr_unknown_context_field`. It also cannot provide the contracted lazy flat-column behavior merely by exposing `feature(slot)`. Strategy state includes portfolio scalars and separately typed asset fields, with reset/default rules on departure and re-entry. Public history already carries recorded structural metadata: deferring its construction must not change the returned attribute or make later `ledgr_history_info()` depend on a live/recycled owner. These are observable differences despite unchanged numerical values.

**Patch:** Replace Section 3.2 with:

> The private packet is positional typed data. The strategy boundary preserves the classed flat lazy `ctx`, aliases, strict field errors, non-forcing enumeration, at-most-once column construction, helpers and frozen retention required by `contract-context-pulse-data`. Private slot readers do not become public fields. The bans on dispatch, caches and environments apply to trusted arithmetic, not mechanisms needed for that public boundary.

In principle 6 and Section 3.3 replace “strategy state” with “asset-state fields with declared types and decision-axis reset rules; portfolio-state fields are typed scalars”. Replace principle 10's second sentence with:

> A private value read may return only values and admission. Public history results retain their existing class, names, shape and recorded structural metadata; long diagnostic reads return cell evidence immediately. Later explanations use frozen retained summaries and never rerun user code or read a mutable pulse cursor. Only construction invisible through the existing public surface may be deferred.

### P6 — High: state the first checkpoint and stage boundaries explicitly

**Evidence:** B:6-7, :15-20, :125-129, :174-176, :225-248; S:74-120, :146-188, :197-209, :407-439; `macro_plan.md:649-677`, :733-743. `R/lot-accounting.R:286-335`, :524-576, :706-766 supplies the operation/refusal rules. `R/fold-engine.R:1336-1395`, :1431-1433 publishes and flushes during execution, with failure ordering that an end-only recorder cannot preserve.

The brief gives neither the complete kernel acceptance cases nor field/axis/validation ownership for its replacement interfaces. “No defensive code” can erase dynamic invariant refusals. “After the last pulse” and “frames ... once” can move publication failures. A1's line-by-line maintainer review, provisional reference status, exclusion from `R/`, and numerical family budgets are not stated locally. Principle 14's eventual run/sweep reuse is otherwise easy to interpret as immediate integration.

**Patch:** Add a “First checkpoint” section:

> Work stays exclusively under `dev/lean_core/`; nothing in `R/` imports, calls, selects or dispatches to it. No hybrid or canonical arithmetic fallback is permitted. Evidence before acceptance of the WS7/WS8/WS15 close is provisional; record the provisional commit, then rebase and rerun against that explicitly pinned close. A later pin change requires maintainer disposition. Keep the rules ledger and A3 dispositions; contracts prevail over oracle defects.
>
> The first checkpoint contains two separately reviewed workstreams: memory preparation under synthesis Section 4 and the complete R FIFO operation/refusal family under Section 3. Cover openings, fills, dispositions, repeated-instrument block boundaries, replay/import/recovery inputs, signed opening basis, unchanged opening compensation, zero-price exhaustion, replay witnesses, dust, fee splits, cached totals and earliest-refusal precedence. Compare the whole book and every applied field; include negative witnesses and retained-input ownership checks. Trusted inputs avoid duplicate validation; new transformations, applied rows and dynamic overflow/invariant failures still have named checks. Failure stops further growth for maintainer disposition.
>
> Before coding, complete the interface table for this checkpoint: each field's type, axis, unit, invariant, producer, validator and owner; use `contract-execution-fold-carrier` as the semantic baseline. Identify the existing services reused and the preparation allocation boundary being changed. P1 alone reads the substrate; P2 receives only its cutoff-bound packet/view; P3-P5 receive no substrate or history handle. Preserve stop installation and append/flush/publication ordering. Record each workstream's pinned-baseline microsecond budget, added-line budget and measurement boundary before scoring. Require line-by-line maintainer review of the skeleton and first family before extension. Each close reports per-function samples, fixes subtraction findings and dispositions budget overruns. There is no aggregate cap.

Replace the end-publication sentence in Section 1 and “Frames are built once, at publication” in Section 3.4 with:

> Reuse the existing output services at their contracted event, chunk, pulse and completion boundaries, including failure prefixes; manifest frames at those boundaries. Buffer growth does not postpone publication until run completion.

### P7 — Medium: correct what the cited measurements actually establish

The source paths exist, but several statements exceed or misdescribe them. These corrections matter because the brief uses them to choose representation and budgets.

| Evidence and problem | Exact patch to B |
| --- | --- |
| B:214's 9/11 us is the instrument-major synthetic tile probe (3,427 live), not the proposed time-major path: `dev/spikes/data_layout/probe.R:43-51`, `README.md:34`. | Relabel that row “synthetic instrument-major tile pulse, 3,427 live”. Add the separate orientation observation “time-major 14 us versus instrument-major 10 us, 3,400 live” from `README.md:70`. |
| B:215's 391/1,291 uses 252-session tiles and payload estimates, not the proposed lookback-derived width or total resident cost: `dev/spikes/data_layout/sharadar_lifetimes.R:7-33`. Values divide by `2^20`. | Label the row “recorded private-catalog payload estimate, 252-session tiles, MiB; excludes maps, summaries and preparation peak”. Do not extrapolate it to a different tile width. |
| B:216 compares an isolated matrix slice with a complete public feature-history call: `q2_orientation.R:17-23`, `q7_history_read.R:33-38`. B:211 also mixes floor-loop and durable-run clocks, already corrected by S:44-46. | Replace B:218 with “Different probes have different clocks and host controls. The fixed-basket row is floor-loop versus durable-run time; 191/12,580 us is a slice versus a complete public read. Neither is a matched-stage speedup or an acceptance budget.” |
| “As fast”, “2 to 4 times” and “half to four-fifths of every” are not universal: layout `README.md:36-38` reports ragged/dense 8,840/5,008 and tile/dense 69/43; :71 reports 208 versus 153 us with orientation changed. Current bar reads already use fused output without a transpose (`R/history-frame.R:625-649`). | Replace B:62-66 with “Measured tiles trade lower payload memory and faster history slices against some slower pulse/cross-edge reads. Time-major removes the transpose in the synthetic orientation probe and adds about 4 us for its 3,400-instrument pulse slice. Complete public reads remain to be measured.” |
| B:55's ratio is 6.872/0.079 = about 87 (`dev/bench/v0_2_3_r_cost_reference/evidence/costs.csv:48-49`). The 1.5 us lookup is specifically one ID in 500 (:83). | Replace “85 times” with “about 87 times in the scalar probe”, and “`match()` 1.5 us per call” with “`match(id, ids)` about 1.5 us for one ID in 500”. |
| B:89-90 says input validation is about a quarter; recorded input-only costs are 36/221 and 40/390, about 10-16% (`dev/spikes/r_floor/README.md:212-217`). B:94 attributes four arithmetic findings; that source's four stage-2 findings also include two diagnostic rules (:109-117). | Replace the validation fraction with “about 10-16% in the recorded canonical blocks”. Replace principle 9's evidence with “LR-03/LR-04 for cash order; the lean FIFO plain-sum negative control for compensation.” |
| B:75-76's 91% is the quickr conversion wrapper, not a general R book cost (`dev/spikes/lean_fifo/README.md:78-82`); copy cost was measured at 116/788 slots (`r_floor/README.md:219`). B:69-70's SMA difference is a maximum, not a constant error. | Qualify these as “quickr wrapper share”, “no measurable copy cost at the two tested lot sizes”, and “all 150 tested overlapping SMA values differed, maximum about 5e-14”. Replace “Free in the seam” with “retained-view immutability passed the seam; its separate cost was not isolated”. |
| B:189-191 cites an old scalar accessor as the interactive path. Current flat fixture reads prepare a matrix (`R/pulse-context.R:308-355`, :441-465); snapshot inspection already uses common preparation (`R/pulse-snapshot.R:220-240`). | Replace that bullet with “Keep fixture and interactive consumers on the shared prepared representation. Current flat fixture access already prepares a feature matrix; interactive inspection already uses the experiment preparation path.” |

The other headline ranges, the 18-field metadata list, the sub-microsecond simple call cost and the timestamp regression are supported by their cited records. The small-history timings are measured calls, not an isolated fixed-cost estimate: replace “fixed cost” in Section 6 item 7 with “measured complete-call cost at 10 instruments”.

## Observations needing no action

- No measured alternative clearly dominates compact time-major tiles. Ragged saves additional payload memory but pays for indexing; dense wins some pulse reads. The evidence supports trying tiles, not proving preparation, total RAM or one universally best width.
- Principles 0, 1-3, 8-9, 11-14 and 16-18 have useful distinct checks: public parity; preparation frequency, axes and epochs; producer validation and arithmetic order; information flow, retention and exclusive mutation; one implementation; timing and size. The overlaps in 1/8, 6/13 and 16/18 are harmless when these checks are named. Principles 4-7 and 10 need the substantive corrections above; 15 needs S's explicit oracle-defect rule. “Small”, “free”, “whole life”, “alive” and “changed” are not sufficient acceptance criteria on their own.
- Omitting past-membership planes is correct: past membership does not itself exclude history (C:1942-1943). That does not permit dropping lifetime/terminal knowledge or LR-08 carry evidence. Principle 0, one FIFO implementation, frozen views, A3 and A4 are the right direction; none authorizes a changed registered test oracle or a production fallback.
