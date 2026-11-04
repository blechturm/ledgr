# RFC: Lean Core Skeleton (v0.2.3), Seed v2

- Status: **seed v2** of an active RFC cycle ([pipeline](README.md#lean-core-skeleton)). Not binding.
- Parent: the accepted [lean fold core synthesis](rfc_lean_fold_core_v0_2_3_synthesis.md), amendment A1. This RFC holds the skeleton design, so the A1 brief for whoever builds the skeleton can stay a short operative brief.
- Authors: maintainer with Claude. Seed v1 2026-11-03 ([seed](rfc_lean_core_skeleton_v0_2_3_seed.md), first committed as the packet file `lean_core_skeleton_brief.md` at `267d2405`). Seed v2 2026-11-04 after the [response](rfc_lean_core_skeleton_v0_2_3_response.md) (Codex, Type 2, REVISE): P1 to P5 and P7 applied, P6 applied in Section 4 with the workstream rules left in macro plan WS16; then after the [seed v2 review](rfc_lean_core_skeleton_v0_2_3_seed_v2_review.md) (Codex, ACCEPT_AFTER_PATCHES): N1 applied.
- Converted from a packet brief into this RFC on 2026-11-04 by maintainer decision: it chooses architecture and an evidence boundary, which is RFC scope (`rfc_cycle.md`, Routes).
- Governs, once a synthesis is accepted: the first code under `dev/lean_core/`, its skeleton and first checkpoint. Later families follow its structure (A1).
- Inputs: `inst/design/rfc/rfc_lean_fold_core_v0_2_3_synthesis.md` and its
  amendment; macro plan WS16; `dev/spikes/r_floor/`; `dev/spikes/lean_fifo/`;
  `dev/spikes/data_layout/`; `dev/bench/v0_2_3_r_cost_reference/`;
  `inst/design/manual/optimization_coding_style.qmd`.

## 1. What The Core Is

The lean core prepares a run once, then folds over pulses. Each pulse
observes and settles (E, P1), asks the strategy for targets (P2), plans,
applies and commits fills (P3 to P5), and records what happened. Output
goes through the existing services at their current event, chunk, pulse
and completion boundaries, including the prefix written before a failure;
buffer growth never postpones publication to the end of the run.
Snapshots, feature computation, registration, preflight, the WS15 codec
and the readers are reused, not rebuilt (synthesis Section 2).

The first code is the code agents will copy. It should be short enough to
read in one sitting and shaped like the contracts.

## 2. Principles

Each principle names the evidence that produced it.

### Above all

0. **The API and functionality do not change.** Only the core and the
   internal representation of its data are replaced. Every exported
   function, argument, default, the `ctx` surface, history shapes and
   attributes, condition classes, results, stored records and readers
   behave exactly as before; a user cannot tell which core ran except by
   speed and memory. The only permitted differences are ledgr rules the
   maintainer changes deliberately under A3, each with a recorded oracle
   difference. Every principle below serves this one and yields to it.
   *Source:* lean fold core synthesis, full public parity at the switch.

### Data

1. **Prepare once, read by index.** Everything that does not depend on a
   decision is prepared before the loop: bars, features, treatment masks,
   membership, availability. A pulse reads by position.
   *Evidence:* P2 seam 14 to 50 us against 664 to 1,479 us for the current
   decide stage, same outputs (`dev/spikes/r_floor/`).
2. **Positions, not names.** One run axis inside the core. Names exist only
   at the strategy boundary and are resolved once at preparation into slot
   numbers: feature aliases, instrument ids, field names.
   *Evidence:* cost reference (`match(id, ids)` about 1.5 us for one id in
   500; alias resolution today runs on every feature and history call).
3. **Time is a number.** Epoch doubles inside the core; ISO strings and
   POSIXct are built once per axis for display.
   *Evidence:* POSIXct compare about 87 times slower than epoch compare in
   the scalar probe; one `ledgr_utc()` per pulse cancelled a whole cut's
   gain.
4. **Prepared data lives in compact dense tiles, time-major.** Per block of
   sessions, one plain double matrix per field or feature, sessions x the
   instruments stored in that block, with a global-instrument to
   tile-column map. Which instruments a tile stores is a storage rule only,
   never membership or history admission (Section 3.1).
   *Evidence:* measured tiles trade lower payload memory and faster history
   slices against some slower pulse and cross-edge reads. Time-major
   removes the transpose in the synthetic orientation probe and adds about
   4 us to its 3,400-instrument pulse slice. Complete public reads remain
   to be measured (`dev/spikes/data_layout/`).
5. **Features keep the existing service's calculation semantics.**
   Features are computed by the existing feature service from data start
   through calculation end, keeping its required-field treatment, knowledge
   ranges, segment restarts, readiness, arithmetic order and vintage
   evidence, with outputs and evidence stored in tiles without changing the
   calculation sequence. Tile edges add no restart or
   recalculation. "Whole series" does not mean one uninterrupted indicator
   call, and it never uses lifetime knowledge a pulse could not have had.
   *Evidence:* all 150 tested overlapping-window SMA values differed from
   the full-series SMA, maximum about 5e-14 (final review of the synthesis).
6. **Typed state, no rows.** Positions, cash and targets are typed vectors
   on the run axis. Asset-state fields have declared types and the
   decision-axis reset rules on departure and re-entry; portfolio-state
   fields are typed scalars. The lot book is flat typed segments. Buffers
   are preallocated and written by index. No data frames, lists of rows or
   per-pulse environments inside the trusted arithmetic.
   *Evidence:* in the compiled-kernel split, 91% of the time was the quickr
   conversion wrapper around the book, not arithmetic
   (`dev/spikes/lean_fifo/`).

### Work per pulse

7. **Work is proportional to change.** Each due pulse validates the full
   strategy return and applies risk. Planning selects the post-risk targets
   that differ from current settled holdings by the canonical actionable
   threshold, not targets that differ from the previous request, so a
   repeated unmet request is attempted again. The one lot kernel updates
   the book for every opening, fill and disposition in event order;
   position facts advance at those same boundaries. WS15 compresses trace
   storage while keeping every required logical row and instruction and
   sizing witness.
   *Evidence:* trace rows about 350 us per pulse today; the diff trace
   rebuilt exactly in the floor spike.
8. **Validate at boundaries, once.** Inputs are checked where they enter:
   snapshot, configuration, strategy output every pulse, imports. Trusted
   handoffs between stages are not re-checked. New transformations, applied
   rows and dynamic overflow or invariant failures keep named checks.
   *Evidence:* carrier validation 380 us per quiet pulse; kernel input
   validation about 10 to 16% of the recorded canonical FIFO blocks.
9. **Arithmetic order is contract.** Ordered bookings use plain double
   additions in event order: cash fill by fill, expected cash sells first,
   compensated realized P&L. No `sum()` or `cumsum()` where order matters.
   *Evidence:* LR-03 and LR-04 for cash order; the lean FIFO plain-sum
   negative control for compensation.
10. **Explanations on demand, invisibly.** A private value read inside the
    core returns values and admission only. Public history results keep
    their existing class, names, shape and recorded structural metadata;
    long diagnostic reads return cell evidence immediately. Later
    explanations use frozen retained summaries and never rerun user code or
    read a mutable pulse cursor. Only construction that the existing public
    surface cannot observe may be deferred.
    *Evidence:* a current history read assembles a selection table and an
    18-field metadata list on every call (`R/history-frame.R`, read plan).

### Ownership

11. **Data flows one way.** The core feeds the strategy's view; it never
    reads back from it. P2 never sees the next bar.
12. **Views are fresh and frozen.** The strategy gets a new view each
    pulse; a retained view cannot change. Retained-view immutability
    passed the seam; its separate cost was not isolated.
13. **One owner per mutable buffer.** The fold owns the book and the
    buffers; what leaves the fold is a copy or is never written again.
    Copy-on-modify of the book had no measurable cost at the two tested
    book sizes (116 and 788 slots).
14. **One implementation per concept.** One FIFO kernel, no fallback; one
    prepared representation. After the switch, runs, sweeps, tests and
    fixtures all use it; before the switch nothing in `R/` does.

### Method

15. **The oracle decides, the contract prevails.** Every piece is
    bit-identical to the pinned reference before it counts. A parity
    failure is a specification discovery and goes into the rules ledger
    (A3). Where the oracle contradicts `contracts.md`, the contract
    prevails and the defect is dispositioned on its own.
16. **Measure by function.** Per-function profile samples against the
    family budget (A2), not wall time alone.

### Code shape

17. **Shaped like the contracts.** Each stage is a small function with
    explicit inputs and outputs; each guarantee is a named layer with a
    cost. No duplicate validation inside trusted kernels.
18. **Small on purpose.** Line budgets per family (A2) and subtraction at
    every close (A4).

## 3. Data Structures

### 3.1 Prepared run (built once, immutable)

| Part | Shape |
| --- | --- |
| axis | session epochs (double); ISO strings for display |
| instruments | ids in run-axis order, one global identity per instrument including re-entries; one hashed lookup built once |
| tiles | tiles, each with `t0`, `t1`, a column map (global instrument to tile column, `NA` if not stored) and one double matrix per plane, sessions x instruments |
| planes | raw bar fields (`open`, `high`, `low`, `close`, `volume`), `observed`, and vintage feature values by slot |
| treatment | the base masks (expected sessions, terminal barrier, carry source) plus per-instrument overlays for late-known facts, keyed by knowledge epoch |
| segments and change points | flat typed columns with instrument offsets, effective and knowledge boundaries, state codes, reasons and witnesses, from the substrate's existing segments |
| names | feature aliases and field names resolved to slots |

**Two clocks.** A bar history read uses the treatment knowable at its read
cutoff: a late-known fact changes the masks of an earlier session from
its knowledge epoch on (`ledgr_history_cutoff_planes()`). A feature cell
keeps the masks knowable at its own pulse (`ledgr_history_vintage_planes()`).
Raw bars are stored once. Treated bar history is the raw tile plus the base
mask or the overlay for the cutoff's epoch, never a single pre-treated
plane.

**What a tile stores.** Tile inclusion is a physical storage rule. Leaving
an instrument out of a tile must still reproduce exactly what the substrate
returns today, including inactive but readable prints, carried values,
explicit requests for off-axis instruments, and late-known facts on either
side of an edge. Carry source, carry age and lifetime and terminal barriers
cross tile edges. Pulse-current membership and availability vectors are
execution cursors only, not the history authority.

**Tile width and memory.** Tile width is a storage choice inside a declared
resident working-set budget, not a limit on public history requests. Any
finite lookback and `lookback = Inf` may span any number of tiles, and no
request or `requires_bars` overrides the budget. The first memory
checkpoint (Section 4) sets the width, how many tiles stay resident, how
other history is reached, eviction, and who owns a tile a retained view
still points to. If exact supported reads cannot fit that design, the work
stops for maintainer disposition.

**History admission.** Selection follows `contract-strategy-decision-axis`.
Admission counts the finite values in the returned treated window,
including carried values, against `min_observations`, with the defaults
and empty-window behavior of `contract-context-pulse-data`. A trailing
count of consecutive finite values may serve as a shortcut for the
complete-window default only; general requests use an exact window count.
Bar windows use the read cutoff's treatment and feature windows use vintage
cells. Exclusion precedence, selection counts and `min_instruments` warmup
stay as they are. No past-membership plane is kept (past membership does
not exclude history), but observation flags alone never decide admission.

**Change points.** Membership and availability change rarely. The fold
applies the change points as it passes them and keeps one live vector of
each, so the work is proportional to the number of changes. The change
points keep their effective and knowledge boundaries, resolver precedence
and witnesses.

### 3.2 Pulse view (built each pulse, handed to the strategy)

Inside the core the per-pulse packet is positional typed data: column
slices for bars, positions and membership, and slot readers for features
and history that know the pulse. The strategy still receives the classed
flat lazy `ctx` that `contract-context-pulse-data` defines: aliases,
`ledgr_unknown_context_field` for an unknown field, enumeration that
forces nothing, each column built at most once, the helpers, and frozen
retention. Private slot readers do not become public fields. The bans on
dispatch, caches and environments apply to the trusted arithmetic, not to
what that public boundary needs.

### 3.3 Fold state (mutated by the fold only)

Typed vectors on the run axis: quantities and targets; asset-state fields
with their declared types and reset rules; portfolio-state fields as typed
scalars; cash as a double; the flat typed lot book from the lean kernel.

### 3.4 Recorder

Preallocated typed columns with a row counter, grown by doubling. Fills
and ledger events append per fill; the trace appends differences (WS15).
Frames are built at the existing output services' boundaries (Section 1),
not once at the end.

## 4. First Checkpoint

The workstream rules are in macro plan WS16 and are not repeated here:
`dev/lean_core/` only, nothing in `R/` calls it, no hybrid or fallback,
evidence provisional until the WS7/WS8/WS15 close is pinned, line-by-line
maintainer review of the skeleton and first family, budgets and
subtraction at every close, two correction rounds before escalation.
Record the commit any provisional evidence was taken on, then rerun it on
the pinned close.

The first checkpoint is two separately reviewed workstreams.

**Memory preparation** (synthesis Section 4). It chooses and measures tile
width and residency before any further family grows. It keeps the existing
feature algorithm and evidence and adapts its input access and output
allocation to the tiled substrate without changing calculation semantics;
it is not a second feature engine. It reports separately:
source and history, feature payload, resident tiles, summaries, transient
copies, lots, retained views and output, and parent, worker and
process-tree peaks. It varies history length at fixed tile width and worker
count on the portable and registered scale shapes of synthesis Section 4.
The paired 1.10 resource gate of `contract-verification-release-gates`
binds. Writing features straight into tiles, and its peak, are hypotheses
until measured. Spilling tiles to disk so sweep workers can share them is
measured here against in-memory copies before it is decided.

**The complete R FIFO kernel** (synthesis Section 3). It covers openings,
fills and dispositions; blocks that repeat an instrument; replay, import
and recovery inputs; signed opening basis and unchanged opening
compensation; zero-price exhaustion; replay witnesses; dust; fee splits;
cached totals; and earliest-refusal precedence. Parity compares the whole
book and every applied field, with negative witnesses and checks that
retained inputs are not modified.

**Before coding**, write the interface table for this checkpoint: for each
field its type, axis, unit, invariant, producer, validator and owner, with
`contract-execution-fold-carrier` as the semantic baseline. Name the
existing services reused and the preparation allocation boundary being
changed. P1 alone reads the substrate; P2 receives only its cutoff-bound
view; P3 to P5 receive no substrate or history handle. Stop installation
and the append, flush and publication order stay as they are. Record each
workstream's microsecond budget, added-line budget and measurement boundary
before scoring.

## 5. What Changes From Today

The planes themselves are right and stay: instrument x session bar
matrices (`R/history-substrate.R`), feature matrices over full series
(`R/runtime-projection.R`), and large history reads that already cost about
one copy (`dev/bench/v0_2_2_history_manifestation/`). What changes is the
handling around them:

- Feature values are split per instrument and reassembled into a matrix by
  a loop (`R/history-substrate.R` payload, `R/runtime-projection.R`). One
  format: the tile matrix.
- Fixtures and interactive consumers stay on the shared prepared
  representation. Flat fixture access already prepares a feature matrix
  (`R/pulse-context.R`), and snapshot inspection already uses the
  experiment preparation path (`R/pulse-snapshot.R`).
- Names are resolved and attached per call and per pulse. They are resolved
  once.
- The context is refreshed per pulse with a new cache environment and
  re-named lists (`R/pulse-context.R`, lookup refresh). The core builds a
  positional packet; the public `ctx` boundary stays (Section 3.2).
- A history read re-validates, re-derives admission and assembles metadata
  every call (`R/history-frame.R`, read plan): about 240 us for a 5-session
  bar window over 10 instruments, 450 us for a feature window, and 12.6 ms
  for a 252-session feature window over 500 instruments
  (`dev/spikes/data_layout/q7_history_read.R`). Admission uses the exact
  request-specific count of Section 3.1; only metadata the public surface
  cannot observe is deferred.
- Dense instrument-major whole-axis planes become compact time-major tiles.
- Membership and availability are applied as change points, not
  re-derived per pulse.

## 6. Evidence At A Glance

| Probe | Lean | Current | Source |
| --- | ---: | ---: | --- |
| fixed-basket pulse, floor plus priced guarantees | 26 to 103 us | 2.8 to 8.3 ms | `dev/spikes/r_floor/` |
| P2 strategy context, changing axis | 14 to 50 us | 664 to 1,479 us | `dev/spikes/r_floor/` |
| lot kernel per fill block | 92 to 190 us | 223 to 417 us | `dev/spikes/lean_fifo/` |
| synthetic instrument-major tile pulse, 3,427 live (tiles vs dense) | 9 us | 11 us | `dev/spikes/data_layout/` |
| orientation, pulse slice, 3,400 live (time-major vs instrument-major) | 14 us | 10 us | `dev/spikes/data_layout/` |
| recorded private-catalog payload estimate per plane, 252-session tiles (MiB; excludes maps, summaries and preparation peak) | 391 | 1,291 | `dev/spikes/data_layout/` |
| history window 252 x 500 (time-major tile slice vs complete current feature read) | 191 us | 12,580 us | `dev/spikes/data_layout/` |

Different probes have different clocks and host controls. The fixed-basket
row is floor-loop against durable-run time; 191 against 12,580 us is a
slice against a complete public read. None is a matched-stage speedup or an
acceptance budget. The payload estimate is not extrapolated to other tile
widths.

## 7. Decisions And Remaining Questions

Worked through with the maintainer on 2026-11-03; revised 2026-11-04.

1. **Named stages, decided.** The loop calls named stages, each a small
   function passing a few typed vectors rather than carrier objects. A
   function call costs well under a microsecond; each stage stays testable,
   profilable and budgetable on its own.
2. **Time-major tiles, decided** (principle 4). Measured in
   `dev/spikes/data_layout/q2_orientation.R`.
3. **Tile width, residency and spilling, set by the memory checkpoint**
   (Sections 3.1 and 4). Reads go through one tile accessor, so the answer
   is a local change.
4. **Preparation, set by the memory checkpoint** (Section 4). The existing
   feature calculation stays; its input access and output allocation adapt
   to the tiled substrate (Section 4).
5. **Membership and availability as change points, decided** (Section
   3.1).
6. **Small history reads, measured.** Today's measured complete-call cost
   at 10 instruments is about 240 us for bars and 450 us for features
   (Section 5). Measure the complete lean public read, including general
   admission and required metadata, before setting its baseline-derived P2
   budget under A2; a slice timing is only a component target.
