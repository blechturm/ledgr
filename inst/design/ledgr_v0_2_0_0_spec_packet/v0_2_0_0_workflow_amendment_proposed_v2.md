# Proposed amendment v2: inspectable availability workflow

**Target:** accepted ledgr v0.2.0.0 spec.
**Status:** Revised proposal for maintainer/adversarial review. No additional implementation tickets are allocated or marked accepted by this document.
**Date:** 2026-09-12.
**Baseline:** [ce5095f](https://github.com/blechturm/ledgr/commit/ce5095fbbec45dfb807847cfc2fe27ff22971033).
**Supersedes for review:** [proposal v1](v0_2_0_0_workflow_amendment_proposed.md), preserved as the record reviewed by Claude.

The implementation and vignette are now published. The merged design index correctly records an accepted spec, reviewed batches 0–9, Batch 10 implementation awaiting review, and a pending release gate. This proposal extends that packet; it does not reopen completed batches wholesale or replace their acceptance records.

This revision responds to Claude's F1–F9 review and reads the merged implementation. Source inspection is distinguished from the reviewer's executed probes. No R tests were executed while drafting this revision.

## 1. Scope and release outcome

The accepted spec already requires independent sessions, explicit knowledge assumptions, separate membership/holding state, controlled stops and durable explanations. Preserve those contracts. Add this user outcome:

> A user can construct sessions and constituent lists, inspect their assertions and resolve membership at a decision cutoff before involving portfolio accounting, then run an ordinary strategy and explain its achieved horizon.

The minimum new scope is three public functions: assertion history, cutoff resolution and a qlcal adapter. Extend the existing membership constructor with list-column input. Defer `ledgr_experiment_preview()` until use of this smaller workflow demonstrates the remaining need; retain `ledgr_experiment_plan()` and post-run explanation.

| Accepted spec location | Proposed change |
| --- | --- |
| §1 | Add the pre-run evidence-inspection outcome above. |
| §2.3 | Add `ledgr_facts_history()`, `ledgr_facts_resolve()` and `ledgr_facts_sessions_qlcal()` in the availability workstream. |
| §2.4 | Add constituent-list input and the bounded calendar adapter; clarify complete-set causality and shared local-time validation. |
| §§2.5–2.6 | Preserve fact identity/read-only behavior; explicitly distinguish research inspection from callback visibility. |
| §2.7 | Enforce the existing opening-time execution contract and define derived fill-to-pulse alignment; close any remaining completion-summary gaps. |
| §3 | Constructors remain at the facts boundary; public inspection delegates to shared fact resolution; economics stay in the fold. |
| §4 | Update the remaining teaching requirements against the now-published vignette. |
| §§5–7 | Route the bounded follow-up work and detecting assertions in §8 below. |
| §8 | Permit one qlcal preparation adapter; preserve broader calendar, multi-venue and runtime deferrals. |

## 2. Separate assertion history from cutoff resolution

Both functions accept a normalized fact family or bundle, initially for `membership` and `sessions`. `scope_id` identifies a universe or venue. They need no bars, database, strategy, opening positions or run. Cross-input structural validation remains `ledgr_facts_validate()`'s job. Both return a small classed list with public eager-tibble `rows` and `evidence` components and serializable `metadata`; no cursors or durable inspection artifact.

### Assertion history

```r
ledgr_facts_history(
  facts, family, scope_id,
  instruments = NULL, from = NULL, to = NULL
)
```

Return class `ledgr_facts_history`. This is explicitly retrospective: it shows supplied assertions, including future-effective, future-known and audit-only records, completeness and knowledge basis. It is not a decision view.

For membership, `from`/`to` are optional full UTC effective-time bounds for interval overlap, with omitted bounds unbounded and supplied bounds interpreted as `[from, to)`. Headers for dated lists represent their asserted effective state; include a preceding header when needed to interpret that state at `from`. An instrument filter selects supplied member/interval rows and preserves the applicable complete-set headers, including empty sets. It does not manufacture false/unknown rows for an ID absent from the source. Without filters, return the selected history in deterministic effective/knowledge/ID order.

For sessions, `from`/`to` are optional inclusive civil `Date` bounds; omitted endpoints use declared coverage. Without a range, return all supplied dates, including closures, with venue, timezone, UTC opens/closes and knowledge treatment. `instruments` is invalid for sessions. Curated printing may abbreviate long tables but must disclose the full row count and coverage.

### Cutoff resolution

```r
ledgr_facts_resolve(
  facts, family, scope_id, at,
  instruments = NULL
)
```

Return class `ledgr_facts_resolution`. `at` is exactly one full UTC cutoff; reject a bare civil date or a date-only string. There is no `at = NULL` history mode and no range argument. Arbitrary full cutoffs are valid; the query need not coincide with a strategy pulse.

For membership:

- Resolve effective state using evidence knowable by `at`, through the same resolver as runtime.
- Return `instrument_id`, nullable logical `member`, resolution reason and supporting evidence references. False and unknown remain distinct; both exclude an ID from runtime members.
- Without `instruments`, return current resolved members in runtime member order. With an explicit vector, return each distinct requested ID in first-occurrence order, including false/unknown cases. Reject missing/empty IDs. An ID without usable evidence is unknown; do not discover future members automatically.
- Supporting evidence includes fact/set IDs, effective bounds, knowledge time/basis, completeness and provenance. Omission cites the applicable complete-set header; do not fabricate a negative member assertion.
- Exclude not-yet-known evidence, including its IDs and provenance. A future-effective announcement already known at `at` must not activate membership early. The current-state response need not list announcements that do not support that state; inspect their source history separately.

For sessions, resolve the civil date containing `at` in the declared venue timezone. Return its known open/closed schedule and supporting evidence, or an explicit missing/not-yet-knowable-coverage result. `instruments` is invalid. Never interpret absent coverage as closure. Use history inspection for a readable schedule range; runtime retains complete-window coverage validation.

Invalid scope/family or incompatible arguments fail with a useful classed error. Empty results retain typed schemas. Query metadata states the operation, scope, cutoff or range, knowledge assumptions and normalization version.

Neither function invokes callbacks, changes caller RNG, repairs inputs or writes persistent tables. Reuse canonical facts and resolution; do not implement a second membership engine in a convenience wrapper. Factor the existing member-selection resolver only as needed to retain unknown/false and supporting evidence, with existing runtime results preserved.

**Information boundary:** assertion history is a researcher-facing audit surface. Cutoff resolution may answer explicit IDs outside the callback axis without enumerating future members or revealing not-yet-known evidence. Neither return value is a strategy context. Synthesis §5.5 continues to restrict callbacks and supported pulse views to current members plus nonzero holdings; do not widen `ledgr_pulse_snapshot()` as a side effect.

## 3. Connect inspection to the existing experiment workflow

The normal journey is: construct facts, inspect history, resolve a chosen cutoff, validate inputs, seal, configure, inspect the plan, run and explain. Show those operations directly before comparison wrappers.

`ledgr_facts_resolve()` answers what the named evidence says. The experiment's selector determines whether that history is used: `ledgr_universe_members("u")` selects it; a fixed basket stays fixed even when another membership family is present. A standalone membership resolution is not an experiment preview or an affordability check.

Teach the actual callback contract: `ctx$members` is the investment cross-section, while `ctx$universe` is its union with nonzero holdings. Targets are complete desired quantities over that axis. `ctx$hold()` preserves former-member holdings; removal does not create a sale or standing order.

Continue using `ledgr_experiment_plan()` for chosen rules, assumptions and disabled checks, and `ledgr_run_explain()` for actual positions, targets, valuation and fill outcomes. Rich pre-run experiment preview remains an explicit deferral; no fake holdings are permitted merely to inspect membership.

## 4. Accept familiar constituent lists

Extend `ledgr_facts_membership_snapshots()` with list-column input alongside its existing row-per-member form:

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

Normalize through existing set headers and member rows. `character(0)` is an empty list without a dummy instrument. Reject mixed input shapes and inconsistent headers. Equivalent rows/lists with identical provenance produce identical canonical facts and hashes.

Retain `complete` and its current default; all first-path examples pass it explicitly. Printing spells out “complete replacement lists” or “partial assertions”. Partial assertions remain legitimate: omission does not erase prior applicable evidence or become an explicit false assertion.

Clarify spec §2.4: a complete set establishes omission for its effective state only when that set is knowable at the cutoff. An announcement must satisfy both clocks; early publication does not advance its effective date.

Preserve `knowledge = "evidenced"` and `"assume_effective"`. Equal effective/knowledge timestamps can be evidenced; unsupported equality is an assumption. Receipt time supports a receipt timeline, not an invented historical publication date. Later availability can change results in either direction. Missing knowledge without an assumption remains audit-only where the existing family contract permits it.

## 5. One optional qlcal preparation adapter

```r
ledgr_facts_sessions_qlcal(
  calendar, from, to, venue_id, timezone,
  session_open, session_close,
  knowledge = "assume_effective", knowledge_time = NULL,
  overrides = NULL, provenance = NULL
)
```

The calendar identifier, inclusive civil date range, venue label, IANA timezone and local hours are explicit. Keep qlcal in `Suggests`; missing dependency gives installation guidance. Use an explicit qlcal calendar object and pass it to business-day queries; never modify its global calendar. Do not persist its external pointer. [qlcal reference](https://cran.r-project.org/web/packages/qlcal/refman/qlcal.html)

Materialize every date, including closures, then delegate to `ledgr_facts_sessions()`. Running, reopening and inspecting the materialized snapshot must not require qlcal. Retain one venue applying to every instrument; add no venue routing, provider registry, calendar merge, Python bridge or annualization-calendar rename.

### Time and overrides

Delegate date-specific local-time conversion, coverage and knowledge validation to the shared constructor. Existing per-date conversion already handles ordinary DST changes. Strengthen `ledgr_session_times()` to reject ambiguous and nonexistent local wall times consistently across supported operating systems instead of silently selecting an offset. Explicit `POSIXct` instants are already disambiguated and remain valid. Add no second parser in the adapter and no overnight/split-session runtime scope.

Overrides provide a complete replacement row for a civil date, with explicit status, local opening/closing times, knowledge treatment and provenance. Reject duplicate/out-of-range overrides; validate them through the same constructor. They replace rows in one schedule, not a versioned calendar engine. The adapter supplies date classification with user-declared hours and exceptions; do not claim authoritative early-close coverage or archived historical announcements.

### Knowledge and schedule provenance

Keep the existing two-value `knowledge` vocabulary and normalization behavior. The adapter defaults explicitly to `"assume_effective"`: missing knowledge is assumed at each session's effective civil-day start, subject to the shared validation. With `"evidenced"`, require supplied historical knowledge timestamps and source provenance supporting that claim. `knowledge_time` is either absent or a scalar full UTC instant expanded over generated rows; overrides may supply their own timestamps. Do not silently use generation/download time. Arbitrary backdated assumed timestamps are not a new capability in this adapter.

Separate generated schedule content from knowledge-time treatment. Add a documented `schedule_basis = "generated"` field to this adapter's hashed session-family metadata. Record provider, provider version, calendar identifier, adapter normalization version, timezone, declared hours, canonical overrides and provenance in that metadata/row-provenance structure. This is a defined metadata contract, not free-text that printing guesses from.

Explicitly extend the plan's assumption predicate in `R/availability-policy.R`: a family is assumption-backed when existing knowledge metadata says `"assume_effective"`, or its schedule basis is `"generated"`. Preserve the two underlying reasons separately for inspection/summary. An evidenced timestamp does not turn generated schedule content into archived exchange evidence. Conversely, the generated-content label must not falsify a genuinely evidenced timestamp.

Existing families without new metadata retain their labels and canonical hashes. Do not insert default fields into old/dense payloads. New adapter metadata participates in existing hash rule 2; changes in provider version, hours, overrides or assumptions change the new snapshot's identity. Exclude volatile generation wall time from semantic identity.

This is a bounded exception to spec §8's calendar-expansion deferral. Keep `ledgr_facts_sessions_*` naming distinct from metric annualization `ledgr_calendar*`. The main DEMO fixture retains its explicit synthetic calendar; show qlcal in a short companion preparation example.

## 6. Bind economic execution timing and derived pulse alignment

**Chosen contract for this proposal:** active execution uses the next declared session's opening timestamp. This preserves the accepted spec §2.4 requirement. The acceptance cases below implement this choice; no alternative timing decision is deferred to ticket cut.

Source at `ce5095f` confirms that `ledgr_fold_build_availability_pulse_plan()` currently takes `pulses_posix[[pulse_idx + 1L]]` as `execution_ts`, passes it to `provider$execution_view()` and stamps the fill with it. Thus both the timestamp and execution-time fact cutoff currently use the close. `ledgr_session_execution_opportunities()` already computes declared next openings; integrate session-aligned openings into the canonical execution path, respecting the selected window and terminal no-fill rule.

Bind these field meanings:

| Field/surface | Active convention |
| --- | --- |
| `decision_ts_utc` / existing signal timestamp | Close at which the target was decided. |
| `execution_ts_utc` in diagnostics | Declared next opening, or missing when no opportunity exists. |
| Ledger fill-event timestamp and public `fills$ts_utc` | Actual simulated economic execution time: that opening. |
| Public derived `recording_pulse_ts_utc` | Close of the uniquely associated execution session. A simulation alignment label, not database insertion wall time. |
| Equity timestamp | Existing close pulse; do not restamp equity to the open. |

Recheck status/lifetime and other execution-time facts at the opening cutoff. A restriction becoming effective/known after opening must not retroactively block that fill; a restriction already applicable and knowable at opening must block it. Preserve decision-frozen membership eligibility and the existing permitted next-open-price evidence boundary; do not expose later OHLCV to the strategy. This correction can change fills and returns, not just presentation.

Dense conventions remain unchanged because that path has no independent declared opening clock. Do not fabricate one to make shapes appear symmetric. For dense fills, derived pulse alignment equals the existing fill timestamp and carries no new economic-time claim.

Expose `recording_pulse_ts_utc` as a read-side derivation from recorded fill association and sealed session facts, not another persisted column. It must survive reopening without strategy replay. Missing or ambiguous associations remain explicitly unavailable; never guess from a truncated UTC date. Preserve historical stored event timestamps rather than silently rewriting old runs. Do not relabel a historical close stamp as a newly evidenced opening. Capture the semantic change in the execution fingerprint/version machinery already governing run identity, with a documented compatibility disposition.

Document a fills-to-equity example: group fills by `recording_pulse_ts_utc`, aggregate the desired measures, then join that table to equity `ts_utc`. A raw equality join on economic `fills$ts_utc` is not session alignment; multiple fills must not duplicate equity rows. Verify that current results, reopened results, replay/projections, stop boundaries and last-executed metadata all agree under the opening convention.

### Already integrated UTC bounds fix

Commit `440a5d6` fixes availability bounds and walk-forward creation-time parsing; the changes are present at this baseline. Availability workflow tests include final-close inclusion, intraday-start exclusion and a final eligible target/fill scenario. Retain them. The reviewer reports detecting reversions and a green suite; those runs were not repeated for this document.

The remaining creation-time obligation is a focused behavioral test that executes the existing creation path and verifies preserved time of day. A source-text guard alone is insufficient. Rebaseline affected outputs with explanations tied to corrected timing, and preserve historical recorded artifacts. Do not revive the already-fixed early-end defect as new work.

### Completion reporting

Use existing `ledgr_run_info()`/`summary()` and recorded completion metadata. Check for remaining gaps rather than adding a second accessor: requested/achieved window, status, reason, last fully valued/executed time, incomplete-performance label and affected-ID explanation should be readily visible. Unknown legacy evidence remains unknown. Preserve incomplete-candidate exclusion from complete-performance selection.

## 7. Finish teaching against the published vignette

The installed survivorship article and its three figures now exist; the survivor reaches the intended final date after the bounds fix. Keep the controlled comparison and update the existing article rather than requiring another implementation of completed work.

Remaining requirements:

- Use readable source information → required shape → constructor → inspected interpretation. Replace the artificial opening positions and do-nothing runs used solely for membership inspection with the new resolver.
- Show the full experiment constructor before the `declare()` comparison wrapper. Make named history → selector → `ctx$members` → members-plus-holdings axis → targets → execution/valuation explicit.
- Teach complete lists and both clocks through executable cutoff queries, including delayed knowledge and already-known future-effective replacement. Do not activate future membership early.
- Preserve separate questions for observed data, membership, holdings, admissibility and permissible valuation. Explain failed targets as single execution attempts, not standing orders.
- Inspect a closed date and a venue-wide feed outage. Missing observations do not remove scheduled pulses or make a closed day count toward stale age.
- Compare the two runs on the last common fully valued session; report full-horizon statuses separately. Both runs keep the same snapshot, strategy, cash/headroom, costs, timing and valuation policy; only the universe selector differs.
- Generate price-gap, AAA state-timeline and equity-comparison plots from the actual inputs/results. End incomplete curves at their real endpoint. Regenerate timing-sensitive outputs after the opening-time correction; retain no numeric result by assumption.
- Move the substantive strict-first/explicit-quarantine tutorial to `data-input-and-snapshots`, cross-link it here, and preserve its tests. Keep focused conflict/empty-set/retry cases in tests or follow-on examples.
- Finish with a concise fresh-session reopen demonstrating identical explanations. Folded fixture plumbing remains visible and executable; no hidden helpers or internal SQL joins in the learning path.

## 8. Bounded follow-up work and detecting acceptance

Add synchronized tickets and batch-plan entries only after acceptance. Use the actual active packet allocation. Preserve H/U gates and completed batch records; these are follow-up owners, not instructions to restart batches 6–10.

| Work / owner | Detecting acceptance evidence |
| --- | --- |
| Facts history/resolution; `R/availability-facts.R`, provider/read-side owners; facts/causality/workflow tests | Typed outputs and all argument combinations; raw history includes supplied future/audit-only evidence; cutoff path excludes not-yet-known metadata; explicit unknown/false IDs retained; empty complete sets and known future-effective changes correct; no callback/write/RNG change. |
| Membership list input; facts owner | Equivalent list/row forms with identical provenance give identical facts/hashes; empty list and partial assertions preserve existing semantics; no fake instrument/header row in user input. |
| qlcal adapter; facts owner and focused adapter tests | Inclusive calendar coverage, known closure and explicit early-close override; no global mutation; invalid overrides fail; materialized snapshot works without qlcal; metadata changes alter new identity; generated/evidenced and generated/assumed cases both label their distinct assumptions correctly. |
| Shared session-time validation; `ledgr_session_times()`, `test-availability-facts.R` | Ordinary constructor rejects ambiguous fall-back and nonexistent spring-forward local times on supported OSs; explicit instants accepted; normal DST conversion preserved, without qlcal involvement. |
| Opening-time execution; economics/provider/fold owners, economics/parity tests | Decision at close fills at next declared open and uses that open price; status changing between open and close does not change earlier fill, while pre-open restriction blocks it; selected-window alignment and final no-opportunity behavior correct; dense unchanged. |
| Fill/read-side alignment; fills/results owners, parity/persistence tests | Public `fills$ts_utc` is opening time; pulse field derives to the correct close; grouped fills-to-equity join preserves equity cardinality; economic order, clean/reopened/replayed projections, completion and fingerprints reconcile; no historical restamping. |
| Remaining creation-time regression; walk-forward owner | Actual creation path retains a controlled non-midnight timestamp; source guard is not the only evidence. Keep integrated window regressions. |
| Completion UX and teaching; existing result/vignette owners | Public preparation/resolution requires no artificial holdings; full constructor precedes wrapper; correct common-window comparison and no extrapolation; completion/stop evidence agrees on reopen; tests assert behavior rather than exact prose or plot style. |

Use independent dates/economics in addition to shared-resolver and cross-path parity. A parity test cannot prove that both paths chose the right opening cutoff. Keep normal release tests/checks and OS gates; document the fixes and their identity consequences. No standalone spike or new gate registry is required.

## 9. Review disposition and remaining deferrals

| Review finding | Revision disposition |
| --- | --- |
| F1 | §6 binds opening-time execution; §8 derives acceptance from that same choice. |
| F2 | Confirmed in published source; explicitly preserve dense conventions and correct execution-fact cutoff as well as timestamps. |
| F3 | Define public `fills$ts_utc`; derive pulse alignment, do not persist a third timestamp; teach grouped equity join. |
| F4 | Separate history and resolution functions/classes with explicit filters, defaults and forbidden combinations. |
| F5 | Retain knowledge vocabulary; define hashed generated-schedule metadata and explicitly extend assumption reporting. |
| F6 | Delegate conversion; put ambiguity/nonexistence rejection in the common local-time helper. |
| F7 | Defer experiment preview on priority grounds; no export-count compensation rule. |
| F8 | Record integrated corrections and published article; retain the behavioral creation-time check and unfinished teaching work. |
| F9 | Specify default session inspection and distinguish not-yet-known evidence from already-known future-effective announcements. |

Preserve deferrals for broad adapters, multi-venue/calendar runtime, imputation, optimization, OMS, financing, terminal settlement and new performance claims. This revision remains a proposal pending review; concrete defaults describe what acceptance would bind, not a claim that the maintainer has already accepted them.

## Sources and revision record

- [Accepted spec at ce5095f](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/inst/design/ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md), especially §§2.3–2.7 and 4–8.
- [Facts/session normalization](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/R/availability-facts.R), [provider and corrected calendar bounds](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/R/availability-provider.R), [execution planning](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/R/availability-economics.R), [assumption labels](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/R/availability-policy.R).
- [Availability workflow regressions](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/tests/testthat/test-availability-workflow.R), [walk-forward creation](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/R/walk-forward.R), [published vignette](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/vignettes/survivorship-bias.qmd).
- [Accepted availability synthesis](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/inst/design/rfc/rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md), [contracts](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/inst/design/contracts.md), [RFC-cycle guidance](https://github.com/blechturm/ledgr/blob/ce5095fbbec45dfb807847cfc2fe27ff22971033/inst/design/rfc_cycle.md).
- Claude's maintainer-supplied F1–F9 review: local execution evidence before the implementation was pushed. qlcal was not installed for that review; this revision likewise claims no executed adapter test.
- 2026-09-12: v1 committed as `dd5df5d`; implementation and docs merged at `ce5095f`; v2 incorporates review dispositions above. V1 remains historical rather than being rewritten in place.
