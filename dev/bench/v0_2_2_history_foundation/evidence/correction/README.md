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

## Post-correction profiles

The first fast-profile attempt after correction commit `26885b4b` stopped at
LTB-0204. It found that the internal carry-layout validator no longer accepted
the raw `ledgr_fold_list` shape used by its registered direct-call oracle. The
product path already passed resolved windows. Follow-up `88c5afc7` restores the
tested private entry shape by resolving a raw fold list inside that helper;
production still resolves once and passes the prepared windows.

At `88c5afc7`, `fast_profile_retry/run-1-summary.csv` records 565/565 blocks
passing in 110.09 seconds against the unchanged 112-second bound.
`review_profile/run-1-summary.csv` records 353/353 blocks executing in 304.90
seconds, with no failures and the one pre-existing optional-package skip. The
failed first attempt remains under `fast_profile/` as detecting evidence rather
than being relabelled or deleted.
