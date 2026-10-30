# Probe findings: why PMwR is fast, and what ledgr can take from it

Probe of 2026-10-30, release/v0.2.3 at 145cc93b, installed from `git archive`
into a scratch library. Workload: the peer suite's normalized 500 x 1260 bars,
SMA 5/10 transition, unit quantities, next-open fills, zero cost, USD 10M.
PMwR 1.3.0 from the suite's isolated library. Runner: `probe.R`; numbers:
`timings.csv`; sampled profiles: `profile_*_total.csv`. Single runs on a
desktop host, not gate measurements. Rprof undercounts on this host (it
sampled 8.3 s of a 12.9 s sweep), so profile figures are shares, not seconds.

## What ran

| Run | Seconds | Fills | Final equity |
| --- | ---: | ---: | ---: |
| PMwR `btest`, both SMAs included (median of 5) | 0.59 | 67,725 | 10,728,507 |
| ledgr, no fills, no state, both features read (sweep / run) | 1.84 / 2.02 | 0 | 10,000,000 |
| ledgr, suite recipe, named-list state (sweep / run) | 15.00 / 20.21 | 67,725 | 10,728,507 |
| ledgr, same decisions, vector state (sweep / run) | 12.34 / 17.31 | 67,725 | 10,728,507 |
| the same, compiled spot-FIFO sweep | 8.88 | | 10,728,507 |
| durable fill reader after the run | 3.49 | | |

The final equity agrees exactly with PMwR. With the no-fill floor subtracted,
ledgr pays about **155 us per fill** in a sweep, **104 us** with compiled FIFO
and **226 us** for a durable run, plus 52 us per fill in the fill reader. PMwR
does all of its work, including both SMAs, in under 9 us per fill. **The gap is
per fill, not per pulse:** ledgr's floor of 1,260 pulses with no fills is 3x
PMwR's total, which is a reasonable cost for building a context per pulse,
point-in-time access and validation.

## Why PMwR is fast (source: `PMwR::btest`, 628 lines of plain R)

1. **State is only what the next decision can see.** That is a preallocated
   T x n position matrix, plus cash and wealth vectors. Each bar writes one row.
2. **A bar's trades are one vector.** It computes `dx <- Xs[t,] - X[t-1,]` and
   cash as `cash - dx %*% open`, then sets `X[t,] <- X[t-1,] + dx`. Fifty fills
   cost about what one costs.
3. **No fill objects exist during the loop.** The journal is derived once at
   the end from `diff(X)`, looping over instruments, not over fills.
4. **The signal reads precomputed matrices by row**, through closures. No
   per-bar context object, no validation, no serialization, no persistence.
5. **No lots and no realized P&L.** Caveat: the journal price is the close
   while cash trades at the open, so PMwR's journal price is not its execution
   price. The suite already classifies PMwR as agreeing on decisions only.

## Where ledgr's per-fill time goes (sampled shares of the fold)

Canonical-R sweep:
- **Apply stage, 50%:** `ledgr_lot_apply_fill` 19%, `ledgr_fill_event_payload` 15%.
- **Plan stage, 26%:** `ledgr_next_open_fill_proposal` 15%.

`ledgr_fold_build_pulse_plan` (`fold-engine.R:143`) and
`ledgr_fold_stage_apply` (`fold-engine.R:1342`) loop in R once per fill. Each
fill builds a proposal object and resolves it through the cost model. It then
updates the lots, writes the event, records the accounting fact and recomputes
the position from the lots: about ten R calls and several list allocations per
fill.

Three findings inside that:
- **Timestamps are re-validated on every fill.** `ledgr_ts_utc_posix` and
  `ledgr_assert_whole_second_utc` take 11–13% of sampled fold time, both for
  canonical R and for compiled FIFO. The pulse axis is already validated when
  it is built.
- **Compiled FIFO moves lot state across the R/C++ boundary every pulse.**
  Packing and unpacking the lots take 18% of the compiled run. The accelerator
  saves 3.5 s, but the copying eats part of the gain.
- **The durable path runs FIFO three times:** in the fold, in finalisation,
  and again in the fill reader. `ledgr_replay_accounting_events` is 23% of the
  durable profile, and canonical JSON is another 10%.

