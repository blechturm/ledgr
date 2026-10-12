# RFC Seed v2: Snapshot Verification Policy for v0.2.2

- Status: Revised seed; patched after Type 2 review; spike is next
- Author: Codex, seed v1 author
- Date: 2026-10-12
- Target window: v0.2.2
- Baseline reviewed: `1c8df889`; Type 2 source check at `ba754286`

Revision, 2026-10-12: the seed-v2 review found seven exactness and spike-scope
defects. This revision adopts its column-major block layout, binds the fact
payload by reference, closes presence, ordering and store-key ambiguities,
corrects the threat boundary and read census, and narrows the spike. The
two-part architecture is unchanged.

This RFC uses "v1" for the first implementation of this policy, not ledgr
1.0. ledgr is pre-CRAN and has no external research corpus that requires old
snapshot hashes to remain executable. Deliberate reset is allowed; accidental
drift is not.

## 1. Question and Boundary

When must ledgr prove that persisted snapshot rows still match their sealed
content identity, and how can it reuse that proof without charging every run,
fold and snapshot-dependent result read for a complete rehash?

This seed covers WS5-A. It does not decide feature-artifact persistence,
history panels, recursive-indicator state or the broader R/DuckDB placement
policy. WS5-B remains after WS3 and WS4.

## 2. What the Response Changed

The Type 2 response and its review preserve the two-part architecture but
replace two v1 choices.

1. Use one cadence-neutral complete content root for every new snapshot.
2. Define its canonical bytes in R, not through database text formatting.
3. Reuse a completed proof through a process-local verified set, not state on
   a locator that can be copied, serialized or bypassed by the run call graph.

The review also found a real defect in the old identity rule: default R
collation can order mixed-case quarantine content differently across hosts.
Rule 3 therefore binds byte ordering everywhere.

The following v1 proposals are rejected:

- DuckDB-defined typed text as the canonical encoding;
- locator-scoped trust;
- stored component hashes or a Merkle tree;
- live row counts as an integrity guarantee;
- a public bypass or verification-scope knob; and
- trusting a stored root before reading rows that affect an output.

## 3. Decision in One View

New snapshots use hash rule 3. It hashes instruments, bars and the normalized
fact projection into one SHA-256 root. An R oracle defines the bytes. Fixed
logical blocks bound the encoder and do not depend on market cadence.

A successful seal or complete verification registers the tuple

```
process generation + store key + snapshot id + stored root + rule
```

in a private verified set. Every snapshot-dependent operation first checks
that the stored status, root and rule still match. A hit avoids a full rehash;
a miss verifies fully. Proof is never persisted or sent to another process.

## 4. Rule 3 Logical Coverage

Rule 3 covers the same economic content as rule 2:

- normalized instrument rows;
- normalized bar rows;
- every sealed point-in-time fact-family header and row;
- knowledge assumptions, completeness and coverage metadata; and
- acknowledged observation-quarantine evidence included by rule 2.

The current exclusion of the derived `off_session_bar` observation record is
retained because the hashed bars and sessions already determine it.

Snapshot IDs, paths, envelope timestamps, run metadata and physical database
layout stay outside the root. Dense and availability-aware snapshots use the
same rule. No facts means one canonical empty fact section, not another hash
algorithm.

## 5. Canonical Rule-3 Bytes

This section defines the candidate the conformance spike must attempt. Failure
of that candidate returns the RFC to design; the spike may not silently choose
different bytes.

### 5.1 Primitive encoding

All multi-byte values are little-endian. Hashes are their 32 raw bytes, not
hex text. Counts, lengths and block indexes are unsigned 64-bit integers. The
rule number in the final root is the only unsigned 32-bit integer.

Every field, nullable or not, starts with one byte: `00` for missing and `01`
for present. A present value then carries its typed payload:

- text: `enc2utf8()` bytes;
- timestamp: two's-complement signed 64-bit whole seconds since 1970-01-01
  UTC;
- number: IEEE-754 binary64 after R's `round(x, 8)`, with negative zero folded
  to positive zero; and
- canonical JSON: UTF-8 text.

