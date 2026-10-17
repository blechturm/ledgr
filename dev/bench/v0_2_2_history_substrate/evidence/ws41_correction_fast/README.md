# WS41 correction fast profile

Tree: `9c1e352e7c9dd5c9fea21b3f1cbaab18d60ee7e9`

The three ordinary fast-profile runs execute 565 of 565 registered blocks
with no failures or skips. Their elapsed times are 112.82, 111.11 and 113.29
seconds. The registered checker returns a timing miss because the median is
112.82 seconds against the unchanged 112-second bound.

This record is retained as a miss. It does not replace or relabel the original
pre-review passing record.

Commands:

```text
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_history_substrate/evidence/ws41_correction_fast --run-index=<1|2|3>
Rscript --vanilla tools/check-test-gate.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_history_substrate/evidence/ws41_correction_fast
```
