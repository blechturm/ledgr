# Successor A0 record

This is the WS23 public-output oracle. The historical output-freeze corpus is
an integrity record of commit `20034e00`; it is not the WS23 before arm.

`record.R` runs the same eight A0 workloads with one compatibility shim:
only the `avail_incomplete` and `failures` fixtures, which omitted `opening`
before Cut 7 made it mandatory, receive the former default explicitly as
`ledgr_opening(cash = 100000)`. No product call is otherwise changed.

The immutable before record is produced from `0d6c0b11`. `compare.R` requires
the candidate to have the same 281-file set and byte-identical content except
for exactly four accepted cells: the two candidates in each of
`avail_incomplete/sweep_w1/sweep.csv` and `sweep_w2/sweep.csv` change
`annualized_return` from `"0"` to typed missing.

`record_identities.csv` binds both record arms to their exact commits and
product-tree identities. The record was regenerated at `7361951e`. Correction
`fbf90cb1` changes `R/`, and regenerating at its tree reproduces all 281 files
byte for byte. The later row-scoped subtype reader correction at `01cc546d`
changes no recorded A0 output; the committed pair still passes `compare.R`.
