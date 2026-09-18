# Proposed Amendment: Trusted Timestamps And Final Benchmark Boundary

**Target:** accepted ledgr v0.2.0.1 specification and accepted hot-path
complexity amendment.

**Status:** accepted by the maintainer 2026-09-18 after independent review and
focused re-review. The Section 5.1 prerequisite is authorized before ticket
cut; package implementation remains unauthorized until tickets are accepted.

**Date:** 2026-09-18.

**Baseline:** `8064a77`, which commits the reviewed remaining-optimization
inventory and exact-parity proof-template draft.

**Evidence:**

- `remaining-optimization-options-inventory.md`;
- `setup-orchestration-optimization-note.md`;
- `results-path-and-benchmark-boundary-note.md`;
- `dev/bench/notes/durable_path_observations.md`;
- `dev/spikes/snapshot-sealing/loop_audit.md` and
  `probe_findings.md`;
- the corrected public-sweep working-tree measurement recorded in the
  results-path note; and
- `inst/design/exact_parity_internal_optimization_proof_template.md`.

The accepted v0.2.0.1 work removed the provider, diagnostic, seal-validator,
event-buffer, and fold-valuation discontinuities in its declared scope. The
first closeout attempt then exposed a benchmark-boundary defect and three
additional bounded costs whose proof can share the final-source record that
must already be rerun.

This amendment binds that final correction. It does not authorize the rest of
the optimization inventory, a new execution mode, a new hash rule, or a broad
cleanup pass. The present Batch 10 record remains diagnostic history. Release
closeout resumes only after the corrected public benchmark boundary and every
admitted optimization have been implemented, independently reviewed, and
measured once from accepted final source.

## 1. Authority And Narrow Supersession

The accepted v0.2.0.1 specification and accepted hot-path amendment remain
binding except where this amendment says otherwise.

On acceptance, this document supersedes only the following clauses:

- Spec Section 2.2 adds the exact timestamp, hash, benchmark, and
  proof-template work in Section 2 here.
- Spec Section 2.3 permits only the named exceptions in Sections 3 through 6
  here.
- Spec Sections 3.7 and 7.3 replace private memory rows with the public
  one-candidate sweep boundary in Section 3 here.
- Spec Sections 7.4 and 9 bind the parity reference, record disclosure, and
  final-source rerun in Sections 3 and 8 here.
- Accepted amendment Sections 7 and 8 reclassify the current Stage J record as
  provisional and insert Section 7 here before release closeout.
- Accepted amendment Section 9 permits only the exact OPT-C01, combined
  OPT-C02/C03, and OPT-L01 work below.
- The packet documentation rule ratifies and indexes the exact-parity proof
  template under Section 6 here.

All other compatibility, identity, execution, rollback, resume, reopen,
dependency, measurement, and release gates continue to apply.

This amendment changes no public function, argument, default, schema,
canonical JSON, snapshot-hash bytes, hash-rule version, config hash, run or
event identity, accounting policy, availability policy, transaction owner,
cache contract, worker protocol, or execution engine.

## 2. Exact Scope

The amendment contains five deliverables:

1. correct the two memory peer rows to time public one-candidate
   `ledgr_sweep()` workflows and retain the old private rows only as internal
   diagnostics;
2. bind the compensated public inline summary as the memory equity reference;
3. replace scalar timestamp formatting in dense static-coverage validation;
4. conditionally replace two redundant availability-ingestion timestamp
   operations and deduplicate timestamp formatting within snapshot-hash
   chunks; and
5. accept, index, and independently verify the exact-parity internal
   optimization proof template as evidence infrastructure.

The three admitted optimization mechanisms correspond exactly to OPT-C01,
the combined OPT-C02/C03 item, and OPT-L01 in the reviewed inventory.

The work is complete only when production source is singular. Test-only
oracles may survive where this amendment requires them. No option, environment
variable, arm stamp, alternate public method, or runtime compatibility branch
may select a superseded production path.

## 3. Public Benchmark Boundary And Parity Authority

