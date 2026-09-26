# RFC Synthesis: Point-in-Time Historical Projection

**Status: SUPERSEDED 2026-09-26** by
[synthesis v2](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v2.md),
after a final review returned `NEEDS_TYPE_2`. Section 5 of this document
over-bound the knowledge clock, and sections 7 and 10 contradicted each other.
Retained as cycle history; it binds nothing.

**Status (original):** Decision synthesis awaiting maintainer acceptance and final review.
Decisions bind on acceptance, not on publication of this draft.
**Date:** 2026-09-26
**Author:** Claude, per `../rfc_cycle.md` role rotation: synthesis goes to the
author who did not write seed v2. I also wrote the seed review and the
response,
three of whose four findings were withdrawn under maintainer correction; where
this synthesis departs from the response it says so.
**Inputs:** [seed v1](rfc_point_in_time_historical_projection_v0_2_x_seed.md)
(historical), [seed review](rfc_point_in_time_historical_projection_v0_2_x_seed_review.md),
[seed v2](rfc_point_in_time_historical_projection_v0_2_x_seed_v2.md) (operative),
[response](rfc_point_in_time_historical_projection_v0_2_x_response.md) (corrected),
[probe findings](../../../dev/spikes/historical-projection/probe_findings.md),
the maintainer Type 2 correction of 2026-09-26.
**Baselines:** design `491c4ed`; implementation `ae040e7`, which every code and
contract citation means. Claims are verified by execution or by reading the
cited authority, and marked accordingly.

**Scope note.** Seed v2 section 9 places a semantic checkpoint before
synthesis.
The maintainer directed that the synthesis be written first. This document
therefore binds what is decidable from existing accepted contracts and executed
evidence, and **explicitly does not bind the achievable cell distinctions**,
which remain gated (section 7). Two of seed v2's proposals turn out to be
consequences of existing contracts rather than open choices, which shrinks what
the checkpoint must settle.

---

## 1. Decisions and costs

| Item | Decision | Cost |
| --- | --- | --- |
| Projection owner | The existing runtime feature projection. No lower shared projector. | None; reuse of a mandatory fold input. |
| Direction 5.4 | Preserved, including the `ctx$window()` spelling. Two disclosure extensions. | Reference-table and contract additions. |
| Column clock | Consecutive prepared decision pulses ending at the invoking pulse. Availability mode: declared session closes. | None; already bound. |
| Row axis | `Daxis` in its contract-defined order, including held nonmembers. | None; already bound. |
| Cutoff meaning | Original cutoff. Current membership is never broadcast backward. | None; already bound. |
| Access boundary | Engine-owned dataset, accessors bounded by the invoking decision time, no directly indexable projection on the context. | One bounded accessor plus a detached result; LDG-2864 owns the repair. |
| Semantic companion | Required, shape and encoding **not bound**. | Gated on the checkpoint. |
| Identity | Existing feature-cache keys preserved; result-affecting window declarations enter canonical declarations. | No registry, no matrix hash. |
| Multi-feature tensor, training export, estimators | Out of scope. | None. |

No second execution path, no second market-history authority, and no
statistical missing-data policy enters the engine.

## 2. The owner is the existing projection, and Direction B is closed

**Verified by execution and reading.** The runtime projection is a mandatory
fold input: `ledgr_execute_fold()` aborts with `ledgr_invalid_fold_execution`
when it is absent (`R/fold-engine.R:252`). It is passed into the per-pulse
context path at `R/fold-engine.R:631`, which handles availability explicitly
one
line later (`id_to_idx = if (availability_active) NULL else id_to_idx`). Its
`feature_values` hold one instruments-by-all-pulses numeric matrix per registered
feature: a three-instrument, twelve-pulse run with one `sma_3` exposes a 3 x 12
matrix with `pulse_index` of length twelve at the first callback, in both dense
and availability-aware folds. Two authors reproduced this independently.

A bounded lookback is therefore a slice of prepared, already indexed numeric
data. **Decision:** the existing projection is the single owner of causal
historical numerical backing. Seed v1's Direction B, a lower shared projector,
is closed as a contingency: it requires a demonstrated failure of reuse, never
a
precautionary alternative of equal standing. Seed v1's numerical-backing gate
is
withdrawn as answered.

