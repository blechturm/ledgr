# Synthesis: Usable Equity Corporate Actions for v0.2.0.2

**Status:** Binding for v0.2.0.2 once accepted. Patched 2026-09-24 after
final review returned `NEEDS_TYPE_2`; see the revision history.
**Author:** Claude (synthesis). **Date:** 2026-09-24
**Seeds:** v1 through v7, Codex. **Responses:** v1 through v7 plus two
addenda, Claude. **Maintainer decisions:** 2026-09-23 and 2026-09-24.
**Evidence:** quantity-primitive spike (RED), axis-density spike (GREEN,
scoped), terminal-disposition spike (GREEN), corrected Tier 2 census.

Two decisions in this document originate here rather than in the seed or
response record. They are marked **[synthesis-only]** so review can
scrutinise them first. The first draft claimed three and marked two.

## 1. Corrections The Synthesis Author Owes

I wrote every response in this cycle and must record where I was wrong before
choosing anything.

**The density claim.** Response v4 asserted that a recipient starting to trade
mid-window could not sit on a sealed axis because finalization requires a
dense close matrix. I read one branch as the general rule. The axis-density
spike falsified it for the public availability path, and I reviewed that
spike's evidence and confirmed the refutation.

**The transaction claim.** Response v4 offered multi-row grouping with
atomicity coming free from "one transaction". Response v5 found that no such
transaction exists on either writer. I proposed a property and then charged
the seed with failing to provide it.

**The product frame.** Responses v1 through v7 reviewed each seed against the
user it declared. Only after the maintainer stated the two-path constraint did
I consider the user with a free data export, who will be the more common one.
Every finding in the v7 addendum comes from that late shift.

**The competitor claim.** The first draft of this synthesis asserted that no
surveyed engine handles security distributions. The 2026-09-24 horizon entry,
which I had read, records that zipline can create recipient shares from a
stock dividend. I generalised a real gap into a false absolute. Section 4
carries the correction.

The cycle ran seven seeds. Two were caused by measurements contradicting
belief, which is the system working. Two were caused by my errors.

## 2. Decision

v0.2.0.2 ships one equity corporate-action slice: sealed vendor-neutral facts,
evidenced gross cash distributions, modeled terminal disposition, explicit
refusal, and a headline fidelity signal. It does not transform parent holdings
into recipient holdings, and it may not describe itself as corporate-action
complete.

The release exists because a multi-year walk-forward that halts at the first
held terminal produces nothing, and because omitted distributions are the
largest systematic economic error in the package for equity research.

Exact quantity settlement is scheduled product work under its own RFC, not an
unowned deferral. The corrected census is its empirical input: 41 candidates,
22 daily-model-ready, 10 clean single-recipient stock acquisitions.

## 3. Bound Architecture

### 3.1 Layers

The adapter owns vendor decoding, action-meaning validation, stable parent and
recipient identity resolution, unit normalization into the snapshot's share
basis, clock preservation and refusal classification. ledgr owns policy,
accounting effects, reporting and experiment identity. ledgr never learns a
vendor code, a raw vendor field or an adjustment formula.

This boundary survived all seven seeds unchanged and is the most tested claim
in the cycle.

### 3.2 Sealed facts

One typed `equity_corporate_actions` family. Header: stable fact identity,
subtype, parent identity, the four clocks when supplied, knowledge time,
completeness, one closed refusal reason, and a provenance tier. Terms: gross
cash per canonical parent unit, recipient identity and normalized recipient
quantity per parent unit, each only when independently validated. An
incomplete fact keeps its header and reason and carries no guessed leg.

**Provenance is tiered, not required.** `snapshot_bound` means the facts are
user-supplied, sealed, and covered by snapshot identity. The stronger tier,
`upstream_vintage_bound`, adds a named canonical build and bar vintage.
Both validate. The weaker tier stays reproducible and is ineligible for
work that genuinely requires vintage, exact quantity transformation above
all.

This resolves the lock-out in the v7 addendum. A vendor that cannot express a
canonical build no longer bars its user from the rigorous path entirely.

The family may need migration or reseal when the exact-quantity RFC lands.
This release does not promise today's term shape is final.

### 3.3 Policy

`corporate_action_policy`, a constructor-built object joining the six that
`ledgr_experiment()` already takes. Omission resolves to a versioned research
preset; `ledgr_corporate_actions_strict()` is the explicit refusal preset.
Values are drawn from closed sets. Arbitrary callbacks are not accepted. The
resolved policy including defaults enters experiment and run identity, so a
historical run never acquires a default implicitly.

