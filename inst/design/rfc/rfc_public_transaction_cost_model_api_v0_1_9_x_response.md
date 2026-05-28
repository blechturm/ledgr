# Response: Public Transaction-Cost Model API RFC Seed

**Status:** Reviewer response; design input for a future cost-API synthesis.
**Respondent:** Claude
**Date:** 2026-05-27
**Responds to:** `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_seed.md`

**Revision note:** This response was written against the v1 seed authored by Codex. The seed was not edited. Future RFC rounds should preserve separate versioned seed files before any response-stage in-place revision.

---

## Summary Verdict

The seed's central direction is right and largely aligned with the cost-RFC predecessor thread, the walk-forward synthesis, the OMS synthesis, and the execution-policy north star. The proposed public model — classed cost objects, ordered chain composition, quantity-preserving fill-time semantics, deterministic object identity, hard boundary against liquidity/OMS/financing/TCA — is the correct minimum for v0.1.9.x/v0.2.0.

The seed is not synthesis-ready as written. The architectural direction holds, but several places overscope v1 or punt decisions the synthesis writer will need to bind. The fixable issues:

- the proposed primitive catalog has six constructors; the honest v1 minimum is two-plus-chain, with the rest as follow-up tickets;
- §4.4's `timing_model` rename is a real breaking change presented as a cosmetic choice; the cost-benefit deserves explicit weighing;
- §4.3 admits a templated composite (`ledgr_cost_equity_retail`) that §11 elsewhere warns against — internal contradiction;
- the spread-bps convention (full bps per leg → ~2× spread on round trip) is described accurately but punted to spec-cut; this is the kind of semantic where punting bites later;
- percentage-fee composition semantics are unspecified (compute against reference price vs adjusted price); load-bearing for chain ordering;
- min/max fee caps interact with chain composition in ways the seed doesn't address;
- §15 open-question list duplicates several decisions the seed text already leans toward; pick one mode (lean and remove from open, or stay open and don't lean).

The right next step is one focused seed revision narrowing v1 scope and binding the small set of semantic conventions above. No architectural rework needed. The synthesis can then bind decisively without re-opening the design space.

---

## Accepted Direction

The response accepts these design directions and recommends they not be re-litigated during synthesis:

- **The v1 public cost API is quantity-preserving.** No partial fills, no quantity clipping, no no-fill rows. Quantity-mutating concerns belong to the future liquidity/execution layer. This matches the OMS synthesis's stage boundary and the execution-policy north star.
- **Public surface is ledgr-classed objects only.** No arbitrary user closures with replay-stable identity guarantees in v1. R closure semantics make the captured-environment problem sharp; the seed correctly defers free-form callbacks.
- **Cost identity belongs to execution identity.** Cost affects fills, equity, metrics, and promoted evidence; therefore it participates in run/sweep/promotion provenance. This matches the chainable-risk synthesis's treatment of risk identity.
- **Timing and cost are conceptually separable.** Timing produces proposals; cost prices them. This matches the cost-model-architecture-response thread that already established the internal seam.
- **Strategy ctx vs fill_context boundary is preserved.** Cost models receive a post-decision execution context, never the strategy ctx. The seed §6 is explicit and correct.
- **Cost may adjust price and add fees; it may not change side, quantity, instrument, or execution timestamp.** This is the v1 invariant that protects future liquidity from being confused with cost.
- **Borrow, margin interest, carry, perpetual funding, TCA, tax-lot accounting, paper/live reconciliation are all out.** The §0 non-scope list is comprehensive and well-grounded in the research.
- **NautilusTrader is the right architectural influence with explicit humility about catalog semantics.** Same verdict the walk-forward synthesis reached on Nautilus, for the same reasons.
- **Core ledgr does not ship broker-certified fee schedules.** §11 ownership split is correct: primitives in core, approximations as docs examples, broker-specific schedules in adapter packages or user code.
- **Cost does not see the strategy ctx; the no-lookahead boundary is mechanical, not documentary.**

These are the load-bearing choices. The remaining findings refine how the seed should make them implementable.

---

## Blocking Corrections

### 1. The v1 primitive catalog is broader than v1 needs

The seed §4.2 lists six primitive constructors as if they're a coherent v1 minimum:

```r
ledgr_cost_spread_bps(bps)
ledgr_cost_price_adjust_bps(bps, side)
ledgr_cost_fixed_fee(amount)
ledgr_cost_notional_bps_fee(bps, min_fee, max_fee, side)
ledgr_cost_per_share_fee(amount, min_fee, max_fee, side)
ledgr_cost_per_contract_fee(amount, min_fee, max_fee, side)
```

The honest minimum for parity with current behavior is two:

```r
ledgr_cost_spread_bps(bps)        # preserves current spread_bps semantics
ledgr_cost_fixed_fee(amount)      # preserves current commission_fixed semantics
ledgr_cost_chain(...)             # composition
```

That's the v1 scope that:
- preserves the existing internal cost behavior exactly;
- introduces the classed-object public surface and chain composition;
- requires no new semantic decisions about min/max caps, side filtering, per-share vs per-contract distinctions, or asset-class assumptions.

The other four constructors are reasonable and probably useful, but each adds real scope:
- `ledgr_cost_price_adjust_bps` with `side` parameter introduces the asymmetric-spread case (only adjust BUY or only adjust SELL).
- `ledgr_cost_notional_bps_fee` with min/max caps introduces cap composition semantics (per-step or per-chain?).
- `ledgr_cost_per_share_fee` with caps introduces share-counting assumptions and lot semantics.
- `ledgr_cost_per_contract_fee` introduces the contract/instrument-class concept that ledgr doesn't currently have at the cost layer.

**Recommendation:** synthesis binds v1 minimum as the two-primitive parity surface plus `ledgr_cost_chain()`. The other four constructors become a "primitive-catalog expansion" ticket inside the v0.1.9.x/v0.2.0 window, but separate from the core public-cost-API ticket. Each can be added once its semantic questions are bound. The seed should not present them as v1 baseline.

This is consistent with how chainable risk shipped: two adapters (`ledgr_risk_long_only`, `ledgr_risk_max_weight`) and the chain, with everything else deferred.

### 2. The `timing_model` rename is presented as a cosmetic choice but is a real breaking change

The seed §4.4 recommends introducing `timing_model` and `cost_model` as the new public API, with the alternative ("preserve `fill_model` as the timing argument and add `cost_model` beside it") presented as a fallback. The reasoning ("`fill_model` has historically conflated timing and costs") is correct but understates the cost of the rename.

Current state (verified against [R/experiment.R:155-203](R/experiment.R#L155-L203)): `fill_model` is a documented public argument on `ledgr_experiment()`. The shape is `list(type = "next_open", spread_bps = ..., commission_fixed = ...)`. It is validated by `ledgr_experiment_normalize_fill_model()` and `validate_ledgr_config()` (the latter at [R/config-validate.R:155-169](R/config-validate.R#L155-L169)). Default README, getting-started, and Yahoo examples all show `fill_model = ...`.

Renaming to `timing_model` requires:
- new argument on `ledgr_experiment()`;
- deprecation or removal of `fill_model`;
- migration of config-validate semantics;
- updates to every vignette, every example, the `extract-strategy` README chunk story, and the v0.1.8.5 workflow article that ships next;
- documentation contract test updates;
- existing run-store reopen behavior (`ledgr_run_open()` reads config_json and expects `fill_model`).

The benefit of `timing_model` is real: the name better describes what the object does once costs are a separate concept. But the cost is also real, and ledgr just paid a similar cost on the v0.1.8.4 docs rewrite. Pre-CRAN policy permits the rename; it doesn't require it.

**Recommendation:** synthesis binds `fill_model` as the timing argument (continues to mean "when fills happen"), and adds `cost_model` beside it. The argument that "`fill_model` conflated timing and costs" is true historically but stops being true the moment `cost_model` exists as a separate argument — `fill_model` retroactively becomes the timing-only argument. This is the path with smaller migration cost and equivalent semantic clarity.

If the maintainer wants the rename, the synthesis should call it out as a deliberate breaking change with a non-trivial doc-migration cost, not present it as the obviously cleaner default.

### 3. §4.3 contradicts §11 on broker templates

The seed §4.3 admits:

```r
ledgr_cost_equity_retail(spread_bps = 5, per_share = 0, min_fee = 0)
ledgr_cost_zero()
```

as v1 convenience composites. The seed §11 then warns against shipping recognizable broker-certified templates in core:

> "If core ledgr ships a recognizable template, it must carry explicit wording: 'This is an approximation for research examples. It is not a broker-certified fee schedule and may not match your account, venue, jurisdiction, or date.'"

`ledgr_cost_equity_retail()` is exactly the kind of template §11 warns about. The name is generic enough to imply a US-retail-equity standard. Users will read it as "the default for equity research." The composite hides a spread/per-share/min-fee assumption that is jurisdiction-specific and date-sensitive.

`ledgr_cost_zero()` is fine — it's literally zero, not an approximation. But `ledgr_cost_equity_retail()` is the unsafe case.

**Recommendation:** synthesis drops `ledgr_cost_equity_retail()` from v1. `ledgr_cost_zero()` is the only v1 convenience composite worth admitting. If template-style helpers are useful, they belong in a docs vignette ("here's how to compose a US retail equity cost with default assumptions") or in a future companion package, not in core.

If the maintainer wants `ledgr_cost_equity_retail()`, §11's caveat language must be carried into the help page itself, the function must be name-mangled to make its approximation status visible (e.g., `ledgr_cost_equity_retail_approx()`), and the maintainer must accept ongoing schedule-maintenance burden.

### 4. Percentage-fee composition semantics are unspecified

The seed §5.2 acknowledges that "A price transform before a percentage fee may differ from a percentage fee before a price transform if the fee is computed on adjusted notional." This is correct but the seed doesn't bind which one happens. That decision is load-bearing for v1 because:

- if `ledgr_cost_notional_bps_fee(10)` is computed on the *reference* price (pre-transform), composition order doesn't matter for fee calculation;
- if it's computed on the *adjusted* fill price (post-transform), composition order changes the fee amount in ways users will not predict.

The competitor evidence in the research is mixed: Zipline's `SlippageModel` produces transactions and `CommissionModel` operates on those transactions (post-slippage); LEAN's docs are less explicit but the per-security model assignment suggests fees and fills are independent of order.

**Recommendation:** synthesis binds that percentage and notional fees in v1 are computed against the **resolved fill price after any price transforms in the same chain**. This is the natural reading, matches the Zipline pattern, and means a "10bps notional fee" is "10bps of what actually traded." Specifically:

```text
For a chain [price_transform, notional_bps_fee]:
  resolved_fill_price = price_transform(reference_price)
  fee = notional_bps_fee.bps / 10000 * resolved_fill_price * qty
```

Document this explicitly in the chain semantics. Note that this makes chain order semantically meaningful (price transforms must come before percentage fees that depend on the adjusted price), which the §5.2 order-matters point already implies but doesn't quite bind.

### 5. Min/max fee caps interact with composition in unspecified ways

The seed §4.2 admits `min_fee` and `max_fee` arguments on three of the proposed fee primitives. The seed never says whether caps apply per-step or per-chain. The cases:

- Two fee steps, each with `min_fee = 1`: does the user pay the per-step minimum twice (total min = 2), or is the minimum a per-chain floor (total min = 1)?
- Two fee steps, each with `max_fee = 5`: does the chain cap at 10, or at 5?
- A `notional_bps_fee` with `min_fee = 1` plus a `fixed_fee` of 0.50: does the fixed fee count toward the notional fee's minimum, or are they independent?

These aren't edge cases — they're the first user question for anyone with a real-world IBKR-style cost stack.

**Recommendation:** the easiest bound semantic is **caps apply per-step, not per-chain**. Each step independently enforces its own min/max; the chain sum is whatever the per-step results add to. This matches how `ledgr_cost_chain` composes other steps (independently, in order) and is the only semantic that scales to arbitrary chain length.

Alternative: defer min/max caps from v1 entirely, since the two-primitive minimum (recommendation #1) doesn't need them. If caps are deferred, this finding goes away.

### 6. The seed's §15 open-question list duplicates positions the seed text already takes

Several open questions in §15 are already answered in the seed body, with the seed's recommendation contradicting "open" status:

- **Q1 (timing_model vs fill_model):** §4.4 recommends `timing_model`; Q1 asks the same question. Either remove Q1 (decision is bound) or remove the §4.4 recommendation (decision is open). Per blocking correction #2, my recommendation is to bind `fill_model` as timing in synthesis and remove from open questions.
- **Q2 (legacy scalar handling):** §4.5 recommends "clean break or explicit legacy helper." Q2 asks the same question with three options. Pick one in §4.5 or leave Q2 open.
- **Q4 (spread vs slippage naming):** §4.2 already proposes `ledgr_cost_spread_bps()` as the primitive name. Q4 asks whether to rename to `ledgr_cost_price_adjust_bps()`. Either remove Q4 (bound to `_spread_bps`) or remove the primitive name from §4.2 (open).
- **Q13 (broker templates):** §11 binds core does not ship broker-certified templates. Q13 asks the same. Bound; remove from open.

**Recommendation:** the seed should pick one mode per topic. Either commit in the text and remove from §15, or leave open in §15 and don't lean in the text. The current state — text recommends, §15 reopens — leaves the synthesis writer guessing which is binding.

---

## Non-Blocking Findings

### 1. The seed accurately describes the existing spread-bps convention but punts the binding

§7.1 says: "current behavior applies the full bps value on each leg, so a round trip costs roughly `2 * spread_bps` before explicit fees."

Verified against [R/fill-model.R:177](R/fill-model.R#L177): `multiplier <- if (side == "BUY") (1 + spread_bps / 10000) else (1 - spread_bps / 10000)`. BUY pays `open * (1 + bps/10000)`; SELL receives `open * (1 - bps/10000)`. Round-trip transaction cost is `2 * open * (bps/10000)`.

The seed correctly notes this and says "preserve the existing per-leg spread convention" unless the spec changes it. Two issues:

1. The convention is genuinely confusing to users. A user reading `spread_bps = 5` reasonably expects "the bid-ask spread is 5bps" (i.e., 5bps round-trip cost), not "I pay 5bps on each leg." The half-spread-per-leg convention (which would give 5bps round-trip for `spread_bps = 5`) is what most users would assume.
2. Pre-CRAN status means the convention can be changed without backwards-compat shims.

**Recommendation:** synthesis explicitly binds the convention. My recommendation: change to half-spread-per-leg (BUY pays `open * (1 + bps/20000)`, SELL receives `open * (1 - bps/20000)`), so `spread_bps = 5` means "5bps total round-trip cost," which matches user intuition. If the synthesis keeps the current convention, document loudly in the help page that `spread_bps` is per-leg, not the bid-ask spread.

Not blocking because either convention is defensible if bound; the convention should not be left as "preserve current unless spec changes."

### 2. Negative-fee handling means relaxing an existing validator

The seed §7.3 discusses negative fees and rebates as a v1 decision. Verified: current code enforces `commission_fixed >= 0` at [R/config-validate.R:168](R/config-validate.R#L168). Admitting negative fees requires relaxing this validator.

The seed recommends "banning general negative fees in v1 and admitting rebates only if a dedicated rebate/maker-taker convention is bound." Agreed. But the seed should make explicit that the v1 ban on negative fees is a *continuation* of the current behavior, not a new restriction. The phrasing "the first public cost API must decide explicitly" suggests an open design space when the status quo already bans them.

**Recommendation:** synthesis carries forward the current `commission_fixed >= 0` invariant explicitly as "all v1 fees ≥ 0; rebates deferred to a future RFC that binds a maker/taker convention."

### 3. Cost identity field count is higher than walk-forward's

The seed §5 proposes six identity fields:

```text
cost_model_version
cost_model_type
cost_model_json
cost_model_hash
cost_plan_hash
cost_step_hashes
```

Compare to the walk-forward synthesis's identity fields: `session_id`, `candidate_key`, `fold_id`, `fold_list_hash`. Walk-forward is a more complex domain; cost should not need more identity fields than walk-forward needs for its entire data model.

The seed's six fields collapse to two semantic concepts:
- the cost model itself (object identity)
- the compiled cost plan (worker-safe representation identity)

Plus a JSON serialization for inspection. Step hashes are computable from the plan; version and type are part of the canonical JSON.

**Recommendation:** synthesis binds two persisted identity fields per run/candidate:

```text
cost_model_hash       deterministic content hash of the cost-model object
cost_plan_json        canonical JSON of the compiled plan (queryable)
```

Step hashes, version, type are all recoverable from `cost_plan_json` without needing separate columns. This matches the OMS synthesis's discipline of binding the contract, not over-binding the storage shape.

### 4. Component-fee retention vs single-fee accounting needs binding

The current `ledger_events.fee` is a single DOUBLE column per row. The seed §12 says total fee in canonical accounting, component details in `meta_json` when retained. This is the right direction but leaves a v1 question: what if a `ledgr_cost_chain` produces two fees (e.g., a commission + an exchange fee)? Do they sum to one `ledger_events.fee` row, or do they produce two rows, or does `meta_json` carry the breakdown?

The simplest v1 binding: chain fees sum to one total fee per fill; component breakdown lives in `meta_json` only when retention is explicit. This avoids ledger-schema changes for v1 and matches the seed's preference.

**Recommendation:** synthesis binds the sum-to-one-fee-per-fill semantics. Component-level fee storage is deferred to a future diagnostic retention tier (matches the walk-forward synthesis's "scalar default; richer retention is future" pattern).

### 5. `metric_context_hash` participation not addressed

The walk-forward synthesis binds `metric_context_hash` in both `session_id` and `candidate_key` composition. The chainable-risk synthesis treats metric context as part of post-run analysis (not execution identity). Cost is execution identity; does the cost identity hash include metric context?

My read: no. Cost is computed at fill time, before metrics. Metric context affects post-run aggregation. They're orthogonal. But the seed should say this explicitly to prevent the synthesis writer from coupling them by accident.

**Recommendation:** synthesis adds one sentence: "`cost_model_hash` does not participate in metric-context identity; they are orthogonal. Two runs with the same cost model and different metric contexts are different runs by metric identity, not by cost identity."

### 6. Sweep namespace for cost is correctly deferred but the boundary is sharp

The seed §8 correctly defers `ledgr_cost_grid()` and `ledgr_grid_cross(cost = ...)` to future work. Agreed. But the boundary needs one sharp sentence: in v1, cost is *fixed per experiment*, not per candidate. Users who want to sweep cost assumptions must either:

- run separate experiments with different cost models, or
- wait for the future cost-sweep RFC.

Without that sharp statement, users will try to put cost parameters in `strategy_params` and get confused about why cost varies per candidate but cost identity does not.

**Recommendation:** synthesis binds "cost is experiment-level in v1; per-candidate cost is future work." Either reject cost-bearing names in strategy_params with a classed error, or document that putting cost in strategy_params is invisible to cost identity.

### 7. No mention of fill_intent shape changes

The seed assumes the existing `ledgr_fill_intent` shape (instrument_id, side, qty, fill_price, commission_fixed, ts_exec_utc) is sufficient. Adding richer cost models (multi-component fees, side-conditional adjustments, currency-tagged fees) may require new fields. The seed doesn't address this.

**Recommendation:** synthesis confirms or specifies the v1 `fill_intent` shape. If it stays the same (single `commission_fixed` field), then chain-fee summation per finding #4 is required. If it changes (e.g., `fees = list(component_a = ..., component_b = ...)`), then internal schema needs binding.

---

## Open Questions: Bind / Defer / Remove

Walking through the seed's 15 open questions:

| # | Question | Disposition | Rationale |
|---|---|---|---|
| 1 | timing_model vs fill_model | Bind (keep `fill_model` as timing arg) | Per blocking #2. Don't pay the rename tax. |
| 2 | Legacy scalar handling | Bind (legacy helper for one cycle, then remove) | The seed §4.5 already leans this way. |
| 3 | V1 primitive catalog | Bind (two primitives + chain only) | Per blocking #1. |
| 4 | Spread vs slippage naming | Bind (`ledgr_cost_spread_bps` per current convention name) | Removes Q4 ambiguity. |
| 5 | Negative fees and rebates | Bind (ban in v1; rebates deferred) | Per finding #2. |
| 6 | Fee currency | Bind (v1 single-account-currency) | The seed §7.4 already recommends this. |
| 7 | Cost detail retention | Bind (sum to one fee; components in meta_json when retained) | Per finding #4. |
| 8 | Cost sweep namespace | Defer (correctly) | The seed §8 already reserves room. |
| 9 | Parameter references | Defer (coupled to #8) | Premature. |
| 10 | Assignment model (per-instrument/asset/venue) | Defer | Real future-RFC question; v1 is experiment-level. |
| 11 | Simple impact proxy | Bind (deferred to liquidity RFC) | Research is explicit: impact is liquidity. |
| 12 | Maker/taker convention | Defer (coupled to liquidity) | Same as #11. |
| 13 | Broker templates | Bind (not in core) | The seed §11 already binds this; Q13 is redundant. |
| 14 | Identity migration | Spec-cut | Real implementation detail. |
| 15 | Cost plan shape (row-wise vs vectorized) | Defer (implementer's choice) | Implementation detail; the synthesis can leave open. |

**Missing open questions worth adding:**

- **Spread-bps convention (half-spread vs full-spread per leg).** Per finding #1. The seed mentions but doesn't elevate.
- **Percentage-fee composition semantics (reference vs adjusted price).** Per blocking #4. Must be bound.
- **Min/max fee cap composition (per-step vs per-chain).** Per blocking #5. Either bind or defer with the primitives.
- **fill_intent shape for v1.** Per finding #7. The synthesis writer needs to know what schema work is in scope.

**Net:** of 15 questions, 9 should be bound by synthesis, 5 should be deferred to future RFCs, and 1 should be spec-cut. 4 new questions should be added. The seed should end up with maybe 5-6 open questions after the revision, all genuinely synthesis-stage decisions or spec-cut details.

---

## Roadmap / Codebase Alignment

### Roadmap

Synthesis targeting v0.1.9.x/v0.2.0 matches `ledgr_roadmap.md`. Cost API correctly sits after target risk (v0.1.9), around walk-forward (v0.1.9.x), and before OMS implementation (v0.2.x). The seed does not pull OMS, liquidity policy, or paper/live forward. ✅

The walk-forward synthesis explicitly placed cost API at v0.1.9.x/v0.2.0 in its sequencing table. The cost seed's target window matches. ✅

The accepted OMS synthesis says: "the public cost API is quantity-preserving and should stabilize before OMS." Cost seed preserves the quantity-preserving invariant. ✅

### Chainable-risk synthesis

- Risk transforms targets; cost prices fills. No overlap. ✅
- Risk identity participates in execution identity; cost identity should too. Seed §5 binds this. ✅
- "Classed ledgr objects only" discipline that chainable-risk applied to risk steps is correctly applied to cost objects. ✅
- Worker-safe compiled plan requirement carried forward in §4.1. ✅

No contradictions.

### Walk-forward synthesis

- Walk-forward includes `risk_chain_hash` in candidate identity post-v0.1.9. Cost identity (`cost_model_hash`) should also participate in walk-forward candidate identity post-v0.1.9.x. The cost seed doesn't address walk-forward identity composition; the synthesis should add it.
- Walk-forward's `metric_context_hash` is orthogonal to cost identity per finding #5.

Not a contradiction, but a missing handoff: cost synthesis should note that future walk-forward candidate identity must include `cost_model_hash` once the cost API lands.

### OMS synthesis

- OMS sits between fill proposal and fill intent: `target delta → order intent → fill proposal → cost resolver → fill intent → ledger event`. Cost API consumes the fill proposal and emits the fill intent. ✅
- Liquidity is downstream of cost; cost does not mutate quantity. ✅
- The OMS synthesis explicitly defers paper/live cost reconciliation; cost seed §0 honors this. ✅

No contradictions.

### Execution-policy north star

- North star binds: "quantity-preserving pricing/fee adjustments are not the same thing as quantity-changing execution or liquidity decisions." Cost seed enforces this in §2.3, §3, §10. ✅
- North star sequences: risk → order policy → timing → cost → liquidity → ledger. Cost seed sits between timing and ledger, with liquidity downstream. ✅

No contradictions.

### Current code feasibility

- The internal seam (`ledgr_next_open_fill_proposal`, `ledgr_resolve_fill_proposal`, `ledgr_cost_spread_commission_internal`, `ledgr_fill_context`) is real and verified at [R/fill-model.R](R/fill-model.R). The seed accurately describes it.
- `fill_model` is a public experiment argument verified at [R/experiment.R:155-203](R/experiment.R#L155-L203). The seed's claim that the public surface conflates timing and cost is accurate.
- `validate_ledgr_config()` enforces `spread_bps >= 0` and `commission_fixed >= 0` at [R/config-validate.R:165-169](R/config-validate.R#L165-L169). Confirmed; negative-fee admission requires validator changes (per finding #2).
- The default cost resolver at [R/fill-model.R:158-191](R/fill-model.R#L158-L191) uses the full-bps-per-leg convention (per finding #1).
- Implementation scope: the cost API requires (a) new public `ledgr_cost_*` constructors, (b) `ledgr_cost_chain()` composition, (c) the chain-compilation step that produces a worker-safe plan, (d) experiment integration, (e) config-validate updates, (f) provenance/hash fields. None require fold-core changes; the existing internal seam absorbs the new public surface.

The seed correctly understates the implementation scope for the two-primitive minimum (blocking #1). For the full six-primitive surface as proposed, the scope is meaningfully larger because of side handling, min/max cap composition, and per-contract instrument-class assumptions.

---

## Recommended Next Step

**One focused seed revision, then synthesis. No second response round.**

The seed is architecturally sound. The blocking corrections are scope-narrowing and ambiguity-resolution, not redesign:

1. Narrow the v1 primitive catalog to two-plus-chain (blocking #1).
2. Bind `fill_model` as the timing arg, add `cost_model` beside it; drop the `timing_model` rename (blocking #2).
3. Drop `ledgr_cost_equity_retail()` from v1 composites; keep only `ledgr_cost_zero()` (blocking #3).
4. Bind percentage-fee composition semantics: computed against resolved fill price (blocking #4).
5. Either bind min/max cap semantics (per-step) or defer min/max from v1 (blocking #5).
6. Bind decisions in §4.4, §4.5, §4.2, §11 and remove the corresponding open questions from §15 (blocking #6).
7. Bind the spread-bps convention explicitly (finding #1).
8. Note negative-fee ban is continuation of current behavior (finding #2).
9. Condense identity fields to `cost_model_hash` + `cost_plan_json` (finding #3).
10. Bind sum-to-one-fee-per-fill accounting; component breakdown in `meta_json` when retained (finding #4).
11. Note `metric_context_hash` orthogonality (finding #5).
12. Note cost is experiment-level in v1; per-candidate is future (finding #6).
13. Confirm `fill_intent` shape stays the same in v1 (finding #7).
14. Add the four missing open questions (spread-bps convention, percentage-fee composition, cap composition, fill_intent shape).
15. Add the walk-forward identity handoff note (cost API integration with walk-forward `candidate_key`).

After these revisions, the seed should be synthesis-ready with ~5-6 genuinely open questions for spec-cut. The synthesis can then bind decisively in a single round.

The architecture stays the same. The deferrals stay the same. The accepted directions stay the same. The work is tightening overclaims and binding semantic conventions the v1 implementation needs to know.

**Process discipline note:** per the lessons from the OMS and walk-forward cycles, the seed revision should be authored by the original seed author (Codex). The revised seed should be a separate file (`_seed_v2.md`) preserving the v1 seed as historical artifact, not an in-place revision. This response document remains the historical adversarial input regardless.
