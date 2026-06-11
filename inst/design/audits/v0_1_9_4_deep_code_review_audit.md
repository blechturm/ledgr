# v0.1.9.4 Deep Code Review Audit

**Date:** 2026-06-11
**Reviewer:** Claude (deep review pass over engine core, accounting, identity,
and persistence layers)
**Baseline:** v0.1.9.4 walk-forward packet closed; Batch 8 release surfaces
committed.
**Scope:** `src/spot_fifo.cpp`, `R/lot-accounting.R`, `R/fold-engine.R`,
`R/compiled-spot-fifo.R`, `R/fill-model.R`, `R/cost-model.R`,
`R/ledger-writer.R`, `R/backtest-runner.R`, `R/derived-state.R`,
`R/fold-metrics.R`, `R/backtest.R` (metric kernels), `R/rng.R`,
`R/timestamp.R`, `R/config-hash.R`, `R/config-canonical-json.R`,
`R/snapshots-hash.R`, `R/pulse-context.R`, `R/strategy-contracts.R`,
`R/fold-event-buffer.R`, `R/sweep.R` (memory output handler).
**Out of scope:** walk-forward layer (reviewed batch-by-batch during the
v0.1.9.4 packet), risk-model internals (reviewed during v0.1.9.3 batches),
feature engine, snapshot adapters, run-store projections.

**Disposition:** tracked for the next release cycle. No findings block the
v0.1.9.4 release gate; B-1 should land before any benchmark re-record that
exercises the compiled spot-FIFO path at scale.

---

## Severity index

| ID  | Severity | Area | One-line summary |
| --- | --- | --- | --- |
| B-1 | Blocker  | C++ kernel | Unprotected SEXP during string-vector construction; GC use-after-free risk |
| H-1 | High     | Runner | Single-pulse run crashes with bare unclassed subscript error |
| H-2 | High     | Accounting | R lot accounting fails silent-open on invalid fill input; C++ fails closed |
| H-3 | High     | Telemetry | elapsed-time heuristic divides by 1e9 for runs longer than ~1000 s |
| M-1 | Medium   | Cost model | Two spread_bps semantics: public half-spread vs legacy full-spread |
| M-2 | Medium   | C++ kernel | Missing TYPEOF checks on scalar state arguments |
| M-3 | Medium   | C++ kernel | Rf_error longjmps over live C++ destructors; leaks on error path |
| M-4 | Medium   | Accounting | Dust-lot accumulation with fractional quantities (shared R/C++ behavior) |
| M-5 | Medium   | Durable path | db_live mode pays two DB roundtrips per fill (per-fill COUNT query) |
| M-6 | Medium   | Identity | Snapshot hash tolerates two timestamp representations (driver hazard) |
| M-7 | Medium   | Cost model | notional_bps_fee computed on pre-rounding, spread-adjusted price |
| N-1 | Nit      | Replay | derived-state parses each event meta_json twice |
| N-2 | Nit      | Compiled bridge | pack_lots grows vectors with c() in a loop (O(n^2) on lot count) |
| N-3 | Nit      | Contract | event_seq is int32; overflow at 2^31 events (unreachable at daily bars) |
| N-4 | Nit      | Engine | actionable-delta tolerance is absolute sqrt(eps); interacts with M-4 |
| N-5 | Nit      | JSON cache | set-count eviction never decrements on overwrite; effective capacity below nominal |
| N-6 | Nit      | Context | features_wide fills matrix with per-value R loop (slow path only) |

---

## Blocker

### B-1. Unprotected SEXP during string-vector construction in spot_fifo.cpp

**Files:** `src/spot_fifo.cpp` lines 305-312 (`set_string_vec`), 331-339
(inline `event_run_id` block), 341-349 (inline `event_type` block).

`set_string_vec` allocates a STRSXP with `Rf_allocVector`, then fills it in a
loop with `SET_STRING_ELT(x, i, Rf_mkChar(...))`, and only afterwards anchors
it into the PROTECTed output list via `SET_VECTOR_ELT(out, k, x)`. Between
allocation and anchoring, `x` is reachable from no protected root. Every
`Rf_mkChar` call inside the loop can allocate a CHARSXP; if that allocation
triggers a garbage collection, `x` is eligible for collection while still
being written. Classic R-internals PROTECT bug.

