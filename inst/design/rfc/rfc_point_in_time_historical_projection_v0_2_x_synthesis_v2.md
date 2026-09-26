# RFC Synthesis v2: Point-in-Time Historical Projection

**Status:** Decision synthesis, superseding
[synthesis v1](rfc_point_in_time_historical_projection_v0_2_x_synthesis.md),
which returned `NEEDS_TYPE_2`. Decisions bind on maintainer acceptance.
**Date:** 2026-09-26
**Author:** Claude, per role rotation. v1 over-bound its section 5 and
contradicted itself in sections 7 and 10; section 2 below records each
withdrawal. The final review that caught them is
[here](rfc_point_in_time_historical_projection_v0_2_x_synthesis_review.md) if
committed, otherwise in the cycle record.
**Maintainer decision, 2026-09-26:** a history request returns **all
information knowable at the decision pulse**. This resolves the question v1
wrongly treated as already settled, and it is the organising decision of this
document.
**Baselines:** design `491c4ed`; implementation `ae040e7`. Claims are marked
verified by execution, verified by reading, or open.

---

## 1. The decision, stated precisely

A history request made at decision pulse `t` returns, for each historical
column `s <= t`, the value and the evidence that are **knowable at `t`**.

Two clocks, separated:

- the **knowledge clock is fixed at `t`** - a fact participates if
  `knowledge_time <= t`;
- the **effective clock varies with the column** - a fact applies to column `s`
  if `effective_from <= s` and `s < effective_to`.

This is not lookahead. Only information available at the decision pulse is
used,
and nothing after `t` is consulted. It differs from replaying the information
set of each historical pulse, which is a different product served by a
different
surface (section 6).

**The single most important implementation constraint.** `t` is the **simulated
decision pulse**. It is never snapshot-seal time and never wall-clock now. In a
backtest replaying 2020, `t` is a date in 2020, and the knowledge filter uses
the sealed `knowledge_time` values against that simulated instant. Resolving at
seal time or at the real present would admit facts published after the
simulated
decision, which is genuine lookahead. Every detector in section 8 exists
primarily to protect this sentence.

## 2. Withdrawals from synthesis v1

Recorded rather than deleted, because the reasoning is part of the cycle.

| v1 claim | Disposition |
| --- | --- |
| Original cutoff is already required by `contracts.md:354-358` | **Withdrawn.** That rule forbids rewriting an earlier *result*; it does not fix the knowledge clock of a new request. The accepted availability synthesis says the opposite explicitly: excluded rows are "visible in retrospective views", exclusion is "cutoff-specific", and a row "may become admissible history later... and no later admission changes an earlier result". |
| The checkpoint shrinks because cutoff semantics are inherited | **Withdrawn as stated.** The checkpoint does shrink, but because the maintainer decided the clock, not because a contract had. |
| The column clock is already bound at `contracts.md:359` | **Softened.** That line binds *when decisions occur* - declared session closes. It does not establish that a history request counts consecutive common decision pulses. That remains a design choice, made in section 4. |
| Fact resolution is "three vectorised comparisons over loaded rows" | **Withdrawn.** `ledgr_availability_applicable()` returns an applicability mask; production resolution delegates to `ledgr_availability_provider_build_prepared()`, which prepares membership and status/lifetime segments and resolves precedence and supersession. Prepared machinery exists; that description of it was wrong. |
| Sections 7 and 10 together | **Corrected in section 8.** v1 gated the cell distinctions and then mandated detectors for three of them, and listed a valuation distinction section 5 had excluded. |

Unchanged from v1 and not re-argued here: the projection is the single owner
and
the lower-projector direction stays closed (verified by execution); Direction
5.4
is preserved including its `ctx$window()` spelling; the row axis and its order
follow `contracts.md:348-352`; the access boundary follows the maintainer
correction of 2026-09-26 and its repair is owned by LDG-2864 and LDG-2850.

## 3. What the decision settles, and how much it removes

**The numeric matrix is unaffected.** Verified by reading. Feature values
derive
from bars; bars are sealed and carry no knowledge clock within a snapshot, so a
value at column `s` does not change with `t`. The window's rows are the
decision
axis at `t`, which was already bound. Therefore the knowledge-clock decision
governs **only the companion evidence**, not the numbers.

That is a large scope reduction and it should be stated plainly: this cycle is
no longer deciding anything about the matrix beyond Direction 5.4.

**One knowledge filter, not `L` resolutions.** Because the knowledge clock is
fixed at `t`, the evidence for an entire window derives from a single knowledge
filter, followed by a per-column effective-interval test. The expensive shape -
resolving every column at its own cutoff - is the one the decision rejects.

**The existing resolver is the special case.** Verified by reading.
`ledgr_availability_applicable(rows, cutoff)` applies one `cutoff` to both
clocks (`R/availability-provider.R:51-57`), and `ledgr_session_resolve_at()`
does the same with one `at` (`R/availability-inspection.R:496-520`). Both are
the `s == t` case of what history needs. The generalisation is small in shape -
two time arguments instead of one - but its **completeness is not
established**,
because precedence and supersession resolution live in the prepared provider
rather than in those masks. Section 7 gates that.

## 4. Column clock

