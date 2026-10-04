# Fact integrity verification probe findings

**Date:** 2026-10-04
**Status:** prerequisite probe; binds nothing.

The Workstream 9 record attributed 3.80 seconds of a 300,000-row in-memory
membership resolution to `ledgr_facts_assert()`. Source inspection located a
specific repeated cost: canonical fact frames call `ledgr_fact_time_token()`
over every timestamp even when 500 rows share each effective and knowledge
time.

`probe.R` replaced only that formatting step with a distinct-value map. On a
30,000-row membership family, the current exact assertion took 0.31 seconds
and the candidate took 0.06 seconds, a 5.17x speedup. The stored family hash,
recomputed family hash and bundle hash remained identical.

This is sufficient to charter a bounded exact-verification spike. It does not
authorize trusting a stored hash, changing the hash rule, changing snapshot
identity or caching a mutable R object as verified.

