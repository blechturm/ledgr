# Read-path inventory: absolute session positions (LDG-3216, step 1)

Every place on the pinned preparation and read path (d5b3a151) that holds or
uses an integer meaning a position on the full session axis, or a row or
column index into a full instruments x sessions plane. Paths are pinned
(`R/...`, `src/...`). Read, not run: no R was executed.

In the run path the session axis, the substrate's `pulse_index`, the
projection's pulse axis and the feature-plane `n_pulse` are the same axis, so
"column" below always means a 1-based position on it unless stated.

Tile classes:

- **A** unaffected: the integer is only compared, stored or used to index a
  resident axis-length vector (`substrate$axis`, `pulse_index` names) or a
  sparse summary; it never indexes a plane.
- **B** translate: one column (or one instrument row) of a plane; map the
  global column to tile + offset at the access.
- **C** gather: the access spans columns that may lie in several tiles.
  "Source" means bar or feature planes (source tiles, all resident under
  Section 12.3, so a gather copies but never rebuilds); "working" means memo
  planes (masks, carry sources, last barrier), which are evicted beyond three
  tiles and rebuilt.
- **D** other, explained.

## R/history-substrate.R

| Line | Function | Integer | Produced / consumed | Class |
| --- | --- | --- | --- | --- |
| 441-447, 456, 459 | `ledgr_history_substrate_bar_matrices` | `row`, `col` (match to ids and axis), `linear = row + (col - 1) * n_inst` | hydration scatter of the long bar frame into the six N x T planes; duplicate check on `linear` (`:448`) | B: becomes the per-tile scatter (`collapse::fmatch`), duplicate check per range |
| 1575-1581 | substrate builder | `bar_gap_runs[[field]]`: per row `off`, `count`, 1-based absolute `start`, `end` of non-finite runs (`src/history_compact.cpp:61-95`) | built once from each full plane; consumed by the C++ compact read | A for consumers (compared only); preparation must build the runs across tile edges so a run crossing an edge stays one run |
| 1600, 1602 | substrate builder | `instrument_index` (id to row), `pulse_index` (ISO name to column) | maps; consumed by the read plan and fold reader | A |
| 465-485 | `ledgr_history_substrate_bar_packet` | `pulse_idx` here is a substrate column | reads `bars$<field>[, pulse_idx]` for six planes | B |
| 498-509 | `ledgr_history_substrate_fold_reader` | `pulse_columns` = `pulse_index[fold pulse names]` | made once per fold; consumed by `bars()`, `view()`, the fold's `source_column` and the valuation cursor | A (held) |
| 513-515 | fold reader `bars()` | `pulse_columns[[pulse_idx]]` | current packet column | B |
| 518-527 | fold reader `bars()` | `next_column` = next fold pulse's column, or this column + 1 on the final pulse | `next_bar` packet, refused past the axis end | B; the next column can be in the next tile (the resident "next" working tile covers it; the source tile is resident anyway) |
| 532-534 | fold reader `view()` | `cutoff_col = pulse_columns[[pulse_idx]]` | builds the view E places on the context (`R/fold-engine.R:308`) | A |
| 650-652, 711-712, 786-791 | segment builders | `observation_from`, `observation_to`: absolute half-open column bounds (`to` = T + 1 for open-ended) | from `ledgr_history_axis_lower_bound` (`:738-746`) on effective times | A (sparse summaries) |
| 1318-1319, 1356-1361 | `ledgr_history_segments_query`, `_materialize` | `observation_idx` compared with segment bounds | materialize state planes over requested columns | A for the comparison; the materialized output is whatever range the caller asks for |
| 1395-1407 | `ledgr_history_substrate_expected_at` | `observation_idx` (default all columns) | expected plane over those columns, from segments | A (computed from segments, no plane read); the callers' ranges decide tiles |
| 1437, 1455, 1459 | `ledgr_history_substrate_terminal_planes` | `prefix_idx = seq_len(max(observation_idx))`; `first` = first asserted terminal column (relative to the prefix, which starts at 1, so absolute) | resolves the whole prefix, then keeps the requested columns | C (working, derived from segments): any range resolves the prefix from column 1. Cost grows with history but reads no plane |
| 376-407 | `ledgr_history_precompute_payload` | `matrix_values[i, ]` | splits each feature matrix into per-instrument rows (sweep and precompute) | C (source): one full row per instrument |

