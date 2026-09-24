# Type 2 Response v3: Equity Settlement After v0.2.0.2

**Status:** Third adversarial Type 2 review, read-only. Binds nothing.
**Author:** Claude. **Date:** 2026-09-23
**Reviews:** `rfc_equity_settlement_post_v0_2_0_2_seed_v3.md`

No licensed identifier, price or action value appears below.

## 1. Verdict

v3's direction is right and its release boundary is defensible. Two things
are wrong, and both are the kind that get expensive rather than the kind
that get argued.

It freezes a schema for semantics it explicitly refuses to design. And its
single gate cannot detect the one error that would make the release
economically misleading, because no case in it tests the only decision that
matters for a dividend.

Neither needs another full cycle. Both are small, named edits below.

## 2. My bias, stated

v3's primary partition is my addendum's proposal, adopted close to whole.
Section 3 is my two-dimension argument with the valuation dimension demoted
to Class C. I am therefore the worst available judge of whether that
partition is correct, and it is the part of v3 that no independent party has
ever challenged. I challenge it in F3 rather than leave it standing on my
own say-so.

Codex did not merely transcribe it. Three things in v3 are its own and are
improvements. The validate-before-append rule in section 8 is derived from
the spike's prefix result and is not in my addendum. The refusal to choose
serialization in section 7 is a better instinct than my addendum showed.
Denying settlement the `opening_position` discriminator is the correct
response to the duplicated-classifier finding, which I had filed as a side
observation rather than a constraint.

Where I judged v3 against my own framing I have said so.

## 3. What v3 gets right

**The retirements are correct and completely stated.** Cash-only is not a
release class, operation 3 is not a settlement primitive, and mid-fold
emission alone does not justify a new event type. All three follow from the
evidence rather than from the loudest reviewer.

**Class B is rightly deferred whole.** The brief invited me to argue for a
positive-insertion subset, on the grounds that spike cases 4 and 9 showed
insertion works and survives resume. I cannot make that argument honestly.
Every positive insertion in this population is a spin-off or stock
distribution leg, and each splits an existing basis rather than adding one.
Inserting a child without reducing its parent overstates total cost and
understates every later realized gain. There is no subset where insertion
alone is economically true. v3 is right and the invitation is refused.

**Declining to name the future serialization is discipline, not deferral.**
Section 7 makes the ordering explicit: demonstrate consumption,
reallocation and rollback, then choose how to serialize them. A name chosen
before the semantics exist constrains the semantics to fit the name. The
brief asks whether the fact compiler already depends on that choice. It does
not. The compiler only needs to know that Class B emits nothing, which is a
classification outcome and not an event shape.

**Class A's product value is real.** Omitted dividends are the largest
systematic economic error in the package for equity research, they compound,
and they bias every long-horizon result in the same direction. This is not a
token release.

## 4. Findings

### F1. The schema is frozen for semantics v3 refuses to design

Section 5 commits the fact family to store Class A, B and C, and justifies
it so that "a later lot-settlement design must not require the source
evidence to be resealed merely because its account projection changes."

The argument only works if the later design's needs are known. v3 says
twice that they are not. Section 7 declines to decide whether the future
operation is a new event type or a validated group. Section 13 says the seed
does not design the future lot operation.

So the recipient identities, recipient quantity legs, recipient bar
references and transformation-policy identity are fields shaped by guessing
at a design that is explicitly unspecified. Guessed fields are resealed when
the guess turns out wrong, except that by then they hold data.

Count what Class A actually consumes from that list. It has no recipient, no
recipient quantity leg and no recipient bar reference. The majority of the
schema cost in this release buys storage for effects that emit nothing.

The anti-reseal argument also assumes a reseal is expensive. This is a
pre-release package with no consumers, where the maintainer's standing
position is that contracts break freely. What is genuinely expensive is the
hash rule version, migration, seal and compilation work, and v3's approach
pays that twice anyway: once now on guessed fields, once again when the lot
design arrives and the guesses do not fit.

**The smaller version.** Store identity, clocks, subtype and classification
for every recognized fact, and terms only for the class that acts on them.
A Class B fact is then recognized, classified and refused without its ratio
or its recipient legs being sealed. Section 8's requirement that a
recognized event is never represented as absent is satisfied by
classification, not by term storage. Terms matter when something will act on
them.

### F2. The gate cannot see the only error that matters

Section 10's eight cases test normalization, vintage, misclassification,
replay, prefix and the compiled arm. Not one tests when an admitted
distribution posts.

A real dividend has an ex-date and a payment date weeks apart. The census
established that this vendor supplies the first and not the second. So every
admitted Class A fact will post under a modeled convention, and section 6
permits exactly that: a named convention whose unavailable claim is
reported.

Every one of the eight cases can pass while that convention is wrong. The
release would then ship dividends that post on a date no holder received
them, with identity, normalization, atomicity and replay all verified. That
is a gate that certifies the machinery around a number without ever looking
at the number.

The brief asks whether the single gate is one coherent decision or an
oversized bundle. It is neither. It is a bundle, and it has a hole where its
only economic question should be.

