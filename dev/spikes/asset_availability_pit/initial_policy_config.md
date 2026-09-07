# Initial Comparison Policy

**Status:** Proposed; maintainer approval required.

**Policy ID:** `asset_availability_initial_policy_v2_proposed`.

This is one coherent starting configuration for comparing representations. It
is not a package default, API decision, or implementation authorization. The
maintainer may revise it before approving Stage 2. Once approved, every
provider uses the same configuration.

## Portfolio Budget

- Preserve held non-members at their current quantity unless the strategy
  explicitly emits zero.
- Size current-member allocation from residual marked NAV after preserved
  exposure, not total NAV.
- Do not count expected sale proceeds as cash before a sale fills.
- Apply affordability at the existing
  `ledgr_fold_apply_net_feasibility_noop()` seam after fill proposals and costs
  resolve, but before any state mutation or event emission.
- For feasibility only, the shared fork evaluates actionable intents against a
  virtual cash ledger ordered by stable asset ID. It credits executable
  cash-generating fills first, then evaluates cash-consuming fills against
  current cash plus those same-pulse net proceeds.
- Stable-ID order is an arbitrary deterministic tie-break shared by every
  provider. It is not an execution-priority or economic-preference rule.
- Accept a cash-consuming fill only in full when its resolved cash delta leaves
  the virtual balance non-negative. Otherwise reject that fill alone with
  `insufficient_cash`; do not scale, floor, defer, or reject unrelated fills.
- Record intended gross exposure, post-risk target exposure, realized cash, and
  actual exposure separately. Apply and emit accepted fills in the original
  validated target-vector order, preserving dense-fold event ordering. A buy
  may therefore precede its same-pulse funding sale in the event stream; this
  policy guarantees final pulse affordability, not an intra-pulse cash floor.

This proposed policy is deliberately conservative. Alternative financing or
affordability policies may be separate named scenarios only after the initial
comparison and must be applied to every provider.

## Membership Removal And Targets

- Membership removal never creates an automatic liquidation target.
- Zero always means desired quantity zero.
- Package-style constructors initialize held non-members to current quantity.
- A held non-member that is not otherwise target-restricted admits its current
  quantity, zero, or a same-sign target with no greater magnitude. An increase
  or sign reversal fails with `nonmember_exposure_increase`; membership removal
  never permits new ineligible exposure.
- A target-restricted holding admits only its current quantity or zero before
  risk. Post-risk closure follows the separate rule below.
- A failed zero target creates no pending order; a later attempt requires a new
  zero target.
- Target wrappers remain thin and carry no command or order state.

## Valuation

- Fresh valuation uses an accepted observed close.
- A held instrument may use a separate stale valuation mark for at most two
  expected sessions under the declared calendar.
- A stale valuation mark never becomes an observed close or execution price.
- At the first pulse where a held position has no permissible mark after the
  stale horizon, stop that candidate before strategy, risk, fill, or accounting
  work for the pulse. Record `valuation_horizon_exhausted`, the affected
  exposure, the intended horizon, and the achieved horizon through the
  preceding fully valued pulse. Reserve terminal-settlement reasons for an
  accepted terminal event whose economics cannot be represented.
- Prefix metrics through the achieved horizon remain visible but are marked
  incomplete and excluded from complete-performance comparison.

## Trading Status

- Resolve status at the event time from facts knowable by that time, considering
  effective intervals, source precedence, and supersession.
- Equal-precedence conflict or unresolved status produces a conservative
  no-fill with a typed reason.
- Execution evidence remains unavailable to the strategy decision context.

## Observation And Calendar Handling

- The declared venue calendar creates the pulse axis; observed rows never add
  pulses by themselves.
- A row outside the declared expectation or for an instrument not knowable at
  that pulse is classified as `observed_row_outside_expectation`, retained for
  diagnostics, and ignored by runtime inputs, fitted state, features, targets,
  fills, and economic outputs.
- Classification is pulse- and cutoff-specific. A row ignored at one pulse may
  become admissible source history later when it is knowable and passes every
  declared history rule; it never retroactively changes an earlier result.
- Unknown lifetime metadata alone restricts nothing, creates no terminal event,
  and does not invalidate a fresh accepted observation. Membership, status,
  observation, valuation, and execution facts still resolve independently.

## Risk And Accounting

- When the strategy close is unavailable, `max_weight` uses the separate
  accepted valuation mark and records its source and age. It records
  `stale_mark_pass_through` when the target is unchanged and
  `stale_mark_reduction` when it reduces the target.
- A holding without a permissible valuation mark stops under
  `valuation_horizon_exhausted` before risk, so `max_weight` never receives an
  unvalued holding under this policy.
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

## History And Estimation Population

- Accepted source-domain history remains keyed by stable asset ID across
  membership entry, exit, and re-entry. Membership does not erase admissible
  observations or rolling feature history.
- Pre-membership observations may contribute after entry only when they were
  knowable by the decision cutoff and pass the same lifetime, calendar,
  classification, revision, and observation policies. The strategy never sees
  the future member before entry.
- Supported strategy state remains while an asset is visible as a member or a
  holding. When it is neither, strategy state is dropped; a later re-entry
  initializes new strategy state while source and feature history remain keyed
  to the stable ID.
- The default estimation population is the historically knowable investment
  membership at each fit cutoff. W12 is an explicit named override to a broader
  historically knowable population. W13's future-selected population is
  rejected as non-causal.
- The admissible-history and estimation-population rules are identity-bearing
  inputs to their dependent feature and fitted artifacts.

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
