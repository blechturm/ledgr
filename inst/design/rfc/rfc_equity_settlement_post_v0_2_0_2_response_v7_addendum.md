# Addendum to Type 2 Response v7: The Two-Path Product

**Status:** Addendum, read-only. Binds nothing.
**Author:** Claude. **Date:** 2026-09-24
**Extends:** `rfc_equity_settlement_post_v0_2_0_2_response_v7.md`
**Occasioned by:** two maintainer product constraints stated after that review.

## 1. Why this is separate

Response v7 reviewed seed v7 against the user it was written for: someone
with a licensed vendor, a real adapter, and the ability to bind a bar vintage.
The maintainer has since stated two constraints that describe a different
user, and they change what the design has to support.

The constraints, as given:

1. A quick path must stay quick. Someone with a Yahoo export or a random
   crypto exchange dump must be able to run a throwaway strategy, with a
   documented route to "as right as possible" for those who want it.
2. No user may be permanently locked out of the rigorous path because the
   vendor they chose cannot produce some required input.

Both are reasonable and neither was in the review's frame. The findings below
follow from them. The disposition does not change.

## 2. F1. The fidelity ladder has one word for two states

Section 6 defines `none` as "no supplied fact affected a held instrument". A
user who supplied no corporate-action facts at all also lands on `none`.

Those are opposite messages. Facts supplied and none applicable means the
period was genuinely quiet. No facts supplied means the returns are price-only
and dividends are missing. For a ten-year buy-and-hold on a free data export,
which is the archetypal quick-path run, `none` will print and read as
reassurance.

This will be the most common value the field ever takes, produced by the path
it was not designed for, and it is the one case where it says something
comforting and wrong. The seed guards it in prose, requiring that the field
not claim source completeness, but the printed word carries no such caveat.

**Change:** a distinct value for no corporate-action facts supplied, ranked
outside the evidenced ladder rather than at its clean end, whose printed form
says that distributions are not represented.

## 3. F2. The fact header demands provenance a weak vendor cannot produce

Section 4.2 requires every fact header to carry build and bar-vintage identity
and a normalization-policy identity. The clocks are qualified as "when
supplied"; these are not.

A Yahoo user has an amount and a date. A crypto exchange export has less.
Neither can bind a vintage against a sealed canonical build, because their
source has no such concept. So neither can construct a dividend fact that
passes validation, and neither can ever climb past the quick path.

That is constraint 2 violated by the fact schema itself.

**Change:** make provenance a declared level rather than a precondition. A
fact states either that it was normalized against a named sealed build, or
that it is user-supplied with no vintage binding. Both validate. The second
reports at lower fidelity and is ineligible for later work that genuinely
requires vintage, exact quantity transformation above all. Rigour stays
available to those who can reach it; nobody is barred from the first rung.

## 4. F3. The rungs do not exist in the code

This is the largest of the three and it is not a seed defect. It is existing
behavior that blocks the product the constraints describe.

The intended ladder is bars, then dividends, then lifetime facts unlocking
terminal disposition, then membership, then normalized terms. Each rung
reachable on its own.

The code offers one bundled step. `ledgr_availability_activation()` in
`R/availability-policy.R` sets `active` when **any** of membership, sessions,
trading status or lifetime is declared, or when a valuation policy is passed.
`ledgr_availability_validate_experiment()` then aborts with
`ledgr_availability_sessions_required` unless a complete declared session
calendar exists, and with `ledgr_valuation_policy_required` unless a staleness
policy is supplied.

So a user who declares only lifetime facts, wanting nothing but an honest
terminal disposition for a delisted holding, is immediately required to supply
a complete session calendar and choose a staleness horizon. There is no rung.
There is a cliff.

This bites the quick path hardest and crypto worst, since a complete declared
session calendar for a continuous market is an awkward artifact to demand from
someone who wanted a delisting handled.

Terminal disposition is reachable only through `availability_view`, which
exists only when the provider is active (`R/fold-engine.R:239-240, 385-390`).
So the seed's headline capability is gated behind the whole apparatus.

**Change:** synthesis must decide whether decoupling activation is in scope.
If it is, declaring one family must not compel the others, and the required
session calendar and valuation policy must attach to the capabilities that
actually need them. If it is not, the release should say plainly that terminal
disposition requires availability-aware setup, rather than implying a ladder
that is not there.

## 5. What this does to the review

Response v7's conditions stand: the preset selects the executed disposition
option, the summary reports omitted recipient value, the `DISPOSITION` payload
stays asset-neutral, and the vignette teaches identity resolution and refusal
as ordinary outcomes.

Three are added: a distinct unsupplied fidelity state, declared provenance
levels in the fact header, and a decision on activation coupling.

F1 and F2 are ordinary synthesis binds. F3 may not be, because it changes
behavior this RFC did not introduce and that other work depends on. It is a
routing question for the maintainer, not something a Type 2 response should
resolve.

## 6. Why the review missed these

Not because the constraints were unstated, but because I reviewed the seed
against its own declared user and did not ask who else would run it. The
quick-path user is the more common one, and every finding here comes from
taking that user seriously for the first time in the cycle.

The disposition is unchanged.

TYPE_2_DISPOSITION: PROCEED_TO_SYNTHESIS
