# Initial Comparison Policy

**Status:** Maintainer approved.

**Policy ID:** `asset_availability_initial_policy_v4`.

**Revision history:** `asset_availability_initial_policy_v2` was approved on
2026-09-07 at commit `3d76615`. Version 3 was accepted on 2026-09-07 after a
late independent policy review and before witness authoring. Version 4 was
accepted on 2026-09-07 after independent review of the drafted witness packet.

This is the approved starting configuration for comparing representations. It
is not a package default, API decision, or implementation authorization. Every
provider uses the same configuration unless a later reviewed amendment applies
an alternative scenario to every provider.

## Portfolio Budget

- Package-style constructors preserve held non-members at their current
  quantity by default. An explicit admissible reduction or zero target
  overrides that default.
- Size current-member allocation from residual marked NAV after reserving the
  current marked absolute exposure of every held non-member, not from total
  NAV. An intended reduction does not release this reserve before an accepted
  fill changes the position.
- Rejected or unfilled sale intents contribute no available funds. For batch
  feasibility, net proceeds from accepted same-pulse sales may fund accepted
  purchases. Recorded cash changes only when accepted fills are applied.
- Affordability-certified scenarios require finite, non-negative opening cash.
- Apply affordability at the existing
  `ledgr_fold_apply_net_feasibility_noop()` seam after fill proposals and costs
  resolve, but before any state mutation or event emission.
- Affordability is evaluated only when an execution price exists. A fill
  blocked by status or by a missing execution bar never enters the virtual
  ledger as a cash-consuming or cash-generating fill.
- For feasibility only, the shared fork evaluates actionable intents against a
  virtual cash ledger ordered by stable asset ID. It credits executable
  cash-generating fills first, then evaluates cash-consuming fills against
  current cash plus those same-pulse net proceeds.
- Every sale credited by the virtual ledger must remain in the final accepted
  fill set and be applied in that pulse. If a credited fill later disappears,
  invalidate pulse completion rather than retaining purchases it funded.
- Stable-ID order is an arbitrary, deterministic funding priority shared by
  every provider. It does not represent exchange execution priority or a
  strategy preference.
- Accept a cash-consuming fill only in full when its resolved cash delta leaves
  the virtual balance non-negative. Otherwise reject that fill alone with
  `insufficient_cash`; do not scale, floor, defer, or reject unrelated fills.
- The initial comparison uses an absolute `cash_tolerance` of `1e-8` in base
  currency. Feasibility and accounting use the same resolved cash deltas. A
  balance whose absolute value is no greater than the tolerance is canonical
  zero; a balance below negative tolerance is negative.
- After applying the final accepted fill set in event order, final recorded
  cash must reconcile to the virtual final balance within `cash_tolerance`.
  Failure stops the candidate with `affordability_reconciliation_failed`.
- Record intended gross exposure, post-risk target exposure, realized cash, and
  actual exposure separately. Apply and emit accepted fills in the original
  validated target-vector order, preserving dense-fold event ordering. A buy
  may therefore precede its same-pulse funding sale in the event stream; this
  policy guarantees final pulse affordability, not an intra-pulse cash floor.

This is a declared same-pulse netting model with current-exposure reservation.
It is conservative about rejected or unfilled sales, but it is not a universal
cash-floor or settlement model. Alternative financing or affordability
policies may be separate named scenarios only after the initial comparison and
must be applied to every provider.

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
- Stale age is exact: a fresh accepted mark has age zero, the first missing
  expected session has age one, the second has age two, and the third stops the
  candidate. A held former member continues to age on expected sessions after
  leaving the investment universe; declared closures do not increment age.
- A stale valuation mark never becomes an observed close or execution price.
- At the first pulse where a held position has no permissible mark after the
  stale horizon, preserve all fills and accounting events already executed
  before that valuation cutoff, then stop before initiating a new strategy
  decision, risk pass, or fill proposal at the failing cutoff. Record
  `valuation_horizon_exhausted`, the affected exposure, the intended horizon,
  the achieved horizon through the preceding fully valued pulse, the last
  fully valued metric timestamp, and the last executed-event timestamp.
  Reserve terminal-settlement reasons for an accepted terminal event whose
  economics cannot be represented.
- Prefix metrics through the achieved horizon remain visible but are marked
  incomplete and excluded from complete-performance comparison.

## Trading Status

- Resolve status at the event time from facts knowable by that time, considering
  effective intervals, source precedence, and supersession.
- Decision-time target restriction is the trading status resolved at the
  decision pulse from facts knowable by that pulse. A restricting status that
  is knowable but effective only after the decision pulse does not restrict
  that decision; it applies at the execution opportunity through status
  resolution.
- Equal-precedence conflict or unresolved status produces a conservative
  no-fill with a typed reason.
- When no status assertion exists, status is `status_unknown` and execution
  produces a typed no-fill; an observation alone never implies active status.
  A fixture that expects a fill must provide an effective active assertion.
- Execution evidence remains unavailable to the strategy decision context.
- When more than one blocker applies at one execution opportunity, blockers
  are evaluated in this order: status resolution, execution-bar availability,
  affordability. The fill row carries the first applicable reason as its typed
  reason, and `no_fill_reasons` retains every applicable reason in that order
  joined with `|`.

## Observation And Calendar Handling

- The declared venue calendar creates the pulse axis; observed rows never add
  pulses by themselves.
- Decision-view exclusion is cutoff-specific. A row outside the declared
  calendar expectation is classified as `observed_row_outside_expectation`; a
  row for an instrument not yet knowable is classified as
  `instrument_not_yet_knowable`; and an invalid observation is classified as
  `observation_invalid`. Each is retained for diagnostics and excluded from
  that cutoff's runtime inputs, fitted state, features, targets, fills, and
  economic outputs.
- History eligibility is evaluated separately for each consumer and cutoff.
  Membership exclusion alone does not permanently invalidate genuine source
  history: a row excluded at one cutoff may become admissible history later
  when it is knowable and passes every declared history rule. A calendar or
  observation-validity failure is not repaired merely by later membership;
  only a valid, historically knowable superseding fact may change that
  classification. No later admission retroactively changes an earlier result.
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
- An unheld instrument with a new positive target is outside the held-position
  stale-mark rule. If a risk step that requires a mark, including
  `max_weight`, has no permissible mark for that target, stop before fill
  proposal or state mutation with `risk_mark_unavailable`; record the asset,
  target, and risk step.
- Post-risk validation accepts zero or a same-sign target with magnitude no
  greater than the admissible strategy target, explicitly including an
  unchanged target.
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
- For the prototype, asset-scoped strategy state occupies an explicitly
  declared `asset_state` map keyed by stable asset ID. The shared fork removes
  an entry when that asset is neither a member nor held. State outside that map
  is portfolio-level and is preserved. A later re-entry initializes new asset
  state while source and feature history remain keyed to the stable ID.
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

- Maintainer: repository maintainer.
- Date: 2026-09-07.
- Approved policy ID: `asset_availability_initial_policy_v4`.
- Supersedes: `asset_availability_initial_policy_v3`, approved at `3d76615`.
- Notes: accepted after independent review of the drafted witness packet. The
  amendment binds decision-time restriction, ordered no-fill reasons, and the
  execution-price prerequisite for affordability. No amendments remain open
  at approval.
