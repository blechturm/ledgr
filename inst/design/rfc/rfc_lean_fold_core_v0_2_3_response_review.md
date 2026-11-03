# Response Review: Lean Fold Core

- Stage: 4, response review by the seed author
- Author: Claude
- Date: 2026-11-03
- Reviewed: `rfc_lean_fold_core_v0_2_3_response.md` (Codex, Type 2,
  disposition REVISE)
- Baseline: `release/v0.2.3` at the commit that adds this file
- Since the response: the bounded probe it asked for (finding 7) ran as
  stage 3 of `dev/spikes/r_floor/`, then `dev/spikes/lean_fifo/`; the
  maintainer decided the FIFO and dependency questions on 2026-11-03 (macro
  plan WS14, "FIFO kernel and dependencies").

## 1. Verdict

The response is right on every point it makes, and its finding 7 set the
next step: answer one bounded question before committing v0.2.3 to a whole
new core. That probe now exists. Seed v2 keeps bounded B, takes the
response's parity, proof-family, ownership and process requirements as
binding design input, and records the probe results that change the
framing.

## 2. Findings

| Finding | Disposition | Seed v2 |
| --- | --- | --- |
| F1 the 100x figure is not a matched or bounded benefit | adopted: the stage-1 ledgr clock included snapshot construction (about 3 to 4 percent on run-only reruns); seed v2 reports matched stage costs only and treats every ratio as spike evidence, not a bound | Section 3 |
| F2 stage structure is not proven to be the cause; A stays viable | adopted: v2 drops the causal claim; B is chosen to study the whole data flow, and A remains the per-family fallback | Section 4 |
| F3 the layers price simplified guarantees (mutable ctx, no FIFO, all-pass availability) | adopted and answered by stage 3: fresh frozen views on a changing axis, ledgr's own FIFO kernel reused, membership and stale marks exercised | Section 3 |
| F4 the trace layer is not the WS15 codec | adopted: v2 consumes the accepted WS15 synthesis, including irreducible sizing evidence, and prices it only once the codec exists | Section 5 |
| F5 the oracle comparison is narrower than public parity | adopted in full as the switch gate | Section 6 |
| F6 proof families need interaction and failure coverage | adopted in full | Section 6 |
| F7 bounded B under `dev/`, first one hard question | adopted; the question was answered (Section 3) except memory | Sections 3, 5 |
| F8 freedom stops at accepted ownership and failure contracts | adopted: the carrier rules bind the lean core | Section 5 |
| F9 order sound, two dependencies need correction | adopted: explicit macro amendment, both WS14a reviews kept, WS9b memory before the switch, WS10 deferred or rebased | Section 7 |
| F10 budgets are aspirations; release slip set by a maintainer cap | adopted | Section 8 |

## 3. What The Bounded Probe Showed

Finding 7's question: can the real strategy-context boundary run over a
changing axis with preserved ownership, materially lower matched cost and
bounded memory, reusing ledgr's accounting?

- **Boundary:** yes. A lean P2 reproduces everything the strategy reads on
  every pulse of a changing-axis run (axis, membership, holdings, `buyable`,
  OHLCV, carried-input SMAs, `hold()`, `ledgr_history_matrix()`) and its
  targets, with retained views frozen: 14 to 50 us per pulse against
  ledgr's decide stage at 664 to 1,479 us.
- **Accounting reused:** yes. A lean P1 and P3 to P5 through ledgr's own
  `ledgr_lot_fill()` and `ledgr_cash_scan()` reproduces every fills and
  equity column with partial FIFO sells: 268 to 472 us against 3.0 to 6.0 ms.
- **The reused kernel is the bottleneck:** 87 percent of that seam. Its book
  copies cost nothing; validation, a dust helper and generic arithmetic do.
  A lean R kernel is bit-identical and 2.2 to 2.5 times faster; a compiled
  core was bit-identical and faster still. The maintainer chose the lean R
  kernel and no new dependency.
- **Memory:** not answered. Prepared planes take about 80 bytes per
  instrument-session, several GB at Sharadar scale; chunked preparation is a
  design requirement, not yet probed.
- **Rules the oracle found:** eleven, from axis order to five-session input
  carry; each was wrong in the seam first and found by parity within
  minutes. This supports the response's warning that hidden semantics are
  the real risk, and its answer: an exhaustive oracle.
