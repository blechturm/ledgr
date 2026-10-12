# RFC Seed: Snapshot Verification Policy for v0.2.2

- Status: Seed v1, non-binding input to a Type 2 response
- Author: Codex
- Date: 2026-10-12
- Target window: v0.2.2
- Baseline: `1c8df889`

This is an internal v1 contract. Here, v1 means the first implementation of
this policy, not ledgr 1.0. ledgr is pre-CRAN and has no external users or
research artifacts that require snapshot-hash compatibility. Deliberate
breakage is allowed; accidental drift is not.

## 1. Question

When must ledgr prove that a sealed snapshot's persisted rows still match its
stored content identity, and how can that proof remain exact without charging
every run, fold and fact read for the whole snapshot again?

This seed covers the WS5-A verification-policy decision. It does not decide
WS5-B feature-artifact persistence. That question depends on the accepted
history and recursive-indicator semantics from WS3 and WS4.

## 2. Evidence and Current Behaviour

The current hash is trustworthy but too expensive and inconsistently applied.

- `ledgr_snapshot_seal()` computes the complete hash before committing the
  `SEALED` transition.
- `ledgr_run_snapshot_guard()` recomputes it for every committed run.
- `ledgr_backtest()` validates once and then reaches the run guard, so the same
  snapshot can be hashed twice before one run.
- A walk-forward test run reaches the run guard for every fold. On the
  5.5-million-bar Sharadar snapshot, the recorded estimate is about 24 of
  32 minutes for 26 unchanged-fold rehashes.
- Availability inspection and derived-state reconstruction each rehash the
  complete snapshot on demand.
- Sweep candidates already reuse a stored snapshot hash without rehashing per
  candidate.
- Rule 1 hashes instruments and bars. Rule 2 adds every declared point-in-time
  fact family and its sealed metadata.

The current R implementation formats and hashes rows in R. At the long-window
shape, measured hashing is about 8.4 to 9.8 microseconds per bar and grows with
an exponent near 1.2. A DuckDB prototype was 6 to 8 times faster on one thread
and about 35 times faster on eight, but it did not reproduce the current hash
bytes. DuckDB and R differ at numeric rounding ties and large magnitudes.

The evidence therefore supports a new hash rule. It does not support treating
DuckDB's incidental display formatting as a canonical contract.

Sources:

- `dev/bench/notes/rehash_tax_findings.md`
- `dev/bench/notes/long_window_scaling_findings.md`, Section 5
- `R/snapshots-hash.R`
- `R/run-snapshot.R`
- Snapshot and Execution Contracts in `inst/design/contracts.md`

## 3. Smallest Honest Policy

The proposed policy has two parts:

1. replace rules 1 and 2 with one cadence-neutral, database-computable hash
   rule for all new snapshots; and
2. prove that root once per process-local trust lease, then reuse the proof for
   operations performed through that trusted snapshot locator.

This deliberately does not introduce stored component or Merkle hashes in
v1. Faster complete verification plus bounded reuse is simpler and, on the
evidence available, sufficient. Component hashing remains a later escalation
if an intraday-shaped measurement falsifies that bet.

## 4. One New Hash Rule

### 4.1 Logical coverage

Hash rule 3 covers the same logical content that rule 2 covers:

- instrument rows;
- normalized bar rows;
- every sealed point-in-time fact-family header and row;
- knowledge assumptions, completeness and coverage metadata; and
- every other field currently declared part of snapshot content identity.

Dense snapshots and availability-aware snapshots use the same rule. An empty
fact-family section is a canonical empty section, not a different algorithm.
Snapshot IDs, database paths and run-local metadata remain outside the root.

The ordered section list, column list, type tag and row order are part of the
rule. Physical insertion order, DuckDB row-group layout, fetch size, thread
count and market cadence are not.

### 4.2 Canonical encoding

Rule 3 uses a ledgr-owned typed row encoding computed through DuckDB. It must
not hash an engine-specific pretty-printed table or depend on R serialization.
Each token identifies its type and length, so values and row boundaries cannot
collide by concatenation.

The ticket cut must freeze the exact encoding before production code lands:

- UTF-8 text after ledgr's existing normalization;
- UTC time as an exact integer epoch token at ledgr's supported precision;
- numeric bar values under the stored normalized representation, without a
  second undocumented rounding step;
- explicit, distinct tokens for missing and non-finite values where the schema
  permits them; and
- explicit section, row and field boundaries.

A textual typed encoding is the v1 preference because the existing DuckDB
probe establishes its performance direction and it is inspectable. A custom
binary format is rejected for v1 unless the conformance probe shows that typed
text cannot be made exact or affordable.

The hash algorithm and canonical-encoding version are recorded together as
the hash-rule version. Changing either changes snapshot identity.

### 4.3 Cadence neutrality

