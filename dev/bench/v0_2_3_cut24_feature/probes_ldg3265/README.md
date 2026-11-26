# LDG-3265 diagnostic probes

Descriptive probes behind LDG-3265's diagnosis of the stage-3 regressions.
They are not decision statistics: the retention decision rests on the three
shared-harness records under `dev/bench/timing/records/cut24-feature-1/`.
Added for close review round 1, F2: the first session ran equivalent
scratch scripts whose outputs were not kept; these are the committed
scripts and a fresh run of them.

## Inputs

- Fixtures and definitions: protocol cut24-feature-1's `workloads.R`
  (zero-admission: 500 x 1,260 with one middle session removed from every
  instrument, Cut 22's run SMA set; custom-only: the 500 x 1,260 bar-native
  fixture with one close-returning custom indicator).
- Libraries, installed from their commits under
  `C:/Users/maxth/ledgr-wt/cut24-scratch/libs/`: `final-8f7c6977` (R/ equal
  to the cut base 2dee0f98), `ldg3265-ffe19415` (simplified candidate),
  `ldg3265-b56eaee9` (exception candidate).
- `swap.R` reads `R/history-features.R` at 2dee0f98 and `R/debug.R` and
  `R/history-features.R` at ffe19415 with `git show`.
- Environment: `host.txt` (Windows 11 x64, R 4.6.1, Balanced power plan;
  the timing records ran on High performance). Debug off throughout.
- Clock: elapsed `proc.time()`, medians of blocks; Windows' clock resolution
  is about 15 ms per block, so figures are coarse at the 5-10 ms level.

## Command

    Rscript dev/bench/v0_2_3_cut24_feature/probes_ldg3265/run_probes.R

Writes `host.txt`, `pieces.txt`, `zero_components.txt` and `swap.txt`.
The fresh run is from 2026-11-26 14:07 CET, about 25 minutes wall.

## Results

- `pieces.txt` (whole-library piece timings, two alternations per case):
  zero-admission compute 0.583 to 0.600 s on the base library, 0.583 to
  0.590 s on the candidates; custom-only compute 0.400 to 0.417 s base,
  0.417 to 0.423 s candidates; engine-version computation and projection
  costs are broadly comparable at this probe's resolution. This
  probe does not resolve differences of 1 to 4 %. The first session's
  reading of 570 ms base against 590 ms candidate (zero), an unverified
  original observation whose record is unavailable, is not reproduced and
  is withdrawn.
- `zero_components.txt` (ffe19415, per preparation, zero-admission): the
  finiteness pass about 2 ms, the gate over all 500 instruments about 7 ms,
  mask construction over all instruments about 97 ms, knowledge ranges
  about 3 ms.
- `swap.txt` (one process, function sets swapped and byte-compiled, 12
  alternations of 5 calls): zero-admission compute 0.583 s base, 0.599 s
  candidate (ffe19415), 0.592 s hybrid (base with the candidate's input and
  mask helpers); custom-only 0.436 s base, 0.433 s candidate, 0.427 s
  hybrid.

The first session's scratch outputs were not kept; any figure from that
session is an unverified original observation and is not used here.

## Reading

On the zero cells the candidate's compute code costs about 15 ms more per
preparation in one process, of the order of the gate and finiteness pass on
ffe19415; this points at per-instrument admission work but does not prove
the cause of the harness ratios. On the custom cells no cost appears in the
compute code itself; the harness regression there is unexplained.
