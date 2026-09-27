# RFC Synthesis v3: Point-in-Time Historical Projection

**Status: SUPERSEDED 2026-09-26** by
[synthesis v4](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v4.md),
which repairs the four findings a Type 2 review accepted here and incorporates
the maintainer missingness amendment. Its settled knowledge clock and column
clock are carried forward; its recomputation prohibition, mixed-clock section
and cost arguments are withdrawn there. Retained as cycle history; it binds
nothing.

**Status (original):** Decision synthesis, superseding
[synthesis v2](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v2.md),
which returned `NEEDS_TYPE_2`. Decisions bind on maintainer acceptance.
**Date:** 2026-09-26
**Author:** Claude, per role rotation.
**Baselines:** design `491c4ed`; implementation `ae040e7`. Claims are marked
verified by reading, verified by execution, or open.

**What v2 got wrong.** Its organising decision was accepted and is unchanged
here. Three supporting claims were not: it asserted the numeric matrix is
unaffected on a reason that does not hold, it understated what two-clock
resolution costs by a category rather than a factor, and it justified a scope
decision with an argument about a surface that does not serve the question.
Section 2 records each withdrawal. Verifying the first of them surfaced a
divergence between binding availability text and the implementation, which this
document reports and does not own (section 3.3).

---

## 1. The decision, stated precisely

A history request made at decision pulse `t` returns, for each historical
column `s <= t`, the value and the evidence that are **knowable at `t`**.

Two clocks, separated:

- the **knowledge clock is fixed at `t`** - a fact participates if
  `knowledge_time <= t`;
- the **effective clock varies with the column** - a fact applies to column `s`
  if `effective_from <= s` and `s < effective_to`.

This is not lookahead. Only information available at the decision pulse is used,
and nothing after `t` is consulted. It differs from replaying the information
set of each historical pulse, which is a different product served by a different
surface (section 6).

**The single most important implementation constraint.** `t` is the **simulated
decision pulse**. It is never snapshot-seal time and never wall-clock now. In a
backtest replaying 2020, `t` is a date in 2020, and the knowledge filter uses
the sealed `knowledge_time` values against that simulated instant. Resolving at
seal time or at the real present would admit facts published after the simulated
decision, which is genuine lookahead. Every detector in section 8 exists
primarily to protect this sentence.

This section is carried unchanged from v2 and was accepted in Type 2 review:
the bound that available information is limited by the invoking simulated
decision time is settled and is not reopened here.

## 2. Withdrawals from synthesis v2

Recorded rather than deleted, because the reasoning is part of the cycle. v2's
own withdrawals from v1 stand as recorded there and are not repeated.

| v2 claim | Disposition |
| --- | --- |
| "The numeric matrix is unaffected. Feature values derive from bars; bars are sealed... so a value at column `s` does not change with `t`." | **Withdrawn as stated.** The conclusion holds at `ae040e7`, but not for that reason. Feature values derive from bars *and from the session axis the window counts*, and the binding availability text makes that axis knowledge-dependent. Section 3.1 restates the claim with its actual, contingent ground and names the trip-wire that would falsify it. |
| "One knowledge filter, not `L` resolutions... The existing resolver is the special case... The generalisation is small in shape - two time arguments instead of one." | **Withdrawn.** The prepared fact tables collapse the two clocks into one and therefore cannot express the state the decision requires. This is a representational gap, not a cost gap, and the correction is a category change rather than a number. Section 3.2. |
| Shipping no second replay mode "would duplicate a shipped surface with a worse one." | **Withdrawn as justification; the decision is retained on other grounds.** `ledgr_run_explain()` returns retained decision evidence and feature *identity*, not feature values or historical windows, and dense runs retain no diagnostic rows at all. It does not serve the rejected clock, so it cannot be cited as already covering it. Section 6. |
| Detector 1's test: "a backtest whose history changes when the snapshot is re-opened later has failed it." | **Withdrawn as the test.** It is necessary and not sufficient: an implementation that resolves at seal time returns the *same* leaked history on every reopen and passes a stability comparison. Section 8 restates item 1 as a construction check made falsifiable by item 2's fixture. |

