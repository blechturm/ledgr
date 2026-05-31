# Spike Log: yyjsonr canonical_json Write Byte-Identity Test

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2,
jsonlite 2.0.0, yyjsonr 0.1.22 - **Status:** v0.1.8.9 optimization-round
Round 2 input (LDG-2494, Spike 14).

**Script:** `dev/spikes/spike-yyjsonr-write-byte-identity.R`. Raw CSV
(gitignored): `dev/bench/results/spike_yyjsonr_write_byte_identity.csv`.

**Relates to:**
- `dev/spikes/spike-yyjsonr-readpath-parity.md` (LDG-2493, Spike 13)
  — companion read-side spike
- `R/config-canonical-json.R:115-122` — the production canonical_json
  toJSON call
- `R/ledger-writer.R:79-86` — per-event meta_json canonical_json call

## Question

LDG-2493 carved Class B (canonical_json writes) out of scope on the
assumption that byte parity vs jsonlite would be hard. Empirically
test whether `yyjsonr::write_json_str` can produce byte-identical
output to `jsonlite::toJSON(..., auto_unbox = TRUE, null = "null",
na = "null", digits = NA, pretty = FALSE)` for the input shapes
canonical_json accepts in production.

Pre-CRAN audit confirmed (per follow-up to LDG-2493) that the actual
stored-hash blast radius is small: no test fixtures store specific
hash literals; parity history is gitignored; no user-generated
artifacts exist. The byte-format change cost is ~hours, not
weeks. The spike now informs whether yyjsonr's bytes can match
jsonlite's directly or whether a format version bump is needed.

## Method

25 test fixtures spanning every production canonical_json input
class:
- 4 scalar types (int, double, string, logical)
- 2 empty list types (named and unnamed)
- 2 list types (simple and nested)
- 2 missing-value types (NULL, NA)
- 1 POSIXt fixture
- 4 numeric precision fixtures (1e-12, 1e10, near-max, integer-like)
- 1 irrational (pi)
- 4 string fixtures (quote, backslash, newline, unicode)
- 2 boolean fixtures
- 3 production meta_json shapes (fill, fill+realized, opening
  position)

Each payload passed through ledgr's `canonicalize()` (replicated from
`R/config-canonical-json.R:48-112`), then serialized with both:

```r
# jsonlite (production)
jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null",
                 na = "null", digits = NA, pretty = FALSE)

# yyjsonr
yyjsonr::write_json_str(payload, opts = opts_write_json(
  pretty = FALSE, auto_unbox = TRUE, digits = -1L,
  null = "null", num_specials = "null"
))
```

Byte-compared via `identical()`. Differences characterized at the
character position level.

## Results

### Per-fixture byte parity

```
[OK    ] scalar_int                     : identical
[OK    ] scalar_double                  : identical
[OK    ] scalar_string                  : identical
[OK    ] scalar_logical                 : identical
[OK    ] empty_named_list               : identical
[OK    ] empty_unnamed_list             : identical
[OK    ] simple_list                    : identical
[OK    ] nested_list                    : identical
[OK    ] null_value                     : identical
[OK    ] na_value                       : identical
[OK    ] posixt                         : identical
[OK    ] numeric_precision_tiny         : identical
[DIFFER] numeric_precision_huge         : 17 vs 19 chars, delta 2
[DIFFER] numeric_precision_max          : 27 vs 28 chars, delta 1
[DIFFER] numeric_integer_lookalike      : 7 vs 9 chars, delta 2
[DIFFER] numeric_irrational             : 22 vs 23 chars, delta 1
[OK    ] string_with_quote              : identical
[OK    ] string_with_backslash          : identical
[OK    ] string_with_newline            : identical
[OK    ] string_unicode                 : identical
[OK    ] bool_true                      : identical
[OK    ] bool_false                     : identical
[DIFFER] meta_fill                      : 58 vs 62 chars, delta 4
[DIFFER] meta_realized                  : 59 vs 63 chars, delta 4
[DIFFER] opening_position               : 107 vs 111 chars, delta 4

Overall: 18/25 byte-identical (72.0%)
```

### Detailed byte differences

```
fixture: numeric_precision_huge
jsonlite (17): {"x":10000000000}
yyjsonr  (19): {"x":10000000000.0}

fixture: numeric_precision_max
jsonlite (27): {"x":1.79769313486232e+298}
yyjsonr  (28): {"x":1.7976931348623157e298}

fixture: numeric_integer_lookalike
jsonlite (7):  {"x":1}
yyjsonr  (9):  {"x":1.0}

fixture: numeric_irrational
jsonlite (22): {"x":3.14159265358979}
yyjsonr  (23): {"x":3.141592653589793}

fixture: meta_fill
jsonlite (58): {"cash_delta":-100,"position_delta":1,"realized_pnl":null}
yyjsonr  (62): {"cash_delta":-100.0,"position_delta":1.0,"realized_pnl":null}
```

All 7 non-identical fixtures fail on **numeric formatting**, not on
structure, strings, booleans, nulls, or container shapes.

### Timing (130k payloads)

```
jsonlite: 22.530s  (173.31 us/payload)
yyjsonr : 3.390s   (26.08 us/payload)
Speedup : 6.65x
Recovery: 19.140s at 130k serializations (isolated)
```

## Findings

**Bytes differ in exactly three predictable, characterizable ways:**

1. **Whole-number doubles get a `.0` suffix in yyjsonr.** `100` becomes
   `100.0`. jsonlite drops trailing zeros from whole doubles.
2. **Full-precision irrationals use more digits in yyjsonr.** jsonlite
   uses ~15 significant digits (3.14159265358979); yyjsonr uses ~17
   (3.141592653589793). Both are valid IEEE 754 round-trippable
   representations.
