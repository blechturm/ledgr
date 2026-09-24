# Final Review: Usable Equity Corporate Actions for v0.2.0.2

**Status:** Type 1 final review.
**Reviewer:** Codex.
**Date:** 2026-09-24.
**Reviews:** `rfc_equity_settlement_post_v0_2_0_2_synthesis.md`.

## Verdict

The synthesis is faithful on the release boundary, producer/runtime split,
policy default, provenance levels, availability-aware disposition scope,
fidelity disclosure and exact-quantity deferral. It is not ready to accept
because one synthesis-only design decision is unsound. Under the accepted RFC
rules, a design concern found in Type 1 returns to Type 2 rather than being
silently patched by the verifier.

## Blocking Design Finding

### D1. The temporary policy-knob classification is false

Section 3.3 says the unsupported-quantity knob is a temporary capability
frontier that "must disappear" when exact quantity settlement lands. That
does not follow from the accepted direction.

The same synthesis requires incomplete facts to retain a refusal reason and
carry no guessed leg (section 3.2), preserves `report_only` versus `refuse`
for unsupported quantity effects (sections 3.3 and 3.4), and rejects guessed
legs (section 7). Exact settlement can make currently supported facts
executable. It cannot make incomplete, contradictory, unknown or future
quantity effects disappear. Those cases still require the policy choice.

The lifecycle marker therefore schedules a future identity and API removal
for a condition that remains permanent. It also adds a second policy taxonomy
that neither Seed v7 nor either Type 2 response proposed or challenged.

Smallest sound resolution: remove the lifecycle-marker decision and the
obligation to remove the knob. Exact-quantity support should shrink the set of
facts reaching `unsupported quantity event`; it should not erase the policy
for facts that remain unsupported. If the marker and planned removal are to
stay, they need an actual Type 2 argument and failure scenarios first.

## Type 1 Corrections

### F1. The competitor sentence is false

Section 4 says, "No surveyed engine handles security distributions." The
repository's own prior-art research says Zipline pays stock dividends by
adding recipient shares (`Cross-Asset-Accounting-Critical-Events.md:67`).
The synthesis elsewhere correctly distinguishes that partial primitive from
atomic parent reduction, mixed cash and basis allocation.

Replace the sentence with the narrower supported claim: no surveyed engine
establishes the complete atomic transformation required by ledgr. This is a
factual correction, not a reason to change scope.

### F2. `evidenced` has no reachable release behavior

The release implements gross cash under a configured posting convention and
modeled disposition; both raise fidelity to `modeled`. Quantity effects are
either `unsupported` or refused. With no affected fact the value is `none`,
and without supplied facts it is `not_supplied`.

Section 3.5 does not name any v0.2.0.2 effect that can produce `evidenced`.
Either define the exact reachable condition, with a gate witness, or reserve
the value for the later exact-quantity RFC instead of shipping a dead state.

## Synthesis-Only Decisions Checked

- The eleven-case gate has a defensible reason: its added case detects the
  published bars-plus-simple-facts rung and the activation exclusion. It does
  not need a new mechanism. The author may combine it with the fictional
  adapter case to retain ten, but the extra case is not a correctness defect.
- The activation exclusion is accurate and narrowly scoped. Current code
  activates only on membership, sessions, trading status, lifetime or an
  explicit valuation policy (`R/availability-policy.R:93-104`). The synthesis
  retains the real session and staleness prerequisites for terminal
  disposition rather than weakening missing-bar semantics.

## Other Verification

- The quantity-primitive, axis-density and terminal-disposition closeouts are
  RED, scoped GREEN and GREEN respectively, matching section 1 and the header.
- The terminal spike executed `last_permissible`, including current, allowed
  stale and no-permissible-mark cases. The research preset correction is
  faithful.
- The axis-density closeout supports static closure only on the public
  availability path with a real current mark. The synthesis preserves that
  scope.
- `terminal_settlement_unsupported` still means preserving the holding and
  never fabricating cash (`contracts.md:434`).
- The synthesis creates no production code, test, ticket, checker or schema.

## Containment

Only this review file was added by the review. No synthesis, seed, response,
code, test, evidence or planning file was edited, staged, committed or pushed.
No spike or census was rerun.

NEEDS_TYPE_2