Unchanged from v2 and not re-argued here: the projection is the single owner and
the lower-projector direction stays closed (verified by execution);
Direction 5.4 is preserved including its `ctx$window()` spelling; the row axis
and its order
follow `contracts.md:348-352`; the access boundary follows the maintainer
correction of 2026-09-26 and its repair is owned by LDG-2864 and LDG-2850; the
column clock (section 4); the evidence semantics (section 5); and identity, cost
and consumers (section 9).

## 3. What the decision governs

### 3.1 The matrix is `t`-invariant at `ae040e7`, contingently

**The mechanism by which it would not be.** Three pieces of binding text, each
verified by reading at its own authority:

- the accepted availability synthesis: "An instrument's expected sessions,
  **which drive feature windows** and observation classification, are the venue
  open sessions minus those inside an accepted `known_inactive` lifetime
  interval when the `lifetime` family is declared";
- `contracts.md:803`: "Strict feature windows count expected sessions";
- `contracts.md:808-810`: "Active feature fingerprints and cache keys include
  strict expected-session and **cutoff-causal** history semantics. Future-known
  facts cannot rewrite cached earlier feature values."

Accepted lifetime facts carry knowledge times. So under that text the window's
own axis is knowledge-dependent, and a design-conformant engine's matrix carries
a knowledge clock. v2's reasoning skipped this step entirely: it reasoned from
the immutability of bars to the immutability of values, and the window that
selects the bars is not made of bars.

**What the implementation does.** Verified by reading at `ae040e7`. In
availability-aware mode feature hydration builds one frame per instrument on
`pulses_posix`, the **venue** pulse axis, identical for every instrument
(`R/backtest-runner.R:873-907`). Absent observations are NA-filled and marked
`gap_type = "MISSING_EXPECTED_SESSION"` (`:886`), and the run **fails** if any
per-instrument axis differs from the venue axis (`:904-905`), so a narrowed
per-instrument axis is not merely absent from this path but prohibited by it.
`ledgr_compute_feature_series_strict()` then rolls `width` consecutive rows of
that frame and skips to `NA` when any value in the window is non-finite
(`R/features-engine.R:286-320`, gate at `:314`). `known_inactive` does not
appear in the feature path at all; across `R/` its only functional uses are
trading restriction (`R/availability-provider.R:195-203`, contributing
`reason = "lifetime_inactive"`) and terminal handling (`R/fold-engine.R:505`).

**Therefore.** The matrix is a function of sealed bars and the venue decision
axis, and is `t`-invariant. v2's conclusion survives and the knowledge-clock
decision governs the companion evidence only - **while the venue-axis window
holds.**

**Trip-wire.** If feature windows are ever narrowed per instrument, this claim
fails, the matrix acquires a knowledge clock, and section 3.4 becomes live. Any
change to the feature session axis reopens this section. It is stated as a
contingency rather than an invariant precisely because the binding text points
the other way (section 3.3).

**Recomputation is not an available resolution.** `contracts.md:809-810`
forbids future-known facts rewriting cached earlier feature values. So no
present or future resolution of this cycle can be "recompute the matrix at
`t`". This closes the option v2 never considered and Astra correctly declined
to assert.

### 3.2 The prepared fact tables cannot express the two-clock state

Verified by reading, at two sites. `ledgr_availability_prepared_segments()`
sets each segment start to
`pmax(seconds(effective_from), seconds(knowledge_time))`
(`R/availability-provider-prepared.R:102-105`), and the membership-interval
preparation does the same (`:47-50`). Precedence and supersession are resolved
into plane codes at segment starts (`resolve_status` at `:196-206`,
`resolve_lifetime` at `:222-230`).

The consequence is sharper than a cost correction. A fact effective at `s` but
first knowable at `t > s` receives `start = knowledge_time`, so the prepared
segments report it **inapplicable at `s`** - which is exactly the cell the
decision in section 1 requires to appear. The prepared representation does not
merely make the two-clock query expensive; it has discarded the information the
query needs. v2's "the existing resolver is the special case, and the
generalisation is two time arguments instead of one" is wrong in kind.

Feasibility is unaffected: `ledgr_availability_provider_data()` loads the six
families as row tables retaining both columns, so the information exists
upstream of the collapse. But the state at `(s, t)` is
`{rows : effective_from <= s < effective_to  and  knowledge_time <= t}`,
a two-dimensional range condition per instrument, and a single collapsed segment
table cannot answer it at any price. Rebuilding segments per `t` runs the
instrument-by-boundary double loop at `:110-119`, which is optimization shapes 1
and 6 if it happens per pulse.

