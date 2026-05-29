# Fold-Path Hot-Path Audit

**Scope:** `R/fold-core.R`, `R/backtest-runner.R`, `R/fill-model.R`,
`R/ledger-writer.R`, `R/pulse-context.R`, `R/runtime-projection.R`,
`R/feature-cache.R`

**Branch:** v0.1.8.5 · **Audit date:** 2026-05-29 · **Status:** v0.1.8.7
optimization input. Not a v0.1.8.6 deliverable. No optimization ships from this
document; it names hot-path costs, maps them to code paths, and assigns each to
an optimization lane so the RFC can sequence the work.

---

## Method

`dev/bench/run_benchmarks.R` `peer_sma_crossover` scenario plus a turnover
differential and an `Rprof` pass on the i9-12900K. Representative shape 200
instruments x 504 pulses x 2 SMA features, `persist_features = FALSE`, 2099
fills.

- trade vs flat phase split: `t_loop` 1.04s (flat) -> 13.39s (trade), residual
  5.50s -> 7.55s. The turnover cost is **+12.35s in the loop** (fill emission)
  and only **+2.05s in the residual** (write + reconstruction).
- `Rprof` top self time on the trading run: `handler$buffer_event` 29%,
  `format.POSIXlt` 16%, `sprintf`/`formatC` ~10%. `ledgr_lot_apply_event`,
  `canonical_json`, `jsonlite::fromJSON` were each <0.3%.

**Headline:** per-event durable-ledger *reconstruction* is NOT the slow path.
The cost is per-event *emission* inside the fold loop: timestamp formatting,
event-id construction, per-event JSON, and a quadratic buffer-copy. Rprof
absolute times are inflated (~30%); the relative ranking and the unprofiled
loop/residual deltas are the load-bearing evidence.

## Common root: per-iteration `format.POSIXlt`

`ledgr_normalize_ts_utc()` (`R/pulse-context.R:619-625`) on a `POSIXt` input does
`format(x, "%Y-%m-%dT%H:%M:%SZ")` -- this is the `format.POSIXlt` the profiler
reports. On a character input it runs a `grepl` regex validation. It is called
*per iteration* in three hot loops, on values that are either loop-invariant or
already typed:

1. per cache key (precompute / `t_pre`),
2. per fill (emission / `t_loop`), with a redundant string->POSIXct re-parse,
3. (vectorized and fine in reconstruction).

This is the same boundary-representation-in-the-hot-path pattern as the
canonical-JSON cache key: format/serialize once at the persistence boundary,
carry primitives (`POSIXct`/integer) through the loop. It is the concrete
performance face of the sealed-data trust boundary.

## Findings