### 3.1 Peer-comparable ledgr rows

The final peer record retains the durable public `ledgr_run()` row and adds two
public memory-backed rows:

- `ledgr_ttr_canonical_sweep`, implemented as `ledgr_sweep()` with exactly one
  candidate under canonical R accounting; and
- `ledgr_ttr_compiled_spot_fifo_sweep`, the same public workflow with
  `compiled_accounting_model = "spot_fifo"`.

The complete public-call wall belongs to each peer-comparable result. The
one-candidate grid, sweep orchestration, inline summary, retained returns, and
retained trades are not subtracted to improve the reported number.

The historical private-fold memory and compiled rows remain immutable internal
diagnostics under their original record and method identifiers. They are never
renamed as product rows, used in a peer ordering, or quoted as ledgr workflow
performance.

The corrected method is `public_one_candidate_ledgr_sweep_v002`. The working
tree measurement under that method proves feasibility only. The immutable
record is rerun after all accepted source changes at the exact accepted commit.

### 3.2 Untimed oracle and production reference

An internal oracle may run outside the reported clock to expose fills, cash,
positions, and other surfaces that public sweep retention does not return. It
does not contribute a second peer result.

The public inline summary is authoritative for memory equity. It is the
production path and uses compensated accumulation. The reconstruction oracle
is a comparison path, not an authority.

Required comparison rules are:

- fills and realized trades compare exactly, including row order, classes,
  names, identifiers, and non-floating metadata;
- public canonical and public compiled sweep outputs compare exactly at all
  non-floating surfaces;
- floating equity uses the already registered relative `all.equal()`
  tolerance of `1e-8` and no wider value;
- maximum absolute and relative residuals are recorded with affected columns
  and rows; and
- failure of the existing predicate blocks the record rather than changing
  the reference or tolerance.

The final record must state that earlier peer parity CSVs used reconstructed
equity as their basis and that the new CSVs use compensated production-inline
equity. New residuals are not presented as if the reference basis were
unchanged.

### 3.3 Report integrity

The report orders stacked phases as snapshot preparation, experiment setup,
engine, and results. Factor order is explicit rather than derived from input
row order.

An unavailable peer time is missing, not zero. In particular, an unavailable
LEAN row may not render as `0.000s`, enter an ordering as zero, or appear to
have completed. Optional and required peer availability retain the accepted
benchmark-methodology rules.

Plotting-library choice does not affect acceptance. The rendered chart and its
source data must agree on row status, totals, phase order, and missingness.
The current working-tree report already has explicit phase factors, separates
completed and unavailable rows, and renders missing time as `NULL`. This
section locks that corrected behavior; it does not require a second chart
implementation.

## 4. Dense Static-Coverage Timestamp Validation

### 4.1 Production rule

`ledgr_precompute_validate_static_coverage()` continues to prove that every
static-universe instrument has one non-empty, identically ordered timestamp
axis. The coverage proof is not removed or replaced with an assumption about
sealing.

The implementation converts each axis to one primitive POSIXct or numeric
representation and compares it by vector operations. It may not call
`ledgr_normalize_ts_utc()`, `format.POSIXct()`, `ledgr_iso_utc()`, or another
scalar formatter once per bar. It may not move the check into DuckDB after the
same vectors are already materialized.

The supported public path traverses adapter normalization, snapshot sealing,
`SEALED` status enforcement, and ordered snapshot loading. The validator may
rely on the whole-second UTC guarantee only after that complete chain. It must
still prove the new derived property: a complete, identically ordered dense
instrument-by-pulse rectangle.

### 4.2 Defensive behavior

The optimized validator fails closed before equality comparison when an axis
contains missing or non-finite time values. Missing values may not compare
equal merely because they occupy the same positions.

Sub-second values are rejected by the validator. This intentionally tightens
unsupported direct/internal behavior: the current string formatter silently
truncates two instants inside one second, while supported persisted bars are
already rejected at seal and unsealed snapshots cannot be opened. The direct
validator must no longer normalize that invalid input into equality.