| Choice | Research preset | Other admitted values |
| --- | --- | --- |
| cash amount | `gross` | `refuse` |
| cash posting | `next_open` | `effective_close`, `refuse` |
| held terminal position | `last_permissible` | `last_mark`, `refuse` |
| unsupported quantity event | `report_only` | `refuse` |

**The preset selects `last_permissible`.** The terminal-disposition spike
executed that option and refused without a qualifying mark. Unbounded
`last_mark` was not executed, and it suspends the staleness horizon for the
one case where an instrument is least likely to be worth its last price. This
repository's own prior-art review calls stale-price liquidation hazardous in
zipline; the default must not reproduce it. `last_mark` remains available as
explicit opt-in and keeps its gate case.

**[synthesis-only] A policy value's version covers its scope, not only its
behaviour.** The first draft claimed the unsupported-quantity knob would
disappear when exact settlement lands. Final review refuted that: unknown
subtypes, incomplete evidence and event types not yet designed keep a
"cannot execute this" choice alive permanently. No knob here is temporary.

What does change is what a value covers. `report_only` today means every
quantity-changing effect is skipped; after exact settlement it would mean only
the remaining unsupported ones. The same recorded string would describe two
different behaviours, and a historical run's policy would silently change
meaning.

So the versioned identifier each value already carries is bound to scope as
well as behaviour. Narrowing what a value applies to mints a new version. Runs
either side of a frontier move are then distinguishable rather than colliding
in identity. This uses the versioning convention the seeds established; it
adds no mechanism.

### 3.4 Account effects

**Gross cash distributions** post one existing `CASHFLOW` at the selected
convention, carrying source-fact, amount-policy and posting-policy identity.
No payment-date, withholding, investor-tax or broker-net claim is asserted.

**Modeled terminal disposition** consumes live lots at the selected evidenced
mark under canonical FIFO, realizes model PnL, removes the position and moves
cash. It persists `DISPOSITION`, not `FILL`: no exchange, broker, order, fee
or executable trade is asserted. **The payload is asset-neutral.** Position
removal at a mark is a cross-asset concept and option exercise or physical
delivery must be able to inherit the event. Equity subtype lives in the source
fact and the policy, never in the shared ledger event.

**Unsupported quantity effects** change no account state under `report_only`
and raise fidelity to `unsupported`. Strict mode stops when the affected
parent is held.

### 3.5 Fidelity

Execution state and economic fidelity answer different questions and must not
share a field. Ordinary results carry a headline `corporate_action_fidelity`,
printed in the standard result rather than a specialist reader.

| Value | Meaning |
| --- | --- |
| `not_supplied` | No corporate-action facts were supplied at all |
| `none` | Facts were supplied and none affected a held instrument |
| `modeled` | A configured posting or disposition convention was exercised |
| `unsupported` | A relevant supplied fact was reported without its effect |

Seed v7 proposed a fifth value, `evidenced`, for effects using wholly
evidenced semantics. Final review found it unreachable and it is dropped.
Every effect this release can exercise, cash posting and terminal disposition
alike, runs through a configured convention, so `modeled` always outranks it.
A state that can never occur is noise in a headline field. It is reserved in
section 9 for a release with complete clocks.

Severity is monotone across the last three. `not_supplied` sits outside that
ladder rather than at its clean end, and prints unambiguously, for example
`Corporate actions: NOT SUPPLIED - returns may omit distributions`. This is
the most common state the package will ever report and the one case where a
reassuring word would be wrong.

**Omitted value is reported, not merely counted.** Where terms permit, the
summary reports the omitted recipient value as recipient quantity times the
recipient mark at the effective session, in currency and as a share of
affected exposure. It is labelled an effective-date estimate and explicitly
not the eventual return bias, because the value at distribution is not what
holding the recipient would have earned. Where terms do not permit it, report
`unavailable` rather than nothing.

This makes the sealed recipient terms load-bearing in this release rather than
schema built for deferred work.

The field speaks only about supplied facts. It never claims the source was
complete.

### 3.6 The capability ladder

Availability activation is **not** dismantled. A terminal position with
missing bars needs a session calendar and staleness semantics to distinguish
temporarily unpriced from economically terminated. That requirement is a real
semantic dependency, not coupling.

