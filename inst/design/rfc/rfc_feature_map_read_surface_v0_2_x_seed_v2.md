# RFC Seed v2: Feature-Map Read Surface

**Status:** Seed v2 after the Type 2 response; nothing binds until a synthesis
is accepted, and seed v1 is historical. Two narrow Type 2 reviews of this seed
(2026-10-06) kept the architecture; their corrections are applied in place: D2
covers every public explicit-map consumer and settles wide-column keys, D5
warns at bundle level, no formal rename, and prepared lookup is dense-only.
**Date:** 2026-10-06. **Author:** Claude (seeds); Codex wrote the response and
the review and writes the decision synthesis (`../rfc_cycle.md`).
**Source baseline:** `4f2d6c7`. Line numbers refer to it.
**Route:** full RFC; the read surface is public strategy semantics.

This RFC uses v1 to mean the first implementation of this read surface. ledgr's
roadmap has no feature-map v1 milestone; later work belongs to named follow-up
RFCs in their own roadmap windows.

## 0. What changed since seed v1

These are now facts and leave the open design:

- **Collision rule (v1 Q2).** `ledgr_feature_map()` refuses an alias that names
  another entry's concrete feature, at construction and again at resolution,
  because resolution rebuilds the map through the constructor
  (`R/feature-map.R:121,150-170,215-219`; LCL-0115). An own-ID alias stays valid.
- **Named outer bundles (v1 Q5).** Refused with a pointer to `prefix` or
  `naming` (LCL-0114).
- **Prepared lookup, dense path only.** On the dense fast path one run-local
  factory prepares instrument, universe and feature-ID indexes and the active
  alias map once (LCL-0139), and an explicit-map memo reuses only an identical
  successful map (LCL-0141). The availability path rebuilds its accessors
  every pulse (`R/fold-engine.R:755-770`).
- **Signals.** Context signals keep raw values and carry `ctx$vec$admissible`
  as `eligible` (`contracts.md`, Decision Axis And Eligibility); v1's
  "masking" wording is obsolete.
- **Inspection refusal.** Both inspection helpers refuse an unresolved map
  (LCL-0112) and tell the user to resolve with concrete `feature_params`, which
  no inspection helper accepts; the resolver is internal.

Active aliases come only from a feature map (`R/experiment.R:467-469`); a plain
feature list registers engine IDs and no aliases.

## 1. The problem that remains

| Read | One instrument | Whole decision axis |
| --- | --- | --- |
| engine ID | `ctx$feature(id, feature_id)` | `ctx$vec$feature(feature_id)` |
| active alias | `ctx$features(id)[[alias]]` | **none** |
| explicit map | `ctx$features(id, map)` | none |

`ctx$vec$feature()` reads `lookup$feature_vector`, an engine-ID accessor with no
alias knowledge (`R/pulse-context.R:813-819`; `R/runtime-projection.R:402-430`).
Only the bundle accessor sees the alias map (`R/runtime-projection.R:572-654`).
So active-alias strategies loop over instruments, as the demo and several
articles teach. The response's clock (about 5.24 s per 630,000 calls against
0.01 s for column extraction) locates the cost in that loop, not the alias count.

## 2. Decision D1: one naming rule for every singular feature read

**Rule.** Wherever a strategy names one feature, the name resolves as follows:

1. if the name is an alias in the run's or candidate's active map, read that
   alias's concrete feature ID;
2. otherwise read the name as a concrete feature ID registered for this run or
   candidate;
3. otherwise fail with `ledgr_unknown_feature_id`.

**Why the order cannot change a result.** Every registered engine ID in an
active-map run belongs to some map entry, and the collision rule makes a name
that is both alias and engine ID its own entry, so both readings select one
series. Without an active map step 1 never applies. D2 adds the matching rule
for explicit maps: they may introduce call-local names, but may not redefine
an active alias or registered engine ID in that context.

