# Accounting-Core Inventory (Post-v0.2.0.1)

**Purpose:** the fact base for the accounting-core consolidation RFC. This
document proposes nothing and recommends nothing. Where a fact could not be
settled by execution it says so.

**Author:** Claude, 2026-09-22, against the working tree at `7a15693` plus the
uncommitted Workstream 4 test changes. Production sources were read, not
modified.

**Companion table:** `post_v0_2_0_1_accounting_core_inventory_sites.csv`,
one row per site (S01–S12).

## 1. The roadmap's premise does not hold

The roadmap row states "eight independently written FIFO replay loops." That
is not what the tree contains. There is **one** R lot-consumption kernel and
**one** independent C++ reimplementation of it. Everything else either calls
the R kernel or reads an already-computed `realized_pnl` column.

| Category | Count | Sites |
| --- | ---: | --- |
| Canonical R kernel | 2 | S01 `ledgr_lot_apply_fill`, S02 `ledgr_lot_apply_event` |
| Independent reimplementation | 1 | S04 `ledgr_cpp_spot_fifo_batch` |
| Drivers that call the kernel | 6 | S03, S05, S06, S07, S08, S09 |
| Consumers of a driver | 2 | S10, S11 |
| Duplicated projection helper | 1 | S12 |

Files that mention `realized_pnl` but perform no replay — `backtest-results.R`,
`business-objective.R`, `sweep.R`, `sweep-retention.R`,
`sweep-persistence.R`,
`public-api.R`, `fold-metrics.R`, `ledger-writer.R`, and the schema files
— read the column from `trades` or `equity` tables. They are projections,
not replays.

So the consolidation problem is not "collapse eight loops into one." It is:
**six driver loops around one shared kernel, plus one compiled kernel that
supports a strict subset of what the shared kernel supports.**

## 2. The real duplication is the driver pair, not the kernel

The six drivers form three pairs by purpose, each pair differing only in where
its events come from:

| Projection | DuckDB-backed reader | In-memory sweep path |
| --- | --- | --- |
| Equity curve | S05 `derived-state.R:239` | S07 `ledgr_equity_from_events` |
| Fills and trades | S06 `backtest-fills.R:166` | S08 `ledgr_fills_from_events` |
| Lot state only | S09 `ledgr_lot_state_from_events` | — |

S03 is the live fold path and has no persisted-event twin by design.

Each driver re-implements event ordering, column extraction, validation, and
row-buffer assembly around identical calls to S02. The lot arithmetic itself
is not duplicated.

## 3. Side vocabulary: one live token set, four dead ones

Verified by execution against a freshly created schema:

| Token | Accepted by `ledger_events` |
| --- | --- |
| `BUY` | accepted |
| `SELL` | accepted |
| `SHORT` | rejected |
| `BUY_TO_COVER` | rejected |
| `COVER` | rejected |
| `SELL_SHORT` | rejected |
| `buy` (lowercase) | rejected |

`R/db-schema-create.R:200` declares `side TEXT CHECK (side IN ('BUY','SELL'))`
and DuckDB enforces it case-sensitively.

The only producer of `side` is `R/fill-model.R:71`:
`side <- if (desired_qty_delta > 0) "BUY" else "SELL"`.

The compiled kernel agrees: `ledgr_spot_direction` (`src/spot_fifo.cpp:46`)
maps only `BUY` and `SELL`, and line 185 aborts with
``"`fill_side` must be BUY or SELL."``

Against that, two R sites carry a broader vocabulary that nothing can reach:

- **S01** `ledgr_lot_direction` accepts six tokens, case-insensitively:
  `BUY`, `COVER`, `BUY_TO_COVER` map to +1; `SELL`, `SHORT`, `SELL_SHORT`
  map to −1.
- **S06** `backtest-fills.R` re-validates the same six tokens and adds two
  directional guards that abort on `BUY_TO_COVER` with a non-negative net
  position and on `SELL_SHORT` with a non-positive net position.

Because the schema rejects all four extra tokens at write time and the fill
model never emits them, those branches and both guards are unreachable from
persisted events. They cannot be exercised without bypassing the schema.

**S05 is the only driver whose validation matches the schema** — it accepts
`BUY` and `SELL` and aborts otherwise with `ledgr_invalid_ledger_event`.

## 4. CASHFLOW is the compiled kernel's hard boundary

`CASHFLOW` appears **zero** times in `src/spot_fifo.cpp` and zero times in
`R/compiled-spot-fifo.R`. The compiled batch entry takes fill vectors only.

Three of the four persisted-event drivers must handle `CASHFLOW`:

