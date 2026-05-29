# RFC Seed: v0.1.8.7 Optimization Round — Single-Core R Hot Path

**Stage:** Seed (v1) — opens the cycle, invites an adversarial response. Not
binding; the synthesis binds.
**Author (seed):** Claude
**Response author:** Codex (pending)
**Date:** 2026-05-29
**Roadmap window:** v0.1.8.7 (the optimization round; see `ledgr_roadmap.md`).

**Goal:** Make a single ledgr backtest run as fast as possible **while staying in
R** — no ledgr-authored compiled core. Leaning on optimized R-package
dependencies (`collapse`, `TTR`) is in scope; writing C/Rcpp inside ledgr is not.

### RFC-cycle context (`rfc_cycle.md`)

- **Stage 1 (research input):** done and durable — the optimization-round spike
  cluster (`inst/design/spikes/ledgr_optimization_round_spike/`, five spike logs,
  the architecture synthesis) plus the LDG-2457 real-run profile. This seed cites
  it rather than re-deriving.
- **Stage 2 (this seed):** Claude.
- **Expected next:** Codex response (stage 3) → review (4) → seed v2 if warranted
  (5) → synthesis by the author who didn't write v2 (7) → final review (8) →
  horizon entry (9). Maintainer decisions (6) only if a product-level binary
  choice surfaces.
- **Pre-CRAN framing:** ledgr is pre-CRAN with no external users, so
  external-user-breakage cost is phantom and contracts may change. But the parity
  gates below are **internal-coherence / determinism** cost, which is *not*
  waived by pre-CRAN status — ledgr's USP is byte-reproducibility. "Break freely"
  applies to APIs, not to determinism.

**Context files:**
- `inst/design/spikes/ledgr_optimization_round_spike/architecture_synthesis.md`
- `dev/spikes/spike-event-buffer-rewrite.md` / `spike-event-buffer-factorial.md`
- `dev/spikes/spike-empty-fold-profile.md`
- `dev/spikes/spike-amdahl-floor.md`
- `dev/spikes/spike-reconstruction-collapse.md` / `spike-projection-collapse.md`
- `inst/design/spikes/ledgr_optimization_round_spike/codex_review_request_response.md`
- `inst/design/adr/0004-dependency-footprint-and-strategy-interface.md`
- `inst/design/collapse_optimization_map.md`
- `inst/design/audits/fold_path_hotpath_audit.md` (verified profile sites)

---

## Background

ledgr's execution loop is a left fold over EOD pulses (`R/fold-core.R`):
strategy → fill model → ledger events → state. Pre-v0.1.8 it was "abysmally
slow"; v0.1.8.x brought it to ~**2.74×** Backtrader (durable run) / ~3.33×
(one-candidate sweep) on a matched same-host 500×1,260 SMA crossover (LDG-2457).
Backtrader (~5,500 bars/s) and quantstrat (~3,120) beat ledgr (~1,900) on the
single run; both peers are **interpreted with no compiled core**, so the gap is
removable implementation waste, not a language or architecture chasm.

### What the measurements established

1. **ledgr is machinery-bound, not callback-bound.** The irreducible
   strategy-callback/user-logic floor is ~0.2% of the loop (spike 4). No *large
   measured* floor — the loop is almost entirely ledgr machinery. (Not "zero
   floor": strategy invocation, minimal context access, target validation,
   accounting transitions remain irreducible.)
2. **The cost is two localized, shape-dependent rocks:**
   - **High turnover → the event buffer/emission**, 72–82% of loop R time
     (real-run profile; `handler$buffer_event` in the durable run,
     `append_event_row_list` in the sweep — `R/backtest-runner.R`). The factorial
     (spike 1b) isolated it: **capacity/sizing carries the whole structural win
     (27–88×)**, storage topology is noise (~1×), `collapse::setv` is a
     turnover-scaling secondary (2.4–8×). O(fills²) is the *suspected* mechanism,
     pending a production re-profile.
   - **Low turnover → per-pulse boundary representation (timestamp/string
     formatting)** (spike 2b). `format.POSIXlt` is the **#1 self-time function at
     26.6% with zero trades**; formatting totals ~62% of the empty fold; the
     strategy/ctx callback is only ~13%; `%||%` ~10%. Context construction proper
     is **not** the rock.
3. **The villain is per-event machinery (over-allocation + boundary
   representation), not event-sourcing.** The architecture — events as source of
   truth, derived views, sealed/hash-verified snapshots — is sound and unchanged.
4. **Projection is not a perf lane** (spike 3): `features_wide` build + df→matrix
   is ~0.74s/run; `mctl` is *slower* than the base-R stamp. Matrix-canonical
   surface = contract decision, out of scope here.

---

## Goals and non-goals

**Goal:** minimize single-core, single-run wall in pure R, validated by a
real-run re-profile and byte-identical output parity.

