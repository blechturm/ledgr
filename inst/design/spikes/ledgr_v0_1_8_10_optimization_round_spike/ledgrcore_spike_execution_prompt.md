# ledgrcore-spike Execution Prompt

## Your mission

Author the spike specification document, implement the minimum-viable
measurement harness (R reference + Rust extendr + C++ cpp11), run the
four-number measurement protocol per ledgr's K1 charter, and author
the build / scope-further / park verdict. You are not building a
production package; you are running a research spike that answers
"does a compiled fold core deliver a meaningful gap over post-v0.1.8.10
production R, and if so, by how much, on which boundary, in which
language?"

The scaffold is already in place at
`c:/Users/maxth/Documents/GitHub/ledgrcore-spike` (see
`ledgrcore_spike_scaffold_prompt.md` for what was set up, including
the discipline files `ledgr_context_index.md` and
`ledgrcore_spike_decision_log.md` that you must keep current as you
work).

## Authoritative spec

Source of truth: ledgr's `inst/design/horizon.md` K1 entries and the
v0.1.8.10 architecture_synthesis Round-3 substrate decision. Read
these BEFORE authoring the spike spec:

- `inst/design/horizon.md` 2026-05-30 entry: "Compiled fold core as
  `ledgrcore` sister package" — the original K1 framing, the four
  load-bearing numbers, the decision-rule thresholds (1.5x park /
  2-3x scope-further / 5x+ build authorized).
- `inst/design/horizon.md` 2026-06-01 update inside that entry:
  measurement-spike gate, repo-split decision, the "fair comparison
  is post-substrate R vs compiled" framing.
- `inst/design/horizon.md` 2026-06-01 entry: "R-side data structures
  as shared substrate for compiled-core path" — the substrate
  framing this spike measures against.
- `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis.md`
  Round 3 — specifically L7 Ticket 2 (fold-owned accounting) and L9
  (substrate expansion principle). The post-v0.1.8.10 R baseline
  this spike measures against includes fold-owned FIFO lot
  accounting per Round-3 L9.

The four load-bearing numbers (quote them verbatim in the spike
spec):

1. per-pulse cost with R strategy callback (realistic boundary case);
2. per-pulse cost with an inline static strategy (compiled-only ceiling);
3. per-fill cost with R output-handler callback (realistic boundary case);
4. per-fill cost with inline event accumulation (compiled-only ceiling).

The decision-rule thresholds:

- gaps < 1.5x on both per-pulse and per-fill: park `ledgrcore`;
- gaps 2-3x: `ledgrcore` is worth scoping with explicit cost/benefit
  math;
- gaps 5x+: compiled story is empirically load-bearing; build is
  authorized; language choice driven by the spike's measured
  boundary-cost differential.

## Repository context

- `ledgrcore-spike` repo: `c:/Users/maxth/Documents/GitHub/ledgrcore-spike`
  (this is where you work).
- `ledgr` repo (design context, read-only):
  `c:/Users/maxth/Documents/GitHub/ledgr`.

Continue maintaining `inst/design/ledgr_context_index.md` as you read
new files from ledgr. Continue using
`inst/design/ledgrcore_spike_decision_log.md` for any ambiguity
resolutions. Stage hand-offs (per definition-of-done below) are
natural checkpoints where the maintainer reviews before you proceed.

## Stage 1 — Author the spike specification document

**Deliverable:**
`inst/design/spikes/k1_measurement_spike/spec.md` in the
ledgrcore-spike repo, plus matching `README.md` for the spike
directory.

**What the spec must define:**

1. **The minimum-viable fold loop shape.** Per the horizon: bars
   matrix in, equity vector out. The loop must include fold-owned
   accounting (cash, positions, FIFO lots) per the v0.1.8.10
   Round-3 substrate decision — otherwise the K1 measurement
   compares "compiled fold (no lot) vs R fold (no lot)" and
   understates the compiled-core opportunity (per Round-3 L9
   substrate-expansion principle). DO NOT include features the
   horizon excludes (real cost-resolver, runtime projection,
   feature engine, telemetry, durable writes). This is a research
   harness, not a fold-engine reimplementation.

