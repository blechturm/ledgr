# Cut 6 Ticket-Cut Review

**Reviewed cut:** `8a1fb15`, cut 6, workstreams 10 through 12,
`LDG-2804` through `LDG-2818`.

**Authority:** accepted synthesis `000d7f4`.

## 1. Type 1: Ownership And Detectability

| Accepted requirement | Owner | Result |
| --- | --- | --- |
| 3.1 vendor decoding, identity, normalization and clocks stay upstream; ledgr owns canonical validation and policy | LDG-2805, LDG-2806 | Owned. The fictional-adapter source guard makes the vendor boundary detectable. |
| 3.2 one sealed fact family, validated terms, incomplete facts and two provenance tiers | LDG-2805 | Owned, subject to F4's two ambiguous negative cases. |
| 3.3 closed policy, presets, identity and scope-versioned values | LDG-2809 | Owned. LDG-2810, LDG-2814 and LDG-2815 own the resulting reporting and effects. |
| 3.4 rules 1 through 7 for gross cash and fixed entitlement | LDG-2811 | Owned by failure-sensitive pulse, clock and late-knowledge criteria. |
| 3.4 `DISPOSITION`, FIFO lot consumption, marks and refusal | LDG-2814 | Owned, except the payload exclusion in F3. |
| 3.4 unsupported quantity policy and four-way composition | LDG-2815 | Owned by a four-row numerical witness. |
| 3.5 four fidelity values and ordinary summary | LDG-2810, LDG-2811, LDG-2814, LDG-2815 | The values are owned; several required summary fields lack a detecting acceptance criterion. See F3. |
| 3.6 capability ladder and corporate-action activation exclusion | LDG-2805, LDG-2811, LDG-2814 | Owned. The activation mutation is explicitly detecting. |
| 3.7 compiled economic-event envelope | LDG-2804 | Incompletely detected. See F2. |
| 3.8 quick-path vignette, adapter article and vendor-neutral witness | LDG-2812, LDG-2817, LDG-2806 | Owned. Both articles execute and the adapter has a source guard. |
| 4 price-basis admission and double-counting refusal | LDG-2807, then LDG-2810 and LDG-2811 | The intended owners exist, but the criteria are placed in the wrong serial workstream and one accepted refusal is missing. See F1. |
| 4 quick and rigorous product paths | LDG-2805, LDG-2810, LDG-2811, LDG-2814 | Owned. The later exact-quantity and total-return work is expressly outside this cut. |
| 5 prerequisite-to-gate sequence and no exact-quantity work | Workstreams 10, 11 and 12 | Correct in outline; F1 currently makes Workstream 10 depend on Workstream 11. |
| 6 cases 1 through 3 | LDG-2806, LDG-2811 | Owned. |
| 6 cases 4 through 6 | LDG-2814 | Owned. |
| 6 cases 7 and 14 | LDG-2816 | Owned; durable recovery and memory containment have distinct observables. |
| 6 cases 8 and 13 | LDG-2815 | Owned with numerical, not presence-only, assertions. |
| 6 case 9 | LDG-2817 | Owned, including the cross-sectional-feature failure mode. |
| 6 case 10 | LDG-2804 | Owned in name but not over the complete event set. See F2. |
| 6 cases 11 and 12 | LDG-2810, LDG-2811 | Owned, but the Workstream 10 closeout claims case 11 before its implementation exists. See F1. |
| 8 constructor/preset spellings | LDG-2809 | Owned and recorded at the Workstream 11 close. |
| 8 summary layout | LDG-2810 | Owned and recorded at the Workstream 11 close. |
| 8 refusal-reason closure | LDG-2805 | Owned and recorded at the Workstream 10 close. |
| 8 fictional-adapter placement | LDG-2806 | Owned and recorded at the Workstream 10 close. |
| 11 permitted claims and prohibited claims | LDG-2818, with product surfaces in LDG-2812 and LDG-2817 | The closeout wording is owned; protection against a contradictory release-facing claim is missing. See F5. |

### F1. LDG-2807 and LDG-2808 create a serial dependency cycle

`LDG-2807` is in Workstream 10, but two acceptance criteria require behavior
that only Workstream 11 supplies: an ordinary result naming an undeclared
basis, and a distribution being posted exactly once. Workstream 11 may not
open until Workstream 10 is reviewed and accepted. `LDG-2808` compounds this
by claiming the bars-only half of gate case 11, although `not_supplied` is
implemented by `LDG-2810` in Workstream 11.

The same ticket also tests refusal only when distribution-adjusted bars and
facts coexist. Synthesis section 4 says declared distribution-adjusted bars
are not admitted as execution bars at all; a run with those bars and no facts
could pass the cut as written.

Required patches:

- **LDG-2807:** keep only boundary work in Workstream 10. Reject declared
  distribution-adjusted execution bars both with and without facts. For
  undeclared and split-adjusted bases, assert construction admission and that
  the declaration is carried forward; do not require a completed run.
