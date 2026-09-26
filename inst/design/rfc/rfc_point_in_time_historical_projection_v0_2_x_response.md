# RFC Response: Point-in-Time Historical Projection

**Status:** Type 2 response to Seed v2, **corrected 2026-09-26** under a
maintainer Type 2 correction. Three of its four findings are withdrawn and
section 8 records each withdrawal and its cause. The original arguments are
left in place as history rather than deleted. Binds no design. The maintainer
owns
the
operative brief; Seed v2 section 10 supplied an agenda rather than that brief,
and this response departs from it where the evidence pointed elsewhere.
**Date:** 2026-09-26
**Author:** Claude, response author. I also wrote the Seed v1 review, so the
findings this seed accepts are partly mine; I have tried to spend this response
on what the seed and I have both missed rather than on confirming it.
**Baselines:** design `491c4ed`; implementation `ae040e7`, which all code and
contract citations below mean. Verified by execution under R 4.6.1 unless
marked
as reading.

---

## 1. Assessment

Seed v2 is accurate where it is checkable and honest where it is not. Its
reproduction is correct, its disposition of the v1 review is right on four of
five findings, and on the fifth it corrected me: v1 section 10 forbade
redundant
full-panel **long** materialization while the engine performs **wide**
materialization, which are different costs, and my finding conflated them.

Two of its refinements are better than the review they answer. Copy-versus-view
is insufficient while the source stays reachable, which is the correct reading
of
the exposure. And Daxis-versus-M settles the current axis without settling
historical sampling populations or which knowledge cutoff applies to old facts.

I accept the withdrawal of the v1 numerical-backing gate, the single-feature
minimum scope, original-cutoff over a retrospective mode, and the refusal to
charter a comparative spike.

The response therefore concentrates on four issues, one of which I think is the
cycle's real architectural fork and which neither the seed nor my review posed.

---

## 2. R1 - The lookback argument and LDG-2864 are in direct tension

> **Withdrawn 2026-09-26.** The claimed incompatibility does not hold. See
> section 8.1. The text below is the original argument.

This is the finding I would most like challenged in turn.

Seed v2 section 5 proposes `ctx$window(feature, lookback)`, taking the lookback
as a **call argument**. Implementation ticket LDG-2864, cut in the current
release, requires that no accessor closure reachable from a callback capture
the
full projection, because `force(projection)` at `R/runtime-projection.R:365` is
the actual exposure rather than the attached field. I verified the exposure
directly: `environment(ctx$feature)$projection$feature_values[[1]]` returns the
complete matrix.

Those two requirements cannot both hold naively. If the accessor may only hold
a
bounded slice, it must know the bound when the context is built. The lookback
is
not known then, because it arrives as an argument at call time. So exactly one
of
three things must be true, and the seed picks none of them:

1. **Lookback is declared, not requested.** The window becomes a declared
   dependency resolved before execution, like a registered feature's window.
The
   accessor then captures the declared maximum. This is the Zipline
   pre-declaration pattern the prior-art pass describes, and it makes
   `ctx$window(feature, lookback)` a *lookup* of something already prepared
   rather than a request. It changes section 5's contract: the lookback becomes
   part of the experiment declaration and therefore part of identity.
2. **The accessor retains engine reach at call time**, and LDG-2864's guarantee
   is weakened to "no future values" rather than "no full projection", enforced
   by a cutoff check inside the accessor rather than by what it holds.
3. **LDG-2864 ships first and blocks `ctx$window()`** until the RFC chooses (1)
   or (2), which is coherent but should be said rather than discovered.

Option 1 is the only one that makes the bound physical rather than
conventional,
and it has a public consequence the seed does not carry: a declared window is
an
identity input, which section 8 currently assigns to "canonical strategy or
consumer declarations" without naming the declaration site.

**Requested of the synthesis:** choose between declared and requested lookback
explicitly, and state the consequence for identity and for LDG-2864's
acceptance criteria. This is not a spelling question.

## 3. R2 - The checkpoint is not evenly split, and its hard half has one authority

> **Withdrawn 2026-09-26.** The cost claim cited the wrong function and the
> correction strengthens the seed. See section 8.2.

Section 9's checkpoint asks whether prepared feature values **and** production
fact semantics can supply aligned original-cutoff evidence. Those halves are
not
comparable in difficulty and should not share one gate.

The **value** half is nearly free and close to already answered. Feature values
are computed from bars, not facts, and their causality is already guarded for
the series function by the no-lookahead checker in `R/features-engine.R`. A
value at historical pulse `s` is therefore already the value computable at `s`,
and no later-knowable fact revises it. Section 2's reproduction plus that
guard essentially settle it.

