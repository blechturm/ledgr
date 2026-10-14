# WS30 Locale-Stable Identity Sharadar Record

This directory contains the aggregate-only LDG-3036 repeat of the LDG-3031
research-store build and Sharadar lane. It was produced at ledgr commit
`c566e4338e640926091109e13398fc35f52f6fae` and ledgr.sharadar commit
`6be0b99e63f9feaa07f782a5bd2545c3bcccb28a`.

The documented build and census stages created a fresh schema-119 store under
snapshot hash rule 3 and the final 21-member format fingerprint. The new
member is `ledgr_canonical_json_rule_version = 1L`. The existing vendor
canonical lake was read without rebuilding or changing it. No prior ledgr
store was migrated or deleted, and the later dividend-fact mapping is absent.

The snapshot is SEALED with 5,481,906 bars, 1,166 instruments with bars,
7,213 open sessions, 290,811 membership rows in 580 sets and 829 lifetime
rows. Its content hash is unchanged from LDG-3031 because the package-format
fingerprint is not snapshot content.

The build took 213.4 seconds at 5,987 MiB sampled peak child RSS. Snapshot
construction took 200.67 seconds and complete post-build verification took
9.18 seconds. The LDG-3031 record was 217.6 seconds at 5,848 MiB. These are
repeatability context, not an effect estimate for the identity correction.

The complete scale lane then ran momentum, equal-weight, both reader passes,
availability, explain, a three-candidate sweep, promotion and walk-forward.
It retained the same row counts in all 38 families as LDG-3031. Thirty-five
family hashes are identical. Only `momentum_run_info`,
`equal_weight_run_info` and `snapshot_info` change, because those public
records expose the intentionally changed format fingerprint. Fills, ledger,
equity, returns, features, diagnostics, strategy state, trades, metrics,
sweep results, promotion results and walk-forward results remain identical.

`build_summary.csv` contains native ledgr identity, current format markers,
aggregate counts and phase clocks. `build_stages.csv` contains aggregate time
and peak RSS. `scale_summary.csv` and `scale_summary_phases.csv` contain only
family row counts, SHA-256 digests and phase durations. No private row,
instrument identifier, universe identifier, path, credential or vendor
canonical-build identity is committed.
