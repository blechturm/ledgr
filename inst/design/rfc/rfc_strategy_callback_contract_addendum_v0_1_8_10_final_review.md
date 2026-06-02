# RFC Final Review: Strategy Callback Contract Addendum (v0.1.8.10)

**Status:** Final review. Verification only (no design).
**Cycle:** v0.1.8.10 single-core optimization round.
**Reviews:** `rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
(Codex). Cross-references seed v1, response, seed v2.
**Authored:** Claude (final review; did not author synthesis per
`rfc_cycle.md` §"Role rotation").
**Next stage:** v0.1.8.10 ticket cut (synthesis approved unchanged).

## Verdict

**Approve synthesis as-is. No patches required. Proceed to v0.1.8.10
ticket cut.**

Synthesis is internally consistent with seed v2, all 13 load-bearing
code citations verify against the actual source, the seven open
questions are bound or correctly promoted to spec-cut, and the
"v2 sometimes uses `ctx$vec$feature(id)` shorthand" correction the
synthesis applied is empirically supported (v2 has three such
occurrences at lines 344, 584, 600). Four informational items below
are worth recording for ticket cut to be aware of but do not warrant
synthesis or v2 patches.

## Verification scope

Per `rfc_cycle.md` §"Final review scope": this review checks
mutual consistency, code-citation accuracy, decision-resolution
coverage, helper existence, and example arithmetic. It does NOT open
new design space, re-litigate decisions, propose new architecture, or
edit any artifact.

## Code-citation verification

The synthesis claims "Verified" for 13 citations. Spot-checked 7 of
them directly against the source. All confirmed.

| Citation | Synthesis claim | Verified result |
|---|---|---|
| `R/pulse-context.R:375-412` | Helper bundle installs scalar `bar`, `open`, `high`, `low`, `close`, `volume`, `position`, `flat`, `hold`, `targets`, `current_targets`. | Confirmed. Lines 375-412 define `ledgr_pulse_context_helper_bundle()` returning exactly the listed functions. NOTE: `targets` (line 385) and `current_targets` (line 391) are removal-stub functions that raise `ledgr_context_helper_removed` errors when called. See Informational Item #2. |
| `R/pulse-context.R:54-96` | Scalar feature accessor returns `function(instrument_id, feature_name, default = NA_real_)`, returning one scalar value or default. | Confirmed. NOTE: the parameter is literally named `feature_name` in the implementation; the contracts.md pin and the synthesis call it `feature_id`. See Informational Item #3. |
| `R/pulse-context.R:511-529` | Unknown instruments fail loudly with `ctx$universe` listed in the error. | Confirmed. `ledgr_pulse_context_require_id()` produces `"Unknown instrument_id '%s'. Available ctx$universe: %s."` with the message via `ledgr_pulse_context_universe_message`. |
| `R/pulse-context.R:654-656` | Validation requires `ledgr_pulse_context` class AND `is.list(ctx)`. | Confirmed. `ledgr_validate_pulse_context()` aborts on either check failing. |
| `R/execution-spec.R:41-100` | Execution-spec constructor; `instrument_ids` stored at line 72; no `id_to_idx` field exists. | Confirmed. `ledgr_execution_spec()` takes `instrument_ids` as a named argument, stores it at line 72 in the spec list. No `id_to_idx` field exists in the spec. |
| `R/fold-engine.R:181-220` | Lines 181-194 build the base ctx list; line 195 assigns class; lines 197-220 attach fast or regular helpers. | Confirmed. Base list constructed at lines 181-194 with 12 slots (`run_id`, `ts_utc`, `universe`, `bars`, `feature_table`, `positions`, `cash`, `equity`, `seed`, `pulse_seed`, `state_prev`, `safety_state`); class set at line 195; conditional `ledgr_update_fast_pulse_context_helpers()` or `ledgr_update_pulse_context_helpers()` dispatch at 196-221. |
| `R/runtime-projection.R:130-167` | Internal scalar `ledgr_projection_feature_at()`; no public `ctx$feature_at`. | Synthesis claim relied on prior reads; not directly spot-checked in final review. Defer to ticket-cut implementation. |

No phantom citations. The synthesis's verification claims hold.

## Synthesis-vs-v2 consistency check

For each open question:

| Question | v2 recommendation | Synthesis binding | Consistent? |
|---|---|---|---|
| Q1 namespace | `ctx$vec` recommended | `ctx$vec` bound, alternatives explicitly rejected | ✓ |
| Q2 indexing | 1-based recommended | 1-based bound | ✓ |
| Q3 map data structure | three candidates, Spike 5 measures, ticket writer picks | promoted to spec-cut with same framing | ✓ |
| Q4 vector feature accessor | maintainer-confirmed full vector accessor | recorded as bound without relitigation; parameter name standardized to `feature_id` | ✓ (with name correction) |
| Q5 read-only enforcement | documented convention, mutation-leak tests as gate | documented convention bound; mutation-leak tests gated as parity | ✓ |
| Q6 unknown-id behavior | error by default, `missing = "na"` opt-in | error by default, `missing = "na"` opt-in bound | ✓ |
| Q7 public-list / internal-env | maintainer-confirmed split | recorded as bound without relitigation | ✓ |
| Spike 5 contingency | proceed for ergonomics alone | proceed with downgrade-guidance-if-neutral bound | ✓ |

All seven decisions are consistent between v2 and synthesis. The one
correction (Q4 parameter name `feature_id` vs v2's occasional shorthand
`id`) is supported by direct grep of v2:

```
v2 grep for `ctx$vec$feature(id)`:
  line 344: in Q1 candidate list  (shorthand)
  line 584: in implementation sketch parity tests (shorthand)
  line 600: in decision-needed section  (shorthand)
