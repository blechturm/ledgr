# WS39 schema-120 private-lake rebuild

This is the aggregate-only LDG-3055 record from the final Workstream 38 tree.
The existing public adapter and ledgr APIs were sufficient: no research-side
manifest, schema, validator, reconstructed strategy context, migration, or
legacy reader was added. The only direct SQL against the new store is
read-only aggregate inspection of its current format markers, its fact counts,
and the LFB-021 lifetime-count workaround.

The documented `ws39_record.R` command completed from a fresh destination at
ledgr commit `043a5ce128493a3906c70cf40b09137cb8494ddc` and pinned adapter
commit `6be0b99e63f9feaa07f782a5bd2545c3bcccb28a`. It read the frozen qualified
canonical build under adapter policy
`sharadar_ledgr_snapshot_adapter_v003`. The resulting native snapshot is
`snapshot_20261015_192255_63d4`, SEALED under rule 3 with content hash
`c5b4f12f6ec60e34de1b602c08a2cf3fb2619c35ba0fdf50d536e9d26c4433fc`.
The successful harness was committed afterward, unchanged, at `7c9edee4`.
Two earlier fresh attempts stopped only on recorder assertions; their stores
remain untouched and were never opened as inputs to this accepted record; they
are not evidence inputs.

Public schema validation and an explicit fresh-process `verify = TRUE` open
passed. The store records schema 120, identity rule 3, and the exact current
format fingerprint. The build took 211.7 seconds at 5,757 MiB externally
sampled peak child RSS; native snapshot construction was 201.03 seconds and
the explicit rule-3 verification was 8.72 seconds (10.8 seconds for its whole
stage). The host record is Windows 10 x64 x86-64 with R 4.6.1 and DuckDB
1.5.6.9000. The adapter lake and aggregate-inspection connections were pinned
to one thread; ledgr's public store path used DuckDB's recorded 24-thread
default.

The snapshot has 5,481,906 bars, 1,166 instruments, 7,213 open sessions,
290,811 membership assertions in 580 complete sets, 829 lifetime rows, and
three declared fact families over the requested
1998-01-02T21:00:00Z--2026-09-04T20:00:00Z window. The first and last observed
bar dates are 1998-01-02 and 2026-09-04. All six counts and the snapshot hash
match the independent checked-in LDG-3036 schema-119 aggregate record. This
run independently projects only bars, instruments, and first/last dates from
the frozen canonical lake; sessions, membership, lifetime, and the snapshot
hash are not independently projected by the WS39 reconciliation. The prior
CSV was compared as evidence; its store was never opened.

The intended current-format and identity differences are exactly those
accepted by LDG-3050: schema 120 has no `features` table or three retired
feature persistence/cache telemetry columns, and identity rule 3 replaces
rule 2. No snapshot content changed, so the rule-3 snapshot hash remains
exact. Dividend fact mapping remains absent and stays routed to the later
dividend-facts rebuild.

Two fresh-process flat-hold probes each ran 25 pulses to `DONE` on the same
snapshot ID and hash. The first uses all snapshot instruments with
`universe = NULL`; because the snapshot declares availability facts, this is
the accepted full-membership shape on the availability path, not the frozen
legacy dense runner. The second uses the dynamic membership universe rule.

`build_summary.csv` records native identity, aggregate provenance, format,
counts, clocks, host, and thread settings. `stages.csv` records parent-sampled
wall time and peak RSS. `experiments.csv` records only native run identities
and aggregate result counts. `reconciliation.csv` records the aggregate
current/source/prior comparisons in thirteen rows, explicitly marks the five
values not independently projected here, and records the identity-rule change
plus the two intended schema deletions. No private path, source row, instrument
or universe identifier, or credential is present in this directory.
