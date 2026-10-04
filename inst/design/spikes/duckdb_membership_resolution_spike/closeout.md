# Closeout: DuckDB Membership Resolution Spike

**Status:** RED after independent review. The six recorded fixtures and timing
gate passed, but a tied-clock, mixed-case set-ID counterexample was not exact
because DuckDB byte ordering chose a different complete-set boundary from the
retained R resolver's locale ordering.
**Date:** 2026-10-04
**Baseline:** `a3f54cc`, R 4.6.1, duckdb 1.5.6.9000.

## What Ran

Both arms accepted the same sealed snapshot and performed the ordinary full
snapshot-hash verification. The current arm used public
`ledgr_facts_resolve()`. The scratch arm asked DuckDB for the last complete set
and later set rows plus applicable set-less assertions, then called the
retained R resolver. Three alternating pairs ran for explicit instruments and
the full universe.

| Set rows | Current explicit | SQL explicit | Current full | SQL full |
| ---: | ---: | ---: | ---: | ---: |
| 6,000 | 0.18 s | 0.16 s | 0.19 s | 0.15 s |
| 30,000 | 0.67 s | 0.64 s | 0.65 s | 0.65 s |
| 300,000 | 6.36 s | 3.84 s | 6.33 s | 3.89 s |

At 300,000 rows the speedups were 1.66x and 1.63x. The final 50,000 of 300,000
set rows crossed into R. Rows and evidence were exact in all six cases,
including changing complete-set composition, explicit unknowns and compatible
set-less overrides. They did not cover the tied-order counterexample.

## What Was Learned

SQL is not a universal improvement. At 30,000 rows the only complete set was
the first, so all history remained relevant and the arms were equal. The gain
appears when a later complete set makes earlier set rows irrelevant to the
public result.

The candidate does not need a second resolver, new schema or new index, but its
boundary must be selected under the retained R resolver's ordering. The
original gut chose the first complete set and then changed later headers; that
tested mutated data rather than the dangerous too-late boundary. Independent
review also found that the scratch arm omitted the public SEALED-status guard
and that guarding `inst/design/` made concurrent planning edits a false scope
failure.

## Consumable Result

This record does not authorize a ticket. The corrected harness orders eligible
headers in R, carries the public SEALED guard, adds the tied mixed-case case,
uses a too-late gut and narrows its scope guard. It must be rerun after the
exact-verification implementation. That rerun should compare one candidate
path at all measured sizes; it must not add a small-history fallback unless an
actual regression justifies a second path.

The regenerated baseline record returned exact results for all eight ordinary
cases and 1.64x explicit and 1.61x full-universe speedups at 300,000 rows. A
separate too-late gut made all six scale cases and both tied cases non-exact.
Those clocks do not replace the required post-verification rerun.

The corrected baseline record returned exact results for all eight ordinary
cases and 1.64x explicit and 1.61x full-universe speedups at 300,000 rows. A
separate too-late gut made all six scale cases and both tied cases non-exact.
Those clocks do not replace the required post-verification rerun.

No RFC is needed unless implementation requires a schema, index, identity,
verification-policy or authoritative-resolver change. In-memory fact families
remain an R path.

Evidence and the three executor artifacts are under
`dev/spikes/duckdb_membership_resolution/`.
