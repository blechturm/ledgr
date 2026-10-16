# Workstream 40 correction clock

`base.csv` and `candidate.csv` were recorded with
`civil_resolution_clock.R` in fresh R processes on the same host. Each arm
constructs its fact family before timing, then times only `ledgr_facts()` over
20,000 membership rows. The runner uses three repetitions and calls `gc()`
before each one.

The base is the reviewed tree `ae88df62`. The candidate is the correction
working tree before its evidence commit. The POSIX-only median is below the
clock's 0.01-second resolution after the correction, so `0.00` is not a claim
of zero cost. The registered call-count detector, rather than this supporting
clock, binds the rule that POSIX-only rows bypass civil re-resolution.

The civil median falls from 1.50 to 0.45 seconds after replacing row-wise time
token formatting with one vectorized call. This is supporting shape evidence,
not a release performance gate. The remaining Date-backed construction cost
belongs to the later shared-substrate and memory work; Workstream 40 adds no
second civil representation.
