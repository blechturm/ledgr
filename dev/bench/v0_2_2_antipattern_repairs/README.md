# v0.2.2 Antipattern-Repair Evidence

This directory contains local evidence for Cut 8. It is structural and
regression evidence, not a public engine-speed claim.

## LDG-2966 Writer Record

`writer_arm.R` measures three 5,000-fill pulses through the production memory
handler. Each fill exercises event staging, the accounting patch and one fill
leg before the pulse flush. Three fresh-process pairs alternate accepted
pre-cut commit `a8669a3` and candidate commit `f318453`.

The per-process pulse medians were:

| Pair | Pre-cut | Candidate | Ratio |
| ---: | ---: | ---: | ---: |
| 1 | 0.95 s | 0.28 s | 0.295 |
| 2 | 0.91 s | 0.29 s | 0.319 |
| 3 | 0.89 s | 0.30 s | 0.337 |

The median paired ratio is 0.319, or a 68.1% reduction at this deliberately
wide pulse. Event and fill hashes are identical within every pair. The
checker requires both hashes, all three pairs and at least 2,000 fills per
pulse. This isolated record does not estimate an ordinary portfolio run.

The ordinary Workstream 11 suite then compared the same commits in five
fresh-process pairs per shape. Cold ratios were 0.984 to 1.003 and warm
ratios 0.992 to 1.015, all below the existing 1.10 gate without a retry.
Semantic hashes and the accepted 757-pulse orientation record passed the
self-testing checker. Its complete scratch record was
`C:/tmp/ledgr-ws17-ldg2966-long-window`; the durable summary, measurements,
process record, hashes and suite provenance are copied under
`evidence/ldg2966_long_window/`.

Run one writer arm from the repository root with:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_2_antipattern_repairs/writer_arm.R `
  <repo> <pre_cut|candidate> <pair> <output.csv>
```

Combine the six arm files as `writer_record.csv`, then run:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_2_antipattern_repairs/check_writer_record.R `
  dev/bench/v0_2_2_antipattern_repairs/evidence/writer/writer_record.csv
```

## LDG-2967 Long-Window Record

`evidence/ldg2967_long_window/` is the durable summary of the ordinary
Workstream 11 comparison between accepted pre-Cut-8 commit `a8669a3` and
candidate `16e660b`. It contains five alternating fresh-process pairs for all
three ordinary shapes. The checker passed without retry: cold paired-median
ratios range from 0.9844 to 1.0029 and warm ratios from 0.9917 to 1.0036,
against the retained 1.10 ceiling. Semantic hashes and the accepted 757-pulse
orientation match. These are regression gates, not a speedup claim for the two
minor repairs.