The release publishes an honest ladder instead:

| Rung | Capability |
| --- | --- |
| Bars only | Ordinary execution; corporate-action coverage explicitly absent |
| Bars plus simple facts | Cash distributions and reporting, where existing pulses suffice |
| Availability-aware setup | Terminal disposition, stale-mark policy, ragged histories, physical-axis closure |
| Later exact-quantity release | Atomic recipient positions and basis transfer |

Terminal disposition is advertised as an availability-aware capability. A
lifetime-only disposition without sessions and a valuation policy changes
missing-bar semantics and requires its own runnable probe before it is
promised.

**The second rung must be defended in code.** `ledgr_availability_activation()`
activates on membership, sessions, trading status or lifetime. The
`equity_corporate_actions` family must be explicitly excluded from that list,
with the reason recorded beside it, or a dividend-only user is forced into a
session calendar and the published ladder becomes false.

### 3.7 Compiled boundary

Compiled spot-FIFO must refuse a plan containing `CASHFLOW`, `DISPOSITION` or
a future quantity transformation, before execution. It may not complete after
dropping one. This release adds no compiled settlement. Canonical R is the
executable authority.

### 3.8 Documentation as product

An executable vignette teaches the private-to-canonical boundary using
fictional vendor data: headers, terms, keys, clocks, units, refusal states,
physical axis versus membership, construction, sealing, reopening, policy
presets, and the difference between preserved facts, executed effects and
unsupported effects. It teaches identity resolution and refusal as ordinary
outcomes, not failures, because the census could not resolve every recipient
even with full vendor data.

A synthetic adapter with different source column names and codes must build
the same canonical facts and pass the same validator, calling no Sharadar
helper and reproducing no Sharadar formula. This is the vendor-neutrality
witness and it is a release deliverable, not documentation.

The constructor and validator are the authority; the vignette is executable
teaching that cannot drift independently.

## 4. Open Decisions Resolved

**Adjusted prices are not sealed as execution bars.** An adjusted price is not
a price anyone could trade at, and sealing one corrupts cash, basis and
affordability while leaving returns roughly right. Adjusted series are also
retroactively mutable, which breaks the reproducibility this package exists
for. Total-return series are derived later from sealed split-adjusted bars
plus sealed distribution facts, on the feature plane, not in the bars.

**The product serves two paths deliberately.** Quick path: bars in, run, no
ceremony, coverage explicitly absent. Rigorous path: facts, tiers, policy,
fidelity. Neither is a degraded version of the other and no user is locked out
of climbing.

**Competitor incompleteness does not lower the target.** Corrected after
final review. LEAN applies splits and cash dividends and liquidates a
disappearing holding at delisting, without establishing an atomic recipient
and basis transformation. Zipline holds the stronger partial primitive: a
stock dividend can create recipient shares from a payment asset and ratio,
though the visible ledger path increments quantity rather than expressing
parent reduction, a mixed cash leg and basis allocation. Backtrader commonly
consumes adjusted prices instead. The complete transformation is established
by none of them. That bounds the market gap; it does not change what ledgr
eventually owes.

## 5. Workstream

1. Land the compiled economic-event-envelope refusal. It has no ticket in any
   spec packet and blocks everything below it.
2. Canonical constructor, sealed family with provenance tiers, synthetic
   adapter, executable vignette.
3. Policy object, identity, fidelity field and ordinary summaries.
4. Gross `CASHFLOW` projection.
5. Canonical-R `DISPOSITION`, replay, interruption, resume, reopen.
6. Gate, then one independent workstream review.

The research default cannot change before strict mode, identity, fidelity and
ordinary reporting exist. No exact-quantity ticket enters this workstream.

## 6. Evidence Before Old Paths Leave

**[synthesis-only] The gate covers eleven cases, not ten.** Seed v7 capped at
ten and none of them exercises a published product claim: that the second rung
works. A cap is a discipline against speculative cases, not against testing a
claim the documentation makes.

1. a fictional non-Sharadar adapter producing the canonical fact shape;
2. dividend normalization across a later parent split;
3. distinct identified `next_open` and `effective_close` cash results;
4. current, permitted-stale and opt-in beyond-horizon marks with source age;
5. strict refusal versus research disposition on one held terminal;
6. no finite mark causing no mutation and no fabricated value;
7. interruption, resume, replay and reopen applying one disposition once;
8. `report_only` changing fidelity, omitted-value report and summary but no
   account state;