Strategy state written as a named list of 1,000 scalars adds 2.7 s, about 20%.
This cost comes from the recipe, not the engine. PMwR's recipe avoids it by
precomputing `above` as a matrix.

## What the spec may consume

Against the v0.2.3 macro plan, most levers are already planned. The probe
supplies their sizes on a wide all-fill shape.

| Insight | Owner in the macro plan | Note |
| --- | --- | --- |
| Remove per-fill objects: plan and apply one pulse's fills as vectors | WS4a typed carrier | A columnar batch filled by a per-fill R loop still pays the per-fill calls. The carrier's producer must be vectorized across instruments, PMwR's step 2, or most of the gap stays. Fills in one pulse touch distinct instruments, so they are independent. |
| Validate timestamps once, at the pulse axis | WS4a, or a direct ticket now | About 1 s on this workload; the smallest standalone lever. Optimization coding style: validation belongs at boundaries. |
| Apply lots per pulse, not per fill; recompute positions once per pulse | WS4a, with WS7/WS8 | The accepted typed-accounting synthesis keeps lots as the only position authority (3.2) and rejects `position_delta` as an authority (dust divergence). So PMwR's `X + dx` is not available; a batched lot kernel is. |
| Keep compiled lot state native across pulses | compiled envelope; out of scope for WS7/WS8 | Measured here; it needs its own decision. |
| One FIFO replay, no per-fill JSON | WS7/WS8 (accepted) | Confirmed: the reader costs 52 us per fill, and finalisation replays too. |
| Typed vector state in the authoring API | WS5 declared state | Named-list state costs about 20% here. Docs should not teach it. |

**Recommendation:** use this probe as input to the WS4a profile probe and RFC,
not as a separate spike; it already measures the wide all-fill shape that
WS4a's gate names. WS4a's gate should record **per-fill marginal cost** on this
workload against the no-fill floor, so a carrier that is typed but still loops
per fill in R cannot pass unnoticed. A follow-up spike is warranted only if
WS4a's RFC wants evidence that a vectorized plan-and-apply stage keeps event
order and economics byte-identical. That spike would ask one question with one
kill condition: does per-fill cost fall below a stated bound on this workload
with A0 unchanged?

## Addendum: the availability no-fill floor (2026-10-30)

`floor_state_profile.R <out> <lib> availability|dense` runs a no-fill sweep
whose strategy writes two logical state vectors every pulse. The
availability snapshot declares complete session and lifetime facts, as the
WS4a probe did. Wall: availability 7.99 s, dense 2.12 s, single runs. The
profiles use `event = "elapsed"` at 5 ms. Windows' 15.6 ms timer makes the
sampled time about a third of wall on both producers (factor 3.1), so the
stage seconds below are scaled shares. Files:
`profile_floor_state_{availability,dense}_total.csv`.

| Extra on availability | ~s | Cause |
| --- | ---: | --- |
| State JSON | +2.2 | `ledgr_fold_asset_state_normalize()` (`R/fold-engine.R:97`) pads an empty `asset_state` entry for all 500 instruments every pulse; `canonical_json()` then encodes it |
| Decide | +1.4 | general `ledgr_update_pulse_context_helpers()`, not dense's fast helpers |
| Feature setup | +0.8 | history-substrate precompute |
| Observe and settle | +0.7 | per-pulse valuation and carry |
| Diagnostics | +0.5 | per-pulse block flush, including the reconciliation record |
| Plan | +0.3 | |

The reconciliation's JSON detail record is small, and target validation
costs the same on both producers.

## Open

- Floor profile (`profile_floor_total.csv`, no fills): about 45% is one-off
  setup (feature precompute through the generic series path, bar fetch,
  snapshot hold, store checks); about 55% is the fold, mostly the decide
  stage, where refreshing the pulse context helpers is the largest item.
  Unprofiled in detail.
- Single runs only; repeats and the shared harness come with any gate.
- Whether the business objective or risk chain needs per-fill lot facts in the
  fold was checked only by grep. Strategy `ctx` does not read lot state.