## 3. Direction 5.4 is preserved, including its spelling

**Decision:** preserve the accepted single-feature contract from
`rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` Direction 5.4:
`ctx$window(feature, lookback)` returning a numeric
`length(Daxis) x lookback` matrix, rows in `ctx$universe` order, columns
oldest to current, leading `NA_real_` for unavailable early columns, feature
`stable_after` semantics unchanged, no list-valued replacement and no
multi-feature tensor. The `lookback` is a **requested argument**; no declared
maximum is required.

**On the spelling, this synthesis overrules its own author's response.** R3
argued for `ledgr_window(ctx, feature, lookback)` on the grounds that a
matrix-valued member breaks accepted surface rules. Both premises were wrong:
the reference table explicitly permits "counterpart or an explicit
not-applicable", and the zero-exceptions rule attributed to LDG-2851 appears
nowhere in `tickets.yml`. With the argument gone, superseding an accepted
direction would rest on taste. The distinction that remains is real and
supports
the accepted spelling: the context-first verbs introduced by the
strategy-context
synthesis are pipeline **constructors**, while a window is a **read** of
pulse-known-and-earlier data, which is what the context is for.

Two extensions to Direction 5.4's disclosure, neither changing its shape:

1. The matrix joins the context reference table and its dense and
   availability-aware surface comparison, documenting axis, units, cutoff,
   padding, missingness and ownership. It is neither a scalar accessor nor an
   unnamed `ctx$vec` plane, and it declares an explicit not-applicable
   counterpart.
2. Semantic evidence travels in an aligned bounded companion surface, never
   encoded in numeric `NA`. Its spelling and physical encoding are not bound
   here (section 7).

## 4. Axis, order and clock are already bound

**Verified by reading.** These were proposals in seed v2 and are in fact
consequences of the Availability Contract.

- **Row axis.** `Daxis = ctx$universe = ctx$vec$id`; `M` is the current
  investment member set. Window rows use the current `Daxis`, which may include
  held nonmembers. Allocation constructors continue to default to `M`
  (strategy-context synthesis section 3). A matrix is not an eligibility
screen.
- **Row order.** Already defined: the decision axis "preserves declared member
  order for character-vector universes. For membership-rule universes, members
  are ordered by C-locale stable ID; nonzero held nonmembers then follow in the
  same stable-ID order" (`contracts.md:348-352`). Direction 5.4's "rows in
  `ctx$universe` order" is therefore well defined in both modes without a new
  rule.
- **Column clock.** Consecutive prepared decision pulses ending at the invoking
  pulse, never the last `L` nonmissing observations per asset. In
  availability-aware execution these are declared session closes, which is
  already bound: "availability-aware decisions occur at declared session
closes"
  (`contracts.md:359`).
- **Zero axis.** An empty decision axis yields a `0 x L` result, consistent
with
  the empty-domain decisions in the strategy-context synthesis.

Former members absent from the current `Daxis`, and any ever-member population,
belong to a later explicit export or domain contract. Implicit row discovery is
forbidden: no option may reveal a membership fact by the shape of a matrix.

## 5. Original cutoff is the existing contract, not a new semantics

**Verified by reading, and this is the synthesis's main tightening of seed
v2.**
Seed v2 *proposes* original-cutoff columns. The contract already requires them:

> Facts become applicable only after both effective time and knowledge time...
> Future facts may change snapshot and descendant identity but **must not rewrite
> earlier context, errors, features, or supported telemetry.**
> (`contracts.md:354-358`)

A historical view that recomputed membership at `t` and broadcast it backward,
or
that revised an earlier column using later knowledge, would rewrite earlier
context and features. That is already forbidden.

**Decision:** at historical pulse `s <= t`, value and evidence mean what was
effective and knowable at `s`. This binds as a consequence of the Availability
Contract rather than as a new choice. A retrospective "history as known today"
mode is a different contract and is excluded from the first implementation.