## R/history-frame.R

| Line | Function | Integer | Produced / consumed | Class |
| --- | --- | --- | --- | --- |
| 36-39 | `ledgr_history_late_epochs` | `observation_from` vs `axis[from]` | finds late-known facts | A |
| 60-95 | `ledgr_history_prepare_masks` | `all_columns = seq_len(T)`; `terminal_first` = absolute first terminal column (T + 1 = none); `barrier_runs` (false runs, absolute 1-based) | base and overlay masks, full axis | C (working): built over the full axis today. Per tile, `expected` derives from segments per range; `terminal_first` stays a per-row scalar (A); `barrier_runs` must be whole-axis runs merged across edges (A for consumers) |
| 101-121 | `ledgr_history_prepare_positions` | carry `source` plane: absolute column of the latest admissible observation (NA none) | `collapse::na_locf` over each full row of `bars[[field]]` (`R/history-treatment.R:249-273`) | C (working): a tile's carry sources need the state carried in from the previous tile (last source and barrier per row), and the values are absolute columns that can point before the tile |
| 126-146 | `ledgr_history_mask_barrier` | `last_barrier` plane: absolute column of the latest barrier (`R/history-treatment.R:275-298`) | memo, first bar read | C (working): same carried-in state across edges |
| 186-204 | overlay masks and positions | 1 x T planes per late-known instrument and epoch | memo | C (working) |
| 207-247 | `ledgr_history_cutoff_planes` | `cutoff_col` (to a time), `columns` window, `terminal_first` vs `columns` (`:239`) | slices `expected`, `last_barrier`, `source` `[rows, columns]` from memo; overlay rows `[1, columns]` | C (working): window gather; `lookback = Inf` reaches column 1, i.e. evicted working tiles (Section 12.3 transient buffer). The terminal comparison is A |
| 257-285 | `ledgr_history_vintage_planes` | `columns`; per-epoch `at`; `terminal_first <= columns[at]` (`:280`); `reach_seen` = expected counts from the window start | slices base and overlay `expected` over the window | C (working, window only; `reach_seen` never reaches before the window); comparisons A |
| 287-325 | `ledgr_history_bar_evidence` | `stored[rows, columns]` (`:290`); `column` matrix of absolute columns (`:291-295`); carried values read by linear index `rows + (source - 1) * nrow(stored)` (`:301-304`); `source_index` returned | long-layout bar read | C (source): window gather plus point reads at carry sources. Sources come from the unbounded `na_locf` plane, so a read can reach any earlier column, but only cells with age <= `price_carry` use the value (`R/history-treatment.R:339-344`); the rest are discarded. Tiles can bound the point reads to `[first column - price_carry, cutoff]` without changing output. `source_index` is compared only (A, `:1260`) |
| 359-432 | `ledgr_history_feature_evidence` | `values[rows, columns]` (`:372`); key `(row - 1) * n_pulse + column` (`:377-378`); `column >= calc_from/<= calc_to`, `>= ready_col` (`:380`, `:388`); `bars$observed[rows, columns]` (`:394`); `axis[columns]` (`:395`) | long-layout feature read | C (source) for values and observed; keys and comparisons A (sparse records keyed on absolute columns) |
| 483-488 | `ledgr_history_view` | `cutoff_col` | stored in the view | A |
| 532-600 | `ledgr_history_bar_mask_view` | `dependency_first = max(1, first column - max_carry)` (`:535-539`); `dependency_columns` (`:540-544`); `override_expected` = overlay `expected[1, dependency_columns]` (`:569`); `override_terminal`, `override_barrier_runs` (absolute); also hands on the full base `expected` plane, `terminal_first`, `barrier_runs` (`:583-585`) | input to the C++ compact read | C (working): override rows over `[dependency_first, cutoff]`, reaching `price_carry` columns before the window; the base `expected` is passed whole today |
| 602-623 | `ledgr_history_value_slice` | whole `stored` plane, `rows`, `columns`, `dependency_first`, run bounds | calls `ledgr_cpp_history_bar_compact` | D: see `src/history_compact.cpp` below |
| 625-663 | `ledgr_history_bar_compact` | `names(pulse_index)[columns]` (`:647`) | matrix and wide bar reads | A for the names; the plane access is in C++ |
| 665-768 | `ledgr_history_feature_compact` | `feature_values[rows, columns]` (`:677`); keys (`:699-701`); range and ready comparisons (`:702`, `:715`); `axis[[columns[1]]]` (`:728`); `columns[[1]] > 1` (`:733`); `reach_seen` window positions (`:746`) | matrix and wide feature reads | C (source) for values; vintage masks C (working, window); the rest A |
| 1082-1090 | `ledgr_history_read_plan` | `cutoff_col` range check against T | refusal `ledgr_history_outside_axis` | A |
| 1114-1116 | `ledgr_history_read_plan` | `first_col = max(1, cutoff_col - lookback + 1)` (1 for `Inf`); `columns = first_col:cutoff_col` | the request window | A (computed); it decides which tiles every read gathers |
| 1154, 1173-1174, 1204 | `ledgr_history_read_plan` | `axis[[columns[1]]]`, `axis[columns]`, `names(pulse_index)[columns]`, `axis[[cutoff_col]]` | metadata | A |
| 1254-1285 | `ledgr_history_used_before_window` | `source < columns[[1]]`; `columns[[1]] > 1`; `reach_seen` window | the `used_before_window` flag | A |