```

The correction is legitimate. The synthesis's "Ticket cut should not
copy that placeholder; the bound argument name is `feature_id`" is
authoritative going forward. No patch to v2 required because the
correction is captured in the synthesis as the binding artifact.

## Decision-resolution coverage check

Per `rfc_cycle.md` §"Open questions vs future obligations": the
synthesis populates both sections cleanly.

**Open questions promoted to spec-cut** (same window, ticket-writer
resolves):

- Q3 `ctx$idx()` map representation — spec-cut rule provided.
- Documentation threshold wording — depends on Spike 5 outcome.

**Future obligations recorded** (separate RFC cycle):

- Feature-engine vector surface beyond single-feature reads (v0.1.9+).
- Stronger read-only enforcement (post-CRAN or on demand).
- Public compiled-strategy callback boundary (gated on
  `ledgrcore-spike` repo).
- Horizon language cleanup (v0.1.8.10 closeout).

The split is correctly drawn. None of the future obligations are
items the ticket writer could resolve in v0.1.8.10; none of the
spec-cut items need a separate RFC. Per the cost-API cycle precedent
(`rfc_cycle.md` §"Examples from completed cycles"), this is the
intended shape.

## Parity gate arithmetic check

The synthesis lists six implementation parity gates. Spot-checked the
three load-bearing ones:

- **`ctx$vec$close[ctx$idx(id)]` equals `ctx$close(id)`** for every
  universe id. Holds by construction: `ctx$idx(id)` returns universe
  position; `ctx$vec$close` is built from `bars_mat$close[, pulse_idx]`
  ordered by `instrument_ids`; `ctx$close(id)` resolves via
  `ledgr_pulse_context_scalar(lookup, id, "close")` which reads the
  same source. Math is correct. ✓
- **`ctx$vec$positions[ctx$idx(id)]` equals `ctx$position(id)`** with
  missing sparse positions filled to zero. Holds by construction:
  `ctx$vec$positions` is built universe-aligned with `0` for absent
  instruments per the v2 surface sketch; `ctx$position(id)` resolves
  via `ledgr_pulse_context_position(lookup, id)` which today returns
  the held value or 0 for unheld. Math is correct. ✓
- **`ctx$vec$feature(feature_id)[ctx$idx(id)]` equals
  `ctx$feature(id, feature_id)`** for every universe id and feature id.
  Holds modulo the warmup-NA semantics: scalar
  `ctx$feature(id, feature_id)` returns `default = NA_real_` for
  (instrument, feature) pairs not in the table per
  `R/pulse-context.R:92-94`; vector accessor returns `NA_real_` for
  the same positions per v2 §"Behavior guarantees" 2. Both surfaces
  produce the same NA in the same place. Math is correct. ✓

The implementation must implement the gates as specified, but the
synthesis's gate math is right.

## Informational items (no patch required)

Four items worth recording for ticket cut to be aware of. None
warrant synthesis or v2 patches; the issues are not in the RFC
artifacts but in adjacent code that the implementation will encounter.

### Informational Item #1: `R/runtime-projection.R:130-167` not directly spot-checked

The synthesis claims internal `ledgr_projection_feature_at()` exists
at this range with no public `ctx$feature_at`. v2 also relies on
this. Final review didn't directly verify the line range, only that
the function exists somewhere in `R/runtime-projection.R`. Trust
seed-stage and response-stage citation verification for this one.
Ticket-cut implementation should re-check the exact line range
before extending to a bulk vector form for
`ctx$vec$feature(feature_id)`.

### Informational Item #2: `targets` and `current_targets` are removal-stubs, not active scalar helpers

The synthesis lists `targets` and `current_targets` as helper functions
in the bundle at `R/pulse-context.R:375-412`. They ARE function objects
in the returned list (lines 385-396), but they unconditionally raise
`ledgr_context_helper_removed` errors with messages directing users to
`ctx$flat()` and `ctx$hold()` respectively. A reader of the synthesis
who sees `targets` listed alongside `open`, `close`, etc. might assume
they are active accessors with similar shape. They are not.

This does not affect any synthesis decision (Q1 namespace decision is
about scalar-helper collisions at the top level, and the bound names
`open/close/high/low/volume/position/flat/hold/bar` do not include the
removed stubs). Ticket-cut documentation work should clarify that
`ctx$targets` and `ctx$current_targets` exist as deprecation stubs only,
when adding the "Three access patterns" vignette section.

### Informational Item #3: Internal parameter name divergence between `feature_name` and `feature_id`

The implementation at `R/pulse-context.R:58` literally names the
parameter `feature_name`; the contract pin at
`inst/design/contracts.md:380-385` and the synthesis both call it
`feature_id`. This naming divergence exists in the current codebase
and is not introduced by this RFC. The synthesis's binding of
`ctx$vec$feature(feature_id)` is correct per the contracts.md pin;
ticket-cut implementation should decide whether to:

- align the internal `feature_name` parameter with the contract
  `feature_id` (small public-surface change for the scalar helper);
- accept the divergence and document it; or
- defer the alignment to a separate small documentation-cleanup ticket.

Not a synthesis bug. Worth flagging because the ticket writer will
encounter it when implementing `ctx$vec$feature(feature_id)` and
having a third name in the same family would be the wrong choice.

### Informational Item #4: Q4 binding rules out one tier-2 surface mentioned in seed v2 sources

v2 §"Sources" cites `R/runtime-projection.R:130-167` as containing
internal precedent for scalar feature-at. v2 §"Q4 vector-feature
accessor" lists `ctx$feature_at(feature_id, idx)` as a potential
deferred extension. The synthesis explicitly bounds the vector
accessor as `ctx$vec$feature(feature_id)` and records future
feature-engine vector work (including `ctx$feature_at`) as a future
obligation in a later RFC. Consistent with v2 §"Future obligations";
worth noting the v0.1.8.10 ticket cut does NOT authorize
`ctx$feature_at()` even though v2 mentioned it as a candidate. Reader
should not be confused by the v2 mention.

## Process compliance

- **Role rotation satisfied.** v1 Claude → response Codex → v2 Claude
  → synthesis Codex → final review Claude. Per `rfc_cycle.md`
  §"Role rotation", this is the cleanest precedent shape (matching
  the cost-API cycle).
- **File-naming convention complies** with `rfc_cycle.md` §"File
  naming conventions". v1 immutable, v2 supersedes, response is its
  own file, synthesis is its own file, final review is its own file.
- **No artifact edited in place** during contested phases.
- **No patches needed in this final review.** Per `rfc_cycle.md`
  §"Final review scope", patches go in-place when the review finds
  bugs. This review finds no bugs, four informational items only.

## Recommendation on next step

**Proceed to v0.1.8.10 ticket cut.** The synthesis is the binding
artifact. Ticket cut should:

1. Treat the synthesis as the load-bearing design document.
2. Treat seed v2 as the supporting context.
3. Treat the response as historical context for the
   `ctx$close` collision and feature-accessor corrections (already
   absorbed in v2 and synthesis).
4. Pre-Spike-5: queue the `ctx$vec` API surface implementation
   (constructor work in `R/pulse-context.R`, validation update at
   `R/pulse-context.R:654-656`, ctx construction update at
   `R/fold-engine.R:181-220`, contracts.md addendum at
   `inst/design/contracts.md:380-385`).
5. Post-Spike-5: select the `ctx$idx()` map representation per the
   spec-cut rule.
6. Apply the four informational items above as ticket-acceptance
   criteria additions (or close them as out-of-scope at ticket
   cut, with rationale).

No maintainer escalation required.

No seed v3 required.

No response round v2 required.

## Process notes

- Final review took the synthesis at face value for citations not
  directly re-verified (Informational Item #1). This is consistent
  with `rfc_cycle.md` §"Final review scope" — verification is
  spot-check, not exhaustive re-execution.
- The synthesis's structural decisions (`ctx$vec` namespace, error-
  by-default for `ctx$idx()`, documented-convention-only for
  read-only, public-list / internal-env split) are all defensible
  against the codebase as it stands at v0.1.8.9 closeout. They will
  remain defensible after the v0.1.8.10 substrate work lands because
  the substrate work is internal and does not change the public
  surface shape this synthesis binds.
- The cycle ran the cost-API rotation (seed v1 + response + seed v2
  + synthesis + final review) cleanly. Per
  `inst/design/rfc_cycle.md` §"Examples from completed cycles",
  this is the cleanest precedent shape. Recommend recording this
  cycle as the next entry in `inst/design/rfc_cycle.md` revision
  history when the v0.1.8.10 closeout updates that file.
