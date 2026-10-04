# DuckDB membership-resolution probe findings

**Date:** 2026-10-04
**Status:** prerequisite probe; binds nothing.

`probe.R` used a sealed snapshot and kept the ordinary full snapshot-hash
verification in both arms. The candidate read eligible membership headers,
found the last complete set, fetched only that set and later set rows plus all
applicable set-less assertions, then used the existing R resolver on that
reduced input.

At 30,000 set rows there was only the initial complete set, so no history could
be pruned: both arms took about 0.73 seconds. At 300,000 rows the last complete
set reduced transfer to the final 100 of 600 sets. The ordinary public call
took 7.25 seconds and the candidate 4.07 seconds, a 1.78x speedup. Public rows
and evidence were exact after normalizing data-frame row names.

The result justifies a bounded spike, not a general SQL rewrite. Its central
question is whether the gain and parity survive full-universe resolution,
explicit instruments, set-less overrides and a failure-sensitive complete-set
boundary.

