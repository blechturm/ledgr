# RFC Synthesis: Strategy Callback Contract Addendum (v0.1.8.10)

**Status:** Synthesis. Binding artifact pending final review.
**Cycle:** v0.1.8.10 single-core optimization round.
**Synthesizes:** seed v1, response, seed v2.
**Authored:** Codex (synthesis stage; v2 author was Claude per
`rfc_cycle.md` role rotation).
**Next stage:** final review by Claude (verification, not design).

## Summary verdict

Accept seed v2's direction with one synthesis-level correction: the vector
feature accessor is bound as `ctx$vec$feature(feature_id)` everywhere, not
`ctx$vec$feature(id)`. The binding design is additive: existing scalar
helpers (`ctx$close(id)`, `ctx$feature(id, feature_id)`, `ctx$position(id)`)
remain first-class, `ctx$positions` remains sparse named numeric, and the new
high-throughput surface lives under `ctx$vec`. The only open decision promoted
to spec-cut is the internal `ctx$idx()` map data structure, which Spike 5 /
LDG-2509 should measure. No seed v3 is needed; proceed to final review, then
ticket cut if final review verifies this synthesis.

## Decisions bound by this synthesis

### Q1: Namespace for vector accessors

**Binding answer:** use `ctx$vec`.

**Status:** closed decision.

**Reason:** direct top-level vectors would collide with accepted helper
functions. `R/pulse-context.R:375-412` installs `ctx$open`, `ctx$close`,
`ctx$high`, `ctx$low`, `ctx$volume`, `ctx$position`, `ctx$flat`, and
`ctx$hold` as functions. Tests pin this shape at
`tests/testthat/test-pulse-context-accessors.R:25-43`, and the strategy guide
documents `ctx$open(id)` / `ctx$close(id)` at
`vignettes/strategy-development.qmd:174`. `ctx$vec$close` avoids collision,
keeps the high-throughput path visible, and avoids top-level name sprawl.

Ticket cut should treat `ctx$vec` as the only authorized namespace unless the
maintainer explicitly overrides before final review. The alternatives
(`ctx$prices`, suffixed top-level names, or renaming scalar helpers) are
rejected for v0.1.8.10.

### Q2: Universe indexing convention

**Binding answer:** 1-based R indexing.

**Status:** closed decision.

**Reason:** the whole surface is R-native; internal matrices and projection
accessors already use R integer indices. `R/runtime-projection.R:130-167`
uses integer row and pulse indices in the normal R convention. A Python-style
0-based contract would be foreign to R users and would create off-by-one risk
without measurable benefit.

### Q3: `ctx$idx()` map data structure

**Binding answer:** build the map once per execution spec, but leave the
specific data structure to Spike 5 / LDG-2509 measurement and spec-cut.

**Status:** open question promoted to spec-cut.

**Reason:** `R/execution-spec.R:41-100` is the natural construction point, and
`instrument_ids` is already stored at `R/execution-spec.R:72`. The unresolved
piece is representation: named integer vector, environment-backed hash map, or
`collapse::fmatch`-based lookup. This is an implementation-measurement
question, not a new RFC question. Spike 5 should measure the candidates for
scalar lookup cost and worker-serialization behavior; the v0.1.8.10 ticket
writer should pick the measured winner.

Spec-cut rule: prefer the fastest representation that preserves parallel
sweep serialization and deterministic behavior. If timings are effectively
tied, prefer the simpler serializable representation.

### Q4: Vector feature accessor

**Binding answer:** ship `ctx$vec$feature(feature_id)` in v0.1.8.10.

**Status:** closed maintainer-confirmed decision, recorded without
relitigation.

**Reason:** seed v2 and the prompt confirm the maintainer decision that the
full vector-feature accessor is in scope. This is new contract, not an
extension of existing `ctx$feature()`: current regular and projection-backed
feature helpers are scalar two-argument accessors
(`R/pulse-context.R:54-96`, `R/runtime-projection.R:332-367`), and the contract
pin is `ctx$feature(instrument_id, feature_id)` at
`inst/design/contracts.md:380-385`.

Binding semantics:

- `ctx$vec$feature(feature_id)` returns a universe-aligned numeric vector.
- Unknown feature IDs fail loudly with the same class and message discipline as
  scalar `ctx$feature(id, feature_id)`.
- Warmup values remain `NA_real_`.
- The result order matches `ctx$universe`.
- Existing `ctx$feature(id, feature_id)` and `ctx$features(id, feature_map)`
  remain first-class.

