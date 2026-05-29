# RFC Seed v2: v0.1.8.7 Optimization Round — Single-Core R Hot Path

**Stage:** Seed v2 — revised after the Codex response (stage 5). Incorporates the
response findings; does not reopen the optimization-round architecture. Not
binding; the synthesis binds.
**Author (seed v1, v2):** Claude
**Response author:** Codex (`rfc_optimization_round_v0_1_8_7_response.md`)
**Synthesis author:** Codex (per role rotation — the author who did not write v2)
**Date:** 2026-05-29
**Roadmap window:** v0.1.8.7.

**Goal:** Make a single ledgr backtest run as fast as possible **while staying in
R** — no ledgr-authored compiled core, no parallel dispatch. Optimized R-package
dependencies (`collapse`, `TTR`) are in scope; C/Rcpp inside ledgr is not.

### RFC-cycle context (`rfc_cycle.md`)

- **Stage 1 (research input):** the optimization-round spike cluster
  (`inst/design/spikes/ledgr_optimization_round_spike/`) + the LDG-2457 real-run
  profile (`inst/design/audits/fold_path_hotpath_audit.md`). Durable; cited.
- **Stages 2–3–4:** seed v1 (Claude) → response (Codex) → this v2 (Claude).
- **Expected next:** synthesis (Codex) → final review → horizon entry. **No
  maintainer decision is pending** — the one escalated item (sub-second timestamp
  policy) was resolved by the maintainer on 2026-05-29: **whole-second is the
  contract; sub-second is out of scope (ledgr is not an HFT engine).** Everything
  is now bound or spec-cut, so v2 can go to synthesis.
- **Pre-CRAN framing:** no external users, so API-breakage cost is phantom and
  contracts may change freely. But **determinism / byte-reproducibility is
  internal-coherence cost and is NOT waived** — it is ledgr's USP. "Break freely"
  applies to APIs, not to durable identity or reproducible outputs.

**Context files:** as seed v1, plus
`rfc_optimization_round_v0_1_8_7_response.md` (the response this v2 answers).

---

## Background

ledgr's loop is a left fold over EOD pulses (`R/fold-core.R`): strategy → fill
model → ledger events → state. v0.1.8.x brought it to ~**2.74×** Backtrader
(durable) / ~3.33× (one-candidate sweep) on a matched same-host 500×1,260 SMA
crossover (LDG-2457). Both peers are interpreted, no compiled core → the gap is
removable implementation waste.

### What the measurements established (with verified citations from the response)

1. **Machinery-bound, not callback-bound.** Irreducible user-decision floor
   ~0.2% of the loop (spike 4). No *large measured* floor; not "zero floor."
2. **Two localized, shape-dependent rocks:**
   - **High turnover → event buffer/emission**, 72–82% of loop R time
     (real-run profile). The fold computes worst-case capacity
     `length(pulses_posix) * length(instrument_ids)` (`R/fold-core.R:72-73`); the
     durable handler allocates one full column per field
     (`R/backtest-runner.R:365-379`) and writes fields one-by-one
     (`R/backtest-runner.R:385-408`, assignments `:397-407`) via
     `buffer_event(write_res)` (`R/backtest-runner.R:441-442`); the sweep memory
     handler has the same append shape (`R/sweep.R:750-770`, `:868-879`,
     `:882-890`). The factorial (spike 1b) isolated it: **capacity/sizing is the
     whole structural win (27–88×)**, storage topology is noise (~1×),
     `collapse::setv` a turnover-scaling secondary (2.4–8×). **O(fills²) is the
     suspected mechanism — priority is production-profile evidence; the exact
     mechanism is confirmed only by a production re-profile after the rewrite.**
   - **Low turnover → a per-pulse representation/formatting bucket** (spike 2b).
     `format.POSIXlt` is the **#1 self-time function at 26.6% with zero trades**;
     formatting totals ~62% of the empty fold; the strategy/ctx callback is only
     ~13%; `%||%` ~10%. **This is a low-turnover representation/formatting bucket;
     the profiler did not map those samples to a specific equity-frame
     constructor** — and in fact the final equity frame stores `pulses_posix`
     directly (`R/backtest-runner.R:1476-1485`), so v2 does **not** attribute the
     bucket to equity-row construction. Context construction proper is **not** the
     rock.
