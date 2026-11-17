# LDG-3253 commands

`S = C:/Users/maxth/ledgr-wt/ws41-scratch`; the tree is this worktree at
45df6928 (the final feature-path code: LDG-3250, LDG-3251 and LDG-3253; the
candidate-5 change reverted).

Census walk and replacement proof (census_walk.csv, census_proof.csv,
census_counts.csv, census_check.txt):

    Rscript dev/feature_parity/census.R --source=<ws41> --out=dev/feature_parity/evidence/ldg3253 --census=dev/feature_parity/census.csv

Negative controls (census_negative.txt): the same check on three corrupted
copies of census.csv, each required to fail: a dropped row
(ledgr_history_lifetime_segments), a falsely claimed engine binding
(ledgr_history_feature_evidence) and a false exclusion of a bound helper
(ledgr_history_lifetime_segments).

Reconciliation with the measuring step's census (census_reconciliation.csv/.txt):

    Rscript dev/feature_parity/census_reconcile.R --probe=dev/spikes/feature_stage1_probe/results/census.csv
      --final=dev/feature_parity/census.csv --out=dev/feature_parity/evidence/ldg3253/census_reconciliation.csv

Engine-version cost (scratch, on the cut base's installed library and the
working tree): `ledgr_feature_engine_version()` timed over 50 calls.

Old precompute, stored sweep and run (decision 6): dev/feature_parity/identity.R
and identity_check.R, recorded under LDG-3255 (evidence/ldg3255/identity_*).

Targeted suites (load_all): feature-engine-census, fingerprint-stability,
strict-feature-acceleration, strict-ttr-cleanup, features,
precompute-features, history-integration, indicator-history, indicator-ttr.
