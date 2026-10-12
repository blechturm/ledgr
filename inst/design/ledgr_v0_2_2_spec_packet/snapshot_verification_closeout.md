# Workstream 27 Closeout: Rule-3 Snapshot Verification

**Status:** Agent-provisional; implementation complete, fast gate unresolved.
**Date:** 2026-10-12
**Implementation range:** `f281066e..2bfa2be3`
**Tickets:** LDG-3019 and LDG-3020

## Outcome

New snapshots seal under the accepted portable rule-3 root. Missing markers,
rule 1 and rule 2 remain metadata-readable but refuse every complete
verification with `ledgr_snapshot_rebuild_required`; unknown future markers
retain `ledgr_snapshot_hash_rule_unsupported`. There is no migration, older
format reader, missing-marker fallback or executable old encoder.

Within one process, a complete matching verification or a successful seal
after COMMIT records a private proof keyed by snapshot store, snapshot id,
stored root and rule. Later content-dependent calls may reuse only that exact
tuple. PID change, serialization, an unstable connection path, `:memory:`, a
status failure or a hash failure cannot supply a reusable proof.

Commits:

- `028a3c57` implements LDG-3019's root, refusal boundary, golden-root
  detectors and registered-host evidence.
- `7367d28c` implements LDG-3020's verified set, complete consumer census,
  public-boundary guards, truthful metadata and failure-sensitive detectors.
- `2bfa2be3` keeps ordinary reuse in fast and places the multi-store, PID,
  memory-store and injected-COMMIT boundary matrix in review.

## LDG-3019

The production encoder reproduces all ten accepted spike roots or relations
on Windows and Ubuntu. Six schema-valid cases also pass the ordinary create,
append and seal path. Invalid fact enums remain rejected by the existing
schema and hostile order remains an encoder refusal witness; validation was
not weakened to make the corpus seal.

LTB-0249 pins the independent roots, insertion order, fetch size, threads,
block boundary and value mutation. LTB-0251 pins one fixed 10,000-row logical
block and the R-owned radix-order assertion. LTB-0250 covers missing, rule-1,
rule-2 and unknown markers. LTB-0018 deliberately pins the checked-in fixture
to its rule-3 root under the accepted synthesis.

On the registered one-thread host, complete-verification medians are 0.940,
0.940, 1.000 and 0.972 microseconds per bar at 0.5M, 1M, 2M and 5M bars. The
endpoint exponent is 1.014. Encoder-only medians are 0.820, 0.780, 0.775 and
0.778 microseconds per bar. The prepared 5M-bar process peaks at
1,072,869,376 bytes. The retained 300,000-row fact projection emits
67,750,987 bytes in 3.83 seconds and peaks at 603,635,712 bytes. Fact memory
remains the accepted later obligation; this cut does not disguise it.

## LDG-3020

The source-derived census classifies every R file naming a snapshot content
table as metadata-only, durable-result-only, snapshot-dependent, verifier,
writer or schema plumbing. It names the enclosing entries and guard. The
detector derives the source set independently and requires exact equality,
plus the required summary, facts, quarantine, sweep-open, pulse-snapshot and
indicator-tool surfaces.

LTB-0252 covers seal truth, cold and warm locators, forced validation,
different stores with the same id, split reconstruction, PID reset,
`:memory:` and COMMIT failure. LTB-0253 covers corruption and status
invalidation. LTB-0254 counts one complete hash for each fresh run, sweep,
walk-forward, fact inspection and reconstruction, with none per candidate or
fold. LTB-0256 uses a real subprocess to prove a serialized locator starts
cold.

The registered fixture used three alternating fresh-process pairs at the
same 50-instrument, 1,260-session shape as LDG-3019. All 30 gated result
families and the informational identity family are byte-identical in every
pair. Median candidate/accepted elapsed ratios are 0.928 for the momentum
run, 0.956 for readers, 0.961 for the three-candidate sweep and 0.910 for
walk-forward. Build is 1.023 because seal itself establishes the proof.

The registered ordinary long-window suite completed in 554.60 seconds and
returned `LWREG_CHECK_OK`. Its three cold ratios are 0.918 to 0.960 and its
three warm ratios are 0.904 to 0.968, all below 1.10 with exact semantic
hashes and no retry.

The private Sharadar lake is rule 2 and therefore refuses. The owning WS7
ledgr-research cut retains the one rule-3 rebuild and aggregate 26-fold post
clock. Workstream 27 neither reads it through an older format nor migrates or
reseals it.

## Mutation Record

| Mutation | Detector result |
| --- | --- |
| every ensure misses the set | LTB-0252 and LTB-0254 fail |
| PID comparison removed | LTB-0252 fails |
| split mode keyed by run connection | LTB-0252 fails |
| root mismatch retains proof | LTB-0253 fails twice |
| proof registered before COMMIT | LTB-0252 fails under injected COMMIT failure |
| rule-3 order assertion removed | LTB-0249 fails |
| legacy refusal removed | LTB-0250 fails seven assertions |

## Seven-Shape Walk

1. Rule-3 fields encode vectors inside fixed blocks; the verified set stores
   scalar tuples. Neither path constructs one-row frames and binds them.
2. Snapshot sections stream once. No table is subset inside an instrument,
   pulse, candidate or fold loop.
3. Typed fields are encoded vector-wise. The verified-set path does no
   per-row timestamp or JSON formatting.
4. Bars and instruments use typed binary fields. The existing accepted fact
   projection remains one canonical record and its memory is disclosed.
5. A complete root is computed once per fresh process boundary and reused
   only for the exact tuple. Explicit validation deliberately recomputes.
6. Ensures read one scalar envelope and one hashed-environment key. They do
   not scan prior data, runs, candidates or folds.
7. Block vectors are preallocated. The private environment grows by one
   bounded tuple per proven snapshot, resets on PID change and removes a
   matching tuple on failure. No caller-owned object is mutated.

## Gates And Review Accounting

The focused snapshot, seal, hash, fact, availability, experiment, sweep,
walk-forward, result-reader, documentation-contract and control-plane suites
pass.

One product-identical candidate record passed the ordinary fast gate with
566 of 566 blocks in 109.67 seconds. It predates only the later test-only
COMMIT-failure detector, which now runs in review. Subsequent records retained
every green block but missed the 112-second wall-time gate: 121.80, 120.70 and
114.28 seconds; 133.48, 111.34 and 123.07 seconds; and, after the heavy key and
seal matrix moved to review, 122.04, 120.89 and 124.34 seconds. An adjacent
unchanged LDG-3019 run also missed at 112.28 seconds. The broad census movement
does not isolate a Workstream 27 regression, but the failed medians are
binding and are not reported as passes. Workstream 27 is not review-ready
without a maintainer disposition or a later clean passing record.

When requested, the close review is Cut 13 invocation two over three tickets,
0.667 against the 0.5 gate. The accepted cut already records that the breach
comes from one cut review plus one close review for each of two independently
closeable workstreams; nothing is padded, merged or skipped to repair it.
