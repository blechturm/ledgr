# Cut 2 Review: Accounting-Core Consolidation

**Reviewed cut:** `e87d441`.
**Modes:** Type 1 coverage verification, then Type 2 grouping review.
**Reviewer/date:** Codex, 2026-09-22.

## 1. Type 1: Coverage And Checkability

The basic ownership map is faithful:

| Bound area | Owner |
| --- | --- |
| 3.1, D6: carrier, running net, scan removal, accessors, copy cost | LDG-2776 |
| 3.2: cash and positions outside the kernel | LDG-2776; replay parity in LDG-2779 |
| 3.3: common preparation and fail-closed operation mapping | LDG-2778 |
| 3.3-3.4: replay, facts, projections, fetch state, resume | LDG-2779 |
| 3.5: R/C++ behavioral parity | LDG-2779; registry ownership in LDG-2784 |
| 3.5: segment transfer and its measured cost | LDG-2780 |
| D1 through D6 | LDG-2783, 2781, 2782, 2784, 2777, 2776 respectively |
| Section 6 bullets 1-5 | LDG-2776 through 2779 and LDG-2784 |
| Section 6 production profile | LDG-2785 |

The paired entries above divide behavior from registration or component proof;
they are not duplicate authority. Three bounded corrections are required.

### T1-F1 - Two acceptance clauses take work owned by later tickets

LDG-2778 requires that no side or event-type vocabulary check survives outside
the preparer, but LDG-2782 owns deletion of the dead side and FILL_PARTIAL
checks and cannot run until after LDG-2779. LDG-2779 requires that no projection
owns a second event loop, while LDG-2780 owns deletion of those loops and
depends on LDG-2779. Neither earlier ticket can honestly close as written.

Keep LDG-2778 responsible for the preparer's sole vocabulary on the new path
and LDG-2779 for routing every production projection to the replay. Leave
source deletion to LDG-2782 and LDG-2780. Also add rejecting acceptance cases
for invalid quantity, price, fee, and opening metadata; LDG-2778 currently
tests only unknown event type or side despite binding all of them.

### T1-F2 - Three bound safeguards are not checkable

No acceptance criterion owns 3.1's prohibition on persisted-schema, identity,
or public-result change. Add it to LDG-2776. No criterion preserves 3.5's
compiled boundary: optional, fill-only, memory-sweep-only, unchanged default,
and fail-before-execution for unsupported operations. Add one owner, naturally
LDG-2784 alongside LCL-0006. LDG-2785 owns the production profile but does not
say that prototype multiples are not thresholds; add that Section 6 rule.

### T1-F3 - The closeout can precede required cleanup

LDG-2785 depends on LDG-2784 and LDG-2780, but not LDG-2781 or LDG-2782.
Both cleanup tickets are required synthesis work. Add both dependencies.
LDG-2783 stays optional and need not block closeout, which must name it as
deferred if it does not land.

### Inventory And Cut-1 Reconciliation

All twelve inventory sites map to work: S01 and S03 to LDG-2776; S02 to
LDG-2779/2780/2782; S04 to the LDG-2780 transfer and LDG-2784 differential
claim; S05-S09 to LDG-2779 and 2780, with S06 also in LDG-2782; S10-S11 to
LDG-2779; S12 to LDG-2780. S04 is deliberately retained, not rewritten.

The cuts block is coherent: Cut 1 owns workstreams 1-5 and is closed; Cut 2
owns workstream 6 and is cut. Every workstream has the correct `cut` value.

The requested `7ae5892` comparison is not literally unchanged: 28 of 31 Cut-1
tickets are identical. LDG-2771 changed title, status, scope, acceptance, and
evidence; LDG-2772 and LDG-2775 changed status and evidence. Those changes all
landed earlier in `ec0e6f3`, the accepted Workstream-5 completion. Comparing
`e87d441` with its parent confirms that Cut 2 changed none of the 31 Cut-1
ticket objects and preserved their order.

## 2. Type 2: Grouping And Review Grain

The intermediate carrier check should stay optional. The accepted synthesis
binds one review at close, and LDG-2776 already has exact carrier witnesses.
A mandatory review immediately after it would run before LDG-2777 proves the
failure-sensitive scaling detector. If the maintainer calls the optional
check, call it after LDG-2777 so carrier semantics and scaling are reviewed
together, before preparer and replay work starts.

Ten tickets are an honest unit count, not padding. I would merge or split none:

- LDG-2776 changes semantics and representation; LDG-2777 proves scaling by
  mutation.
- LDG-2778 proves a source-normalization boundary; LDG-2779 proves economic
  replay and every projection.
- LDG-2781 is a data-dependent schema decision; LDG-2782 is dead R cleanup.
- LDG-2780 is the irreversible removal step; LDG-2784 changes the claims
  control plane; LDG-2785 records the closeout; LDG-2783 is optional work.

The review gate must be judged on actual completed tickets at close, not the
cut's planned denominator. If LDG-2783 lands, two reviews over ten is 0.20; if
it is deferred, the ratio is 2/9. An optional third review makes those 0.30 or
0.33. Even the synthesis's coarser six-step denominator gives 0.33 or 0.50,
so the gate result is not an artifact of this ticket split.

## Verdict

The accepted design and one-workstream grouping remain intact. Patch T1-F1
through T1-F3, move the optional-check wording to after LDG-2777, and state the
gate denominator as actual completed tickets. No Type 2 redesign is needed.

PASS_AFTER_PATCHES

## Patch record

Applied by Claude in place, 2026-09-22. T1-F1: LDG-2778's vocabulary
clause now claims only the new path and adds rejecting cases for invalid
quantity, price, fee, and opening metadata; LDG-2779's clause now claims
routing, with deletion left to LDG-2780. T1-F2: LDG-2776 owns the
no-persisted-change prohibition; LDG-2784 owns the compiled boundary;
LDG-2785 states that prototype multiples are not thresholds. T1-F3:
LDG-2785 depends on LDG-2781 and LDG-2782 and names LDG-2783 as landed or
deferred. Type 2: the optional check moved to after LDG-2777; the README
states the gate on completed tickets at close.

One item postdates this review. The inventory correction at b92a45c found
six ledger_events readers the twelve-site inventory missed (S13-S18: one
lot driver, two live position/cash replays, three dead). LDG-2779 and
LDG-2780 were widened to own them. The review's ownership map is
unaffected because both tickets already existed; its "all twelve sites map
to work" statement now reads "all eighteen".
