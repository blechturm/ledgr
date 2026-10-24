# History manifestation spike charter v2

**Status:** GREEN; closed 2026-10-24  
**Date:** 2026-10-24  
**Product changes:** none

## One question

Does supplying the ordinary reader with a prepared finite-observation summary
make an exact matrix and wide frame cost at most 0.5 ms median at 500
instruments by 252 sessions, without a value rescan, transient digest, rich
cell evidence or cost proportional to unrequested snapshot rows?

## Prerequisite

The v1 charter stopped because a fresh completeness scan put the otherwise
minimal reader just outside its raw-copy multiple. `representation_probe.R`
shows that a prepared prefix-count query itself costs about 0.006 ms and that
the resulting minimal matrix and frame cost about 0.241 and 0.359 ms. The
probe's dense prefix plane is a cost oracle only, not an authorized product
representation; a production amendment must choose a memory-bounded prepared
summary or fuse counting into the one manifestation pass.

## Runnable comparison

`spike_runner.R` compares the current public reader with one v2 candidate. The
candidate receives the exact finite counts from the already treated window,
as the answer a prepared summary would supply, then performs one value slice,
sparse carry patch, transpose and direct result construction. It records the
same four shapes as v1, exact value and selection parity, allocation, retained
size and component clocks. Matrix and frame remain sibling outputs.

## Kill condition

Stop before proposing a focused RFC amendment if either v2 output exceeds
0.5 ms median at 500 by 252, differs from the current values, dimensions,
names or selected IDs, invokes a digest, exceeds 3.5 payload copies, or has a
log-log growth exponent outside 0.65 to 1.30 over the registered shapes.

## Deliverables

- the v2 runner, evidence CSVs and checker;
- a gutted transient-hash path that the checker rejects;
- one inventory naming the unresolved storage-form and memory question;
- a one-page closeout stating only what the spike proved.
