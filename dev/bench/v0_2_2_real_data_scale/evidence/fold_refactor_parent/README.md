# Fold-refactor parent baseline

This is the repaired full fixture record required by LDG-3052 before any fold
body is extracted.

- Source commit: `61fd6774792dcbec0728a8bfb06842e14116c823`.
- Environment: Windows x64, R 4.6.1, default 800 instruments, 1,260
  sessions and 300 members.
- Command: `Rscript dev/bench/v0_2_2_real_data_scale/run_record.R .
  .tmp/ws38-parent-baseline --lane=fixture`.
- Result: `RECORD_OK`; 51 total family files, comprising 50 gated families
  and informational `identity`.
- Checker: `check_record.R .tmp/ws38-parent-baseline --self-test` detected
  each of the 51 independently perturbed families and no other family.
- Feature-plane witness: 1,260 rows in `momentum_feature_plane`, one per
  strategy pulse, read through `ctx$vec$feature("return_60")` over the ordered
  `ctx$universe`.
- Portability probe: two independent 20-instrument, 100-session records in
  different output directories compared 25/25 gated families and identity
  byte-identically. The output path is held outside strategy params and is
  restored after the run; params remain `{"lookback":60,"n":20}` and the
  strategy stays tier 1.

`summary.csv` and `summary_phases.csv` are the aggregate parent record that
subsequent stage commits compare against. Full families and work databases are
local scratch evidence and are not committed. `historical_summary.csv` and
`historical_summary_phases.csv` summarize the last accepted full fixture
record at `3ab97b33c353428b7b5834544483a53e6c19723b` (52 family files).

## Historical transition

The exact family-name transition is two removals and one addition:

- removed `momentum_features` and `equal_weight_features`, whose schema-119
  source table was deleted by the accepted feature-retention removal;
- added `momentum_feature_plane`, the callback-time evidence witness; it is
  not product persistence.

Of the 52 union families, 44 common families are byte-identical. The remaining
differences are fully enumerated in `transition.csv`:

- both run-info families lose `persist_features`, `feature_cache_hits` and
  `feature_cache_misses`, and report schema 120 rather than 119;
- `momentum_explain` carries the accepted identity-rule-3 feature fingerprint
  and feature-set hash;
- walk-forward candidate identities, labels, execution seeds and row order
  change with identity rule 3, while the sorted metric-value and trade-count
  multisets are exact;
- the informational identity family records the schema-120 config hashes, the
  rule-3 feature/session identities, the accepted strict-TTR availability
  engine digest and the recorder wrapper's strategy-source identity.

No unexplained economic difference remains. The old and new aggregate hashes
make this comparison durable without checking in large fixture rows.