| # | Site | Pattern | collapse rule | Severity | Lane |
|---|------|---------|---------------|----------|------|
| 1 | `handler$buffer_event` (`backtest-runner.R:385-409`) | 11x `state$pending_cols$col[[i]] <- v` copies each preallocated column (length `max_events = n_inst*n_pulses`) per event. Analytic cost O(events x n_cols x n_inst x n_pulses); ~2.3e9 element-copies at 200x504, matching the 29% self time. | "Never grow/copy in loops; allocate once, fill by reference" | **HIGH** | B emission |
| 2 | `ledgr_fill_event_payload` (`backtest-runner.R:176-177`) + `ledgr_next_open_fill_proposal` (`fill-model.R:70`) | Per fill: `ledgr_normalize_ts_utc` formats `POSIXct -> ISO` (in fill model), then payload re-validates the string and `as.POSIXct(...)` parses it **back** to `POSIXct` for the DB. A `POSIXct -> string -> POSIXct` round trip per fill. | "Avoid repeated coercion; coerce once" | **HIGH** | B emission |
| 3 | `ledgr_fill_event_payload` (`backtest-runner.R:188`) | `canonical_json(meta)` per fill. `meta` varies per fill (`cash_delta`/`position_delta`), so the `canonical_json` cache always misses -> full `toJSON` per fill. | "Construct/serialize once, not per row" | **MED-HIGH** | B emission |
| 4 | `ledgr_fill_event_payload` (`backtest-runner.R:190`) | `paste0(run_id, "_", sprintf("%08d", event_seq))` per fill. | "Avoid repeated allocation in loops" | **MED** | B emission |
| 5 | `ledgr_fills_from_events` (`fold-core.R:561-689`) | Per-event `data.frame()` (605/623/655/669) + `do.call(rbind, rows)` (688); `events[i, , drop = FALSE]` row-subset per event (575); `jsonlite::fromJSON` per event via `ledgr_event_meta_at` (442). | "Never `rbind` in loops; never per-row `data.frame`; avoid `[` row-subset in loops; use `.subset2`" | **MED** (lazy read-back, not run wall) | C read-back |
| 6 | reconstruction loops `ledgr_equity_from_events` / `..._sweep_summary_...` (`fold-core.R:445-901`) | `events$col[[i]]`, `ev$col[[1]]` data.frame accessors in per-event loops. | "Replace `$`/`[[` on data.frames with `.subset2`" | **LOW-MED** | C read-back |
| 7 | `handler$buffer_strategy_state` (`backtest-runner.R:420`) | Per-pulse `data.frame(...)` when the strategy returns `state_update`. | "Per-row data.frame construction" | **LOW** (stateful strategies only) | B emission |
| 8 | `ledgr_feature_cache_key_from_parts` (`feature-cache.R:116-117,119`) | `ledgr_normalize_ts_utc` on `start`/`end` (run-level constants) per `(inst x feat)` key + `canonical_json` + `digest` per key. | "Hoist loop-invariant work; don't treat a session lookup key as durable provenance" | **HIGH at scale** (`t_pre` ~38.8s at 500x50) | A cache-key |

## collapse-checklist result (broader)

Audited against `developing_with_collapse.html`. What is already correct, so we
don't regress it:

- `handler$init_buffers` preallocates column vectors (right *shape*); finding #1
  is that the per-event write pattern *defeats* the preallocation by copying.