## R/history-treatment.R

| Line | Function | Integer | Produced / consumed | Class |
| --- | --- | --- | --- | --- |
| 249-273 | `ledgr_history_carry_source` | `column` matrix `seq_len(n)`, `na_locf` of source columns | positions relative to its input; absolute when the input starts at column 1 (memo and feature prefix) | C (working): see `prepare_positions` |
| 275-298 | `ledgr_history_carry_last_barrier` | same, for barriers | as above | C (working) |
| 300-313 | `ledgr_history_carry_source_value` | linear `row + (source - 1) * n` into the given value matrix | feature-input treatment over a prefix | C (source, within the gathered prefix) |
| 319-397 | `ledgr_history_carry_evidence` | `age = column - source`; `axis[pmax(source_out, 1)]` (`:372`) | cell evidence | A (`axis` is the resident axis vector) |

## R/history-features.R

| Line | Function | Integer | Produced / consumed | Class |
| --- | --- | --- | --- | --- |
| 169-187 | `ledgr_history_feature_inputs` | `prefix = seq_len(prefix_end)`; `bars[[field]][instrument, prefix]` (`:187`); expected and terminal over the prefix (`:171-180`) | one instrument's treated inputs from column 1 to the range end | C (source): gathers the instrument's prefix across all tiles up to the range end (Section 12.3 "feature input"); masks from segments, not memo |
| 222-226 | `ledgr_history_feature_terminal_breaks` | `cumsum(terminal_asserted)[rows]` | prefix-relative (= absolute) | A |
| 329-407 | `ledgr_history_feature_calculate` | `calc = calc_from:n`, segment `start`, `end`, `ready` | prefix positions (absolute) | A (works on the gathered vector) |
| 412-428 | `ledgr_history_feature_ranges` | range `start`/`end` from `axis_lower_bound(knowledge)` vs `observation_from` | knowledge ranges | A |
| 430-443 | `ledgr_history_feature_bounds` | `calc_from`, `calc_to` (absolute) | calculation bounds | A |
| 459, 481, 487 | `ledgr_history_compute_feature_series` | `keep = start:range_end`; `out[[d]][i, keep] <-` | writes one knowledge range of one instrument | C (source): a range can span several output tiles (Section 12.3 "feature output") |
| 540-585 | `ledgr_feature_plane_exceptions` | `input_col`, `output_col`, `segment_start/ready/end`, `reason_start/end` (absolute) | sparse evidence records | A |
| 587-611 | `ledgr_feature_plane_records` | `calc_from`, `calc_to`, rows and cols | flattened records | A |
| 627-670 | `ledgr_history_feature_causality` | probe positions `1, n/3, 2n/3, n`; probe inputs as `feature_inputs`; `values[[d]][i, ]` (`:669`) | preparation-time causality check on one instrument per definition | C (source): one full output row and one input prefix per probed definition |

