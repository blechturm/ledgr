# Synthesis: Context Frame Retirement

Role: record; RFC-cycle synthesis and durable decision record.
Status: accepted
Authority: accepted synthesis; binds only its stated scope.

**Status:** Accepted by the maintainer on 2026-11-03 after the Type 1
[final review](rfc_context_frame_retirement_v0_2_3_final_review.md)
(PASS_AFTER_PATCHES; P1 applied). Acceptance does not claim implementation or
authorize work without a WS6 ticket cut.
**Date:** 2026-11-03
**Author:** Claude, who did not write seed v2.
**Target window:** v0.2.3, macro-plan WS6.
**Source baseline:** `e3bb4cec` (`release/v0.2.3`).
**Synthesizes:** [seed v2](rfc_context_frame_retirement_v0_2_3_seed_v2.md)
(Codex), the [Type 2 response](rfc_context_frame_retirement_v0_2_3_response.md)
(Claude), the [response review](rfc_context_frame_retirement_v0_2_3_response_review.md)
(Codex), and the maintainer's acceptance of response decisions M1(a) and
M2(a). Seed v1 is history. Where seed v2 and this synthesis differ, this
synthesis governs once accepted.

## 1. Decision

Retire `ctx$bars`, `ctx$feature_table`, `ctx$features_wide` and `ctx$bar(id)`
without aliases. Strategies read the flat named columns that the accepted
[strategy authoring synthesis D1](rfc_strategy_authoring_api_v0_2_3_synthesis.md#d1-one-flat-lazy-decision-view)
already made primary. P2 binds primitives and builds no frame.
`ledgr_pulse_features()` and `ledgr_pulse_wide()` remain explicit inspection
boundaries, rebuilt over the pulse-frozen flat context. They have one alias
source, one row order and honest empty output, and carry no decision-time
performance promise.

No current-bars helper is added. Nor is a generic frame DSL, a replacement
feature matrix, a frame cache, a hash, or a durable or serialized context.
Seed v2 Sections 4 to 10 are accepted with the five corrections in Section 4
of this synthesis.

This discharges the [strategy-context synthesis Section 5](rfc_strategy_context_surface_v0_2_x_synthesis.md#5-state-reads-and-the-deferred-inspection-boundary)
inspection-boundary requirement. It states what is inspected (the flat
context of one pulse), how axis and cutoff are kept (the helpers accept only a
context), how a view stays frozen (in-process ownership, D7), and where frames
manifest (only inside the two helpers). Section 3 records the parity
evidence.

## 2. Inputs, Rotation And Brief

The rotation is: seed by Codex, response by Claude, response review by Codex
as the seed author, seed v2 by Codex, synthesis by Claude. The synthesis
author is not the seed v2 author, as `rfc_cycle.md` requires. The same author
wrote the response and this synthesis. The maintainer accepted that by
assigning it, and Section 3 re-verifies the inputs rather than relying on the
response.

Brief: the maintainer adopted an agent-drafted question as the operative
brief ("consider this the brief"). The question is whether seed v2, the
response and the response review support binding seed v2's D1 to D10 as
written. Per `rfc_cycle.md` "Briefs", this records that the framing was drafted
by an agent and accepted by the maintainer.

Stages skipped: none so far. Maintainer decisions were taken inline at the
response review (M1(a), M2(a)) instead of in a separate decisions artifact,
because they were two binary choices with recorded recommendations.

## 3. Independent Verification Of The Inputs

Each load-bearing claim was checked against the code at `e3bb4cec`, and
executed where marked. The durable probe is
`dev/spikes/ctx_frame_views/response_probe.R`. The response review reran it
independently.

| Claim in seed v2 | Check | Result |
| --- | --- | --- |
| The old probe's functions are gone | Source search for `ledgr_bars_pulse_views`, `ledgr_projection_pulse_views` | Absent from `R/`. Holds. The durable probe's E0 block reports it (its disabling guard was removed before final review). |
| `gap_type` is the `is.na(ctx$close)` mask; `is_synthetic` is constant | Executed (probe E1); `R/history-substrate.R:488-515`; Bar Validation `contracts.md:928-935` | Holds. Every stored price is positive, so an observed cell always has a close. |
| The runtime and experiment forms ignore the active alias map; only the snapshot form stores it | Executed (E2, E4, E5); `R/feature-inspection.R:437-446`; `R/pulse-snapshot.R:259-263` | Holds. |
| A single resolver alias source is complete | Executed: a feature map with one unnamed entry is refused; names on a plain `features` list create no aliases | Holds. Every active map covers every registered feature, so partially aliased output cannot occur. |
| Nothing reads the five D5 metadata fields | Source search | Holds. Only `active_alias_map` is read (`R/feature-inspection.R:441`), and D4 replaces that read. The other `feature_params` readers act on sweep objects, not pulses. |
| Explicit maps "retain their memo" rule | `R/feature-alias-map.R:273-300`; `contracts.md:2421-2426` | **Does not hold.** The inspection helpers have no memo. The contract's memo belongs to the bundled accessor behind the retired `ctx$features()`, and that accessor now has no caller (`R/pulse-context.R:256-309`). Correction C1. |
| Mapped empty axes refuse; unmapped order is radix | Executed (E6); `R/feature-inspection.R:357-362`, `:449-498` | Holds. |
| A retained context stays frozen | Executed (E3) | Holds, in process only (D7). |
| P2's frame block is removable work | Executed (E7): 409.85 µs against 1.70 µs, isolated | Holds as an isolated comparison only. |
| The readable feature-name set is rebuilt on every `$` read | `R/pulse-context.R:69-75`, called at `:152` and `:175-176` | Holds. |

No whole-run speedup is bound or claimed. A session A/B in which the
maintainer asked about speed observed about 5 to 7 percent of run wall time at
600 to 1,500 instruments, with identical equity. That script was not
preserved, so it is not evidence here and gates nothing (macro-plan rule 16).

## 4. Corrections To Seed v2

**C1. Explicit maps have no memo.** D4's bullet becomes: "Explicit maps
retain their collision and unknown-ID rules." In
[Feature Resolution And Explicit Maps](../contracts.md#contract-context-feature-resolution),
the same cut deletes only the final memo sentences of the existing
prepared-state bullet (`contracts.md:2422-2426`). Those sentences describe a
surface Cut 7 removed. The bullet's decision-time, pulse and axis enforcement,
run-local preparation and candidate-isolation guarantees
(`contracts.md:2415-2422`) are retained; B4, B6 and B9 rely on them. No helper
gains a memo.

**C2. The amendment table misses two contract groups.**
[Reproducibility And Preflight](../contracts.md#contract-strategy-reproducibility)
names `.feature_table_current` twice (`contracts.md:2034`, `:2037`), and
Feature Resolution carries C1's stale memo sentences. Both join Section 6.

**C3. Retired names get a pointed refusal.** Add `bars`, `bar`,
`feature_table` and `features_wide` to `ledgr_pulse_context_retired_fields()`
(`R/pulse-context.R:47-49`). They then refuse through the same targeted
`ledgr_unknown_context_field` path as the Cut 7 names, and the message points
to flat columns and the two inspection helpers. This is guidance, not a
compatibility path. Reservation against feature aliases is unchanged.

**C4. Internal manuals are part of the census.** Seed v1 corrected internal
manuals in the same cut, and seed v2 dropped that. Restore it.
`inst/design/manual/execution_fold_core`, `features` and
`observability_determinism` (`.qmd` and rendered `.md`) and
`man/ledgr_strategy_context.Rd` (lines 44, 74, 84 and 100, including the
`feature_table` counterpart of the declared-feature plane) must describe no
retired member after the cut.

**C5. Census patterns use exact names.** The source and documentation census
must not count `ctx$bars_since_entry` and `ctx$bars_since_exit`, which a
plain `ctx$bars` pattern also matches.

## 5. Bound Design

**B1. Retirement (seed v2 D1, with C3).** The four names are absent from
`names(ctx)` and `str(ctx)` in all three entrances: runtime callback,
experiment-form inspection and snapshot-and-universe inspection. `$` and
`[[` refuse them with `ledgr_unknown_context_field`. No binding, warning
period, fallback or compatibility argument exists. One value is
`ctx$close[[id]]`; a cross-section is the flat columns themselves.

**B2. No current-bars helper (D2, maintainer M1(a)).** Documentation may say
that `is.na(ctx$close)` means no observed bar at that pulse. It does not say
why. Expected-session and carry evidence stay with the history readers.

**B3. Inspection boundary (D3, maintainer M2(a)).** Both helpers accept any
valid pulse context, including a retained in-process one. They make no
decision-time cost, durability or serialization promise. "No speed promise"
does not license a scale-growing implementation. The helpers allocate typed
columns once and stamp each result once. There is no nested
instrument-by-feature row loop, `rbind()`, repeated frame growth, per-row
timestamp formatting, or repeated ID scan.

**B4. One alias source, one order, honest empties (D4, with C1).**

- The prepared resolver is the only alias source for every entrance.
- With an active or explicit map, the long view reports alias and concrete
  ID, and wide keys use aliases. Without a map, both use engine IDs.
- Long rows follow Daxis instrument order. Features follow map declaration
  order when a map applies, and radix feature-ID order otherwise.
- Wide reports keep their radix instrument blocks.
- A map is validated against the resolver's registered features. A known
  mapped feature over an empty Daxis returns the typed empty long frame and a
  wide row holding only `ts_utc`, `cash` and `equity`.
- Unknown IDs and collisions still refuse with their existing classes.

Three deliberate changes follow and are named here: runtime and
experiment-form output becomes aliased; unmapped long rows move from radix to
Daxis order; mapped empty axes return results instead of refusing.

**B5. No inspection-only metadata on contexts (D5).** Snapshot-and-universe
inspection stops adding `feature_params`, `active_alias_map`,
`alias_map_json`, `alias_map_hash` and `alias_map_version`. That also removes
the alias-map SHA-256 computed when a pulse is built. `feature_params`
remains an input to resolution.

**B6. P2 binds primitives (D6).** P2 no longer calls the bar-frame
constructor or the run-axis wide builder, stores the three frames, installs
`.feature_table_current`, or retains `observed` for a bars view. It binds the
aligned OHLCV columns from the P1 data packet (`R/fold-engine.R:605-611`),
availability state, feature-lookup metadata, the projection ordinal and a
numeric cutoff into the existing private lookup. Each flat column is still
built at most once per context.

Three readers change in the same step. `ledgr_pulse_snapshot()` stops forcing
a long table. `print()` counts the Daxis and the prepared feature names.
Strategy-error wrapping uses the resolver's `available_message`
(`R/runtime-projection.R:400-403`). Preflight drops `.feature_table_current`;
exported helpers need no new exception, because they are already Tier 1.

**B7. In-process freezing only (D7).** A retained context and its helper
results cannot observe later book state, strategy state or reusable fold
buffers. A private closure may keep read-only prepared matrices and one pulse
ordinal. No persistence, serialization or cross-process promise is made.

**B8. The fixture adapter (D8).** The private `ledgr_pulse_context()` may
take bar and feature frames as test input. It normalizes them once, with
vectorized timestamp validation, into the same primitive lookup that real
contexts use, then discards the frames. P2 never calls it, and its contexts
neither store nor rebuild retired fields. Tests whose subject is an
inspection helper use a real run or inspection context.

**B9. Readable names are prepared once (D9).** The resolver prepares the set
of readable feature names once per run or candidate. Enumeration and `$`
lookup reuse it. Rebuilding it on every read is a detected regression.

**B10. Trust boundary (D10).** Helpers take only a context. They shape-check
what they manifest and do not seal, hash, authenticate, query DuckDB or attach
provenance. Their results are ephemeral R values.

**B11. Migration (seed v2 Section 6, with C4 and C5).**

- Reference documentation teaches flat columns for decisions, the two helpers
  for inspection, and history readers for windows.
- It also teaches one ordinary named-column idiom for a cross-sectional
  feature matrix. This is an idiom, not an API, and there is no successor to
  `features_wide`.
- Tests of the removed representation are deleted or rewritten with that
  stated reason.
- The shared peer recipe reads flat feature columns and builds no frame.
- The frozen peer oracle (`dev/bench/peer_benchmark/dense/oracles/20261030-pre-ws4/`)
  is not re-recorded. Targets, fills and public results must match;
  strategy and config source identity is the only named exclusion.

## 6. Contract Changes

The implementation cut amends these groups. This synthesis edits no contract
in advance.

| Rule group | Amendment |
| --- | --- |
| [Pulse data](../contracts.md#contract-context-pulse-data) | Remove the four retained fields (`contracts.md:2250-2251`). Bind the primitive-only P2 carrier, the reserved retired names with targeted refusal (C3), and the prepared readable-name set (B9). |
| [Feature resolution](../contracts.md#contract-context-feature-resolution) | Delete only the final memo sentences of the prepared-state bullet (`contracts.md:2422-2426`, C1). Its decision-time, pulse and axis, run-local preparation and candidate-isolation guarantees (`contracts.md:2415-2422`) and the anti-shadowing rule for the two inspection consumers are unchanged. |
| [Prepared views](../contracts.md#contract-context-prepared-views) | Delete the prepared-frame bullet (`contracts.md:2438-2442`). Eligibility and frozen-holding rules are unchanged. |
| [Inspection](../contracts.md#contract-context-inspection) | Bind B3 to B5 and B10. Replace the `ctx$features_wide()` sentence (`contracts.md:2481-2482`) with "there is no context frame; `ledgr_pulse_wide()` is the wide inspection API". The error-wrapper sentence keeps its feature-ID wording. |
| [Reproducibility and preflight](../contracts.md#contract-strategy-reproducibility) | Remove `.feature_table_current` from both private-field lists (C2). |
| [Strategy teaching](../contracts.md#contract-documentation-strategy-context) | Remove the old members from the reference table and distinguish flat pulse data, current-pulse inspection and causal history (C4). |

No store schema, format fingerprint, snapshot hash, config identity, result
schema or execution semantics change. Strategy source that read a retired
field gets its ordinary new strategy identity once rewritten.

## 7. Detecting Evidence Required By The Ticket Cut

Seed v2 Section 8 items 1 to 13 bind, with these additions:

1. **Item 1** also checks C3: each retired name refuses through the targeted
   path. A feature alias named `bars` refuses at declaration.
2. **Item 3** asserts `is.na(ctx$close)` at the missing-bar cell. It does not
   assert a `gap_type` or `is_synthetic` value anywhere.
3. **Item 4** compares `names()` across all three entrances. The difference
   may only be interactive-only documented metadata, of which none remains
   after B5.
4. **Item 5** covers both helpers: a known mapped feature on an empty Daxis
   returns, and an unknown one refuses.
5. **Feature-resolution check:** after C1, no memo exists. A detector fails
   if an explicit-map cache reappears in either helper without an accepted
   design.
6. **Census:** the exact-name census (C5) over `R/`, `tests/`, `vignettes/`,
   `man/`, `inst/design/manual/` and the shared benchmark finds no supported
   use of a retired field.
7. **Absence assertions:** the ticket tests, not the descriptive probe, carry
   the failure-sensitive assertion that the retired fields and old frame
   helpers are absent.

The registered suites, documentation contracts, fixture lane and package
check remain required. Clocks recorded at cut close are descriptive only.

## 8. Rejected Alternatives

| Alternative | Reason |
| --- | --- |
| `ledgr_pulse_bars()`, in either the seed v1 or the M1(b) form | Adds no information. Under v1, it also preserves a `gap_type` label that never consults expected sessions. Maintainer M1(a). |
| Callback-grade performance promise for the inspection helpers | Strategies have the flat surface. A promise would make inspection cost a contract surface. Maintainer M2(a). |
| Lazy compatibility fields or aliases | Keeps two representations and makes the removal unverifiable (pre-CRAN policy). |
| Reintroducing `ctx$vec` as builder input | Contradicts authoring D1 and the Cut 7 removal. |
| One-row `ledgr_history_frame()` as the current-pulse view | History carries selection, evidence and missingness semantics that current-pulse inspection does not need. |
| Generic frame or layout DSL; a `features_wide` successor | No observed workflow needs either. Feature-map synthesis D2 already rejected bulk multi-feature reads. |
| Caching manifested frames | Restores retained memory and complicates frozen ownership, with no measured need. |
| Dropping frame input from the private constructor | Rewrites registered fixture setup across 35 call sites with no semantic gain. B8's named adapter is smaller. |
| Re-recording the frozen peer oracle | Erases the source-identity boundary instead of naming it. |
| Hashing or sealing helper results; keeping the snapshot-form alias hash | The context is already past the trust boundary. Nothing reads the hash. |
| Keeping the explicit-map memo wording | Describes a retired surface (C1). |
| Treating seed v2 as optional | The response review's R1 is accepted: the response removed the seed's only export, so a stale seed would have misled the synthesis. |

## 9. Open Questions Promoted To The Spec Cut

1. Ticket grain, and whether the peer-recipe migration shares a ticket with
   the field removal.
2. Private carrier names inside the pulse lookup, including the numeric
   cutoff field.
3. The exact form of each structural detector: frame-constructor count, shape
   witnesses, the readable-name rebuild detector and the memo detector.
4. The wording of the targeted refusal message (C3). Exact prose is not an
   API.

These are calibration choices, not alternative semantics, and need no RFC.

## 10. Future Obligations And Routing

This synthesis creates no new RFC obligation.

- The [strategy-context-preflight](README.md#strategy-context-preflight) row
  keeps its external-helper preflight obligation. Its inspection-boundary
  part is discharged by this synthesis once a WS6 ticket cut takes ownership.
- The [authoring synthesis Section 7](rfc_strategy_authoring_api_v0_2_3_synthesis.md#7-future-obligations-and-downstream-consumers)
  obligation that "explicit on-demand frames must preserve inspection
  obligations" is discharged the same way.
- Multi-feature historical panels remain with the historical-projection
  follow-ups.
- The holistic core review may delete helpers that WS6 leaves dead (for
  example `ledgr_feature_accessor()`, `ledgr_feature_bundle_accessor()`,
  `ledgr_features_wide()`). It does not own this public decision.

At acceptance, add the decision bridge to `decisions.md` and move the
[ctx-frame-retirement](README.md#ctx-frame-retirement) row to "Obligations
open", with one WS6 implementation cut as its route, until that cut takes
ownership. Nothing goes to the horizon. The speculative ideas raised in
the cycle (a bars helper, a frame DSL, a matrix API) are rejected in Section
8, not deferred.

## 11. Sequence

1. Type 1 final review by an author other than Claude checks this synthesis
   against seed v2, the response, the review and the code citations above.
2. Maintainer acceptance establishes scope. It does not claim implementation.
3. The WS6 ticket cut resolves Section 9 and registers Section 7 in
   `tickets.yml`. The cut follows the macro plan's measure, cut, review and
   implement order.

No production code, registered test, ticket, contract or macro plan is changed
by this synthesis.

## 12. Revision History

- 2026-11-03: initial synthesis at `e3bb4cec`. It accepts seed v2 D1 to D10,
  records maintainer decisions M1(a) and M2(a), and applies corrections C1
  to C5.
- 2026-11-03: [final review](rfc_context_frame_retirement_v0_2_3_final_review.md)
  (Codex) PASS_AFTER_PATCHES. P1 applied in place: C1 and the Section 6
  Feature Resolution row now delete only the memo sentences at
  `contracts.md:2422-2426` and retain the prepared-state guarantees at
  `:2415-2422`. Also corrected: C2's cross-reference (Section 6, not 5), and
  the acceptance routing in Section 10 ("Obligations open", per
  `rfc_cycle.md`). No design change.
- 2026-11-03: accepted by the maintainer. The RFC row moves to "Obligations
  open" with one WS6 cut as its route, and the `decisions.md` bridge is added.
