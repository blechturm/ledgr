# Maintainer Amendment: Missingness Treatment For Historical Projection

**Status:** Maintainer product direction recorded 2026-09-26; incorporation
into the next synthesis and Type 2 review remain open. This does not accept
synthesis v3 or authorize implementation, a spec packet, or a spike.
**Author:** Codex, recording the maintainer's decision and its design handoff.
**Target:** [synthesis v3](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v3.md)
at `24b3b391` on `rfc-hp-response`.
**Baselines:** design `491c4ed`; implementation `ae040e7`.

This is a separate amendment under `../rfc_cycle.md`: the cycle is contested,
so prior artifacts remain intact. The product decisions below replace the
cycle's exclusion of simple missing-data treatment. They do not claim shipped
behavior. `../contracts.md` remains authoritative for the current package;
the eventual packet must amend the affected contracts explicitly.

## 1. Maintainer decision and release scope

The ML release must ship simple carry-forward and missingness information for
both prices and indicators. Price padding is intended to be on by default and
switchable off. Indicator-output carry must also be available independently of
price-input padding; their combined default is a synthesis decision, not an
assumption that the two operations are interchangeable.

The purpose is to make incomplete data usable for ordinary research without
requiring every strategy to implement its own missing-data treatment. Preserve
source evidence and disclose transformations. Strict propagation remains an
available policy; it is no longer the only supported research treatment.

"ML release" names the maintainer's delivery scope, not a numbered release or
a commitment to the currently open release packet. Historical projection owns
the preparation and delivery implications. General fitted imputers need deeper
design in the follow-up recorded in the 2026-09-26 horizon entry, and are not a
prerequisite for shipping the simple policy.

The settled knowledge clock is unchanged: a request at simulated decision `t`
may use only information knowable at `t`, including for historical columns
`s <= t`. Neither snapshot sealing nor wall-clock time is an information cutoff.
One causal world and the shared execution fold remain non-negotiable.

## 2. Two operations, with explicit ordering

Preparation must distinguish:

1. **Price-input carry:** replace a permitted missing price input with the
   latest admissible earlier value, then calculate the indicator.
2. **Indicator-output carry:** when the indicator still has a permitted missing
   output, reuse its latest admissible earlier valid output.

If both are enabled, input treatment precedes calculation and output treatment
follows it. Recalculating a moving average on carried prices and carrying the
previous moving average can produce different values. The effective plan must
disclose which operations are selected, and disabling one must not silently
enable the other.

For a historical cell at `s`, a carried source must be from the same stable
instrument and field/feature at an earlier effective time, and be knowable and
admissible at the request cutoff `t`. A later observation cannot fill that cell
under a carry-forward policy even if it is already known at `t`. Repeated carry
retains the original source time; it does not make an old value fresh again.

No leading value is invented before the first admissible source.
Indicator-output carry cannot produce a value before the indicator first
satisfies its declared readiness on the selected prepared inputs. Any seed
value from before the returned window must come from declared, prepared
hydration history; the policy does not authorize hidden history fetching or
expansion of the public axis.

Exchange-closed weekends and holidays contribute no padded session or lookback
count. The declared calendar is the authority, rather than a global weekday
rule that would misclassify a market which actually opens on a weekend.
Missing observations must not be used to infer a market closure.

Raw observations and raw absence remain unchanged. Research-input treatment
does not create an observed bar, membership, trading permission, a valuation
mark, or an execution price. Existing valuation and execution policies retain
their own authority. Errors, invalid indicator definitions, and unsupported
computations must not be silently converted to fillable gaps.

## 3. Missingness information is part of the delivered result

Values alone are insufficient. The simple policy must make these distinctions
available alongside prices and indicators, aligned to the same IDs, columns,
and simulated cutoff:

- whether the input or computed output was missing before its selected
  treatment, and whether a value remains missing afterward;
- whether the delivered value was carried directly or was calculated using
  transformed inputs; a finite indicator can depend on padded prices without
  its output having been carried;
- the original source time and age of a carried value, with the age clock
  stated explicitly;
- incomplete initial warm-up versus a later input gap, and existing applicable
  absence/quality reasons where supported by the evidence.

For finite-window indicators, preserve enough dependency information to explain
which required inputs were filled, including their count or share in that
window. Do not prescribe a finite-window denominator for every future fitted
or recursive method, or compute a second indicator series merely to manufacture
such a flag. Dependency provenance and output treatment are separate facts.

These are logical requirements, not new API names, reason tokens, tables, or
Boolean-plane choices. Reuse existing evidence where its meaning matches.
Missingness summaries should be available without custom strategy checks;
consumers may inspect the companion or use it as model input. No universal
"usable" flag may prevent a future consumer from accepting native `NA`.