- S05 branches on it at `derived-state.R:238`.
- S06 selects it explicitly:
  `event_type IN ('CASHFLOW','FILL','FILL_PARTIAL')`.
- S07, S08, S09 pass `event_type` through to S02, which handles it.

S02 additionally routes `CASHFLOW` carrying opening-position metadata to
`ledgr_lot_apply_opening` via `ledgr_lot_meta_is_opening`. That opening path
is also absent from the compiled kernel.

This is the single concrete blocker preventing any persisted-event driver from
using the existing kernel unchanged.

## 5. Accumulator and tolerance already agree

Both named open questions in the roadmap row have factual answers.

**Compensated accumulation is present on both paths.** R
(`ledgr_lot_add_realized`, `lot-accounting.R:70`) is textbook Kahan:

```r
y <- delta - state$realized_comp
t <- state$realized_pnl + y
state$realized_comp <- (t - state$realized_pnl) - y
state$realized_pnl <- t
```

The compiled entry takes both `realized_pnl` and `realized_comp` as scalar
state (`src/spot_fifo.cpp:77-78, 139-140`) and threads the compensation
term through the batch, so the compiled path does not silently drop it.

**Dust tolerance is the same formula on both paths.**

| Path | Expression |
| --- | --- |
| R `ledgr_lot_dust_tolerance` | `.Machine$double.eps * max(c(1, values))` |
| C++ `ledgr_spot_dust_tolerance` | `epsilon() * max({1.0, abs(a), abs(b), abs(c)})` |

No tolerance divergence exists to reconcile. The R variant is variadic and the
C++ variant is fixed at three arguments; both scale machine epsilon by the
largest magnitude among their inputs and 1.

## 6. S12 duplicates an existing helper

`derived-state.R:311` sums cost basis with a nested `for` loop over
`lot_state$lots`. `ledgr_lot_basis` (`lot-accounting.R:21`) exists for exactly
this and is not called here. This is a duplicated projection helper, not a
duplicated replay; it is listed because it is a genuine redundancy on a reader
path, and because per-pulse nested iteration over lots is the shape the
optimization style manual names.

## 7. Detecting evidence

Counted as test files whose source mentions the symbol. Indirect coverage
through public-surface tests is not counted.

| Symbol | Test files |
| --- | ---: |
| `spot_fifo` | 7 |
| `lot_apply_fill` | 2 |
| `lot_state_asof` | 1 |
| `derived_state` | 1 |
| `lot_apply_event` | 0 |
| `lot_state_from_events` | 0 |
| `fold_reconstruction` | 0 |

The compiled kernel is by far the best-covered site, and three of the
registered claims-registry blocks guard it: `LTB-0006`, `LTB-0013`, and
`LTB-0014`, all under `LCL-0006` in the `fast` profile with the maintainer as
owner. S02, S09, and the two `fold-reconstruction.R` drivers have no test that
names them directly.

## 8. The differential-oracle constraint

`LCL-0006` registers "Canonical-R and compiled spot-FIFO differential parity."
Its three detecting blocks compare the compiled kernel against the R path. The
comparison is meaningful only while an independent R replay exists to compare
against.

S01/S02 are currently that counterparty. Any consolidation that routes every
site through the compiled kernel removes it, and `LCL-0006` would then compare
the kernel against itself. AGENTS.md states canonical R is the normative
executable oracle for optimized paths, so this is a binding constraint on the
consolidation design rather than a preference.

This inventory records the constraint; it does not propose a resolution.

## 9. Performance: antipatterns and measured costs

Measured on R 4.6.1, this machine, against the working tree. All figures are
elapsed wall clock; each is reproducible from the expression given.

### P1. Round-trip fills are quadratic in fills per instrument

`ledgr_lot_apply_fill` (S01) has two shapes that are each linear in open lots
and are executed once per fill:

- line 174 recomputes net position across every open lot:
  `sum(vapply(lots, function(lot) as.numeric(lot$qty), numeric(1)))`
- lines 202 and 220 pop the head lot with `lots <- lots[-1]`, which copies
  the remaining list every time a lot is consumed

Measured, N buys followed by N sells on one instrument:

| N | elapsed | ratio vs half-N |
| ---: | ---: | ---: |
| 100 | 0.070 s | - |
| 200 | 0.080 s | 1.14x |
| 400 | 0.220 s | 2.75x |
| 800 | 0.890 s | 4.05x |

The ratio converges on 4x per doubling, which is O(N^2). The compiled kernel
avoids both shapes: it holds lots in a `std::deque` and pops the front in
constant time.

### P2. Cost basis is recomputed from scratch on every pulse

