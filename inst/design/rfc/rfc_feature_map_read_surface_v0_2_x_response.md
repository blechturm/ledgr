# Response: Feature-Map Read Surface

**Status:** Type 2 adversarial response; input to seed v2.
**Respondent:** Codex
**Date:** 2026-10-05
**Responds to:** `rfc_feature_map_read_surface_v0_2_x_seed.md`

**Active design input:**
`../ledgr_v0_2_2_spec_packet/research_strategy_ux_brief.md`. The brief is a
non-binding account of the cross-RFC research UX. This response uses its
minimal-context and singular-read direction where the current tree supports
it; seed v2 remains responsible for accepting, changing or rejecting that
direction within this RFC's scope.

## Verdict

The product gap is real and now measured more strongly than the seed could
measure it. Active-alias strategies still need one scalar call per instrument,
and the package teaches that exception in the demo and several articles. A
whole-universe alias read belongs in v0.2.2.

The seed's preferred API is no longer the smallest or most coherent way to
close the gap. It chose plural `ctx$vec$features()` mainly to keep aliases and
engine IDs in separate namespaces. Since the seed, ledgr has prohibited the
only case in which those namespaces select different series under one name.
The accepted historical reader also binds one feature per call. Adding a
second plural accessor would preserve a distinction whose ambiguity has been
removed, materialize features the caller may not need, and give current and
historical reads different addressing shapes.

Revise the seed around one deterministic singular read rule. Widen
`ctx$vec$feature()` to accept either an active alias or a concrete engine ID,
and let `ledgr_signal_feature()` use the same resolver. Do not add
`ctx$vec$features()` or an `alias =` argument unless seed v2 demonstrates a
separate need that the singular route cannot meet.

## Reviewer Bias And Method

I prefer subtraction and one public spelling over symmetric API grids. That
bias could underweight the convenience of reading several aliases at once. I
checked it against the current implementation rather than the seed's old
baseline.

I traced the post-seed feature-map repairs, accessor-scaling work, contracts,
accepted historical-projection shape and current v0.2.2 macro plan. I ran the
five focused feature-map, accessor, active-alias, warning and inspection test
files under R 4.6.1 with DuckDB 1.5.6.9000. I also ran:

- a public-path pulse probe with a parameterized active map; and
- a bounded prepared-state clock comparing the existing scalar alias loop
  with singular and plural whole-universe extraction.

The clock is orientation evidence, not an end-to-end effect estimate. It can
show that call-count removal is material; it cannot choose an API by itself.

## Facts That Changed After The Seed

The response must not pretend these are still open questions.

1. **Alias/ID collisions are settled.** `ledgr_feature_map()` calls
   `ledgr_validate_feature_map_alias_id_collisions()` at construction, and
   `ledgr_resolve_feature_map()` reconstructs parameterized maps through that
   constructor (`R/feature-map.R:116-132,150-170,215-219`). A cross-entry
   collision fails; an alias equal to its own feature ID remains valid.
   Public run and sweep isolation are covered by LTB-0115. This is the seed's
   Q2 position A, already implemented and accepted.
2. **Named outer bundles are settled.** A named bundle entry now fails with
   `ledgr_invalid_feature_map` and directs the author to the bundle's `prefix`
   or `naming` argument (`R/feature-map.R:100-106,136-147`). Q5 is no longer a
   choice for this cycle.
3. **Accessor preparation is shipped.** The run creates one prepared feature
   lookup and reuses it for scalar ID and alias access
   (`R/pulse-context.R:427-466`). Workstream 7 measured an active-alias bundle
   read at about 7.4 microseconds and no recorded R-heap allocation, down from
   about 17.5 microseconds and 4,048 bytes. The remaining cost is proportional
   call count, not unresolved lookup construction.
4. **Inspection now refuses cleanly but remains unusable for this case.** Both
   public inspection helpers raise `ledgr_feature_factory_requires_params` for
   an unresolved map (`R/feature-inspection.R:8-11,56-61,94-108,189-196`).
   Their message says to materialize the map, but
   `ledgr_resolve_feature_map()` is not exported. Runs and pulse snapshots can
   resolve it internally; a user cannot perform the instructed standalone
   step through the public API.