3. **The villain is per-event machinery (over-allocation + boundary
   representation), not event-sourcing.** The architecture is sound and unchanged.
4. **Projection is not a perf lane** (spike 3); `mctl` slower than the base-R
   stamp. Out of scope.

---

## Goals and non-goals

**Goal:** minimize single-core, single-run wall in pure R, validated by a
real-run re-profile and byte-identical output parity.

**Non-goals:** no ledgr compiled core; no parallel/multicore; sweep/amortization
is a separate track with **open** evidence (no crossover claim); projection
throughput is a contract decision.

---

## The lanes

Priority order. Each: mechanism + verified sites, expected effect (**bounded;
production re-profile is the verdict; isolated sims overestimate ~3×**), parity
gate.

### Lane B — Event buffer / emission (high-turnover rock)

**Mechanism (B0, surface-preserving).** Replace worst-case preallocation with
realistic sizing + grow-by-doubling; use `collapse::setv(col, i, v, vind1=TRUE)`
for the in-place write; flush emits the **same rows**.

**Surface-preservation condition — when B0 may land first.** B0 is limited to:
capacity policy, internal column storage, the write op (`[[<-` vs `setv`), and a
flush that emits identical rows. Under that scope it does **not** touch the
snapshot hash, run-config hash, or strategy-visible context — it affects
`ledger_events` only through the values buffered, so **event-stream parity is the
correct gate** and B0 lands first. **If a change touches fill-model inputs,
next-bar shape, payload construction, or strategy-visible context, it is no
longer B0** — it is the deeper typed-emission rewrite (B1) and must wait for the
primitive-contract binding (see Sequencing).

**Evidence.** Factorial (spike 1b): capacity fix **27–88×** (base R, no
dependency); `setv` a further **2.4–8×** growing with turnover; topology
negligible.

**Expected wall effect (bounded).** Lane B is bounded by two profile numbers:
`handler$buffer_event` self ≈137s and `output_handler$write_fill_events` total
≈149s. On the 313s durable run, removing 137s → ~176s; removing 149s → ~164s. So
**~1.7×–1.9× wall on turnover-heavy runs** — the upper end assumes B0 removes
nearly all write-fill-event work, not just the buffer assignments. Negligible on
low-turnover runs.

**Parity gate (value-neutral → event-stream parity).** Exact event row order and
`event_seq`; **exact `event_id` strings** (bound — see decisions); exact `ts_utc`
values **and classes** after the DB round trip; exact `meta_json`; **both** the
durable (`R/backtest-runner.R`) and memory-sweep (`R/sweep.R`) append paths; and
an explicit check that `collapse::setv` preserves POSIXct **class and `tzone`**,
not merely the numeric seconds.

### Lane R — Representation / formatting (low-turnover rock, cross-cutting)

**Mechanism.**
1. **Carry trusted `POSIXct` end to end on the hot path**, formatting to ISO only
   at validated ingress / durable-output boundaries. The current per-fill round
   trip normalizes `ts_exec_utc` and parses it back
   (`R/backtest-runner.R:176-177`); `ledgr_normalize_ts_utc()` formats via
   `format(..., "%Y-%m-%dT%H:%M:%SZ")` (`R/pulse-context.R:619-625`) and
   reparses character inputs (`:642-647`); fast contexts already carry a
   precomputed `ts_iso` into `ctx$ts_utc` (`R/fold-core.R:132-157`) while the
   slower constructor/validation still normalize (`R/pulse-context.R:1-29`,
   `:650-677`).
2. **De-`sprintf`/`formatC` the per-row event construction** (event-id
   `R/backtest-runner.R:190`, per-fill metadata `:188`): build once / vectorize,
   not per row.
3. **Audit the hot `%||%`** (~10% of the empty fold) on the per-pulse path.

**Identity boundary — Lane R is FENCED away from durable identity formatting.**
Lane R may remove **per-pulse / per-fill hot-path** formatting only. It must
**not** change the byte representation of any durable or session identity path:
- `canonical_json()` POSIXt formatting (`R/config-canonical-json.R:61-63`) — feeds
  config/provenance hashes;
- `ledgr_feature_cache_key_from_parts()` (`R/feature-cache.R:101-119`) — the
  session-local cache-key identity;
