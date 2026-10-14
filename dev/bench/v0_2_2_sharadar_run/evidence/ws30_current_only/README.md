# WS30 Current-Only Sharadar Record

This directory contains the aggregate-only record for LDG-3031. It was
produced after every Workstream 30 format-changing commit, at ledgr commit
`b55552e322464fa9ed179e824223ca489dab4ab0` and ledgr.sharadar commit
`6be0b99e63f9feaa07f782a5bd2545c3bcccb28a`.

The documented `build` and `census` stages in
`dev/bench/v0_2_2_sharadar_run/run_record.R` created and checked a fresh
schema-119 store under snapshot hash rule 3. The complete documented
Sharadar scale lane then ran against that store. It covered the momentum and
equal-weight runs, result readers, availability and explain surfaces, a
three-candidate sweep, promotion and walk-forward.

The build used the existing vendor canonical lake. It did not rebuild or
modify that lake, migrate an older ledgr store, delete a prior ledgr store or
add the later dividend-fact mapping.

## Files

- `build_summary.csv` records native ledgr identity, current format markers,
  aggregate snapshot counts and the retained Cut 11 comparator.
- `build_stages.csv` records elapsed time and sampled peak child RSS for the
  build and census stages.
- `scale_summary.csv` records only per-family row counts and SHA-256 digests
  from the completed scale lane.
- `scale_summary_phases.csv` records the lane's aggregate phase clocks.

No vendor row, instrument identifier, private path, credential or vendor
canonical-build identifier is present. The snapshot ID and hash are ledgr's
native provenance rather than a parallel research manifest.

## Result

The fresh snapshot is SEALED at schema 119, snapshot hash rule 3 and the
recorded current format fingerprint. It contains 5,481,906 bars for 1,166
instruments over 7,213 open sessions, plus 290,811 membership rows across
580 membership sets and 829 lifetime rows. The dividend-fact mapping is
explicitly absent.

The build stage completed in 217.6 seconds with a sampled peak child RSS of
5,848 MiB. The retained Cut 11 aggregate arm recorded 359.0 seconds and
7,621 MiB, reductions of 39.4% and 23.3%, respectively. Snapshot construction
inside the current build took 204.46 seconds and the post-build complete
verification took 9.16 seconds. These are cumulative current-tree results,
not an isolated Workstream 30 effect estimate: the comparator predates the
intervening optimization and rule-3 work.

The complete scale lane succeeded. Its committed hashes are opaque aggregate
evidence only; private source rows remain in their owning environment.
