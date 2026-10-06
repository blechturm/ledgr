# Feature-Map Read-Surface Record

This local, vendor-neutral record belongs to Cut 7 / LDG-2965. It compares
three fresh-process arms at 500 instruments by 1,260 pulses:

1. the accepted pre-cut active-alias bundle loop;
2. the candidate bundle loop; and
3. the candidate singular-plane strategy.

Each attempt is three alternating triplets. Normalized fills, equity and
strategy state must be exact across all arms. The candidate plane must take at
most 0.90 times the candidate loop median; the candidate loop must take at most
1.05 times the pre-cut loop median. A failed initial timing gate triggers one
complete retry, whose result stands.

Run from the repository root with the R profile needed by the local checkout:

```powershell
Rscript dev/bench/v0_2_2_feature_map_read_surface/run_record.R `
  C:/tmp/ledgr-ws16-precut . <record-dir> 3
Rscript dev/bench/v0_2_2_feature_map_read_surface/check_record.R <record-dir>
```

The record is implementation evidence, not a general engine-speed claim.
