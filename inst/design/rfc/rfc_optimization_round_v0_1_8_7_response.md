# RFC Response: v0.1.8.7 Optimization Round

**Stage:** Response (stage 3)  
**Author:** Codex  
**Date:** 2026-05-29  
**Responds to:** `rfc_optimization_round_v0_1_8_7_seed.md`

## Verdict

Accept the direction, but require a seed v2 before synthesis.

The seed is evidence-aligned on the major shape: v0.1.8.7 should stay
single-core pure R, attack ledgr-owned machinery rather than user callbacks,
start with the event-emission/buffer lane, and keep determinism as the hard
constraint. The spike reconciliation work is reflected correctly: no large
measured callback floor, buffer hotness is production-profile evidence, the
low-turnover rock is representation/formatting rather than ctx-build, and sweep
crossover remains open.

The seed needs v2 for three reasons:

1. the wall-trajectory table is too point-estimate-heavy and likely overstates
   the independently evidenced Lane R contribution on turnover runs;
2. Lane R needs a sharper identity boundary: event/equity timestamp formatting
   is in scope, but durable snapshot/config/provenance hash formatting must be
   preserved or explicitly excluded;
3. the collapse determinism gate should pin `stable.algo` or the full
   `set_collapse()` state, not only `nthreads`, `na.rm`, and `sort`.

No second response round is needed if v2 addresses those points. A maintainer
decision is needed only if v2 wants to change event-id strings or sub-second
timestamp policy; otherwise v2 should bind preservation/rejection defaults and
proceed to synthesis.

## Claim Verification

### Buffer and event-emission sites

The seed's buffer references are accurate.

- The fold computes the worst-case buffer capacity as
  `length(pulses_posix) * length(instrument_ids)` and passes it to the output
  handler at `R/fold-core.R:72-73`.
- The durable handler allocates one full column per ledger-event field at
  `R/backtest-runner.R:365-379`.
- The durable handler writes each event field one by one at
  `R/backtest-runner.R:385-408`, with the per-field assignments at
  `R/backtest-runner.R:397-407`.
- The durable fill path calls `ledgr_fill_event_row()` and then
  `handler$buffer_event(write_res)` at `R/backtest-runner.R:441-442`.
- The sweep memory handler has the same per-event append shape at
  `R/sweep.R:750-770`, reached through `handler$buffer_event()` at
  `R/sweep.R:868-879` and the sweep fill writer at `R/sweep.R:882-890`.

The seed should continue to distinguish priority evidence from mechanism
evidence: production profiles make this lane the big rock; the exact
`O(fills^2)` mechanism is still to be confirmed by production re-profile after
the rewrite.

### Timestamp and formatting sites

The seed's timestamp-round-trip references are accurate.

- `ledgr_fill_event_payload()` normalizes `ts_exec_utc` and parses it back to
  POSIXct at `R/backtest-runner.R:176-177`.
- The same function serializes per-fill metadata at `R/backtest-runner.R:188`
  and constructs the event id with `sprintf()` at `R/backtest-runner.R:190`.
- `ledgr_normalize_ts_utc()` formats POSIXt inputs through
  `format(..., "%Y-%m-%dT%H:%M:%SZ")` at `R/pulse-context.R:619-625` and
  reparses/reformats character inputs at `R/pulse-context.R:642-647`.
- Fast fold contexts currently carry a precomputed `ts_iso` string into
  `ctx$ts_utc` at `R/fold-core.R:132-157`; the slower constructor and
  validation path still normalize at `R/pulse-context.R:1-29` and
  `R/pulse-context.R:650-677`.

One scope correction: the seed says "per-pulse equity/positions path" for the
empty-fold formatting evidence. The code path that writes the final equity
frame stores `pulses_posix` directly at `R/backtest-runner.R:1476-1485`. The
empty-fold profile still proves formatting is a hot low-turnover bucket, but v2
should avoid over-specifying the exact equity-row site unless the profiler maps
those samples to a concrete function.

### Reconstruction sites

The seed's reconstruction references are accurate.

- `ledgr_equity_from_events()` loops per instrument and rescans events with
  `which(events$instrument_id == id)` at `R/fold-core.R:500-513`.
- The sweep-summary reconstruction repeats the same per-instrument pattern at
  `R/fold-core.R:841-855`.
- `ledgr_fills_from_events()` row-subsets each event at `R/fold-core.R:574-581`,
  builds per-row data.frames at `R/fold-core.R:605-616`,
  `R/fold-core.R:623-634`, `R/fold-core.R:655-666`, and
  `R/fold-core.R:670-681`, then binds with `do.call(rbind, rows)` at
  `R/fold-core.R:688`.

The seed correctly treats this as read-back / reconstruction work, not the main
run-wall lane.

### Sweep feature-union amortization