Two consequences follow without further evidence. Membership and observation
remain independent: an observed pre-membership value is not automatically
deleted, and nonmembership alone does not imply absent history. And market-cell
metadata cannot replay historical `held`, `priced`, `mark_age` or `tradable()`
state; that promise is excluded, because a valuation view would require
explicit
policy and portfolio-state inputs. A stale risk mark is never an observed close
or a feature input (`contracts.md:401-405`).

## 6. The access boundary

**Decision, per the maintainer direction of 2026-09-26.** The full prepared
dataset stays engine-owned. Strategies obtain current values or requested
historical slices only through accessors bounded by the invoking decision time.
The context exposes no directly indexable full projection.

An accessor **may** retain the full projection internally provided its
supported
operations enforce the cutoff. Enforcement belongs to the operation, not to
what
a closure holds. Consequently:

- a requested `lookback` argument is causally sound, and no declared maximum is
  required to prevent introspection. A maximum may still be justified later by
  demonstrated resource needs, which is a resource argument and not a causality
  mechanism;
- deliberate R introspection - extracting closure environments, inspecting call
  stacks, modifying internal bindings - is outside the guarantee. No field
  rename or closure arrangement is a sandbox, and the synthesis does not
pretend
  otherwise;
- the window returns a **detached** numeric result with value semantics: a
  caller may mutate its matrix without changing engine storage, another
  consumer, or a later result, and a retained result keeps its original axis
and
  cutoff when the fold advances. Allocation is bounded to the requested slice,
  not to a copy of the full projection per pulse.

The response's R1, which held that a requested lookback and a bounded capture
were incompatible, is withdrawn: it treated internal retention as the defect.

**Repair ownership.** The present violation of `contracts.md:113` is owned by
LDG-2864 in the current release, not by this cycle, and its detector is
inverted
accordingly: it fails on a reattached directly indexable projection or on a
supported accessor returning a value beyond the invoking pulse, and must not
fail solely because an accessor internally retains engine-owned data. The
contract clarification - that carrying decision-time information only is a
claim
about supported operations, that dot-prefixed context fields are not API, and
that deliberate introspection is outside the guarantee - is owned by LDG-2850
and must be stated explicitly rather than reinterpreted.

**Inspection is preserved.** `ledgr_pulse_feature_table()` reads the private
projection when the long table is empty (`R/feature-inspection.R:304`), and the
strategy-context synthesis deliberately retains that reader. Any repair
supplies
it a bounded route preserving pulse and axis. No automatic full-long rebuild
and
no inspection removal.

## 7. What this synthesis does not bind

**The achievable cell distinctions and the companion surface's encoding.**
The design must distinguish, where evidence supports it: outside the applicable
point-in-time domain; inside with an accepted observation; inside without a
usable observation; feature unavailable because causal warm-up is incomplete;
and value usable only under a valuation or staleness policy. Which of these the
prepared evidence can actually express, and how they are encoded - boolean
planes, packed flags, reason codes, sparse coordinates or otherwise - is not
decided here. Unsupported distinctions must be excluded or fail explicitly,
never guessed, and no second warm-up rule or new durable availability reason
token may be invented for this API.

**The checkpoint that settles it** is seed v2 section 9's, restated. Its cost
premise has changed: the response claimed the companion's hard half runs
through
`provider$history()` at roughly 126,000 in-callback queries. That function reads
bars (`SELECT ... FROM snapshot_bars`, `R/availability-provider.R:212-232`) and
is not the fact-resolution path. Fact resolution is already prepared -
`ledgr_availability_provider_data()` reads all six families once into an ordered
in-memory list (`:28-49`) and `ledgr_availability_applicable(rows, cutoff)`
resolves a cutoff by three vectorised comparisons over those rows (`:52-58`).

So the checkpoint is a **semantics** question over an already prepared,
already cutoff-parameterised authority, not a storage-cost question:

> Can the prepared fact families and prepared feature values express the
> required original-cutoff distinctions for a single-feature window, without a
> second resolver, per-callback storage queries, or replay of portfolio state?

Its kill condition names the missing prepared evidence or ownership seam. Green
establishes bounded semantic reuse only: not future-access repair, not training
export parity, and not research-scale memory suitability.

## 8. Identity and cost

