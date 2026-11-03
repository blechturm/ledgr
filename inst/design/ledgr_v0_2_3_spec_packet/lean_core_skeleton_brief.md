# Lean Core Skeleton Brief

- Status: **maintainer draft**, written under the lean fold core synthesis
  acceptance amendment A1. Not binding until the maintainer accepts it.
- Authors: maintainer with Claude, 2026-11-03.
- Governs: the first code under `dev/lean_core/`, its skeleton and first
  family. Later families follow its structure (A1).
- Inputs: `inst/design/rfc/rfc_lean_fold_core_v0_2_3_synthesis.md` and its
  amendment; `dev/spikes/r_floor/`; `dev/spikes/lean_fifo/`;
  `dev/spikes/data_layout/`; `dev/bench/v0_2_3_r_cost_reference/`;
  `inst/design/manual/optimization_coding_style.qmd`.

## 1. What The Core Is

The lean core prepares a run once, then folds over pulses. Each pulse
observes and settles (E, P1), asks the strategy for targets (P2), plans,
applies and commits fills (P3 to P5), and records what happened. After the
last pulse it publishes through the existing services. Snapshots, feature
computation, registration, preflight, the WS15 codec and the readers are
reused, not rebuilt (synthesis Section 2).

The first code is the code agents will copy. It should be short enough to
read in one sitting and shaped like the contracts.

## 2. Principles

Each principle names the evidence that produced it.

### Above all

0. **The API and functionality do not change.** Only the core and the
   internal representation of its data are replaced. Every exported
   function, argument, default, the `ctx` surface, history shapes,
   condition classes, results, stored records and readers behave exactly
   as before; a user cannot tell which core ran except by speed and
   memory. The only permitted differences are ledgr rules the maintainer
   changes deliberately under A3, each with a recorded oracle difference.
   Every principle below serves this one and yields to it.
   *Source:* lean fold core synthesis, full public parity at the switch.

### Data

1. **Prepare once, read by index.** Everything that does not depend on a
   decision is prepared before the loop: bars, features, membership,
   availability, valid-history counts. A pulse reads by position.
   *Evidence:* P2 seam 14 to 50 us against 664 to 1,479 us for the current
   decide stage, same outputs (`dev/spikes/r_floor/`).
2. **Positions, not names.** One run axis inside the core. Names exist only
   at the strategy boundary and are resolved once at preparation into slot
   numbers: feature aliases, instrument ids, field names.
   *Evidence:* cost reference (`match()` 1.5 us per call; alias resolution
   today runs on every feature and history call).
3. **Time is a number.** Epoch doubles inside the core; ISO strings and
   POSIXct are built once per axis for display.
   *Evidence:* POSIXct compare 85 times slower than epoch compare; one
   `ledgr_utc()` per pulse cancelled a whole cut's gain.
4. **Prepared data lives in compact dense tiles, time-major.** Per block of
   sessions, one plain double matrix per field or feature, sessions x the
   instruments alive in that block, with a global-instrument to tile-column
   map. Time-major is the public history shape, so a window read is a block
   slice with no transpose. A pulse read is one row slice.
   *Evidence:* tiles read as fast as dense and use 391 MB per plane on the
   whole US market against 1,291 MB dense; ragged storage is 2 to 4 times
   slower to read. The transpose is half to four-fifths of every history
   read in today's instrument-major layout; time-major costs about 4 us more
   per plane on a 3,400-instrument pulse read (`dev/spikes/data_layout/`).
5. **Features are computed over each instrument's whole life, then cut into
   tiles.** Never recomputed per tile or window.
   *Evidence:* SMA recomputed on an overlapping window differs from the
   full-series SMA at 5e-14 on every value (final review of the synthesis).
6. **Typed state, no rows.** Positions, cash, targets and strategy state are
   typed vectors on the run axis; the lot book is flat typed segments;
   buffers are preallocated and written by index. No data frames, lists of
   rows or per-pulse environments inside the loop.
   *Evidence:* in the compiled-kernel split, 91% of the time was book
   representation, not arithmetic (`dev/spikes/lean_fifo/`).

