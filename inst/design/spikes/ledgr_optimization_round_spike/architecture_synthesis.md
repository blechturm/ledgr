# Optimization-Round Architecture Synthesis

**Date:** 2026-05-29 · **Host:** Intel Core i9-12900K, Windows 11 · R 4.5.2,
collapse 2.1.7 · **Status:** v0.1.8.7 input (pre-RFC). **Reconciled** against
`codex_review_request_response.md` (2026-05-29): floor claim softened to "no
large measured floor," the 57% reframed as an empty-fold machinery bucket,
O(fills^2) marked a suspected mechanism, `nthreads=1L` added to the gate, the
sweep crossover marked a benchmark target, and the surface-preserving sequencing
nuance added.

**Synthesizes:** the four spikes in this directory's `README.md`
(`dev/spikes/spike-{event-buffer-rewrite,reconstruction-collapse,projection-collapse,amdahl-floor}`),
the real-run profile in `inst/design/audits/fold_path_hotpath_audit.md`, the
matched peer benchmark (LDG-2457), ADR 0004 (drop `cli`/`R6`, add `collapse`,
keep `tibble`), and `inst/design/collapse_optimization_map.md`.

**Why this exists:** ledgr was "abysmally slow" pre-v0.1.8 and is now ~2.74x
Backtrader (durable) / 3.33x (one-candidate sweep) on a matched local run. The
question for v0.1.8.7 was *where the residual cost is* and *whether it is
architectural or removable*. The spikes answer both. These are the lessons.

---

## L1. ledgr is machinery-bound, not callback-bound

**There is no *measured large* callback floor.** Spike 4 Part A shows the
minimum per-pulse *user-decision* work — building an n_inst target vector + a
vectorized decision — is tiny (6.84 us/pulse) relative to the fold loop. The
loop is overwhelmingly ledgr's *own* machinery (context build, feature access,
fill emission), which means it is ledgr's to optimize.

Scope caveat (Codex review): Part A does **not** call the real strategy through
the ledgr strategy path — it omits the R function call, `ctx` access mechanics,
target validation, and the invocation wrapper. So the measured number is a
*minimum user-decision/vector floor*, not the full strategy-callback floor.
Some irreducible machinery does remain — strategy invocation, minimal
context/primitive access, target validation, accounting transitions. So the
claim is **"no large measured floor," not "zero floor."**

The practical consequence stands: the single-run wall is not pinned near the
peers by an irreducible callback. "Catch the peers" is a *machinery race*, not a
dead end — a compiled core would flip it, and even pure R it is a question of how
lean the machinery gets. Do not cite "0.2%" as a hard architectural constant
until a variant includes a real strategy call.

## L2. The cost is localized, not diffuse — two shape-dependent rocks

The slowness is not death-by-a-thousand-cuts. It concentrates in two places, and
which one dominates depends on turnover:

- **Event buffer / emission** — **72-82% of loop R time at high turnover**
  (real-run profile, spike 1; `handler$buffer_event` in the durable run,
  `append_event_row_list` in the sweep). This is profile evidence, decisive.