**Non-goals (explicit):**
- **No ledgr compiled core.** C/Rcpp inside ledgr is out ("stay in R"). It is the
  future lever that would flip the single-run race; recorded as a future
  obligation, not this round.
- **No parallel/multicore** (single-core first).
- **Sweep/amortization** — separate track, evidence OPEN; not the single-core
  goal (see Future Obligations + Open Inputs).
- **Projection throughput** — contract decision.

---

## Proposed work — the lanes

Priority order. Each lane: mechanism, the measured spike, the expected wall
effect (Amdahl-bounded estimate — **the production re-profile is the verdict**;
isolated sims overestimate ~3×), and its parity gate.

### Lane B — Event buffer / emission (high-turnover rock)

**Mechanism.** Replace worst-case preallocation (`n_inst × n_pulses`) with
realistic sizing + grow-by-doubling; use `collapse::setv(col, i, v, vind1=TRUE)`
for the in-place per-event write (`R/backtest-runner.R` buffer path).

**Evidence.** Factorial (spike 1b): capacity fix **27–88×** (whole structural
win, base R, no dependency); `setv` a further **2.4–8×** growing with turnover;
topology negligible.

**Expected wall effect.** Buffer ≈137s of a ≈295s turnover wall → **~1.8× wall**
on turnover-heavy runs. Negligible on low-turnover runs.

**Parity gate.** Value-neutral → **byte-identical event-stream parity** only
(same rows/order/ids); no floating-point gate.

### Lane R — Representation / formatting (low-turnover rock, cross-cutting)

**Mechanism.**
1. **Carry trusted `POSIXct` end to end**; format to ISO only at validated
   ingress and durable-output boundaries. Removes per-row `format.POSIXlt`
   (`ledgr_normalize_ts_utc`, `R/pulse-context.R`) on the per-pulse
   equity/positions path *and* the per-fill payload (`ledgr_fill_event_payload`,
   `R/backtest-runner.R`).
2. **De-`sprintf`/`formatC` the per-row event/equity construction** (event-ids,
   number formatting): build once / vectorize, not per row.
3. **Audit the hot `%||%`** (~10% of the empty fold) on the per-pulse path.