No Unicode composition or case folding is added. Different Unicode code-point
sequences remain different content. Missing numeric values use the missing
tag; NaN and positive or negative infinity refuse. Timestamps must be finite,
whole-second UTC instants representable by the signed 64-bit token.

R writes a signed 64-bit timestamp as the two little-endian 32-bit halves of
its two's-complement value, after the numeric input passes the finite,
whole-second and range checks. It does not ask `writeBin()` for an unsupported
eight-byte integer.

The numeric rule deliberately retains today's eight-decimal identity. The
binary payload removes formatting from identity; it does not increase stored
price precision.

### 5.2 Ordering

Text keys sort lexicographically by their unsigned UTF-8 bytes. Numeric and
timestamp keys sort by value. Composite keys compare fields from left to
right. No session locale participates.

The section and row order is:

1. instruments by `instrument_id` bytes;
2. bars by `instrument_id` bytes, then `ts_utc`; and
3. the fact projection described in Section 5.4.

Physical insertion order, fetch size, database thread count, row-group layout
and daily, intraday or continuous cadence must not change the root.

DuckDB may deliver rows in the requested order, but does not define it. For
each block, the R encoder asserts that the composite keys are in the strictly
increasing order returned by radix ordering of the UTF-8 keys and numeric
ordering of the remaining keys. It also compares the first key with the prior
block's last key. It refuses a violation and never re-sorts the stream.

### 5.3 Base records and framing

The instrument record fields are, in order:

```
instrument_id, symbol, currency, asset_class,
multiplier, tick_size, meta_json
```

The bar record fields are, in order:

```
instrument_id, ts_utc, open, high, low, close, volume
```

Text, time and numeric fields use Section 5.1. Each section is split into fixed
blocks of 10,000 logical rows; a final short block is permitted and an empty
section has no blocks.

Within a block, bytes are column-major. For each field in its declared order:

1. write its `N` presence bytes;
2. for a timestamp or number, write `N` eight-byte payload slots;
3. for text or canonical JSON, write `N` unsigned 64-bit byte lengths and then
   concatenate the present values' bytes in row order.

A missing fixed-width value has eight zero payload bytes. A missing variable-
width value has length zero and contributes no value bytes. The presence byte
therefore distinguishes missing text from a present empty string. This layout
is the measured candidate; it requires no per-row allocation or framing.

For section tag `S`, zero-based block index `I`, row count `N` and column-major
block payload `B`, the block digest is:

```
SHA256("LEDGR-R3-BLOCK" || S || I || N || length(B) || B)
```

The section digest is:

```
SHA256("LEDGR-R3-SECTION" || S || total_rows || block_count || block_digests)
```

Tags are one byte: `01` instruments, `02` bars and `03` facts. Literal strings
above are their ASCII bytes without a terminator. `I`, `N`, `length(B)`, total
rows and block counts are unsigned 64-bit values. Block digests are
concatenated as raw 32-byte values. SHA-256 consumes raw bytes with
serialization disabled.

The root is:

```
SHA256("LEDGR-SNAPSHOT" || uint32_le(3) ||
       instrument_section_digest || bar_section_digest ||
       fact_section_digest)
```

This makes section, block and field boundaries unambiguous. Database fetch
chunks may cut anywhere; they only feed the fixed logical blocks.

### 5.4 Fact section

The fact record is exactly the string produced by
`ledgr_snapshot_availability_hash_payload()` at baseline `ba754286`, with only
these three changes:

1. its schema label is `ledgr_snapshot_hash_rule_3`;
2. every R-side `order()` in that path uses `method = "radix"`, including
   quarantine rows, table names and alphabetically ordered column names; and
3. the quarantine ordering identity is, in this exact order,
   `supplied_instrument_id`, `supplied_ts_utc`, `reason`,
   `original_row_json`, `provenance_json`.

This reference retains rule 2's included tables, selected fields, quarantine
projection, nested per-table canonical writes, outer canonical write and fact
schema version. Fact-field doubles remain yyjsonr shortest-round-trip text;
the fact section therefore deliberately retains a textual identity.

Declared row identities must be unique. If two projected rows share an
identity but differ in bytes, sealing refuses rather than using incidental
database order.