Missing or non-finite timestamps and sub-second timestamps raise the existing
`ledgr_invalid_pulse_context` class. Existing missing-instrument,
empty-instrument, and misaligned-axis failures retain their
`ledgr_precomputed_coverage_error` class and contract-bearing message.

The change does not alter accepted public inputs. Date values and timezone
attributes that denote the same supported whole-second instants continue to
compare as the current path does.

### 4.3 Semantic matrix

The retained current implementation and candidate are compared before source
retirement over at least:

- one instrument and multiple instruments;
- identical axes and a one-second mutation at the first, interior, and final
  pulse;
- a missing instrument and an empty instrument;
- duplicate timestamps, reordering, and unequal axis lengths;
- equal instants carrying different timezone attributes;
- Date coercion currently accepted by the internal validator;
- `NA` in one axis, both axes, and different positions;
- `NaN`, positive infinity, and negative infinity where constructible;
- equal and unequal sub-second values in the same formatted second; and
- direct calls plus the public sweep, precompute, and walk-forward consumers.

Every supported case compares exactly. The deliberately tightened invalid
cases must raise the class bound in Section 4.2. Availability-aware execution
continues to bypass this dense static-coverage validator.

### 4.4 Structural and measured gate

The structural test instruments the validator and proves one vector conversion
per instrument axis and zero per-bar timestamp-format calls. A source guard
rejects restoration of scalar `vapply()` formatting in
`ledgr_precompute_ts_key()` or the coverage validator.

The test must also satisfy Section G of the exact-parity proof template: a
deliberate scalar-format or repeated-work mutant must make the structural gate
fail. Timing alone and assertions observed only on the optimized path are not
sufficient.

The paired performance record uses the registered 500-instrument,
1,260-session public sweep fixture on one quiet host. It holds the corrected
public benchmark boundary constant and records canonical and compiled rows.
Run one warm-up and at least three measured runs per arm.

The candidate passes only when:

- its median dense coverage-validation wall is at most 0.10 times the current
  arm's same-session median;
- both public warm rows improve by at least 10.0 seconds against their
  same-session current-arm medians;
- each improvement exceeds the complete current-arm measured spread;
- every semantic and structural check passes; and
- candidate peak working set does not exceed the current same-session maximum
  by more than 15 percent.

The 0.10 validator ratio is a generous regression ceiling, not the primary
discriminator. Zero per-bar formatting, a mutation-sensitive structural gate,
and the 10-second improvements on both public rows carry the stronger burden.

The earlier 13.94-second unprofiled validator and the 0.0049-second prototype
are scope and threshold evidence only. They are not acceptance measurements.

## 5. Availability Ingestion And Snapshot Hashing

### 5.1 Shared availability prerequisite

The availability work has one prerequisite and one shared fixture family.
After amendment acceptance and before ticket cut, a bounded probe compares:

- the current rowwise `ledgr_availability_observation_times()` result with a
  vector or block candidate; and
- the current token-based session-close comparison with a primitive-instant
  candidate.

Both comparisons cover the full matrix in Section 5.2. The probe writes one
findings artifact, changes no package source, and measures one warm-up plus at
least three runs of each current and candidate operation at the registered
availability shape.

The probe returns exactly one outcome:

- `COMBINED_EXACT`: ticket and implementation cover observation-time
  normalization and session-close comparison. Both semantic comparisons pass,
  and the session-close candidate median is at most 0.20 times its current
  same-session median.
- `SESSION_CLOSE_ONLY`: observation-time normalization remains unchanged and
  implementation covers only session-close comparison. The observation-time
  candidate is inexact or inconclusive, while session-close semantics pass and
  its candidate median is at most 0.20 times its current same-session median.
- `NEITHER`: session-close semantics fail, its candidate misses the 0.20
  admission threshold, or the prerequisite is otherwise unresolved. Neither
  availability optimization enters this release. An exact observation-time
  candidate does not ship alone.

