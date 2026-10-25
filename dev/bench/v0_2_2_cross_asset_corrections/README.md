# Workstream 59 paired record

This record compares the pre-cut tree at `5f12c328` with the Workstream 59
candidate on one vendor-neutral fractional-close run. It is deliberately
small: ledgr's native hashes prove unchanged configuration and event evidence;
the record checks only the three changes owned by this workstream.

Run from the package root with R 4.6.1:

```text
Rscript dev/bench/v0_2_2_cross_asset_corrections/run_record.R <pre-tree> pre dev/bench/v0_2_2_cross_asset_corrections/evidence/pre.csv
Rscript dev/bench/v0_2_2_cross_asset_corrections/run_record.R . post dev/bench/v0_2_2_cross_asset_corrections/evidence/post.csv
Rscript dev/bench/v0_2_2_cross_asset_corrections/check_record.R dev/bench/v0_2_2_cross_asset_corrections/evidence/pre.csv dev/bench/v0_2_2_cross_asset_corrections/evidence/post.csv
```

The fixture opens `0.89101464257119367` shares and sells
`0.89101464257119356`. Before the correction, canonical position state retains
`1.1102230246251565e-16` shares after FIFO has removed its lot. After the
correction, both are exactly zero. Fill and ledger rows, cash, numeric metrics,
configuration identity and metric-context identity remain unchanged. Final
equity is allowed a maximum absolute difference of `1e-12`; the recorded
difference is zero.

The other intended differences are display-only: an omitted US-equity metric
calendar gains `(default)`, while an explicitly supplied equal calendar keeps
its label and both contexts retain one hash; and the result headline changes
from `Corporate actions` to `Economic events` without changing its fidelity
state or suffix.

`check_record.R` prints `LEDGR_WS59_RECORD_OK` only when all stable fields and
the three intended changes satisfy those boundaries.

## Optimization-shape walk

The position correction adds constant-time arithmetic to existing fill and
replay transitions. It adds no scan, query, growing accumulator, per-row data
frame, JSON operation, or environment-held user value. The disclosure changes
format already-held data; run printing reads the existing metric-context row
once on its already-open connection and does not affect the fold.