No component boundary uses a calendar year, civil date or exchange session.
Those boundaries would quietly make the integrity design EOD-specific. Rule 3
is one ordered content stream and works unchanged for daily, minute, irregular
or continuous-market bars.

Chunking is an implementation memory bound only. Changing chunk size must not
change the root.

## 5. The Trust Lease

### 5.1 What it means

A trust lease is process-local evidence that one snapshot locator has already
passed complete verification for this tuple:

```
normalized database path
snapshot ID
stored snapshot root
hash-rule version
current R process
```

The lease may live in the private state environment of a `ledgr_snapshot`
object. It is not serialized, persisted to DuckDB, copied into a result or
accepted from user input.

This is a real change to today's ownership model. A snapshot is currently a
lazy locator, and `ledgr_snapshot_hold()` commonly opens and closes a database
connection for one public call. The lease therefore belongs to the locator's
process-local state, not to the lifetime of a transient DBI connection.

### 5.2 Establishing a lease

A lease is established only by:

- successful sealing, because sealing computed the root from the stored rows
  in the same transaction;
- `ledgr_snapshot_open(..., verify = TRUE)` after a complete recomputation; or
- an explicit complete validation call.

An ordinary `ledgr_snapshot_open(..., verify = FALSE)` returns an untrusted
locator. It is useful for metadata inspection, but the first operation that
consumes snapshot content must verify fully before proceeding.

Adapters that seal and then return a fresh locator must explicitly transfer
the just-established lease into that locator. Constructing a fresh locator by
itself never creates trust.

### 5.3 Reusing and invalidating a lease

Every content-consuming public operation first performs a cheap metadata
check: the snapshot still exists, is `SEALED`, and carries the same root and
rule as the lease. If the check passes, the operation does not rehash rows.

The lease is cleared when:

- the locator is explicitly closed;
- its database path, snapshot ID, stored root or rule changes;
- a full verification attempt fails; or
- the locator crosses a process or serialization boundary.

Internal connection cleanup does not clear it. A reopened locator in the same
R process starts untrusted unless it is the same live locator object.

After a mismatch, ledgr fails closed and taints that locator. It does not fall
back to the stored root, silently repair rows or refresh the root.

### 5.4 Threat boundary

The lease protects against corruption present when trust is established and
against public ledgr operations changing a sealed snapshot. It is not a
defence against an actor who mutates the database through raw DBI after the
lease is established, or rewrites both content and its stored root.

Concurrent out-of-contract mutation is unsupported. If later evidence shows
that ordinary supported workflows can mutate a sealed snapshot behind a live
locator, this policy is falsified and must be tightened.

## 6. Verification by Usage Path

| Usage path | Required action |
| --- | --- |
| Import or build before sealing | No final integrity claim |
| Seal | Compute full rule-3 root; commit it atomically; establish lease |
| Open with `verify = FALSE` | Read metadata only; return untrusted locator |
| Open with `verify = TRUE` | Force full verification; establish lease |
| Explicit validation | Force full verification even if leased; refresh lease |
| `ledgr_run()`, resume, `ledgr_backtest()` | Ensure lease once; no second guard rehash |
| `ledgr_sweep()` | Ensure lease once before candidate evaluation; none per candidate |
| Precompute | Ensure lease once before reading snapshot content |
| Walk-forward | Ensure lease once for the outer operation; none per fold or candidate |
| Fact history, resolution and quarantine reads | Ensure lease; reuse on the same locator |
| Derived-state reconstruction | Ensure lease before consuming snapshot rows |
| Promotion | Ensure the promoting operation has a lease and compare content identity |
| Reopen completed result data without snapshot reads | No snapshot verification |
| Split snapshot/run stores | Verify the source snapshot through the same lease rule |

“Ensure lease” means full verification when absent and the cheap metadata
check when present. It never means trusting a stored root merely because the
root exists.

Informational calls that report only locator or stored metadata may remain
available without a lease, but they must not describe the snapshot as verified.

## 7. Compatibility Decision

There is no in-place migration from rules 1 or 2 to rule 3. Rehashing an old
snapshot under a new rule and retaining its identity would blur two content
contracts and leave old research ambiguous.

After rule 3 ships:

- new execution accepts rule-3 snapshots only;
- old snapshot metadata may remain inspectable;
- any old-snapshot operation that consumes content refuses with one classed
  rebuild instruction; and
- shipped fixtures, examples and adapters are rebuilt through ordinary public
  construction and sealing paths.

The old rule implementations may be deleted once the compatibility tests prove
the refusal. They are not retained as executable legacy modes.

This is an intentional pre-CRAN reset. It is cheaper and clearer now because
there are no external users and no research corpus to preserve. The ticket cut
must still inventory package-owned fixtures and documentation so the break is
complete rather than accidental.

