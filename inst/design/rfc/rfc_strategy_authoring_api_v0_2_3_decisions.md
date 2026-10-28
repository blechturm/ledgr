# Strategy Authoring API: Response Review And Maintainer Decisions

2026-10-28. RFC-cycle stages 4 and 6 for the strategy authoring API. Input
to the synthesis, which the cycle's role rotation assigns to Codex (Claude
wrote seed v2). Inputs: [seed v2](rfc_strategy_authoring_api_v0_2_3_seed_v2.md),
[response to v2](rfc_strategy_authoring_api_v0_2_3_response_v2.md), and the
v1 seed and response.

## 1. Response review (Claude, seed author)

The v2 response is sound; its evidence reproduces. Recommended dispositions:

| Finding | Disposition |
| --- | --- |
| R1 declared state | **Accept.** Helper returns are declared-field patches resolved at the fold normalization boundary; raw `state_update` stays complete replacement validated against the declared schema; `reset_state = TRUE` restores declared defaults and cannot combine with field updates; asset and portfolio names share one namespace; result-role names are reserved; only unnamed scalars broadcast; `NaN` and infinity are rejected before `NA` means reset; undeclared persisted fields are rejected; defaults are a flat `list()` so types survive, normalized before identity hashing. These become acceptance tests of the implementation cut. |
| R2 fills-only facts | **Accept.** Seed v2's "rebuilt from fills" claim is wrong: a cash acquisition closes a holding with zero fills. Entry and exit bars update from fill transitions classified against the canonical book; non-fill events that open or close a holding have specified invalidation; rebuild replays the committed accounting-event prefix through the existing rebuild core. No second replay engine. Teach `entry_price` (remaining FIFO basis) and `entry_at` (bar label) literally, next to the first percentage stop. |
| R3 Turtle sizing | **Accept.** Ordinary quantity steps reproduce all 741 Turtle fills; no bounded-weights helper, levered weights or `fit_to_remaining`. Weight validation stays strict. The unpriced-weight reservation case is specified in the synthesis. |
| R4 fail-closed teaching | **Accept**, with maintainer decisions 6 and 7 below. Leaver policy is taught in the first indexed-universe recipe; `adjust` has no `index_leavers`. |
| R5 flat reader, ctx-first | **Accept.** The pipe may also feed the verb by placeholder; teaching starts with a named `weights` step. |
| Q4 facts across windows | **Accept.** Position facts follow the economic book across a contiguous carried chain; declared strategy state resets between windows as the contract requires. Resume and candidate isolation need explicit cut tests. |
| Q5 internals | **Accept.** One public reader and one eligibility plane; a private lazy `vec` adapter may remain temporarily without public promise. `holding_value` is a proposal the cut must implement and test. |
| Q6 mixed cadence | **Accept.** A pure predicate over existing schedule semantics, e.g. `ledgr_schedule_due(ctx, month_end)`, before CRAN, with an executed off-month-end stop example. |
| Q7, Q8 | **Accept.** Advisory preflight only; no decision-graph promise. |

## 2. Maintainer decisions

Earlier decisions stand: capital base only where it changes the answer
(2026-10-27, decision 1) and no default sale of index leavers (2026-10-27,
decision 2).

Decided 2026-10-28:

1. **`adjust` capital base.** Defaults to total equity, disclosed;
   `capital_base = "remaining_equity"` is the override. `rebalance` keeps
   decision 1.
2. **Position facts.** ledgr provides `entry_price`, `entry_at`, `exit_at`,
   `bars_since_entry` and `bars_since_exit`. `peak_since_entry` is not
   provided; it stays in strategy state. Facts never carry calendar units,
   because intraday support is planned.
3. **Bar counts** use the run's calendar bars, skipped decisions included.
4. **Fact definitions.** `entry_price` is remaining FIFO basis over quantity;
   `bars_since_exit` is `Inf` when never exited; holdings supplied by the
   opening have no entry time or age.
5. **Ledger facts are tracked at fill time and derived on read** (refined by
   R2: classified against the accounting-event book).
6. **Negative selection counts are an error.** `n = 0` selects nothing;
   authors clamp with a named step where negatives are expected
   (`open_slots <- max(0, params$slots - sum(still_held))`).
7. **`keep` by asset name decides a leaver.** `keep = "STK04"` satisfies the
   index-leaver requirement for STK04. A logical mask such as `keep =
   ctx$held` does not; unmentioned leavers still raise the teaching error.
8. **The experiment requires capital and costs.** Both describe the investor,
   not the machinery, and their right values depend on who runs the
   experiment; everything about the machinery has disclosed defaults. A
   cash default may be added later if demand appears. The missing-value
   error explains what the value is for.
9. **Rounding is disclosed.** The run summary and `print()` report targets
   rounded to zero shares and invested against intended exposure. This is an
   acceptance criterion of the implementation cut. Fractional shares belong
   to the [asset-precision RFC](README.md#asset-precision-tradability).
10. **Teaching by pattern.** Fixed mix, filter, rank and rotate, slots,
    preservation, position rules and memory, in one executed article; each
    example passes the maintainer's cold read as an acceptance criterion of
    the implementation cut (roadmap, Research UX completion).

11. **Leaver precedence (final review FR1).** Specific over general: a
    character `keep`, then `index_leavers`, then a logical keep mask. A
    logical mask overlapping a leaver sold by `index_leavers = "sell"` is
    not a contradiction.

## 3. Peer evidence for decision 8

Read from installed sources: backtrader defaults to 10,000 cash and whole
shares; bt to 1,000,000 with `integer_positions = TRUE`; PMwR to
`initial.cash = 0`. From memory, unverified here: zipline-reloaded requires
`capital_base`; LEAN and PyBroker default to 100,000 with whole shares. None
of the inspected peers reports rounding.