**Identity.** Existing feature-cache keys already include snapshot hash,
instrument, feature fingerprint and feature-engine version
(`R/feature-cache.R:122-140`, verified). Preserve that reuse; engine version
alone is not projection identity. Ordered axes, cutoff, lookback and the
semantic contract version must prevent reuse of a view across incompatible
snapshot, feature, range or availability semantics. Result-affecting window or
domain choices belong in canonical strategy or consumer declarations. No
mutable
panel registry and no materialized-matrix hash is introduced.

**Cost.** The baseline already retains `O(FNT)` feature doubles before any
callback; 500 instruments by 2,500 pulses by ten features is about 95.4 MiB of
payload, which is arithmetic rather than measured peak RSS. A detached
one-feature window adds `O(NL)` per materialization - about 1 MB for 500 x 252
-
and does not make total memory `O(NL)`.

The existing bans hold: no per-callback database history queries, no R-level
instrument-by-pulse reconstruction, no redundant full-panel **long**
materialization (wide materialization is a different and already-paid cost),
and
no market panels in serialized strategy state.

**One open reading question, carried from the response's surviving finding.**
Whether the prepared projection is per-process or shared under parallel sweep
is
unanswered, and the motivating consumers run as sweeps. If per-process, a
ten-candidate sweep carries roughly a gigabyte of inherited payload before any
window is requested, which is where the scale risk lives rather than in the
`O(NL)` addition. **This must be answered by reading the sweep path before any
representation measurement is commissioned**, and any later measurement
separates inherited preparation, added window and metadata allocation,
estimator
cost and worker replication, with cold and warm clocks per spike-protocol
section 10.

## 9. Consumers

One owner does not mean one object or one permission. Strategy access is
pulse-bounded. A later offline training export may traverse an explicitly
selected historical range through the same value and semantic rules, preserving
each row's causal cutoff; retrieving the remainder of the run is not a strategy
capability. History supports repeated and expanding fitting and sparse requests
without forcing estimator work every pulse and without equating fit and
rebalance cadence.

Out of scope and unchanged by acceptance: native estimators, optimizers,
clustering, PCA and learners; solver dispatch; model registries; forward
labels,
embargo and overlapping-label weighting; fitted preprocessing and
refit-artifact
identity; imputation defaults; scheduling APIs; a general history query
language; corporate-action or terminal-event accounting; and any release
commitment. Causally re-estimated and frozen-on-train transforms remain
distinct
by fitting regime rather than by algorithm name.

## 10. Detecting acceptance requirements

A later implementation is acceptable only with detectors that fail on:

1. **Future-read escape** - a supported accessor returning any value beyond the
   invoking pulse, in dense and availability-aware execution.
2. **Future-fact perturbation** - a fact effective before but knowable after a
   historical cutoff changing that historical column.
3. **Retained-result mutation** - mutating a returned window altering engine
   storage, another consumer, or a later result; and a retained result losing
   its original axis or cutoff when the fold advances.
4. **Axis alignment** - row order disagreeing with the contract-defined
decision
   axis, including held-nonmember placement, or a `0 x L` empty-axis result
   failing.
5. **Warm-up parity** - leading padding, incomplete feature warm-up and
   observation gaps becoming indistinguishable, or a reason inferred from `NA`.
6. **Current-value parity** - scalar, plane and bundle reads disagreeing with
   the pre-change run at any pulse.
7. **Inspection preservation** - the interactive reader failing when the long
   table is empty.

No member-count, timing or memory threshold is an acceptance gate.

## 11. Next action

Accept or revise these decisions. On acceptance: restate the section 7
checkpoint, answer the section 8 sweep question by reading, and only then
consider a spec cut. No comparative spike is chartered, no spec packet is
written here, and no current-release commitment is made. LDG-2864 and LDG-2850
proceed independently in the current release under the existing contract.

## 12. Revision history

- 2026-09-26: initial synthesis at design `491c4ed`, implementation `ae040e7`.
  Closes the lower-projector contingency, preserves Direction 5.4 including its
  spelling against the response's own recommendation, binds axis, order, clock
  and original cutoff as existing contract consequences, binds the access
  boundary per maintainer correction, and leaves cell distinctions gated on a
  restated semantic checkpoint.
