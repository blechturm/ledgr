# Response Review: Snapshot Verification Policy for v0.2.2

- Role: Codex, seed v1 author
- Date: 2026-10-12
- Status: Response review complete; seed v2 is next
- Baseline reviewed: `1c8df889`
- Current relevant source: unchanged through `0ac5bd10`

This review verifies the response rather than defending seed v1. It changes no
production code, contract, ticket or accepted decision.

## 1. What Ran

Source review covered the locator and held-store lifecycle, config
construction, run guard, adapters, sweep and walk-forward paths, inspection,
result readers, quarantine hashing, interactive tools and derived-state entry
points cited by the seed and response.

Environment: R 4.6.1 ucrt, duckdb 1.5.6.9000 and digest 0.6.39 on Windows.

Three independent probes ran outside the repository:

1. A field added to a snapshot-shaped private environment remained visible
   through an ordinary R copy and survived `saveRDS()` / `readRDS()`.
2. Under `English_Austria.utf8`, default R ordering of `b, B, a, A` was
   `a, A, b, B`; radix, C-locale and DuckDB ordering were `A, B, a, b`.
3. A 500,000-row ordered-bar probe measured 4.82 seconds for current-shaped R
   text, 0.28 seconds for block-bounded R binary and 0.37 seconds for DuckDB
   typed text at one thread. Fresh-process R-binary clocks at 0.5, 1, 2 and
   5 million rows were 0.25, 0.56, 1.08 and 2.89 seconds. The endpoint
   exponent was about 1.06 and cost stayed near 0.5 to 0.6 microseconds per
   row. These clocks confirm direction, not production hash bytes.

No private Sharadar rows or `E:/ledgr-data` were read. The concurrent schema,
derived-state, test and planning edits were not touched.

## 2. Overall Judgment

`REVISE_SEED` is upheld. The response correctly preserves the seed's two-part
architecture while replacing two weak choices:

- use one cadence-neutral complete root, with no calendar components; and
- reuse a completed proof inside one process, but do not carry that proof in a
  serializable locator environment.

The proposed R-defined binary rule is the better v1 candidate. The verified
set is the better carrier. Neither should be copied into seed v2 without the
corrections below.

## 3. Finding Reconciliation

### F1: lease carrier - ACCEPT WITH ONE REQUIRED CORRECTION

The response is right that the locator is the wrong carrier.

- `ledgr_config()` retains path, snapshot ID and stored hash, not the locator.
- `ledgr_run_fold()` opens its own connection and calls the guard with config
  fields.
- adapters seal through a connection and then construct a fresh locator;
  pulse inspection constructs another dedicated locator.
- `ledgr_state_reconstruct()` accepts a raw connection.
- the locator's private environment is shared by R copies and serializes.

A namespace-level verified set keyed by normalized store path, snapshot ID,
root and rule fits the actual call graph and resembles `.ledgr_held_stores`.

The response's statement that a worker process starts empty is not a complete
process boundary. ledgr's supported mirai workers load a fresh package and do
start empty, but an R fork can inherit a namespace environment. Seed v2 must
associate the registry with a process-generation token, at minimum the PID
checked on every lookup, and clear it when that token changes. The registry
must never be serialized into an experiment or worker payload.

Locator close does not clear this registry. That widening is deliberate:
another locator for the same store, ID, root and rule in the same process may
reuse the proof. A changed root or rule misses the key; a failed verification
invalidates the matching entry.

### F2: binary encoding - ACCEPT, NARROW THE CERTAINTY

Both the prior 630,000-row observation and this independent probe support
R-binary as the first candidate. It is materially faster than current text and
slightly faster than one-thread DuckDB text at the smaller independent shape.
It also avoids making rule 3 depend on DuckDB formatting.

Binary is not "exact by construction" until the contract freezes:

- field, row, section and block framing;
- byte order and fixed widths;
- UTF-8 normalization and string lengths;
- timestamp unit and representation;
- the retained eight-decimal numeric normalization;
- negative zero, missing values and forbidden non-finite values; and
- final block-combination and digest rules.

Seed v2 may recommend this representation, but the Windows/Linux golden corpus
remains a pre-ticket gate. The fact section may reuse the normalized rule-2
schema and canonical JSON representation only after the ordering defect in F3
is removed; it cannot claim wholesale byte reuse of the present payload.

### F3: locale-dependent fact ordering - ACCEPT

`ledgr_snapshot_availability_hash_payload()` uses default `order()` over
quarantine keys and table names. The probe reproduced a different mixed-case
order under the session collation than under radix, C locale and DuckDB.

Rule 3 must bind bytewise order after UTF-8 normalization for every section,
row and name. The hostile corpus needs a mixed-case quarantine witness and at
least one non-ASCII witness. This correction belongs in rule 3; old executable
rules are being refused rather than silently repaired.

### F4: content-consuming surfaces - ACCEPT THE CENSUS, REJECT THE SHORTCUT