**Where it applies.** `ctx$vec$feature()`, `ctx$feature(id, ...)` and
`ledgr_signal_feature()`. Later owners consume the same rule: the accepted
`ctx$window()` reads "one feature per call"
(`rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md:97-104`),
and the proposed history helper names features by "the accepted alias and
concrete-ID resolution rule" (`research_strategy_ux_brief.md:68-69`). This
RFC binds only the rule they inherit.

**Untouched.** Feature computation, fingerprints, `config_hash`,
`alias_map_hash` and `feature_set_hash`.

**Formal names stay.** `feature_id` and `feature_name` are kept; documentation
calls the input "an active alias or a concrete feature ID". A future history
helper follows this vocabulary, not the other way round.

### Adjudicating the response

**Accepted: singular, not plural.** Seed v1 chose `ctx$vec$features()` to keep
two namespaces in separate accessors. The collision rule removed the only case
where they disagree, so the separation protects nothing. A plural accessor
would build every mapped plane when callers read two to five, return a list
where `ctx$window()` returns one matrix per feature, and add a second
first-class container that WS3's memory constraints argue against. The measured
cost is the instrument loop; several singular plane reads remove it.

**Rejected for v1: a requested-subset bulk read.** A plane read is one prepared
column extraction; revisit only if the Section 8 record shows otherwise.

**Extended beyond the response: the scalar read takes the same rule.** The
response widened only the plane. That leaves `ctx$feature(id, "fast")` failing
in a run where `ctx$vec$feature("fast")` succeeds, so one string would be a
valid name in one accessor and unknown in its scalar twin. One rule for every
singular read is smaller to teach. The cost is one prepared hash lookup per
scalar call; exact-ID access is unchanged. The review found this defensible.

**Unknown names.** The class stays `ledgr_unknown_feature_id`; with an active
map the message lists active aliases and feature IDs separately.

## 3. Decision D2: explicit maps may add names, never redefine one

Three public functions accept an explicit map: `ctx$features(id, map)`,
`ledgr_pulse_features(pulse, feature_map)` and
`ledgr_pulse_wide(pulse, feature_map)`. They keep their roles, and no singular
read gains a `feature_map` argument. What changes is the naming rule for the
map's entries, applied to all three.

**The defect.** A named character map never passes the constructor's
collision check (`R/feature-alias-map.R:189-191`). The first review's
pulse-snapshot probe, with `sma_5` and `sma_10` both registered, read
`ctx$feature("AAA", "sma_10")` as 5.5 and `ctx$features("AAA",
c(sma_10 = "sma_5"))[["sma_10"]]` as 8.0: one visible name, two series in one
context. A concrete `ledgr_feature_map` passed explicitly has the same gap,
because its constructor checks entries against each other, not against the
run's registered IDs. The inspection pair repeats it: `ledgr_pulse_features()`
builds the lookup without the pulse's aliases or IDs
(`R/feature-inspection.R:287-307`), and the review's probe showed
`ledgr_pulse_wide()` writing the `sma_5` value into column
`AAA__feature_sma_10` (second review; `R/feature-inspection.R:492-504`).

**Decision: fail closed at the read boundary.** When any of the three builds an
explicit map's lookup, every entry whose name equals a name D1 already
resolves in that context or pulse, an active alias or a registered engine ID,
must map to the same concrete feature, or the read fails with
`ledgr_invalid_feature_map` naming the entry, its target and the series the
name already selects. New names stay free: two independent maps may each
introduce the same new name for different features.

Rejected: documenting shadowing overlays, which hides the refused ambiguity.

**Cost.** A memoized map is checked once with its lookup (LCL-0141); uncached
character maps pay one prepared-name lookup per entry per call. Shadowing maps
become errors; no article or test relies on shadowing.

