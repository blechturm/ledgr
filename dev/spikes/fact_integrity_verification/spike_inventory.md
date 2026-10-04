# Exact fact-integrity spike inventory

## Demoted

- Reusing a stored family hash was demoted before implementation. It does not
  verify that an R fact object still contains the rows that produced the hash.
- Changing the hash rule was demoted to the snapshot-verification RFC. It is
  unnecessary for the measured candidate.

## Deleted

- No cache, schema column, registry, alternate serializer or DuckDB hash path
  was added to the spike.

## Learned

- The repeated work is timestamp formatting inside the existing exact
  canonical payload, not SHA-256 arithmetic.
- Membership snapshots repeat effective and knowledge instants hundreds of
  times. Formatting each distinct instant once preserves the payload exactly.
- The same helper is reached by in-memory family assertion and rule-2 snapshot
  hashing, so one bounded internal repair can benefit both boundaries.

## Gut

The gut replaces the first distinct timestamp token with the Unix epoch. The
stored family hash then fails validation and the deterministic case CSV
changes. This proves the evidence depends on the candidate mapping rather than
on a narrated timing result.
