# Indicator Source Attribution Inventory

## Answer

The old 9.57-second built-in-versus-TTR chart gap is not an indicator-source
effect. It is order-confounded. Across the registered six permutations, every
pair changes sign by process position and no pair meets the preregistered
structural threshold. This result authorizes no indicator optimization.

## Executed fixture

The runner built one sealed 500-instrument by 1,260-pulse snapshot from seed
20260530, closed it, and copied its bytes for every arm. All 18 copies reopened
with snapshot hash
`170ac16d96a91f5cbcc42f91f20d45f386ed91080a28a5c85f126b6de8ef0652`,
contained zero prior runs and started after a process-local feature-cache
clear.
Six fresh child processes ran ABC, ACB, BAC, BCA, CAB and CBA, so each arm
occupied each position twice. R 4.6.1 resolved ledgr 0.2.0.2, TTR 0.24.4,
DuckDB 1.5.2 and collapse 2.1.8.

The measured clock is experiment construction plus `ledgr_run()` plus the
equity, fills and realized-trades readers. Store copy, verified reopen and the
post-run full feature extraction are recorded separately. Positions are never
pooled in the decision.

| Arm | Position 1 mean / spread | Position 2 mean / spread | Position 3 mean / spread |
| --- | ---: | ---: | ---: |
| Native `ledgr_ind_sma()` | 50.635 / 0.210 s | 51.740 / 4.160 s | 46.955 / 1.510 s |
| Private `peer_sma_ttr()` | 51.050 / 0.520 s | 48.235 / 4.110 s | 45.535 / 0.310 s |
| Public `ledgr_ind_ttr("SMA")` | 51.295 / 0.990 s | 46.700 / 0.020 s | 45.225 / 0.730 s |

Native minus wrapper is -0.415, +3.505 and +1.420 seconds by position. Native
minus public TTR is -0.660, +5.040 and +1.730 seconds. Wrapper minus public TTR
is -0.245, +1.535 and +0.310 seconds. Every contrast changes sign, and the
minimum effect is below one second and five percent for all three comparisons.
Only the native-minus-public position-2 cell exceeds the largest
within-position spread. Position 1 reverses its direction; position 3 remains
positive but is below five percent and the 4.16-second spread. No comparison
passes the registered conjunction. The first-position native and wrapper
means differ by only 0.415 seconds, not the historical 9.57 seconds.

## Output evidence

Every arm produced 1,260,000 feature cells with the same 6,500-cell NA mask,
1,260 equity rows, 68,201 fills and 33,948 realized trades. Wrapper and public
TTR feature values are exact. Native versus both TTR implementations differs by
at most `7.56699591875076e-10`, within the existing `1e-8` tolerance. Equity,
fills and trades are exact across arms after no run-specific exclusions were
needed. The raw record retains every pairwise residual and every output hash.

One fresh Rprof run per arm points at the same ordinary execution lanes.
`ledgr_execute_fold()` accounts for 68.27%, 68.03% and 68.41% of sampled time;
fill-event writing accounts for 38.98%, 40.24% and 41.30%. No profile localizes
a material difference in the indicator implementations. `t_pre` remains a
small phase and any source differences in it are below the decision threshold.

## Demoted, deleted and learned

- Demoted: the September 23 chart's 9.57-second difference is a historical
  fixed-order observation, not evidence that built-in SMA is faster than TTR.
- Demoted: the isolated 1,000-call micro-comparison is mechanism evidence only;
  it cannot explain a full-run chart row.
- Deleted from the working theory: neither the private wrapper nor the public
  adapter has a measured package-scale disadvantage at this fixture.
- Learned: fresh process position materially affects this workload; the third
  arm is roughly five seconds faster than the first regardless of source.
- Learned: the private wrapper and public adapter compute the same complete
  feature planes, and all three arms lead to the same economic outputs.
- Retained: the semantic tickets remain necessary because missing-session
  and sweep propagation are correctness questions independent of this timing
  result.

## Failure sensitivity and reproduction

The checker validates the 18 arm-position cells, copied-store identity, empty
starting caches, phase reconciliation, complete output coverage, tolerance
and the structural-decision conjunction. A gut changes only public TTR's slow
window from 10 to 11. It makes feature masks and values, equity, fills and
trades fail instead of allowing a timing-only record to pass.

The full independent rerun passed 166 checks and reproduced the output and
parity CSVs exactly. Its three pairwise contrasts also changed sign by
position and declared no structural difference. The gut produced 21 named
parity failures before the checker restored its own successful status.

Run the record:

```text
Rscript dev/spikes/indicator-source-attribution/runner.R
```

Rerun, diff deterministic outputs and validate the clocks:

```text
Rscript dev/spikes/indicator-source-attribution/checker.R --gut
```