A new parser, changed error policy, changed quarantine row, or unresolved
difference prevents `COMBINED_EXACT`. The findings artifact and ticket cut
record the selected outcome before implementation. They do not reinterpret an
inconclusive result as success or re-register the 0.20 threshold after seeing
the probe.

### 5.2 Exact ingestion semantics

Under `COMBINED_EXACT`, observation-time normalization removes the rowwise R
loop but preserves each row's result independently. One malformed element in
a mixed vector becomes the same missing time and later the same
`timestamp_invalid` quarantine candidate as today; it does not abort or alter
another row.

Session-close comparison operates on normalized primitive instants rather than
formatting every value into a token. It must preserve the current whole-second
token semantics, including current behavior for sub-second invalid input that
will later fail the supported seal path. This item does not acquire the
intentional tightening authorized for the post-seal dense validator.

The shared matrix includes:

- Date input with and without a session family;
- character date labels mapped to open, closed, missing, and duplicate session
  headers;
- POSIXct UTC and equivalent timezone attributes;
- accepted ISO-Z and every other currently accepted timestamp form;
- missing, empty, malformed, and non-finite values both alone and mixed with
  valid rows;
- exact close, outside-close, and sub-second values;
- duplicate and unsorted observation rows;
- unknown and missing instruments;
- accepted, rejected, and quarantine-candidate outcomes; and
- absence of session facts and empty open-session rows.

The complete returned `accepted`, `quarantine`, and `report` objects compare
exactly: row order, classes, names, timestamps, reason and outcome tokens,
original-row JSON, provenance JSON, quarantine IDs, and numeric values. The
same snapshot either seals or fails with the same class and retained evidence.

### 5.3 Availability structural and measured gate

The production path is singular. Under `COMBINED_EXACT`, a source guard rejects
an R-level loop over every observation timestamp. In both outcomes it rejects
per-bar textual formatting inside session-close membership comparison.

The paired record uses the registered 563-source, 505-member, 757-pulse
availability fixture. Run one warm-up and at least three measured input
validations per arm plus at least three complete cold snapshot records per arm
on one quiet host.

Under `COMBINED_EXACT`, the candidate passes only when:

- median `ledgr_availability_validate_inputs()` wall is at most 0.50 times the
  current arm's same-session median;
- the complete cold snapshot wall improves by more than the current arm's
  complete measured spread; and
- candidate peak working set is no more than 15 percent above the current
  same-session maximum.

Under `SESSION_CLOSE_ONLY`, the isolated session-close comparison median must
be at most 0.20 times its current same-session median, and the complete cold
snapshot must improve by more than the current arm's complete measured spread.

The two ratios have different denominators. The 0.50 combined gate measures
the complete `ledgr_availability_validate_inputs()` call because both dominant
timestamp mechanisms change. The 0.20 fallback gate measures only the isolated
session-close operation because observation-time normalization remains on its
current path. The prerequisite establishes that the latter threshold is
feasible before ticket cut.

Under `NEITHER`, Section 5.3 authorizes no availability-ingestion source
change and therefore imposes no candidate performance gate. The findings
artifact remains evidence for later work.

All semantic and structural checks are mandatory in either outcome. The
earlier approximately 17-second normalization and 9-second session-close
observations are scope evidence, not acceptance results.

### 5.4 Byte-identical snapshot-hash timestamp deduplication

This item is admitted because its proof is bounded to byte identity, existing
hash-rule fixtures, chunk boundaries, reopen, tamper detection, and one paired
hash record. It does not require a semantic or identity policy decision.

Within each existing snapshot-hash chunk, format each distinct POSIXct
timestamp once and map its canonical token back to the original rows. Preserve
first-occurrence order for the distinct values and the original row order in
the emitted byte stream.

The implementation does not change:

- default or caller-supplied `chunk_size`;
- query order;
- numeric rounding or formatting;
- separators, missing tokens, newline placement, or encoding;
- hash algorithm, hash-rule version, or stored hash;
- seal-time or run-time verification; or
- memory ownership across chunks.

