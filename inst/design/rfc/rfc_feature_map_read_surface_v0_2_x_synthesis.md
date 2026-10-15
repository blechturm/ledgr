# Synthesis: Feature-Map Read Surface

Role: record; RFC-cycle synthesis and durable decision record.
Status: accepted
Authority: accepted synthesis; binds only its stated scope.

**Status:** Accepted by the maintainer on 2026-10-06 after Type 1 final review
and the in-place review patches below. Binding for the implementation ticket
cut.
**Date:** 2026-10-06
**Author:** Codex
**Source baseline:** `83e8376`
**Synthesizes:** `rfc_feature_map_read_surface_v0_2_x_seed_v2.md`,
`rfc_feature_map_read_surface_v0_2_x_response.md`, and historical seed v1.
**Revision note:** final review corrected the warning threshold and added the
accepted-obligation, pipeline and decision-bridge acceptance routes. The Cut 7
review then preserved the addendum's conditional `ctx$feature_at()` shortcut
in its existing follow-up route and corrected one already-applied index step.

This RFC uses "v1" as shorthand for the first implementation of the
feature-map read surface. ledgr's roadmap has no feature-map v1 milestone.
Post-v1 work lives in named follow-up RFCs at their own roadmap windows.

## 1. Decision

Accept seed v2's architecture, including the three choices left for
synthesis:

1. `ctx$feature()` widens alongside `ctx$vec$feature()` so every singular
   strategy read uses one alias-or-engine-ID rule.
2. Every public explicit-map consumer refuses a map that redefines an active
   alias or registered engine ID.
3. `ledgr_pulse_wide()` uses aliases as feature keys when a map applies and
   engine IDs otherwise; the conflicting contract clause is amended.

The response was right to reject a plural plane accessor. The measured defect
is 630,000 per-instrument bundle calls at the registered shape, not an unmet
need for a list of every feature plane. One prepared singular read closes that
defect with less API and retained-memory surface.

This synthesis changes naming and inspection semantics only. Feature
computation, warmup, fingerprints, no-lookahead, feature-map identity,
`config_hash`, `alias_map_hash`, `feature_set_hash`, decision-axis membership
and eligibility do not change.

## 2. Bound Design

### D1. One resolver for every singular strategy read

A requested feature name resolves in this order:

1. an alias in the run's or candidate's active map;
2. a concrete feature ID registered for that run or candidate; or
3. `ledgr_unknown_feature_id`.

The rule applies to:

- `ctx$vec$feature(feature_id)`;
- `ctx$feature(instrument_id, feature_name)`; and
- `ledgr_signal_feature(ctx, feature_id)`.

The existing formal argument names remain. Their documentation says that the
value may be an active alias or a concrete feature ID. Unknown-name messages
list active aliases and concrete IDs separately when an active map exists.

Alias-first resolution cannot change a valid result. In an active-map run all
registered feature IDs come from map entries. The settled collision rule
allows a string to be both alias and feature ID only when both identify that
entry's same series. Without an active map, current exact-ID behavior remains.

The scalar widening is accepted. Keeping the scalar exact-ID-only would make
the same name valid in the plane and signal helper but invalid in their scalar
twin. It would preserve a teaching exception without preserving an identity
or correctness distinction.

### D2. Singular, not plural

No `ctx$vec$features()`, requested-subset bulk reader or separate alias
accessor is added in v1. Reading several aliases means several singular plane
reads. Each is one prepared lookup and one column extraction, which removes
the measured instrument loop without constructing another first-class list or
tensor.

An implementation record may reopen only the requested-subset optimization if
it attributes material residual cost to repeated singular reads. It does not
authorize that surface in this cycle.

### D3. Explicit maps may add local names but may not redefine known names

The rule applies equally to all three public explicit-map consumers:

- `ctx$features(instrument_id, feature_map)`;
- `ledgr_pulse_features(pulse, feature_map)`; and
- `ledgr_pulse_wide(pulse, feature_map)`.

When a lookup is built, an explicit entry whose alias is already an active
alias or registered engine ID in that context or pulse must map to the same
concrete feature. Otherwise it fails with `ledgr_invalid_feature_map`, naming
the alias, requested target and series the name already selects.

New call-local names remain valid. Independent explicit maps may use the same
new name for different features because the map remains an explicit argument;
neither may rebind a name that already has meaning without that map.

This rule covers named character maps and concrete `ledgr_feature_map`
objects. A successful concrete-map lookup retains the existing last-identical
memo. Character maps remain uncached. Failed or non-identical input clears the
memo as already bound.

No singular plane read accepts an explicit map. A concrete map's caller can
obtain its feature IDs with `ledgr_feature_id(map)`; unresolved maps use the
candidate's active aliases after resolution. Explicit-map scalar loops remain
unwarned because no public plane reader accepts the same input.

### D4. Mapped wide views use stable aliases