- `ledgr_snapshot_hash()` (`R/snapshots-hash.R:26-29`, `:66-69`);
- `ledgr_run_data_subset_hash()` (`R/data-hash.R:122-149`);
- any feature-def fingerprint / strategy/config hash.

**Default: non-scope** — Lane R does not touch these. **If a Lane R change is
found to touch any of them, it is blocked** until the relevant hash/fingerprint
**pin is updated through an explicit accepted contract change** (a separate RFC),
not silently. "Carry POSIXct end to end" is a hot-path statement, not a license
to alter durable identity bytes.

**Timestamp parity.** Lane R must preserve current **whole-second** observable
behavior. Fixture covers, for daily / minute / second / sub-second inputs:
- durable `ledger_events.ts_utc`;
- memory-event `ts_utc`;
- `equity_curve.ts_utc`;
- replay / reopen reconstruction from persisted events;
- byte-identical `ts_utc` strings and POSIXct class/`tzone`.

**Sub-second handling is bound (maintainer decision, 2026-05-29): whole-second is
the contract; sub-second is out of scope.** ledgr is not an HFT engine and
sub-second resolution is a deliberate non-goal. Within the fold all timestamps are
whole-second, so Lane R carries `POSIXct` with no sub-second concern. The only
residual is a **spec-cut** detail — whether the snapshot seal **rejects**
sub-second input (error) or **truncates** it to whole-second; both honor the
contract, **reject preferred** (don't silently accept data ledgr won't faithfully
represent), but it is an implementation choice, not a product escalation.

**Expected wall effect (regime-dependent).** On the **turnover** run the directly
named formatting/payload bucket is small — the audit records
`ledgr_fill_event_payload` ≈11s total and `format.POSIXlt` ≈8s self — so the
turnover increment is **~1.05×–1.15×**, *not* a further large subtraction. On
**low-turnover / wide-universe** runs the effect is **likely large** (the empty
fold is ~62% formatting). Magnitude confirmed by re-profile.

### Lane C — Reconstruction / read-back (gated, value-bearing)

**Mechanism.** Replace per-row `data.frame()` + `do.call(rbind)` fills assembly
with `collapse::rowbind` (or preallocated columns); replace per-instrument
`which()`+`cumsum` loops with grouped `collapse::fcumsum(x, g)`. Verified sites:
`ledgr_equity_from_events()` per-instrument `which()` (`R/fold-core.R:500-513`);
sweep-summary same (`:841-855`); `ledgr_fills_from_events()` row-subset
(`:574-581`), per-row data.frames (`:605-616`, `:623-634`, `:655-666`,
`:670-681`), `do.call(rbind, rows)` (`:688`).

**Evidence.** Reconstruction spike: fills assembly **58×** on the read-back path
(`ledgr_results(bt, "fills")`); cumsum kernel byte-identical but minor (read-back,
not run wall).

**Parity gate (value-bearing — full gate).** `ledgr_with_collapse_deterministic()`
(below) + real-ledgr fill-table fixtures (CASHFLOW-before-fill, opening positions,
partial close/open, close-before-open split rows, invalid/missing rows, DB- and
memory-backed event tables, exact column order/classes/`event_seq`). `rowbind`
parity is **row/order/class parity, not just numeric floating-point parity**.
Synthetic parity is not final parity.

### ctx-build proper — deprioritized

Spike 2b: the strategy/ctx callback is ~13% of the empty fold. **Not** a headline
lane (and v2 does not relabel the low-turnover rock as "ctx-build" — it is
representation/formatting). Revisit only if a feature-bearing line-level profile
promotes it.

---

## The determinism gate (cross-cutting)

For **value-bearing** collapse ops (Lane C; any future metrics use):
1. Pass collapse arguments **explicitly** (explicit beats the global).
2. Run inside **`ledgr_with_collapse_deterministic()`**, which sets a **full known
   `set_collapse()` state** with on-exit/error-path restore: at minimum
   **`nthreads = 1L`, `na.rm = FALSE`, `sort = TRUE`, `stable.algo = TRUE`**
   (`set_collapse()` on this host also exposes `remove`, `digits`, `stub`,
   `verbose`, `mask` — pin the full state or document each as irrelevant to the
   used ops). `nthreads = 1L` and `stable.algo = TRUE` are required because
   threaded / unstable reductions can reorder floating-point accumulation and
   break byte-identity even with `na.rm` pinned.
