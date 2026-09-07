# Initial Comparison Policy

**Status:** Proposed; maintainer approval required.

**Policy ID:** `asset_availability_initial_policy_v1_proposed`.

This is one coherent starting configuration for comparing representations. It
is not a package default, API decision, or implementation authorization. The
maintainer may revise it before approving Stage 1. Once approved, every
provider uses the same configuration.

## Portfolio Budget

- Preserve held non-members at their current quantity unless the strategy
  explicitly emits zero.
- Size current-member allocation from residual marked NAV after preserved
  exposure, not total NAV.
- Do not count expected sale proceeds as cash before a sale fills.
- Reject a decision whose intended buys cannot be funded from current cash plus
  sale proceeds actually realized in the same ordered execution step.
- Record intended gross exposure, post-risk target exposure, realized cash, and
  actual exposure separately.

This proposed policy is deliberately conservative. Alternative financing or
affordability policies may be separate named scenarios only after the initial
comparison and must be applied to every provider.

## Membership Removal And Targets

- Membership removal never creates an automatic liquidation target.
- Zero always means desired quantity zero.
- Package-style constructors initialize held non-members to current quantity.
- A failed zero target creates no pending order; a later attempt requires a new
  zero target.
- Target wrappers remain thin and carry no command or order state.

## Valuation

- Fresh valuation uses an accepted observed close.
- A held instrument may use a separate stale valuation mark for at most two
  expected sessions under the declared calendar.
- A stale valuation mark never becomes an observed close or execution price.
- Exhausting the stale horizon stops complete-performance interpretation and
  records an incomplete-evidence reason.

## Trading Status

- Resolve status at the event time from facts knowable by that time, considering
  effective intervals, source precedence, and supersession.
- Equal-precedence conflict or unresolved status produces a conservative
  no-fill with a typed reason.
- Execution evidence remains unavailable to the strategy decision context.

## Risk And Accounting

- `max_weight` may use the separate accepted valuation mark and records its
  source and age.
- Post-risk validation accepts zero or a same-sign magnitude reduction from an
  admissible strategy target.
- W23's short case is an isolated algebraic closure witness, not short-account
  authorization.
- Unsupported terminal settlement prevents complete-performance claims.

## Incomplete Evidence

- A stopped candidate retains intended and achieved horizon, stop reason, and
  affected exposure.
- Prefix metrics remain visible but cannot participate as complete comparable
  evidence.
- Selection and reports show the exclusion rather than silently dropping it.

## Scope

- One declared venue calendar for the initial comparison.
- Multi-venue scheduling, live bad-data handling, general OMS behavior, margin,
  and corporate-action accounting remain outside this spike.
- Model-native missing-value handling in W30 is a consumer stub, not an ML API.

## Approval

- Maintainer: pending.
- Date: pending.
- Approved policy ID: pending.
- Notes or amendments: pending.
