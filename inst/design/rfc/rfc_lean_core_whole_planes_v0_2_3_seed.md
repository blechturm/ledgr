# Amendment: Lean Core Whole Planes (v0.2.3), Seed v1

- Status: **accepted** by the maintainer on 2026-11-08 as written, without a
  review cycle ("we measured and found the thing we designed lacking"); the
  WS28 close review (Type 1) reads the installed text. Section 4 (W1-W5) is
  appended as a dated amendment to the
  [skeleton synthesis](rfc_lean_core_skeleton_v0_2_3_synthesis.md#amendment-maintainer-2026-11-08-whole-planes)
  and the [lean fold core synthesis](rfc_lean_fold_core_v0_2_3_synthesis.md#amendment-maintainer-2026-11-08-whole-planes),
  with a notice in each affected section. Before acceptance this was a
  proposed amendment; the text below is unchanged.
- Authors: maintainer with Claude, 2026-11-08.
- Amends: the [lean fold core synthesis](rfc_lean_fold_core_v0_2_3_synthesis.md)
  Section 4 (Memory And Family Order); the
  [lean core skeleton synthesis](rfc_lean_core_skeleton_v0_2_3_synthesis.md)
  Section 3 (first paragraph) and Section 5.1; Cut 12 decision (6) in
  `tickets.yml`; [lean_core_interface.md](../ledgr_v0_2_3_spec_packet/lean_core_interface.md)
  Section 12.3; the acceptance of LDG-3216 and LDG-3217.
- Evidence: `dev/bench/v0_2_3_ws28_prep_diag/` (commits `c1a6a9eb` through
  `e17559aa`), on the pinned reference `d5b3a151`, with LDG-3216's parity
  runner (`dev/lean_core/parity/`). Private H1 rows are megabytes and digests
  only.
- Scope: the lean core under `dev/lean_core/` only. The old fold core stays
  the frozen oracle and is not changed. Nothing in `R/` changes.

## 1. The Question

The accepted design prepares history as tiles: blocks of sessions, with the
derived planes (expected mask, last barrier, carry sources) kept to three
resident tiles so that their memory does not grow with history length.
LDG-3216 built it and proved it exact against the pin. Before LDG-3217's
timing gate, a preview showed lean preparation at 1.40x pinned and two short
reads at about 2x. This seed asks whether tiles are worth that cost, and what
replaces them if not.

## 2. What Was Measured

All runs use cut12-prep-1's workload and clocks on 500 x 5,040, a prebuilt
store copied per slot, arms alternating, High performance plan, P-core
affinity. Every arm's work string (decided pulses, fills, final equity and a
digest of every read result) is identical to the pin's.

**Tiles are not the cost; the access layer is.** Median ratio to pinned, 3
rounds (`evidence/clock.csv`):

| Arm | prep | r1 | r2 | r3 | r4 | r5 | r6 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| tiles, time-major (approved) | 1.44 | 2.98 | 1.05 | 1.61 | 1.21 | 2.52 | 1.56 |
| tiles, instrument-major | 1.40 | 2.36 | 1.02 | 1.43 | 1.11 | 1.97 | 1.42 |
| one tile spanning the history | 1.20 | 2.18 | 1.05 | 1.37 | 1.10 | 1.88 | 1.34 |

One tile, with no edges, is nearly as slow as many. The pin's read kernels are
C++ that take whole matrices and absolute positions, with no copy. Lean planes
are R objects that must find the tile, build an index and copy a slice before
any kernel runs. Per call, unwrapped, at 500 instruments
(`access_bench.R`): a 21-session read costs 37 us from a tile against 13 us
from a plain matrix; a 252-session read across an edge 317 against 117 us,
because R must copy each tile's piece and then bind them. The fold's
per-pulse bar packet, which no gate clock covers, cost about 5.7x the pin's
in the wrapped stage run (`evidence/stages_4arms.csv`), above LDG-3215's
per-pulse budget.

**The best tiled variant still misses.** Plain matrices for the resident bar
and feature planes, direct slices of full working tiles and four tiles per
bar query (`evidence/clock_builds.csv`): prep 0.99, r1 2.09, r2 1.07, r3
1.19, r4 1.09, r5 2.05, r6 1.35. Building working tiles inside reads takes
0.26 s of the 0.88 s read excess; the pin builds its mask planes in a step
its read clocks subtract.

**Whole planes reach the pin's reads.** Bar planes allocated once at full
size and filled in place from chunked bar queries (no long frame), feature
series whole, masks, carry planes and reads left to the pinned code. Median
of 8 rounds (`evidence/clock_whole8.csv`): r1 1.06, r2 0.99, r3 0.98, r4
1.03, r5 1.14, r6 1.08, prep 1.14. Per pair, prep ranges 0.85-1.27 and r5
0.77-1.54; prep plus all reads, per pair, 0.97-1.08. A wrapped stage run
(`evidence/stages_pinned_whole.csv`) shows lean preparation spending
slightly less self time than the pin's; the remaining prep gap is not yet
explained (Section 6).

**Tiles buy little memory.** Peak private commit, MiB, one fresh process per
arm (`mem.R`, `evidence/mem_*.csv`):

| | pinned | tiles as built | whole planes |
| --- | --- | --- | --- |
| 500 x 5,040, during preparation | 979 | 884 | 903 |
| 500 x 5,040, whole run | 1,263 | 1,214 | 1,171 |
| H1, during preparation | 2,539 | 1,735 | 1,683 |
| H1, whole run | 4,875 | 4,500 | 4,767 |

The preparation saving comes from not holding the whole-history long bar
frame, which whole planes keep. The run peak is set after preparation in
every arm. On H1, whole planes cost about 270 MiB (6%) more than tiles at
that peak and stay below the pin. Source tiles were always all resident, so
history memory already grew with history length under the tile design; only
the derived planes were bounded.

## 3. What This Implies

A bounded working set for derived planes costs up to 2x on short reads and
about 0.45 ms per read call in R, and saves about 6% at the H1 run peak. The
lean fold core synthesis Section 4 anticipated the stop: "if an exact bounded
implementation cannot do so, stop for maintainer disposition". The tiled
implementation is exact, but cannot meet Cut 12 decision (5) within the cut's
scope, which excludes compiled kernels.

## 4. Proposed Amendment

**W1. Whole planes.** Lean preparation keeps the pin's representation: each
bar field, `observed`, each feature series and each derived plane is one
instruments x sessions matrix for the run, allocated once at full size. There
are no tiles, no resident-tile limit, no eviction and no transient tile
buffer. Reads, packets, masks, carry sources, barriers and feature series use
the pinned code over these matrices.

**W2. Chunked in-place hydration.** Bars are read through the verified
snapshot handle with one bar query per chunk of sessions and written into the
preallocated planes by position (`collapse::fmatch`). A chunk is 4 x
max(252, ceiling(126,000 / instruments)) sessions: 1,008 at 500 instruments
and on H1, one query for the long intraday shapes. No whole-history long bar
frame exists. Duplicate bars refuse as the pin's do; a chunk edge never
changes a value.

**W3. Memory claim.** Replace the bounded working set with: lean preparation
holds no whole-history long bar frame, and its preparation peak is at most
the pinned arm's on 500 x 1,260, 2,520, 5,040 and private H1. Every resident
component and every peak (parent, worker, process tree; one and two workers)
is reported against the pinned arm, as before. History-length growth is
reported, not bounded. The paired history resource gate at the switch
(`contracts.md#contract-verification-release-gates`, its 1.10 limits and
exception route) is unchanged.

**W4. Text replaced.**

- Lean fold core synthesis Section 4, paragraphs 2 and 4: "physical tiling"
  and "tile" read as "chunked hydration"; "bound execution's prepared working
  tiles and buffers" is withdrawn under W3; "fixed tile width" reads as
  "fixed chunk width". The rest of Section 4 stands: no chunk resets state,
  history begins at the data start, no feature restarts, no truncation.
- Skeleton synthesis Section 3, first paragraph: "Choose compact time-major
  tiles" is replaced by W1; the inclusion paragraph is satisfied by the pin's
  whole-matrix semantics. Section 5.1, first two paragraphs: tile width,
  residency, eviction and recycling are withdrawn; chunk-boundary parity on
  the fixture at two chunk widths and the component report stand.
- Cut 12 decision (6): its first sentence is replaced by W3; the rest stands.
- Interface Section 12.3: rewritten to W1-W2. The spilling row (none) and the
  feature-input row stand.

**W5. Ticket acceptance.**

- LDG-3216, acceptance 1: two fixture chunk widths instead of two tile
  widths. Acceptance 2 (retained results after recycling) is withdrawn: there
  is no recycling, and retained results are ordinary R values. Acceptance 3's
  mutations are replaced by hydration mutations: a bar at a chunk edge
  dropped, a bar at a chunk edge fetched by both chunks, and duplicate bars
  within a chunk not refused. Acceptance 4 stands.
- LDG-3217, acceptance 1: replaced by W3. Timing (decision 5), the 900-line
  limit, the floor-v1 per-pulse budget and the remaining items stand.

## 5. Rejected Alternatives

| Alternative | Reason |
| --- | --- |
| Keep tiles; read them through a new C++ kernel | Cut 12 excludes compiled kernels; it adds compiled code to buy 6% at the H1 peak. |
| Overlapping tiles (each holds the previous 252 sessions) | Removes edge copies only; narrow reads stay about 3x per call. |
| Charge working-tile builds to preparation | An accounting change; tiled reads stay 1.3-2x. |
| Gate on prep plus reads together | Changes decision (5) to hide a per-read regression. |

## 6. Open Before The Gate

The whole-plane preparation median is 1.14x with wide pair noise, while the
stage run shows less lean work. LDG-3217 profiles it before the timing
record. A remaining miss goes to the maintainer under decision (5).

## 7. Affected Owners

The macro plan WS9b note ("whether sweep workers share prepared tiles") reads
"prepared planes"; the packet README line on "memory-bounded tile
preparation" is updated at acceptance. LDG-3215's evidence (fixture,
captures, frozen clocks, spilling result, R11 budget) stands; its tile-width
choice survives only as the chunk-size formula.