That UTF-8 blob is the one-row, one-field column-major fact block. An absent
fact table and a present empty table both project to `[]`; the canonical empty
fact projection uses that equivalence for every table. Rule 3 does not hash
rule 2's root or reuse its locale-dependent ordering.

This is intentionally the least novel fact representation. The measured cost
is in bar formatting, while the existing normalized fact projection already
has its own exactness and scaling evidence. If the whole-process memory gate
shows that this single JSON record is unaffordable, that falsifies this choice
and returns the fact encoding to design.

## 6. Process-Local Verified Set

The verified set is private package state, not part of a snapshot object. Its
process-generation record contains the current PID and an opaque nonce. Every
lookup compares the PID. A fork or other PID change clears the set and creates
a new generation before lookup.

Within that generation, the key is:

```
canonical store key + snapshot id + stored root + hash-rule version
```

The canonical store key is the snapshot store's normalized key. In split-store
mode it comes from `snapshot_db_path`, never the run store. A store without a
durable key, including `:memory:`, is never entered in the set and therefore
verifies on every trust-bearing use. The set is never serialized in a locator,
config, experiment, result or worker payload. Fresh mirai workers and
deserialized objects start cold. A locator close does not clear it; a second
locator for the same tuple in the same process may reuse the proof.

Only two events populate the set:

- a seal that has committed the newly computed root and `SEALED` status; or
- a successful complete recomputation matching the stored root and rule.

`verify = TRUE` and explicit validation always recompute, even on a hit. An
ordinary content-consuming call uses a hit after checking stored status, root
and rule. A missing entry, changed tuple or generation change verifies fully.
A failed check or verification removes the matching entry and fails closed.

The guarantee covers corruption present when proof is established and all
mutations through supported ledgr APIs. After proof, an ordinary ensure checks
only stored status, root and rule. Any row mutation by any process that
preserves those values is undetected until `ledgr_snapshot_validate()`, an
eager `verify = TRUE` open or a new process performs a complete verification.
Raw DBI writes and external mutation after proof remain outside the contract;
no cross-call DuckDB lock is claimed.

## 7. Which Reads Require Proof

The ticket cut must derive a source census. The rule is semantic, not a fixed
list of function names.

| Read class | Requirement |
| --- | --- |
| Metadata only | May read status, root, rule and counts cold; must not claim rows are verified. |
| Durable result only | No snapshot proof when the output reads no snapshot rows. |
| Snapshot dependent | Ensure the verified set before rows affect execution, metrics, marks, reports or returned data. |

Seal computes the root. Experiment construction reads the universe and fact
headers and is class 3. Run, resume, backtest, precompute, sweep evaluation,
walk-forward, fact inspection, quarantine inspection, derived-state recovery,
availability marks, corporate-action reporting and interactive row tools are
also class 3 when they consume snapshot rows. The first class-3 call in an
ordinary workflow, usually `ledgr_experiment()`, pays the cold verification.
Verification occurs once for an outer sweep or walk-forward operation, not per
candidate or fold.

`ledgr_sweep_save()` needs only its existing identity comparison when attaching
an already-computed sweep and reads no snapshot content. `ledgr_sweep_open()`
is class 3 while it reconstructs output from the snapshot universe. It could
become class 2 only if that required derived value becomes durable and the row
read is removed.

A stored-root comparison is never a substitute when rows are about to affect
an output. Repeated live row counts are also not part of the guarantee.

## 8. Compatibility and UX

The rule marker is mandatory. Missing, rule-1 and rule-2 markers remain
metadata-readable but are not executable or otherwise content-consuming.
They refuse with one classed condition that says to rebuild from source. There
is no in-place identity migration and no missing-marker fallback to rule 1.

Ordinary UX stays automatic. `ledgr_snapshot_open(..., verify = FALSE)` opens
metadata without proving rows. The first trust-bearing use verifies cold.
`verify = TRUE` verifies eagerly. There is no public `trust`, component or
skip-verification switch.

