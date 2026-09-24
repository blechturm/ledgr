# Synthesis: Usable Equity Corporate Actions for v0.2.0.2

**Status:** Binding for v0.2.0.2 once accepted. Type 1 final review passed
at `065f3a3` (Codex, 2026-09-24) after two rounds. Awaiting maintainer
acceptance, then ticket cut with the compiled envelope guard first. See the
revision history.
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

**The transaction claim, twice.** Response v4 offered multi-row grouping with
atomicity coming free from "one transaction". Response v5 then found no
transaction on either writer, and that finding was itself wrong:
`R/backtest-runner.R:266` wraps the durable fold in `dbWithTransaction()`. I
proposed a property, charged the seed with failing to provide it, and was
mistaken about whether it existed. What survives is narrower and still true:
the memory handler has no equivalent, so the guarantee differs by handler.

**The product frame.** Responses v1 through v7 reviewed each seed against the
user it declared. Only after the maintainer stated the two-path constraint did
I consider the user with a free data export, who will be the more common one.
Every finding in the v7 addendum comes from that late shift.

**The competitor claim.** The first draft of this synthesis asserted that no
surveyed engine handles security distributions. The 2026-09-24 horizon entry,
which I had read, records that zipline can create recipient shares from a
stock dividend. I generalised a real gap into a false absolute. Section 4
carries the correction.

**The compensation claim.** Patching after the first external review I wrote
that a disposed holder "was compensated" so nothing was omitted. Modeled cash
is not the consideration. If the real consideration is successor shares worth
more or less than the modeled proceeds, the difference is real and so is the
divergent path afterwards. Section 3.5 now reports four quantities instead of
one verdict.

**The entitlement rule.** I proposed fixing entitlement at the effective
date's decision point. In a close-decision workflow that falls after trading
on the ex-dividend date, so it would credit a buyer who is not entitled and
deny a seller who is. Exactly inverted. Section 3.4 carries the correct rule.

The cycle ran seven seeds. Two were caused by measurements contradicting
belief, which is the system working. Four were caused by my errors.

## 2. Decision

v0.2.0.2 ships one equity corporate-action slice: sealed vendor-neutral facts,
evidenced gross cash distributions, modeled terminal disposition, explicit
refusal, and a headline fidelity signal. It does not transform parent holdings
into recipient holdings, and it may not describe itself as corporate-action
complete.

The release exists because a multi-year walk-forward that halts at the first
held terminal cannot answer the full-horizon portfolio question it was run to
answer. Its partial output is still evidence; completion under a declared
convention is not by itself a methodological improvement. It exists also
because omitted distributions are the largest systematic economic error in
the package for equity research.

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
Both validate and both are sealed, so both are reproducible.

The tier records provenance strength. It is not a capability gate. What exact
quantity transformation will require is demonstrable consistency between event
terms, price units and quantity units; a named upstream build is one way to
establish that, neither proof on its own nor the only route. The
exact-quantity RFC states its own evidence requirement. Using the label as a
premature gate would recreate the vendor-infrastructure lock-out the v7
addendum removed, one level higher.

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
| cash posting | `effective_close` | `next_open`, `refuse` |
| held terminal position | `last_permissible` | `last_mark`, `refuse` |
| unsupported quantity event | `report_only` | `refuse` |

**The preset selects `last_permissible`.** The terminal-disposition spike
executed that option and refused without a qualifying mark. Unbounded
`last_mark` was not executed, and it suspends the staleness horizon for the
one case where an instrument is least likely to be worth its last price. This
repository's own prior-art review calls stale-price liquidation hazardous in
zipline; the default must not reproduce it. `last_mark` remains available as
explicit opt-in and keeps its gate case.

It bounds staleness, not error. A recent mark can still be a poor settlement
proxy, and nothing here validates recovery value. It is a declared research
convention, which is why modeled terminal proceeds must appear as a figure in
ordinary results rather than only as a count of dispositions.

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

**Entitlement is fixed before the boundary and never recomputed.** For a
supported ordinary cash dividend, the entitled quantity is the eligible
holding immediately before the ex-dividend boundary. That boundary comes from
the supplied and validated entitlement clock. It is not derived from a generic
corporate-action effective date, and a subtype whose entitlement rule differs
needs its own supported interpretation or a refusal.

Posting happens later under the selected convention and retains the entitled
quantity even if the position has since changed. A holder who sells on the
ex-date keeps the distribution; a buyer on the ex-date does not receive one.
Knowledge timing stays separate: a fact learned after the boundary may not
retroactively influence an earlier decision.

**Recognition versus spendable cash: maintainer decision, 2026-09-24.**
Between the entitlement boundary and posting, the portfolio owns something it
cannot spend. Three options were costed: a receivable in equity, which is
economically cleanest but adds a third term to the equity identity and touches
every result surface; posting at the ex-dividend close, which removes the
missing-asset dip at no structural cost; and delayed posting with no
receivable, which leaves one pulse of understated equity and was never
acceptable.