The **evidence** half is the whole difficulty, and the only existing authority
for resolving facts at a cutoff is the availability provider. Section 8 warns
that its `history` is not a prepared path; the code is worse than that warning
suggests. `provider$history(instrument_id, cutoff, sessions)` issues a
`DBI::dbGetQuery` per call, keyed on one instrument and one cutoff
(`R/availability-provider.R:212-232`). It is not merely unprepared, it is
per-instrument-per-cutoff SQL. A 500-instrument, 252-column semantic companion
assembled naively through that authority is on the order of 126,000 queries
inside a callback, which is the pattern the optimization manual and section 8
both ban.

So the checkpoint's real question is narrower and sharper than stated: **can L
pulses of membership, session and observation evidence be prepared once per run
alongside the feature projection, or does every historical cutoff require the
provider?** Phrased that way it can fail cleanly, and its kill condition
identifies a missing prepared index rather than a vague "ownership seam".

**Requested:** restate the checkpoint as the evidence question alone, and
record
the value half as settled by section 2 plus the existing series guard.

## 4. R3 - `ctx$window()` may be the wrong home, given the cut this seed inherits

> **Withdrawn as an argument 2026-09-26**, reduced to a preference. Its two
> premises were both wrong. See section 8.3.

Seed v2 correctly inherits Cut 13's vocabulary but not its direction of travel.
Cut 13 moves composable operations **off** the context into context-first
verbs:
`ledgr_signal(ctx, values = )`, `ledgr_selection(ctx, ids = )`. Its LDG-2855
binds one reference table asserting every public member with shape, axis,
units,
missingness and **counterpart**, in both dense and availability contexts, and
LDG-2851 establishes a law with, in its own words, zero exceptions.

A matrix-valued `ctx$window()` is a third shape on the context: not a scalar
accessor, not a plane, and with no counterpart. Section 5 acknowledges it "is
not
a scalar or unnamed `ctx$vec` plane" and requires it to join the reference
table,
but that makes it an exception to the law within one release of the law being
established for the first time.

`ledgr_window(ctx, feature, lookback)` would be consistent with Cut 13's own
entrance design, keeps the context surface governed by one law, and composes
with
the existing pipeline the same way the new entrances do. It also sits more
naturally with R1 option 1, since a free function can be resolved against a
declared window without implying a context member.

The accepted Direction 5.4 named `ctx$window()`, so this is a supersession
question, not a free choice. But Direction 5.4 predates both Cut 13 and the
decision-time defect, and section 5 already reserves the right to supersede it
explicitly in synthesis.

**Requested:** decide the home, not only the return shape, and dispose of
Direction 5.4's spelling as deliberately as its shape.

## 5. R4 - Worker replication is named but not priced

> **Stands.** Unaffected by the correction.

Section 8's arithmetic is correct and usefully labelled as arithmetic rather
than measured RSS: 500 instruments by 2,500 pulses by ten features is about
95.4 MiB of payload, inherited before any callback.

It then lists parallel workers among the additional costs without pricing them.
That omission matters for this cycle specifically, because the motivating
consumers are portfolio and ML research, and the natural way to run those is a
sweep. If each worker holds its own prepared projection, a ten-candidate
parallel sweep carries roughly a gigabyte of inherited payload before any
window
is requested, and the per-window `O(NL)` addition the seed prices at about 1 MB
is not where the scale risk lives.

I have not measured this and am not asserting that workers replicate the
projection; the seed should not assert the opposite either. It is a bounded
reading question about the sweep path, answerable before any spike.

**Requested:** state whether the prepared projection is per-process or shared
under parallel sweep, and if per-process, price it at the research scale the
cycle targets.

---

## 6. What I do not contest

Section 6's original-cutoff proposal is the strongest part of the seed.
Deriving
it from the Availability Contract's non-retroactivity rule rather than
inventing
a history semantics is exactly right, as is excluding a retrospective
"history as known today" mode from the first contract, and excluding replay of
`held`, `priced`, `mark_age` and `tradable()` state. The separation of membership
from observation, and the refusal to infer a reason from `NA`, follow from
existing contracts rather than from taste.

Section 4's asymmetry between strategy access and offline export is right:
sharing semantic ownership does not require sharing the object or the
permissions, and retrieving the remaining run is correctly excluded as a
strategy capability.

Section 7's honesty about R reflection is worth preserving verbatim in the
synthesis. A renamed field is not a sandbox, and the useful claim is that no
documented or ordinarily reachable path yields a future value.

---

## 7. Disposition

> **Superseded 2026-09-26.** The original disposition below rested on R1,
> which is withdrawn. The corrected position is in section 8.4: seed v2 is
> ready for synthesis, with R4 answerable by reading and the contract
> clarification owned by LDG-2850.

Seed v2 is ready for synthesis on three of its five agenda items. Two need
deciding first, and one of them is new: the lookback argument and the
already-cut LDG-2864 cannot both stand as written, and resolving that probably
makes the window a declared dependency with an identity consequence. That
decision should precede the semantic checkpoint, because a declared window
changes what the checkpoint must prepare.