- **Per-pulse boundary representation (timestamp/string formatting)** — the
  low-turnover rock, and **not** ctx-build as first hypothesized. The line-level
  profile (spike 2b, `spike-empty-fold-profile.md`) split the empty-fold bucket:
  **~62% is formatting** (`format.POSIXlt` alone is 26.6% *with zero trades*,
  plus `formatC`/`sprintf`/`paste`), only **~13% is the strategy/ctx callback**,
  and a surprising **~10% is `%||%`** (a hot null-coalesce). So the per-pulse
  equity/positions path formats timestamps per row — the same anti-pattern as the
  per-fill payload (audit finding #2), now shown to dominate even an empty fold.

Optimize in that order: the **buffer** first (it owns the turnover-heavy runs
people actually profile), the **representation/formatting lane** next (it owns
the low-turnover wall *and* part of the high-turnover emission — one cross-cutting
fix). ctx-build proper (~13%) is no longer a headline target.

## L3. The villain is per-event machinery, not event-sourcing

The stronger formulation (Codex review): **the villain is per-event boundary
representation *and* buffer machinery — over-allocation is one important part of
it, not the whole story.** The durable handler preallocates `n_inst * n_pulses`
and copies fills-sized columns per event (a real over-allocation smell), *and*
`ledgr_fill_event_payload()` normalizes timestamps, parses back to POSIXct,
builds metadata, serializes JSON (durable path), and formats event IDs per event.
Both feed the profile.

The fixes are **implementation, not architecture**. The factorial (spike 1b,
`spike-event-buffer-factorial.md`) isolated the three bundled changes:
- **capacity (worst-case -> doubling) is the whole structural win: 27-88x** —
  the over-allocation to `n_inst * n_pulses` is the villain;
- **storage topology (nested -> direct) is noise: ~1.0-1.2x** — no topology
  change is needed for the perf;
- **the write op (`collapse::setv`) is a turnover-scaling secondary lever:
  2.4x -> 8.0x** on top of the capacity fix (and 65-1300x vs the current
  worst-case baseline).

The **O(fills^2)** explanation is a *suspected mechanism*, consistent with the
profile but to be confirmed by re-profiling the production handler after the
rewrite (not asserted from the isolated replica). Priority rests on the
production profile; absolute asymptotics rest on the re-profile.

This is the central reassurance of the round: **"events are the source of truth,
views are derived" is not the tax.** The naive per-event machinery was. The
event-sourcing model — sealed snapshots, hash-verified determinism, derived
views — survives intact; the slowness is removable waste on top of it.

## L4. The anti-pattern catalogue (grep for these across the fold path)

The same handful of R performance anti-patterns recur. They are cheap to
recognize once named:

1. **Over-allocation to the worst-case product** — the buffer at `n_inst*n_pulses`.
2. **Per-item growth-by-copy** — copying fills-sized columns per event (the
   O(fills^2) trap).
3. **Per-row `data.frame()` + `do.call(rbind)`** — the fills-table assembly;
   `collapse::rowbind` (or preallocated columns) is **58x** here (spike 2,
   read-back path).
4. **Per-instrument `which()`-scan inside a loop** — reconstruction is
   O(n_inst^2) because `which(events$instrument_id == id)` re-scans all events
   per instrument; grouped `fcumsum(x, g)` is byte-identical and linear (spike 2).
5. **Per-fill timestamp format/re-parse round-trip** — `format.POSIXlt` in the
   hot path (audit finding #2); carry `POSIXct`, format once at the boundary.

## L5. Measurement discipline (the hardest-won lesson)

The order of operations is *spike -> real-run re-profile -> parity gate -> ship*,
and the re-profile is non-negotiable, because:

- **Isolated micro-benchmarks are unfaithful.** A buffer micro-benchmark misled
  the analysis once and caused finding #1 to be wrongly downgraded; the real-run
  profile re-confirmed it (72.43% self). Micro-benchmarks are refcount-sensitive
  and do not reproduce the real handler's closure-captured-list conditions.
- **Isolated sims overestimate absolute cost ~3x** (429s sim vs ~137s real
  buffer). Trust the *ratios and the mechanism* (tracemem), not the absolute
  seconds.
- **Component multiples are not wall multiples.** A 1300x on a component that is
  ~half the wall is ~1.8x overall (Amdahl). Never promise from a component
  number; bound it to the wall.

## L6. Determinism is a first-class constraint on *how* we optimize

collapse's value-bearing ops (`fcumsum`, `fmean`, ...) **do change results** under
a hostile caller `set_collapse(na.rm=...)` — proven in spike 2, not theoretical.
Because ledgr's USP *is* reproducibility, every value-bearing optimization carries
a gate, and spike 2 validated both defenses:

- pass collapse arguments **explicitly** (explicit beats the global), **and**
- run inside **`ledgr_with_collapse_deterministic()`**, which **must pin
  `nthreads = 1L`** (Codex review: threaded reductions like `fsum`/`fmean` can
  reorder floating-point accumulation and break byte-identity *even with `na.rm`
  pinned* — so `nthreads = 1L` is necessary, not just `na.rm`/`sort`), with
  scoped `set_collapse` + on-exit/error-path restore, **and**
- gate with a **byte-identical** event/equity/fills parity fixture + a hostile
  `set_collapse` invariance test.

Value-*neutral* ops (the buffer `setv`, an in-place write) do not need the value
gate. The distinction — value-bearing vs value-neutral — is the rule for which
optimizations require the wrapper. This constraint is unique to a backtester
whose product is determinism, and it shapes the optimization, not just gates it.

## L7. Where the architecture actually wins: amortization, not single runs

Single-run, ledgr races the peers on machinery (L1) — winnable but hard in pure
R against a decade-tuned Backtrader. The architecture's *expected* structural
advantage is the **sweep regime**: the sealed snapshot, feature precompute, and
bars views are built once and amortized across N candidates, where Backtrader's
`optstrategy` and quantstrat's `apply.paramset` re-run the per-candidate work.

But this is a **hypothesis to measure, not an established fact** (Codex review):
- the recorded one-candidate sweep was *slower* than the durable run, so
  `ledgr_sweep` carries real per-candidate costs (fold execution, event append,
  result assembly, candidate metadata, promotion/reproducibility bookkeeping)
  that must be amortized *past* before the crossover;
- the multi-candidate Backtrader/quantstrat opt comparison has **not** been
  measured locally.

So: "the expected architectural win is amortization across sweeps," and "the
crossover is an open benchmark target for v0.1.8.7, not a finding." Any candidate
count (e.g. "~50 candidates") is a hypothesis to test, not a conclusion. Spend
single-run effort on removing waste (L2-L4); *test* the win in a local
multi-candidate three-way (`ledgr_sweep` vs `apply.paramset` vs `optstrategy`).

## L8. The optimization sequence (forward, for the RFC)

A governance ordering precedes the implementation priority (Codex review): the
RFC must **bind the primitive-in-core rule and the emitted-event parity gates
first**, because whether Lane B can land first depends on what it touches:

- If the buffer fix is **surface-preserving** (only internal capacity, storage
  shape, and write op; same event rows) it lands first, behind **event-stream
  parity**.
- If it changes fill-model inputs, next-bar shape, context representation, or any
  strategy-visible surface, the **primitive-contract RFC must bind those choices
  first**.

Implementation priority, each behind the L5 discipline and the L6 gate:

1. **Buffer (Lane B)** — right-size + `setv`, where surface-preserving. The rock;
   ~1.8x turnover wall (estimate; confirm by re-profile). Value-neutral, but
   still needs event-stream parity.
2. **Representation / formatting lane (the low-turnover rock, cross-cutting).**
   Spike 2b shows ~62% of the empty fold is per-row timestamp/string formatting,
   and the same functions sit in the per-fill payload — so this one lane owns the
   low-turnover wall *and* part of the high-turnover emission. Work: carry trusted
   `POSIXct` end to end (format only at validated ingress / durable output);
   de-`sprintf`/`formatC` the per-row event/equity construction; audit the hot
   `%||%` (~10% of the empty fold). **Parity fixture:** `ts_utc` identical for
   daily/minute/second timestamps, explicit sub-second handling per the
   whole-second snapshot-seal contract (the new path must not preserve sub-second
   precision the current path truncates). (Plain ctx-build proper is only ~13% —
   not a headline lane; revisit only if the line-level profile of a feature-bearing
   run promotes it.)
4. **Reconstruction (collapse, value-bearing)** — `rowbind`/preallocated fills
   (read-back UX), grouped `fcumsum`. Behind the full L6 gate **and** real-ledgr
   fill-table fixtures (per spike 2's caveat: CASHFLOW-before-fill, opening
   positions, partial close/open, close-before-open split rows, invalid/missing
   rows, DB- and memory-backed tables, exact column order/classes/`event_seq`).
5. **Projection** — *not* a perf lane (spike 3), scoped to `features_wide`
   manifestation only. A matrix-canonical strategy surface is a **contract**
   decision for ergonomics, not a speed lane; `mctl` is dropped (slower than the
   base-R stamp).

Emission-lane parity hard gates: **`meta_json` must stay per-row canonical**
(`vapply(meta_list, canonical_json, character(1))`, never a single batched
array); the **event-id string must be preserved exactly** unless the RFC
explicitly changes the event-id contract.

Dependency moves that enable the above (ADR 0004): drop `cli` (unused), drop
`R6` (function-only strategy interface; also removes the original-vs-replay path
divergence), add `collapse` (zero transitive deps), keep `tibble` (tidyverse
signal). Net Imports 9 -> 8.

---

## One-paragraph version

ledgr's residual slowness is removable implementation waste, not an architectural
tax: there is no large measured callback floor, so the loop is overwhelmingly
optimizable ledgr machinery, concentrated in two shape-dependent rocks — the
event buffer/emission at high turnover (decisive in the profile; O(fills^2) is the
suspected mechanism, pending production re-profile) and the per-pulse empty-fold
machinery (context construction a plausible dominant part) at low turnover. The
event-sourcing model is sound; per-event machinery — over-allocation *and*
boundary representation — was the villain. Fixes are sequenced buffer ->
ctx/primitive build, gated by the RFC's primitive-in-core + emitted-event parity
rules, validated by real-run re-profiles (never micro-benchmarks) and
Amdahl-bounded to the wall, with a mandatory determinism gate (incl. `nthreads =
1L`) on every value-bearing collapse op. Single-run, this is a machinery race the
peers currently win; the architecture's structural win is the sweep/amortization
regime — an open benchmark target, the bet still to be settled.
