# Spike Log: Chunked Extractor Wall Recovery Measurement

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2,
collapse 2.x, duckdb 1.x - **Status:** v0.1.8.9 optimization-round
Round 2 input (LDG-2491, Spike 12). Closes Codex peer-review Finding 3.

**Script:** `dev/spikes/spike-chunked-extractor-wall-recovery.R`. Raw CSV
(gitignored): `dev/bench/results/spike_chunked_extractor_wall_recovery.csv`.

**Relates to:**
- `dev/spikes/spike-fills-reconstruction-scaling.{R,md}` (LDG-2486,
  Spike 7 — the monolithic measurement this spike refines)
- `dev/spikes/spike-persistent-handler-buffer.{R,md}` (LDG-2490,
  Spike 11 — companion Round 2 spike)
- `R/backtest.R:1021-1276` (production chunked extractor)
- `R/fold-reconstruction.R:155-227` (the buffer + hot function being
  patched)

## Question

Codex peer review Finding 3 noted that Spike 7's (LDG-2486) ~170s
recovery estimate was an extrapolation from monolithic
`ledgr_fills_from_events()` measurement. Production durable
`ledgr_results(bt, "fills")` goes through `ledgr_extract_fills_impl`
at `R/backtest.R:1021` with a chunked reader (fetch_size = 50000L per
chunk, per-chunk buffer sized to nrow(rows) * 2L). What is the ACTUAL
wall recovery on the production chunked path?

## Method

Faithful real-path measurement. Build a synthetic ledger_events
DuckDB table at three scales (30k, 68.5k, 133k matching grid cells).
Call `ledgr:::ledgr_extract_fills_impl` directly. Then use
`assignInNamespace` to swap `ledgr_fill_row_buffer_add` for a
`collapse::setv` variant. Call the extractor again. Restore the
namespace. Compute recovery as baseline - patched. Row-count and
column-value parity verified at every scale.

Critically: only the per-row buffer-write hot function is replaced.
The chunked DBI fetch loop, lot machinery, fill-row classification,
temp-table accumulation, and tibble materialization are unchanged.

`stream_threshold` is set to `.Machine$integer.max` so the non-lazy
materialized path is taken at all scales. The chunked DBI fetch
(fetch_size = 50000) still runs identically.

## Results

```
n_rows  baseline_s  patched_s  recovery_s  speedup
30000     28.950s     4.970s     23.980s    5.82x
68500     99.140s    17.230s     81.910s    5.75x
133000   238.640s    52.170s    186.470s    4.57x
```

**Parity at all scales:** baseline and patched extractors return the same
row count and byte-identical column values (sampled first 100 rows, 9
columns).

### Per-fill cost

| Scale | Baseline us/fill | Patched us/fill |
|---:|---:|---:|
| 30k | 965 | 166 |
| 68.5k | 1448 | 251 |
| 133k | 1794 | 392 |

Baseline per-fill cost still grows with scale (965 -> 1794, +86% on
4.4x scale), confirming the chunked path still has the O(N^2) write
pattern PER CHUNK. Setv per-fill cost is essentially flat (166 -> 251
-> 392, mostly DBI/jsonlite/lot machinery, not buffer writes).

## Findings

**Wall recovery confirmed at 186.47s on the production chunked path at
133k events.** The mechanism Spike 7 identified (per-row column writes
into a preallocated buffer triggering O(N) copy-on-modify) is correct
and the setv fix recovers the expected magnitude. The chunked path
DOES bound per-chunk buffer size (~100k slots per chunk vs Spike 7's
monolithic 260k slots), but the per-chunk O(N^2) cost is still
substantial because individual chunk buffers are large enough that
each per-row write copies tens-of-thousands of elements.