**The smaller version.** Add one case: the same distribution under two
declared posting conventions must produce two different, correctly labelled
results, and a fact whose convention is unstated must not be admitted.

### F3. Mutation shape is the right feasibility axis and the wrong product axis

This attacks my own contribution, and it is where I think I was half wrong.

Mutation shape answers what an event does to the books. It is objective,
checkable in code, and it correctly predicted which events ledgr can
currently express. As a feasibility partition it survives.

It is blind to whether the amount is right. Withholding is the clean
demonstration. A dividend net of withholding is still additive cash with no
position, lot, basis or realization effect, so it satisfies the Class A
predicate exactly. The amount is simply wrong for any holder the vendor's
gross figure does not describe. v3 does not mention withholding anywhere,
and its partition is structurally incapable of noticing.

The same blindness admits any timing error, which is F2 restated from the
other side.

The honest primary question for a *product* boundary is whether the terms
are evidenced well enough to post under a stated policy. Mutation shape is
then the derived explanation of why something is not, which is what it is
good at.

The brief asks whether "additive cash distribution" is a stable boundary or
another temporary label. It is stable as a statement about the ledger. It is
not a statement about economic correctness, and v3 presents it as both.

### F4. The prerequisite is honest and still load-bearing

Section 9 is better than v2 on this: it names the compiled envelope guard as
unowned and says accepting the seed does not make it landed. That is candid.

It is still the case that gate case 8 requires the guard's behavior. A gate
that cannot run until unowned work lands is a schedule dependency whether or
not the RFC absorbs it. Say so in the sequence rather than leaving it to be
discovered when the gate is run.

## 5. The smaller alternative

Subtract the taxonomy from the release and keep it as vocabulary.

One admission predicate: is this fact postable as cash under a named policy,
with its unavailable claims reported? A fact that passes is admitted and
compiles to one `CASHFLOW`. A fact that fails is retained with a reason, and
the reasons are v3's section 8 list including "requires lot or basis
mutation."

What this removes: the three-class table as a release structure, the B and C
term fields from the sealed schema, and the section 3 argument about
recipient location, which is a valuation matter with no bearing on what
v0.2.0.2 ships.

What this keeps unchanged: upstream normalization, bar-vintage binding,
policy identity in experiment identity, validate-before-append, the closed
model-basis rule for later, off-axis deferral, and the refusal to name a
future event type.

The difference is that the policy decision is forced to the front. Under
v3 a fact is admitted because of its shape and then a convention is chosen
for it. Under this it is admitted because a stated convention covers it,
which is the same set of facts reached through the question that can
actually be got wrong.

## 6. Both designs through the damaging cases

| Case | v3 | Alternative |
| --- | --- | --- |
| 1. Dividend, ex and pay differ | Admitted; convention unchosen and untested | Admitted only under a named convention, or refused |
| 2. Cash acquisition extinguishing parent | Refused, Class B. Correct | Refused, terms not postable as cash. Correct |
| 3. Return of capital, basis not quantity | Refused, Class B. Correct | Refused. Correct |
| 4. Positive on-axis spin-off leg | Refused, Class B. Correct | Refused. Correct |
| 5. Malformed second effect | No prefix, per section 8 | Same rule, unchanged |
| 6. Interruption and resume at posting | Covered by gate case 6 | Same |
| 7. Wrong bar vintage | Refused by the vintage binding | Same |
| 8. Compiled arm | Gate case 8, blocked on unowned guard | Same dependency, stated in the sequence |

The two designs differ on one row. Cases 2 through 8 are v3's and I am not
improving them.

## 7. Where my alternative fails

Its classification vocabulary becomes policy-dependent. Changing the posting
convention changes which facts are supported, which moves experiment
identity for a reason that reads as a policy tweak rather than a scope
change. v3's shape-based classes do not have that problem, and a user
reading two runs with different supported sets will find v3's version easier
to explain.

It also gives no structured home for the terms of a refused fact. If someone
later wants to audit what was refused and on what evidence, v3's family can
answer and mine cannot without a reseal. I judge that a fair trade because
the later design is unspecified, but it is a real loss and not a free one.

And it concentrates more weight on a single policy decision that nobody has
yet made. If that decision is made badly, my version has less structure
around it to contain the damage.

## 8. Recommended revision

Two edits, both small. This is the fourth seed round, so I have deliberately
made them nameable rather than directional.

1. Narrow section 5. Seal terms for the class that acts on them. Recognize
   and classify the others without sealing their terms. Drop the anti-reseal
   justification, which cannot hold while section 7 and section 13 decline to
   specify what a later reseal would need.
2. Add one case to section 10. The same distribution under two declared
   posting conventions produces two different labelled results, and an
   unstated convention is not admissible.

F3 is an argument, not an instruction. If Codex can defend mutation shape as
a product boundary against the withholding case, I will withdraw it.

If the maintainer judges these smaller than another round is worth, overrule
this disposition and carry both into synthesis as bound conditions. I would
not argue.

TYPE_2_DISPOSITION: REVISE_SEED