### Work per pulse

7. **Work is proportional to change.** A quiet pulse values the book and
   records what must be recorded. Planning touches instruments whose target
   changed, FIFO touches instruments that filled, the trace stores
   differences (WS15).
   *Evidence:* trace rows about 350 us per pulse today; the diff trace
   rebuilt exactly in the floor spike.
8. **Validate at boundaries, once.** Inputs are checked where they enter:
   snapshot, configuration, strategy output every pulse, imports. Trusted
   handoffs between stages are not re-checked.
   *Evidence:* carrier validation 380 us per quiet pulse; kernel input
   validation about a quarter of the FIFO kernel.
9. **Arithmetic order is contract.** Ordered bookings use plain double
   additions in event order: cash fill by fill, expected cash sells first,
   compensated realized P&L. No `sum()` or `cumsum()` where order matters.
   *Evidence:* four of the eleven parity failures in the floor spike.
10. **Explanations on demand.** Selection tables, history metadata, evidence
    planes and reasons are built when a reader asks for them, not on every
    call. The hot read returns values and admission only. What a reader
    gets later is identical to what an eager build would have returned,
    because it is computed from the same frozen view (principle 0).
    *Evidence:* a current history read assembles a selection table and an
    18-field metadata list on every call (`R/history-frame.R`, read plan).

### Ownership

11. **Data flows one way.** The core feeds the strategy's view; it never
    reads back from it. P2 never sees the next bar.
12. **Views are fresh and frozen.** The strategy gets a new view each
    pulse; a retained view cannot change. Free in the seam.
13. **One owner per mutable buffer.** The fold owns the book and the
    buffers; what leaves the fold is a copy or is never written again.
    Copy-on-modify of the book costs nothing measurable at real sizes.
14. **One implementation per concept.** One FIFO kernel, no fallback; one
    prepared representation, used by runs, sweeps, tests and fixtures alike.

### Method

15. **The oracle decides.** Every piece is bit-identical to the pinned
    reference before it counts. A parity failure is a specification
    discovery and goes into the rules ledger (A3).
16. **Measure by function.** Per-function profile samples against the
    family budget (A2), not wall time alone.

### Code shape

17. **Shaped like the contracts.** Each stage is a small function with
    explicit inputs and outputs; each guarantee is a named layer with a
    cost. No defensive code inside trusted kernels.
18. **Small on purpose.** Line budgets per family (A2) and subtraction at
    every close (A4).

## 3. Data Structures

### 3.1 Prepared run (built once, immutable)

| Part | Shape |
| --- | --- |
| axis | session epochs (double); ISO strings for display |
| instruments | ids in run-axis order; one hashed lookup built once |
| tiles | list of tiles; each holds `t0`, `t1`, a column map (global instrument to tile column, `NA` if not alive) and one double matrix per plane, sessions x instruments |
| planes | bar fields (`open`, `high`, `low`, `close`, `volume`), `observed`, each feature by slot, a valid-run count per plane |
| membership and availability | change points: a list of (pulse, instrument, new value) sorted by pulse, from the substrate's existing segments |
| names | feature aliases and field names resolved to slots |

Tile length is at least four times the longest declared lookback, so a
window crosses at most one tile edge, and is capped by a memory target per
tile across all planes; when both cannot hold, the lookback wins. A
`lookback = Inf` read spans all tiles, at a cost proportional to the data it
returns.

The valid-run count holds, for each instrument and session, how many
consecutive valid observations end there. A history window of length `L`
admits an instrument when its count at the cutoff is at least `L`: one
comparison per instrument instead of a scan of the window.

Membership and availability change rarely. The fold applies the change
points as it passes them and keeps one live vector of each, so the work is
proportional to the number of changes. History admission uses `observed`
and the valid-run count, so no past-membership planes are kept.

### 3.2 Pulse view (built each pulse, handed to the strategy)

A plain list: column slices for bars, positions and membership; small
functions `feature(slot)` and `history(slot, L)` that know the pulse. No
environments, caches or S3 dispatch created per pulse. The public `ctx`
surface stays as contracted; this is its implementation.