The maintainer accepted the second: `effective_close` is the research preset
for this release, with its early-cash assumption disclosed. Receivables and
actual payment-date handling remain future work. The decision is the
maintainer's, not inherited from seed v7 and not the reviewer's or the
synthesis author's, both of whom recommended it.

Two reasons beyond cost. Reliable historical payment dates are not a
prerequisite anyone should have to meet to use ledgr, and it is not a given
that vendor data supplies them at all. And a vendor that does supply a payment
date has not thereby established when that date became knowable; a supplied
clock is a fact, and an assumed one must never be presented as observed.

Posting at the close is still an approximation and must be disclosed as one.
It removes the dip. It also makes cash spendable at the ex-date close, which
may precede actual payment, so reinvestment timing is optimistic. That is the
assumed cash timing the result and the vignette state. The trigger for
implementing a receivable is research that depends materially on precisely
when cash becomes spendable.

The bound rules for a supported ordinary dividend under `effective_close`:

1. `effective_close` means the ex-dividend session's close, taken from the
   validated entitlement clock, never an unspecified corporate-action
   effective date.
2. The entitled quantity is fixed immediately before the ex-dividend boundary
   and is not recomputed at posting.
3. The amount is credited before that pulse's equity and strategy context are
   computed, so the dropped price and the cash land together.
4. The fact and every term the posting needs must be knowable by that cutoff
   under the declared knowledge policy.
5. A fact known only after the cutoff is never silently backdated. It posts at
   the first pulse at or after its knowledge time, with the entitled quantity
   still fixed at the original boundary, and the late arrival is counted in
   the fidelity summary. The one-pulse claim above assumes timely knowledge
   and does not cover this case.
6. Fidelity is `modeled`, and the summary names the assumed cash timing.
7. `next_open` remains an explicit alternative with its equity-timing
   limitation documented: one pulse in which the price has dropped and the
   cash has not arrived.

**Modeled terminal disposition** consumes live lots at the selected evidenced
mark under canonical FIFO, realizes model PnL, removes the position and moves
cash. It persists `DISPOSITION`, not `FILL`: no exchange, broker, order, fee
or executable trade is asserted.

**The payload carries no equity or vendor subtype.** Those live in the source
fact and the policy. What `DISPOSITION` means in this release is bounded to
that: remove a position at a stated mark, realize model PnL, move cash. It is
not promised as the event option exercise or physical delivery will inherit.
Those involve strike payments, delivery and linked positions whose economics
nobody has designed, and a future operation may reuse these mechanics where
they fit without being constrained by a promise made in their absence.

**Unsupported quantity effects** change no account state under `report_only`
and raise fidelity to `unsupported`. Strict mode stops when the affected
parent is held.

**Composition is bound, because one transaction can raise both.** A stock
acquisition supplies a terminal fact and a quantity fact for the same economic
event. Without a rule the preset both disposes the holding and reports its
recipient value as omitted.

| Case | Account effect | Fidelity | Reported |
| --- | --- | --- | --- |
| Cash acquisition | Disposition at mark | `modeled` | Modeled proceeds; contractual cash where supplied, and the difference |
| Stock acquisition | Disposition at mark | `unsupported` | All four quantities in 3.5; successor exposure not represented |
| Mixed acquisition | Disposition at mark | `unsupported` | As stock acquisition, with the cash leg named separately |
| Spin-off, parent survives | None | `unsupported` | Omitted child value only; no compensating cash exists |

One source-fact identity governs the whole transaction and prevents a supplied
cash leg from being credited alongside modeled disposition proceeds for the
same event. Double crediting is a validation failure, not a rounding concern.
Fidelity is `unsupported` whenever a security leg went unrepresented, even
though a modeled cash exit occurred, because the portfolio does not hold what
the transaction delivered.

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

**Omitted value is reported as four quantities, not one.** Reporting a single
number was wrong: for an acquisition the holder received modeled cash, so the
recipient value is not an uncompensated loss, and for a spin-off it is.

Where terms permit, the summary reports:

- modeled cash credited;
- estimated contractual consideration, in consistent units and one currency:
  entitled parent quantity times the sum of cash per parent unit and the
  normalized recipient ratio times a named recipient mark at a named
  timestamp. A formula covering only the security leg understates a mixed
  acquisition; the mixed case in gate 13 exercises both legs;
- the difference between them at a common valuation timestamp; and
- successor exposure not represented.

Each is labelled an effective-date estimate and explicitly not the eventual
return bias, because value at distribution is not what holding the successor
would have earned. Any quantity whose required observation does not exist
reports `unavailable` rather than nothing or zero.

