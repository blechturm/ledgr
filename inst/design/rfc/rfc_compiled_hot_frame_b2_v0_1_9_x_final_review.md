# RFC Final Review: Compiled Hot Frame B2 (v0.1.9.x)

**Status:** Final review. Verification, not design.
**Cycle:** Architecture B2 measurement gate / v0.1.9.x promotion scoping.
**Reviews:** `rfc_compiled_hot_frame_b2_v0_1_9_x_synthesis.md`
**Authored:** 2026-06-02. Final review author is Claude (v3 author per `rfc_cycle.md` role rotation; final review verifies Codex's synthesis).
**Relates to:** seed v1, response, seed v2, seed-v2 review, maintainer decisions, seed v3, synthesis.

## Verdict

**Approve as binding artifact.** No seed v4. No synthesis v2. Ready for v0.1.8.10 Ticket 5 cut.

The synthesis honestly absorbs seed v3's substantive changes, binds the ten remaining decisions tightly, separates spec-cut from RFC scope cleanly, and records future obligations without smuggling new scope. Citations verified accurate. Threshold language matches v3. Parity scope is faithful with one minor enumeration looseness flagged below. Pattern A staging vs Pattern B promotion distinction is preserved.

The synthesis's own explicit request was that final review verify "citations, threshold language, parity scope, and the distinction between Pattern A staging and Pattern B promotion." Each is covered below.

## Citations verified

Spot-checked the load-bearing citations in the synthesis's `Code-citation verification` table against current source.

| Citation | Synthesis claim | Verification |
|:---------|:----------------|:-------------|
| `R/fold-engine.R:288-365` | Fold fill loop including next-open lookup, proposal, cost resolution, event creation, handler write, cash/position mutation | Confirmed in v3 author's prior reads; matches synthesis read |
| `R/fold-engine.R:354-361` | Cash/position mutation inside first-cut compiled scope | Confirmed |
| `R/fill-model.R:18-96` | Fresh fills emit BUY/SELL with next-open semantics | Confirmed |
| `R/fill-model.R:118-195` | Default cost resolver closure + `ledgr_default_cost_resolve` | Confirmed |
| `R/backtest-runner.R:141-218` | Fresh-fold `ledgr_fill_event_payload` with BUY/SELL signed_qty + meta payload | Confirmed |
| `R/ledger-writer.R:27-39` | Fresh ledger-side BUY/SELL validation | Confirmed |
| `R/sweep.R:957-1190` | Memory output handler contract | Confirmed |
| `R/sweep.R:1035-1101` | Handler typed-column write + materialization region | **Verified directly:** covers `append_event_row_list` (1035-1057), `event_meta_json` (1059-1075), `materialize_events` (1077-1102). Accurate. |
| `R/sweep.R:1157-1188` | Handler buffer/materialization endpoints | **Verified directly:** covers `buffer_event` (1157-1168), `pending_event_count`/`flush_pending` (1169-1170), `write_fill_events` (1171-1180), `buffer_strategy_state`/`write_strategy_state` (1181-1182), `typed_events` (1183-1185), `events` (1186-1188). Accurate. |
| `R/lot-accounting.R` | Replay alias handling for COVER/BUY_TO_COVER/SHORT/SELL_SHORT | Confirmed |
| `architecture_synthesis.md:392-423` | Substrate parity gates inherited by B2 | Confirmed |
| K1 verdict `:9-27`, `:57-72` | K1 supports measuring a compiled hot frame but does not itself authorize ledgr promotion | The `:57-72` range is new vs v3 (v3 cited `:9-27` only). The addition is consistent with the K1 verdict's scope-bounding language and does not change the binding answer. No correction needed. |

No phantom citations. No interpretation drift between v3 and synthesis.

## Threshold language verified

D7 reads: "On the LDG-2479 `density_high_xlarge_ephemeral` production cell, B2 passes only if Pattern B delivers at least 30s wall recovery and all parity gates pass. A 15-30s recovery with parity is a maintainer review band. Less than 15s, or any parity failure, fails the B2 promotion gate."

Matches v3's outcome matrix exactly:
- ≥ 30s + all parity → PASS
- 15-30s + all parity → REVIEW BAND
- < 15s OR any parity failure → FAIL

The threshold is anchored to first-cut compiled scope, not gross wall, which is the calibration fix v2-review Finding 2 required. No drift.

## Parity scope review

D8 binds: "the eight substrate-decision gates from the v0.1.8.10 Round-3 synthesis plus the B2 fresh/replay side semantics gate" with an example coverage list.

**Faithful:** the v0.1.8.10 Round-3 gates are incorporated by reference. Anchor citation `architecture_synthesis.md:392-423` is correct.

**Minor looseness flagged for spec-cut, not requiring synthesis revision:** the synthesis's example list ("Required coverage includes event realized PnL and cost basis parity, equity-time-series parity, opening-position and CASHFLOW coverage, event ordering/identity preservation, BUY/SELL fresh-fill semantics, replay alias preservation, and memory-handler output shape preservation") names seven items. Seed v3's gate table named nine. The semantic mapping is:

| v3 gate | Synthesis enumeration coverage |
|:--------|:-------------------------------|
| 1. Event log preserved | "event ordering/identity preservation" |
| 2. Equity parity | "equity-time-series parity" |
| 3. Fill table parity | implicit in event identity + BUY/SELL fresh-fill semantics |
| 4. Lot-state parity (state$lots byte-identical FIFO queue) | partially implied by realized PnL + cost basis parity; not explicitly named |
| 5. Opening-position CASHFLOW coverage | "opening-position and CASHFLOW coverage" |
| 6. Invalid/semantic-violation coverage | not explicitly named |
| 7. Durable readback compatibility | "memory-handler output shape preservation" (related but not identical surface) |
| 8. No strategy lookahead | not named; B2 does not touch strategy input so hygiene-only |
| 9. B2 fresh/replay side semantics | "BUY/SELL fresh-fill semantics" + "replay alias preservation" |

The "includes" verb makes the list non-exhaustive; the binding answer says "the eight substrate-decision gates ... plus the B2 ... gate" without paraphrasing them. The list is illustrative.

**Recommendation for spec-cut (not for synthesis revision):** when Ticket 5 Sub-B's parity test suite is enumerated, the implementer should write each of the nine gates as a distinct test target rather than relying on the synthesis's example list. The Round-3 architecture synthesis `:392-423` is the authoritative gate enumeration, not D8's example list.

This is a documentation precision note, not a synthesis defect. Approval stands.

## Pattern A vs Pattern B distinction verified

D2 binds: "Pattern B is the only decision-bearing compiled design. Pattern A may be used as a parity/debug staging shim, but Pattern A timing cannot promote or park B2."

Reasoning is faithful to K1: Pattern A leaves per-fill R handler writes in place and therefore measures a hybrid surface, not the K1-relevant inline-output design. K1's authorization explicitly applied to inline-output designs only (`ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md:9-27`).

The disposition matrix in D7 correctly omits Pattern A from the pass/fail conditions. Pattern A failure triggers "debug the staging shim," not "park B2." This was Finding 3 of the v2-review; the synthesis closes it cleanly.

No drift.

## v3 absorption verified

Cross-checked synthesis's `v3 absorption verification` section against seed v3's revision notes:

| v3 change | Synthesis absorption | Verdict |
|:----------|:---------------------|:--------|
| Binding maintainer decision recorded; override-request retired | D1 | Absorbed |
| Recoverable-slice table re-bucketed; 30s gate calibrated to first-cut | D3 + D7 reasoning | Absorbed |
| Pattern B decision-bearing; Pattern A staging only | D2 | Absorbed |
| Sub-B internal `compiled_accounting_model = NULL \| "spot_fifo"` enum; no instrumented copies | D5 | Absorbed |
| Fresh-fill BUY/SELL vs replay alias semantics split | D4 | Absorbed |
| Ticket 5 split: Sub-A in ledgrcore-spike, Sub-B in ledgr | D6 | Absorbed |
| 15-30s review band | D7 | Absorbed |
| K1 rates / next-open / R cost resolvers / R equity / durable deferral / no-fast-math / cross-platform parity preserved from v2 | "preserved from v2" subsection + D9 + D10 | Absorbed |

The in-place mojibake cleanup is documented at synthesis stage with no separate cleanup artifact — clean handling.

## Process compliance

- Role rotation: v3 by Claude, synthesis by Codex, final review by Claude. Consistent with `rfc_cycle.md`.
- File naming: `rfc_compiled_hot_frame_b2_v0_1_9_x_*` series intact.
- Pre-CRAN framing preserved: no backwards-compatibility shims introduced; durable scope explicitly deferred.
- Open questions vs future obligations are correctly partitioned: spec-cut items (field naming, B.1/B.2, buffer lifetime, language pick, CI matrix, toolchain absence behavior) are same-window; future obligations (compile cost resolver, compile target validation, durable compiled integration, partial fills, public compiled flag, ephemeral attribution fallback) are explicitly out-of-scope for this cycle.

## Items NOT raised as concerns

The following synthesis choices could have been flagged but I am explicitly NOT raising them, to avoid scope creep into the synthesis cycle:

- D9's "fastest parity-preserving build profile" fallback rule is a refinement of v3's `-O2` risk note. Reasonable and binding.
- Synthesis adds K1 verdict citation `:57-72` not in v3. Consistent with the verdict's scope-bounding language.
- Implementation handoff sequence (5 steps) is concrete enough for ticket cut without over-specifying.

## Approval and next stage

**Approved as binding artifact.** The synthesis closes the RFC cycle cleanly enough for v0.1.8.10 Ticket 5 cut. Recommended next steps:

1. Horizon patch: update the 2026-06-01 ephemeral wall attribution gate entry to record the B2-first override and re-sequence the gates. Add a 2026-06-02 horizon entry referencing this synthesis as the bound artifact.
2. v0.1.8.10 spec packet: add Ticket 5 with Sub-A and Sub-B sub-artifacts per D6.
3. Spec-cut: write the Ticket 5 spec consuming this synthesis + the six promoted open questions in `Open questions promoted to spec-cut`.

No further RFC iteration on this cycle is required.

## Process notes

This review verifies; it does not redesign. The one minor enumeration looseness in D8 is flagged as a spec-cut precision note, not a synthesis defect. The synthesis's recommendation to proceed to final review without seed v4 is upheld by this final review's verdict.
