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

## Close-review correction

The Type 1 close review found that the accepted retry hid a repeatable cost on
the bundle-loop arm. Commit `d72a73b` removes redundant singular resolution
inside an already-resolved bundle and stops warning accounting after its one
run-level warning. The independent correction record is under
`evidence/close_review_correction/`.

Its first three-triplet attempt compares pre-cut `6ef9b19` with candidate
`d72a73b`. Median seconds are 34.72 for the pre-cut bundle, 36.06 for the
candidate bundle and 27.43 for the candidate plane. Candidate/pre-cut is 1.039
against the 1.05 gate; plane/candidate is 0.761 against 0.90. Fills, equity and
strategy state are exact, and no retry was triggered.