The estimate is retrospective reporting. It is never visible to the strategy
and never enters a decision.

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

The first vignette is small and demonstrates the quick path rather than
asserting it: one dividend under the research preset, its result, its stated
limitation, then the same case under strict refusal. Nothing else.

Adapter authoring, provenance tiers, physical-axis closure and the
private-to-canonical boundary belong in a second article, using fictional
vendor data to teach headers, terms, keys, clocks, units and refusal states.
That article teaches identity resolution and refusal as ordinary outcomes
rather than failures, because the census could not resolve every recipient
even with full vendor data.

A synthetic adapter with different source column names and codes must build
the same canonical facts and pass the same validator, calling no Sharadar
helper and reproducing no Sharadar formula. This is the vendor-neutrality
witness and it is a release deliverable, not documentation.

The constructor and validator are the authority; the vignette is executable
teaching that cannot drift independently.

## 4. Open Decisions Resolved

**The supported price basis is split-adjusted, and distribution-adjusted bars
are not admitted.** The first draft said "adjusted prices are not sealed",
which prohibited this design's own canonical input. Split-adjusted bars with
consistently normalized quantities are the basis; bars that already
incorporate distributions are not.

The reason is not mutability. Sealing a vintage preserves reproducibility
whatever the vendor does afterwards. The reasons are that a
distribution-adjusted price is not a price anyone could trade at, so cash,
basis and affordability are corrupted while returns stay roughly right, and
that such a series already contains the distributions.

That second reason is a trap on the quick path. A user whose bars already
include distributions, who later supplies distribution facts, counts them
twice. The release must detect the combination where it can, from the declared
price basis on the bars, and refuse or declare it where it cannot. Silent
double counting is the worst available outcome.

Total-return series are derived later from sealed split-adjusted bars plus
sealed distribution facts, on the feature plane, not in the bars.

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

**[synthesis-only] The gate covers fourteen cases, not ten.** Seed v7 capped
at ten. A cap is a discipline against speculative cases, not against testing
claims the product makes. Four are added: the second rung of the ladder,
dividend entitlement, acquisition composition, and the real disposition event
under interruption on both handlers.

Ordering makes several cases material and the gate asserts against it. Per
pulse the fold reads positions for valuation at `R/fold-engine.R:458`, builds
the strategy context at `:506`, runs the strategy, and applies the fills that
decision produces at the next pulse at `:882`. So under `effective_close` the
credited cash must be in state before line 458, and entitlement must be fixed
before boundary fills land. A case that only checks the eventual cash balance
cannot see either.

1. a fictional non-Sharadar adapter producing the canonical fact shape;
2. dividend normalization across a later parent split;
3. table-driven posting: one dividend under `effective_close` and under
   `next_open`, asserting the exact cash, equity and strategy-context values
   at the ex-date pulse and the following pulse, so that cash posted after
   the strategy has run, or after valuation, fails the case;
4. current, permitted-stale and opt-in beyond-horizon marks with source age;
5. strict refusal versus research disposition on one held terminal;
6. no finite mark causing no mutation and no fabricated value;
7. interruption, resume, replay and reopen applying one disposition once;
8. `report_only` changing fidelity, omitted-value report and summary but no
   account state;
9. physical closure leaving membership, pre-event features and fills intact;
10. compiled execution refusing the economic-event envelope before running;
11. a bars-only run printing `not_supplied`, and a dividend-only run posting
    cash with no availability setup;
12. table-driven entitlement with the entitlement clock and the generic
    effective clock set to different sessions: an existing holder selling on
    the ex-date and a new buyer entering on it, where only the seller is
    credited and only if the entitlement clock is used; plus one fact whose
    knowledge time falls after the cutoff, which posts at the first eligible
    pulse with the pre-boundary quantity, is not backdated, and appears in the
    fidelity summary's late-arrival count;
13. a four-row composition witness, one row per case in the 3.4 table: cash
    acquisition, stock acquisition, mixed acquisition with both legs nonzero,
    and spin-off with the parent surviving. Each row asserts the exact event
    count, the exact final cash proving no supplied leg was credited beside
    modeled proceeds, the fidelity value, and the four reported quantities
    reconciled numerically to the formula in 3.5 including sign, ratio,
    common timestamp and total. Presence of a field is not an assertion; and
14. the real `DISPOSITION` event through replay, results and reopen on the
    durable handler, with interruption occurring after a disposition is
    recorded and resume applying it once, compared against an uninterrupted
    control; and, on the memory handler, failure injected after the
    disposition has entered the memory buffer, asserting a failed candidate
    with no final equity and no retained artifacts and an unaffected sibling
    candidate. No memory reopen or rollback guarantee is added; the memory
    handler's transaction is a passthrough at `R/sweep.R:1670` by design.