The seed's sweep-amortization statement is directionally accurate, with one
minor citation nuance.

- `ledgr_sweep()` fetches and normalizes bars once at `R/sweep.R:94-111`.
- When `precomputed_features` is absent, the sweep resolves candidates once and
  builds one runtime projection from the unique candidate feature definitions at
  `R/sweep.R:115-126`; `ledgr_precompute_unique_feature_defs()` is invoked here,
  though its definition is not in `R/sweep.R`.
- Each candidate then receives the shared `runtime_projection` at
  `R/sweep.R:189-205`, installs it into the fold execution object at
  `R/sweep.R:634-654`, and reruns `ledgr_execute_fold()` at `R/sweep.R:662`.
- The feature-union metadata is computed at `R/sweep.R:243` using
  `ledgr_sweep_feature_union()`, defined at `R/sweep.R:1067-1073`, and attached
  at `R/sweep.R:256-257`.

So the seed is right: sweep amortizes feature precompute/projection, not the
per-candidate fold. No crossover claim should be made until the open
measurement lands.

### Durable identity formatting sites

Lane R has a broader blast radius than event/equity rows if it is phrased as
"remove timestamp formatting" globally.

Durable identity paths still depend on canonical string formatting:

- `canonical_json()` formats POSIXt values at
  `R/config-canonical-json.R:61-63`; this feeds config/provenance hashes.
- `ledgr_feature_cache_key_from_parts()` normalizes start/end timestamps and
  hashes canonical JSON at `R/feature-cache.R:101-119`. This is session-local,
  not durable provenance, but it is a current cache-key identity site.
- `ledgr_snapshot_hash()` formats timestamp fields at
  `R/snapshots-hash.R:26-29` and `R/snapshots-hash.R:66-69`.
- `ledgr_run_data_subset_hash()` formats timestamps and numeric values into a
  hash input at `R/data-hash.R:122-149`.

v2 should explicitly fence these sites: Lane R may remove per-pulse/per-fill
hot-path formatting, but durable hash/provenance canonicalization remains
byte-preserved unless a separate RFC changes those contracts.

## Focus-Area Findings

### 1. Wall trajectory: useful as a target, not as an expected table

The table is the main place where v1 overreaches.

The seed table goes:

```text
today     ~313s
+ Lane B  ~165s
+ Lane R  ~130s
+ tail    ~115s
```

Lane B is bounded by two related but different profile numbers:

- `handler$buffer_event` self time: about 137s;
- `output_handler$write_fill_events` total: about 149s.

Using the 313s same-host durable run as the denominator, removing 137s yields
about 176s; removing 149s yields about 164s. So `~165s` is an optimistic
upper-bound if Lane B removes nearly all write-fill-event work, not just the
buffer assignments. That is defensible only if labelled as an optimistic
Amdahl bound.

Lane R is less bounded on the turnover run. The directly named turnover-path
formatting/payload bucket is much smaller than 35s: the audit records
`ledgr_fill_event_payload` around 11s total and `format.POSIXlt` around 8s self.
The empty-fold profile proves representation dominates low-turnover runs, but
it does not by itself justify subtracting another 35s from the post-Lane-B
turnover wall.

There is also potential double counting: if Lane B is implemented as a typed
event-emission rewrite rather than a narrow capacity/setv rewrite, it may
subsume some row/payload work that Lane R also claims.

Recommended v2 change:

- Replace the point-estimate table with a bounded range.
- Example framing:
  - Lane B turnover bound: `~1.7x-1.9x` wall, depending on whether it removes
    only buffer self-time or nearly all write-fill-event time.
  - Lane R turnover increment: measured direct evidence supports a smaller
    `~1.05x-1.15x` on the current turnover run unless additional profiling
    attributes more of the wall to representation after Lane B.
  - Lane R low-turnover effect: likely large, because the empty-fold profile is
    dominated by formatting.
- Keep "roughly Backtrader-level" as a target, not an expected outcome.

### 2. Lane R parity blast radius

The daily/minute/second plus sub-second fixture is necessary but not sufficient
if Lane R touches shared timestamp-normalization helpers.

For event/equity rows, the fixture should cover:

- durable `ledger_events.ts_utc`;
- memory-event `ts_utc`;
- `equity_curve.ts_utc`;
- replay/reopen reconstruction from persisted events;
- daily, minute, second, and explicit sub-second behavior.

For identity paths, v2 should add one of two constraints:

1. **Non-scope constraint:** Lane R must not change canonical JSON, snapshot
   hash, data-subset hash, strategy/config hash, or feature-def fingerprint
   formatting.
2. **If touched:** fingerprint/hash pins must be updated only through an
   explicit accepted contract change.

Without that fence, "carry POSIXct end to end" can accidentally change durable
identity bytes.

### 3. Lane B surface preservation