- `ledgr_equity_from_events` uses `findInterval` + vectorized `cumsum` (good).
- `ledgr_sweep_summary_from_ordered_events` already uses the preallocated-column
  + `add_fill_row` pattern -- it is the template `ledgr_fills_from_events`
  (finding #5) should converge to.
- `ledgr_fast_data_frame` (post-LDG-2453/2455) is the cheap stamp the article
  recommends; `flush_pending` builds the batch `data.frame` once (acceptable;
  could use the stamp, minor).

Still-open anti-patterns are findings #1, #5, #6 above. No `collapse` dependency
is required to fix any of them (preallocation, `.subset2`, batched formatting are
all base R); `collapse` would be an *optional* further win, not a prerequisite.

## Proposed v0.1.8.7 lanes

- **Lane A - cache-key** (already scoped): hoist `start`/`end` normalization out
  of the per-key loop; replace the JSON+SHA session key with a length-prefixed
  composite string. Session-local, no parity constraint, no dependency.
- **Lane B - event emission** (the confirmed turnover cost): carry `ts` as
  `POSIXct` end to end (drop the `normalize -> re-parse` round trip); **defer
  `meta_json` serialization to flush as per-row
  `vapply(meta_list, canonical_json, character(1))` -- NOT one `toJSON` /
  `canonical_json` over the whole column, which emits a JSON array and breaks
  per-row event/replay parity**; build event ids without per-event `sprintf`
  (preserving the exact `run_id_00000001` format unless an RFC changes the
  event-id contract); pass next-open primitive fields into the fill model
  instead of a per-fill `b[i + 1L, , drop = FALSE]` row-subset + `as.list`
  coercion (finding #9); and size the event buffer realistically rather than to
  `max_events = n_inst * n_pulses` (a memory/GC win -- the per-write
  full-column-copy mechanism is **not confirmed**; see the reconciliation note).
  **Timestamp contract (decided): whole-second UTC. ledgr is not an HFT/tick
  engine; no sub-second support.** Enforce whole-second at the snapshot
  seal/ingest boundary (the sealed-data trust boundary), so the fold carries
  already-whole-second `POSIXct` and the round-trip elimination needs no
  per-event truncation and leaks no sub-second into the ledger. The validation
  regex stays the single source of truth, applied at the boundary, not per
  event. Parity gate: a ledger-event `ts_utc` fixture against current output for
  representative daily/minute/second timestamps.
- **Lane C - read-back reconstruction**: rewrite `ledgr_fills_from_events` to the
  preallocated-column pattern already used by the sweep summary; replace
  `events[i, , drop = FALSE]` / `$` with `.subset2`. Parity gates the rewrite
  must preserve: `event_seq` ordering; CASHFLOW handled before fill rows; FIFO
  lot-state progression; CLOSE-before-OPEN row order when one event splits into
  both; output column order and classes; memory-event vs DB-backed parity. Needs
  focused fixtures for opening positions, partial close/open, invalid fill rows,
  and DB-backed vs memory-backed events.

## Non-goals / boundaries

- No optimization in v0.1.8.6. This is measurement + attribution + lane
  assignment only.
- No `collapse` dependency is implied; all proposed fixes are base R.
- Numbers are machine-specific (i9-12900K) and `Rprof`-relative. Re-measure on
  the release host before citing.

---

## Codex Peer Review (2026-05-29)

**Scope:** contestable claims in the audit above, especially the R
reference-counting claim in finding #1 and parity hazards in the proposed
lanes. This section is appended as peer review; it does not overwrite the
initial audit.

### Verdict summary

Accept the broad direction: the remaining speed work is hot-path boundary
representation leaking into the fold (timestamps, JSON/session keys, row/frame
construction), and the v0.1.8.7 lanes are the right place to turn those findings
into RFC/spec inputs.

Refute finding #1 as written: the current nested-list buffer writes are not
confirmed as quadratic full-column copies under the tested R 4.5 runtime.
`handler$buffer_event` is still hot, but the hotness should not be attributed to
`O(events x n_cols x n_inst x n_pulses)` vector copying without stronger
evidence.

### Finding #1: buffer-event copy claim

The R-internals analysis in finding #1 does not hold under a direct
micro-benchmark on the current Windows/R 4.5 workspace.

Tested patterns:

```r
state$pending_cols$x[[i]] <- i      # current nested-list shape
state$x[[i]] <- i                   # direct env-bound column
state$pending_cols$x[[i]] <- i      # pending_cols as env
cols$x[[i]] <- i                    # list alias
x[[i]] <- i                         # local vector
```

With `n = 5000`, `cap = 100000`, all patterns ran in roughly `0.01s-0.03s`.
`tracemem()` printed no vector-copy events for the current nested-list pattern,
direct env-bound columns, env-contained columns, or the list alias. A closer
11-column benchmark shaped like `buffer_event` also did not show a
capacity-scaled explosion:

```text
n events  capacity  current_nested_list  direct_env_columns
   2099    100800                0.30s              0.28s
  20000    100800                2.81s              2.76s
```

Conclusion: the current pattern appears in-place enough for the preallocated
columns in this runtime. Direct env columns may reduce a little accessor
overhead, but they are not a major asymptotic fix. Realistic sizing or growth
can still reduce memory pressure from `max_events = n_inst * n_pulses`, but the
audit should not carry forward the quadratic-copy explanation as a fact.

Recommended rewrite of finding #1 for RFC input:

- `buffer_event` is a measured hot function in the turnover path.
- The confirmed costs are per-event list/accessor work, payload construction
  around the write result, and large preallocation memory pressure.
- The unconfirmed claim is full-column copy-on-each-write; keep it as refuted
  unless a lower-level benchmark proves otherwise.

### Finding #2: timestamp round trip

Confirm. The current path is redundant:

- `ledgr_next_open_fill_proposal()` converts `next_bar$ts_utc` to an ISO UTC
  string via `ledgr_normalize_ts_utc()`;
- `ledgr_fill_event_payload()` then normalizes the value again and parses the
  ISO string back to POSIXct for `ledger_events.ts_utc`.

The v0.1.8.7 lane should carry a trusted POSIXct timestamp into the fill
payload and write that POSIXct to DuckDB. Parity caveat: the current
`ledgr_normalize_ts_utc()` format is second-granularity
`"%Y-%m-%dT%H:%M:%SZ"`. If a future path starts carrying subsecond POSIXct
values, it could preserve precision the old round trip discarded. The safe
gate is an explicit ledger-event `ts_utc` parity fixture against current output
for representative daily/intraday timestamps.

### Finding #3: batched `meta_json`

Accept only with a precise implementation constraint.

Safe: defer serialization out of the per-fill payload and serialize each row at
flush with the same canonical function:

```r
meta_json <- vapply(meta_list, canonical_json, character(1))
```

That should produce byte-identical `meta_json` values to today's per-row
`canonical_json(meta)`, subject to a direct parity fixture.

Unsafe: one `jsonlite::toJSON(meta_list)` call or one `canonical_json(meta_list)`
call for the whole column. That produces a JSON array over the batch, not one
canonical JSON string per ledger row, and would break event/replay/provenance
parity.

### Finding #4: event-id formatting

Accept as a smaller Lane B target. `paste0(run_id, "_", sprintf("%08d",
event_seq))` is per-event allocation. It is not as important as timestamp/meta
work, but it can be optimized if the replacement preserves the exact
`run_id_00000001` event-id format or if an RFC explicitly changes the event-id
contract.

### Findings #5-6: read-back reconstruction

Accept with parity gates.

`ledgr_fills_from_events()` currently uses per-event row subsetting,
per-output-row `data.frame()` construction, and `do.call(rbind, rows)`. A
preallocated-column rewrite plus `.subset2()` reads is a valid low-risk cleanup
because fill reconstruction is a pure projection over ordered events. The
rewrite must preserve:

- ordering by `event_seq`;
- CASHFLOW handling before fill rows;
- FIFO lot-state progression;
- CLOSE-before-OPEN row order when one event splits into both rows;
- output column order and classes;
- parity between memory-event and DB-backed event tables.

The existing `ledgr_sweep_summary_from_ordered_events` pattern is a reasonable
template, but the fill-table rewrite still needs focused fixtures for opening
positions, partial close/open, invalid fill rows, and DB-backed vs memory-backed
events.

### Finding #7: strategy-state buffering

Accept as low priority. Per-pulse `data.frame()` construction exists only when a
strategy emits `state_update`. It belongs in Lane B if stateful strategies
become hot, but it should not displace timestamp/meta/cache-key work.

### Finding #8: cache-key lane

Confirm. The repeated `ledgr_normalize_ts_utc()` calls on run-level
`start_ts_utc` / `end_ts_utc` inside `ledgr_feature_cache_key_from_parts()` are
real setup-path work and fit the sealed-data trust boundary. Session-local
cache keys should not need durable canonical JSON + SHA semantics. The RFC
input should keep this separate from durable provenance hashes.

### Completeness additions

Add one Lane B candidate before RFC synthesis:

- `fold-core.R` creates `next_bar <- b[i + 1L, , drop = FALSE]` per fill and
  `ledgr_next_open_fill_proposal()` immediately converts that one-row
  data.frame to a list. In high-turnover paths this is another per-fill
  data.frame row subset / coercion. The primitive-lane version should pass the
  next-open primitive fields directly into the fill model.

Other scanned hot-path candidates are already covered by the audit or are
boundary/reconstruction work rather than fold-loop emission.

### RFC input adjustment

Before this audit becomes v0.1.8.7 RFC input, revise the lane wording:

- Lane A cache-key: keep as written.
- Lane B event emission: keep timestamp, meta-json, event-id, and next-bar
  primitive work; downgrade the buffer-copy claim to "measured hot function,
  accessor/payload overhead and sizing pressure, no confirmed quadratic copy."
- Lane C read-back: keep as written, with the parity gates above.

---

## Reconciliation (Claude, post-review re-verification, 2026-05-29)

After Codex's refutation I re-ran the buffer question with six micro-benchmarks
on R 4.5 / i9-12900K. Outcome:

- **Finding #1 is downgraded; Codex's refutation is accepted.** Results were
  inconsistent and non-reproducible: single-numeric, single-POSIXct, and
  11-numeric-interleaved columns were all flat across capacity; some mixed-type
  variants scaled, a functionally-equivalent rerun did not; `tracemem` showed no
  column copy in any case. That pattern is GC/heap-scan pressure proportional to
  the over-allocated buffer, **not** the claimed
  `O(events x n_cols x n_inst x n_pulses)` per-write vector copy. `buffer_event`
  remains a measured hot function, but the confirmed costs are per-event
  accessor/payload work plus preallocation memory/GC pressure. The actionable,
  mechanism-independent fix is **realistic buffer sizing** (not
  `max_events = n_inst * n_pulses`); the copy-elimination story is withdrawn.
- The genuine, *confirmed* emission costs are findings #2/#4 (per-fill
  `format.POSIXlt` round trip and per-fill `sprintf`), backed by Rprof
  self-time. Finding #3 is confirmed by the code path and retained as a
  parity-sensitive serialization target, but it was not a top self-time entry
  in this profile. Lane B stands on those.
- **Finding #9 (Codex addition):** `fold-core.R` builds `next_bar <-
  b[i + 1L, , drop = FALSE]` per fill and `ledgr_next_open_fill_proposal`
  (`fill-model.R:44-52`) coerces it via `as.list`. Per-fill data.frame
  row-subset + coercion. Owner: Lane B / `v0.1.8.7_primitive_contract`.
- **Finding #3 constraint:** batched `meta_json` must be per-row
  `vapply(meta_list, canonical_json, character(1))` at flush, never one
  `toJSON`/`canonical_json` over the column (array != per-row, breaks parity).
- **Parity gates added:** ledger-event `ts_utc` fixture (second vs subsecond);
  the `ledgr_fills_from_events` rewrite invariants (event_seq order,
  CASHFLOW-before-fills, FIFO, CLOSE-before-OPEN, column classes, memory-vs-DB).

### `fasttime` note (s-u/fasttime)

POSIXct parse/format slowness is the premise behind findings #2 and #8, and
adjacent to Lane B emission work. `fasttime`
(`fasttime::fastPOSIXct`) is a fast C **parser** of ISO strings to POSIXct.
Scope and limits for ledgr:

- It addresses only the **parse** half of the #2 round trip
  (string -> POSIXct). It does **not** speed up `format.POSIXlt` (POSIXct ->
  string), which is the dominant *format*-side cost in the Rprof.
- The primary Lane B fix -- carry `POSIXct` end to end and never round-trip --
  avoids **both** the format and the parse, so `fasttime` is unnecessary on the
  fill path if that fix lands.
- `fasttime` becomes a candidate only at **unavoidable** string -> POSIXct
  boundaries (e.g. DB read-back). It assumes UTC and a fixed format and has
  historically been loose on fractional seconds / format validation, so for a
  provenance tool it needs an exact round-trip/precision parity gate plus the
  same dependency decision the project applied to `collapse`.
- For the *format* side, the answer is structural (don't format per event;
  format once, vectorized, at the persistence boundary, or store epoch
  integers), not a faster formatter.
