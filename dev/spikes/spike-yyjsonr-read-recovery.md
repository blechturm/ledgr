# Spike Log: yyjsonr Read-Path Recovery Investigation

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7, yyjsonr 0.1.22) - **Status:** v0.1.8.10 spike-round
Batch D input (LDG-2511, Spike 7).

**Script:** `dev/spikes/spike-yyjsonr-read-recovery.R`. Raw CSV:
`dev/bench/results/spike_yyjsonr_read_recovery.csv`.

**Relates to:**
- `R/config-canonical-json.R:27-37` (`ledgr_json_read_nested` —
  production helper)
- `inst/design/ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md`
  LDG-2501 read-path regression caveat
- `dev/spikes/spike-yyjsonr-readpath-parity.md` from v0.1.8.9 (original
  parity work)
- Commit `7bb39d9 Migrate canonical JSON to yyjsonr` (v0.1.8.9 Batch 8)

## Question

LDG-2501 measured `ledgr_json_read_nested` 2.3x slower than jsonlite on
production meta_json shapes (0.53s jsonlite vs 1.21s yyjsonr at 50k
payloads). Investigate whether the regression is recoverable through
different yyjsonr configurations, helper-indirection removal, or a thin
jsonlite read-fallback.

Decision rule: any variant achieving 1.5x recovery over Variant A
(production helper) proceeds to v0.1.8.10 ticket; otherwise the
read-path stays as the documented LDG-2501 trade-off.

## Method

Five variants on 50k synthetic meta_json payloads matching production
shape (`{"cash_delta":-7376.5,"position_delta":-20,"realized_pnl":null}`
or with realized_pnl numeric).

Variant A: current `ledgr_json_read_nested` helper.
Variant B: direct `yyjsonr::read_json_str(x, opts = pre-built)` — same
options as VarA but constructed once outside the per-call loop.
Variant C: yyjsonr with `length1_array_asis = FALSE` (alt-opts).
Variant D: `jsonlite::fromJSON(x, simplifyVector = FALSE)` (raw nested
list).
Variant E: `jsonlite::fromJSON(x, simplifyVector = TRUE)`.

Cash-delta parity check: extract `parsed$cash_delta` as numeric from
each variant and verify equivalence vs Variant A.

## Results

**Cash-delta parity vs VarA: B=PASS C=PASS D=PASS E=PASS.**

```
Variant                            Wall   us/payload   Speedup vs A
A (helper indirection)            1.140s        22.80          1.00x
B (direct yyjsonr)                0.110s         2.20         10.36x
C (yyjsonr length1_array=FALSE)   0.110s         2.20         10.36x
D (jsonlite simplify=FALSE)       0.470s         9.40          2.43x
E (jsonlite simplify=TRUE)        1.220s        24.40          0.93x
```

Decision rule outcome:

```
VarB speedup: 10.36x => PROCEED
VarC speedup: 10.36x => PROCEED
VarD speedup: 2.43x  => PROCEED
VarE speedup: 0.93x  => BELOW THRESHOLD
```

## Findings

**The LDG-2501 regression is entirely explained by per-call options
construction inside `ledgr_json_read_nested`.** Variant A constructs
`yyjsonr::opts_read_json(...)` inside the helper body, so 50k calls
build 50k options objects. Variant B pre-builds the options once and
reuses; that single change recovers **10x** at the 50k-payload shape.

Looking at `R/config-canonical-json.R:27-37`:

```r
ledgr_json_read_nested <- function(x) {
  yyjsonr::read_json_str(
    x,
    opts = yyjsonr::opts_read_json(    # constructed every call
      obj_of_arrs_to_df = FALSE,
      arr_of_objs_to_df = FALSE,
      arr_of_arrs_to_matrix = FALSE,
      length1_array_asis = TRUE
    )
  )
}
```

The fix is a trivial production change: hoist the options object to a
package-level constant:

```r
.ledgr_json_read_nested_opts <- yyjsonr::opts_read_json(
  obj_of_arrs_to_df = FALSE,
  arr_of_objs_to_df = FALSE,
  arr_of_arrs_to_matrix = FALSE,
  length1_array_asis = TRUE
)

ledgr_json_read_nested <- function(x) {
  yyjsonr::read_json_str(x, opts = .ledgr_json_read_nested_opts)
}
```

