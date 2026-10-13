# Focused re-review residue fast profile

This record was taken on the Windows Workstream 8 host after commit
`2e15d34e`. All 566 selected fast blocks passed with zero failures, warnings
or skips in each of three serial fresh processes. Elapsed times were 131.01,
131.70 and 131.92 seconds. The 131.70-second median exceeds the unchanged
112-second bound, so the checker correctly fails and this is not a timing
pass.

The retained census was compared with `../correction_fast/run-1-census.csv`.
Matched block time rose broadly from 107.72 to 128.09 seconds. The strengthened
LTB-0250 legacy-reader block rose from 2.61 to a 3.22-second median, accounting
for 0.61 seconds rather than the approximately 20-second lane increase. The
record therefore supports semantic completion but is not an effect estimate
or a replacement for the earlier binding 110.04-second record.

Commands:

```text
Rscript tools/run-test-profile.R --profile=fast --mode=ordinary \
  --records=<residue-fast-directory> \
  --run-index=<1|2|3> \
  --library=C:/Users/maxth/AppData/Local/R/win-library/4.6
Rscript tools/check-test-gate.R --profile=fast --mode=ordinary \
  --records=<residue-fast-directory>
```

The checker result is:

```text
Fast test gate failed: median 131.700 > 112.000 seconds.
```