## R/runtime-projection.R

| Line | Function | Integer | Produced / consumed | Class |
| --- | --- | --- | --- | --- |
| 40 | `ledgr_runtime_projection` | `pulse_index` (name to column) | projection map | A |
| 62-102 | `ledgr_projection_index_planes` | keys `(row - 1) * n_pulse + col` with `n_pulse` = axis length | sorted sparse keys for reads | A |
| 134-187 | `ledgr_projection_from_payload` | `mat[j, seq_along(values)]` (`:169`) | rebuilds N x T from per-instrument rows (sweep) | C (source): full-row writes |
| 189-222 | `ledgr_projection_slice` | `idx`; `mat[, idx]` (`:202-205`); planes kept only for the identity slice (`:211`) | sweep slicing | C (source) |
| 232-257 | `ledgr_projection_feature_vector_accessor` | `pulse_idx` = projection column; `mat[, pulse_idx]` (`:255`) | per decided pulse feature vector (`ctx$feature`) | B |

## R/fold-engine.R

| Line | Function | Integer | Produced / consumed | Class |
| --- | --- | --- | --- | --- |
| 305, 308 | P1/P2 observation | fold `pulse_idx` to `history_reader$bars()` and `view()` | packets and the view | A here (translation happens in the reader) |
| 610 | P2 decision data | `source_column = pulse_columns[[pulse_idx]]` | carrier field, validated `>= 1` (`R/fold-carrier.R:286`) | A |
| 741, 1762-1765, 1855 | services | `projection_pulse_idx` = projection column of each fold pulse | feature accessor (`R/pulse-context.R:384-392`) and settlement | B at the accessor; A elsewhere |
| 378, 409, 493 | settlement install (`:229`) | `bar_index` = projection column | recorded with position changes | A |
| 1733-1740 | valuation state | `bars$close` (full plane), `pulse_columns` | builds the cursor | see `R/availability-economics.R` |

## R/availability-economics.R

| Line | Function | Integer | Produced / consumed | Class |
| --- | --- | --- | --- | --- |
| 38-46 | `ledgr_availability_valuation_state` | `pulse_columns` (strictly increasing, within `ncol(close)`) | cursor setup | A |
| 90-107 | `advance()` | `target_column`, `current_column` (0 before the first pulse), loop `close[, j]` for `j` in `(current, target]`; `last_pulse` absolute | forward scan of closes | B per column. The first call scans from column 1 to the first pulse's column, so it reads every source tile before the scoring start; later calls are contiguous and forward |
| 196-219 | `ledgr_availability_frozen_at` | a new cursor per call, `advance(pulse_idx)` from column 1 | results path (freeze inspection) | C (source): scans column 1 to the pulse each call |

## R/run-finalize.R and R/backtest-runner.R

| Line | Function | Integer | Produced / consumed | Class |
| --- | --- | --- | --- | --- |
| `R/run-finalize.R:143-160` | equity finalization | new valuation cursor over `bars_mat`, `pulse_columns` | after the fold | C (source): a full forward scan of `close` |
| `R/backtest-runner.R:664`, `:719-726` | runner | `bars_mat <- history_substrate$bars`; `pulse_columns` handed to finalization | holds the full planes past the fold | D: a consumer outside the fold reader that needs the whole close plane; served by gathering resident source tiles or by keeping a close plane, outside LDG-3216's read set |

## R/availability-provider-prepared.R, R/pulse-context.R

No session columns: the provider plan keys segments by time in seconds
(`R/availability-provider-prepared.R:276-305`, `findInterval` on times at
`:162`), so it is A throughout. `R/pulse-context.R` indexes no substrate
plane: its bar fields come from the packet, its feature vector from the
projection accessor above, and `:322-345` builds a fixture matrix from a
features frame (inspection, not the fold path).

## src/history_compact.cpp