**What the decision does still buy.** The knowledge bound is one value for the
whole window rather than one per column, so at most one preparation per decision
pulse is needed rather than one per column. That reduction is real and it is the
reason the fixed-`t` decision is cheaper than the rejected per-column clock. It
is smaller than v2 claimed, and it is a reduction from `L` preparations to one,
not from `L` to zero.

**A direction for the checkpoint, not a decision here.** The production fold
needs only the `s == t` diagonal, and the single-clock prepared path is correct
and fast for that; nothing in this cycle proposes changing it. A history
capability could instead carry its own preparation, built when the capability is
requested, leaving the hot path untouched. Whether a once-per-run preparation
can answer the two-dimensional condition without a per-pulse rebuild is now the
hardest part of the checkpoint and is explicitly in its scope (section 7).

### 3.3 A divergence this cycle reports and does not own

Verifying section 3.1 found that the binding availability text and the
implementation disagree, and that the disagreement changes numbers rather than
coverage.

Narrowing and NA-gating are not the same computation. Across an accepted
`known_inactive` interval, **narrowing** removes those sessions from the axis,
so a `width`-session window reaches back past the interval and yields a value;
**gating** leaves them in the frame as `NA`, so any window overlapping the
interval yields `NA`. The accepted synthesis and `contracts.md:803` describe
narrowing. `ae040e7` gates (section 3.1).

This is not a spec-cut. Section 15 of the availability synthesis does not list
it, and its revision history records the rule as a deliberate final-review
addition: "*final-review patch set 2 (Codex re-review): `unknown` lifetime
preserves the venue calendar and only accepted `known_inactive` intervals remove
expected sessions (3, 4.1)*."

Two checks were not run and belong to the ticket rather than to this document:
whether gates 21 through 23 assert narrowing anywhere, and whether a later
v0.2.0.0 packet decision deferred it.

**A direction note, because it changes which side moves.** Gating may be the
better behaviour. Narrowing across a three-month halt makes a nominal twenty-day
average span five calendar months, which is worse research than returning `NA`.
If that is the maintainer's reading, the design text is what changes and the
engine stands, which is much the cheaper repair.

This belongs to the current release and not to this cycle. It needs its own
ticket; as of this writing none is cut. It is recorded here because section
3.1's claim depends on which way it resolves.

### 3.4 What a narrowing repair would force, recorded and not decided

If narrowing lands, the matrix stays on the causal clock, because
`contracts.md:808-810` requires it and because
`history_semantics = "expected_sessions_cutoff_causal"` is an identity input to
the active feature fingerprint (`R/feature-cache.R:55`, verified). The evidence
would be on the knowledge-at-`t` clock, by section 1. The two would then ship
together on different clocks, and a consumer joining them could read evidence
saying a cell is inside the applicable domain at `s` beside a value that is `NA`
because the axis knowable at `s` said otherwise.

That is a coherence hazard rather than an arithmetic error, and it is the case
detector 7 would have to cover. No decision is taken here, because the
antecedent is not the current state and because deciding it now would bind a
design against text that may itself change (section 3.3).

## 4. Column clock

**Decision.** Columns are consecutive prepared decision pulses ending at the
invoking pulse, never the last `L` non-missing observations per asset. In
availability-aware execution those pulses are declared session closes, which
follows from `contracts.md:359` binding decisions to session closes; in dense
execution they are the run's pulses.

This is a design choice, not an inheritance. It is made because a per-asset
"last `L` observations" clock would give different assets different time axes in
one matrix, which silently destroys any cross-sectional estimate computed from
it - the motivating consumer of the whole cycle.

Leading padding uses `NA_real_` where the window extends before available
history. Pre-range history is never silently fetched to replace that padding.

## 5. Evidence semantics under the decision

For column `s` in a window requested at `t`, evidence answers what was
**effective at `s`, as known at `t`**. Consequences that follow without further
evidence:

- A fact effective at `s` but first knowable after `t` does not appear. This is
  the causality guarantee and it is detector-protected (section 8, item 2).
- A fact effective at `s` and knowable at or before `t` appears in column `s`,
  **even if it was not knowable at `s`**. This is the substance of the decision.