3. Gate with a **byte-identical** event/equity/fills parity fixture **and** a
   hostile-`set_collapse` invariance test that mutates **`nthreads`, `na.rm`,
   `sort`, and `stable.algo`** (not only `na.rm`).

**Value-neutral** ops (Lane B `setv`) need only event-stream parity (incl. the
POSIXct class/`tzone` check above).

---

## Dependencies and strategy interface (ADR 0004)

Drop `cli` (unused); drop `R6` (consolidate to the function `(ctx, params) ->
targets` interface; reimplement the four built-ins + `ledgr_strategy_fn_from_key`
as functions; removes the original-vs-replay execution-path divergence); add
`collapse` (gated on the wrapper above); keep `tibble`. Net Imports 9 → 8.
`collapse`/`TTR` are R-package deps, consistent with "stay in R."

---

## Sequencing and governance

1. **Bind the primitive-in-core rule and emitted-event parity gates first.**
2. **B0** — capacity/`setv` buffer rewrite, **if surface-preserving** (as scoped
   above), lands first behind event-stream parity.
3. **R** — timestamp/formatting cleanup, next or in the same implementation arc
   but **measured separately** (so its turnover vs low-turnover contribution is
   not conflated with Lane B).
4. **B1** — any deeper typed event-emission rewrite that changes payload / fill
   inputs / strategy-visible context **waits for the primitive-contract binding.**
5. **C** — reconstruction read-back, behind the full value-bearing gate.

**Per-lane discipline:** spike → implement in the real handler → **real-run
re-profile (the verdict)** → byte-identical parity gate → ship. Amdahl-bound all
projections; component multiples are not wall multiples; measure B and R
separately.

---

## Expected outcome (bounded ranges; not a point estimate)

| lane | regime | bounded effect | basis |
| --- | --- | --- | --- |
| B0 | turnover | **~1.7×–1.9× wall** | remove buffer self (~137s→~176s) … up to nearly all write-fill (~149s→~164s) |
| R | turnover | **~1.05×–1.15×** | named turnover formatting/payload ≈11s/≈8s; small unless re-profile attributes more post-B0 |
| R | low-turnover / wide | **likely large** | empty fold ~62% formatting |
| C | read-back only | n/a to run wall | 58× on `ledgr_results(…, "fills")` |

**Do not multiply B and R naively** — a typed-emission B1 could subsume payload
work R also claims; B0 + R are bounded *separately* and re-profiled *separately*.
Composing the turnover bounds gives roughly **~1.8×–2.2× turnover wall** (≈140–185s).

**"Backtrader-level" (≈2.7× / ≈115s) is a target/possibility, not an expected
result.** It would require the low-turnover representation gains plus the tail to
land at the optimistic end; the turnover-run evidence alone does not predict it.
Decisively beating Backtrader single-run needs the compiled core (future
obligation, out of scope). The honest target: **in reach of / level with
Backtrader on a single core in pure R.**

---

## Open questions promoted to spec-cut (same window)

1. **Buffer sizing policy:** initial capacity and growth factor for the doubling
   buffer.
2. **`LedgrStrategy` mutation guard (ADR 0004):** drop, or port a uniform
   function-based check (currently inconsistent — replay yes, direct run no)?
3. **Representation-lane enumeration:** the concrete `formatC`/`sprintf` sites
   safe to vectorize/defer without changing output bytes.
4. **Whole-second enforcement at the seal:** reject sub-second input (preferred)
   vs truncate to whole-second — both honor the bound whole-second contract; the
   choice is implementation, not product.

## Bound decisions (this round)

- **Event-id contract: preserve the exact strings.** v0.1.8.7 is an optimization
  round; the `paste0(run_id, "_", sprintf("%08d", event_seq))` event-id
  (`R/backtest-runner.R:190`) is **preserved byte-for-byte**. Changing the
  event-id contract is a separate explicit decision, not part of this round.

## Maintainer decisions (resolved 2026-05-29)

