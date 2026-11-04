# RFC: Lean Core Skeleton (v0.2.3), Maintainer Decisions

- Stage: maintainer decisions (stage 6), 2026-11-04. Input to the synthesis.
- Drafted by Claude from the maintainer's statement below. The maintainer
  kept D1 as the skeleton's minimal guard on 2026-11-04 and moved the full
  extension design into its own cycle (D2).

## D1. Built for what comes next, without building it

Maintainer statement: "we have to rewrite the core with a future OMS in mind
and it needs to be extensible for future order types, short selling, etc and
asset classes."

The lean core does not implement any of these now: principle 0 holds, and no
unused code path, generic metadata field or plugin layer is added. It must
not foreclose them either. Each of the four below must be addable later by
changing the stages and structures named for it, without reshaping the
others:

| Future capability | Existing authority | What the lean core keeps open |
| --- | --- | --- |
| OMS (order intent, lifecycle, outstanding orders) | [OMS synthesis](rfc_ledgr_oms_seed_synthesis.md) Sections 3 and 6: an internal layer between target deltas and ledger writing; `order_events` as a second append-only stream; outstanding-order accounting for paper and live | The plan-to-apply handoff is an order-shaped record (instrument position, side, quantity, order type, timing); today the only type is the market next-open order, filled in the same pulse. Order state that outlives a pulse can be added to fold state without changing P2 or the lot kernel. |
| Order types beyond market next-open (limit, stop and similar) | OMS synthesis Sections 5 and 6.3 | Fill resolution is one stage reading prepared bar planes by index, so a type that needs high, low or a later session reads the same tiles. |
| Short selling and leverage | [Shorting and leverage contract](README.md#shorting-leverage-contract) obligation; `contracts.md` short-exposure rule (new or enlarged short exposure refused; existing short holdable and coverable) | Quantities, lots and openings stay signed as the current lot input already allows (`contracts.md`, lot input row); short refusal stays a rule in target validation, not a property of the data shape. Borrow and financing arrive as typed accounting events. |
| Other asset classes (futures, FX, crypto, others) | [Cross-asset accounting events](README.md#cross-asset-accounting-events) and [asset precision and tradability](README.md#asset-precision-tradability) rows | Per-instrument terms that valuation, costs and sizing would need (for example multiplier, currency, quantity precision) are typed per-instrument columns of the prepared run, read by index, if and when a contract adds them; nothing assumes a term is absent by inlining a constant across stages. New accounting-critical events follow the cross-asset route: typed fields, vocabulary entries, schema reset. |

**Check.** The synthesis, and every family close after it, answers for each
of the four rows: which stage and which structure would change, and confirms
that no other stage would. An answer that needs a second engine, a mode
branch, or a rewrite of P2 or the lot kernel is a finding.

## D2. The extension design gets its own cycle, and gates skeleton code

Maintainer statement: "the goal here is to be able to extend the core easily
and cleanly in the future to approach feature completeness for a
backtesting/trading framework. it needs to be clean and maintainable, so we
need to plan how to extend the core as well."

- How the core is extended (extension points, how a new order type, position
  rule, asset class or accounting event is added, and what feature
  completeness means for ledgr) is decided by a separate RFC, the
  [core extension architecture](README.md#core-extension-architecture)
  cycle, seeded from ledgr's own corpus without an external research stage.
- This skeleton RFC keeps D1 as its minimal guard and does not grow into that
  design.
- No lean-core code is written until the extension RFC is accepted. If its
  synthesis changes a structure this RFC binds, this RFC's synthesis is
  amended before coding.
- Stage parity before end-to-end parity, and the stage recorder in the first
  checkpoint, are routed in macro plan WS16 (2026-11-04) and bind this RFC's
  first checkpoint.