`derived-state.R:305-315` sums cost basis with a nested loop over every
instrument and every open lot, inside the per-pulse loop that begins at line
290. That is O(pulses x instruments x lots) for a quantity the lot state
already has the deltas to maintain incrementally.

`ledgr_lot_basis`, which S12 duplicates inline, is itself linear in lots:

| open lots | per call |
| ---: | ---: |
| 50 | 45 us |
| 100 | 85 us |
| 200 | 175 us |
| 400 | 370 us |
| 800 | 695 us |

About 0.87 us per lot per call.

### P3. One throwaway data frame is built per event

`derived-state.R:296` passes `events[event_idx, , drop = FALSE]` into
`apply_event`, constructing a one-row data frame with all eleven columns for
every event. Measured against reading the same value by primitive index:

| access | per event |
| --- | ---: |
| `ev[i, , drop = FALSE]` | 43.5 us |
| `qty[[i]]` on the extracted column | below timer resolution |

At 5,000 events that is 0.22 s spent allocating rows that are read once. The
primitive path could not be measured at 100,000 iterations, so the ratio is
at least four orders of magnitude; no precise multiple is claimed.

### P4. Timestamps are converted one at a time

`derived-state.R:294` calls `as.POSIXct` per event inside the advance loop.
Converting the column once is about three times cheaper: 14 us per event
scalar versus 4 us per event vectorized.

### P5. Structural redundancy

S12 reimplements `ledgr_lot_basis` inline. Separately, the six drivers each
carry their own event ordering, column extraction, validation, and row-buffer
assembly around identical calls to S02; only the lot arithmetic is shared.

### Where the replay actually runs

`ledgr_results(bt, "equity" | "fills" | "trades")` does **not** replay. Those
readers issue plain `SELECT`s against materialised tables;
`ledgr_backtest_equity` is a five-line query. On a 366-pulse two-instrument
run they cost 0.110 s, 0.190 s and 0.250 s respectively, and none of P1-P4
is on that path.

The replay has exactly one public entry: `ledgr_state_reconstruct()`
(`public-api.R:121`), which calls `ledgr_rebuild_derived_state()`
(`derived-state.R:81`) at `public-api.R:159`. That is the only place S05's
driver, and therefore P2, P3 and P4, execute.

### Decomposition of a reconstruction

Eight instruments, 300 pulses, 2,392 ledger events, lots accumulating to a
depth of 200 per instrument before bleeding down. `ledgr_state_reconstruct()`
takes **1.19 s** cold. `Rprof` over three warm calls, as a share of
`ledgr_rebuild_derived_state`:

| component | share | finding |
| --- | ---: | --- |
| `ledgr_lot_apply_event` | 45.8% | dispatch into the kernel |
| `ledgr_lot_apply_fill` | 43.5% | the kernel itself (nested) |
| `vapply` | 36.2% | P1 net-position scan (nested) |
| `ledgr_lot_set` | 20.9% | P1 state copy (nested) |
| `ledgr_lot_basis` | 18.6% | P2 cost basis |
| `[.data.frame` | 13.0% | P3 row slicing |
| `as.POSIXct` | 2.8% | P4 scalar conversion |
| `DBI::dbGetQuery` | **1.7%** | database I/O |

Shares are nested, not additive. The load-bearing result is the last row:
**database I/O is under two percent of reconstruction.** The cost is R-level
lot arithmetic and driver overhead, not storage.

### What the fixed shapes would cost instead

A prototype replaying the same 2,400-event stream with all four shapes
corrected — event columns prepared once, running net position per instrument,
lots held in an index-addressed queue rather than popped with `lots[-1]`, and
cost basis maintained incrementally on push and pop:

| | per event | total |
| --- | ---: | ---: |
| current shapes | 250 us | 0.570 s |
| fixed shapes | 3.23 us | 0.0077 s |
| ratio | | **77x** |

Output is equivalent: realized PnL matches exactly (difference 0.0e+00) and
the per-pulse cost-basis series matches to 2.6e-10.

Three caveats bound that figure. The prototype handles `FILL` with `BUY` and
`SELL` only; it performs no input validation; and it does not assemble equity
rows. It is a measurement of the four shapes, not a candidate implementation.

End to end the gain is smaller, because Amdahl applies. The shapes the
prototype addresses cover roughly 80% of reconstruction (kernel, cost basis,
row slicing, timestamp conversion), which bounds a full-driver rewrite at
about **5x** on `ledgr_state_reconstruct`, and nearer **3x** if only the lot
arithmetic is consolidated and the driver layer is left as it is. Restoring
validation lowers both. No compilation is involved in either figure: the 77x
is pure R.

### What compilation adds over fixed R shapes