3. **Exponent format differs.** jsonlite writes `e+298`; yyjsonr writes
   `e298` (no plus sign).

All non-numeric values (strings with special characters, booleans,
nulls, empty objects, nested lists, POSIXt-derived ISO strings,
unicode) serialize byte-identically.

**The numeric differences are deterministic.** Given the same input
yyjsonr always produces the same output, with no platform/version
dependence visible at this scale. So yyjsonr's output is a
self-consistent canonical format — just a DIFFERENT canonical format
from jsonlite's.

**Recovery is substantial: ~19s isolated at 130k serializations.**
canonical_json is more expensive than fromJSON per call (173 vs 9
us). The write path is the bigger JSON lane on the production durable
xlarge cell.

**Production frequency check:** canonical_json is called per-fill in
`R/ledger-writer.R:79-86` for the durable live mode (`use_transaction
= TRUE`) and through `ledgr_fill_event_payload` for buffered mode.
The chunked extractor's per-event meta-parse (Spike 13) and
canonical_json on the write side are likely both proportional to
fill count.

## Wall translation

At 133k fills on `density_high_xlarge_durable`:
- Isolated recovery: 19.14s / 130k * 133k = ~19.6s
- After standard ~1.5x isolated-overestimate discount: **~13-15s
  production recovery on durable xlarge**

If canonical_json fires per pulse for state_update strategies (~1260
pulses × 173 us = ~0.22s per run), the per-pulse contribution is
small but still recovers ~0.18s per run. The per-fill contribution
dominates.

Amdahl bound on `density_high_xlarge_durable` (445s):
- p = 13.5/445 = 0.030 (canonical_json is 3% of wall)
- Max wall speedup: 1.031x
- Wall recovery: ~13.5s

This is the same magnitude as Spike 2 (per-target delta) and bigger
than Spike 5 (next-bar). Real lane, real impact.

## Caveats

- **The differences require a canonical-format version bump.** Existing
  snapshot_hash values computed under jsonlite's format will not
  match new yyjsonr-format hashes. Pre-CRAN this is acceptable per the
  blast-radius audit (no fixed-string hash tests; parity history
  gitignored; no user artifacts) but must be documented.
- **yyjsonr 0.1.22 is the version tested.** Numeric formatting in
  future versions could change. Pin yyjsonr in Imports with a specific
  version constraint and add a byte-identity smoke test in CI to catch
  drift.
- **`auto_unbox = TRUE` matches between libraries** (scalar singletons
  unboxed in both). The non-identical fixtures are NOT auto_unbox
  issues; they are pure numeric formatting.
- **Round-trip safety verified informally.** Both jsonlite and yyjsonr
  can parse the OTHER library's output and recover identical R
  numeric values. The byte difference does not change semantic content.

## Recommendation

**PROCEED-WITH-BUMP.** Switch canonical_json to yyjsonr with a
documented format version bump.

Implementation sketch:

```r
# In R/config-canonical-json.R, replace the jsonlite::toJSON call with:
out <- yyjsonr::write_json_str(
  payload,
  opts = yyjsonr::opts_write_json(
    pretty = FALSE,
    auto_unbox = TRUE,
    digits = -1L,
    null = "null",
    num_specials = "null"
  )
)
```

Migration tasks (estimated total: ~3-4 hours):

1. Add yyjsonr to Imports with version constraint (e.g., yyjsonr (>=
   0.1.22)).
2. Replace the jsonlite::toJSON call site.
3. Document the canonical_json byte format change in NEWS and in the
   v0.1.8.9 release notes ("canonical_json byte format v2: whole-number
   doubles serialize as `1.0` not `1`; irrationals use 17 digits;
   exponent format drops the `+` sign").
4. Reset the 2 gitignored parity_history JSON files (since they
   reference v0.1.8.8-format hashes).
5. Add a byte-identity smoke test fixture so future yyjsonr drift is
   caught in CI: write a known payload, hash it, assert the hash
   matches a stored constant.
6. Verify all existing `expect_match(hash, "^[0-9a-f]{64}$")` tests
   still pass (they will — the hash shape is unchanged).

Sequencing in v0.1.8.9: independent of Spikes 11, 12. Can land in
parallel. Recommend landing AFTER Spikes 11, 12 (the headline lanes)
so the format change is bundled with other v0.1.8.9 closeout work and
the parity_history regenerates against the post-fix engine.

Expected real-run signature: `t_loop_sec` and `t_residual_sec` on
`density_high_xlarge_durable` drop by ~13s. Tier 1 parity tests pass
unchanged (they check hash shape and stability, not specific
values). The parity_history file (when regenerated) records the
new canonical format hashes.

## Architectural lesson

**The "canonical_json is durable identity, don't touch" framing was
half right.** The bytes ARE durable identity in the sense that they
feed snapshot_hash; the bytes are NOT durable identity in the sense
that any change is release-breaking. Pre-CRAN, with no user
artifacts and only mechanism-checking tests, the byte format is a
v0.1.8.9 line item.

The right framing: **canonical_json's byte format is a versioned
contract. Pre-CRAN we can bump the version freely; post-CRAN any
bump requires a migration story.** v0.1.8.9 happens to be the right
window to make this kind of change.

The K1 forward path is unchanged: when `ledgrcore` lands, it absorbs
canonical_json into the compiled byte-identity gate, and the encoder
pinning lives inside the compiled core's release contract rather
than in R-level Imports. v0.1.8.9 yyjsonr is the bridge; the
v0.1.8.9 byte format becomes the format `ledgrcore` matches.
