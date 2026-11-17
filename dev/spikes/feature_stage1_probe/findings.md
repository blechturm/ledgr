# Feature engine stage 1: measuring step findings

Input to the stage-1 cut (rfc_feature_engine_v0_2_3_seed_v2.md, Section 5).
Probe at ffc7e3eb on release/v0.2.3, pin d5b3a151 (R/'s feature code is
identical). No product code changed. Runner probe.R; checker check.R (CHECK
PASS: reruns into scratch, diffs the CSVs, candidate against pin, census
check, package-scope guard); timing steps_clean.R, probe_time.R,
inputs_split.R; evidence in results/.

## 1. Clean step table

Quiet machine (about 10 percent load), High performance plan, P-cores via
pcore.ps1, 7 reps. Cells: clean seconds (share) / the RFC's busy-machine
seconds.

| step | 10x7200 run | 10x7200 sweep | 500x1260 run | 500x1260 sweep | 1166x252 run | 1166x252 sweep |
|---|---|---|---|---|---|---|
| axis formatting | 0.16 (64%) / 0.19 | 0.34 (59%) / 0.43 | 0.03 (4%) / 0.04 | 0.06 (4%) / 0.07 | 0.01 (1%) / 0.01 | 0.02 (1%) / 0.01 |
| TTR raw call | 0.00 / 0.00 | 0.01 (2%) / 0.03 | 0.14 (18%) / 0.14 | 0.41 (23%) / 0.49 | 0.30 (29%) / 0.37 | 0.90 (38%) / 1.11 |
| input treatment | 0.03 (11%) / 0.04 | 0.02 (4%) / 0.03 | 0.25 (34%) / 0.34 | 0.27 (15%) / 0.35 | 0.30 (29%) / 0.35 | 0.28 (12%) / 0.34 |
| calculate bookkeeping | 0.01 (6%) / 0.02 | 0.05 (9%) / 0.07 | 0.16 (21%) / 0.16 | 0.50 (29%) / 0.52 | 0.20 (19%) / 0.22 | 0.56 (24%) / 0.67 |
| segment frame and rest | 0.00 / 0.00 | 0.02 (4%) / 0.03 | 0.06 (8%) / 0.10 | 0.19 (11%) / 0.24 | 0.08 (8%) / 0.11 | 0.24 (10%) / 0.32 |
| planes | 0.01 / 0.00 | 0.00 / 0.02 | 0.03 (4%) / 0.06 | 0.11 (6%) / 0.11 | 0.06 (6%) / 0.08 | 0.16 (7%) / 0.21 |
| compute residual | 0.03 (11%) / 0.03 | 0.09 (16%) / 0.13 | 0.06 (8%) / 0.06 | 0.14 (8%) / 0.21 | 0.05 (5%) / 0.07 | 0.14 (6%) / 0.23 |
| causality and certification | 0.01 / 0.02 | 0.03 / 0.05 | 0.00 | 0.01 / 0.02 | 0.00 | 0.01 / 0.01 |
| payload split and rebuild | - | 0.00 | - | 0.05 (3%) / 0.05 | - | 0.03 (1%) / 0.05 |
| whole path | 0.25 / 0.30 | 0.57 / 0.80 | 0.75 / 0.90 | 1.75 / 2.08 | 1.03 / 1.24 | 2.37 / 2.98 |
| bare TTR, same definitions | <0.005 | <0.005 | 0.08 | 0.24 | 0.16 | 0.47 |

Shares match the RFC within a few points; the whole paths are 14-29
percent faster than the busy-machine numbers.

- Candidate 1 (format the axis once): strongly supported on narrow shapes,
  about 0.12 s (run) and 0.30 s (sweep) at 10x7200; negligible on wide
  shapes. It must keep the same format string (it feeds the precompute
  axis_hash).
- Candidate 3 (TTR per-call overhead): raw-call bucket minus bare TTR is
  0.06, 0.17, 0.14 and 0.43 s on the four wide cells.