5. **Signal semantics changed.** The current contract preserves raw values for
   every decision-axis ID and carries `ctx$vec$admissible` in the signal's
   `eligible` attribute (`contracts.md:736-743,780-790`;
   `R/strategy-helpers.R:50-54`). The seed's repeated description of helper
   "masking" is obsolete.

## Direction Worth Keeping

The following parts of the seed survive:

- active aliases need a whole-universe read;
- the read uses the run- or candidate-local resolved map and prepared indexes;
- feature computation, fingerprints and all identity hashes stay unchanged;
- warmup `NA`, decision-axis order, empty axes and unknown-name refusal stay
  aligned with the existing plane;
- inspection accepts concrete `feature_params` without inventing grid-level
  inspection; and
- the scalar-loop warning expands only after a replacement exists.

No new spike is needed. The uncertainty is public shape, not executable
feasibility.

## Blocking Findings

### F1. The plural accessor solves the measured problem with extra surface

At 500 instruments by 1,260 pulses the current strategy makes 630,000 alias
bundle calls. Against the prepared current tree, the scalar loop took about
5.24 seconds; extracting an equivalent universe vector took about 0.01
seconds. With five aliases over 250 pulses, the scalar loop took about 1.83
seconds and both singular and plural extraction rounded to about 0.01 seconds.
Values were checked against the current accessor.

This proves the need to remove the instrument loop. It does not prove that all
aliases should be returned on every call. A strategy may need one alias, while
the seed's list allocates every mapped plane. That shape is especially hard to
justify now that the v0.2.2 macro plan treats peak memory and worker
multiplication as architectural constraints and prohibits retaining equivalent
representations for convenience (`macro_plan.md:47-54,171-177`).

The accepted historical projection makes the mismatch sharper:
`ctx$window()` reads one feature per call and returns one
instrument-by-lookback matrix; it explicitly rejects a list or multi-feature
tensor (`rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md:
97-107`). Current and historical reads should not acquire different naming
models without evidence that the difference is necessary. The active research
UX brief also treats derived frames as exported helper results rather than a
reason to expand `ctx` with another plural representation. That direction is
not authority, but it makes the seed's extra container something seed v2 must
justify rather than inherit.

Smallest correction: widen the existing singular plane reader. Resolution is
deterministic:

1. if the requested name is an active alias, use its candidate-local concrete
   feature ID;
2. otherwise read it as a concrete feature ID; and
3. fail with the existing unknown-feature vocabulary when neither exists.

The collision rule makes step 1 safe: a valid map cannot use that same string
for a different concrete series. An own-ID alias selects the same series under
either interpretation.

Seed v2 may retain an optional explicit-map argument if parity with
`ctx$features(id, map)` is a real requirement. It must use the existing
run-local exact-map memo and may not repeat resolution per read. It should not
add a plural accessor merely to make the API table rectangular.

### F2. `alias =` duplicates the namespace distinction inside the helper

If `ctx$vec$feature(name)` resolves both accepted kinds of readable name,
`ledgr_signal_feature(ctx, name)` can call the same resolver. Adding a mutually
exclusive `alias =` argument would force users to classify a name that ledgr
can resolve unambiguously and would create two routes to the same signal.

The binding semantics are raw values plus `eligible`, not identical masking.
The signal's origin should record the name the author supplied; the resolved
map remains part of execution identity. `ledgr_signal_return()` should stay a
small exact-ID specialization. Parameterized return strategies can use the
generic helper with an active alias instead of making the return helper infer,
register or resolve a grid.

### F3. The inspection refusal describes a public route that does not exist

The seed is right to add `feature_params` to
`ledgr_feature_contracts()` and `ledgr_feature_contract_check()`. The current
alternative is not merely inconvenient: their documentation tells users to
materialize an unresolved map, while the materializer is internal.