- **LDG-2810:** own and detect the ordinary-result disclosure for an
  undeclared basis.
- **LDG-2811:** own and detect exactly-once posting on split-adjusted bars.
- **LDG-2808:** remove gate case 11 from the Workstream 10 closeout.
- **LDG-2813:** own all of gate case 11, not only its dividend half.

### F2. LDG-2804 can pass with a CASHFLOW-only guard

The synthesis binds refusal for `CASHFLOW`, `DISPOSITION` and any future
non-`FILL` economic kind. `LDG-2804` executes only `CASHFLOW`. Its source guard
checks that both accounting arms read the same sources; it does not prove that
the event-kind predicate is general. A hard-coded CASHFLOW check can satisfy
all three current acceptance criteria while silently dropping DISPOSITION.

Required patch:

- **LDG-2804:** make the envelope witness table-driven over `CASHFLOW`,
  `DISPOSITION` and a synthetic unknown non-`FILL` kind. Every row must abort
  before execution; removing or narrowing the predicate must make the block
  fail.

### F3. The ordinary-summary and payload requirements are only partly detected

`LDG-2810` lists every required ordinary-summary field, including zero-valued
fields, but its criteria detect only the headline fidelity field. An
implementation may omit selected identities, refusal counts, affected
exposure, modeled proceeds, disposed positions or zero values and still pass.
Later tickets populate some of these values, but do not consistently assert
that they reach the ordinary summary.

`LDG-2814` says the DISPOSITION payload carries neither equity nor vendor
subtype. Its acceptance excludes only the equity subtype.

Required patches:

- **LDG-2810:** add an exact ordinary-summary schema witness covering every
  listed field and explicit zero rendering; retain the existing gut test.
- **LDG-2811:** assert the gross-cash and late-arrival fields in that ordinary
  summary, not only internal state.
- **LDG-2814:** assert exact ordinary-summary values for modeled proceeds,
  disposed positions and realized model PnL, and reject both equity and vendor
  subtype fields in the event payload.
- **LDG-2815:** assert the unsupported count and affected-exposure summary
  fields in addition to the four-quantity report.

### F4. LDG-2805 leaves two negative schema cases ambiguous

The stronger provenance tier requires both a named canonical build and bar
vintage. The current criterion can be satisfied by testing only a row missing
both. Likewise, the no-guessed-leg criterion names only a guessed recipient
leg, although the sealed family also admits gross cash and normalized quantity
terms.

Required patch:

- **LDG-2805:** table-drive the provenance failure with each required binding
  missing separately, and table-drive rejection of every admitted term when
  that term lacks independent validation. Include an incomplete fact carrying
  one independently validated term so the test does not incorrectly prohibit
  known legs merely because a different leg is unavailable.

### F5. LDG-2818 records the release boundary but does not defend it

Restating section 11 in the closeout is falsifiable for that file, but a README,
NEWS entry or either new article could still claim corporate-action
completeness, broker-exact settlement, net cash, tax correctness or exact
recipient exposure while all ticket criteria pass.

Required patch:

- **LDG-2818:** add a release-facing documentation check covering README,
  NEWS and both new articles: permitted claims are qualified as in section 11,
  and none of the prohibited claims appears without the stated limitation.

## 2. Type 2: Workstream Shape And Review Points

The three-workstream shape is sensible after F1 is patched.

- Workstream 10 has one admission-boundary claim: canonical vendor-neutral
  facts and honest price basis enter, while unsupported compiled execution does
  not. The compiled guard belongs here, not in its own workstream. No economic
  event executes before the Workstream 10 close, so reviewing the guard there
  still verifies the prerequisite before cash or disposition work begins.
- Workstream 11 is the complete bars-plus-simple-facts path: policy identity,
  disclosure, gross cash, and its executable quick-path documentation.
- Workstream 12 is the availability-aware terminal path and the integrated
  release gate: disposition, composition, recovery, physical closure and the
  second article all depend on the same event/replay claim.

The close review points are correctly placed. Workstream 10 must close before
any account effect, Workstream 11 before lot-consuming disposition, and
Workstream 12 closes the cut. An extra review immediately after LDG-2804 would
test no additional consumer and would turn a one-ticket prerequisite into
ceremony.

The ticket grain is honest: 15 tickets, exactly five in each workstream. The
adapter, two articles, recovery witness, integrated gate and three closeouts
are independently holdable deliverables, not padding. The planned cut review
plus three close reviews is 4 / 15 = 0.267. This required correction review
would make it 5 / 15 = 0.333. The cut can satisfy the D8 maximum of 0.5 without
merging workstreams or manufacturing ticket count.

## Verdict

The architecture and grouping survive. Five bounded findings need ticket patches
before implementation; F1 is blocking because the current serial plan cannot
complete Workstream 10 on its own terms.

CHANGES_REQUIRED