Snapshot information reports stored root, rule and whether this process has a
matching verified-set entry. Durable run, sweep and walk-forward provenance
records root and rule, never a claim that another process is warm. A progress
or predicted-cost message is not part of this seed; add one only if the spike
demonstrates a confusing pause that needs it.

## 9. Implementation Order After Synthesis

One policy produces two ordered implementation tickets:

1. implement rule 3 while retaining every current complete-verification call;
2. add the verified set and replace duplicate verification with ensure calls.

The first ticket must be independently useful and reviewable. The second may
not weaken coverage to rescue performance. Neither ticket belongs to the
parked broad DuckDB-placement RFC because R continues to define and compute
the identity bytes.

Ticket 1 owns the end-to-end seal, cold-open, run, three-candidate sweep and
26-fold walk-forward clocks after rule 3 is wired into production. Ticket 2
owns the source-derived read census and changes `ledgr_backtest()` from its
current forced full validation to an ensure call; explicit validation and
`verify = TRUE` remain forced complete checks.

## 10. Conformance Spike Before Synthesis

A separately authored bounded spike must answer one empirical question:

> Can the exact Section 5 candidate produce one portable root with bounded,
> near-linear cost at the shapes v0.2.2 must support?

The prerequisite is an executable R encoder matching Section 5. The kill
condition is needing a second canonicalization engine or materializing bars or
instruments beyond one logical block. The retained fact projection is measured
under B4 and does not itself trip this kill condition. The spike changes no
product code.

The golden-corpus menu is: Windows and Linux, insertion order, fetch size,
DuckDB thread count, repeated processes, mixed-case and non-ASCII keys, DST
renderings of equal instants, numeric ties and large values, negative zero,
missing values, every fact family, quarantine rows and an empty fact section.
After the first runnable encoder exists and has run, the charter freezes at
most ten cases from that menu. Each covered-value mutation changes the root;
path and snapshot ID do not.

The provisional cost gates, measured at one database thread, are:

- base payload no more than 1 microsecond per bar at the largest registered
  shape;
- endpoint growth exponent no greater than 1.10 over at least 0.5, 1, 2 and
  5 million bars; and
- bounded encoder memory, with whole-process peak RSS and the fact JSON peak
  reported separately rather than hidden.

The spike measures its scratch encoder and query path, not production seal or
execution calls. If a threshold is noisy, it reports that rather than revising
it. Section 9 routes end-to-end product clocks to the first implementation
ticket.

## 11. Contract Changes an Accepted Synthesis Would Authorize

The synthesis would replace the Snapshot Contract's rule-1/rule-2 and missing
marker clauses, the Execution Contract's per-run rehash requirement, the
Availability Contract's per-read rehash requirement, and split-store and
derived-state verification clauses.

The replacement must distinguish content identity, complete verification, a
current-process verified entry and mere possession of a stored root. It must
also record the three read classes and the legacy rebuild refusal.

## 12. Bets and Falsifiers

| Bet | What would falsify it |
| --- | --- |
| B1. The Section 5 bytes are portable. | Any supported Windows/Linux golden root differs. |
| B2. One fast full root is enough. | The registered daily or intraday-shaped probe breaches cost, growth or memory gates. |
| B3. The verified set is safe for supported use. | A supported API changes sealed content without changing the checked tuple, or a proof is reused after a PID/process-generation change. |
| B4. One canonical fact JSON record is affordable. | Fact-bearing whole-process peak or cost is not bounded at the registered shape. |
| B5. Components are unnecessary in v1. | A supported path repeatedly needs independent proof of a subset after a valid full proof. |
| B6. Old snapshots can be rebuilt. | A package or maintainer artifact that must execute lacks frozen source inputs. |
| B7. Users need no verification knob. | A valid public workflow cannot express its integrity requirement through open, validate and automatic execution. |

## 13. Sequence

1. Charter, run and independently review the Section 10 conformance spike.
2. Synthesis by an author other than this seed's author, using spike evidence.
3. Final verification and maintainer acceptance.
4. Cut the fast-rule ticket, then the verified-set ticket, for WS5-A.
5. Return to WS5-B after WS3 and WS4 bind history and recursive state.

This seed authorizes no production change, schema migration or ticket.