- Membership and observation stay independent: an observed pre-membership value
  is not deleted, and non-membership alone does not imply absent history.
- Historical `held`, `priced`, `mark_age` and `tradable()` state is **not**
  replayed. Those depend on portfolio state and valuation policy, not on
  market-cell evidence. A stale risk mark is never an observed close or a
  feature input (`contracts.md:401-405`). This exclusion is firm and is not
  contradicted elsewhere in this document.

## 6. History is for estimating; explain is for auditing

The rejected clock - replaying the information set of each historical pulse -
has a legitimate use: "what did my strategy see that day, and why did it trade?"

**What v2 got wrong about that.** v2 claimed the question already has a surface
and that a second replay mode would duplicate it. Verified by reading:
`ledgr_run_explain()` "joins one retained decision trace to its availability,
execution, valuation, **feature-identity**, position, and terminal evidence"
(`contracts.md:884-889`) - feature identity, not feature values and not
historical windows. And `diagnostics` returns "its typed zero-row schema" for
dense runs (`contracts.md:879-880`), so a dense run retains no trace for explain
to join. Explain audits decisions; it does not reconstruct the numbers a
strategy computed. The duplication argument is withdrawn.

**Decision, on scope grounds.** History serves estimation; explain serves audit.
The first implementation ships no second replay mode, because a second clock is
a second product: it needs its own preparation, whose cost section 3.2 now shows
is not a filter over existing structures, and its own detectors. If a
per-column-cutoff mode is wanted, it opens as its own cycle with its own
justification. This is a scope decision and no longer rests on a claim that the
capability already exists.

## 7. What remains gated

The checkpoint has two parts. v2 had only the first.

**(a) Semantic.** Which cell distinctions the prepared evidence can express, and
how they are encoded. The candidate distinctions are: outside the applicable
point-in-time domain; inside with an accepted observation; inside without a
usable observation; and feature unavailable because causal warm-up is
incomplete. The valuation-policy distinction is **excluded** by section 5, not
gated.

**(b) Representational, new in v3.** Whether the two-dimensional condition of
section 3.2 can be prepared once per run, or whether it requires a rebuild per
decision pulse - and if the latter, what that costs at research scale. This part
exists because v2 wrongly treated the generalisation as a parameter change to an
existing mask.

**The checkpoint, restated:**

> At one knowledge cutoff `t`, can the prepared fact families express, for each
> historical column `s <= t`, which of the section 7(a) distinctions applies -
> including precedence and supersession - without a second resolver,
> per-callback storage queries, or replay of portfolio state; and can the
> `(effective, knowledge)` condition be prepared without a per-decision-pulse
> rebuild of instrument-by-boundary segments?

Its kill condition names the missing prepared evidence, the ownership seam, or a
per-pulse rebuild that cannot be bounded. Green establishes bounded semantic
reuse only: not future-access repair, not training-export parity, not memory
suitability at research scale.

Encoding - boolean planes, packed flags, reason codes, sparse coordinates - is
not decided here. One observation for the checkpoint rather than a decision: a
reason vocabulary already exists in the inspection layer, including
`not_yet_knowable` and `missing_coverage` (`R/availability-inspection.R`), and
the checkpoint should evaluate it for reuse before anything new is minted. Seed
v2's prohibition stands: no new durable availability reason token is invented
for this API, and no second warm-up rule.

## 8. Detecting acceptance requirements

An implementation is acceptable only with detectors that fail on:

1. **Simulated-time escape** - evidence resolved at snapshot-seal time or
   wall-clock now rather than at the simulated decision pulse. This is a
   **construction** check and not a stability check: a seal-time implementation
   returns the same leaked history on every reopen and passes any
   close-and-reopen comparison. It fails when any resolution input is a seal
   timestamp or a wall clock, and it is made falsifiable by item 2's fixture.
2. **Future-knowledge admission** - a fact first knowable after `t` appearing in
   any column. The fixture must contain a fact with `effective_from <= s` and
   `knowledge_time > t` for the invoking `t`, so that seal-time resolution and
   decision-time resolution give **different** answers. Items 1 and 2 are not
   independent; this fixture is what makes item 1 detect anything.
3. **Late-knowledge omission** - a fact effective at `s` and knowable at `t`
   *not* appearing in column `s`. The decision is bidirectional and this is the
   half a per-column clock would forbid.
