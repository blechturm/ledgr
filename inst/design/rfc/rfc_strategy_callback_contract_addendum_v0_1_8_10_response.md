# RFC Response: Strategy Callback Contract Addendum (v0.1.8.10)

**Status:** Response-stage adversarial review. Not accepted. Not
authorized implementation scope.
**Cycle:** v0.1.8.10 single-core optimization round.
**Relates to:** `rfc_strategy_callback_contract_addendum_v0_1_8_10_seed.md`.
**Authored:** Codex (response stage; seed author was Claude per role rotation
in `inst/design/rfc_cycle.md`).

## Summary verdict

Support the seed's architectural direction, but push to seed v2 before
synthesis. The R-side substrate motivation is sound: v0.1.8.9 removed the
largest buffer-write pathologies, and the remaining strategy-callback surface
still has avoidable per-pulse lookup and construction cost. The seed is not
ready to synthesize because two load-bearing code reads are wrong: `ctx$close`
is already an accepted scalar helper function (`ctx$close(id)`), so direct
vector slots would not be additive; and `ctx$feature("sma_20")` is not a
vector-returning accessor today, because the current contract is
`ctx$feature(instrument_id, feature_id)`. The response also finds that
`ctx$positions` is named numeric but not guaranteed universe-aligned today,
and that reusable in-place ctx slots need an explicit snapshot/retention
semantics decision before they are exposed to strategy code.

## Code-citation findings (F1)

