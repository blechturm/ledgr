# Spike Log: Event-Buffer Write Rewrite (current vs base-R vs collapse)

**Date:** 2026-05-29 · **Host:** Intel Core i9-12900K, Windows 11 · R 4.5.2,
collapse 2.1.7 · **Status:** v0.1.8.7 optimization-round (Lane B) input.

**Script:** `dev/spikes/spike-event-buffer-rewrite.R`
(run with `--big` for the 630k row). Raw CSV (gitignored):
`dev/bench/results/spike_event_buffer_rewrite.csv`.

**Relates to:** `inst/design/audits/fold_path_hotpath_audit.md` (finding #1),
`inst/design/collapse_optimization_map.md`, ADR 0004.

## Question

The LDG-2456/2457 real-run profile put ~72-82% of fold-loop R time in the
per-event ledger buffer write (`handler$buffer_event`; sweep
`append_event_row_list`). How much does the proposed fix recover, and via which
lever — buffer *sizing* or the *write op*?

## Method

Faithful replica of the real handler: a factory builds a `state` env; a separate
closure mutates it per event (cross-frame, the condition that reproduces the
cost). 11 mixed-type columns like the real ledger buffer; a fixed `VALS` reused
so only the BUFFER WRITE is timed (not payload construction). Anchored: current
at (100800, 2099) reproduces the seconds-scale copy cost of the 200x504 Rprof.

Three variants:
- **current** — nested list-in-env, over-allocated to `max_events`, base-R write.
- **base_r** — flat env cols, grow-by-doubling (realistic size), base-R write.
- **collapse** — flat env cols, doubling, `collapse::setv(col, i, v, vind1=TRUE)`.

## Results

```
max_evt   fills      current     base_r   collapse | cur/baseR  cur/coll
100800    2099         5.17s      0.19s      0.08s |     27.2x     64.6x
315000    6784       113.53s      1.28s      0.17s |     88.7x    667.8x
630000    13000      429.22s      4.25s      0.33s |    101.0x   1300.7x
```

tracemem (3 writes to one column): **current copies** (3 copies), **base_r also
copies** (fills-sized), **collapse `setv` does NOT copy** (in place).

## Findings

Two stacking, independently-confirmed levers:

1. **Capacity/sizing (base R, no dependency).** **27-101x** (grows with scale).
   Codex flagged that the `base_r` variant bundled three changes; the factorial
   (`spike-event-buffer-factorial.md`) isolated them: **capacity (worst-case ->
   doubling) carries the whole win, 27-88x**; **storage topology (nested ->
   direct) is noise, ~1.0-1.2x**; the write op is a separate secondary lever
   (below). So it *is* the sizing — the over-allocation to `n_inst * n_pulses` is
   the villain, and no topology change is needed for the perf.
2. **Write op (`collapse::setv`, in place by reference).** **65-1300x** vs
   current; true O(fills). Its edge over base R *grows with turnover*
   (base_r/collapse: 2.4x -> 7.5x -> 12.9x at 2k -> 6.8k -> 13k fills).

**O(fills^2)** is the *suspected mechanism* (consistent with the per-write copy in
tracemem and the profile), to be **confirmed by re-profiling the production
handler** after the rewrite — not asserted from this isolated replica. Over-
allocation is one important part of the villain; the per-event payload stack
(timestamp round-trip, JSON, event-id formatting) is the other (see the audit).

## Wall translation (do not over-read the 1300x)

The 1300x is on the isolated buffer *write*. The buffer is ~half a turnover
run's wall (~137s of ~295s in the real profile), so Amdahl caps the *wall*
speedup at **~1.8-2x** -- roughly into quantstrat's territory, from ~2x behind.
The component fix is spectacular; the wall fix is "respectable."

It helps most exactly where ledgr looks worst: the cost scales with
`n_inst * n_pulses`, so it should lift the wide-universe numbers and flatten the
turnover-driven degradation seen in `dev/bench/peer_comparison.md`.

## Caveats

- The isolated replica **overestimates absolute cost ~3x** (current sim 429s vs
  real ~137s buffer self-time): it copies on every write; real refcounting
  copies somewhat less. Trust the **ratios and mechanism**, not the seconds.
- The **real-run re-profile after implementing in the handler is the verdict.**
- `setv` is value-neutral here, but Lane B also carries timestamp/meta changes;
  ship behind a byte-identical event-stream parity gate.

## Recommendation for the v0.1.8.7 RFC

Ship the **base-R structural fix regardless** (most of the win, zero dependency);
use **`setv`** for the actual buffer since collapse is adopted (ADR 0004) — it
completes the fix and pulls away on high-turnover workloads. Validate with this
spike's mechanism + a **production re-profile** (the verdict), behind an
event-stream parity gate. Lane B lands first only if surface-preserving;
otherwise the primitive-contract RFC binds the surface choices first.
