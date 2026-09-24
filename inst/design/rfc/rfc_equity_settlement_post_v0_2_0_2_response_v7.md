# Type 2 Response v7: Usable Equity Corporate Actions

**Status:** Adversarial Type 2 product and architecture review, read-only.
**Author:** Claude. **Date:** 2026-09-24
**Reviews:** `rfc_equity_settlement_post_v0_2_0_2_seed_v7.md`

No licensed identifier, price or action value appears below.

## 1. Judgment

This is the first seed in the cycle that describes a product rather than a
mechanism, and the slice is the right one. Given the scheduling decision, the
alternatives are all worse, and I say why in section 4.

Two things must change before it ships, and both are small.

The zero-configuration preset ships the one option the spike did not execute,
and it is the more dangerous of the two. And the fidelity signal reports that
economics were omitted without reporting how much, which is the difference
between a research product and a run that finishes.

Neither is a redesign. Both are bindable in synthesis.

## 2. The two changes

### F1. The default is the unexecuted option, and it is the risky one

The preset selects `last_mark` for a held terminal: "the latest finite sealed
mark at or before the terminal event, even beyond the ordinary staleness
horizon." Section 5 concedes this "was not executed by the spike and must earn
its place in the release gate."

The spike executed `last_permissible`. It ran current and one-session-stale
marks, and it refused without a permissible mark rather than inventing a
price. That is the proven behaviour, and it is not the default.

The difference matters most where the default is most likely to fire. A
company delisted for bankruptcy stops trading long before its terminal event
is recorded. Its last finite sealed mark may be months old and far above any
recovery value. Selling the full position at that mark books a fictional gain,
credits fictional cash, and the run continues compounding on it. The staleness
horizon exists precisely to stop a mark that old from being treated as
information, and the preset suspends it for the single case where the
instrument is least likely to be worth its last price.

`last_permissible` fails differently and better. When no qualifying mark
exists it refuses, the run stops, and the user chooses. That is the behaviour
the maintainer asked to avoid, but the answer is to widen what counts as
permissible for a terminal event, with an age bound, not to remove the bound
entirely by default.

**Change:** the preset selects `last_permissible`. `last_mark` remains
available as an explicit opt-in, and the gate case for beyond-horizon marks
stays as written.

### F2. Fidelity reports that value was omitted, never how much

Section 6 is the best idea in the seed. A separate quality axis, monotone
severity, printed in the ordinary result rather than a specialist reader, with
zero printed as zero. I would keep all of it.

It stops one step short. The summary shows counts by choice, refusal reasons,
affected marked exposure, gross cash posted, positions disposed and
unsupported fact counts. None of that tells a researcher the size of what was
left out.

The held spin-off is the case that exposes it. The parent does not terminate,
so no disposition fires. Under `report_only` nothing happens to the account.
But the parent's price drops on the distribution date by roughly the value
that left with the child, and the child never arrives. The equity curve
absorbs a permanent loss that did not occur. This is not incompleteness. It is
a known error with a known sign, repeated for every held spin-off, compounding
for the rest of the run.

`unsupported` in the headline tells the user something is missing. It does not
tell them their returns are biased downward, and nothing in the summary lets
them size it. Affected marked exposure measures the parent, not the omission.

The fix is already sealed. Section 4.2 stores a validated recipient identity
and a normalized recipient quantity per parent unit. Multiplying that by the
recipient's mark at the effective session gives the omitted value directly. It
requires no position mutation, no lot transition, no group persistence and
nothing from the deferred RFC. It is arithmetic over facts the release already
holds, reported as a number rather than executed as an effect.

**Change:** the summary reports omitted recipient value, in currency and as a
share of affected exposure, whenever terms permit. Where terms do not permit
it, say so explicitly rather than printing nothing.

This also settles the machinery question. Storing recipient identity and
quantity that nothing consumes would be schema built for deferred work. Under
this change they are load-bearing in this release.

## 3. The evaluation questions

**Would the preset help or normalize wrong results?** It helps, with F1
applied. A run that finishes with a labelled approximation beats a run that
produces nothing, and the disposition approximation is usually good: an
acquired company's last traded price is close to the deal price because the
market prices it in. The exception is the delisting-without-a-bid case, which
is exactly what F1 guards.

**Is fidelity prominent and precise enough?** Prominent, yes. A headline word
in the ordinary result, not a warning in a specialist reader, is the right
placement and I cannot find a way to consume returns without meeting it. B2's
falsifier is the correct test. Precise, no, until F2 lands. A four-level word
is a category, and the user needs a magnitude.