| Seed claim / citation | Verified? | Actual code / document state | Response finding |
|---|---:|---|---|
| RFC-cycle stage is response-stage adversarial review by different author. | Yes | `inst/design/rfc_cycle.md` requires seed, response, and synthesis artifacts, with the response written by a different author and not editing the seed in place. | Process shape is correct. This artifact should be the response file, not a seed edit. |
| Horizon motivation is the 2026-06-01 R-side substrate entry. | Yes, with version wording caveat | `inst/design/horizon.md:543-611` frames R-side data structures as shared substrate before `ledgrcore`, including integer-indexed accessors around lines 594-596. | The seed's K1 boundary is aligned with the horizon. The horizon text still says v0.1.9 in places while this RFC is v0.1.8.10; synthesis should clarify whether that is stale version language or a deliberate future-minor reference. |
| v0.1.8.9 closeout residual #2 is R-side substrate. | No | `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md:140-151` lists R-side substrate as residual target #1; residual #2 is ephemeral phase visibility. | Citation number is stale or mistaken. The substance is present, but the seed should cite residual #1 or avoid numbering. |
| `R/fold-engine.R:180-194` is the pulse-context constructor. | Partly | The fold constructor starts at `R/fold-engine.R:181`, creates a 12-slot list through line 194, assigns class at line 195, then attaches fast or regular helpers at `R/fold-engine.R:197-220`. | The cited range captures only the base list. The strategy-visible context surface is really `R/fold-engine.R:181-220`, because helper attachment is part of the public shape. |
| Current context has "12+ slots". | Partly | The base list has exactly 12 slots before helper attachment: `run_id`, `ts_utc`, `universe`, `bars`, `feature_table`, `positions`, `cash`, `equity`, `seed`, `pulse_seed`, `state_prev`, `safety_state`. Helpers then add slots like `feature`, `features`, `features_wide`, `.pulse_lookup`, `open`, `close`, `position`, `flat`, and `hold`. | Say "12-slot base list plus helper slots", not "12+ slots", if the point is code-citation precision. |
| Context is a named-list pulse context today. | Yes | `R/fold-engine.R:181-195` creates a list and sets class. `R/pulse-context.R:654-656` validates that a pulse context both inherits `ledgr_pulse_context` and is a list. | Spike 4's reusable-env idea is not compatible with current validation unless validation changes or the env is only an internal helper backing a list-like public context. |
| `ctx$positions` is named numeric and indexable by name and integer. | Partly | `R/fold-engine.R:187` passes `state$positions`. `R/pulse-context.R:724-740` requires named numeric positions with names inside universe, but does not require universe length or universe ordering. `tests/testthat/test-pulse-context-accessors.R:14` creates sparse `positions <- setNames(c(3), "B")`. | It is named numeric, but not necessarily universe-aligned. Integer indexing today is storage-order over held positions, not universe index. The seed's compatibility claim needs this distinction. |
| `ctx$positions` can be changed to universe-aligned while preserving named lookup. | Possible but not proven | `tests/testthat/test-execution-spec.R:151-170` intentionally observes shuffled `ctx$positions` and realigns via `ctx$positions[ctx$universe]`. Existing helpers also build hold targets by mapping sparse positions into universe order. | This is a real contract shift, not just documentation. Tests and docs must decide whether sparse named positions remain visible or whether `ctx$positions` becomes full-length universe-aligned. |
| `ctx$close`, `ctx$open`, etc. are new slots. | No | `R/pulse-context.R:375-412` builds helper functions named `open`, `close`, `high`, `low`, `volume`, `position`, `flat`, and `hold`. `tests/testthat/test-pulse-context-accessors.R:25-43` asserts these are functions and `ctx$close("A")` works. `vignettes/strategy-development.qmd:174` documents `ctx$open(id)`, `ctx$close(id)`. | Direct vector slots named `ctx$close` would overwrite an accepted scalar helper. Q1's recommended direct slots are not additive. |
| `ctx$feature("sma_20")` already returns a universe-aligned vector. | No | `R/pulse-context.R:54-96` defines the regular accessor as `function(instrument_id, feature_name, default = NA_real_)`, returning one scalar. `R/runtime-projection.R:332-367` defines the projection-backed accessor with the same two-argument scalar shape. `inst/design/contracts.md:380-385` pins `ctx$feature(instrument_id, feature_id)`. | Q4 is built on a false premise. A vector-returning feature accessor would be new API and needs its own name and tests. |
| A scalar feature-at primitive exists nowhere today. | Partly | `R/runtime-projection.R:130-167` has internal `ledgr_projection_feature_at(projection, instrument_id, feature_id, pulse_idx, ...)`, but no public `ctx$feature_at`. | There is internal precedent for scalar feature-at, but not for the seed's proposed public shape. |
| `R/fold-reconstruction.R:514-526` is the sweep-summary position reconstruction loop cited by substrate context. | Yes | The cited range loops over `instrument_ids`, subsets `events$instrument_id == id`, uses `cumsum(position_delta[ev_idx])`, then `findInterval()` to fill `positions_mat`. | Citation is accurate. It supports the "matrix-canonical / primitive structure" substrate context, but it is not direct evidence for the callback API shape. |
| `R/execution-spec.R` can host an `id_to_idx` map. | Yes, as a new field | `R/execution-spec.R:41-100` builds the execution-spec list and currently stores `instrument_ids` at line 72. No `id_to_idx` field exists today. | A per-backtest map has a natural home, but it must be added to constructor and validation. Prefer immutable named integer vector unless Spike 5 proves an env is materially faster. |
| Existing guides primarily document filtered data-frame access. | Mixed | Some old examples and tests still use `ctx$bars$close[...]` (`tests/testthat/test-backtest-audit-log-equivalence.R:23`; old design packet examples), but current strategy guide documents scalar helpers: `ctx$open(id)`, `ctx$close(id)`, `ctx$feature(id, feature_id)` at `vignettes/strategy-development.qmd:174-175`. | The seed overstates the filtered data-frame pattern as the main current contract. The addendum should benchmark against both accepted scalar helpers and filtered data-frame access. |

## Question-by-question review (F2)

### Q1: Naming convention

**Seed recommendation:** direct slots such as `ctx$close`, `ctx$open`,
`ctx$positions`.

**Response read:** disagree with direct slots as written; support a
high-throughput surface under a non-conflicting namespace or suffix.

**Evidence:** `ctx$close` and related names are already helper functions.
`R/pulse-context.R:375-412` installs them, `tests/testthat/test-pulse-context-accessors.R:25-43`
asserts they are functions, and `vignettes/strategy-development.qmd:174`
documents them. Assigning a numeric vector to `ctx$close` would break
`ctx$close(id)` immediately. Pre-CRAN zero-users removes external migration
cost, but it does not remove the internal accepted-example and test-suite
cost.

**Missed dimension:** the seed treats "direct slots" as additive, but they are
name collisions. The response-stage alternatives worth putting into v2 are:

- namespaced vectors such as `ctx$vec$close`, `ctx$bars_vec$close`, or
  `ctx$prices$close`;
