# Fact-Family Scaling Note

**Status:** Measured pre-ticket finding; ticket amendment reviewed
`PASS_AFTER_PATCHES`. It is not implementation evidence.

**Baseline:** Production code at `af5bdc6`. Commit `1f3c5b8` changed packet
records only.

## Finding

Workstream 10 added `equity_corporate_actions` through the shared fact-family
plumbing. Its validator uses whole columns, but the shared identity path still
manifests and encodes one row at a time. The new family makes that latent cost
material at an ordinary equity-research scale.

The measured fixture used 100 instruments over 300 days and complete cash
distribution facts. Times are wall seconds:

| Fact rows | Constructor | Seal | Public run |
| ---: | ---: | ---: | ---: |
| 0 | -- | -- | 1.26 |
| 20,000 | 16.4 | 23.2 | 5.4 |
| 100,000 | 97.9 | 112.9 | 18.3 |

At 100,000 rows, construction plus sealing costs about 211 seconds and every
run pays about 17 seconds above the no-fact control. A long equity history can
plausibly contain 50,000 or more ordinary distributions before other action
families are considered.

## Source Shape

- `R/availability-facts.R:1051-1067` builds each family hash from a list of
  row payloads.
- `R/availability-facts.R:1237-1251` slices a data frame and emits canonical
  JSON once per row to detect identity conflicts.
- `R/availability-persistence.R:259-296` normalizes persisted tables and
  rebuilds row payloads for snapshot hash rule 2.
- `R/availability-facts.R:1253-1258` formats timestamps. Called from a
  per-row payload path, that repeats POSIX conversion and formatting.
- `R/snapshot_adapters.R:66`, `R/availability-ingest.R:5`, and
  `R/availability-persistence.R:17` each call `ledgr_facts_assert()` during
  one `ledgr_snapshot_from_df()` path. At 20,000 rows the profile showed
  three full family-hash re-encodes of about 5.5 seconds each; DuckDB append
  itself was negligible.
- `R/run-snapshot.R:41-63` deliberately recomputes the snapshot hash from
  persisted data at run start. This is the corruption detector and cannot be
  replaced by trusting the stored hash.

An R profile over 20,000 rows attributed the material time to per-row data
frame slicing, canonical JSON and timestamp formatting. The same logical
encoding is paid during deduplication, family identity, seal-time assertion
and persisted snapshot verification.

## Boundary

This is an output-preserving maintenance change only while all of these stay
true:

- existing family, bundle and snapshot hashes remain byte-identical;
- duplicate selection, ordering, error classes and condition fields remain
  unchanged;
- the run guard still derives evidence from actual persisted rows and detects
  a row changed without its stored snapshot hash changing;
- no schema, public API, fact vocabulary or hash-rule version changes.

DuckDB may read, filter and order typed rows. Rendering the bytes that enter
an identity remains R-owned. Making DuckDB's version-dependent text rendering
part of snapshot identity requires an RFC and is not a ticket option.

The run guard deliberately remains O(fact rows): it re-derives identity from
the persisted content on every run. An O(1) open based on a signed manifest,
incremental hash or verification at another boundary is a design change and
requires an RFC.

Comparing a stored hash with another stored hash is not an optimization; it
removes the corruption detector. If the measured gain requires a new hash
identity, a persisted helper column or weaker verification, implementation
stops for a separate design decision.

## Review Miss And Route

The Workstream 10 close review measured the bars-only CSV-to-snapshot path.
It did not measure construction, sealing or run startup with the new family
populated, so its registered clock could not expose this cost.

The maintainer routes the correction before Workstream 12. Workstream 14
preserves identity and corruption detection while removing row-wise fact
preparation. It depends on accepted Workstream 11; Workstream 13 is an
independent Cut 7 chore and may proceed separately. Only after Workstream 14
review is accepted does Workstream 12 open.
