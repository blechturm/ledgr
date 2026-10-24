# History manifestation spike charter

**Status:** stopped by the raw-copy gate; superseded by `charter_v2.md`  
**Date:** 2026-10-24  
**Product changes:** none

## One question

Can an ordinary causal-history matrix and wide frame be manifested directly
from already prepared, policy-treated values with compact provenance, complete
case selection and sparse carry patching in the sub-millisecond cost class at
500 instruments by 252 sessions, while runtime and allocation grow with the
returned cells rather than total snapshot length?

## Prerequisite

`probe.R` and `probe_findings.md` establish that final manifestation alone is
about 0.188 ms for the matrix and 0.305 ms for the frame at 500 by 252, versus
22.5 ms for the registered current reader. The verified snapshot and
owner-validated prepared substrate are the trust boundary. Candidate transient
outputs are not content-hashed or sealed.

## Runnable comparison

The runner prepares one public-API availability context, warms the current
reader, and compares only two paths:

1. the current rich public reader;
2. one minimal direct candidate over prepared treated values.

Component clocks within the candidate attribute orientation, selection,
sparse carry patching, compact metadata, matrix construction and frame
construction. They are attribution, not additional competing designs.

The registered cases are 50 by 252, 500 by 252, 1,166 by 252 and 500 by the
fixture's full history. The runner records elapsed time, R allocations,
retained size, numeric parity and whether cost follows returned cells.

## Kill condition

Stop and recharter the internal representation before proposing an RFC
amendment if either direct output at 500 by 252 exceeds 1 ms median, exceeds
twice the raw-copy median, cannot reproduce the current treated values and
selection, or grows materially with unrequested snapshot rows.

## Deliverables

- `spike_runner.R` and recorded CSVs;
- `spike_checker.R`, which reruns into scratch, checks deterministic outputs
  and the charter gates, and rejects product-source changes;
- `gut_demo.R`, which restores a transient SHA-256 seal and must fail;
- `spike_inventory.md`, including the smallest representation change and the
  gates a focused design amendment may consume.

## Stop result

The first runnable candidate was exact and sub-millisecond, but its 500 by
252 matrix and frame medians were about 0.490 and 0.619 ms. Relative to the
probe's bare manifestation clocks, both sat just beyond the two-times stop
rule. The largest avoidable component was a fresh completeness scan. This
charter therefore stopped as written; `representation_probe.R` established
the cheaper prerequisite for v2 rather than weakening the gate in place.