| Line | Function | Integer | Class |
| --- | --- | --- | --- |
| 61-95 | `ledgr_cpp_history_gap_runs` | scans a full N x T plane; returns per row `off` (1-based into start/end), `count`, `start`, `end` as 1-based absolute columns | A for consumers; preparation must merge runs across tile edges (one run per maximal gap on the full axis) |
| 101-133 | `ledgr_cpp_history_false_runs` | same over a full `expected` plane | A for consumers; same merge rule |
| 146-252 | `ledgr_cpp_history_bar_compact` setup | `stored` dims define the plane (`:204-207`); `expected` must have the same dims (`:211-214`); `rows`, `columns` 1-based (`:278`, `:220`); `dependency_first` 1-based (`:216`); `override_expected` is `n_override x (last column - dependency_first + 1)` (`:221-229`); every column checked `< ncol(stored)` (`:314-318`) | D |
| 49-53, 325-327 | `ledgr_history_source::read` | linear `row + column * nrow` (0-based) into the full plane; with `trace_access` records `index + 1` | D |
| 344-350 | `is_expected` | base: `expected[row + column * nrow]` (full plane); override: offset `column + 1 - dependency_first` | C (working) |
| 351-373 | `has_lifetime_barrier` | binary search of absolute barrier runs between `candidate` and the current column | A |
| 375-428 | main loop | reads `stored` at each window column (`:380-381`); on a gap, `candidate = gap_start - 2` (0-based column before the gap, `:401`); `age = column - candidate`; reads `stored` at `candidate` only when `age <= max_carry_sessions` and asserts `candidate + 1 >= dependency_first` (`:419-421`); `terminal_at` compared (`:388`); `used_before` when `candidate + 1 < columns[0]` (`:427`) | C (source): values over `[dependency_first, cutoff]` only. The gap-start lookup and barrier search can look further back but read no plane |
| 429-437 | short-row structural check | `is_expected` over the window | C (working, window) |

**The D entries in C++.** The kernel takes the whole stored plane and the
whole base `expected` plane and indexes them with absolute rows and columns.
Gap runs, barrier runs, `terminal_first`, `dependency_first` and the override
offset are all absolute too, and the bounds checks compare columns with the
plane's own width. A tile-backed call can pass either:

- a gathered `rows x [dependency_first, cutoff]` slice of `stored` and
  `expected`, with every absolute coordinate (columns, `dependency_first`,
  `terminal_first`, gap and barrier run bounds, override offset) shifted by
  the same offset; or
- the absolute coordinates unchanged plus one column-offset argument, in
  the same C++.

Both are storage and access changes. The `trace_access` oracle
(`tests/testthat/test-history-api-cleanup.R:176`) records linear indices into
the full plane, so a lean trace must report the same global coordinates to
stay comparable.

## Summary

Counts by table row, each row counted under the class its last cell starts
with (one fold-engine row only points to the cursor and is not counted):

| Class | Rows |
| --- | --- |
| A | 30 |
| B | 7 |
| C | 25 (13 source, 12 working; the two feature-read rows mix both) |
| D | 4 |

**Accesses that can reach evicted working tiles.** Under Section 12.3 these
are the only reads that can need tiles older than the three resident ones,
via the transient buffer:

- `cutoff_planes`, `vintage_planes`, `bar_mask_view` and the C++
  `is_expected` with `lookback = Inf` or more than 252 sessions back;
- `bar_mask_view` override rows, which reach `price_carry` columns before the
  window start.

Every source read (bars, features, observed) hits resident source tiles: it
costs a gather copy, never a rebuild. Long gathers of source tiles:

- feature input prefixes (column 1 to the range end);
- the causality probe's full row;
- the valuation cursor's first advance from column 1;
- finalization and `frozen_at` full scans;
- payload split and rebuild.

**Carried-in state at tile edges.**
- Carry `source` and `last_barrier` planes: absolute positions from an
  `na_locf` over the whole row, so each working tile needs the previous
  tile's last values per row.
- `terminal_planes`: resolves the prefix from column 1 out of segments.
- Gap and barrier runs: whole-axis summaries, so preparation must merge runs
  across edges.

**NEEDS_TYPE_2: none.** Every entry is a storage, fetch or allocation change
that keeps the same calculation, order and evidence. One read-volume note
that changes nothing in the output: `bar_evidence` reads carry-source values
at any distance and then discards those older than `price_carry`, so a tile
read can stop at `price_carry`. One consumer lies outside LDG-3216's read set
and holds full planes: run finalization and `frozen_at` through `bars_mat`.
Its tile access (gather or a kept close plane) has to be decided where that
path is replaced.
