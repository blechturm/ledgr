# Codex Review: v0.1.8.10 Spike Round Architecture Synthesis

**Verdict:** Reject pending Round-2 synthesis.

The spike measurements are useful, but the Round-1 synthesis over-binds two
implementation tickets from evidence that does not match the current production
code. The largest issue is Ticket 1: the synthesis says fold-time inline
capture can emit realized PnL / cost basis because the fold engine already
computes them. It does not. Those values are first produced by reconstruction
lot replay, so the proposed ticket is not just "emit already-computed values";
it moves or duplicates lot accounting into the fold path. The second ticket has
a smaller but still scope-changing contract issue: the next-bar fill proposal
does not consume only `open`, and the cited file does not exist. These findings
should change v0.1.8.10 ticket cut before scope is bound.

## Blocking Findings

### 1. Ticket 1 assumes realized PnL / cost basis already exist during the fold; they do not

**Claim being challenged:** `architecture_synthesis.md:55-61`

> capture per-pulse equity + per-fill realized_pnl / cost_basis in the memory
> output handler during the fold ... The fold engine already computes both
> values; the change is emitting them to the handler instead of recomputing them
> post-fold.

**Evidence:**

- `R/fold-engine.R:295-306` builds and resolves a fill proposal, then
  `R/fold-engine.R:354-361` updates `state$positions` and `state$cash`. There
  is no lot-state update and no call to `ledgr_lot_apply_event()` in this fold
  path.
- `R/backtest-runner.R:183-188` writes event metadata with
  `realized_pnl = NULL`; the write result at `R/backtest-runner.R:206-218`
  returns `cash_delta`, `position_delta`, `meta`, and `row`, not cost basis or
  realized PnL.
- `R/fold-reconstruction.R:453-504` is where
  `ledgr_sweep_summary_from_ordered_events()` creates `reconstruction_lots`,
  calls `ledgr_lot_apply_event()`, and derives `event_realized`,
  `event_cost_basis`, and OPEN/CLOSE fill rows. That is the work Ticket 1 is
  trying to bypass.

**Why this changes scope:**

Inline equity capture is plausibly additive: cash and positions are already
available during the fold. Inline lot-state capture is not additive in the same
way. It requires either:

1. moving FIFO lot accounting into the fold engine / memory output handler; or
2. introducing a second inline lot-state path whose parity against
   `ledgr_lot_apply_event()` must be proved.

Either path shifts work from results/reconstruction into engine time. The
current synthesis treats the 93% lot-replay slice as eliminated, but if the same
lot machinery runs during the fold, total wall recovery is smaller than the
results-phase reduction unless the inline path is structurally cheaper.

**What the synthesis should say instead:**

Ticket 1 should be split conceptually into:

- telemetry-first production attribution;
- inline equity capture, using state that already exists during the fold;
- inline lot-state accounting, which is a semantic move of FIFO lot machinery
  into the fold path and needs byte-identical parity gates against the existing
  reconstruction outputs.

The ticket can still be one implementation ticket if that is operationally
cleaner, but the synthesis should not claim realized PnL / cost basis are
already computed by the fold engine.

**Severity:** Blocking. This changes implementation scope and expected wall
recovery for the lead v0.1.8.10 ticket.

### 2. Ticket 1's recovery projection uses a stale pre-v0.1.8.9 production anchor

**Claim being challenged:** `architecture_synthesis.md:245-249`,
`architecture_synthesis.md:340-355`, and `architecture_synthesis.md:442-449`

The synthesis uses the LDG-2476 "40.9s reconstruction at 68k events" anchor,
scales it to `~80s`, and projects `density_high_xlarge_ephemeral` from `~280s`
to `~195s`.

**Evidence:**

- The v0.1.8.9 closeout supersedes the LDG-2476 peer-benchmark anchor for
  current-source post-v0.1.8.9 planning. In
  `v0_1_8_9_release_closeout.md:95-100`, the post-v0.1.8.9 peer ephemeral row
  is already `92.61s` wall with `9.63s` results, not a 40.9s results phase.
