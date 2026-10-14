# Identity Ordering Census

Date: 2026-10-14  
Owner: LDG-3036  
Scope: explicit `order()` and `sort()` operations on durable identity, hash,
serialization, selection-identity and provenance paths.

The general rule is simple: `canonical_json()` recursively orders named atomic
vectors and named lists with radix ordering. Callers do not need to pre-sort
object keys. Explicit ordering that becomes array order, row order, a generated
identifier, a tie break or recorded provenance must also use radix ordering.

| Surface | Files | Disposition |
| --- | --- | --- |
| Canonical object keys | `R/config-canonical-json.R` | Both recursive named-key branches use `order(..., method = "radix")`. |
| Store fingerprint | `R/store-gate.R` | Already used radix for bindings, parsed markers and differing constants. |
| Config and inferred universe | `R/config-hash.R`, `R/backtest.R` | Feature IDs and inferred instrument IDs use radix. Explicit user vector order remains semantic. |
| Feature aliases and fingerprints | `R/feature-alias-map.R`, `R/precompute-features.R`, `R/features-engine.R`, `R/backtest-runner.R`, `R/availability-results.R` | Alias names, feature IDs, fingerprints and prepared rows use radix. Timestamp ordering remains numeric/time ordering. |
| Strategy source and dependencies | `R/determinism.R`, `R/strategy-preflight.R`, `R/parallel-workers.R` | Captured globals, symbols and package provenance use radix. Tier-priority order remains the explicit semantic order. |
| Indicator identifiers | `R/indicator-ttr.R` | Argument-name contributions to generated IDs use radix. Registry listing is radix for stable diagnostics. |
| Snapshot adapter and availability serialization | `R/snapshot_adapters.R`, `R/availability-ingest.R`, `R/availability-facts.R`, `R/availability-persistence.R` | Instrument, family, fact, provenance and column-name ordering is radix; date and numeric boundary ordering stays numeric. |
| Sweep and walk-forward identity | `R/sweep.R`, `R/sweep-retention.R`, `R/walk-forward.R`, `R/walk-forward-identity.R`, `R/walk-forward-selection.R` | Fingerprint sets, character panel labels, score rows, row JSON and candidate-key tie breaks use radix. Pulse and trade sequence ordering remains numeric/time ordering. |
| Promotion identity | `R/promotion-context.R` | Recorded condition-class sets use radix; object-key identity is covered by canonical JSON. |
| Strategy-facing feature discovery | `R/pulse-context.R`, `R/runtime-projection.R`, `R/feature-inspection.R` | Feature and instrument sets use radix for stable reads and diagnostics; table time order remains semantic. |
| Parameter, feature-cache, metric, cost, risk and objective hashes | their owning R files | Named object keys flow through canonical JSON. Numeric and declared chain order is semantic and is not re-sorted. |

The registered two-process witness uses C and a non-C collation whose ordinary
mixed-case/underscore order differs. It requires byte-identical canonical JSON
and `config_hash`; restoring locale-sensitive `order(nm)` fails it.