Seed v2 sometimes uses `ctx$vec$feature(id)` as shorthand. Ticket cut should
not copy that placeholder; the bound argument name is `feature_id`.

### Q5: Read-only enforcement

**Binding answer:** documented convention only, with tests proving strategy
mutation does not affect fold internals or later pulses.

**Status:** closed decision.

**Reason:** R has no cheap full read-only slot mechanism. `lockBinding()` would
block reassignment but not all in-place mutation, while copy-on-access would
defeat the performance point. Q7's public-list / internal-env split removes
the strongest aliasing hazard because public ctx slots are fresh per pulse.
The current suite already contains mutation-leak checks for `ctx$bars`
(`tests/testthat/test-sweep.R:913`, `1017`, `1027`), and the new vector path
should get equivalent tests.

Documentation must say strategy code should not mutate ctx slots. If a
strategy needs to retain a snapshot in `state_update`, it should copy the
values it retains. Implementation must still ensure that mutating
`ctx$vec$close` or `ctx$vec$positions` inside a strategy cannot corrupt the
fold engine's internal `bars_mat` or `state`.

### Q6: Unknown-id behavior for `ctx$idx()`

**Binding answer:** error by default, with `missing = "na"` opt-in.

**Status:** closed decision.

**Reason:** existing scalar helpers fail loudly for unknown instruments.
`R/pulse-context.R:511-529` validates ids and reports available
`ctx$universe`; tests pin that behavior at
`tests/testthat/test-pulse-context-accessors.R:255-256`. Silent `NA` by
default would weaken the strategy contract and make NA-indexed reads easy to
miss.

Bound shape:

```r
ctx$idx("AAA")                 # integer index or error
ctx$idx("BAD", missing = "na") # NA_integer_
```

Ticket cut may choose the exact accepted values for `missing`, but the default
must be error.

### Q7: Public-list / internal-env split

**Binding answer:** public ctx stays a list with fresh public slots per pulse;
reusable-env optimization is internal-only.

**Status:** closed maintainer-confirmed decision, recorded without
relitigation.

**Reason:** current validation requires a list-backed pulse context:
`R/pulse-context.R:654-656` checks both `inherits(ctx, "ledgr_pulse_context")`
and `is.list(ctx)`. A public reusable env would require broader contract
change and would reintroduce state-retention aliasing risk. Spike 4 may still
optimize helper state or internal lookup environments, but it does not
authorize exposing a mutable public env as `ctx`.

Implementation handoff: `R/fold-engine.R:181-220` still constructs and
decorates a public list per pulse. Any reusable env work is behind that public
surface.

### Spike 5 contingency

**Binding answer:** proceed with the additive `ctx$vec` addendum even if Spike
5 does not beat scalar helpers, but downgrade performance guidance if the
measurement is neutral.

**Status:** closed decision.

**Reason:** `ctx$vec` is not only a speed lane. It gives cross-sectional
strategies a direct universe-aligned surface, aligns the public callback
contract with the R-side substrate round, and avoids making users hand-roll
`ctx$bars$instrument_id == id` scans. If Spike 5 shows no material speedup
over scalar helpers, the documentation should say "advanced vector view" rather
than "recommended high-throughput path above N instruments." If Spike 5 shows
a win, documentation should include the measured threshold.

## v2 absorption verification

Seed v2 absorbed the response's load-bearing findings correctly.

- **Q1 collision fixed.** v1's direct `ctx$close` / `ctx$open` vector slots
  are replaced by the `ctx$vec` namespace. This addresses the collision with
  scalar helpers installed at `R/pulse-context.R:375-412`.
- **Q4 feature contract fixed.** v2 acknowledges that current
  `ctx$feature(instrument_id, feature_id)` is scalar and that
  `ctx$vec$feature(feature_id)` is new contract. This matches
  `R/pulse-context.R:54-96`, `R/runtime-projection.R:332-367`, and
  `inst/design/contracts.md:380-385`.
- **Positions shape fixed.** v2 keeps `ctx$positions` sparse named numeric and
  adds `ctx$vec$positions` as the full universe-aligned view. This matches
  observable tests at `tests/testthat/test-pulse-context-accessors.R:14-45`
  and `tests/testthat/test-execution-spec.R:151-170`.
- **Unknown-id behavior added.** v2 adds Q6 and recommends error-by-default,
  aligning with `R/pulse-context.R:511-529`.