It does not bite in small tests because GC rarely fires inside that window.
It bites under allocation pressure: large fill batches, big universes,
high-turnover strategies -- exactly the workloads the compiled accelerator
targets. Failure mode is nondeterministic corruption or a segfault, the worst
possible failure mode for a kernel whose entire claim is byte-parity with
canonical R.

Affected sites: six string columns through `set_string_vec` (`event_id`,
`event_instrument_id`, `event_side`, `fill_instrument_id`, `fill_side`,
`fill_action`) plus the two inline STRSXP blocks. `set_double_vec` and
`set_int_vec` are safe: nothing allocates between their `Rf_allocVector` and
`SET_VECTOR_ELT`.

**Fix (cheapest correct):** anchor before filling. `out` is already
PROTECTed, so inserting the fresh vector first makes it reachable during the
fill loop:

```cpp
auto set_string_vec = [&](const std::vector<std::string>& values) {
  SEXP x = Rf_allocVector(STRSXP, static_cast<R_xlen_t>(values.size()));
  SET_VECTOR_ELT(out, k, x);   // anchor FIRST -- out is protected
  for (R_xlen_t i = 0; i < static_cast<R_xlen_t>(values.size()); ++i) {
    SET_STRING_ELT(x, i, Rf_mkChar(values[static_cast<size_t>(i)].c_str()));
  }
  ++k;
};
```

Same pattern for the two inline blocks. About ten lines, no behavior change.

---

## High priority

### H-1. Single-pulse run crashes with a bare, unclassed subscript error

**File:** `R/backtest-runner.R` lines 910-913.

```r
resume_posix <- pulses_posix[[1]]
resume_iso <- pulses_iso[[1]]
resume_exec_posix <- pulses_posix[[2]]   # evaluated unconditionally
```

Coverage checks upstream require only >= 1 pulse. A run whose window contains
exactly one bar reaches line 912 and dies with R's raw "subscript out of
bounds" -- no ledgr_* class, no context. The resume branch at line 944 guards
`start_idx < length(pulses_posix)`; the unconditional line above does not.
`resume_exec_posix` is only used in the resume branch, so the eager
evaluation is pure hazard.

**Fix options:** guard the subscript with a length check, or (better
contract) fail closed at the coverage check with a classed
"window must contain at least two pulses" error -- the fill model needs a
next bar to fill anything, and walk-forward already enforces >= 2 scoring
pulses per window.

### H-2. R lot accounting fails silent-open on invalid input; C++ fails closed

**Files:** `R/lot-accounting.R` lines 139-153 vs `src/spot_fifo.cpp` lines
174-177; consumer at `R/fold-engine.R` lines 490-531.

When `ledgr_lot_apply_fill` receives invalid input (NA direction,
non-positive qty, non-finite price/fee), it returns the state unchanged with
NA result fields -- and the fold engine then proceeds anyway: it writes the
fill event, updates positions, and updates cash. If that path were ever hit,
realized P&L and cost basis would silently diverge from the cash/position
stream: an event-sourced ledger whose lot state no longer reconciles with its
own events. The C++ kernel makes the opposite choice and hard-errors on the
same conditions.

Currently unreachable in practice because `ledgr_fold_build_pulse_plan`
filters non-finite/non-positive fill prices and the proposal constructor
guarantees qty > 0. But the guard lives two layers away from the invariant it
protects, and the silent-NA return makes future breakage invisible.

**Fix:** make `ledgr_lot_apply_fill` abort with a classed error on invalid
input, matching the C++ kernel's fail-closed philosophy. Replay paths in
`derived-state.R` already validate event rows before calling it, so the
blast radius is nil.

### H-3. ledgr_time_elapsed divides by 1e9 for any run longer than ~1000 seconds

**File:** `R/backtest-runner.R` lines 108-127.

```r
if (is.numeric(delta)) {
  if (abs(delta) > 1e3) return(as.numeric(delta) / 1e9)  # "must be nanoseconds"
  return(as.numeric(delta))
}
```

`ledgr_time_now()` returns `proc.time()[["elapsed"]]` -- numeric seconds --
on every normal install. The `> 1e3` magnitude heuristic exists to catch
numeric nanosecond clocks (the `microbenchmark::get_nanotime` fallback), but
it cannot distinguish 1,500 nanoseconds-as-numeric from 1,500 seconds of
actual runtime. Any durable run, sweep, or walk-forward session whose wall
time exceeds 1,000 seconds (~17 minutes) gets `elapsed_sec` divided by 1e9
and persisted to `run_telemetry` as roughly zero. The 500-instrument
benchmark fixture ran 115 seconds, under the threshold, so this has not
surfaced. The first multi-hour sweep will write garbage telemetry, and
`elapsed_sec` feeds release-closeout perf language.