9. physical closure leaving membership, pre-event features and fills intact;
10. compiled execution refusing the economic-event envelope before running;
11. a bars-only run printing `not_supplied`, and a dividend-only run posting
    cash with no availability setup.

The upstream private gate separately reconciles the distribution population
and the corrected census without publishing identifiers, prices, action values
or suppressed cells.

## 7. Rejected, One Line Each

- One opaque `SETTLEMENT` row: cannot feed per-instrument position
  reconstruction, which every projection funnels through.
- Reusing opening-position operation 3: inserts lots, never consumes them, and
  realizes nothing.
- Partition by recipient location: answers valuation feasibility, not which
  lot operation an event needs.
- Mutation shape as the product boundary: blind to whether the amount is
  right, as withholding shows.
- Storing guessed legs for incomplete facts: manufactures evidence.
- A generic `settlement_policy`: equity assumptions would constrain crypto,
  futures and derivatives later.
- A universal cross-asset fact family: same reason.
- Unbounded `last_mark` as the default: the unexecuted option, and the
  hazardous one.
- Dynamic runtime axis growth: static preseal closure covered every observed
  case.
- Dividend-adjusted execution bars: not tradable prices, and retroactively
  mutable.
- Strict refusal only: multi-year walk-forwards halt and produce nothing.
- Cash distributions only: leaves the halting problem untouched.
- Broad decoupling of availability activation: the prerequisites are a real
  semantic dependency for terminal disposition.
- Exact quantity transformation in this release: scheduled under its own RFC.

## 8. Open Questions Promoted To Spec-Cut

- Constructor and preset argument spellings, beyond the two fidelity values
  whose wording is bound above.
- Summary layout and where the omitted-value figure sits.
- Whether the refusal-reason set is closed by enumeration or by validator.
- Whether the synthetic adapter ships in the package or in the vignette.

## 9. Future Obligations Recorded

- The exact-quantity RFC, already on the roadmap, owning atomic groups, parent
  consumption, recipient creation, mixed cash legs, model-basis transfer,
  fractions, off-axis valuation and compiled handling.
- A runnable probe for lifetime-only terminal disposition without sessions and
  a valuation policy, before any such capability is advertised.
- Total-return feature derivation from sealed bars plus sealed distributions.
- An `evidenced` fidelity state, once a release can exercise an effect with
  no configured convention, which requires complete source clocks.
- A new policy-value version wherever the exact-quantity release narrows what
  an existing value covers.

## 10. Failure Scenarios

- A held spin-off under `report_only` finishes with a downward-biased curve.
  Mitigated by the omitted-value report, not eliminated.
- A factor study at breadth returns `unsupported` on nearly every run, so the
  category stops informing. The magnitude, which varies, is the signal.
- A delisting with no qualifying mark refuses under the preset and the run
  stops. This is intended and is the price of not inventing a price.
- `equity_corporate_actions` is added to the activation families for
  consistency and the second rung silently disappears.

## 11. Release Boundary And Final Review

The release may claim: evidenced gross distributions, modeled terminal
disposition under a named convention, visible refusal, reproducible sealed
facts, and a fidelity signal over supplied facts. It may not claim
corporate-action completeness, broker-exact settlement, net cash, tax
correctness, exact recipient exposure, or that no unknown event existed.

Final review is Type 1 and belongs to Codex, which did not write this
synthesis. Its standing question applies with extra force here: the synthesis
author wrote every response, so the first thing to check is whether this
document merely transcribes those responses. The two `[synthesis-only]`
decisions are where to start, and the first of them was already refuted once.

## Revision History

- **2026-09-24** initial synthesis, after seed v7, response v7 and its
  addendum, and maintainer decisions of 2026-09-23 and 2026-09-24.
- **2026-09-24** patched after final review returned `NEEDS_TYPE_2`
  (`rfc_equity_settlement_post_v0_2_0_2_final_review.md`, Codex). Three
  findings, all upheld. The knob-lifecycle decision in 3.3 was refuted and
  replaced by scope versioning, which is the narrow Type 2 decision the review
  asked for and remains overridable by the maintainer. The `evidenced`
  fidelity state was unreachable and is dropped. The competitor claim in
  section 4 contradicted the 2026-09-24 horizon entry and is corrected. A
  fourth error the review did not raise is also fixed: the preamble claimed
  three synthesis-only decisions and marked two.