2. **The four boundary variants.** Each measurement runs ONE
   combination of strategy boundary (R callback or inline static)
   and output-handler boundary (R callback or inline event
   accumulation). Define a static strategy that produces a
   deterministic non-trivial fill stream (e.g. "rebalance to
   equal weight every 5 pulses"). Define the inline event
   accumulator as a typed numeric / integer vector buffer with no
   R-side callback per event.

3. **The scales (synthetic grid).** Match LDG-2479 grid cells: at
   minimum `large` (100 inst × 1260 pulses × ~13.5k fills) and
   `xlarge` (1000 inst × 1260 pulses × ~130k fills). Include a
   smaller cell (50 inst × 1260 pulses) for fast parity-gate
   iteration. Pulse count fixed at 1260 (matches production EOD
   reference workloads).

4. **The parity gates.** Byte-identical equity vector AND
   byte-identical event stream (or numerically-equivalent within
   the Kahan vs cumsum tolerance per ledgr v0.1.8.9 L4) between
   all three implementations (R reference, Rust compiled, C++
   compiled) at the smallest scale. Parity gate MUST pass before
   any timing run.

5. **The measurement protocol.** Per (boundary variant ×
   implementation × scale) cell: N reps (recommend N=5),
   warm-cache vs cold-cache discipline named, median wall time
   reported, per-pulse and per-fill costs derived. Outputs to
   `dev/bench/results/k1_measurement_<date>.csv` with explicit
   columns for boundary variant, implementation, scale, n_pulses,
   n_fills, wall_median, wall_min, wall_max, us_per_pulse,
   us_per_fill.

6. **The verdict authorship.** Decision-rule application: compare
   compiled-vs-R per-pulse and per-fill gaps against the 1.5x /
   2-3x / 5x+ thresholds. Verdict document at
   `inst/design/spikes/k1_measurement_spike/verdict.md` per the
   horizon's specified shape.

7. **Determinism contract.** Cross-platform deterministic random
   number generation for any fixture randomness; fixed seeds; no
   wall-clock-dependent inputs. The release contract for any
   future `ledgrcore` is byte-identical event-stream parity with
   the pure-R reference; the spike's parity gate is the
   forerunner of that contract.

**Out of scope for Stage 1 (do NOT include in the spec):**

- Cost-resolver semantics (the spike uses zero-cost fills).
- Feature engine / runtime projection (the spike has no features).
- Strategy callback contract addendum (`ctx$vec` etc.) — the spike's
  R-callback variant uses a minimal `ctx` shape sufficient for the
  static rebalance strategy, not ledgr's full ctx surface.
- Durable / DuckDB I/O (the spike is in-memory only).
- Telemetry exposure (the spike measures wall directly; no subphase
  decomposition needed for the four load-bearing numbers).
- Multiple cell types from the workload grid beyond {small, large,
  xlarge}.

**Hand-off after Stage 1:** brief deliverables summary listing
spec path, scales decided, parity gate decision, decision_log
additions, ledgr files read. Stop and wait for maintainer review of
the spec before proceeding to Stage 2.

## Stage 2 — R reference implementation

**Deliverable:** `R/k1_r_reference.R` in the ledgrcore-spike repo,
plus a parity-gate test under `tests/testthat/test-k1-parity.R`
that compares the R reference to itself on a fixed seed (basic
sanity check; cross-implementation parity comes in Stages 3 and 4).

**What to implement:**

1. The minimum-viable fold loop in pure R, matching the spec's
   bars-matrix-in-equity-vector-out shape with fold-owned
   accounting.

2. The four boundary-variant entry points exposed as four R
   functions:
   - `k1_r_fold_strat_R_handler_R(bars, ...)` — both R callbacks.
   - `k1_r_fold_strat_R_handler_inline(bars, ...)` — R strategy +
     inline output accumulation.
   - `k1_r_fold_strat_static_handler_R(bars, ...)` — static
     strategy + R output handler.
   - `k1_r_fold_strat_static_handler_inline(bars, ...)` — both
     inline (compiled-only ceiling baseline; in R this is the
     ceiling-floor distinction by design).

3. The static rebalance strategy as a self-contained function.

4. The R-callback strategy as a thin wrapper around the static
   rebalance (so the R-vs-static comparison isolates callback
   overhead).

5. The R output handler as a thin R function the loop calls per
   fill event, accumulating into a simple list/data.frame.

6. The inline event accumulator as a preallocated numeric / integer
   buffer the loop writes into directly (matching what compiled
   cores would do).

**Parity gate (Stage 2):** the four R entry points produce the
same equity vector (within Kahan tolerance) on the smallest scale
fixture with a fixed seed. This is a self-consistency check, not a
cross-implementation check.

**Hand-off after Stage 2:** parity confirmed on smallest scale;
R entry points runnable; brief deliverables summary.

## Stage 3 — Rust extendr implementation

**Deliverable:** the same four entry points implemented in Rust via
extendr, exposed to R as `k1_rust_fold_<variant>()`. Code lives
under `src-rust/src/` and is registered through the existing
extendr module setup.

**What to implement:**

1. The same minimum-viable fold loop in Rust, mirroring the R
   reference's algorithm step-for-step.

2. The four boundary variants. The R-callback variants call back
   into R through `extendr_api::eval_string` or the appropriate
   extendr callback mechanism (the spike's job is to measure
   exactly this boundary cost, so the callback path must be
   honest — no shortcuts that bypass the R interpreter for the
   "R-callback" variant).

3. FIFO lot accounting in Rust. Use whatever representation reads
   cleanly (Vec<Lot>, indexed by inst_idx). Determinism matters:
   floating-point reduction order must be specified.

4. The inline event accumulator as a Rust Vec<f64> / Vec<i32>
   that the loop writes into directly, returned to R as a numeric
   vector at the end.

**Parity gate (Stage 3):** at the smallest scale, with a fixed
seed, the equity vector AND the event-stream (fills tibble or
equivalent) produced by all four Rust variants must match the
corresponding R reference variants byte-identical (or within Kahan
tolerance for equity, byte-identical for integer / character
fields). Parity MUST pass before any Stage-5 timing run.

**Hand-off after Stage 3:** Rust extendr build clean; parity
against R reference confirmed; brief deliverables summary noting
any Rust-specific implementation decisions added to
`decision_log.md`.

## Stage 4 — C++ cpp11 implementation

**Deliverable:** same as Stage 3 but in C++ via cpp11. Code lives
under `src/` and is registered through the existing cpp11 setup.

**What to implement:** same four boundary variants, same algorithm,
same parity gate against the R reference.

**Parity gate (Stage 4):** equity vector and event stream
byte-identical (or Kahan-tolerant) against R reference and against
Rust at the smallest scale, with a fixed seed.

**Hand-off after Stage 4:** C++ cpp11 build clean; three-way
parity confirmed (R / Rust / C++); brief deliverables summary.

## Stage 5 — Measurement runs

**Deliverable:** `dev/bench/results/k1_measurement_<YYYYMMDD>.csv`
plus `dev/bench/notes/k1_measurement_methodology.md` documenting
the run discipline.

**What to run:**

For each of (boundary variant × implementation × scale) =
(4 × 3 × 3) = 36 cells:

- N reps (recommend N=5; if any cell takes > 5 minutes per rep,
  reduce to N=3 for that cell only and note in methodology).
- Garbage-collect between reps (the R-side `gc(FALSE)` discipline
  used in ledgr's spike scripts).
- Record wall median, min, max.
- Derive `us_per_pulse = wall_median * 1e6 / n_pulses` and
  `us_per_fill = wall_median * 1e6 / n_fills`.

**Methodology discipline:**

- Warm-cache: the first rep per cell is discarded (run N+1 reps,
  drop first). Document this.
- Cross-implementation invocation order randomized per cell to
  avoid systematic ordering bias.
- If any timing rep shows > 3x deviation from the median, flag in
  methodology notes; investigate before trusting the cell.
- Cross-platform note: this spike runs on Windows R 4.5.2 with
  Rtools / extendr / cpp11 toolchain per the scaffold. Platform
  is named in the methodology doc; any later cross-platform
  comparison requires explicit re-runs.

**Out of scope for Stage 5:**

- Production-workload benchmarks against ledgr's full sweep dispatch
  (the spike measures the minimum-viable loop, not ledgr's
  per-strategy peer workloads).
- Cost / liquidity / risk-step measurements (the spike has none).
- Memory profiling, GC profiling, allocation counting (wall is the
  load-bearing measurement per the horizon's K1 spec).

**Hand-off after Stage 5:** results CSV written; methodology note
written; brief deliverables summary listing any anomalous cells
flagged.

## Stage 6 — Verdict authoring

**Deliverable:** `inst/design/spikes/k1_measurement_spike/verdict.md`.

**What the verdict must contain:**

1. **Headline number:** per-pulse and per-fill gaps for each
   compiled-vs-R comparison at the xlarge scale. Six numbers:
   (Rust vs R, C++ vs R) × (per-pulse strat_R_handler_R, per-pulse
   strat_static_handler_inline, per-fill strat_R_handler_R,
   per-fill strat_static_handler_inline). Plus the
   strat_R_handler_inline and strat_static_handler_R cells for
   completeness.

2. **Decision-rule verdict per the horizon thresholds.**
   - All gaps < 1.5x: park `ledgrcore` (the spike answered
     "compiled is not worth it on this substrate").
   - Some gaps 2-3x: scope `ledgrcore` further with explicit
     cost/benefit math against the substrate-round residual.
   - Some gaps 5x+: build is authorized; the language choice is
     driven by the boundary-cost differential between Rust and
     C++ (per horizon decision: not by ecosystem-alignment or
     memory-safety priors).

3. **Language verdict (if build authorized).** Compare Rust
   extendr vs C++ cpp11 on the same numbers; identify which
   language's boundary cost is smaller; cite the specific cells.
   Document any toolchain-friction findings (build complexity,
   cross-platform readiness, etc.) that should weigh against pure
   speed.

4. **Confidence and caveats.** Synthetic-fixture limitations,
   platform-specific notes, what would change the verdict if
   measured on production R workloads, what the horizon's
   "post-substrate R" framing means once v0.1.8.10 ships and the
   R baseline gets the fold-owned accounting Round-3 specifies.

5. **Cross-link back to ledgr.** The verdict should be readable by
   the maintainer landing a ledgr-side horizon update. Quote the
   horizon's K1 entry language verbatim where the verdict
   directly answers an entry's open question. State the date the
   verdict was authored.

**Hand-off after Stage 6:** verdict written; final deliverables
summary listing every stage's output, every decision_log entry,
the headline numbers, and the verdict shape.

## Determinism and parity gates (cross-cutting)

These apply throughout:

- Every measurement uses a fixed seed. Document the seed in the
  spec and in every result file.
- Equity vector parity: Kahan-tolerant cross-implementation
  agreement (the v0.1.8.9 L4 doctrine; name the tolerance
  mechanism in the spec, not as "DuckDB float noise").
- Event-stream parity: byte-identical integer / character fields
  across implementations; numerical fields within Kahan tolerance.
- Cross-platform note: this spike runs Windows-only for now. The
  release contract for any future `ledgrcore` will require
  cross-platform determinism (Linux + macOS + Windows); the spike
  does not need to demonstrate it but should not rely on
  Windows-specific tricks.

## Out of scope (do NOT do these)

- Do not turn this into a CRAN-ready package. The spike is research
  scaffolding; production hardening comes later if the verdict is
  "build authorized".
- Do not implement features beyond what the four load-bearing
  numbers require (no risk steps, no cost resolvers, no telemetry,
  no durable writes, no feature engine, no runtime projection).
- Do not depend on ledgr at runtime. Read ledgr at design time only
  (per scaffold prompt discipline).
- Do not author new RFCs. The horizon's K1 entry is the binding
  doctrine; the spike spec operationalizes it; no RFC cycle needed
  unless the maintainer asks.
- Do not run the measurement against the actual ledgr installed
  package as the R baseline yet — v0.1.8.10 has not shipped. The
  R reference in this repo IS the baseline; document that the
  baseline reflects the v0.1.8.10 substrate-decision shape per
  Round-3 L9, not the current ledgr R fold.
- Do not extrapolate the spike's numbers into ledgr's production
  workload-grid units. The horizon's K1 entry asks for per-pulse
  and per-fill cost in microseconds; that's the language to use.
- Do not commit secrets, credentials, or large binary measurement
  artifacts. CSV results under `dev/bench/results/` are fine;
  anything larger than 10 MB needs maintainer sign-off.

## Ambiguity handling

Same discipline as the scaffold prompt: document every ambiguity
resolution in `inst/design/ledgrcore_spike_decision_log.md` with
the question, alternatives considered, choice made, and one-sentence
rationale. Flag large decisions in the stage hand-off as "needs
maintainer review". Do not block on minor decisions.

If you encounter a decision the horizon's K1 entry should bind but
does not (e.g. tolerance value for Kahan-vs-cumsum at xlarge,
event-buffer overflow policy), pick a reasonable default, log the
decision, and surface it for maintainer review.

## Definition of done (all six stages)

1. `inst/design/spikes/k1_measurement_spike/spec.md` authored,
   maintainer-reviewed, and binding for the measurement
   implementation.
2. R reference implementation runs cleanly via `devtools::load_all()`
   and produces the four entry points.
3. Rust extendr implementation builds cleanly via `cargo build` and
   exposes the four entry points; three-way parity with R reference
   confirmed at smallest scale.
4. C++ cpp11 implementation builds cleanly via
   `R CMD INSTALL .` and exposes the four entry points; three-way
   parity with R reference and Rust confirmed at smallest scale.
5. Measurement CSV at `dev/bench/results/` populated for all 36
   cells (or documented exceptions for cells that hit the per-rep
   wall ceiling).
6. Methodology note at `dev/bench/notes/k1_measurement_methodology.md`
   documents reps discipline, warm-cache discipline, randomization,
   anomaly flagging, platform.
7. Verdict at `inst/design/spikes/k1_measurement_spike/verdict.md`
   answers the horizon's K1 question with headline numbers,
   threshold-mapped verdict, language verdict (if applicable), and
   confidence / caveats section.
8. `inst/design/ledgr_context_index.md` updated with every new
   ledgr file read across stages.
9. `inst/design/ledgrcore_spike_decision_log.md` updated with every
   ambiguity resolution.
10. Git history shows clean per-stage commits (one commit per
    stage minimum; smaller commits welcome).
11. GitHub repo pushed; final commit summary in the deliverables
    summary message.

## After you finish

Stop. The maintainer will read the verdict, decide the next step
(park / scope further / authorize the build), and land any
necessary ledgr-side horizon update. If the verdict authorizes a
build, the repo will be renamed from `ledgrcore-spike` to
`ledgrcore` as a one-time GitHub operation and a fresh roadmap
authored. Your work ends at "verdict authored; pushed to GitHub;
deliverables summary written".