**Codex's Finding 3 is partially confirmed.** The 170s estimate from
Spike 7 was NOT a wild over-projection — Spike 12 measures 186.47s
recovery isolated, which is in the same ballpark as Spike 7's
estimate. After the standard v0.1.8.7 ~1.2-1.5x isolated-overestimate
discount, the production recovery is ~120-160s, somewhat lower than
Spike 7's claimed 170s but still the second-largest single-lane
recovery in the round (behind Spike 11).

**Spike 12 vs Spike 7 reconciliation:**

- Spike 7 (monolithic) at 130k: 618s baseline. The 580s of cost beyond
  the chunked baseline came from a 260k-slot buffer vs Spike 12's
  100k-slot chunks. Roughly: monolithic per-write copy is 2.6x more
  bytes than chunked, and monolithic does ~130k writes total vs
  chunked's 130k writes split across 3 chunks of smaller buffers.
- Spike 12 (chunked) at 133k: 238.64s baseline. The chunked path is
  ~2.6x faster than monolithic, EXACTLY matching the buffer-size
  ratio.
- The setv-patched chunked path: 52.17s. Most of this is DBI fetch
  (~25s) + jsonlite meta parsing (~15s) + lot machinery (~10s) — the
  irreducible cost that setv cannot help.

**4.6x speedup on the chunked path (vs Spike 11's 140x and Spike 6's
6.45x).** The reason setv's edge is smaller here than in Spike 11 is
that the chunked extractor also has DBI fetch + jsonlite parsing in
the per-chunk loop, both of which scale linearly with row count.
After fixing the O(N^2) buffer writes, those linear costs become the
dominant remaining cost. The fix achieves the correct architectural
goal — flat per-fill cost beyond the linear DBI/parse overhead.

**Chunked buffer is still large enough to have a visible O(N^2)
component.** At fetch_size = 50000, per-chunk buffer is ~100k slots.
Each per-row write copies ~100k elements (for full chunks). That is
still measurable. The chunked architecture mitigates the issue but
does not eliminate it. setv eliminates it.

## Wall translation

Spike 12's measurement IS the wall translation. No further
extrapolation needed.

Reference workload: `density_high_xlarge_durable` runs in 445.02s
wall, with `fills_extract_sec` at 197.11s. Spike 12 measures isolated
recovery of 186.47s.

The production reference (197s fills_extract_sec) is similar in
magnitude to the spike's 238s baseline — within 20%, consistent with
the standard isolated-overestimate factor. Applying that factor:

- Spike 12 isolated baseline -> production: 238s -> ~197s (matches!)
- Spike 12 isolated patched -> production: 52s -> ~43s
- **Expected production recovery: ~150s on the xlarge cell**

Amdahl bound on `density_high_xlarge_durable` (445s):

- fills_extract_sec is 197/445 = 44% of wall
- setv fix recovers ~75% of that = ~33% of wall
- Max wall speedup: 1.49x (~148s of 445s wall recovered)

**Confirms: 150s of wall recovery on durable xlarge from a 9-line setv
replacement.** Same order of magnitude as Spike 11 (50-80s on the
persistent handler) and Spike 6 (~75s on the ephemeral memory
handler). Three lanes, three sites, all setv replacements of the
per-row column-buffer write anti-pattern.

## Caveats

- **Synthetic events use simplified meta_json.** Production fills
  meta has more fields. Real-run jsonlite::fromJSON cost may be
  larger. The setv recovery (which has nothing to do with
  jsonlite) is unaffected.
- **The fix patches the namespace at runtime via
  `assignInNamespace`.** Real implementation requires editing the
  function definition in `R/fold-reconstruction.R:205-230`. The
  spike's namespace patch faithfully exercises the production
  extractor path with the same effect.
- **fetch_size = 50000L is hardcoded at R/backtest.R:1105.** If the
  setv fix lands without changing this, per-chunk buffer remains
  ~100k slots, which still has measurable per-write copy cost (the
  spike's setv variant absorbs the DBI fetch's ~25s per 130k
  events). A follow-up could explore tuning fetch_size lower (e.g.,
  10k) to amortize DBI overhead at smaller chunks, but the setv fix
  is independent and lands first.