- suffixed vector slots such as `ctx$close_vec`, `ctx$open_vec`;
- scalar functions such as `ctx$close_at(idx)` if validation and unknown-id
  policy are more important than vector ergonomics;
- an accessor object such as `ctx$at(idx)$close` only if Spike 5 shows the
  object construction cost is negligible, which is unlikely.

There is also an R partial-matching footgun for list `$` access: adding many
similar names increases accidental partial matches in interactive use. That is
secondary to the `ctx$close` collision, but it favors explicit namespace names
over adding many top-level names.

### Q2: Universe indexing convention

**Seed recommendation:** 1-based indexing.

**Response read:** support 1-based indexing.

**Evidence:** R vectors are 1-based, current matrices and vectors are R-native,
and `R/runtime-projection.R:130-167` uses integer row and pulse indices in the
normal R convention.

**Missed dimension:** unknown-instrument behavior should not default to silent
`NA`. Current scalar helpers fail loudly for unknown instruments:
`R/pulse-context.R:511-529` requires a valid id and reports available
`ctx$universe`; tests assert this at
`tests/testthat/test-pulse-context-accessors.R:255-256`. The seed says
`ctx$idx(id)` returns `NA` for unknown instruments. That is safer for
low-level optional matching but weaker than the existing strategy contract. A
better v2 question is whether `ctx$idx("BAD")` errors by default with an
explicit `missing = "NA"` opt-in, or returns `NA` and requires every example to
guard it.

### Q3: `ctx$idx()` caching policy

**Seed recommendation:** per-backtest cache built at execution-spec
construction.

**Response read:** support per-backtest mapping, with implementation caveats.

**Evidence:** universe is fixed per execution spec. `R/execution-spec.R:41-100`
already stores `instrument_ids`, and no current code suggests universe changes
mid-fold. A map derived once from `instrument_ids` is valid for run and sweep
candidates.

**Missed dimension:** the seed assumes "one integer-keyed env", but the fastest
and safest map may be a named integer vector or integer vector plus name table,
not an env. A named integer vector is immutable enough for validation and
worker serialization; an env map may be faster but has more aliasing and
parallel-worker implications. Spike 5 should benchmark the actual map choices.
If an env map wins, v2 should say where it lives: execution spec, fast-context
state, or pulse lookup env. It should not be rebuilt per pulse.

### Q4: Feature accessor shape

**Seed recommendation:** keep `ctx$feature("sma_20")[idx]` canonical; defer
`feature_at`.

**Response read:** disagree; the existing accessor shape is scalar
`ctx$feature(instrument_id, feature_id)`, so `ctx$feature("sma_20")[idx]` is
not current API and should not be made canonical by assumption.

**Evidence:** `R/pulse-context.R:54-96` and `R/runtime-projection.R:332-367`
both implement `function(instrument_id, feature_name, default = NA_real_)`.
`inst/design/contracts.md:380-385` and
`vignettes/strategy-development.qmd:583-643` document that scalar shape.
Tests under `tests/testthat/test-pulse-context-accessors.R` repeatedly assert
`ctx$feature("AAA", "signal")` and unknown-feature errors.

**Missed dimension:** feature vectors already exist as `ctx$features_wide`
views in some paths (`R/pulse-context.R:253-281`,
`tests/testthat/test-pulse-context-accessors.R:203-204`), but that is a
data-frame-like wide view, not a one-argument `ctx$feature()` contract. A v2
seed should open a real naming decision: `ctx$feature_vec(feature_id)`,
`ctx$features_vec[[feature_id]]`, `ctx$feature_at(feature_id, idx)`, or
no feature-vector API in v0.1.8.10. The feature surface has enough existing
contract and tests that it should not be bundled under an incorrect premise.

### Q5: Read-only enforcement

**Seed recommendation:** documented convention only.

**Response read:** support documented convention for ordinary mutation, but
the seed missed a reusable-slot snapshot semantics issue that must be resolved
before accepting Spike 4-based ctx reuse.

**Evidence:** the fold engine reads from its own state and matrices, not from
mutated ctx slots after strategy return. Target validation and fill execution
continue from `result$targets` and internal state. Tests already verify that
strategy mutation of `ctx$bars` does not leak into later pulses
(`tests/testthat/test-sweep.R:913`, `1017`, `1027`).

