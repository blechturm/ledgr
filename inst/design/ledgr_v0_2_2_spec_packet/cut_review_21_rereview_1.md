# Cut 21 focused re-review 1

Mode: focused Type 1 confirmation of `cut_review_21.md` F1-F6 and its two
should-fix items, with a containment check for new ownership, grain, routing
and testability defects.

Verdict: **CHANGES_REQUIRED**.

F1-F3 and F5-F6 are corrected, as are both should-fix items. F4 is corrected
in the cut decision and scope, but one acceptance sentence still crosses the
logical and physical names it was meant to separate.

## Required patch

### R1 - Medium - LDG-3112 still assigns the physical column name to public run information

**Where:** `tickets.yml:329` (Cut 21 decisions 5 and 7) and
`tickets.yml:2837` (LDG-3112 acceptance item 3).

**Concrete failure:** the corrected cut decision binds `strategy_schedule` as
the structured plan and `ledgr_run_info()` field, while reserving
`schedule_json` for the physical `run_provenance` column. LDG-3112 acceptance
item 3 still says that live, reopened, reconstructed, resumed and zero-decision
"run information agrees on canonical `schedule_json`". An implementation can
therefore expose `schedule_json` publicly and satisfy that item while violating
the cut decision, or expose `strategy_schedule` correctly and fail the literal
acceptance text. The round-trip detector in item 2 does not cure this public
field-name contradiction.

**Exact minimal patch:** in LDG-3112 acceptance item 3 replace:

> run information agrees on canonical schedule_json, schedule_hash

with:

> run information exposes canonical strategy_schedule and schedule_hash,
> agreeing exactly with the physical run_provenance.schedule_json and
> run_provenance.schedule_hash values

Keep acceptance item 2's logical/physical round-trip mutation unchanged.

## Confirmed corrections

- **F1:** LDG-3111 and LDG-3112 are explicitly one atomic merge unit in cut
  sequencing, both ticket scopes and both acceptance lists. Schema 124, its
  gate, skip behavior/vocabulary, provenance, telemetry, contracts, catalogue
  and oracles have one combined review range and no mergeable intermediate.
- **F2:** LDG-3114 uses the exact registered private monthly-momentum H1 input,
  identifies it without publishing rows, starts from the bound shared true
  boundary, runs at least three alternating pairs and gates the median of
  within-pair ratios at `<= 0.90`. The minimum-variance strategy is now only
  the separate documentation witness. Required empirical provenance fields
  are named.
- **F3:** LDG-3110 owns declaration extraction, in-memory config reconstruction
  and config/run/live-candidate identity; LDG-3112 owns current-run persistence
  and durable run recovery; LDG-3113 owns disjoint orchestration formats and
  parallel transport; LDG-3114 is not a second product owner. Contract groups
  follow those owners, and the Workstream 60 review no longer claims workers.
- **F4, except R1:** Cut decision 7 and LDG-3112 scope distinguish logical
  `strategy_schedule` from physical `run_provenance.schedule_json`, retain
  `schedule_hash` in both layers and require an independent round-trip
  mutation.
- **F5:** exact diagnostic fields, display strings, unscheduled output bytes
  and every condition-to-failure mapping are failure-sensitive. The integrated
  detector repeats those fixed choices without taking product ownership.
- **F6:** Workstream 62 owns only LDG-3113 orchestration formats. Serial
  Workstream 63 owns only LDG-3114 teaching and integrated proof. Cut metadata,
  macro-plan WS6/Remaining order, `decisions.md`, the RFC redirect and packet
  README route consistently to Workstreams 60-63.
- **Should-fix 1:** every LDG-3113 format binds its fields, writer, reader,
  refusal and version constant as one atomic change.
- **Should-fix 2:** `NULL` is explicitly only the private compiler input for an
  absent declaration and cannot enter a canonical public or durable payload.

No other ownership, grain, routing or testability defect was introduced.
LFB-035 remains separate, sweep summary count columns remain forbidden and the
fixed format bumps are unchanged.

## Mechanical checks

`tickets.yml` parses with 192 unique ticket IDs and 63 unique workstream IDs.
Every dependency resolves, the graph is acyclic, every ticket references an
existing workstream, Cut 21's six tickets remain pending and all status tokens
are valid. `git diff --check` reports no whitespace error; its line-ending
messages concern pre-existing modified files.

Under M1 this focused re-review is a second independent cut-review invocation,
not a ratio gate. Under M2 this file is the single packet home for R1. After
the one-line correction, `cuts[21].cut_review` should link both review files
and record the focused verdict; another finding-free focused confirmation gets
one line and no new artifact.