Lane B is surface-preserving if it is limited to:

- capacity policy;
- internal column storage;
- write operation (`[[<-` vs `collapse::setv`);
- flush implementation that emits the same rows.

Under that scope, it does not interact with snapshot hash, run config hash, or
strategy-visible context. It affects `ledger_events` only through the values it
buffers. Event-stream parity is therefore the correct gate.

The parity gate should include:

- exact event row order and `event_seq`;
- exact `event_id` strings;
- exact `ts_utc` values/classes after DB round trip;
- exact `meta_json`;
- memory sweep events and durable events, because the hot append path exists in
  both `R/backtest-runner.R` and `R/sweep.R`;
- a check that `collapse::setv` preserves POSIXct class/tzone and not just the
  numeric seconds.

If Lane B also changes fill-model inputs, next-bar shape, or payload
construction, it is no longer the narrow surface-preserving lane and must be
sequenced with the primitive-contract work.

### 4. B -> R vs R -> B sequencing

B -> R remains defensible.

The production peer gap is turnover-heavy, and the production profile names
buffer/append as the dominant sampled R cost. The factorial spike also says the
capacity policy is the whole structural win and can be implemented without
changing public strategy surfaces.

R -> B is only preferable if the first implementation batch chooses to rewrite
the whole event-emission surface rather than just the buffer. In that case the
representation lane and buffer lane are entangled, and the primitive/event
contract should bind first.

Recommended v2 wording:

- "B0: capacity/setv buffer rewrite, if surface-preserving, lands first."
- "R: timestamp/formatting cleanup lands next or in the same implementation
  arc, but measured separately."
- "B1: any deeper typed event-emission rewrite that changes payload/fill inputs
  waits for the primitive-contract binding."

### 5. Collapse determinism gate

The gate is close but not complete.

On this host, `collapse::set_collapse()` exposes at least:

```text
nthreads, remove, stable.algo, sort, digits, stub, verbose, mask, na.rm
```

For byte-identical value-bearing operations, `nthreads = 1L`, explicit `na.rm`,
and deterministic `sort` are necessary. `stable.algo` is also a determinism
setting and should be pinned or explicitly justified as irrelevant for the
chosen functions. `digits`/`stub` are more likely to affect presentation/names
than numeric values, but row/name/class parity means the wrapper should either
pin the full collapse state or document which settings are irrelevant to the
used operations.

Recommended v2 change:

- Define `ledgr_with_collapse_deterministic()` as setting a full known collapse
  option set, at minimum `nthreads = 1L`, `na.rm = FALSE`,
  `sort = TRUE`, and `stable.algo = TRUE`, with on-exit restore.
- The hostile-settings fixture should mutate more than `na.rm`; include
  `nthreads`, `sort`, and `stable.algo`.
- `rowbind` parity should be treated as row/order/class parity, not just
  numeric floating-point parity.

### 6. Open questions vs future obligations

The split mostly follows `rfc_cycle.md`, but two open questions are too
load-bearing to leave as ordinary spec-cut details.

Keep as spec-cut open questions:

- buffer sizing policy;
- `LedgrStrategy` mutation guard after R6 removal;
- representation-lane enumeration of concrete `formatC`/`sprintf` sites.

Promote or bind before synthesis:

- **Event-id contract.** If v0.1.8.7 is an optimization round, the default
  should be "preserve exact event-id strings." Changing the event-id contract is
  a maintainer/product decision or a separate explicit contract change, not a
  casual spec-cut choice.
- **Sub-second timestamp handling.** Lane R depends on this. Either v2 binds the
  current whole-second behavior explicitly, or it escalates reject-vs-truncate
  to a maintainer decision. It should not be left to implementation tickets.

Future obligations are correctly classified:

- compiled core later;
- sweep/amortization as a separate track, with the current measurement as open
  input;
- matrix-canonical strategy surface as contract/ergonomics rather than speed;
- parallel/multicore later.

One wording correction: the one-paragraph version at the end of the synthesis
input still says "buffer -> ctx/primitive build"; this seed correctly says
representation/formatting rather than ctx-build. v2 should avoid reintroducing
the old ctx-build label.

## Recommended Next Step

Write seed v2 before synthesis.

The v2 should:

1. replace the wall-trajectory table with bounded ranges and explicitly avoid
   double counting Lane B and Lane R;
2. fence Lane R away from durable hash/provenance formatting, or add hash-pin
   gates if those paths are touched;
3. strengthen the collapse deterministic wrapper to include `stable.algo` or a
   full known `set_collapse()` state;
4. bind exact event-id preservation for this optimization round unless the
   maintainer explicitly chooses otherwise;
5. bind or escalate sub-second timestamp behavior;
6. keep sweep crossover as open input, not a finding.

After that, no further response round is needed unless v2 changes scope. It can
go to synthesis.