When a feature map applies, `ledgr_pulse_wide()` uses its aliases as the wide
feature keys. Without a map it uses engine IDs. `ledgr_pulse_features()` keeps
both `alias` and `feature_id` columns.

This chooses seed v2 over the reviewer's initial preference for engine-ID wide
keys. An active alias is the stable research-facing name across sweep
candidates; the resolved engine ID changes with candidate parameters. The
long view preserves both names, and D3 prevents an alias-keyed column from
silently impersonating a registered engine ID. Code, tests and the Indicators
article already implement and teach this choice; `contracts.md` alone drifted.

### D5. Signals reuse the resolver

`ledgr_signal_feature()` calls the D1 plane read. It gains neither `alias =`
nor a sibling alias helper. The signal contains raw values for the full
decision axis, carries `ctx$vec$admissible` as `eligible`, and records the name
the author supplied as its origin. Candidate-local resolved maps remain part
of execution identity.

`ledgr_signal_return(ctx, lookback)` remains the exact-ID specialization for
`return_<lookback>`. Parameterized return strategies use an active alias and
the generic signal helper rather than registering every concrete lookback in
strategy code.

### D6. Parameterized inspection resolves concrete parameters directly

`ledgr_feature_contracts()` and `ledgr_feature_contract_check()` gain
`feature_params = NULL`. With concrete parameters they use the same validator
and resolver as `ledgr_pulse_snapshot()` and a run. Without them, unresolved
maps retain the classed refusal, whose message names `feature_params` rather
than an unavailable public materialization step.

Feature factories remain refused. No general map materializer and no
grid-union inspection helper is exported.

### D7. Warnings follow an exact public replacement

On an axis of at least 100 instruments, the warning fires when one accessor's
calls in one pulse reach the axis size. It is emitted at most once per run and
is neutral to outputs.

- `ctx$feature(id, name)` loops warn and recommend
  `ctx$vec$feature(name)`.
- `ctx$features(id)` loops with an active map are recorded at bundle level.
  The warning recommends reading each needed active alias once through the
  plane and may list the active aliases.
- `ctx$features(id, map)` loops remain unrecorded.
- One-off scalar reads do not warn.

Ledgr cannot observe which `[[alias]]` user code reads from the ordinary vector
returned by `ctx$features()`. No proxy or instrumented vector is introduced,
and the warning must not claim alias-level observation.

### D8. Lookup preparation and axis restriction

The dense path reuses its run- or candidate-local prepared feature-ID and
active-alias tables. The availability path receives that prepared alias table;
it must not normalize or rebuild the map for each read. Removing availability's
existing per-pulse accessor rebuild remains WS8's separate optimization.

Resolution happens before availability restricts the vector to the decision
axis. Warmup `NA_real_`, empty axes, held nonmembers, restricted members and
axis order retain current plane semantics. Prepared state is never shared
across runs or sweep candidates.

## 3. Contract Changes

The implementation cut updates `contracts.md` to bind:

1. singular feature reads accept an active alias or concrete registered ID
   under D1, with one condition class and separately listed available names;
2. every explicit-map consumer enforces D3 at its read boundary;
3. mapped `ledgr_pulse_wide()` columns use aliases, while unmapped columns use
   engine IDs and the long view retains both names;
4. `ledgr_signal_feature()` uses D1 while preserving raw-value-plus-eligibility
   semantics and author-supplied origin;
5. the two contract-inspection helpers accept concrete `feature_params` and
   otherwise retain their classed refusal;
6. active-map bundle loops join scalar-access recording only after the plane
   replacement exists; and
7. the active alias resolver is prepared per run or candidate and reused by
   dense and availability reads.

Maintainer acceptance corrected the stale context-frame-retirement pipeline
wording from plural `ctx$vec$features()` to the singular D1 resolver. That
index correction does not design or authorize context-frame retirement.

## 4. Detecting Evidence Required By The Ticket Cut

The cut must register failure-sensitive evidence, not source presence alone.

### 4.1 Singular parity and isolation

For each active alias `a`, axis position `i` and pulse, require exact equality
among:

- `ctx$vec$feature(a)[i]`;
- `ctx$feature(ctx$universe[i], a)`;
- `ctx$features(ctx$universe[i])[[a]]`; and
- `ctx$vec$feature(resolved_id_a)[i]`.

Use one witness for each distinct construction risk: dense fast context,
availability with a held nonmember and restricted member including an empty
axis, `ledgr_pulse_snapshot()` with parameters, and a two-candidate sweep. A
small walk-forward witness confirms integration but must not duplicate the
resolver matrix. A mutation sharing one candidate's table with another must
fail.

### 4.2 Explicit-map refusal and wide identity

Both character and object maps that rebind a known name must fail through all
three D3 consumers. A mutation removing the common check must make each public
surface fail its detector. Own-name/same-feature mappings and unrelated local
aliases stay valid.