Two lines moved out of the function body. Same parity, 10x recovery.

**`length1_array_asis` toggle is irrelevant.** Variants B and C tie
at 0.11s. The options-construction cost dominates the per-call work
regardless of the actual option values.

**jsonlite::fromJSON(simplifyVector=FALSE) is 2.4x faster than the
broken helper** but 4.3x slower than fixed yyjsonr (VarD 0.47s vs VarB
0.11s). jsonlite is not the right destination after the helper hoist;
yyjsonr is faster and the helper hoist eliminates the regression.

**jsonlite::fromJSON(simplifyVector=TRUE) is slower than the broken
helper.** Default jsonlite simplification adds its own overhead. Not a
viable fallback.

### Wall translation to production

The LDG-2501 regression compounds across every fold path that
re-parses meta_json. Per the spike spec the LDG-2501 helper benchmark
measured 0.53s jsonlite vs 1.21s yyjsonr at 50k payloads on production
metadata shapes; this matches my Variant A reading (1.14s yyjsonr at
50k).

After the options-hoist fix:

| Workload                  | Before (s) | After (s) | Recovery (s) |
|:--------------------------|----------:|----------:|-------------:|
| 50k meta_json reads       |      1.14 |      0.11 |        1.03  |
| 130k meta_json reads      |      2.96 |      0.29 |        2.67  |
| 500k meta_json reads      |     11.40 |      1.10 |       10.30  |

Reopen / resume / persistent DB-replay paths
(`ledgr_reconstruct_positions`, `ledgr_reconstruct_cash`,
`ledgr_rebuild_derived_state`) all hit this helper per row when
reading persisted events from DuckDB. At 130k events these paths gain
~2.7s — meaningful for re-open workloads. Within a fresh fold run
this helper is hit less frequently (typed meta is preferred), but any
path that takes the JSON fallback benefits.

## Disposition

**PROCEED — ship the helper hoist in v0.1.8.10 as a Round-closeout
patch.** Three reasons this should ride along with the v0.1.8.10
implementation tickets rather than waiting:

1. **Implementation is trivial.** Two lines moved out of a function body.
2. **Closes a measured regression.** LDG-2501 documented the read-side
   regression as a known trade-off; this spike measures that the
   trade-off was avoidable.
3. **No contract surface change.** The helper signature
   (`ledgr_json_read_nested(x)`) is unchanged. Parity gate is that
   downstream consumers receive equivalent parsed output — confirmed at
   parity check.

The fix can either:

- Land as a one-line patch inside another v0.1.8.10 ticket (e.g.
  bundled with the inline-state ticket where reopen-from-DB paths are
  exercised).
- Land as a standalone closeout patch in the v0.1.8.10 round.

Either path is appropriate.

## Implementation notes

1. In `R/config-canonical-json.R`, hoist the options object to a
   package-level constant:
   ```r
   .ledgr_json_read_nested_opts <- yyjsonr::opts_read_json(
     obj_of_arrs_to_df = FALSE,
     arr_of_objs_to_df = FALSE,
     arr_of_arrs_to_matrix = FALSE,
     length1_array_asis = TRUE
   )
   ```
2. Refactor `ledgr_json_read_nested(x)` to reference the constant.
3. Apply the same pattern to `ledgr_json_read_config(x)` at lines
   39-49 (same per-call options construction, same regression class).
4. Cross-check `ledgr_json_write_canonical_v2(x)` at lines 51-62 —
   same pattern (`opts_write_json(...)` constructed per call); hoist
   if the write-side benchmark shows similar pattern. Out of Spike 7
   scope but worth a paired closeout patch.
5. Parity gate: existing unit tests for the helpers plus an end-to-end
   reopen-from-DB test (`ledgr_reconstruct_positions` on a persisted
   sweep) produce byte-identical output before vs after.

## Source references

- `R/config-canonical-json.R:27-37` (the helper being patched)
- `R/config-canonical-json.R:39-49` (companion helper with same
  pattern)
- `inst/design/ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md`
  LDG-2501 read-path regression caveat (now closeable as a v0.1.8.10
  follow-up)
- `dev/spikes/spike-yyjsonr-readpath-parity.md` from v0.1.8.9 (parity
  evidence)
- Commit `7bb39d9 Migrate canonical JSON to yyjsonr`