No cross-chunk cache ships. The optimization is bounded by one existing chunk
and disappears after that chunk is processed.

The old and candidate paths compare byte-for-byte and hash-for-hash over:

- dense rule-1 and availability rule-2 snapshots;
- repeated and unique timestamps;
- missing numeric values and every canonical bar column;
- chunk sizes 1, 2, 17, 9,999, 10,000, 10,001, and 50,000;
- row counts below, at, and above each tested boundary;
- fresh seals and old snapshots created before the change;
- reopen and run-guard verification; and
- timestamp, price, and stored-hash tampering.

Any byte or hash difference removes OPT-L01 from this release. It does not
trigger a hash-version bump or permission to update an expected hash.

At the registered 630,000-bar dense shape and default 10,000-row chunk, run one
warm-up and at least three measured hashes per arm. The candidate passes only
when:

- formatter input count is at most 0.20 times the current row count;
- median complete hash wall is at most 0.80 times the current same-session
  median;
- every hash remains exact; and
- candidate peak working set is no more than 15 percent above the current
  same-session maximum.

The earlier 3,200-to-410-millisecond formatter measurement is feasibility
evidence only. `collapse::qF()`, `collapse::qG()`, and `collapse::timeid()` are
not substituted for the proved distinct-and-remap operation.

## 6. Exact-Parity Proof Template

The reviewed draft at
`inst/design/exact_parity_internal_optimization_proof_template.md` is a
v0.2.0.1 documentation deliverable.

Before closeout it must:

1. pass independent review against this amendment, the spike protocol, RFC
   cycle, and accepted optimization-manual principles;
2. retain its eligibility gate, byte/exact/tolerance distinction,
   preregistered performance threshold, structural mutation requirement,
   public-workflow check, and stop/reclassification conditions;
3. state that it is evidence infrastructure rather than independent
   implementation authority;
4. be indexed from `inst/design/README.md` and the active packet README;
5. be locked by documentation-contract tests at its title, status, core stop
   conditions, and relationship to existing authority; and
6. be used for the exact-parity OPT-C02/C03 and OPT-L01 work, with one proof
   artifact allowed to cover the shared OPT-C02/C03 fixture.

OPT-C01 is deliberately ineligible for the exact-parity lane because Section
4.2 tightens unsupported direct/internal sub-second behavior. Its evidence
uses the same semantic, structural, mutation, and performance disciplines, but
authority comes from this normal specification amendment rather than the
template. The eligibility result is `RECLASSIFY`, and this amendment is that
reclassification; it must not be misreported as exact parity.

Amendment acceptance authorizes review and finalization of the template. It
does not create a standing no-ticket or no-RFC lane. The planned post-release
governance review decides whether and how the template reduces future process.

## 7. Sequencing And Review Stops

After maintainer acceptance, ticket cut inserts the following stages between
the present Batch 10 diagnostic record and the existing release gate. This
document allocates no ticket IDs and edits no current ticket or batch artifact.

- **Stage L - Freeze boundaries and oracles.** Freeze the corrected public
  benchmark boundary, parity reference, and old optimization oracles. Exit on
  Section 3 method tests, current-arm semantic and timing prefixes, and
  reviewed proof plans.
- **Stage M - Dense timestamp validation.** Implement Section 4. Exit on its
  semantic matrix, mutation and structural gates, paired public-sweep record,
  and independent code review.
- **Stage N - Availability and hash work.** Implement the prerequisite's
  already recorded outcome and byte-identical hash deduplication. Exit on
  Sections 5.1 through 5.4 proof, paired cold and hash records, tamper tests,
  and independent code review.
- **Stage O - Final evidence.** Finalize and index the proof template and run
  final accepted-source records. Exit on Section 6 contracts, availability
  cold/warm and peer records, the final profiler, independent evidence review,
  and explicit maintainer go-ahead.
