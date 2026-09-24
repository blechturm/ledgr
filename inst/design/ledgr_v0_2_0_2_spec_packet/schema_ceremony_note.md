# Architecture Note: Schema Ceremony on Every Store Open

**Status:** Pre-ticket note for a maintenance cut after workstream 10.
Authority for a direct exact-parity ticket; not a design change.
**Author:** Claude. **Date:** 2026-09-24. **Route:** direct ticket, no RFC.
**Measured at:** `ea22976`, in an isolated worktree, this session. Every
number here is orientation for sizing the ticket; the ticket's own
before-and-after clock is the release evidence.

## 1. Finding

Opening a ledgr store pays two catalogue walks that scale with the schema,
not with the data. `ledgr_create_schema()` in `R/db-schema-create.R` queries
`information_schema` once per required table to decide whether to create it,
then executes every `CREATE IF NOT EXISTS` regardless.
`ledgr_validate_schema()` in `R/db-schema-validate.R` queries
`information_schema` per table for existence, columns, primary key and unique
constraints. There are 31 required tables. Traced through `DBI::dbGetQuery`
and `DBI::dbExecute`:

| Call | Catalogue queries | DDL executes | Wall |
| --- | ---: | ---: | ---: |
| create, fresh store | 95 | 69 | 0.26s |
| create, schema already present | 92 | 32 | 0.21s |
| validate | 105 | 0 | 0.33s |
| DuckDB instance start and stop, for scale | 0 | 0 | 0.045s |

This is shape 5 of `inst/design/manual/optimization_coding_style.qmd`: work
recomputed on every call whose result an identity already certifies. The
identity exists. `experiment_store_schema_version` is written last inside the
store transaction (`R/experiment-store-schema.R:698-708`) and read back in one
query (`:478-490`) against `ledgr_experiment_store_schema_version`, 115 at
`ea22976`. Neither create nor validate consults it.

## 2. Where it is paid

- `ledgr_run()`: create then validate on a store it has just opened,
  `R/backtest-runner.R:615-616`. About 0.54s and roughly 200 catalogue
  queries before any work.
- `ledgr_db_init()`: create then validate, `R/public-api.R:67`. Every reopen
  of a sealed store, including result readers.
- `ledgr_snapshot_from_df()` and `from_csv()`: create on a fresh file,
  `R/snapshot_adapters.R:270`. Genuine work on a fresh store; only the
  catalogue walk before each statement is waste.
- The promotion context and the public schema helpers, same pair.

Every user run pays this, not only the tests.

## 3. Measured impact on the test lanes

Lane clocks, per-block census, clean tree at `ea22976`:

| Lane | Blocks | Wall | Median block | Bound |
| --- | ---: | ---: | ---: | ---: |
| fast | 439 | 86.3s | 0.04s | 90s |
| review | 249 | 396.6s | 1.37s | none |
| heavy | 192 | 543.6s | 1.95s | none |

The fast lane also read 88.5s and 89.9s on the main checkout the same day;
run-to-run variance is 0.01s median per block, so the gate reading is real.
Workstream 10 is adding blocks to that lane.

Removable share, measured by gutting `validate` to an immediate return and
`create` to a skip when the schema is present, then re-running each lane:

| Lane | Untouched | Gutted | Saved | Share | Faster / slower |
| --- | ---: | ---: | ---: | ---: | --- |
| fast, 434 blocks passing both | 80.6s | 70.2s | 10.5s | 12% | 22 / 1 |
| review, 248 passing both | 395.2s | 263.0s | 132.2s | 33% | 147 / 0 |
| heavy | not run | | | a third or more, extrapolated | |

Fast's share is smallest because most fast blocks build a fresh store, where
creating the schema is real work. Review and heavy reopen sealed stores far
more often, and there validation is pure repetition. Heavy's open density is
93 percent of blocks against review's 66, so its share is expected to be at
least review's; a nine-minute run would replace the extrapolation.

## 4. A caution about sizing

A first estimate from counting store-open call sites in the test sources put
the fast saving at 30 to 51 seconds. It was wrong by three to five times.
Sites inside review or heavy blocks, helper branches not taken, and loops
counted once distort static counts in both directions. Size this by gutting
and measuring, as above; use static counts only to find candidates.

## 5. Constraints learned from what the gut broke

Five fast blocks failed under the gut, and each is a design constraint.

- Three in `test-schema.R` drop a table and expect validation to reject the
  store. Detection of out-of-band schema damage must survive the fix.
- Two in `test-experiment-store-schema.R` migrate an older store. The gut
  skipped create on "a table exists" and left `ledgr_schema_metadata` and a
  newer column absent. **The skip condition must be the stored schema version
  equal to the current one, never the presence of a table**, or migration
  silently stops.

## 6. Fix shape

Two changes, both output-preserving.

1. **One catalogue read, compared in memory.** Fetch `information_schema`
   tables, columns and constraints for the schema once per call into R
   frames, and have the per-table helpers filter those frames. The loops and
   every check stay as they are. Validation still detects a dropped table or
   column; it issues about three queries instead of 105. Create issues its
   existence checks from the same frames instead of 92 queries.
2. **Version-marker fast path, for the reopen case only.** When
   `ledgr_schema_metadata` holds the current version, `create` has nothing to
   do and may return after that one read. Validation keeps running in full,
   because the marker cannot certify that no table was dropped afterwards;
   it is cheap once change 1 lands.

Everything a caller can observe is unchanged: same tables, columns,
constraints, errors, classes, messages, hashes and run outputs. That makes
this a candidate for
`inst/design/exact_parity_internal_optimization_proof_template.md`, like the
pulse-context accessor chore.

Not the lever: parallel test execution. The runner is serial by design and
the maintainer's standing rule is single-core first. The waste is in the
package, and users pay it too.

## 7. Ticket scope

**In:** `ledgr_create_schema()`, `ledgr_validate_schema()`, and any private
helper they own. A registered detector that fails if a per-table catalogue
query is reintroduced, in the style of the source guards from cut 4. A
before-and-after clock on `ledgr_run()` open, on `ledgr_db_init()`, and on
the fast and review lanes, interleaved, named cold or warm per
`spike_protocol.md` section 10.

**Out:** the callers, the schema itself, the migration logic, the version
marker's meaning, snapshot hashing, and every test lane's fixture shape. The
test-side double open in `csvc_seal` (from_csv then db_init on the same path)
is legitimate: the helper inspects the sealed store.

**Review:** Type 1 at close, under the packet's review obligations as amended
2026-09-24: walk the diff against the seven shapes, and accept only with the
interleaved measurement in hand.

## 8. Evidence provenance

Per-block censuses for all three lanes and both gut runs were produced by
`tools/run-test-profile.R --records=` in this session and are not committed;
their headline numbers are above. The ticket regenerates them. The
microbenchmarks used closures, not promises, after a first attempt that
returned zeros through promise caching.