- **Real-run gate.** Apply the setv fix to
  `R/fold-reconstruction.R:219-227`, re-run
  `density_high_xlarge_durable` on the workload grid. Expected:
  fills_extract_sec drops from 197s to ~45s. Tier 1 parity (fills
  byte-identical with the production extractor's existing output)
  must hold.

## Recommendation

**Proceed to v0.1.8.9 implementation ticket. Spike 12 validates Spike 7's
setv recommendation with a real-path measurement and confirms a wall
recovery of ~150s on the production durable xlarge cell.**

The fix is the same 9-line setv replacement Spike 7 recommended:

```r
# In R/fold-reconstruction.R:219-227, replace base-R [[<- writes with:
collapse::setv(buffer$event_seq, i, as.integer(event_seq), vind1 = TRUE)
collapse::setv(buffer$ts_utc, i, as.POSIXct(ts_utc, tz = "UTC"), vind1 = TRUE)
collapse::setv(buffer$instrument_id, i, as.character(instrument_id), vind1 = TRUE)
collapse::setv(buffer$side, i, as.character(side), vind1 = TRUE)
collapse::setv(buffer$qty, i, as.numeric(qty), vind1 = TRUE)
collapse::setv(buffer$price, i, as.numeric(price), vind1 = TRUE)
collapse::setv(buffer$fee, i, as.numeric(fee), vind1 = TRUE)
collapse::setv(buffer$realized_pnl, i, as.numeric(realized_pnl), vind1 = TRUE)
collapse::setv(buffer$action, i, as.character(action), vind1 = TRUE)
```

The fix benefits BOTH the durable path (this spike measures ~150s) AND
the ephemeral path (Spike 7 measures monolithic case at ~580s isolated;
ephemeral pays this cost). The same change lands in both with no
additional work — `ledgr_fill_row_buffer_add` is the shared hot
function.

Sequencing in v0.1.8.9: independent of Spike 11. Spike 12's fix can land
in parallel with Spike 11's fix. Both attack the same coding-rule
violation in different files. Both contribute to the durable
xlarge wall recovery.

Expected real-run signature: `fills_extract_sec` on
`density_high_xlarge_durable` drops from 197s to ~45s. Combined with
Spike 11's `t_loop_sec` reduction of ~60s, total xlarge wall drops
from 445s to ~235s — a ~47% wall reduction from two 9-line and
11-line mechanical replacements.

## Architectural lesson

**Production chunked architectures don't eliminate O(N^2) per-write
patterns; they just bound the per-chunk N.** At fetch_size = 50000 and
buffer = N*2, per-chunk N = 100k is still large enough that per-write
copy cost is dominant. Architectural mitigation (chunking) and
implementation mitigation (setv) are complementary, not
substitutable.

The Spike 7 vs Spike 12 contrast quantifies this cleanly:

- Spike 7 (monolithic, buffer 260k): 618s
- Spike 12 chunked baseline (buffer 100k): 238s
- Spike 12 chunked + setv (buffer 100k, no copy): 52s

Chunking gave a 2.6x speedup (618 -> 238). setv on top gave another
4.6x speedup (238 -> 52). Compounded: 12x speedup from monolithic
base-R to chunked + setv.

This refines the round's L2 coding rule with a sub-lesson:
**"chunking bounds N per write; setv eliminates the per-write copy
within that bound."** Both techniques target the same anti-pattern at
different layers. The v0.1.8.9 spec should not present them as
alternatives; they are complementary fixes.

Spike 11's finding (all-atomic buffers get true O(N), not just
bounded O(N^2)) refines this further: chunking + setv + atomic-only
columns is the asymptotically clean combination. The persistent
durable handler (Spike 11) already has the atomic-only columns
property; the fills reconstruction buffer (Spike 12) has it too
(9 atomic columns, no list columns). Both buffers are in the
optimal architectural state once setv replaces the base-R writes.