**Fix:** stop inferring units from magnitude. Tag the clock at source: have
`ledgr_time_now()` always return seconds (convert nanotime / microbenchmark
readings at acquisition), then delete the magnitude heuristic. ~15 lines.

---

## Medium

### M-1. Two spread_bps semantics: public half-spread vs legacy full-spread

`R/cost-model.R` line 417 (public): `1 +/- bps / 20000` -- half-spread per
side, round trip ~= spread_bps. Matches the documented contract.
`R/fill-model.R` line 201 (internal legacy `ledgr_default_cost_resolve`):
`1 +/- bps / 10000` -- full spread per side, round trip ~= 2x spread_bps,
with a "Spec v0.1.0" comment.

The legacy resolver chain (`ledgr_fill_next_open`,
`ledgr_cost_spread_commission_internal`, `ledgr_default_cost_resolve`) is now
reachable only from internal tests; no production caller. Pre-CRAN with no
consumers this is a deletion candidate: port the test fixtures to the public
cost model and remove ~80 lines of trap. If kept as a fixture, rename the
parameter (`full_spread_bps`) or add a loud comment -- same name, 2x
different cost, in the same package.

### M-2. C++ kernel skips type checks on scalar state arguments

`src/spot_fifo.cpp` lines 121-125: `total_cost_basis_sxp`,
`realized_pnl_sxp`, `realized_comp_sxp`, `cash_sxp` are read with `REAL(...)`
and `event_seq_start_sxp` with `INTEGER(...)` without preceding TYPEOF
checks, in a function that otherwise validates every vector argument. The R
caller wraps everything in `as.numeric` / `as.integer`, so this is currently
safe -- but `INTEGER()` on a REALSXP is out-of-bounds memory access, not a
graceful error. Five more `ledgr_spot_check(TYPEOF(...) == ...)` lines
complete the wall.

### M-3. Rf_error longjmps over live C++ destructors

All `ledgr_spot_check` failures call `Rf_error`, which longjmps out of a
frame holding `std::deque` / `std::vector` / `std::string`; destructors are
skipped and that heap leaks. Error-path-only severity. Since the function is
registered through cpp11 (`src/cpp11.cpp`, BEGIN_CPP11 / END_CPP11), the
idiomatic fix is free: throw `cpp11::stop(...)` instead, which unwinds C++
frames properly before surfacing the R error. Mechanical replacement inside
`ledgr_spot_check`.

### M-4. Dust-lot accumulation with fractional quantities

`R/lot-accounting.R` line 180 and `src/spot_fifo.cpp` line 200 pop a lot only
when `lot_qty <= 0` after exact subtraction. Whole-share quantities are
exact. Fractional quantities (crypto-style sizing) can leave ~1e-17 dust lots
that survive forever, slowly bloating the lot deque and adding noise to cost
basis. R/C++ parity is maintained (same arithmetic), so this is a shared
latent behavior, not a divergence. Resolution is a contract decision: either
bind a whole-ish-quantity contract explicitly (consistent with the
whole-second timestamp contract), or add an epsilon-pop in both
implementations in the same release so parity holds through the change.
Candidate for the v0.1.9.5 contracts audit.

### M-5. db_live mode pays two DB roundtrips per fill

`R/ledger-writer.R` lines 61-64: `ledgr_write_fill_events` runs a
`COUNT(*) FROM runs` existence check, then the INSERT -- per fill event. The
buffered audit_log path avoids this entirely (payload built in memory,
batch-appended). The existence check belongs at run start, not per event.
Same per-fill-cost family as the parked performance memory; cost is localized
to identifiable per-event DB chatter in db_live mode only.

### M-6. Snapshot hash tolerates two timestamp representations

`R/snapshots-hash.R` lines 66-77: `fmt_ts_utc_vec` formats POSIXct
deterministically but passes character input through as-is. If a future
DuckDB driver version returns TIMESTAMP columns as strings in a different
shape, the same snapshot bytes would hash differently -- a hash-stability
hazard across driver upgrades, and snapshot_hash is tamper-detection
identity. Cheap hardening: abort on non-POSIXct input so a representation
change fails loudly instead of silently re-keying every snapshot.

### M-7. notional_bps_fee computed on pre-rounding, spread-adjusted price

