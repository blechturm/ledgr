# ws4a-timing-1 base smoke (LDG-3163 scope a)

Base `953338df` installed from `git archive` into a scratch library; protocol
`dev/bench/timing/protocols/ws4a-timing-1/`. Not a gate window.

- `functional_check.csv`: every cell once at reps 1, full size, one process,
  run while other LDG-3163 work loaded the host. Every cell ran and reported
  its work string; it sized the reps in `matrix.csv` (each timed section
  about 2-4 s or more).
- `base_marginal_smoke.csv`: the absolute cell three times on a quiet host
  (2026-10-30, no other ledgr work running): 216.95, 215.05 and 215.83
  us/fill, spread 0.9%; fills_per_repetition 67,725 in every run (33,710
  closed); final equity 10728506.7076, equal to the carrier probe. The
  loaded functional check read 226.06 us/fill.

The ratio thresholds are decision (4)'s, unchanged; the absolute bound is
40e-6 s/fill (`dev/bench/v0_2_3_ws4a/timing_absolute.R`). Both are frozen
before cut acceptance; the gate runs at LDG-3169 (and the reader cells at
LDG-3164) with the shared runner's alternating pairs.