- **Snapshot/retention semantics added.** v2 adds Q7 and resolves it with the
  public-list / internal-env split.
- **Citation fixes absorbed.** v2 corrects the v0.1.8.9 closeout residual to
  #1, expands the fold-engine citation to `R/fold-engine.R:181-220`, and
  describes the ctx as a 12-slot base list plus helper-added slots.

Synthesis correction: v2 occasionally writes `ctx$vec$feature(id)` where the
intended argument is a feature id. This synthesis binds
`ctx$vec$feature(feature_id)` and treats the `id` wording as a placeholder
typo, not a design issue requiring seed v3.

## Code-citation verification

Load-bearing citations were spot-checked against the current source:

| Citation | Verified result |
|---|---|
| `R/fold-engine.R:181-220` | Verified. Lines 181-194 build the base ctx list, line 195 assigns class, and lines 197-220 attach fast or regular helpers. |
| `R/pulse-context.R:375-412` | Verified. The helper bundle installs scalar `bar`, `open`, `high`, `low`, `close`, `volume`, `position`, `flat`, `hold`, `targets`, and `current_targets` functions. |
| `R/pulse-context.R:54-96` | Verified. `ledgr_feature_accessor()` returns `function(instrument_id, feature_name, default = NA_real_)` and returns one scalar feature value or default. |
| `R/pulse-context.R:511-529` | Verified. Unknown instruments fail loudly with a message listing `ctx$universe`. |
| `R/pulse-context.R:654-656` | Verified. Pulse context validation requires a `ledgr_pulse_context` object that is also a list. |
| `R/execution-spec.R:41-100` | Verified. This is the execution-spec constructor; `instrument_ids` is stored at line 72 and no `id_to_idx` exists yet. |
| `R/runtime-projection.R:130-167` | Verified. Internal scalar `ledgr_projection_feature_at()` exists; no public `ctx$feature_at` exists. |
| `inst/design/contracts.md:380-385` | Verified. The context contract pins scalar `ctx$feature(instrument_id, feature_id)` and bundled `ctx$features(instrument_id, feature_map)`. |
| `vignettes/strategy-development.qmd:174-175` | Verified. The strategy guide lists `ctx$open(id)`, `ctx$close(id)`, and `ctx$feature(id, feature_id)`. |
| `vignettes/strategy-development.qmd:583-643` | Verified. The guide describes scalar feature lookup as the foundation and teaches `ctx$features(id, mapped_features)`. |
| `tests/testthat/test-pulse-context-accessors.R:25-43` | Verified. Tests assert helper slots are functions and `ctx$close("A")` works. |
| `tests/testthat/test-execution-spec.R:151-170` | Verified. Tests observe shuffled `ctx$positions`, realign via `ctx$positions[ctx$universe]`, and assert sparse/storage-order behavior. |
| `tests/testthat/test-documentation-contracts.R:220` | Verified. Documentation tests expect `ctx$feature(id, feature_id)` in the strategy context help. |

No phantom citations were found in seed v2. The horizon entry still uses
"v0.1.9" as generic substrate language while this RFC is scoped to
v0.1.8.10; seed v2 correctly treats that as a horizon-language cleanup for
the v0.1.8.10 closeout, not a blocker for this RFC.

## Open questions promoted to spec-cut

### `ctx$idx()` map representation

Spike 5 / LDG-2509 should measure the named integer vector, env-backed map,
and `collapse::fmatch`-based lookup candidates. The ticket writer chooses the
winner inside the v0.1.8.10 window. This is not a future RFC.

Decision rule for ticket cut:

- choose the fastest measured candidate that is safe under parallel sweep
  serialization;
- if candidates are within measurement noise, choose the simpler serializable
  representation;
- document the chosen representation in the ticket acceptance criteria.

### Documentation threshold wording

Spike 5 should provide the threshold language for the strategy guide. If
`ctx$vec` materially beats scalar helpers at xlarge, docs may call it the
recommended high-throughput path. If it only beats filtered data-frame access
or is neutral against scalar helpers, docs should frame it as an advanced
universe-aligned vector view and avoid speed claims beyond the measured case.

This is a spec-cut wording decision because it depends on Spike 5 numbers, not
a separate RFC.

## Future obligations recorded

### Feature-engine vector surface beyond single-feature reads