**Missed dimension:** reusable env-backed slots plus in-place vector mutation
can make strategy-retained objects change across pulses. Strategies may legally
put prior-pulse values into `state_update`; `R/fold-engine.R` stores
`state_prev_mem <- result$state_update` after serializing the state update.
If the strategy stores `ctx$close` itself and future pulses update the same
vector object in place, old `state_prev` can observe new values. Current
fresh-list/fresh-data-frame behavior mostly avoids that aliasing. A v2 seed
needs one of:

- document "do not retain ctx slot objects; copy with `as.numeric()` if needed"
  and test it;
- update slots by rebinding fresh vectors rather than in-place mutation;
- expose immutable vector copies and accept the cost;
- reserve reusable in-place slots for internal helpers, not public ctx objects.

Without this, "read-only convention only" is under-specified for the exact
substrate path the seed wants.

## Substrate dependency review (F3)

| Dependency | Seed mapping | Response read |
|---|---|---|
| Spike 3 / LDG-2507: primitive `state$positions` | Provides universe-aligned numeric `state$positions` plus `id_to_idx`; enables `ctx$positions` and `ctx$idx()`. | Partly right. It can provide the primitive representation and the id map, but it does not by itself decide the public `ctx$positions` shape. Today `ctx$positions` may be sparse named numeric. Public exposure can be a universe-aligned view even if internal state is primitive, but that is an extra contract decision. |
| Spike 4 / LDG-2508: reusable pulse-context env | Provides stable slot identity across pulses. | Performance dependency, not API dependency. Integer-indexed accessors can be added to fresh list contexts, but if Spike 4 fails the performance case weakens. Also current validation requires `ctx` to be a list (`R/pulse-context.R:654-656`), so an env-backed public ctx requires validation and tests to change. |
| Spike 5 / LDG-2509: integer-indexed accessors | Provides measured per-pulse cost and guidance threshold. | Load-bearing for whether the addendum is worth v0.1.8.10 scope. If Spike 5 only beats filtered data-frame access but not existing scalar helpers (`ctx$close(id)`, `ctx$feature(id, feature_id)`), the documentation guidance changes materially. |

The seed correctly keeps the `ledgrcore` compiled boundary out of scope. The
2026-06-01 horizon entry split K1 into a separate `ledgrcore-spike` repo, and
this RFC should stay about the R-side strategy callback substrate.

Missing dependency mapping:

- **Feature engine / projection surface.** A vector-returning feature accessor
  depends on runtime projection shape (`R/runtime-projection.R`) and existing
  `ctx$features_wide` behavior. This is not provided by Spikes 3 or 4.
- **Documentation contract tests.** The docs and tests pin scalar helpers:
  `tests/testthat/test-documentation-contracts.R:220` expects
  `ctx$feature(id, feature_id)` in help output, and the strategy guide pins
  `ctx$close(id)` and `ctx$feature(id, feature_id)`.
- **Unknown-id semantics.** Current helpers fail loudly. `ctx$idx()` returning
  `NA` would be a deliberate weakening unless an explicit opt-in path is used.
- **Snapshot/retention semantics.** Reusable ctx slots need a policy for
  strategy-retained vectors, especially when `state_update` carries previous
  values forward.

If Spike 3 fails: the addendum can still add an `idx` resolver and price
vectors from `bars_mat`, but `ctx$positions` should probably remain sparse
named numeric or be exposed through a separate universe-aligned view. If Spike
4 fails: the addendum may still be ergonomic and somewhat faster, but the
performance case must be revised. If Spike 5 fails to beat existing scalar
helpers at production scale: the addendum should probably park or shrink,
because ergonomics alone is weak when current scalar helpers are already
teachable.

## Backward-compatibility audit findings (F4)

Pre-CRAN/no-users framing means no external migration burden, but internal
coherence still matters.

- Accepted guides pin scalar helpers. `vignettes/strategy-development.qmd:174-175`
  lists `ctx$open(id)`, `ctx$close(id)`, and
  `ctx$feature(id, feature_id)`. The feature-map section at
  `vignettes/strategy-development.qmd:583-643` describes scalar feature
  lookup as the foundation.