## 4. Boundaries the simple implementation must preserve

- **Separate source, treatment and consumption.** Preserve unfilled values and
  their evidence. A later imputer must be able to receive original missingness
  instead of a permanently filled array. Keep input and output transformations
  distinguishable; an unconditional fill hidden inside an accessor or indicator
  would close the future extension point.
- **Declare treatment before execution.** Prepare and index deterministic
  treatment before the fold. Accessors retrieve bounded values and evidence;
  they do not run database history queries, fit models, or rebuild an
  instrument-by-time panel at each pulse. No second execution path is added.
- **Preserve the fitting boundary.** Carry-forward has causal state but no
  estimated training parameters. Do not freeze an interface that assumes all
  future transformations are stateless, per-instrument, or fitted over the whole
  snapshot. Frozen-on-train preprocessing remains model/adapter-owned under the
  existing June 14 ML direction; ledgr supplies admissible inputs and lineage.
- **Preserve identity and parity.** Treatment, ordering, parameters, applicable
  cutoff and implementation version must participate in the existing identity
  and cache machinery. A strict artifact must not satisfy a padded request.
  Under identical policy and information bounds, scalar reads, historical
  windows and training export must agree on values and missingness evidence.
  This does not require a later-cutoff view to equal an earlier-cutoff output.
- **Keep retained results immutable.** A new view with a different cutoff or
  policy must be separately identifiable and must not overwrite earlier outputs.
  Do not use cache immutability to prohibit constructing such a new view.

These constraints reserve the necessary boundaries, not a transformation DAG,
plugin registry, fitted-artifact store, or new model API for this slice.

## 5. Consequences for the next synthesis

| Existing statement | Required disposition |
| --- | --- |
| Seed v1 section 3.3: statistical treatment is not an engine policy | Retain the prohibition on silent statistical choices. Add the declared simple preparation policy; fitted estimator choices remain in model/research adapters. |
| Synthesis v3 section 9 excludes imputation defaults and every release commitment | Replace those exclusions for the simple carry/missingness scope and the maintainer's ML-release direction. Fitted methods remain deferred. |
| v3 section 3.1 treats the numeric matrix as reusable independently of this new policy | Reassess numeric preparation and cache reuse under the selected treatment and request cutoff. Existing prepared doubles alone do not establish feasibility. |
| v3 section 7 gates the evidence representation only | Include original missingness, direct carry, transformed-input provenance and transformed values in the feasibility question. Do not claim the companion alone completes this change. |
| v3 section 8 requires current-value parity with the pre-change run | Preserve strict/control behavior where its inputs and policy are unchanged. Require parity across paths under the same selected policy; padded outputs may intentionally differ from strict outputs. |
| Current strict-window and no-imputed-input contracts | Name their amendment in the eventual packet, including indicator certification, cache identity and teaching changes. Do not describe the new policy as already permitted by the shipped contract. |

The reported lifetime-narrowing versus venue-axis divergence remains unresolved.
Adding carry-forward does not settle which sessions an indicator counts, whether
it may carry across accepted inactive intervals, or how a later-known lifetime
fact changes admissible history. Resolve those dependencies before claiming
matrix invariance or closing the semantic checkpoint. v3's other review findings
are not accepted or disposed of by this amendment.

The next synthesis must also settle the combined default, carry age limits and
expiry behavior, lifecycle reset boundaries, price-field scope, and which
indicator outputs are fillable. Carrying a close does not by itself define
synthetic open/high/low/volume, and no carry limit from a valuation policy is an
implicit limit for research inputs. The simple release must distinguish these
questions from the deferred choice of a fitted imputation algorithm.

No new probe result is claimed. Any empirical checkpoint or subsequent spike
continues to follow `../spike_protocol.md`; this amendment charters none.

## 6. Sources and follow-up

- [Availability synthesis, sections 8, 12 and 16](rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md):
  strict propagation was the bounded first implementation; fitted consumers
  were deferred.
- [Original availability seed, sections 11-12](rfc_asset_availability_point_in_time_universes_v0_1_9_8_seed.md):
  proposed transformations before and after indicators, with separate fit scopes.
- [Prior-art review, section 6](../research/ledgr_ragged_universe_prior_art_review.md):
  values plus missingness masks, causal fitting and separation from execution.
- [Horizon](../horizon.md), 2026-06-14 "General ML-strategy preparedness" and
  2026-09-26 "Fitted imputers after the simple missingness policy": the fitting
  boundary and the follow-up design agenda. Advanced methods remain a later
  design obligation, not a reason to defer the simple ML-release capability.