4. **Future-value escape** - a supported accessor returning a value beyond the
   invoking pulse, in dense and availability-aware execution.
5. **Retained-result mutation** - mutating a returned window altering engine
   storage, another consumer, or a later result; or a retained result losing its
   axis or cutoff when the fold advances.
6. **Axis alignment** - row order disagreeing with the contract-defined decision
   axis including held-nonmember placement, or a `0 x L` empty-axis result
   failing.
7. **Claimed-distinction collapse** - conditional on what the companion claims:
   for whatever distinctions it claims to express, a detector fails when two of
   them become indistinguishable; and any distinction it does **not** claim
   fails explicitly rather than returning a plausible value. No reason is
   inferred from `NA`. If section 3.3 resolves toward narrowing, this item
   extends to the section 3.4 coherence case: evidence and value disagreeing
   about whether a cell was in the applicable domain.
8. **Current-value parity** - scalar, plane and bundle reads disagreeing with
   the pre-change run at any pulse.
9. **Inspection preservation** - the interactive reader failing when the long
   table is empty.

No member-count, timing or memory threshold is an acceptance gate.

## 9. Identity, cost and consumers

**Identity.** Existing feature-cache keys already include snapshot hash,
instrument, feature fingerprint and feature-engine version
(`R/feature-cache.R:122-140`, verified). Preserve that reuse. Ordered axes, the
knowledge cutoff, lookback and the semantic contract version must prevent reuse
of a view across incompatible snapshot, feature, range or availability
semantics. Because the knowledge cutoff is the decision pulse, it introduces no
identity input beyond the run's own clock. No panel registry, no matrix hash.

**Cost.** The baseline already retains `O(FNT)` feature doubles before any
callback - about 95.4 MiB of payload for 500 instruments, 2,500 pulses and ten
features, which is arithmetic and not measured peak RSS. A detached one-feature
window adds `O(NL)` per materialization, about 1 MB at 500 x 252. Section 3.2
adds a second cost question that v2 did not have: the preparation supporting the
two-clock condition. It is not priced here and the checkpoint owns it. Existing
bans hold: no per-callback database history queries, no R-level
instrument-by-pulse reconstruction, no redundant full-panel **long**
materialization, and no market panels in serialized strategy state.

**One open reading question.** Whether the prepared projection is per-process or
shared under parallel sweep is unanswered, and the motivating consumers run as
sweeps. If per-process, a ten-candidate sweep carries roughly a gigabyte before
any window is requested, which is where the scale risk lives. **Answer this by
reading the sweep path before commissioning any representation measurement.**

**Consumers.** One owner does not mean one object or one permission. Strategy
access is pulse-bounded. A later offline training export may traverse an
explicitly selected range under the same rules; retrieving the remainder of the
run is not a strategy capability. Out of scope and unchanged: estimators,
optimizers, clustering, PCA and learners; solver dispatch; model registries;
forward labels, embargo and label weighting; fitted preprocessing and
refit-artifact identity; imputation defaults; scheduling APIs; a general history
query language; and any release commitment.

## 10. Next action

Accept or revise. On acceptance:

1. Cut the section 3.3 divergence as a current-release ticket, with its two
   unrun checks as its first steps. It is independent of this cycle and does not
   wait on it.
2. Run the section 7 checkpoint, both parts.
3. Answer the section 9 sweep question by reading.

Only then consider a spec cut. No comparative spike is chartered and no spec
packet is written here. LDG-2864 and LDG-2850 proceed independently in the
current release.

## 11. Revision history

- 2026-09-26: v3. Supersedes v2 after `NEEDS_TYPE_2`. Keeps the organising
  decision and the settled simulated-clock bound. Replaces v2's matrix claim
  with a contingent one and names its trip-wire; corrects the two-clock
  resolution claim from a cost gap to a representational gap and adds a second
  checkpoint part for it; keeps the no-second-replay-mode decision on scope
  grounds after withdrawing its duplication justification; restates detector 1
  as a construction check dependent on detector 2's fixture; and reports the
  narrowing divergence found while verifying the matrix claim, without taking
  ownership of it.
- 2026-09-26: v2. Recorded the maintainer's knowledge-clock decision as the
  organising choice and withdrew v1's over-bound claims. Superseded.