- **Stage P - Release gate.** Run the full suite and check, render the
  documentation, reconcile governance, and write the release closeout.

Stages M and N have separate independent code-review stops. A pass in one does
not waive failure in the other. The Section 5 prerequisite is recorded before
its implementation begins. A failed OPT-L01 identity check removes that item;
it cannot block the already exact availability branch or authorize a hash
change.

Stage O is the only new closeout record. Earlier Batch 8, Batch 10, corrected
working-tree, scratch, current-arm, and paired-oracle measurements remain
labelled with their actual role. They are not silently replaced or renamed as
the final record.

Stage P remains unauthorized until Stage O evidence is independently reviewed
and the maintainer explicitly elects to proceed.

## 8. Final Records And Permitted Claims

Stage O reruns, from the exact accepted source commit:

1. the availability cold and warm record;
2. the 500-by-1,260 peer command with durable, public canonical sweep, public
   compiled sweep, Backtrader, zipline-reloaded, quantstrat, and the accepted
   optional-peer handling;
3. the final profiler; and
4. the snapshot-hash paired record required by Section 5.4.

Each record includes source commit, package and dependency versions, hardware,
concurrent-load disclosure, fixture identity, clock boundary, repetitions,
spread, peak working set, parity status, and method version.

The report separates one-time snapshot preparation from repeated warm research
iteration. End-to-end peer comparisons include snapshot preparation where the
registered method requires it, while the narrative states that sealed snapshot
preparation is paid once and reused until the data changes.

Permitted claims are limited to measured facts that pass all applicable gates:

- the two public sweep rows measure workflows available to ledgr users;
- exact fills and trades and tolerance-qualified equity are reported with the
  compensated production-inline reference;
- dense timestamp validation no longer formats one string per bar;
- the selected availability-ingestion outcome removes only the mechanisms
  proved by its accepted branch;
- snapshot-hash timestamp deduplication preserves every hash byte; and
- achieved cold, warm, durable, and peer clocks are stated separately.

No record becomes a universal speed promise, hardware-independent ranking,
compiled-default claim, ingestion-free end-to-end claim, or statement that all
known nonlinear work has been removed.

## 9. Explicit Non-Goals

This amendment does not authorize:

- duplicate strategy-preflight cleanup;
- feature payload-to-matrix fusion or setup micro-cleanup;
- ordinary or strict feature-window fallback optimization;
- fact-payload, provenance, event-payload, or quarantine-JSON batching;
- `execution_view()` reuse;
- result reconstruction, lot indexing, incremental basis, compiled lot
  packing, finalization, recovery, result-view, or evidence-join changes;
- persistent prepared-snapshot caches or worker-transfer changes;
- a new public memory-backed single-evaluation API;
- binary/raw-byte hash payloads or any hash-rule/version change;
- merging ingestion contracts or adopting a new observable CSV reader;
- compiled availability execution or promotion of compiled accounting;
- valuation work beyond the already accepted fold-time correction;
- crypto, parallel-architecture, or Docker benchmark-laboratory work;
- changes to peer workload defaults, costs, risk policy, or data; or
- a standing exact-parity governance lane before the post-release governance
  review.

The remaining inventory stays non-binding. Its later and RFC items do not
become tickets merely because this amendment cites the inventory.

## 10. Compatibility And Source Guards

Durable tests and source guards jointly prove:

- no public export, argument, default, dependency floor, or schema changed;
- dense validation has no per-bar timestamp formatting and retains its dense
  coverage proof;
- the selected availability path has no forbidden per-row normalizer or
  per-bar session-close tokenization;
- snapshot hashes and rule versions are unchanged at every tested chunk size;
- seal and run guards still recompute and verify the snapshot hash;
- no option, arm stamp, fallback, cross-run cache, cross-chunk cache, or old
  production path ships;
- benchmark peer rows use public calls and internal oracles remain outside
  reported clocks;
- unavailable times remain missing rather than numeric zero; and
- v0.2.0.0 snapshots and experiment stores reopen without migration.