Case 14 exists because the terminal-disposition spike wrote a `FILL` with side
`SELL`, which the current preparer accepts and `DISPOSITION` is not. The spike
established sale mechanics, not this event. Its interruption also fired before
the terminal pulse, so recovery after a recorded disposition is unproven. The
durable half is well founded: the fold is transactional at
`R/backtest-runner.R:265`, accounting precedes persisted strategy state at
`R/fold-engine.R:957`, and resume restarts after the last state and deletes
only the replaceable tail at `R/run-resume.R:53`. The memory half is a
different guarantee, not a weaker version of the same one.

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
- Distribution-adjusted execution bars: not tradable prices, and they already
  contain the distributions.
- Strict refusal only: a multi-year walk-forward halts before it can answer
  the full-horizon question it was run for.
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
- A distribution receivable in equity with payment-date handling, deferred by
  the posting decision in 3.4. Its trigger is research that depends materially
  on when cash becomes spendable, and its data requirement is a payment clock
  whose own knowledge time is established, not merely supplied.
- The evidence requirement for exact quantity transformation, stated by that
  RFC rather than pre-empted by a provenance label here.

## 10. Failure Scenarios

- A held spin-off under `report_only` finishes with a downward-biased curve.
  Mitigated by the omitted-value report, not eliminated.
- A factor study at breadth returns `unsupported` on nearly every run, so the
  category stops informing. The magnitude, which varies, is the signal.
- A delisting with no qualifying mark refuses under the preset and the run
  stops. This is intended and is the price of not inventing a price.
- `equity_corporate_actions` is added to the activation families for
  consistency and the second rung silently disappears.
- A quick-path user supplies distribution facts over bars that already include
  them and the run double counts undetected.
- A supplied cash leg is credited alongside modeled disposition proceeds for
  one acquisition.

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
- **2026-09-24** patched after an external product review of the pushed branch
  at `485905d`. Six findings and two product points, all upheld. Dividend
  entitlement is now bound to the ex-dividend boundary rather than the
  effective date's decision point, which was inverted. Acquisition composition
  is bound in a table and the omitted-value report becomes four quantities,
  because calling a disposed holder compensated was too strong. The
  adjusted-price decision no longer prohibits this design's own split-adjusted
  input and now requires double-counting detection. The provenance tier stops
  gating future capability. `DISPOSITION` is bounded to this release rather
  than promised to option exercise and physical delivery. The gate grows to
  fourteen cases. Recognition versus spendable cash is raised as a maintainer
  decision rather than inherited from seed v7. Two further errors of mine are
  recorded in section 1: response v5 was wrong that no writer has a
  transaction, and the compensation claim was mine.
- **2026-09-24** patched after the second external product review, of
  `7e1283d`. The posting decision is drafted: `effective_close` becomes the
  research preset with seven bound rules including a late-knowledge rule, the
  receivable is deferred, and the earlier claim of "no artifact at all" is
  corrected to a disclosed cash-timing approximation. The contractual
  consideration formula in 3.5 gains the cash leg it was missing for mixed
  acquisitions. Two superseded arguments still repeated in section 7 are
  removed. Gate case 14 is scoped to durable reopen plus memory-handler
  failure containment so it cannot quietly require durable recovery of memory
  sweeps.
- **2026-09-24** maintainer accepted `effective_close` as the research preset
  with its early-cash assumption disclosed, receivables and payment-date
  handling deferred. Recorded in 3.4 with the maintainer's own reasoning that
  reliable payment dates cannot be a prerequisite and a supplied date does not
  establish its own knowability. Two edits from the third external review, of
  `6c05ad2`: gate 13 now specifies a mixed acquisition with both legs nonzero,
  since a stock-only case could pass while the formula omitted the cash leg;
  and "earlier than any real payment" becomes "may precede actual payment".
- **2026-09-24** patched after the second Type 1 final review (Codex,
  `CHANGES_REQUIRED`, concurred by the external reviewer). The economics were
  found sound; section 6 was not failure-sensitive for all of it. Cases 3 and
  12 become table-driven with distinct entitlement and effective clocks, exact
  pulse-level cash, equity and context values, and a late-known fact. Case 13
  becomes a four-row composition witness with numerical reconciliation to the
  3.5 formula, exact event counts and final cash. Case 14's memory half names
  its failure point and observables. The per-pulse ordering the gate depends
  on is cited in the section preamble. All nine code citations in the review
  were verified before patching.
- **2026-09-24** Type 1 final review of the focused diff `a874776..065f3a3`
  returned `PASS` (Codex). All three findings resolved; accepted economics
  unchanged; only the synthesis changed. The review verifies the checks the
  document binds, not that unimplemented behaviour has passed executable
  tests. No further synthesis revision required.