- Tests pin scalar helpers. `tests/testthat/test-pulse-context-accessors.R:25-43`
  expects `ctx$open`, `ctx$close`, and related slots to be functions.
  `tests/testthat/test-pulse-context-accessors.R:203`, `314-320`, and
  `349-353` assert scalar `ctx$feature()` behavior and unknown-feature errors.
- Documentation tests pin scalar helper docs.
  `tests/testthat/test-documentation-contracts.R:220` expects
  `ctx$feature(id, feature_id)` in the strategy context help.
- `ctx$positions` sparse named behavior is observable. Tests create and
  observe shuffled/sparse named positions (`tests/testthat/test-execution-spec.R:151-170`;
  `tests/testthat/test-pulse-context-accessors.R:14-45`). A full
  universe-aligned `ctx$positions` would improve high-throughput use, but it
  changes what strategies see when they inspect `length(ctx$positions)` or
  `names(ctx$positions)`.
- Internal mutation can still change. `R/fold-engine.R:360` writes
  `state$positions[[instrument_id]] <- cur_qty + qty`. Spike 3 may change
  that internal representation, but the public ctx view should not force the
  internal state to keep slow named-vector writes if a primitive state wins.

The seed's "no removal in v0.1.8.10" policy is therefore load-bearing. It
should be strengthened to "no replacement of existing scalar helper names in
v0.1.8.10." Additive high-throughput accessors need new names.

## Decision space the seed didn't open (F5)

The seed closes too quickly on direct top-level slots. Additional decisions
that should be opened before synthesis:

1. **Vector namespace decision.** Since `ctx$close` is already a function, the
   first naming question should be whether vectors live under `ctx$vec`,
   `ctx$bars_vec`, `ctx$prices`, or suffixed names like `ctx$close_vec`.
2. **Unknown-id policy.** Decide whether `ctx$idx("BAD")` errors by default,
   returns `NA`, or supports both via an argument. Existing strategy helpers
   generally fail loudly.
3. **Retention/snapshot semantics.** Decide what happens if a strategy stores
   `ctx` slots in `state_update` or local closures. This is especially
   important if Spike 4 uses in-place updates.
4. **Feature-vector API scope.** Decide whether v0.1.8.10 includes feature
   vectors at all. If it does, give them a new name and verify no-lookahead,
   unknown-feature errors, warmup `NA`, and feature-map interaction.
5. **Smaller addendum option.** If Spike 5 is ambiguous, v0.1.8.10 could add
   only `ctx$idx()` and namespaced OHLCV vectors, leaving positions and feature
   vectors for a follow-up after Spike 3 and feature-engine measurements.
6. **Larger substrate option.** If Spike 4 strongly wins, a pure env-backed ctx
   might be worth considering, but that is a bigger contract migration because
   current validation requires list contexts and tests assert helper functions.

A fundamentally different compiled-strategy/declarative-target contract is not
recommended for this RFC. It belongs to a later K1 or strategy-compiler design,
and the horizon explicitly parks `ledgrcore` behind a separate repo spike.

## Recommendation on next step

Push to seed v2. The findings are not just synthesis wording changes: Q1's
recommended direct slots collide with existing accepted helper names, and Q4's
feature recommendation is based on a nonexistent vector-returning
`ctx$feature("id")` API. A seed v2 should:

- replace direct top-level `ctx$close`/`ctx$open` vector slots with a
  non-conflicting vector namespace or suffix;
- correct the feature accessor section to acknowledge the current scalar
  two-argument contract;
- distinguish sparse named `ctx$positions` today from proposed full
  universe-aligned position vectors;
- specify unknown-id behavior for `ctx$idx()`;
- add snapshot/retention semantics for reusable env-backed slots.

No maintainer escalation is required before seed v2 unless the maintainer wants
to decide the naming namespace immediately. Once those corrections are in the
seed, synthesis can likely proceed without another response round.

## Process notes

- Role rotation is satisfied: Claude authored the seed, Codex authored this
  response.
- File naming follows `rfc_<topic>_<window>_response.md`.
- The seed correctly keeps implementation code and K1 compiled-core boundary
  decisions out of scope.
- Future seeds should verify existing accepted examples before proposing
  additive names. In this case, a quick scan of `R/pulse-context.R`,
  `vignettes/strategy-development.qmd`, and
  `tests/testthat/test-pulse-context-accessors.R` would have caught both major
  surface-shape errors before response stage.