**Does `report_only` produce a useful research product?** For a held spin-off,
not as written. It produces a completed run with a biased curve and no way to
size the bias. With F2 it becomes genuinely useful: the researcher can decide
whether the omission is material to their study, exclude affected names, or
wait for the follow-up RFC. That decision is the product.

**Is modeled terminal disposition defensible?** Yes, and the naming carries
most of the weight. A distinct `DISPOSITION` event that asserts no exchange,
broker, order, fee or executable trade is not a disguised liquidation, because
nothing about it claims a trade occurred. The spike showed it reuses the
production FIFO kernel and survives resume and reopen. The convention is
defensible as long as the mark is defensible, which returns to F1.

**Is the preparation contract realistic?** Mostly. Pinned action-type
validation, unit normalization and refusal states are ordinary adapter work.
Two parts are expensive and the vignette must be honest about both. Stable
recipient identity resolution needs an identity map across ticker changes, and
the corrected census could not resolve every recipient even with full vendor
data. Bar-vintage binding requires the adapter to know which bars the snapshot
sealed, which couples the adapter to snapshot construction more tightly than
the layering suggests. Teach refusal as a normal outcome, not a failure.

**Do the constructor, fictional adapter and vignette prevent lock-in?** The
fictional adapter is the real instrument, and B3's falsifier is the right one.
The requirement that it use different column names and codes and call no
Sharadar helper is what makes it a witness rather than a demo. This is the
strongest anti-lock-in device the cycle has produced.

**Do the public names preserve cross-asset routes?** Largely. Equity-specific
public surfaces over asset-neutral internal effects is the right split, and
B4's falsifier is well chosen. One leak: `DISPOSITION` is a ledger event type,
which is neither public API nor internal effect but shared schema, and section
7.2 gives its payload a "terminal subtype" field. Position removal at a mark
is a genuinely cross-asset concept and the event should stay that way. Keep
equity vocabulary in the policy and the fact family, out of the event payload.

## 4. The alternatives

**Strict refusal only.** Rejected by the maintainer, and independently worse:
multi-year walk-forwards halt at the first held terminal, producing nothing.

**Cash distributions only.** Fails the same way. A held terminal still stops
the run, so the usability problem is untouched while dividends improve. It is
smaller but it does not solve what this release exists to solve.

**Postpone the slice.** Leaves both problems standing and defers the vendor-
neutrality witness and the fidelity axis, which are the parts with value
independent of quantity settlement.

I would choose seed v7's scope. It is the only one of the four that makes an
ordinary multi-year run finish and say what it assumed.

## 5. Four users, and where it first fails

**Factor researcher.** Cross-sectional study, hundreds of names, many years.
Corporate actions are common at that breadth, so nearly every run returns
`unsupported`. **This is where the design first fails in daily use.** A
severity flag that is always on carries no information; it becomes a thing to
scroll past. The cost of living under it is that the user cannot tell a study
materially affected by omissions from one that is not. F2 is the fix, because
a magnitude varies between runs where a category does not.

**Long-term holder crossing a spin-off.** Worst served. Permanently biased
returns from the distribution date onward, currently unquantified. With F2 they
can at least see the size and decide.

**Adapter author.** Reaches the identity-resolution requirement and discovers
that refusal is not an edge case. Survivable if the vignette teaches it. Hits
real friction at bar-vintage binding, which needs coordination with whoever
builds the snapshot.

**Future derivatives maintainer.** In good shape, provided the `DISPOSITION`
payload stays asset-neutral. Option exercise and physical delivery both need
position removal at a mark, and inheriting that event is a gift rather than a
constraint, as long as no equity subtype is baked into it.

## 6. Would I ship and support it

With F1 and F2, yes. The claims are bounded correctly: no corporate-action
completeness, no broker-exact settlement, no net cash, no tax, no exact
recipient exposure, and the release explicitly may not call itself complete.
Section 10 owning the gap as scheduled work rather than an aspiration is what
makes the boundary supportable in a conversation with a user.

Without F2 I would not, because the first support question will be "how wrong
is my backtest" and the product cannot answer it while holding the terms that
would.

Conditions synthesis must bind: the preset selects the executed disposition
option; the summary reports omitted recipient value wherever terms permit; the
`DISPOSITION` payload carries no equity-specific subtype; and the vignette
teaches identity resolution and refusal as ordinary outcomes.

TYPE_2_DISPOSITION: PROCEED_TO_SYNTHESIS