Both helpers should resolve through the same internal function as a run when
`feature_params` is supplied. Without concrete parameters they keep the
current classed refusal. This is smaller than exporting a general materializer
whose lifecycle and identity promises would outlive the two inspection uses.

### F4. The warning must follow the replacement, not the RFC title

After the singular alias plane ships, a loop of active-alias
`ctx$features(id)` calls at the existing threshold may warn and name the exact
replacement. The 99/100 boundary and result neutrality remain appropriate.

Explicit-map loops should warn only if the shipped plane reader accepts the
same explicit-map input. Otherwise the warning would again diagnose a pattern
without supplying an equivalent public route. Nothing here justifies warning
ordinary one-off scalar reads.

### F5. The RFC index has pre-decided an active design question

The RFC pipeline's context-frame-retirement row currently names an
"alias-keyed `ctx$vec$features()`" as a prerequisite. The feature-map row is
still Active, and neither the seed nor an accepted synthesis binds that API.
The accepted macro plan is correctly neutral: aliases, concrete IDs and
whole-universe reads must be coherent (`macro_plan.md:156-177`).

Seed v2 should treat the pipeline wording as planning drift, not authority.
The row should be corrected when this cycle reaches synthesis. An index cannot
settle the RFC it indexes.

## Failure Scenarios For The Revised Direction

| Scenario | Required result | Where the direction still fails |
| --- | --- | --- |
| Dense run, active alias | Singular plane equals scalar alias reads in decision-axis order | Multi-alias callers make several cheap column reads |
| Availability run with held nonmember | Raw value is retained; eligibility remains a separate plane or signal attribute | A caller can still misuse raw values outside the helper pipeline |
| Alias equal to own feature ID | One series, same value under either interpretation | None specific to naming |
| Alias equal to another feature ID | Construction or resolution refuses before execution | Previously accepted development maps break, intentionally |
| Concrete ID with an active map | Existing concrete plane read remains unchanged | Authors can still bypass the stable strategy alias deliberately |
| Unknown name | Existing classed unknown-feature failure, with useful available names | Long lists may make the message noisy |
| Two sweep candidates | The same alias resolves to each candidate's own series | Incorrect candidate-local preparation would contaminate results |
| Explicit map | Same value as the scalar explicit-map read, if that input is retained | Memo invalidation remains part of the accessor implementation |
| Empty decision axis | Named or unnamed zero-length numeric plane under the existing convention | No plural shape is available for introspection |
| Parameterized inspection | Contracts equal the run's resolution for the same parameters | Grid-union inspection remains deliberately absent |
| Future `ctx$window(alias)` | Uses the same name resolver, one feature per call | Historical preparation and missingness remain owned by WS3 |

The admitted inconvenience is several singular reads for a strategy using
several aliases. At the measured two-to-five-alias shape, that is tiny beside
the instrument loop it replaces and avoids making a multi-feature container a
second first-class representation. If implementation evidence contradicts
that, the synthesis can permit a requested-subset bulk read; it should not
default to every alias.

## Required Revision

Write seed v2 with these changes:

1. replace Q1 position B with the deterministic singular resolver above;
2. remove Q2 and Q5 from the open design and record their accepted outcomes;
3. make `ledgr_signal_feature()` use the same resolver without `alias =`, and
   state raw-value-plus-eligibility semantics;
4. retain Q4's direct `feature_params` support and explain why no public
   materializer is added;
5. scope Q6 to inputs for which the shipped plane is an exact replacement;
6. bind the resolver as the naming prerequisite shared with future
   `ctx$window()` and the proposed on-demand history helper in the research UX
   brief, without designing history or scheduling here;
7. require dense, availability, empty-axis, run, sweep and walk-forward parity,
   plus an allocation and elapsed-time record at the registered shape; and
8. update sequencing: accessor preparation and the pre-tag guards have already
   shipped, and this synthesis now precedes v0.2.2 WS3 implementation.

The response does not reopen feature-map identity, bundle namespaces,
historical missingness, recursive-indicator semantics or context-frame
retirement. Those owners consume the naming rule after it is accepted.

TYPE_2_DISPOSITION: REVISE_SEED