**Wide-column keys: amend the contract to the shipped behavior.**
`contracts.md` (Context Contract) says wide feature columns use engine IDs and
aliases only filter or order them. The code, its tests and the Indicators
article all key wide columns by alias when a map applies, and by engine ID
otherwise. The seed amends the clause rather than the code. Under an active
map the alias is the stable key across sweep candidates while the engine ID
changes with the parameters, the long view already reports both `alias` and
`feature_id`, and with D2 an alias key can no longer mislabel a registered
engine ID. The review preferred restoring engine-ID keys for concrete
identity; the synthesis should weigh that against candidate-stable keys.

**No plane read takes a map.** A concrete map already has a whole-axis route,
`ctx$vec$feature(ledgr_feature_id(map)[["fast"]])` (`R/indicator.R:155-161`);
a parameterized one cannot be read in a callback at all
(`R/feature-alias-map.R:193-200`). Explicit-map loops stay unwarned (D5).

## 4. Decision D3: signals use the same rule

`ledgr_signal_feature()` resolves through D1 by calling the widened plane; it
gains no `alias =` argument. Its semantics stay raw values over the decision
axis plus the `eligible` attribute. The signal's origin records the name the
author wrote, so an active-alias signal reads `fast` in every candidate, while
the resolved map stays part of execution identity.

`ledgr_signal_return()` stays the exact-ID `return_<lookback>` specialization;
its help stops telling users to register every lookback in a grid and points
to an active alias (`mom = ledgr_ind_returns(ledgr_param("lookback"))`) read
with `ledgr_signal_feature(ctx, "mom")`.

## 5. Decision D4: inspection accepts concrete parameters

`ledgr_feature_contracts(features, feature_params = NULL)` and
`ledgr_feature_contract_check(snapshot, features, feature_params = NULL)`:

- with `feature_params`, validate them with
  `ledgr_validate_feature_params_for_declarations()` and resolve with
  `ledgr_resolve_feature_map()`, exactly as `ledgr_pulse_snapshot()` already
  does through its public `feature_params` argument
  (`R/pulse-snapshot.R:48-67`; `R/feature-parameters.R:138`);
- without them, keep the classed refusal, and change its message to name the
  new argument instead of an unreachable resolution step;
- feature factories (`function(params)`) stay refused, as today.

No general materializer is exported, as `ledgr_pulse_snapshot()` shows is
unnecessary; grid-union inspection stays absent.

## 6. Decision D5: exactly which loops warn

The warning mechanism, threshold and result neutrality are unchanged
(LCL-0066, LCL-0102: 100 or more instruments, once per run, outputs identical).
The recorder counts accessor calls per pulse (`R/pulse-context.R:538-569`); it
cannot see which element of a returned vector user code reads afterwards, and
this RFC adds no instrumented vector to find out.

| Loop | v1 behavior |
| --- | --- |
| `ctx$feature(id, name)` over the axis | warns, as today; the message names `ctx$vec$feature()`, now valid for an alias too |
| `ctx$features(id)` with an active map | newly recorded at bundle level; the warning says to read each needed active alias once with `ctx$vec$feature(alias)` and may list the active aliases, without claiming which ones were used |
| `ctx$features(id, map)` | stays unrecorded: no read accepts the same input |
| one-off scalar reads | never warn |

LCL-0102 and LCL-0103 change with this table, because their protected text says
mapped alias reads stay unrecorded "because no replacement exists".

## 7. Preparation and cost constraints

- The resolver reads the prepared active lookup the bundle accessor already
  holds (`R/runtime-projection.R:461-470`), never normalizing per call. The
  availability path must receive that prepared table rather than add a
  per-pulse `ledgr_feature_lookup_map()` call; removing its existing per-pulse
  accessor rebuild is WS8's question.
- Axis restriction stays where it is: availability wraps the plane to the
  decision axis (`R/pulse-context.R:410-415`), and the resolver runs before
  that wrapper reads the column, so an alias read is restricted exactly like an
  engine-ID read.
- Per call: one environment lookup plus the column extraction; no list, frame or
  per-instrument loop.