The full package suite and source-package check run after focused semantic,
identity, structural, and performance gates pass. Required tests may not be
skipped because an optional peer or package is missing. Peer unavailability is
reported under the accepted methodology and never converted to success.

## 11. Amendment Review And Acceptance

Independent amendment review must answer:

1. Does the amendment add exactly the accepted benchmark correction, parity
   reference, OPT-C01, conditional OPT-C02/C03, OPT-L01, and proof-template
   deliverable?
2. Is every public, identity, accounting, ingestion, cache, and execution
   boundary unchanged except for the explicit unsupported direct-validator
   tightening in Section 4.2?
3. Is the benchmark correction a public-workflow repair rather than a faster
   private harness, and are historical private rows preserved honestly?
4. Is compensated production-inline equity unambiguously authoritative, with
   exact non-floating checks and no tolerance widening?
5. Does the dense semantic matrix close the NA and sub-second gaps while
   retaining the dense coverage proof and every public consumer?
6. Does the availability prerequisite fail closed, select exactly one of
   three declared outcomes, and preserve full row-level quarantine evidence?
7. Can hash deduplication pass only through byte-identical old/new hashes,
   bounded memory, old-snapshot reopen, and tamper detection?
8. Are all performance thresholds preregistered, paired, same-session, and
   incapable of being passed by an unchanged or merely faster wrong path?
9. Does the proof template improve evidence reuse without creating authority
   to bypass specifications, tickets, spikes, or RFCs, and is OPT-C01
   correctly reclassified out of its exact-parity lane?
10. Are sequencing, non-goals, final records, and release claims consistent
    with the accepted packet and amendment?

The reviewer returns exactly one disposition:

- `READY_FOR_MAINTAINER_ACCEPTANCE`; or
- `REVISE_AMENDMENT_FIRST`.

Review alone changes no authority. Only explicit maintainer acceptance permits
ticket and batch-plan amendments. No implementation starts at spec review.

Release requires all accepted-spec and accepted-amendment gates plus:

1. Sections 3 through 6 are implemented under their selected branches;
2. Stages M and N pass independent code review;
3. Stage O final records pass independent evidence review;
4. the maintainer explicitly authorizes Stage P;
5. the full package suite and source-package check pass at accepted final
   source; and
6. spec, amendments, tickets, YAML, batch plan, evidence, manuals, design
   indexes, roadmap, NEWS, and closeout agree.

No numerical improvement waives semantic, identity, hash, quarantine,
rollback, resume, reopen, source-removal, benchmark-boundary, or review gates.

## 12. Source Basis And Revision Record

Source basis:

- accepted v0.2.0.1 spec and hot-path complexity amendment;
- completed Batches 0 through 9 and provisional Batch 10 evidence;
- commit `8064a77` containing the reviewed inventory and proof template;
- reviewed setup/orchestration and results-path notes;
- durable-path observations and snapshot-sealing audit;
- accepted benchmark methodology, optimization manual, contracts, RFC cycle,
  spike protocol, and release CI playbook; and
- the corrected public-sweep working-tree measurement, used only as
  feasibility evidence pending an accepted-commit rerun.

Revision record:

- **2026-09-18:** initial proposal. No implementation, ticket, packet-status,
  benchmark closeout, roadmap, horizon, NEWS, or index change is authorized or
  claimed.
- **2026-09-18:** independent-review correction. Extended the availability
  prerequisite to measure the session-close candidate, added the fail-closed
  `NEITHER` outcome, explained branch-specific denominators, identified the
  report requirements as locks on an existing correction, and made mutation
  sensitivity local to the dense structural gate. Explicitly reclassified
  OPT-C01 out of the exact-parity lane because of its intentional unsupported
  direct-input tightening.
- **2026-09-18:** focused re-review returned
  `READY_FOR_MAINTAINER_ACCEPTANCE`; the maintainer accepted the amendment and
  authorized its Section 5.1 prerequisite before ticket cut. No package
  implementation or ticket is claimed by acceptance alone.