I recommend the synthesis open on R1 and R3 together, restate the checkpoint
per
R2, and answer R4 by reading rather than by spike.

---

## 8. Corrections adopted 2026-09-26

A maintainer Type 2 correction directed the boundary this response should have
assumed, and asked me to verify two source claims. All three checks went
against
me. I verified each at implementation baseline `ae040e7` before accepting it.

### 8.1 R1 withdrawn: requested lookbacks and causal access are compatible

The maintainer direction states the boundary: the full prepared dataset stays
engine-owned, strategies obtain current values or requested historical slices
only through accessors bounded by the invoking decision time, and the context
exposes no directly indexable full projection. **An accessor may retain the
full
projection internally provided its supported operations enforce the cutoff.**
Deliberate R introspection of closure environments, call stacks or internal
bindings is outside the guarantee.

Under that boundary my argument collapses. I treated internal retention as the
defect, so a bounded capture looked necessary, so a declared maximum lookback
looked forced. But enforcement belongs to the operation, not to what the
closure
holds: an accessor holding everything and refusing anything past the invoking
pulse is causally sound. A requested `lookback` argument is therefore fine, and
requiring a declared maximum to prevent introspection would have imposed an
architecture the guarantee does not need. A maximum may still be justified
later
by demonstrated resource needs, which is a resource argument rather than a
causality mechanism.

What survives is narrower and is now owned elsewhere. `contracts.md:113` does
not
say whether carrying decision-time information only describes the operations a
context supports or the state it holds. That ambiguity is real, and LDG-2864
was
revised to stop resolving it by implication: LDG-2850 now owns the
clarification
explicitly.

### 8.2 R2 withdrawn: I costed the wrong function, and the correction helps the seed

I claimed the semantic companion's hard half runs through
`provider$history()` and priced a 500-by-252 companion at roughly 126,000
in-callback queries. That function reads **bars**: its statement is
`SELECT instrument_id, ts_utc, open, high, low, close, volume FROM snapshot_bars`
(`R/availability-provider.R:212-232`). It is not the fact-resolution path, so
the
number describes nothing relevant.

Fact resolution is already prepared. `ledgr_availability_provider_data()` reads
all six fact families once into an in-memory list ordered by `effective_from,
knowledge_time` (`R/availability-provider.R:28-49`), and
`ledgr_availability_applicable(rows, cutoff)` resolves a cutoff by three
vectorised comparisons over those prepared rows (`:52-58`). Resolving evidence
at
an arbitrary historical cutoff is therefore a vectorised pass over prepared
data,
not a query.

This does not merely retract a number, it reverses the direction of the
finding.
Seed v2 section 6's original-cutoff proposal is **more** feasible than my
response allowed, because the authority it depends on is already cutoff
parameterised and already prepared once per provider. The checkpoint in
section 9
remains worth running, but as a semantics question over a prepared path rather
than as a storage-cost question.

### 8.3 R3 withdrawn as an argument: both premises were wrong

I argued a matrix-valued member breaks Cut 13's accepted surface rules. Neither
premise survives.

First, the reference table explicitly permits a member without a counterpart.
LDG-2855 requires "applicability, shape, axis, units, missingness and
counterpart
**or an explicit not-applicable**" - wording I drafted myself, then argued
against.

Second, I attributed a zero-exceptions rule to LDG-2851. The phrase appears
nowhere in `tickets.yml`. It came from my own superseded strategy-context seed,
and the accepted synthesis explicitly rejected member-count and
exception-counting targets. Attributing a superseded seed's phrasing to an
accepted ticket is the same error as citing a contract from memory.

What remains is a preference, not a finding: `ledgr_window(ctx, feature,
lookback)` would sit more consistently with Cut 13's context-first verbs than a
new context member would. Direction 5.4 named `ctx$window()`, so a change is a
supersession the synthesis may make on design grounds. It is not compelled by
any accepted rule.

### 8.4 What this leaves

One live finding, R4, which the correction does not touch: state whether the
prepared projection is per-process or shared under parallel sweep, and price it
at research scale if per-process. It is answerable by reading.

Everything the response accepted in section 6 stands, and section 8.2
strengthens it.

### 8.5 Why the response was wrong, recorded for the cycle

Two of the three errors share one shape: I read a single function and inferred
a
system property from it. `force(projection)` became an architectural
requirement,
and a bars reader became the semantic companion's cost model. The third was
citing a rule from memory instead of grepping for it. The seed review made the
same class of error on `contracts.md:113`, in the opposite direction, when a
failed pattern match became evidence of absence.

The guard that would have caught all three is cheap and I did not apply it:
before
a finding depends on a claim about the codebase, locate the claim's authority
and
read it, rather than reading one call site and generalising.
