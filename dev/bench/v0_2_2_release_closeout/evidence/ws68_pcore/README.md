# Workstream 68 P-core fast-profile comparison

This record resolves the invalid whole-CPU-mask timing records in
`ws68_fast` and `ws68_fast_retry`. Those earlier characterization runs used
`0xFFFFFF`, which included efficiency cores. The binding local methodology
uses the performance-core mask `0xFFFF`.

The base arm is detached commit `5a7476e4`, before the Workstream 68 product
correction. The candidate arm is `e18b290e` plus the finding-only Workstream
65 documentation corrections; none of those corrections changes package
runtime code.

Each arm ran three times, alternating base and candidate, under the Windows
High performance power plan. Before each run, the parent PowerShell process
set its affinity to `0xFFFF`, which the child R process inherited:

```text
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity =
  [IntPtr]0xFFFF
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary \
  --records=<base-or-candidate-directory> --run-index=<1|2|3>
Rscript --vanilla tools/check-test-gate.R --profile=fast --mode=ordinary \
  --records=<base-or-candidate-directory>
```

Every run executed 577 of 577 blocks without a failure.

| Pair | Base (s) | Candidate (s) | Candidate / base |
| ---: | ---: | ---: | ---: |
| 1 | 115.74 | 111.74 | 0.965 |
| 2 | 111.53 | 112.47 | 1.008 |
| 3 | 111.39 | 109.69 | 0.985 |

The base median is 111.53 seconds and the candidate median is 111.74 seconds.
Both pass the unchanged 112-second gate. The median within-pair ratio is
0.985, so the bounded Workstream 68 correction does not regress this lane.
`check-test-gate.R` returns `LEDGR_TEST_GATE_OK` for both record directories.
