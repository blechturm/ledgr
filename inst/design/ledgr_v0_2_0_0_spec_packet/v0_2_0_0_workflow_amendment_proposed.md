# Proposed amendment: inspectable availability workflow

**Target:** ledgr v0.2.0.0 spec.  
**Status:** Proposal for maintainer review; no tickets allocated or implementation authorized by this document.  
**Date:** 2026-09-12.  
**Reviewed source:** [v0_2_0_0_spec.md at 931e7b8](https://github.com/blechturm/ledgr/blob/931e7b83350e489d6c6dfb1a85416500dfcc2974/inst/design/ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md), the published tip of `v0.2.0.0` at retrieval. Its own recorded baseline is `048b925`; its status still says draft, no tickets cut. The published tree does not contain the availability implementation or survivorship vignette discussed in the supplied conversation. Implementation findings below are attributed to that report, not independently reproduced here.

## 1. Assessment and scope

The current spec already separates evidence, policies and outcomes. Sections 2.3–2.7 bind explicit knowledge assumptions, independent session clocks, membership/holding separation, controlled stops and durable explanations. Those contracts should remain.

The missing product capability is checking interpreted evidence before running a portfolio. Section 4 asks users to build facts, seal, configure, run and explain, but offers no direct inspection of resolved membership. Its teaching fixture also predates the controlled comparison agreed in the vignette review.

This amendment makes the release outcome:

> A user can prepare sessions and constituent histories, inspect their assertions and decision-time interpretation, configure an ordinary strategy, and explain the run's achieved horizon and trading outcomes using public interfaces.

The bounded additions are three public functions, a second input shape for an existing constructor, and clearer existing result surfaces. Proposed names and signatures below are reviewable choices, not currently available APIs.

| Spec location | Amendment |
| --- | --- |
| §1 | Add the pre-run inspection outcome above. |
| §2.3 | Add `ledgr_facts_inspect()`, `ledgr_experiment_preview()` and `ledgr_facts_sessions_qlcal()` in the availability workstream. Preserve hardening's earlier export boundary. |
| §2.4 | Add constituent-list input and the bounded qlcal adapter; clarify both-clock wording and timestamp parsing. |
| §2.5 | Include adapter normalization/provenance metadata in existing fact identity; inspection writes nothing. |
| §2.6 | Specify research inspection separately from strategy context; preserve callback axis restrictions. |
| §2.7 | Expose existing completion evidence through run info/summary; resolve execution versus recording timestamps. |
| §3 | Place constructors in the facts boundary and inspection in the read-side availability boundary, sharing provider resolution. No second engine. |
| §4 | Replace the main teaching fixture and journey as specified below; retain displaced economic cases as tests/follow-on examples. |
| §§5–7 | Add bounded implementation ownership and detecting acceptance cases below. |
| §8 | Replace blanket calendar-expansion deferral with one qlcal adapter; preserve multi-venue and broader calendar/runtime deferrals. |

## 2. Inspect assertions and their interpretation

Proposed surface:

```r
ledgr_facts_inspect(
  facts, family, scope_id,
  at = NULL, instruments = NULL, from = NULL, to = NULL
)
```

Initially support `family = "membership"` and `"sessions"`. `scope_id` names the universe or venue. Return a small classed list with public `rows`, `evidence` and `metadata` components; use eager tibbles and curated printing, without cursors or a persistent inspection artifact.

- With `at = NULL`, show supplied assertions, including audit-only records, completeness and knowledge treatment. Label this an assertion-history view. Range filters select effective dates/intervals; they do not establish historical knowability.
- With `at` supplied, resolve using that full UTC timestamp. Reject ambiguous date-only decision queries rather than silently choosing midnight or the close. Use the same effective/knowledge and precedence logic as execution.
- Membership rows contain `instrument_id`, nullable logical `member`, a resolution reason and references into `evidence`. Preserve the distinction between false membership and unknown membership; both are excluded from runtime members.
- Supporting evidence includes set/fact IDs, effective bounds, knowledge time and basis, completeness, and provenance. Nonmembership caused by omission cites the complete set header, including an empty set. Do not fabricate a negative fact row.
- Without `instruments`, resolved membership inspection returns current resolved members. An explicit vector retains each requested ID, including false/unknown members, in request order. An ID without usable evidence is unknown. Never enumerate future constituents automatically.
- A cutoff-resolved response must not expose future set IDs, future knowledge timestamps or future provenance. The separate assertion-history view is the place for retrospective inspection.
- Session rows show civil date, venue, timezone, open/closed status, UTC opening/closing times and knowledge treatment. A resolved range reports missing or not-yet-knowable coverage explicitly; it never substitutes a closed day for absent evidence.
- Reject incompatible argument combinations with a useful message. Inspecting a membership history does not require bars, a strategy, cash or an experiment. Cross-input validation remains the job of `ledgr_facts_validate()`.

Inspection consumes normalized facts in memory. It creates no temporary snapshot or persistent rows and does not silently repair malformed input.

## 3. Preview the configured experiment

```r
ledgr_experiment_preview(
  experiment, at, instruments = NULL
)
```

The preview reads the sealed snapshot and effective experiment plan through existing read-only guards. It invokes no strategy, risk or cost callbacks, creates no run, and preserves caller RNG state. It uses the same provider/resolver as runtime, rather than constructing a parallel interpretation in the wrapper.

Return `instruments`, `sessions`, `evidence` and `plan` components. Report selected membership, resolved status/lifetime restrictions, current-session observation presence, supporting facts and timestamps, assumptions and disabled checks. `admissible` may use the existing definition `member & !target_restricted`; document that it does not establish affordability or guarantee a fill.

Default rows are the configured current members; an explicit instrument request keeps non-members visible. With a fixed basket, membership in the preview follows that basket even if another membership history exists in the snapshot. Querying the evidence history itself remains a facts-inspection task.

Only accepted current observations knowable at `at` may appear. Do not expose a subsequent session's OHLCV. Do not return predicted holdings, strategy targets, stale portfolio marks or fills. Those require an actual portfolio trajectory. Omit `held`, `priced` and `mark_age` from the preview rather than fabricating portfolio state.

Validate the requested timestamp against the experiment window and declared decision schedule; fail clearly for a non-decision timestamp. Fact inspection remains available for arbitrary full cutoffs.

**Information-boundary amendment:** the synthesis's §5.5 axis restriction continues to govern strategy contexts and their supported views. Research inspection may answer explicitly requested IDs outside that axis, without discovering future members or disclosing future supporting facts. Neither inspection result is a strategy context. Do not change `ledgr_pulse_snapshot()` or broaden callback visibility as a side effect.

## 4. Make familiar constituent lists valid input

Extend `ledgr_facts_membership_snapshots()` to accept either the existing row-per-member table or a list-column table:

```r
membership_lists <- tibble::tibble(
  effective_from = ledgr_utc(c("2020-01-06T00:00:00Z",
                               "2020-01-13T00:00:00Z")),
  knowledge_time = ledgr_utc(c("2020-01-01T00:00:00Z",
                               "2020-01-13T00:00:00Z")),
  members = list(c("AAA", "BBB"), "BBB")
)

membership <- ledgr_facts_membership_snapshots(
  membership_lists, universe_id = "demo_members", complete = TRUE
)
```

The list-column path normalizes through the existing set-header/member representation. `character(0)` represents an empty set without a dummy instrument. Reject mixed input shapes and inconsistent group headers. Equivalent inputs with the same provenance produce identical canonical facts and hashes.

Retain `complete` and its existing default in this amendment; do not add a second mode argument or rename the constructor. All first-path examples pass it explicitly. Printing spells out “complete replacement lists” or “partial assertions”; it does not present partial assertions as invalid input. Preserve existing partial-update semantics and distinguish unknown membership from an explicit false assertion.

Replace §2.4's potentially ambiguous “omitted IDs as nonmembers from its knowledge time” wording with: “A complete set establishes omission for its effective state only when that set is knowable at the query cutoff.” An announced future-effective replacement must not remove members early.

Knowledge-time teaching must state:

- Effective and knowledge timestamps may legitimately coincide.
- Equality without evidence is an explicit assumption, already supported by `knowledge = "assume_effective"`; preserve its identity and labelling contract.
- Local receipt time supports a receipt-based timeline, not an invented historical publication date.
- Missing historical knowledge remains audit-only unless the user records an assumption. Later availability can change returns in either direction.

## 5. One optional qlcal session adapter

The documented qlcal interface provides named calendar objects and business-day classification; use `getCalendar()` with explicit `xp` in `isBusinessDay()`, avoiding global `setCalendar()`. The object is an external pointer and must not be persisted. [qlcal reference](https://cran.r-project.org/web/packages/qlcal/refman/qlcal.html)

Proposed surface:

```r
ledgr_facts_sessions_qlcal(
  calendar, from, to, venue_id, timezone,
  session_open, session_close, knowledge_time,
  knowledge = "assumed_schedule", overrides = NULL, provenance = NULL
)
```

Required date range is inclusive; required opening/closing hours are local civil times. No implicit venue, timezone, hours or knowledge timestamp. Keep `qlcal` in `Suggests`; unavailable dependency fails with installation guidance. Use it only during preparation. Running, reopening and inspecting materialized snapshots must work without it.

The adapter owns these bounded rules:

1. Materialize every civil date, including closed weekends and holidays, into the existing session-fact contract. Preserve its coverage and knowability validation.
2. Convert explicit local hours using the IANA timezone separately for each date, so DST changes UTC times. Reject ambiguous/nonexistent local times and unsupported overnight/split sessions; do not introduce intraday runtime scope.
3. Apply explicit per-date overrides for closures, exceptional openings and early closes. Overrides provide a full replacement session row with their knowledge/provenance fields; reject duplicates and dates outside coverage. They amend one materialized schedule, not a new revision engine.
4. The adapter supplies date classification plus declared hours. It does not claim authoritative early-close coverage or historically archived exchange announcements. Generic schedule-table import remains available for independently sourced schedules.
5. `knowledge = "assumed_schedule"` is a new adapter-scoped declaration that the generated schedule was available at the supplied `knowledge_time`. Persist that assumption in family metadata and label resulting research assumption-backed. An `"evidenced"` alternative requires source provenance for the claimed availability; qlcal output alone is not that evidence. This addition does not alter other constructors' existing knowledge modes.
6. Preserve calendar identifier, qlcal version, adapter normalization version, local hours, timezone, canonical overrides, knowledge basis and provenance alongside materialized rows. Use existing metadata/provenance fields and hash rule 2. Exclude volatile generation wall time from semantic identity; never auto-stamp historical knowledge with download time.
7. Retain the synthesis's single-venue scope: this one calendar applies to every instrument in the snapshot. `venue_id` labels that calendar; it does not introduce per-instrument venue routing.

Use the `ledgr_facts_sessions_*` family to avoid the existing annualization `ledgr_calendar*` names. Add no metric-calendar rename, provider registry, Python bridge or multi-calendar merge.

This is an explicit narrow exception to §8's calendar-expansion deferral. The synthetic DEMO schedule remains hand-declared for the main teaching fixture; a short companion example shows the qlcal preparation path and its assumptions.

## 6. Time bounds, fill timing and completion reporting

**Reported correctness defect:** the supplied implementation report identifies ISO UTC strings passed to base `as.POSIXct()` without an explicit compatible format, truncating availability bounds and walk-forward creation time to midnight. Before accepting implementation, reproduce on its actual commit, use the canonical UTC parser and add the detecting cases in §8 below. If already fixed, retain the fix and evidence rather than redoing it. Do not narrate a dropped final session as a convention.

**Contract conflict:** base spec §2.4 says active events use the next session's opening timestamp. The report says implementation fills use the open price but are stamped at the next close. The earlier conversational assessment that this was simply correct by design is not supported by the reviewed spec.

Recommended decision: preserve §2.4's economic opening timestamp. Expose the separate close pulse as `recording_pulse_ts_utc` in active fill results and linked diagnostics, alongside `decision_ts_utc` and `execution_ts_utc`. Derive/persist the association from recorded evidence, never by rerunning strategy. Preserve actual event ordering and dense semantics. The recording pulse is a simulation label, not database wall-clock insertion time. Legacy evidence lacking an unambiguous association remains unknown.

Before ticket cut, reconcile the actual implementation's `ts_utc` field, ledger chronology and existing projections with this decision. If the maintainer chooses close-stamped canonical events instead, explicitly amend §2.4 and document the economic-time field; a vignette sentence alone cannot resolve the contradiction. This choice gates timing-related tickets, not unrelated inspection work.

Extend existing `ledgr_run_info()` and `summary()` rather than add another completion accessor. Expose the already-specified requested/achieved window, status, stop reason, last fully valued time, last executed time, complete-performance flag and links to affected instruments. Keep unknown historical evidence unknown. Print the horizon and stop reason before performance metrics; mark any prefix metrics as incomplete. Preserve the existing exclusion rules for incomplete sweep/selection evidence.

Rebaseline only affected output expectations with explanations tied to corrected sessions/timing. Preserve recorded historical artifacts; do not rewrite their economic rows to match new results. No performance numbers from the conversation are acceptance constants.

## 7. Replace the main teaching journey in §4

Use the agreed two-company controlled comparison: AAA and BBB initially belong; a later complete list contains BBB only; AAA remains held after removal and eventually exhausts its two-session mark allowance. Include BBB's missing observation, with the failed trim taught separately. Keep the ten-open-session DEMO range and explicit weekend closures.

The main runs use the same snapshot, strategy, initial cash, sizing headroom, costs, timing and valuation policy; only the universe selector differs. The survivor run uses the fixed BBB basket; the historical run uses the named membership history. Both consume the same session facts. Complete terminal evidence for BBB must let that run reach the intended end.

Teach each input as readable source information → required shape → constructor → inspected interpretation. Show the full experiment constructor before introducing a comparison wrapper. Repetitive fixture mechanics may be folded but remain visible and executable; no hidden helper dependencies.

The mechanism must be accurate:

1. Snapshot facts store the named historical membership evidence.
2. `ledgr_universe_members()` selects that history for decision-time resolution.
3. **`ctx$members` is the investment cross-section. `ctx$universe` is members plus nonzero holdings.** They are not interchangeable.
4. Strategies return complete quantity targets over `ctx$universe`; `ctx$hold()` preserves positions, including former members.
5. Removal does not sell a holding. An unfilled target is not a standing order; a subsequent attempt requires a new target.
6. Valuation uses the explicit mark policy; current observation, admissibility and executable price are separate questions.

Make delayed knowledge executable through the new inspection path. Print the supporting complete-set header and compare the same cutoff before/after changing knowledge time. Also inspect a holiday/weekend and a venue-wide observation outage: missing bars do not delete scheduled pulses.

Generate three plots from the same inputs and run outputs: observed prices with real gaps, AAA membership/holding/valuation tracks, and run equity curves. Compare returns at the last common fully valued session. Show intended full-horizon outcomes separately and end the incomplete curve at its real endpoint. Do not extrapolate settlement or claim that point-in-time research inherently cannot finish.

Move the substantive quarantine tutorial to `data-input-and-snapshots`, preserving §2.4's strict-first/explicit-quarantine demonstration and tests; cross-link it here. Keep empty-set, status-conflict and retry cases in focused tests or follow-on examples. Finish with a short fresh-session reopen showing identical explanations.

## 8. Ownership and acceptance additions

These extend the existing H/U gates and named test owners; they do not create another gate registry. Ticket numbers are allocated later from the actual repository state.

| Work | Sequence/owner | Detecting acceptance evidence |
| --- | --- | --- |
| UTC bounds | First on actual implementation; provider and walk-forward owners | Final close included at equality, excluded one second earlier; sessions before an intraday start excluded; Jan 16 target can fill at Jan 17 open; creation time retains time of day. |
| Facts inspection/list input | Batch 6/7 facts + provider owners; `test-availability-facts.R` | Two lists and equivalent three-row input normalize identically; empty complete list works; complete omission false, absent partial evidence unknown; late knowledge and future-effective changes resolve correctly. |
| qlcal adapter | Batch 6 facts owner; focused adapter tests | Known closed date, inclusive coverage, DST conversion, explicit early-close override, invalid override/time rejection; no global-calendar mutation; version/assumption/override hash sensitivity; materialized snapshot works without qlcal. |
| Experiment preview | Batch 7 provider/read-side owners; causality/workflow tests | Runtime resolver parity; requested nonmember retained; fixed basket unchanged by membership history; future facts/observations absent; no callback, persistent write or RNG change. |
| Information boundary | Batch 7 causality owner, extends U2 | Default inspection does not enumerate future members; explicit future ID yields no future evidence; callback axis remains members plus holdings; raw-history view clearly separate. |
| Timing reconciliation | Shared fold/result owners before affected rebaseline | Distinct decision/open/recording-close timestamps, correct open price, ordered events and clean/reopened agreement; no future OHLCV in strategy context. |
| Completion UX | Batch 9 result owner | Printed requested/achieved bounds and stop reason agree with persisted completion; prefix labelled incomplete; no invented legacy horizon. |
| Executable teaching | Batch 10 workflow/documentation owners | Public-only preparation/inspection/run/reopen; common-window comparison calculated from outputs; complete run reaches requested end; no artificial holdings for membership inspection. |

Use independent expected dates and economics as well as resolver/path parity. Preserve existing full-release gates; keep tests about behavior and causal evidence, not exact prose or plot styling.

For the already-progressed implementation described in the conversation, map these dependencies onto unfinished work instead of rerunning historical batches. Before ticket cut, record the actual implementation commit and existing fix/ticket status, approve final public schemas and the timing disposition, then update the spec, synchronized ticket files, batch plan, contracts, help, NEWS and scoped documentation references together.

The proposal preserves the core architecture and adds no optimization, imputation, OMS, financing, terminal settlement, multi-venue runtime or broad adapter catalog.

## Source basis

- [Reviewed v0.2.0.0 spec](https://github.com/blechturm/ledgr/blob/931e7b83350e489d6c6dfb1a85416500dfcc2974/inst/design/ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md), especially §§2.3–2.7, 4–8.
- [Accepted availability synthesis](https://github.com/blechturm/ledgr/blob/931e7b83350e489d6c6dfb1a85416500dfcc2974/inst/design/rfc/rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md), especially §§4–6 and 10: single venue, knowledge assumptions, membership versus axis and public constructors.
- [Contract index](https://github.com/blechturm/ledgr/blob/931e7b83350e489d6c6dfb1a85416500dfcc2974/inst/design/contracts.md): family-first naming, one engine, read-only inspection and documentation conventions.
- [RFC-cycle guidance](https://github.com/blechturm/ledgr/blob/931e7b83350e489d6c6dfb1a85416500dfcc2974/inst/design/rfc_cycle.md): amendments need substantive decisions or concrete ticket-cut gates.
- [qlcal documentation](https://cran.r-project.org/web/packages/qlcal/refman/qlcal.html), checked 2026-09-12.
- User-supplied vignette discussion and implementation report: workflow evidence and reported timestamp defects; no R execution was performed for this proposal.