- Candidate 2 (narrow input treatment): smaller than its bucket (Section 3).
- Candidate 5 (matrices only): 0.03-0.05 s; its case is memory.
- Calculate bookkeeping (19-29 percent on wide shapes) is the largest cost
  stage 1 does not touch (stage 3's).

## 2. Engine-version census (candidate 6)

results/census.csv: 136 rows (128 helpers reachable from the run, sweep,
projection, read-entry and emitted-closure roots, 8 read-side and reuse
helpers added by hand). census_check.R proves the classification by
mutation: replacing a helper moves the version for exactly the 25 named
ones.

| bound by | rows |
|---|---|
| engine version | 24 (plus ledgr_active_feature_fingerprint, counted as identity) |
| another identity (indicator fingerprint, history rule versions, union hash) | 21 |
| unbound | 60 |
| identity infrastructure or excluded | 31 |

Unbound includes every helper the RFC names, plus the built-in series
helpers, ledgr_ttr_call, the catalogue index/row/apply chain, the causality
probe and refusal builders, and the whole prepared representation (payload
split, rebuild, projection, slice, pulse names).

Marked UNSURE: six substrate mask helpers bound only by hand-maintained
history rule-version constants (ledgr_history_substrate_expected_at,
_terminal_planes, _fact_plane, ledgr_history_segments_materialize,
ledgr_history_axis_lower_bound, ledgr_history_utc); four read-side decoders
(ledgr_history_feature_evidence, _compact, ledgr_history_plane_lookup,
ledgr_history_plane_run); ledgr_feature_def_declarations (its outputs are
hashed into the active fingerprint, its code is not).

Two engine-hashed helpers are off the feature path: ledgr_compute_feature_series
and ledgr_compute_feature_scalar_at (the legacy v0.1.4 block), called only by
the internal ledgr_check_no_lookahead and five test files.

## 3. Candidate 2: identical, saves 0.08-0.16 s

Rule: any custom definition treats all five fields; otherwise the union of
the certified definitions' required fields (built-ins read close; all 44 TTR
catalogue rows have required fields equal to their input mapping).

284 cases: 6 substrates (late-known inactivity, delisting and relisting,
three carry policies, field-level holes, a long gap, short and 2-bar
histories) x 3 calculation starts x 16 definition sets (certified TTR rows
with close, hl, hlc and hlcv; built-in SMA apart from TTR SMA; a forged
catalogue claim; unregistered TTR forms; custom callbacks reading volume,
open and high, one with input_carry excluded; lookahead and parity
refusals; mixtures), plus the single-definition read entry. Compared:
values, NA placement, types, dimensions, names, plane records, indexed
projection planes, history-read evidence, refusal classes and fields, RNG.

0 of 284 differ (c2, c3 and both). 43 pin cases refuse (lookahead 24,
invalid output 10, parity 9), identically. A deliberately broken arm that
narrows custom callbacks (the seed review's F3) differs in 58 cases.

Saves 0.16 s of 0.77 (500x1260 run), 0.08 s of 1.00 (1166x252 run), 0.12 s
(500x1260 sweep). About half the input-treatment bucket is the
expected-session and terminal masks (0.09-0.15 s), which narrowing keeps;
narrowing cuts the carry from about 0.09 to 0.03 s. On the 1166x252 sweep
candidate 2 alone saves nothing (9 reps): the probe's generic frame builder
spends it back. Land candidates 2 and 3 together, or keep the frame built
directly.

## 4. Candidate 3: identical, saves 0.07-0.27 s

TTR function resolved once at certification; on a raw-cache miss, close
inputs pass as.numeric(fields$close[rows]) directly, other inputs build the
frame only then; nothing built on a cache hit. Output selection, the MACD
histogram, normalisation, the short-sample guard and the cache key
unchanged. ledgr_ttr_raw_call() kept as the call site (two optional
arguments), so LTB-0276's counts do not change.

Same 284 cases, 0 differences; raw TTR call counts identical in every
counted case (sharing kept); frames built 82 -> 13 and 495 -> 209.

Saves, alone: run 0.07 s (500x1260), 0.09 s (1166x252); sweep 0.15 and
0.25 s (9-12 percent). With candidate 2: run 0.20-0.22 s (20-27 percent);
sweep 0.29-0.44 s (18-19 percent).

The single-definition read entry (ledgr_history_feature_planes) uses no raw
cache, so TTR runs there through the emitted closure (ledgr_ttr_call); the
two routes must stay equivalent.

## 5. Candidate 5 inventory

Physical-shape assertions (precomputed$payload split vectors):
test-precompute-features.R:27 (length 2), :43-46 (names equal the union
fingerprints), :59-62 (an entry's feature_id and values$AAA against the
matrix row; the matrix side is semantic). test-history-integration.R:174
compares $payload; :173 already compares projections; without $payload it
would pass vacuously, so delete it with a stated reason.

Kept matrix-layout assertions: test-precompute-features.R:47-58, :61, :64,
:235, :720-721. Source-text assertions naming
ledgr_history_precompute_payload: test-strict-ttr-cleanup.R:167-176,
test-history-integrated-proof.R:526.

Split-vector reader: only ledgr_projection_from_payload()
(R/runtime-projection.R:165). Producers: R/sweep.R:278-291,
R/precompute-features.R:91-113, R/pulse-snapshot.R:395-405,
dev/bench/peer_benchmark/peer_benchmark.R:658-670,
dev/bench/v0_2_3_ws16_interface/tile_probe.R:93,
dev/bench/v0_2_3_lean_tuning_profile/feature_steps.R.

## Registered tests the cut will touch (each needs a stated reason)

- LTB-0144 (test-strict-feature-acceleration.R:205) pins the engine version
  literal; every stage-1 change moves it (intended).
- LTB-0276 (test-strict-ttr-cleanup.R:63) counts ledgr_ttr_raw_call()
  calls; unchanged if the call site is kept.
- The candidate-5 physical-shape assertions above.