### 3.3 Fold state (mutated by the fold only)

Typed vectors on the run axis: quantities, targets, strategy state; cash
as a double; the flat typed lot book from the lean kernel.

### 3.4 Recorder

Preallocated typed columns with a row counter, grown by doubling. Fills
and ledger events append per fill; the trace appends differences (WS15).
Frames are built once, at publication.

## 4. What Changes From Today

The planes themselves are right and stay: instrument x session bar
matrices (`R/history-substrate.R`), feature matrices over full series
(`R/runtime-projection.R`), and large history reads that already cost about
one copy (`dev/bench/v0_2_2_history_manifestation/`). What changes is the
handling around them:

- Feature values are split per instrument and reassembled into a matrix by
  a loop (`R/history-substrate.R` payload, `R/runtime-projection.R`). One
  format: the tile matrix.
- Fixtures and interactive contexts read features from a long table with a
  scan per call (`R/pulse-context.R`, feature accessor). They build the
  same prepared run instead.
- Names are resolved and attached per call and per pulse. They are resolved
  once.
- The context is refreshed per pulse with a new cache environment and
  re-named lists (`R/pulse-context.R`, lookup refresh). It becomes a plain
  list of slices.
- A history read re-validates, re-derives admission and assembles metadata
  every call (`R/history-frame.R`, read plan): about 240 us for a 5-session
  bar window over 10 instruments, 450 us for a feature window, and 12.6 ms
  for a 252-session feature window over 500 instruments
  (`dev/spikes/data_layout/q7_history_read.R`). Admission comes from the
  valid-run count; metadata is built on demand.
- Dense instrument-major whole-axis planes become compact time-major tiles.
- Membership and availability are applied as change points, not
  re-derived per pulse.

## 5. Evidence At A Glance

| Probe | Lean | Current | Source |
| --- | ---: | ---: | --- |
| fixed-basket pulse, floor plus priced guarantees | 26 to 103 us | 2.8 to 8.3 ms | `dev/spikes/r_floor/` |
| P2 strategy context, changing axis | 14 to 50 us | 664 to 1,479 us | `dev/spikes/r_floor/` |
| lot kernel per fill block | 92 to 190 us | 223 to 417 us | `dev/spikes/lean_fifo/` |
| pulse read, whole market, 3,400 alive (tiles vs dense) | 9 us | 11 us | `dev/spikes/data_layout/` |
| memory per plane, whole US market (tiles vs dense) | 391 MB | 1,291 MB | `dev/spikes/data_layout/` |
| history window 252 x 500 (time-major tile vs current feature read) | 191 us | 12,580 us | `dev/spikes/data_layout/` |

Spike clocks on one unpinned host; matched stage against stage; not claims.


## 6. Decisions And Remaining Questions

Worked through with the maintainer on 2026-11-03.

1. **Named stages, decided.** The loop calls named stages, each a small
   function passing a few typed vectors rather than carrier objects. A
   function call costs well under a microsecond; each stage stays testable,
   profilable and budgetable on its own.
2. **Time-major tiles, decided** (principle 4). Measured in
   `dev/spikes/data_layout/q2_orientation.R`.
3. **Tile length, stated** (Section 3.1). The memory workstream sets the
   per-tile memory target.
4. **Spilling tiles, open for the memory workstream.** Not built first.
   Sweep workers each holding an in-memory copy multiply memory by the
   worker count; tiles written once to disk could be shared by all workers
   through the operating system's file cache. The memory workstream
   measures both before the decision. Reads go through one tile accessor,
   so either answer is a local change.
5. **Preparation, stated.** Each instrument's features are computed over
   its whole life and written straight into the tiles: no full
   intermediate matrix, no split-and-rejoin. Peak memory is the tiles plus
   one instrument's series; the memory workstream measures it.
6. **Membership and availability as change points, decided** (Section
   3.1).
7. **Small history reads, measured.** Today's fixed cost is about 240 us
   for bars and 450 us for features (Section 4). The lean target is one
   tile slice plus one admission comparison per instrument; the P2 family
   budget is set from that, not from today's cost.