## 8. Evidence the synthesis should bind

**Parity.** For every active alias `a`, decision-axis position `i` and pulse:
`ctx$vec$feature(a)[i]` is identical to `ctx$features(ctx$universe[i])[[a]]`, to
`ctx$feature(ctx$universe[i], a)` and to `ctx$vec$feature(id_a)[i]`, where
`id_a` is the candidate's resolved ID. One witness per distinct risk:

- a dense run (fast-path construction), including warmup `NA_real_`;
- an availability run with a held nonmember, a restricted member and an empty
  decision axis (per-pulse construction and axis restriction);
- `ledgr_pulse_snapshot()` with `feature_params` (a separate public factory);
- a two-candidate sweep where `fast` resolves to different series, plus one
  small walk-forward integration witness;
- `ledgr_signal_feature(ctx, "fast")` equal to the engine-ID signal in values
  and `eligible`, with origin `fast`.

**Failure sensitivity.** Each must fail a registered block:

- sharing one candidate's resolved table with another candidate;
- resolving after the availability axis wrapper instead of before;
- any of the three consumers accepting an explicit map that rebinds a known name;
- returning engine IDs only in the unknown-name message when a map is active;
- recording explicit-map bundle loops, or failing to record active-map bundle
  loops at the 100-instrument threshold;
- inspection resolving with different parameters than a run for the same
  `feature_params`.

**Cost record.** One paired end-to-end clock of the demo crossover strategy as
written against a plane-read rewrite at 500 instruments by 1,260 pulses, one
availability clock at the Workstream 11 `feature_gaps` shape, and a resolver
call counter that keeps the call-count claim in CI without clocks.

## 9. The response's scenarios against D1 to D5

| Scenario | Result under this seed |
| --- | --- |
| Availability, held nonmember | raw value kept; eligibility stays in `admissible` and `eligible` |
| Engine ID read in an active-map run | still allowed; deliberately bypasses the alias |
| Unknown name | `ledgr_unknown_feature_id`, aliases and IDs listed separately |
| Explicit map | new names allowed, no strategy plane read, unwarned; rebinding a known name refused in all three consumers |
| Wide view under a map | alias-keyed columns, protected by D2; contract amended |
| Future `ctx$window(name)` | inherits D1; history semantics stay with WS3 |

## 10. Costs and the case handled least elegantly

- **Least elegant: explicit maps.** A strategy that brings its own map gets no
  plane read in that map's vocabulary and must go through
  `ledgr_feature_id(map)`; its loops stay unwarned, and maps that rebind a
  known name stop working.
- **Several aliases, several reads:** five column extractions, not a loop.
- **ID-like aliases.** `sma_10 = ledgr_ind_sma(ledgr_param("n"))` reads the
  5-bar SMA in the `n = 5` candidate, where no entry owns `sma_10`. Valid, but
  misleading; the settled collision rule is not reopened.

## 11. Escalation

No maintainer decision is needed before synthesis. The synthesis should test
the scalar widening in D1, the read-boundary refusal in D2, and the wide-key
choice, where the review leaned the other way. None changes identity or
stored artifacts.

## 12. Out of scope

Historical missingness, `ctx$window()` and history-helper semantics, recursive
indicators, `ctx` frame retirement, scheduling, feature computation, bundle
namespaces, grid-union inspection and multi-feature history tensors consume D1
and are not designed here. A synthesis accepting D1 should correct the
ctx-frame-retirement pipeline row, which still names `ctx$vec$features()`.

## 13. Sequencing

Shipped: the collision rule, named-bundle refusal, prepared lookups, the
explicit-map memo and the inspection refusal. Next: decision synthesis (Codex)
and final review, before WS3 consumes D1. A ticket cut then implements D1 to
D5 with the Section 8 evidence and updates the demo strategy, the alias-loop
articles, the context reference table and the wide-column contract clause.