- The closeout's residual target is not "known 40.9s reconstruction remains."
  It is phase visibility: `v0_1_8_9_release_closeout.md:143-145` says the
  workload-grid sweep rows need better phase telemetry for future ephemeral
  attribution.
- The current workload-grid post-v0.1.8.9 xlarge ephemeral wall from the
  closeout is `372.55s`, not `~280s`. The `~280s` number is the older
  peer-benchmark shape, not the LDG-2479 xlarge workload-grid cell.
- I replayed the actual post-v0.1.8.9 peer ephemeral fills
  (`dev/bench/results/peer_benchmark_record_20260601T073325Z_ledgr_ttr_canonical_ephemeral_fills.csv`)
  through `ledgr_lot_apply_event()` and measured max open lot depth of 1.
  That does not support the synthesis caveat that the random BUY/SELL fixture
  under-represents production lot-list depth for the production anchor it cites.
  It may under-represent other strategies, but not this measured SMA peer
  record.

**Why this changes scope:**

Spike 11 telemetry is not just "infrastructure to ship alongside." It is the
gate that tells us whether the post-v0.1.8.9 xlarge ephemeral results phase is
still large enough to justify inline lot-state migration. Without that
measurement, the `~80s` Ticket 1 recovery is not a current-source production
claim.

**What the synthesis should say instead:**

Ticket 1 should be `PROCEED IF` telemetry confirms current xlarge ephemeral
results/reconstruction remains material after v0.1.8.9. Recommended ordering:

1. land or stage Spike 11 subphase telemetry first;
2. rerun the LDG-2479 xlarge ephemeral cell;
3. only then bind the inline-state recovery range.

The LDG-2476 40.9s number can remain as historical motivation, but it should
not be used as the current post-v0.1.8.10 wall-projection anchor.

**Severity:** Blocking. This changes the lead ticket from a projected 80s
recovery lane to a telemetry-gated lane.

### 3. The next-bar matrix lookup ticket is under-scoped; the fill proposal does not consume only `open`

**Claim being challenged:** `architecture_synthesis.md:73-75`,
`architecture_synthesis.md:269-276`, plus the spike prompt's citation to
`R/fold-fill-proposal.R`.

The synthesis scopes Spike 6 as replacing the per-fill `next_bar` row subset
with scalar `bars_mat$open[inst_idx, i + 1]`.

**Evidence:**

- `R/fold-fill-proposal.R` does not exist. The actual implementation is
  `R/fill-model.R`.
- `R/fill-model.R:18-96` defines `ledgr_next_open_fill_proposal()`. It reads
  `next_bar$instrument_id`, `next_bar$ts_utc`, and `next_bar$open`; validates
  `instrument_id`, requires `ts_utc`, and constructs an `execution_bar` with
  optional `high`, `low`, `close`, and `volume`.
- `R/fill-model.R:105-116` requires `execution_bar` to include
  `instrument_id`, `ts_utc`, and `open`. `R/fill-model.R:148-160` passes that
  context to the cost resolver. The default resolver currently reads only
  `open` at `R/fill-model.R:178`, but the fill proposal contract is already
  wider than `next_open_price`.

**Why this changes scope:**

The matrix-canonical substrate can still remove the expensive data.frame row
subset, but the implementation is not a simple signature change from
`next_bar` to `next_open_price`. The ticket has to preserve fill-context
semantics for custom/future cost resolvers and the accepted cost-API boundary.

**What the synthesis should say instead:**

Spike 6 should be scoped as "construct a minimal execution-bar / next-bar
object from matrix-backed scalars" or "redesign fill proposal context with an
explicit contract review." At minimum, the ticket needs parity tests that prove
the proposal still carries `instrument_id`, `ts_utc`, `open`, last-bar
`NO_FILL` behavior, and optional OHLCV semantics where they are currently
observable.

**Severity:** Blocking. This changes the Ticket 2 contract edge and test
surface.

### 4. The L10 wall table implies false precision and subtracts Ticket 3 from a cell it may not affect

**Claim being challenged:** `architecture_synthesis.md:346-355`

