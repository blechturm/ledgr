# Strategy Authoring API: Final Review Of The Synthesis

2026-10-28. Type 1 final review (stage 8) of
[the synthesis](rfc_strategy_authoring_api_v0_2_3_synthesis.md) by Claude, who
did not write it. Checked against the binding inputs: the
[response review and maintainer decisions](rfc_strategy_authoring_api_v0_2_3_decisions.md),
[response to v2](rfc_strategy_authoring_api_v0_2_3_response_v2.md) and
[seed v2](rfc_strategy_authoring_api_v0_2_3_seed_v2.md). Verification, not
design.

**Verdict: PASS, with one item for maintainer disposition (FR1).** Every
maintainer decision and every accepted response disposition is carried
faithfully. FR2 and FR3 are record-only notes for the spec cut.

## Checks performed

- **Decisions 1-10 of 2026-10-28** and decisions 1-2 of 2026-10-27: each is
  bound in D2-D9 and Section 3.1 without reopening. Decision 8 (required
  capital and costs) matches the code's starting point: `cost_model` already
  has no default and `opening` defaults to `ledgr_opening(cash = 100000)`
  (`R/experiment.R:233`), which D7 removes.
- **R1-R5 and Q4-Q8 dispositions:** carried into D1-D7 and Sections 4 and 7.
- **Claims about existing behavior, read in code:** the unpriced-holding guard
  in D3 exists (`R/strategy-helpers.R:436-482`, scale
  `max(0, allocation_equity - held_exposure) / priced_value`); the skip
  reason `sizing_unavailable` exists (`R/fold-engine.R:909`); C-locale radix
  tie-breaking exists (`R/strategy-helpers.R:204-206`); an omitted
  `state_update` retains the previous state (`R/fold-engine.R:1509-1511`);
  D4's fraction rule matches the prototype
  (`R/zz_grammar_prototype.R:123` on `spike/strategy-grammar`).
- **Anchors:** all 23 contract rule-group anchors and 4 RFC-index anchors
  resolve.

## Findings

### FR1 (Medium, maintainer disposition): a logical keep plus `index_leavers = "sell"` is a new contradiction rule

D3 says "A logical keep overlapping a resulting sale is contradictory." The
binding inputs say a logical mask does not *decide* a leaver (decision 7);
they do not say it *conflicts* with the leaver policy. The new rule fails a
natural idiom:

```r
ledgr_target_rebalance(ctx, weights, keep = ctx$held & !exit_signal,
                       index_leavers = "sell")
```

Any held leaver without an exit signal is both kept by the mask and sold by
the policy, so the run errors, and the author must add `& ctx$member`.

Two consistent options:
- **A. Precedence, specific over general:** a named keep beats
  `index_leavers`, which beats a logical keep mask. The call above sells
  leavers and keeps other unsignalled holdings. Claude recommends this: it
  reads as written, and the leaver policy is the more specific instruction
  for leavers.
- **B. Keep the synthesis rule:** the overlap is an error with a teaching
  message naming `& ctx$member`. Stricter; one more thing to learn.

### FR2 (Low, record): `holding_value` has no registered evidence

D1 binds `holding_value`, which stage 5 did not implement (response Q5).
Section 4 item 1 or 3 should name it: valuation mark used, zero when unheld,
and the unavailable-mark failure.

### FR3 (Low, record): keep the raw-target rounding notice to one line

D8 requires reporting that rounding intent is unavailable for raw quantity
returns. Correct, but a strategy that never uses the helpers would see that
notice on every run. The spec cut's field design (Section 6, item 2) should
state it once per run, not per decision.

## Review record

One Type 1 final review; one finding for maintainer disposition, two
record-only notes. No design reopened.