**Decision.** Columns are consecutive prepared decision pulses ending at the
invoking pulse, never the last `L` non-missing observations per asset. In
availability-aware execution those pulses are declared session closes, which
follows from `contracts.md:359` binding decisions to session closes; in dense
execution they are the run's pulses.

This is a design choice, not an inheritance. It is made because a per-asset
"last `L` observations" clock would give different assets different time axes
in
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
  **even if it was not knowable at `s`**. This is the substance of the decision
  and the direct reversal of v1.
- Membership and observation stay independent: an observed pre-membership value
  is not deleted, and non-membership alone does not imply absent history.
- Historical `held`, `priced`, `mark_age` and `tradable()` state is **not**
  replayed. Those depend on portfolio state and valuation policy, not on
  market-cell evidence. A stale risk mark is never an observed close or a
  feature input (`contracts.md:401-405`). This exclusion is firm, and unlike v1
  it is not contradicted elsewhere in this document.

## 6. History is for estimating; explain is for auditing

The rejected clock - replaying the information set of each historical pulse -
has a legitimate use: "what did my strategy see that day, and why did it
trade?"
That question already has a surface. `ledgr_run_explain()` returns the
persisted
explanation for an instrument, and Workstream 16 extended it to return a whole
instrument history in pulse order.

**Decision.** History serves estimation; explain serves audit. The first
implementation ships no second replay mode, because it would duplicate a
shipped
surface with a worse one. If a per-column-cutoff mode is ever wanted, it opens
as its own cycle with its own justification.

## 7. What remains gated

**Which cell distinctions the prepared evidence can express, and how they are
encoded.** The candidate distinctions are: outside the applicable
point-in-time domain; inside with an accepted observation; inside without a
usable observation; and feature unavailable because causal warm-up is
incomplete. The valuation-policy distinction is **excluded** by section 5, not
gated.

Encoding - boolean planes, packed flags, reason codes, sparse coordinates - is
not decided here. One observation for the checkpoint rather than a decision: an
existing reason vocabulary already exists in the inspection layer, including
`not_yet_knowable` and `missing_coverage` (`R/availability-inspection.R`), and
the checkpoint should evaluate it for reuse before anything new is minted. Seed
v2's prohibition stands: no new durable availability reason token is invented
for this API, and no second warm-up rule.

**The checkpoint, restated for the decision:**

> At one knowledge cutoff `t`, can the prepared fact families express, for each
> historical column `s <= t`, which of the section 7 distinctions applies -
> including precedence and supersession - without a second resolver,
> per-callback storage queries, or replay of portfolio state?

Its kill condition names the missing prepared evidence or the ownership seam.
Green establishes bounded semantic reuse only: not future-access repair, not
training-export parity, not memory suitability at research scale.

## 8. Detecting acceptance requirements

An implementation is acceptable only with detectors that fail on:

1. **Simulated-time escape** - evidence resolved at snapshot-seal time or
   wall-clock now rather than at the simulated decision pulse. This is the
   primary detector; a backtest whose history changes when the snapshot is
   re-opened later has failed it.
2. **Future-knowledge admission** - a fact first knowable after `t` appearing
in
   any column.
3. **Late-knowledge omission** - a fact effective at `s` and knowable at `t`
   *not* appearing in column `s`. The decision is bidirectional and this is the
   half v1 would have forbidden.
4. **Future-value escape** - a supported accessor returning a value beyond the
   invoking pulse, in dense and availability-aware execution.
5. **Retained-result mutation** - mutating a returned window altering engine
   storage, another consumer, or a later result; or a retained result losing
its
   axis or cutoff when the fold advances.
6. **Axis alignment** - row order disagreeing with the contract-defined
decision
   axis including held-nonmember placement, or a `0 x L` empty-axis result
   failing.
7. **Claimed-distinction collapse** - *conditional, replacing v1's
unconditional
   item*: for whatever distinctions the companion claims to express, a detector
   fails when two of them become indistinguishable; and any distinction the
   companion does **not** claim fails explicitly rather than returning a
   plausible value. No reason is inferred from `NA`.
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
window adds `O(NL)` per materialization, about 1 MB at 500 x 252. Existing bans
hold: no per-callback database history queries, no R-level
instrument-by-pulse reconstruction, no redundant full-panel **long**
materialization, and no market panels in serialized strategy state.

**One open reading question.** Whether the prepared projection is per-process
or
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
refit-artifact identity; imputation defaults; scheduling APIs; a general
history
query language; and any release commitment.

## 10. Next action

Accept or revise. On acceptance: run the section 7 checkpoint, answer the
section 9 sweep question by reading, and only then consider a spec cut. No
comparative spike is chartered and no spec packet is written here. LDG-2864 and
LDG-2850 proceed independently in the current release.

## 11. Revision history

- 2026-09-26: v2. Supersedes v1 after `NEEDS_TYPE_2`. Records the maintainer's
  knowledge-clock decision as the organising choice, withdraws v1's four
  over-bound or incorrect claims, resolves v1's internal contradiction with a
  conditional detector, establishes that the decision governs evidence rather
  than the matrix, separates history from explain, and restates the checkpoint
  around a single knowledge cutoff.
