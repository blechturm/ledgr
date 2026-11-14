# Spike ephemeral_lane: closeout

Charter: `CHARTER.md` (maintainer, 2026-11-14). Question: what one sweep
candidate costs per pulse on the lean loop with results in memory
(`ledgr_sweep()`, one candidate, one worker), against the same workload as a
durable `ledgr_run()`, with phase clocks reconciled.

## What ran

`run.R` (results/lanes_*.csv): both lanes on the pin library d5b3a151 with
the lean loop installed (the cut16-loop-1 loading), alternating fresh
processes, 7 rounds per workload, High performance plan, P-core affinity
0xFFFF, 2026-11-14. Phases per run: the whole call; the fold
(`ledgr_fold_envelope`); the output handler's write and flush methods the
loop calls, timed inside the fold; the rest of the fold; outside the fold.
Every run was one lean fold. A scratch library install (the WS35 candidate,
R CMD INSTALL with compilation) overlapped part of the window; every cell's
seven rounds stay within 5 percent of each other, so the medians are kept.

Microseconds per pulse, medians of 7:

| phase | 10 x 7,200 durable | 10 x 7,200 ephemeral | slice2 durable | slice2 ephemeral |
| --- | ---: | ---: | ---: | ---: |
| whole call | 522 | 415 | 888 | 764 |
| outside the fold (preparation, finalisation, results) | 128 | 85 | 111 | 55 |
| fold | 394 | 331 | 779 | 711 |
| of which output writes | 31 | 3 | 56 | 26 |
| of which the rest (loop, expansion, transaction) | 363 | 328 | 722 | 684 |
| the sweep's own `t_engine` | | 332 | | 713 |

- **Parity:** the nine metrics both lanes report and the final equity are
  bit-identical in every run of both workloads (results/lanes_parity.csv).
- **Reconciliation:** the phases sum to the whole call by construction; the
  independent clock the sweep keeps (`t_engine`) agrees with the fold clock
  within 1 percent on both workloads.

## Verdict

Conclusive (no kill clause hit). The ephemeral lane saves **about 20
percent** of the whole call on the crossover (107 us per pulse) and **about
14 percent** on slice2 (124 us). A little over half of the saving is inside
the fold (63 and 68 us: writes 28-30 us, and 35-38 us of expansion and
transaction work for rows the memory sink never keeps); the rest (43 and
56 us) is outside it (run-store setup, finalisation and result reads).

## What the package learned

- The ephemeral fold is still 331 us per pulse on the crossover and 711 on
  slice2: **the loop itself, not the output, is where the time is.** The
  durable-only work is about 107-124 us per pulse; removing all of it leaves
  80-86 percent of the cost (415 of 522, 764 of 888).
- The memory sink's writes are not free on a fill-heavy workload (26 us per
  pulse on slice2: fill events and diagnostics still go to memory).
- Against the WS14 aim of an ephemeral lane within about 3x PMwR (about
  55 us per pulse in total for 10 x 7,200 on the published figures), the
  measured ephemeral call is 415 us per pulse, about 7.5 times the aim and
  about 21 times PMwR's published 0.14 s (a reference scale on other data,
  not a matched comparison).
- The earlier estimates (about 440 us on slice2 and 250 on the crossover,
  after both compiled kernels) were too low: neither includes the outside-
  the-fold work the sweep still does, and the kernels are not part of this
  measurement.

## Open

The ephemeral lane with the compiled kernels installed was not measured;
neither was a many-candidate sweep (shared preparation across candidates,
the published 12 x 90 x N rows). R-floor stage 2b decides how much of the
loop's 330-710 us per pulse is implementation rather than guarantee.

Reproduce: `Rscript dev/spikes/ephemeral_lane/run.R --lib=<pin library>
--out=<dir>` under the host policy, then `Rscript
dev/spikes/ephemeral_lane/check.R --lib=<pin library> --scratch=<dir>
--spike-base=7816af2c`.