This synthesis binds only `ctx$vec$feature(feature_id)`. Bulk multi-feature
reads, feature-map vector output, lookback-window vector access, alias-map
vector interactions, and any `ctx$feature_at(feature_id, idx)` public scalar
shortcut require a later feature-engine RFC if they become necessary. Target
window: v0.1.9 or later, after v0.1.8.10 measurements show whether the single
feature vector is enough.

### Stronger read-only enforcement

v0.1.8.10 uses documented convention plus mutation-leak tests. If post-CRAN or
maintainer-owned workflows need hard immutability, a later contract-hardening
RFC can evaluate locked bindings, active bindings, copy-on-access, or an R6-like
read-only context. Target window: post-CRAN or when a real mutation bug appears.

### Public compiled-strategy callback boundary

The `ledgrcore` boundary is out of scope. The horizon's 2026-06-01 K1 update
moved that measurement into a separate `ledgrcore-spike` repo. If K1 later
authorizes a compiled core, the compiled strategy callback boundary gets its
own RFC. Target window: after the separate repo spike reports against
post-v0.1.8.10 production R.

### Horizon language cleanup

The 2026-06-01 substrate horizon entry uses v0.1.9 generically while this
addendum targets v0.1.8.10. A post-synthesis or v0.1.8.10 closeout horizon
entry should clarify that this strategy callback addendum landed or parked in
the v0.1.8.10 closing round. This is documentation hygiene, not a design
question.

## Implementation handoff to v0.1.8.10 ticket cut

Ticket cut should work from this binding design:

- public ctx remains a list-backed `ledgr_pulse_context`;
- existing scalar helpers remain unchanged;
- add `ctx$vec` with universe-aligned vectors for OHLCV, positions, and
  `feature(feature_id)`;
- add `ctx$idx(instrument_id, missing = ...)`;
- build the id map once per execution spec, with representation chosen from
  Spike 5 results;
- keep reusable-env work internal-only.

Source surfaces to touch:

- `R/execution-spec.R:41-100`: add the id map and validation.
- `R/fold-engine.R:181-220`: pass the map/vector context into ctx construction
  and helper attachment.
- `R/pulse-context.R`: add `ctx$vec`, `ctx$idx()`, validation for the new slot,
  and helper construction while preserving existing helper functions.
- `R/runtime-projection.R:130-167` and `R/runtime-projection.R:332-367`: add or
  route a bulk vector feature read path for `ctx$vec$feature(feature_id)`.
- `inst/design/contracts.md:380-385`: extend, do not replace, the scalar
  feature contract language.
- `vignettes/strategy-development.qmd:174-175, 583-643`: add a new vector
  access section while preserving scalar helper teaching.
- `tests/testthat/test-documentation-contracts.R:220`: update docs assertions.

Required parity and regression gates:

- `ctx$vec$close[ctx$idx(id)]` equals `ctx$close(id)` for every universe id.
- `ctx$vec$positions[ctx$idx(id)]` equals `ctx$position(id)` for every universe
  id, with missing sparse positions filled to zero.
- `ctx$vec$feature(feature_id)[ctx$idx(id)]` equals
  `ctx$feature(id, feature_id)` for every universe id and feature id.
- Unknown `ctx$idx(id)` errors by default and returns `NA_integer_` only under
  the explicit opt-in.
- Mutating `ctx$vec` inside a strategy does not affect fold internals, later
  pulses, or stored results.
- Existing scalar helper tests continue to pass unchanged.
- Documentation tests cover both scalar and vector patterns.

## Recommendation on next step

Proceed to final review by Claude, then to v0.1.8.10 ticket cut if final
review passes. No maintainer escalation is required because the remaining
product-level choices are either already maintainer-confirmed (Q4 and Q7) or
closed by this synthesis (Q1, Q5, Q6, Spike 5 contingency). No seed v3 is
needed because v2 absorbed the response findings; the only correction is the
`ctx$vec$feature(feature_id)` argument wording standardized here. The only
spec-cut-open item is Q3 map representation, and Spike 5 is the correct
measurement surface for that choice.

## Process notes

- Role rotation is satisfied: Claude wrote seed v1 and seed v2, Codex wrote
  the response and this synthesis. Final review should be Claude's stage.
- File naming complies with `rfc_cycle.md`.
- This synthesis does not edit v1, v2, or the response.
- This synthesis intentionally separates same-window spec-cut questions from
  future obligations per `rfc_cycle.md`.
- No implementation code or ticket text is authorized by this file until final
  review passes and the v0.1.8.10 spec packet cuts implementation tickets.