- **Sub-second timestamp policy → RESOLVED.** Whole-second is the contract;
  sub-second is **out of scope** — ledgr is not an HFT engine and sub-second
  resolution is a deliberate non-goal. No pending escalation; v2 is
  synthesis-ready. The seal-level enforcement (reject vs truncate) is demoted to a
  spec-cut detail (reject preferred).

## Future obligations (separate RFC, later window)

Compiled core (the lever that would flip the single-run race); sweep amortization
track (separate; the in-flight measurement is open input); matrix-canonical
strategy surface (contract/ergonomics, not speed); parallel/multicore sweep.

## Open inputs (evidence pending — does not gate this seed)

- **Sweep amortization (OPEN; no crossover claim).** `ledgr_sweep` fetches/
  normalizes bars once (`R/sweep.R:94-111`), builds one runtime projection from
  the unique candidate feature defs when `precomputed_features` is absent
  (`R/sweep.R:115-126`), shares it across candidates (`:189-205`, installed at
  `:634-654`, fold rerun at `:662`), and computes the feature union metadata
  (`R/sweep.R:243`, `ledgr_sweep_feature_union()` at `:1067-1073`). So it
  amortizes **feature precompute/projection, not the per-candidate fold.**
  **Measured (`dev/bench/peer_sweep_three_way.R` + `peer_sweep_verify.R`, TTR C
  SMA, 40-feature heavy, N=10):** internal sweep ~1.18× vs true naive (124.8s vs
  147.3s); explicit `ledgr_precompute_features()` adds **no** benefit over the
  internal union path (123.9s + a separate 9.9s precompute step → worse total);
  the amortized precompute saves only ~2.25s of ~14.7s per candidate — the
  per-candidate fold dominates. **This is modest amortization, far below the
  ~2.7× single-run gap, so a crossover vs peers looks unlikely on these
  workloads; heavier-precompute workloads are untested.** Still open input — **no
  crossover claim is bound either way.** Separate track from the single-core goal.

---

## Changes from v1 (for the synthesis to verify)

1. **Wall trajectory** — replaced the point-estimate table with **bounded
   ranges** (B0 ~1.7×–1.9×; R turnover ~1.05×–1.15×; R low-turnover large);
   added the explicit **no-double-count** note (B1 may subsume payload R claims);
   reframed **"Backtrader-level" as a target/possibility, not expected.**
2. **Lane R identity boundary** — added an explicit **fence** away from
   `canonical_json` / snapshot / data-subset / config-provenance / feature
   fingerprint hashes (with verified citations), defaulting to non-scope, with a
   **hash-pin contract-change gate** if touched.
3. **Lane R timestamp parity** — expanded the fixture to durable + memory events,
   equity rows, replay/reopen, daily/minute/second/sub-second; **bound current
   whole-second observable behavior**. The sub-second policy was escalated and
   then **resolved by the maintainer (2026-05-29): whole-second contract,
   sub-second out of scope / not HFT**; reject-vs-truncate-at-seal demoted to a
   spec-cut detail. (Post-v2 patch: sweep open-input updated with the landed
   ~1.18× amortization measurement.)
4. **Lane B surface preservation** — stated the exact B0 scope (capacity/storage/
   write-op/flush-same-rows) for landing first, and split out **B1** (payload/
   fill-input changes wait for primitive-contract binding); expanded the
   event-stream parity gate (incl. POSIXct class/`tzone` under `setv`, both
   durable and memory paths).
5. **Collapse determinism** — strengthened the wrapper to a **full known
   `set_collapse()` state** (`nthreads=1L`, `na.rm=FALSE`, `sort=TRUE`,
   `stable.algo=TRUE`); hostile fixture now mutates all four; `rowbind` parity is
   row/order/class, not just numeric.
6. **Open questions vs decisions** — kept buffer sizing / mutation guard /
   representation-site enumeration as spec-cut; **bound event-id preservation**;
   **escalated sub-second policy**; future obligations unchanged.
7. **Code-anchor accuracy** — folded in Codex's verified line citations
   throughout; **dropped the equity-row attribution** for the empty-fold
   formatting evidence (the final equity frame stores `pulses_posix` directly,
   `R/backtest-runner.R:1476-1485`) in favor of the "low-turnover
   representation/formatting bucket" framing; removed the stale "ctx-build" label.
