# Closeout: Exact Fact Integrity Verification Spike

**Status:** GREEN under charter Section 4: exact hashes and corruption failure
were preserved, and the 300,000-row exact assertion cleared the 2x gate.
**Date:** 2026-10-04
**Baseline:** `a3f54cc`, R 4.6.1, duckdb 1.5.6.9000, yyjsonr 0.1.22.

## What Ran

The runner compared the current per-row timestamp formatting with one
scratch-only distinct-value map. Each distinct non-missing instant still went
through the retained `ledgr_fact_time_token()` implementation. Three
alternating pairs measured in-memory bundles; three more measured full rule-2
snapshot-hash recomputation.

| Boundary | Rows | Current median | Candidate median | Speedup |
| --- | ---: | ---: | ---: | ---: |
| in-memory bundle | 6,000 | 0.06 s | 0.02 s | 3.00x |
| in-memory bundle | 30,000 | 0.30 s | 0.04 s | 7.50x |
| in-memory bundle | 300,000 | 3.06 s | 0.58 s | 5.28x |
| sealed rule-2 snapshot | 300,000 fact rows, 500 bars | 3.25 s | 0.73 s | 4.45x |

Every family, bundle and snapshot hash was identical. The deterministic
`bundle_*` rows record family hashes; bundle equality was enforced by
`ledgr_facts_assert()` and independently verified during review. Mutating one
membership row after construction still raised `ledgr_invalid_facts`.

## What Was Learned

The material cost is repeated POSIXct formatting inside the exact canonical
payload, not SHA-256 and not an integrity-policy requirement. Membership sets
repeat each effective and knowledge instant across hundreds of rows. Formatting
each distinct value once removes that repeated work without changing a byte of
the payload.

The checker reran the evidence, changed the first distinct token to the Unix
epoch, observed exact verification fail, byte-diffed deterministic cases and
reported `FACT_INTEGRITY_SPIKE_CHECKS_OK`. Guarded package scope was unchanged.

Independent review also measured a low-repetition bundle at 0.34 seconds on
the current path and 0.38 seconds on the candidate. That shape shows no gain,
so implementation needs a separate no-regression gate rather than treating the
membership-shaped result as universal. The reviewer also confirmed that a
one-second in-memory timestamp tamper and a persisted-table timestamp tamper
both fail exact verification.

## Consumable Result

A bounded internal ticket may replace repeated timestamp formatting in
canonical fact frames with the measured distinct-value map. Acceptance should
pin explicit family, bundle and rule-2 hashes, constructed and persisted
timestamp corruption, the 2x 300,000-row gate and a low-repetition
no-regression gate. No RFC is needed if hash bytes, schema and verification
policy remain unchanged.

This spike does not authorize trusting stored hashes, caching mutable fact
objects, changing snapshot identity or changing a hash rule. Other fact-family
shapes remain implementation-ticket witnesses rather than measured speed
claims.

Evidence and the three executor artifacts are under
`dev/spikes/fact_integrity_verification/`.