The seed's usage table is incomplete. The response correctly finds snapshot
reads in result metrics, availability marks, corporate-action reports,
quarantine and interactive tools. The source census also finds relevant reads
in experiment construction, snapshot listing, precomputation and
walk-forward-window preparation. The ticket cut needs a source-derived census,
not a hand-maintained list copied from either artifact.

The response's proposed reporting rule is unsafe as written. Comparing a
stored root with the root recorded in a result proves identity metadata only;
it does not prove that the rows about to be read still match that root.
`ledgr_estimate_bars_per_year()` reads bars that alter metrics, and
availability and corporate-action helpers read bars that alter reported values.

Seed v2 must use three classes:

1. metadata-only reads may proceed unverified but must not claim verification;
2. durable-result-only reads need no snapshot proof when they read no snapshot
   content; and
3. any operation whose output depends on snapshot rows ensures the verified
   set, unless the required derived value is made durable and the snapshot read
   is removed.

`ledgr_sweep_save()` is not itself a content read; its stored-root comparison
is sufficient for attaching an already-computed sweep to the identity it
records. `ledgr_sweep_open()` does read the snapshot universe and therefore
falls in class 3 unless that universe is persisted with the sweep.

### F5: two implementation levers - ACCEPT

The new hash and proof reuse should be distinct, ordered implementation
tickets under one accepted policy:

1. define and implement rule 3 while retaining complete verification at every
   current guard; then
2. add the process-local verified set and remove duplicate verification.

This preserves a useful fast-hash result even if the reuse mechanism fails its
review. It does not authorize either ticket before synthesis and the rule-3
conformance gate.

### F6: performance gates - ACCEPT THE DIMENSIONS, REVISE THE NUMBERS

Absolute per-row cost, growth and peak memory are better primary gates than a
percentage of an arbitrarily expensive strategy. End-to-end run and
walk-forward clocks should remain supporting product evidence.

The response's exact exponent of 1.05 across 0.5 to 50 million rows is not yet
supported. This review's simpler 0.5-to-5-million probe measured about 1.06,
and the ordered database query may sort more than one fetch block even though
the R encoder is block-bounded.

Seed v2 should propose evidence-backed provisional gates of at most one
microsecond per bar for the base payload and an exponent no greater than 1.10,
then require the registered probe to confirm or return them before tickets.
It must distinguish the R encoder's bounded block from whole-process peak RSS,
including DuckDB ordering and the fact payload.

### F7: legacy refusal - ACCEPT

Package fixtures are rebuilt from source, no DuckDB snapshot is shipped, and
the maintainer has no research corpus requiring executable compatibility.
The rule marker becomes mandatory. The current missing-marker fallback to rule
1 must not survive. Metadata-only inspection may identify a legacy snapshot;
content-consuming operations refuse with one classed rebuild instruction.

### F8: R/DuckDB placement - ACCEPT WITH AUTHORITY CORRECTION

The parked placement RFC expressly gates broad migration of hashing into
DuckDB. Keeping rule 3 R-computed avoids pre-deciding that later architecture.

The response overstates existing authority when it says the contracts make R
the normative hash oracle. They make canonical R authoritative for particular
execution paths, not for a future hash rule. R is preferred here because it is
the smaller architecture supported by the measurements, not because the
Snapshot Contract already binds it.

### F9: UX - ACCEPT CORE, DEFER THE DIAGNOSTIC

Keep `verify = FALSE`, automatic verification at the first trust-bearing use,
eager `verify = TRUE`, and no public bypass.

A classed message predicting verification cost is not yet necessary and would
require its own calibration. The ticket cut may add a progress message if the
registered large-shape probe demonstrates a confusing pause. It is not part of
the integrity contract. Reporting the stored rule and current-process verified
state in snapshot information remains useful but is not load-bearing.

### F10: live row counts - DO NOT ADOPT AS A GUARANTEE

Live counts are not free when repeated, detect only insertion and deletion,
and would make every warm lookup perform data-scale work without proving full
integrity. They may remain an informational or diagnostic check. Seed v2 must
not present them as part of the verified-set guarantee.

## 4. Required Seed v2 Changes

Seed v2 should:

1. replace the locator lease with a process-generation-guarded verified set;
2. make R-defined typed binary the rule-3 candidate and state every canonical
   choice the conformance probe must freeze;
3. bind bytewise ordering across all hashed content;
4. classify reads by whether their result depends on snapshot rows, without a
   stored-root shortcut for content reads;
5. separate fast hashing from proof reuse in implementation order;
6. use absolute cost, growth and whole-process memory gates, with end-to-end
   clocks retained as supporting evidence;
7. require an explicit hash-rule marker and refuse old executable rules;
8. keep DuckDB-side hashing behind the later placement RFC;
9. keep the simple automatic UX and omit speculative progress machinery; and
10. leave live count checks outside the trust guarantee.

No maintainer product decision or new spike is required before seed v2. The
existing pre-ticket conformance probe remains necessary before synthesis can
become executable tickets.

## 5. Decision

The response found genuine architectural defects and substantially improved
the proposal. Its disposition is upheld after the corrections in this review.
The seed author should now write seed v2; the response remains historical.

RECOMMENDED_NEXT_STAGE: Seed v2