The table projects:

| Cell | Pre-v0.1.8.10 | Ticket 1 | Ticket 2 | Ticket 3 | Projected |
| --- | ---: | ---: | ---: | ---: | ---: |
| `density_high_xlarge_durable` | 232s | - | ~5s | ~3s | ~224s |
| `density_high_xlarge_ephemeral` | ~280s | ~80s | ~5s | - | ~195s |

**Evidence:**

- Ticket 3 is explicitly described at `architecture_synthesis.md:294-295` as
  recovery on durable reopen / DB-replay paths. The table subtracts it from the
  fresh workload-grid durable wall without showing that the LDG-2479
  `density_high_xlarge_durable` run exercises the same read path at comparable
  frequency.
- The `~280s` ephemeral baseline is not the v0.1.8.9 closeout workload-grid
  baseline. The closeout recorded `density_high_xlarge_ephemeral` as `372.55s`.
- Per Finding 2, the `~80s` Ticket 1 recovery is not a current post-v0.1.8.9
  measured production claim.

**What the synthesis should say instead:**

The projection table should become a range table with explicit applicability:

- Ticket 2: likely `~5s` workload-grid recovery.
- Ticket 3: `~2-3s` read/reopen/DB-replay recovery unless a workload-grid run
  proves it affects fresh fold wall.
- Ticket 1: telemetry-gated; no current point estimate until xlarge ephemeral
  subphases are exposed.

**Severity:** Blocking for release planning language. It may not change code,
but it would mislead ticket cut and closeout expectations.

## Caveat-Worthy Findings

### 5. The "93% lot replay" decomposition is an inference across non-identical fixtures

**Claim:** `architecture_synthesis.md:41-45` and `architecture_synthesis.md:476-481`.

The caveat at the end acknowledges this, but the main L1 table presents the
split too cleanly. Spike 1's full reconstruction pass is `14.00s` on a
typed-meta fixture. Spike 10's lot-replay standalone is `16.52s` on a heavier
JSON-meta fixture. A component timing larger than the full-pass timing is a
signal that the percentages are directional, not decompositional.

Recommended wording: "lot replay is the dominant candidate within
reconstruction, inferred from separate fixtures" rather than a component table
that sums to the full pass.

**Severity:** Caveat-worthy. This becomes blocking only because Ticket 1 uses
the 93% as implementation-scope evidence.

### 6. Spike 6's 27x vs 166x difference is not just timer-floor noise

**Claim:** `architecture_synthesis.md:458-461`

The synthesis says the speedup shrink "looks like timer-floor noise." I reran a
local scalar matrix-loop check over 133k reads using pre-extracted integer
vectors; median wall was about `0.03s`, matching the v0.1.8.9 anchor rather
than Spike 6's `0.18s`.

That suggests Spike 6 Variant C includes fixture/data-frame indexing overhead
(`fills$inst_idx[[k]]`, `fills$pulse_idx[[k]]`) that production can avoid once
the actionable loop already has scalar `inst_idx` and pulse `i`. The wall
recovery claim (`~4.7s`) is still credible because Variant A is stable near
`4.87s`; the explanation should be "Variant C includes fixture overhead" rather
than "timer-floor noise."

**Severity:** Caveat-worthy.

### 7. Spike 2 should stay as fallback if Ticket 1 is telemetry-gated or blocked

**Claim:** `architecture_synthesis.md:123-127` and `architecture_synthesis.md:304`.

The direct code-path check supports Spike 2's measurement: its
`variant_a_current()` reproduces the production bucket loop at
`R/fold-reconstruction.R:512-526`, and `0.36s` at 130k events is genuinely
small. However, if Ticket 1 becomes telemetry-gated per Findings 1-2, Spike 2
is not fully "subsumed" yet. It is a low-priority fallback for the existing
reconstruction path if inline-state migration is deferred.

**Severity:** Caveat-worthy.

### 8. The spike-round method required "test fails against pre-fix"; the logs do not consistently show it

