# LDG-3019 rule-3 record

Recorded on 2026-10-12 on the registered Windows host with DuckDB threads set
to one. The complete verification medians were 0.940, 0.940, 1.000 and 0.972
microseconds per bar at 0.5M, 1M, 2M and 5M bars. The log-log endpoint growth
exponent over those medians was 1.014. Both gates pass: every median is below
1.5 microseconds per bar and growth is below 1.10.

The encoder-only medians were 0.820, 0.780, 0.775 and 0.778 microseconds per
bar. At 5M rows the production encoder accounts for about 80 percent of the
complete verification clock; retrieval and orchestration account for the
remainder.

The fresh-child whole-process peak was 1,072,869,376 bytes while verifying a
prepared 5M-bar store. The retained 300,000-row fact projection emitted
67,750,987 bytes, took 3.83 seconds and peaked at 603,635,712 bytes.
These are disclosure measurements, not gates. The bar encoder retains one
fixed 10,000-row logical block; the larger process peak includes the package,
DuckDB connection and mapped snapshot database. Fact projection still
materializes its accepted single JSON record
and remains the later memory-release obligation recorded by the synthesis.

`production_cases.csv` is byte-identical to the accepted Windows and Ubuntu
spike corpus. `production_seals.csv` separately records the six cases exercised
through an unchanged real schema and seal. The all-facts corpus uses two enum
labels rejected by the production schema at the RFC baseline, and hostile
order is impossible after the seal query's `ORDER BY`; those remain production
encoder and refusal witnesses rather than weakened-schema seals.

## Seven-shape walk

1. No one-row frame is built per element and bound later. Fields encode whole
   vectors, and a fixed logical block is the collection unit.
2. No full-table subset occurs inside an instrument loop. The database streams
   each ordered section once.
3. Timestamp and numeric encoding is vectorized per field. There is no
   per-element formatting call.
4. Bars and instruments use binary typed fields, not row-wise JSON. The fact
   section deliberately retains the accepted one-record canonical projection.
5. A complete verification computes each section once. LDG-3020 owns reuse
   across public calls.
6. Ordering validation is one radix order per block plus an adjacent identity
   check. It does not compare every row pair.
7. No environment-held vector is grown by scalar writes. Block-digest storage
   and pending chunks are preallocated from row count and fixed block size.
