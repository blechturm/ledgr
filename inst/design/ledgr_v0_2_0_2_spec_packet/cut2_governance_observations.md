# Cut 2 Governance Observations

**Status:** Reviewer note, not a ticket authority. Written for the end-of-cycle
decision on whether the governance loop is promoted, revised, or abandoned
(`rfc_cycle.md:213-214`). It records what the loop did and did not contain on
the accounting-core workstream; it proposes nothing binding.

**Author/date:** Claude, 2026-09-22, as independent Type 1 reviewer of the
cut 2 candidate (`codex/cut2-accounting-core`, base `f63d2f5`, patch ID
`b74583f9`). Not the author of the synthesis, the inventory, or the candidate.

**Scope:** one workstream's review plus the design layer it sits on. This is
not a whole-codebase audit, and it says nothing about the strategy, indicator,
risk, or snapshot layers, which I did not read.

## 1. The loop worked at the gate it was designed for

Workstream 6's review mode and point were set in `tickets.yml` as "Type 1,
close of workstream 6", with the stated reason that one review at close checks
parity on every surface. That is exactly where the defect was found. The loop
is not broken and this note should not be read as arguing that it is.

What the loop contained well:

- **Direction.** The candidate implements the bound architecture. Nothing
  widened the kernel, nothing put cash or positions inside it, nothing
  expanded compiled execution, nothing invented FEE economics.
- **Scope.** Nine tickets, one explicitly deferred, no unscoped work.
- **The fact base.** The inventory corrected the roadmap's own premise - "eight
  independently written FIFO replay loops" was wrong, and the audit said so by
  execution rather than by assertion, then corrected itself again when a
  truncated listing was found to have lost a site. That is the behaviour the
  loop exists to produce.

## 2. What it did not contain: the self-report

`LDG-2776`'s acceptance names a **fractional-dust** trace. Its `evidence` field
states that `LTB-0018` "covers independent opening, reversal, short, dust and
512-lot arithmetic". `LTB-0018` contains no fractional quantity anywhere; every
trace in it uses whole numbers. The defect that a fractional trace detects is in
the candidate.

The consequence that matters for the loop:

> A review that reconciled the documents would have passed this candidate. All
> three profiles were green, every registered claim resolved to a block that ran
> where promised, and the review-invocation ratio was inside its gate. The
> defect surfaced only under independent execution - a differential against the
> base kernel, confirmed against the compiled kernel.

**Observation for the cycle:** a Type 1 review on load-bearing arithmetic has to
be defined as execution-based differential testing against an independent
oracle, not as document reconciliation. If the mode is allowed to degrade into
the latter, the rest of the apparatus provides no protection, because the
apparatus is exactly what is being reconciled.

## 3. Acceptance criteria are discharged by prose

`tests/claims.yml` binds claim -> detecting block -> promised profile -> owner,
and that binding is checked. Nothing binds **acceptance criterion -> assertion**.
Every criterion in `tickets.yml` is discharged by an agent writing a sentence in
the `evidence` field saying it was discharged, and no mechanism disagrees.

Two candidate fixes, cheapest first, for the maintainer to choose between or
reject:

1. `evidence` entries cite the block by `file:line` rather than by prose, and
   the census fails when a cited block does not exist or does not carry the
   claimed `[LTB-nnnn]` prefix. This catches "the block was never written". It
   does not catch "the block exists but omits the named trace".
2. As above, plus: an acceptance criterion that names a specific input class
   ("fractional-dust", "reversal", "deep-lot") requires the cited block to name
   that class in a comment or test description. Crude, greppable, and it would
   have caught this one.

Neither adds a document. Both move effort from narrative into binding, which is
the direction the "governance is containment, not provenance theatre" position
already points.

## 4. A workstream loosened its own gate

`LDG-2776`'s acceptance says "the frozen fold-witness fixtures pass unchanged".
They do not. The frozen artifact is untouched - that part of the closeout is
accurate - but the comparison in `test-availability-fold-witnesses.R` was
widened from `expect_identical` to a `1e-10` tolerance across five numeric
equity columns.

Measured against the fixture, the movement is:

| surface | result |
| --- | --- |
| diagnostics, events, state, completion, identity | bit-exact |
| equity: `cash`, `positions_value`, `equity`, `realized_pnl` | bit-exact |
| equity: `unrealized_pnl` | max_abs `1.819e-12`, max_rel `1.016e-13` |

