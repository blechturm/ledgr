# Cut 7 Focused Re-review 1

Mode: focused Type 1 cut re-review after the maintainer's Type 2 decision.
Reviewer: independent clean-context Claude Opus, high effort.
Range: `14252ffb..9dcb15fb`.
Date: 2026-11-01.
Verdict: **PASS_AFTER_PATCHES**.

## Overall assessment

Option A is sound and fits the existing schema-124 `strategy_state` table
without consuming schema 125. No design decision is reopened. The remaining
findings are bounded ownership and wording corrections, applied verbatim after
this review.

## Original findings

| Item | Result |
| --- | --- |
| R1 cursor/resume | Resolved after defining unchanged state, the marker and the no-payload default. |
| R2 typed codec | Resolved. |
| R3 rule binding | Resolved. |
| R4 D8 mapping | Resolved after pinning memory-sink behavior. |
| R5 WS6 boundary | Resolved. |
| R6 schedule retirement | Resolved. |
| R7 Section 3 ownership | Required a complete row-by-row ownership map. |
| R8 join J | Resolved. |
| R9 exports | Resolved. |
| R10 timing | Resolved. |
| R11 pre-acceptance probe | Resolved after its limitations were stated. |

## Required patches

1. Map every synthesis Section 3 contract row to its implementing ticket or
   to the explicit WS6 handoff.
2. Bind D8 sizing rows to stage `sizing`, exclude them from retained sweep
   memory, make sweep candidates claim no D8 coverage and compare their
   economics with the committed run.
3. Define unchanged as equality of complete typed state and the decision-axis
   ID vector; make the marker disjoint from every payload; restore declared
   defaults when no payload precedes the cursor.
4. Migrate pulse inspection to declared state and make supplied-position facts
   explicitly unknown.
5. Replace per-pulse JSON validation with declaration-driven validation;
   encode only a changed durable payload.
6. Store strategy intent reason in the typed reason column and remove the
   result reader's JSON parse.
7. Correct Section 4 item 6 ownership.
8. State that two probe arms are internal/synthetic, the encode count is exact
   only for the no-fill fixture, the library path is host-specific and the
   probe is input evidence rather than implementation acceptance.
9. Remove Markdown trailing whitespace from the initial review.
10. Pin unavailable `holding_value` as `NA_real_`, locate capital-base origin,
    detect deletion of the private vec adapter and make the maintained-state
    shape census a stopping acceptance check.

## Checked clean

- YAML parses, IDs are unique, and LDG-3179 through LDG-3190 form one serial
  dependency chain.
- Option A covers no-state and never-changed strategies, unchanged tails,
  finalisation-only resume, departure and re-entry, empty axes and state that
  changes every pulse.
- The existing non-null JSON column can distinguish an explicit marker from a
  typed payload under one new rule binding.
- The recorded probe output matches the current code and product source
  `14252ffb`.
- The preferred split progress/checkpoint architecture remains non-binding in
  the horizon.
- The cut introduces no second engine, scheduler, compatibility reader, schema
  bump or premature join-J claim.

One clean-context confirmation follows the exact patches above.
