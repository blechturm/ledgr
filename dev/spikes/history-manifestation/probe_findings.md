# History manifestation prerequisite probe

**Date:** 2026-10-24  
**Product tree:** `4988bfd0`  
**Outcome:** prerequisite satisfied

## Question

Is final matrix or wide-frame construction itself responsible for the current
Workstream 55 latency?

## What ran

`probe.R` reused the registered Workstream 55 public-API record for the current
500-instrument by 252-session direct reader. It then constructed the same-sized
matrix and wide data frame from one already prepared instrument-by-session
double plane. The candidate outputs performed no evidence reconstruction and
no content hash.

## Observation

| Path | Median |
| --- | ---: |
| Registered current direct reader | 22.500 ms |
| Prepared-plane matrix manifestation | 0.188 ms |
| Prepared-plane wide-frame manifestation | 0.305 ms |

The two prepared manifestations have identical numeric values. Their retained
sizes are about 1.06 and 1.07 MB. The current direct result is about 1.16 MB;
its latency therefore does not follow from the returned numeric payload.

## Finding

Final manifestation is not the bottleneck. Both ordinary R representations
already meet the sub-millisecond objective when handed prepared values. The
full spike may therefore ask the remaining bounded question: do direct
selection, sparse carry patching and growth across the registered shapes keep
both outputs in the same cost class?

The probe does not decide the public result contract or authorize a product
change.