The compiled kernel is invoked once per pulse with that pulse's fills
(`fold-engine.R:815-835`). Each call packs the entire lot state into flat
vectors (`ledgr_compiled_spot_fifo_pack_lots`) and unpacks the result back
into R lists (`ledgr_compiled_spot_fifo_unpack_lots`), the latter appending
one `list(qty=, price=)` per lot into a growing list. Both traverse every
open lot, on every pulse.

Four arms on the same 2,400-event stream, 8 instruments, 300 pulses, peak
depth 1,600 open lots:

| arm | per event | relative |
| --- | ---: | ---: |
| current R shapes (default path) | 250 us | 1.0x |
| compiled kernel, as production invokes it | 175 us | 1.4x |
| compiled kernel, flat state threaded | 4.17 us | 60x |
| fixed-shape R, no compilation | 3.23 us | 77x |

All arms agree on realized PnL (24000.000000) and on total cost basis.

**Marshalling is 98% of the compiled path's cost.** Removing the R list
round trip, and nothing else, takes the compiled path from 175 us to 4.17 us
per event.

The marshalling is itself O(open lots) per pulse, so the compiled path
carries the same quadratic shape as the R path it replaces:

| peak open lots | compiled path, per event |
| ---: | ---: |
| 200 | 25.0 us |
| 400 | 37.5 us |
| 800 | 87.5 us |
| 1,600 | 181.2 us |

Two readings follow, and both bear on whether compilation should be extended
to more call sites.

First, the compiled kernel as currently wired buys **1.4x** over the default
R path, not an order of magnitude, and the gap closes further as lot depth
grows because marshalling grows with it. `compiled_accounting_model` defaults
to `NULL` and `backtest.R:419` describes it as ephemeral opt-in, so the
default path today is the 250 us column.

Second, the fixed-shape R prototype and the unmarshalled compiled kernel land
in the same order of magnitude, 3.23 us against 4.17 us. That comparison does
not establish that R is faster than C++: Arm C also maintains positions and
cash and emits event records, which the R prototype does not. What it does
establish is that **the arithmetic is not the bottleneck at this scale.**
Shape and state marshalling are.

Caveats: one machine, one event stream, single threaded, and a synthetic
depth profile. The R prototype omits validation and CASHFLOW. No claim is
made about behaviour at depths or instrument counts far outside this range.

### Mapping to the optimization style manual

P1 and P2 are R-level iteration over collections that grow with events and
with instruments x pulses. P3 and P4 are failures to prepare and index once
and to read primitives by index. P5 is redundancy. All are named shapes in
`inst/design/manual/optimization_coding_style.qmd` and therefore review
criteria for any change on these paths.

## 10. What this inventory did not settle

- **Cross-site perturbation disagreement.** I did not run a differential
  harness feeding one event stream through S05, S06, S07, S08 and comparing
  outputs. The pairwise equity and fills projections are the obvious targets.
  Existing parity tests (`test-sweep-persistence-parity.R`,
  `test-availability-parity.R`) may already cover part of this; I did not
  confirm how much.
- **Whether the four dead side tokens are reachable on the live fold path.**
  S03 passes `fill$side` to S01 before persistence. `fill-model.R:71` is the
  only producer I found, and `fold-engine.R:882` branches binary on `"BUY"`,
  which is consistent with BUY/SELL only. I did not exhaustively prove no
  other producer exists.
- **Whether eliminating marshalling is feasible without changing the fold's
  state contract.** Section 9 shows the compiled path is 98% marshalling and
  that threading flat state removes it, but the prototype threads state
  through a loop, not through `state$lot_state` as the fold requires. What it
  would take to hold lot state in flat vectors across the whole fold is not
  assessed here.
- **Validation cost.** The prototype omits the input validation production
  must keep. How much of the 77x survives it was not measured.
- **Corporate-event coverage.** No site handles split, dividend, or other
  corporate-action event types today; whether the planned equity settlement
  work requires the core to grow them is out of scope here.

## Revision history

- 2026-09-22 — Section 9 extended: compiled kernel measured against the
  fixed R prototype. Marshalling is 98% of the compiled path and scales with
  open lots; the compiled path buys 1.4x over default R as wired.
- 2026-09-22 — Section 9 extended: reconstruction decomposed by profile
  (database I/O 1.7%), fixed-shape prototype measured at 77x on the replay
  portion with equivalent output, end-to-end bound stated. Corrected the
  earlier aggregate, which timed materialised-table readers rather than the
  replay path.
- 2026-09-22 — Section 9 added: measured antipatterns P1-P5.
- 2026-09-22 — Initial inventory, Claude, from the working tree. Schema side
  acceptance and tolerance/accumulator parity verified by execution; site
  classification verified by call-graph inspection.