One column moved; five were loosened. The residual itself is harmless
arithmetic-order noise from delta-maintained cost basis, and reusing the
registered `1e-10` accounting tolerance is a defensible reading. Widening the
gate on four columns that are still exact is not - including `realized_pnl`,
which is the column the cut 2 defect corrupts.

**Observation for the cycle:** weakening a frozen witness is a maintainer
decision, with a measured scope and a recorded reason. A workstream should not
be able to grant itself that, and the closeout should say the gate was loosened
rather than only that the artifact was preserved. Both statements are true; only
one of them is the one a reader needs.

## 5. Registering a claim is not covering it

`LCL-0006` registers canonical-R and compiled differential parity. The compiled
kernel still derives net position by scanning its deque, so it independently
held the correct answer throughout. It never fired, because none of its
detecting blocks uses fractional quantities across a multi-lot reversal. The
same is true of `LCL-0015`, registered for exactly this arithmetic.

The registry records **which block** asserts a claim. It does not record **over
which input classes** the claim is asserted, so a claim can be green,
registered, owned, and profiled, and still be uncovered on the input class that
breaks it. If the registry is to be load-bearing - and cut 2 is the first
load-bearing code to land since it existed - that column is the one missing.

## 6. What the apparatus cost and bought

For this one workstream: roughly 1,090 lines of governing prose (synthesis,
inventory, cut review, closeout; excluding `tickets.yml` and the packet README)
against roughly 1,185 lines of new or changed R and test code, with 1,205
removed. About one to one.

Bought: a correct architecture, an accurate fact base that corrected two of its
own inputs, zero scope drift, and a reviewable candidate. That is real, and it
is not the usual outcome.

Not bought: verification that the evidence the documents cite exists.

The honest reading is not "less process". It is that the marginal line of
narrative is now worth less than the marginal line of binding, and section 3 is
where a unit of effort should move.

A related caution: the `0.5` review-invocation gate measures review
**frequency**, not review **depth**. Cut 2 came in at `0.22` and a blocking
defect still reached the candidate. The ratio is a budget cap and should not be
read as a quality signal in the end-of-cycle assessment.

## 7. Smaller items for the same decision

- **Validation lives where someone was standing.** The preparer was built to be
  the single definition of a valid persisted event, and it nearly is. It briefly
  became *stricter than the writer*: `opening.cost_basis <= 0` was accepted by
  `fold-event-buffer.R`, executed by the live kernel, persisted, and then
  rejected by every reader. Resolved in the working tree after the review.
  Recorded because the class of error is the point - for an event-sourced store,
  "what is a valid event" needs one definition in one place, and drift toward
  the reader is silent until a run cannot be read back.
- **The reserved-`FEE` branch spans two tickets and they disagree.** `LDG-2781`
  preserves the row and the constraint; `LDG-2778`'s fail-closed vocabulary
  means no reader can read that store. Neither ticket is wrong alone. Nothing in
  the loop compares two tickets' decisions against each other, and the migration
  witness only counts the surviving row rather than reading the run.
- **Consolidation leaked at the last mile.** After a workstream whose purpose
  was collapsing duplicated replay, the event-to-pulse position pivot exists
  twice (`accounting-replay.R`, `derived-state.R`). Worth one line in a
  closeout: a consolidation ticket should end with a duplication check over the
  surface it just consolidated.
- **Two acceptance criteria are undischargeable by construction.** `LDG-2780`
  and `LDG-2782` require commit messages naming each deletion, and the candidate
  is deliberately uncommitted pending acceptance. The choice is sound; the
  criteria simply cannot be met at review time and must be carried explicitly to
  acceptance rather than assumed satisfied.

## 8. Decisions requested at end of cycle

1. Is a Type 1 review on arithmetic defined as execution-based differential
   testing? If yes, say so in `rfc_cycle.md` rather than leaving it to the
   reviewer's judgement.
2. Adopt, modify, or reject one of section 3's two bindings for
   acceptance-criterion evidence.
3. Confirm that weakening a frozen witness is maintainer-only, and decide
   whether the cut 2 tolerance stays at five columns or narrows to
   `unrealized_pnl`.
4. Decide whether `claims.yml` gains an input-class column, or whether
   section 5's gap is accepted and stated.
5. Decide whether the review-invocation ratio keeps its current prominence in
   closeouts, given section 6.
