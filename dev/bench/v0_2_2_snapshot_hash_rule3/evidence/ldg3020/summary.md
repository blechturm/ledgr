# LDG-3020 process-local verification reuse

This record is agent-provisional pending Type 1 close review. It contains no
private vendor data and does not migrate, read or reseal a legacy snapshot.

## Semantics and reuse

- The vendor-neutral fixture repeats the LDG-3019 population: 50 instruments,
  1,260 sessions and 30 sweep candidates.
- All 31 family row counts and digests are identical to LDG-3019.
- Phase clocks are 2.041 seconds for build, 5.761 for the momentum run, 3.288
  for readers, 13.668 for the sweep and 9.550 for walk-forward. The LDG-3019
  values were 2.017, 5.812, 3.225, 13.635 and 10.442 seconds respectively.
- LTB-0254 counts one complete verification for each cold run, sweep,
  walk-forward, facts and reconstruction boundary. Disabling the warm proof
  makes the sweep and walk-forward counts fail.
- LTB-0253 detects reactivation of a stale old-root proof after a failed
  verification. LTB-0256 proves serialized public objects start cold in a
  fresh process.

## Test profiles

The ordinary fast profile passed 566 of 566 blocks in 116.93, 126.19 and
122.38 seconds. The 122.38-second median is above the fixed 112-second local
bound, so this is not recorded as a timing pass. A same-session run of the
accepted Cut 13 base passed 565 of 565 blocks in 115.35 seconds and also
exceeded the bound. Earlier same-host observations were about 129.57 seconds
after LDG-3019 and about 139.96 seconds on the adjacent accepted base. These
comparisons support the expected reuse effect but do not replace the
registered-host gate.

The registered ordinary long-window suite compares LDG-3019 commit
`d4d3c06b` with LDG-3020 commit `40df12d0` over five alternating pairs per
shape. It completed in 506.96 seconds and its self-checker passed. Median
candidate/baseline ratios were 0.901 to 1.009 cold and 0.910 to 0.961 warm;
none required a retry. Exact semantic records match for all three shapes. The
complete checked-in record is under `long_window_record/` and reproduces with
`dev/bench/v0_2_2_long_window_regression/check_record.R`.

After rebasing onto release head `b31d523f`, the integrated tree passed the
ordinary Windows fast profile at 566 of 566 blocks, zero skipped or failed,
in 110.260 seconds against the fixed 112-second bound. The machine-readable
record is under `integrated_fast/`. GitHub Actions run 38305153540 passed the
v0.1.x acceptance layer, three semantic fast-profile runs and `R CMD check`
at final commit `f5a54cae`. Its 187.007-second Ubuntu median is advisory under
the accepted synthesis; the registered Windows host owns the timing gate.

The post-review correction fast record is checked in under `correction_fast/`.
It executes 566 of 566 blocks with zero skipped or failed in 110.04 seconds;
the ordinary gate passes against the unchanged 112-second bound on its first
run.

Integration exposed two stale test-harness assumptions, neither in product
code. AT7 claimed a cold-process raw-tamper oracle but retained the warm proof
created by seal; `8e0a75c5` resets that private proof before the load. The
installed-package check excludes `dev/bench`; the corrected claim blocks
distinguish a checkout from an installed package through `.git` or
`.Rbuildignore`: a checkout must contain the suite, while an installed package
must exclude `dev`.

## Seven-shape walk for verification reuse

1. No one-row frames are accumulated; the verified set stores one scalar key.
2. No snapshot table is subset inside an id loop.
3. No per-element parsing or formatting was added.
4. No row-wise JSON encoding was added.
5. The envelope and complete root are each read once per cold outer call; warm
   calls compare one prepared scalar key.
6. Lookup is a hashed environment access, not a scan over verified entries.
7. The environment grows by one tuple per verified snapshot identity, never by
   one value per bar, pulse, candidate or fold.

## Compatibility boundary

Only rule-3 snapshots are executable through content-dependent paths. Missing,
rule-1 and rule-2 markers remain metadata-readable and otherwise refuse with
the classed rebuild condition. This ticket adds no migration, legacy reader or
fallback for missing markers. The private Sharadar lake is therefore not a
post arm; its one rule-3 rebuild and post clock remain owned by the routed WS7
ledgr-research work.
