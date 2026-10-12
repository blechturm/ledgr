# Rule-3 snapshot verification evidence

This directory owns the vendor-neutral LDG-3019 and LDG-3020 measurement
surface. It does not contain private vendor rows.

`run_conformance.R <output-directory>` compares the production rule-3
encoder with the accepted spike oracle for all ten corpus cases, then runs
the schema-valid subset through the real create, append and seal path. The
numeric-edge case contains a missing multiplier but is otherwise sealable.
The accepted fact case deliberately uses enum labels that the production
schema has never accepted, and the hostile-order case deliberately bypasses
database ordering. They remain encoder and refusal witnesses; the harness
does not weaken validation to make them seal.

`run_performance.R <output-directory>` records three one-thread verification
times at 0.5M, 1M, 2M and 5M bars, the encoder-only share, and fresh-child RSS
for a 5M-bar verification and the retained 300,000-row fact projection. The
timing includes DuckDB retrieval and rule-3 encoding. The fresh-child RSS is a
conservative whole-process peak: it includes construction of the synthetic
store as well as verification or fact projection.

The accepted LDG-3019 record is in `evidence/ldg3019/`. The registered cost
gate is the median microseconds per bar (at most 1.5) and the log-log endpoint
growth exponent (at most 1.10) on the fixed Windows host with DuckDB threads
set to one. RSS is disclosed, not gated.

The agent-provisional LDG-3020 record is in `evidence/ldg3020/`. It compares
accepted rule-3 commit `028a3c57` with process-local reuse commit `7367d28c`
in three alternating fresh-process pairs, records exact fixture-family
identity, and carries the registered long-window summary and checker result.
The private rule-2 Sharadar lake is not migrated, resealed or read by this
record.

`fixture_families.csv` and `fixture_phases.csv` are the aggregate-only
vendor-neutral fixture record after LDG-3019. The private rule-2 Sharadar lake
must refuse and is not migrated or resealed by this cut; its rule-3 rebuild
and the requested 26-fold post clock stay with the owning ledgr-research WS7
lake rebuild.

Run the production conformance and performance records from the repository
root, then check the committed record:

```text
Rscript dev/bench/v0_2_2_snapshot_hash_rule3/run_conformance.R <output-dir>
Rscript dev/bench/v0_2_2_snapshot_hash_rule3/run_performance.R <output-dir>
Rscript dev/bench/v0_2_2_snapshot_hash_rule3/check_record.R <output-dir>
```

The fixture files were produced by the existing vendor-neutral real-data
runner and summarizer in `dev/bench/v0_2_2_real_data_scale`; their before
arms are the accepted long-window record and `evidence/sharadar_pair` named
by LDG-3019. The post private-lake arm is intentionally absent because its
rule-2 store must refuse rather than be migrated.