The round `README.md` asks each spike to verify a test that fails against the
current path and passes against the proposed replacement. Several spike logs
provide parity checks and timing tables but not an explicit "fails against
unfixed implementation" line. That is not fatal for exploratory spikes, but the
synthesis should not overstate this round as having the same regression-test
closure discipline as the implementation batches.

**Severity:** Nitpick / process caveat.

## Confirmed Claims

- **Spike 7's options-hoist diagnosis is correct.** `R/config-canonical-json.R:27-62`
  constructs `yyjsonr::opts_read_json()` and `opts_write_json()` inside helper
  bodies. A local 50k-construction timing showed `~0.95s` spent constructing
  read options versus `~0.11s` parsing 50k payloads with prebuilt options. This
  accounts for the measured helper-vs-direct gap.
- **Spike 2 faithfully measured the production bucket loop.**
  `R/fold-reconstruction.R:512-526` uses the per-instrument
  `which(events$instrument_id == id)` / `cumsum` / `findInterval` shape the
  spike isolated. The bucket loop really is small relative to reconstruction.
- **Spike 9's reframing is supported.** `R/feature-alias-map.R:11-104` shows
  normalization is not simply a per-pulse fold-engine cost; the repeated path is
  through feature lookup calls. The accessor RFC synthesis binds
  `ctx$vec$feature(feature_id)`, so parking Spike 9 behind bulk feature access
  is defensible.
- **Spike 4's parking is correctly bounded.** `R/fold-engine.R:181-194` is only
  the base list allocation; helper attachment happens at `R/fold-engine.R:196-220`.
  The synthesis correctly says the spike measured a sub-surface, not the whole
  pulse-context cost.
- **The v0.1.8.9 partial-setv doctrine is preserved where touched.**
  `R/fold-reconstruction.R:439-450` uses `collapse::setv` for POSIXct,
  integer, and numeric inline fill-buffer columns and base R for character
  columns. That matches the v0.1.8.9 correction for collapse character-vector
  safety.
- **The accessor/helper RFC dependencies are represented correctly.** The
  callback-contract synthesis binds `ctx$vec`, `ctx$idx()`, and
  `ctx$vec$feature(feature_id)`. The authoring-helper synthesis binds Pass 1
  only for v0.1.8.10, with new helper extensions deferred to v0.1.9.
- **K1 / `ledgrcore-spike` is correctly out of scope.** The synthesis's
  repo-split boundary matches the horizon framing.

## Suggested Additions

1. **Add a telemetry-first gate to Ticket 1.** The first production step should
   expose `t_engine`, `t_results`, and `t_fills_extract` for the workload-grid
   ephemeral rows, then rerun `density_high_xlarge_ephemeral`. Inline-state
   capture should proceed only if current-source results/reconstruction remains
   large enough to justify moving lot machinery into the fold path.

2. **Add a fill-model contract audit to Ticket 2.** Before replacing
   `next_bar` row extraction, write down the minimal preserved contract:
   `instrument_id`, `ts_utc`, `open`, optional OHLCV, final-bar no-fill
   behavior, and cost-resolver context. This avoids accidentally breaking the
   accepted cost-API direction while chasing the matrix lookup win.

3. **Record real production lot-depth evidence.** The peer 68k SMA production
   fill record had max open lot depth of 1 in my replay check. If the synthesis
   wants to claim production lot depth is deeper than the synthetic fixture, it
   should measure the LDG-2479 xlarge ephemeral sample or narrow the claim to
   "some future strategy shapes may have deeper lot lists."

4. **Reframe the post-v0.1.8.10 projection as Amdahl ranges.** Keep the
   durable `232s` and workload-grid ephemeral `372.55s` baselines separate from
   the peer-benchmark `118.79s` / `92.61s` shape. Do not mix the older LDG-2476
   `~280s` peer baseline into workload-grid planning.

5. **Keep Spike 2 as a fallback disposition.** It should remain parked while
   Ticket 1 proceeds, but if telemetry shows Ticket 1 is below threshold or
   lot-state migration is deferred, the small split/bucket cleanup is the
   standalone reconstruction-path fallback.