**Evidence.** Empty-fold profile (spike 2b): `format.POSIXlt` 26.6% + `formatC`
14.7% + `sprintf` 12.5% + `paste`/`paste0` ~8% = **~62%** of the empty fold, with
zero trades. Same functions sit in the per-fill payload (audit finding #2) →
**cross-cutting** (owns the low-turnover wall *and* trims high-turnover emission).

**Expected wall effect.** Largest lever on low-turnover/wide-universe runs;
meaningful secondary on turnover runs. Magnitude pending re-profile.

**Parity gate.** **Byte-identical `ts_utc` parity** (daily/minute/second) with
explicit sub-second handling per the whole-second snapshot-seal contract — the
POSIXct-carry path must not preserve sub-second precision the current path
truncates. Event-id strings preserved exactly unless the contract is changed (an
open question). `meta_json` stays **per-row canonical**
(`vapply(meta_list, canonical_json, character(1))`, never a batched array).

### Lane C — Reconstruction / read-back (gated, value-bearing)

**Mechanism.** Replace per-row `data.frame()` + `do.call(rbind)` fills assembly
with `collapse::rowbind` (or preallocated columns); replace per-instrument
`which()`+`cumsum` loops with grouped `collapse::fcumsum(x, g)`
(`ledgr_equity_from_events` / `ledgr_fills_from_events` /
`ledgr_sweep_summary_from_ordered_events`, `R/fold-core.R`).

**Evidence.** Reconstruction spike (spike 2): fills assembly **58×** on the
read-back path (`ledgr_results(bt, "fills")`); cumsum kernel byte-identical but
minor (read-back, not run wall).

**Parity gate (value-bearing — full gate).** `ledgr_with_collapse_deterministic()`
+ real-ledgr fill-table fixtures (CASHFLOW-before-fill, opening positions, partial
close/open, close-before-open split rows, invalid/missing rows, DB- and
memory-backed event tables, exact column order/classes/`event_seq`). Synthetic
parity is not final parity.

### ctx-build proper — deprioritized

Spike 2b: the strategy/ctx callback is ~13% of the empty fold. Not a headline
lane. Revisit only if a line-level profile of a feature-bearing run promotes it.

---

## The determinism gate (cross-cutting)

For **value-bearing** collapse ops (Lane C; any future metrics use):
1. Pass collapse arguments **explicitly** (explicit beats the global).
2. Run inside **`ledgr_with_collapse_deterministic()`**, which **must pin
   `nthreads = 1L`** (Codex-confirmed: threaded reductions can reorder
   floating-point accumulation and break byte-identity even with `na.rm` pinned),
   plus `na.rm`/`sort`, with scoped `set_collapse` + on-exit/error-path restore.
3. Gate with a **byte-identical** event/equity/fills parity fixture **and** a
   hostile-`set_collapse` invariance test.

**Value-neutral** ops (Lane B `setv`) need only event-stream parity.

---

## Dependencies and strategy interface (ADR 0004)

- **Drop `cli`** (verified unused).
- **Drop `R6`** — consolidate to the function `(ctx, params) -> targets`
  interface; reimplement the four built-ins + `ledgr_strategy_fn_from_key` as
  functions; removes the original-vs-replay execution-path divergence.
- **Add `collapse`** (pure C, zero transitive deps) — gated on the wrapper above.
- **Keep `tibble`** (tidyverse signal).

Net Imports 9 → 8. `collapse`/`TTR` are R-package dependencies, consistent with
"stay in R."

---

## Sequencing and governance

1. **Bind the primitive-in-core rule and emitted-event parity gates first.**
2. **Lane B** — lands first **iff surface-preserving** (internal
   capacity/storage/write; same event rows). If it changes fill-model inputs,
   next-bar shape, context representation, or any strategy-visible surface, the
   primitive-contract work binds those choices first.
3. **Lane R** — the cross-cutting low-turnover rock.
4. **Lane C** — read-back, behind the full value-bearing gate.

**Per-lane discipline:** spike → implement in the real handler → **real-run
re-profile (the verdict)** → byte-identical parity gate → ship. Amdahl-bound all
projections; component multiples are not wall multiples.

---

## Expected outcome (calibrated, pending re-profile)

| step | turnover-run wall | vs today |
| --- | ---: | ---: |
| today | ~313s (≈2,010 b/s) | 2.74× Backtrader |
| + Lane B | ~165s | ~1.9× |
| + Lane R | ~130s | ~2.4× |
| + tail | ~115s (≈5,500 b/s) | ~2.7× |

Realistic single-core, pure-R ceiling: **roughly level with Backtrader** — a
machinery race we can win to a draw, not a rout. Decisively beating it single-run
needs the compiled core (future obligation). For a project that was "abysmally
slow" a month ago, level-with-Backtrader in pure R is the target.

---

## What the response stage should challenge

(Seed invites adversarial review — the highest-value disagreement targets.)

1. **The wall trajectory table.** It composes per-lane Amdahl estimates; the
   intermediate walls are not measured. Is the composition double-counting (Lane R
   trims emission that Lane B also touches)? Bound it.
2. **Lane R parity risk.** Carrying `POSIXct` end to end is the highest-blast
   change (touches every event/equity row). Is the daily/minute/second + sub-second
   fixture sufficient, or are there formatting sites (e.g. cache-key construction,
   provenance hashing) where the byte representation is load-bearing?
3. **Surface-preservation of Lane B.** Does the sizing/`setv` rewrite genuinely
   avoid touching any strategy-visible or replay surface, or does it interact with
   the snapshot/replay hash?
4. **Whether Lane R should precede Lane B.** Lane R is cross-cutting (helps both
   regimes); the profile says buffer dominates turnover but representation
   dominates low-turnover. Is B→R still right, or R→B?

---

## Open questions promoted to spec-cut (same window)

Decisions for the spec-cut writer, not RFC work:

1. **Buffer sizing policy:** initial capacity and growth factor for the
   doubling buffer.
2. **Event-id contract:** preserve the exact
   `paste0(run_id, "_", sprintf("%08d", event_seq))` string, or change the
   event-id contract as part of Lane R?
3. **`LedgrStrategy` mutation-guard (from ADR 0004):** drop it, or port a uniform
   function-based check (it is currently applied inconsistently — replay yes,
   direct run no)?
4. **Sub-second timestamp handling:** reject sub-second input at ingress, or
   truncate to whole-second, under the snapshot-seal contract?
5. **Representation-lane scope:** enumerate which `formatC`/`sprintf` sites are
   safe to vectorize/defer without changing output bytes.

## Future obligations recorded (separate RFC, later window)

1. **Compiled core (C/Rcpp).** The lever that would flip the single-run race vs
   Backtrader. Its own RFC at a later window; explicitly out of "stay in R."
2. **Sweep amortization track.** Its own measurement + RFC (the in-flight
   three-way is input). See Open Inputs.
3. **Matrix-canonical strategy surface.** Contract/ergonomics RFC (from the
   projection negative result), not a perf lane.
4. **Parallel/multicore sweep execution.** After single-core is exhausted.

## Open inputs (evidence pending — does not gate this seed)

- **Sweep amortization measurement (OPEN).** `ledgr_sweep` computes the feature
  union once and shares it across N candidates (`R/sweep.R`:
  `ledgr_precompute_unique_feature_defs`, `ledgr_sweep_feature_union`) but
  **re-runs the per-candidate fold** — so amortization wins in proportion to the
  feature-precompute fraction (small on cheap SMA, larger feature-heavy). A sweep
  three-way (`dev/bench/peer_sweep_three_way.R`, TTR C SMA for a fair precompute
  cost) is **in flight**; until it lands this seed makes **no claim** about a
  sweep crossover. It is a separate track from the single-core goal.