## 8. Public UX and Evidence

Ordinary users do not select verification scopes. The safe path is automatic:

```r
snapshot <- ledgr_snapshot_open(path, snapshot_id, verify = TRUE)

ledgr_run(experiment)
ledgr_sweep(experiment, grid)
ledgr_walk_forward(experiment, folds)
```

The first line proves the root. The later operations reuse that proof while
the same locator remains alive in the process. If the user omits `verify`, the
first content-consuming operation pays for the same proof automatically.

`ledgr_snapshot_info()` should distinguish at least:

- the stored root and hash-rule version; and
- whether this locator currently holds a verified process-local lease.

Durable run, sweep and walk-forward provenance continues to carry the snapshot
root and rule. It does not persist a claim that a future process is trusted.

No public `trust = TRUE`, component selector or "skip verification" switch
is introduced.

## 9. Contract Changes the Synthesis Would Authorize

An accepted synthesis would amend:

1. the Snapshot Contract's rule-1/rule-2 coverage and open/verify clauses;
2. the Execution Contract's requirement to rehash every committed run;
3. the Availability Contract's requirement to rehash every fact read;
4. the split-store and derived-state verification clauses; and
5. the compatibility statement for stored snapshot hashes.

The replacement contract must distinguish content identity, complete
verification, a live process-local lease and mere possession of a stored root.

## 10. Required Pre-Ticket Evidence

The ticket cut is not ready until one bounded conformance and cost probe shows:

1. rule-3 roots are identical across insertion order, fetch chunk size, DuckDB
   thread count and repeated processes;
2. hostile timestamps, DST renderings, UTF-8 text, numeric ties, large values,
   missing values and every fact family have independent expected roots;
3. changing any covered value changes the root, while changing snapshot ID or
   path does not;
4. corruption before lease establishment refuses on every content-consuming
   surface;
5. run, sweep, walk-forward, fact inspection and derived-state counters show
   exactly one full verification per fresh locator, not per candidate or fold;
6. serialization or process transfer loses the lease; and
7. old rules refuse with the exact rebuild instruction.

Measure complete public operations, not only the hashing kernel:

- creation plus sealing;
- cold open plus verification;
- warm content reads through one locator;
- one run, one three-candidate sweep and one 26-fold walk-forward; and
- an intraday-shaped synthetic snapshot large enough to expose scaling.

The simple design is rejected before tickets if full rule-3 verification:

- grows materially faster than the input rows;
- requires memory proportional to the complete snapshot rather than a bounded
  chunk; or
- remains more than 10 percent of an ordinary representative run after being
  charged once, or more than 5 percent of the registered walk-forward path.

If it fails, the next design round may consider cadence-neutral components or
a Merkle structure. It must not silently choose calendar components.

## 11. Bets and Falsifiers

| Bet | What would falsify it |
| --- | --- |
| B1. One fast full hash per trust lease is enough for v0.2.2. | The registered daily or intraday path breaches the Section 10 materiality or memory gate. |
| B2. A locator-scoped lease is safe under supported use. | A public ledgr path changes sealed content without changing status, root or rule, or a lease survives process transfer. |
| B3. Typed canonical text is exact and portable enough. | The hostile corpus differs across supported platforms or cannot encode a stored value without ambiguity. |
| B4. Components are unnecessary in v1. | Ordinary supported work repeatedly needs independent verification of small subsets after a valid lease. |
| B5. Breaking rules 1 and 2 is cheaper than compatibility. | A package-owned or maintainer research artifact that must execute cannot be rebuilt from its frozen source. |
| B6. Users need no verification-mode knob. | A valid public workflow cannot express its integrity requirement through open, validate and ordinary execution. |

## 12. Questions for the Type 2 Response

The response should attack these points directly:

1. Is locator-scoped trust too broad given that connections are transient?
2. Is the cheap metadata check meaningful, or merely ceremony after a raw DBI
   mutation?
3. Is typed canonical text the smallest stable encoding, or does it smuggle in
   another formatting contract that binary encoding would avoid?
4. Should `verify = FALSE` remain the open default if the first content read
   verifies automatically?
5. Are the relative cost gates in Section 10 strict enough to protect future
   intraday use without overfitting to the current EOD run?
6. Does refusing all executable rule-1/rule-2 snapshots remove anything that
   the package or maintainer cannot honestly rebuild?

## 13. Sequence

1. Type 2 response by an author other than this seed's author.
2. Seed revision if the response finds a design defect.
3. Decision synthesis and final review under `rfc_cycle.md`.
4. A bounded conformance and cost probe.
5. Ticket cut for WS5-A only.
6. WS5-B feature-artifact policy after WS3 and WS4 bind history and recursive
   indicator semantics.

This seed authorizes no production change, schema migration or ticket.