`R/cost-model.R` lines 421-425: the fee uses price after spread transforms
but before the `round(..., 8)` that produces fill_price; cash delta then uses
the rounded price. Sub-1e-8 inconsistency, immaterial economically, but it
means fee != f(fill_price) exactly, which could trip a future byte-parity
reimplementation (e.g. if the compiled kernel ever absorbs cost resolution).
One-line fix (round before the fee loop reads price) or one comment binding
the current order. Also worth one doc sentence: fees-on-spread-adjusted-
notional is a real semantic choice the chain-order validator implies but the
docs do not state.

---

## Nits

- **N-1.** `R/derived-state.R` parses every event's meta_json twice: once in
  `apply_event`, again in the I1/I2 invariant loop (lines 343-351). Replay
  path only; hoist the parsed metas for a free 2x on reconstruction.
- **N-2.** `R/compiled-spot-fifo.R` lines 98-109 grow `lot_inst_idx` etc.
  with `c(...)` in a nested loop -- O(n^2) on lot count. Only matters if a
  strategy accumulates hundreds of open lots per instrument.
- **N-3.** `event_seq` is int32 in both R and C++; overflow at 2^31 events.
  Unreachable at daily bars; binding it as a documented limit costs one
  sentence.
- **N-4.** `R/fold-engine.R` line 426: actionable-delta tolerance is absolute
  `sqrt(.Machine$double.eps)` (~1.5e-8) on quantity deltas. Correct for
  whole-share quantities; interacts with M-4 if fractional quantities arrive.
- **N-5.** JSON cache (`R/config-canonical-json.R` lines 34-42) counts sets,
  not entries, and never decrements on overwrite, so effective capacity is
  slightly below nominal 1024. Harmless.
- **N-6.** `ledgr_features_wide` (`R/pulse-context.R` lines 196-198) fills
  its matrix with a per-value R loop -- only on the slow non-projection
  context path, which production runs bypass via the runtime projection.

---

## What is notably good (do not regress)

1. **Four-path parity discipline is real.** Canonical durable, canonical
   ephemeral, compiled spot-FIFO, and replay reconstruction derive the same
   accounting from the same event grammar. Kahan compensated summation for
   realized P&L is implemented identically in R (`lot-accounting.R` 49-55)
   and C++ (`spot_fifo.cpp` 235-239). The memory handler builds
   compiled-batch metas in field order aligned with
   `ledgr_fill_event_payload()` and byte-compares meta_json against the
   canonical R path. `findInterval(ts <= pulse)` in the durable post-pass
   matches `ev_ts <= t` in the replay loop. The one float divergence
   derivable from the code -- `initial_cash + cumsum(deltas)` vs incremental
   accumulation, different association -- is exactly the divergence the peer
   benchmark measured and attributed to float rounding.
2. **Validate-then-reorder target contract** (`strategy-contracts.R` 34-96):
   duplicate names rejected, exact universe coverage enforced, output
   reordered to universe order. This is what makes the engine's per-pulse
   fill loop and the C++ live-state update provably equivalent -- one fill
   per instrument per pulse, by contract.
3. **Snapshot hashing** (`snapshots-hash.R`): streaming, fixed 10k-row hash
   blocks invariant to DB fetch chunk size, deterministic %.8f formatting,
   non-finite aborts, combination rule documented in place.
4. **No-lookahead boundary is marked in the code** (`fold-engine.R` 320-322):
   bars/features are the current pulse view while fills resolve against the
   next bar.
5. **Hygiene:** zero `sapply` across ~32k lines, zero TODO/FIXME debt
   markers, `Sys.time()` confined to wall-clock metadata, removed context
   helpers error with migration messages, resume path refuses ambiguity
   loudly (config-hash / snapshot-id / metric-context mismatches all
   classed).

---

## Suggested order of attack

1. **B-1** -- ten lines; removes a crash class from the headline performance
   feature. Land before any benchmark re-record.
2. **H-3** -- before the next long benchmark or multi-hour sweep writes
   corrupt telemetry.
3. **H-1, H-2** -- small classed-error hardening; H-2 aligns R with the C++
   kernel's fail-closed stance.
4. **M-1 deletion + M-2/M-3 C++ hardening** as one small kernel-hygiene
   commit.
5. **M-4 and M-6** are contract-binding decisions (fractional quantities,
   driver-representation pinning) that fit the v0.1.9.5 contracts audit.
   M-5, M-7, and the nits ride along as entropy items.