The long inspection view must report both the literal alias and concrete ID.
The mapped wide view must use the alias key and contain the same value; the
unmapped view must use the concrete ID. Candidate-varying maps must keep the
wide alias key stable while the recorded concrete ID changes.

### 4.3 Signals, errors, inspection and warnings

- Alias and concrete-ID signals are exact in values and `eligible`; alias
  origin remains the author-supplied name.
- Unknown-name errors retain `ledgr_unknown_feature_id` and distinguish active
  aliases from concrete IDs. An engine-ID-only message mutation must fail.
- Inspection with `feature_params` must equal the contracts used by a run with
  the same parameters; a differing-resolution mutation must fail.
- On a 100-instrument axis, active-map bundle loops warn at 100 calls and not
  99; explicit-map loops do not warn, and warned versus suppressed runs have
  identical outputs.

### 4.4 Shape and cost

A structural counter must show that each singular read uses the prepared
resolver and that availability does not normalize the alias map per read.

Record one interleaved paired end-to-end clock at 500 instruments by 1,260
pulses, comparing the taught alias-bundle loop with the equivalent singular
plane strategy, plus one Workstream 11 `feature_gaps` availability clock. The
ticket cut preregisters repetitions and its timing decision threshold before
implementation. The record must report elapsed time and must not be represented
as a general engine-speed claim.

## 5. Rejected Alternatives

| Alternative | Decision and reason |
| --- | --- |
| `ctx$vec$features()` returning every active plane | Rejected: more surface and container allocation than the measured problem requires. |
| Requested-subset bulk plane read | Rejected for v1: no measured residual cost justifies it. |
| Separate `ctx$vec$alias()` | Rejected: the collision rule makes a third spelling unnecessary. |
| Keep `ctx$feature()` exact-ID-only | Rejected: preserves an arbitrary scalar/vector inconsistency without protecting identity. |
| `alias =` on `ledgr_signal_feature()` or a new signal helper | Rejected: D1 resolves the name unambiguously. |
| Explicit maps may shadow known names | Rejected: public probes demonstrated silent same-name/different-series results. |
| Engine IDs as mapped wide keys | Rejected: aliases are stable across candidates, long output retains the ID, and D3 removes mislabelling. |
| Export a general feature-map materializer | Rejected: inspection can resolve for its bounded purpose without adding lifecycle promises. |
| Grid-union inspection | Rejected: no current workflow requires it. |
| Rename public formals to `feature` | Rejected: unrelated compatibility churn based on a proposed downstream helper. |
| Per-alias bundle-loop warning | Rejected: ledgr cannot observe user subsetting of the returned ordinary vector. |

## 6. Open Questions Promoted To The Spec Cut

No product-semantic choice remains open. **Synthesis-only evidence choice:**
the cut must preregister the timing repetitions and pass threshold required by
Section 4.4 before implementation. That is evidence calibration, not permission
to change D1 to D8.

## 7. Future Obligations And Downstream Consumers

This synthesis creates no new future RFC obligation.

It disposes of the Strategy Callback Addendum's accepted feature-read
obligation as follows:

- D1 discharges alias-map vector interactions and feature-map vector output
  when its implementation ticket cut takes ownership;
- D2 rejects bulk multi-feature reads for v1; and
- lookback-window vector access stays with the accepted historical projection
  and its one-feature `ctx$window()` contract.

The addendum's conditional `ctx$feature_at(feature_id, idx)` scalar shortcut
remains in the existing strategy-callback follow-up route. This synthesis
neither needs nor drops it: `ctx$feature(id, name)` and
`ctx$vec$feature(name)[idx]` cover the present use cases, and no measurement
has yet established a separate public shortcut as necessary.

The accepted point-in-time historical projection and the proposed research
history helper consume D1 when their existing owners implement one-feature
reads. They inherit only naming; this synthesis does not decide historical
missingness, lookback shape or preparation.

Availability's per-pulse accessor reconstruction remains WS8's existing
optimization question. A requested-subset plane reader remains speculative
unless Section 4.4 or later profiling demonstrates material repeated-read
cost. Neither item is promoted by this synthesis.

## 8. Sequence

1. At maintainer acceptance, add a `decisions.md` bridge row linking this
   synthesis to the affected Context and Strategy contract clauses. Correct
   the ctx-frame-retirement pipeline prerequisite from plural
   `ctx$vec$features()` to the singular D1 resolver in the same step.
2. Cut implementation tickets, resolve Section 4.4 evidence calibration and
   move the accepted alias/vector callback obligations into ticket authority.
   Remove the completed feature-map pipeline row then; retain the separate
   strategy-callback follow-up route for `ctx$feature_at()` and hardening.
3. Implement and review D1 to D8 before WS3 consumes the naming rule.
4. After accepted implementation, update the demo strategy, articles, context
   reference and contracts. The decision bridge leaves only under the normal
   release-closeout rule after the standing clauses contain the design.

No production code, test, ticket or contract change is authorized before
synthesis acceptance and ticket cut.
