# Availability Hot-Path Representation - Diagnostic Block Spike Charter

Charter v1 (2026-09-15) for the final diagnostics spike; non-binding until two
pre-execution structural reviews pass (`spike_protocol.md` sections 8, 2, 4)
and executable only once the accepted version carries READY_FOR_EXECUTION.
Author: Claude (provider Charter author, executor of both earlier spikes, not
the Seed v2 author), who reviews neither this Charter nor its evidence. Branch
`v0.2.0.1` at `b0fe6b8` with the reviewed, uncommitted prepared-provider seam.

## One question and its cheaper prerequisite

> Can one per-pulse typed diagnostic block replace the reviewed scalar
> diagnostic-field and row-append interface, with the prepared availability
> provider held constant, while preserving every diagnostic and run contract
> and materially reducing the registered warm 757-pulse fold?

Prerequisite (`dev/spikes/availability-diagnostic-block-write/`), answered
`PULSE_BLOCK_REQUIRED`: at the registered 383,042-row shape the reviewed
scalar-fields-plus-row-append path took 43.67 s median and one typed block per
pulse 0.30 s median, a 99.31% reduction, with exact R-value parity across a
4,096-row chunk boundary. That is a mechanism floor measured outside the fold,
not full-fold acceptance evidence, and this Charter does not use it as the
full-fold expectation.

## Smallest runnable fork

One seam: the fold-side diagnostic interface behind the reviewed columnar
writer (`R/availability-diagnostic-writer.R`, committed at `5edabae`). Selected
once per fold by `options(ledgr.internal.spike_diagnostic_block)`, default
`off`. Off keeps `ledgr_availability_diagnostic_fields()` per row and one
`append()` per row from the fold's per-instrument loops (`R/fold-engine.R:623`,
`:715`, `:828`, `:849`, the reconciliation and stop rows). On builds one typed
block per pulse from the vectors the pulse already holds through a
namespace-level block constructor and appends it with a writer `append_block()`
that fills the same bounded chunks and flushes at the same boundaries. The
writer stamps the mode it actually built as an attribute outside every
persisted value. Unchanged: the chunk writer, the transaction owner and
write-time `diagnostic_seq` renumbering, the post-rollback exception row, the
schema and reason vocabulary, the prepared provider (option
`ledgr.internal.spike_availability_provider` at `"prepared"` in both arms),
and every public reader.

## Comparison arms and fixtures

1. Current: the reviewed columnar writer, scalar
   `ledgr_availability_diagnostic_fields()` construction, one append per
   diagnostic row, prepared provider held constant.
2. Alternative: the complete typed diagnostic block for each pulse, appended
   to the same bounded columnar chunks, base block replacement for character
   columns and safe vector writes for numeric, integer, and POSIXct columns,
   prepared provider held constant. It may not delete, sample, coalesce,
   reconstruct, or defer ordinary diagnostics.

Semantic fixture: the provider spike's public 14-instrument, 30-session
fixture with its non-flat strategy, plus one missing bar for a held instrument
so stale-mark risk rows and a bar-missing no-fill occur; every stage in claim
3 must appear at least once. Fold fixture: the writer runner's registered
`spike_fixture(FIXTURES$envelope757)` (563 instruments, 505 members, 757
pulses, flat targets), sealed once and copied per run; sealing is the cold
clock and stays outside the comparison, reported separately.

## Evidence claims

Categories the fixtures must exercise and the fork must be able to fail; cases
derive from actual failures, at most ten; a category the fork cannot fail
becomes a policy sentence. Existing `test-availability-*.R` files run under the
alternative as the regression net (optional mirai test recorded separately).

1. Exact arm attestation: the writer's stamped mode plus traced call counts of
   the scalar field constructor and the block constructor per run; an
   alternative run with any scalar construction or no block construction fails
   before any equality can pass.
2. Full diagnostic equality arm-to-arm on both fixtures: types, values, order,
   missingness, reasons, continuous `diagnostic_seq`; resumed equals direct.
3. Stage coverage: decision, restriction, risk (stale mark), no-fill (halted
   at opening, bar missing, final pulse), fill, reconciliation, exception,
   completion (`INCOMPLETE` stop and `DONE`) (`contracts.md:408-436`).
4. Chunk-boundary behaviour: blocks spanning 4,096-row chunks at scale and a
   7-row chunk on the semantic fixture, identical frames and sequence.
5. Clean run, deliberate failure, rollback with the error row written only
   afterwards, interruption, resume, and reopen with identical `availability`
   and `ledgr_run_explain()` results whichever arm serves the reopen.
6. Persisted diagnostics, events, equity, state, completion, and the `runs`
   identity row on one non-measured 757-pulse pair by DuckDB set difference,
   excluding only `run_id`, `created_at_utc`, and the config store locators;
   `archived_at_utc` is compared (both fresh runs are unarchived).
7. The registered warm 757-pulse fold per arm, wall around `ledgr_run()`.
8. Externally sampled peak working set on every measured run.
9. Lane attribution of one profiled alternative run with the lane profile's
   classifier extended to the block constructor and `append_block()`.
10. No character or list `collapse::setv()`: on the semantic scenarios the
    harness traces `collapse::setv()` and records every target's storage type;
    measured runs stay untraced.

## Registered envelope, kill condition, and measurement boundary

Envelope, alternative arm at 757 pulses: median wall around `ledgr_run()` at
most 60 s and below the current arm's median by more than the current arm's
run-to-run spread; every measured peak working set at most 1,024 MiB. Basis:
the provider spike's prepared fold ran 102.58 s median (spread 5.99 s) with
diagnostics at 85.3% of in-loop samples, about 78 s of its 93.47 s `t_loop`
(append 63 s, construction 15 s), leaving about 25 s of valuation, residual,
persistence, and outside-loop work. Removing most of the 78 s lands near 30 s;
60 s admits twice that for block assembly, chunk flushes, and host noise while
still requiring a material reduction; the 25-40 s research aspiration lies
inside the envelope, neither required nor promised. Memory keeps the provider
spike's ceiling (current arm peaks 816-867 MiB; block assembly is transient).

One kill and recharter condition: if the alternative preserves every claim
but breaches any envelope component, close the spike without a third arm; the
profiled run chooses the destination: recharter the block interface if
diagnostics still lead, otherwise route the new leading lane.

Same host, R, and dependency versions; the same collapse library for both
arms, selected explicitly and recorded; one fresh process, scratch store copy,
and run ID per fold run; `t_loop` secondary. Each arm: one unmeasured warm-up
and three measured runs, medians beside raw values; the alternative adds one
profiled run; the current arm is stopped by the external control at 1,800 s
or 4,096 MiB and recorded as stopped if unfinished. GREEN: every claim holds,
the mechanism was observed, and both envelope components are met. RED: a
claim cannot be preserved without narrowing evidence, or identity, schema,
sequence, or the writer contract changes. INCONCLUSIVE: the measurement cannot
separate the arms.

## Deliverables, non-goals, and reviews

Exactly the three items of `spike_protocol.md` section 6 under
`dev/spikes/availability-diagnostic-block-write/`, preserving `probe.R`,
`probe_findings.md`, and `probe_measurements.csv` unchanged: a runner that
regenerates the fixtures, executes both arms, and writes evidence CSVs; a
checker that reruns the deterministic semantic evidence into scratch,
byte-diffs it, validates every measurement and envelope claim, verifies the
observed arm, inspects every tracked and untracked package-scope change
fail-closed, and rejects GREEN when block dispatch is gutted or falls back to
scalar append; and a one-page inventory showing that gut failing after the
clean execution, seam restored and verified before handoff. No hash ledgers,
registries, ancestry or workspace gates, tripwires, or review modes. Harness
and seam within 1,500 R lines; a correction round over 500 changed lines is a
stop-and-talk.
Non-goals: any change to diagnostic schema, types, nullable meaning, reason
vocabulary, order, `diagnostic_seq`, transaction ownership, failure behaviour,
run identity, or to availability, valuation, risk, affordability, execution,
completion, resume, or reopen semantics; public API, schema migration, second
engine, parallel pulse execution, durable expanded matrix, Sharadar-specific
code, release placement, or public performance claims.
Reviews: two pre-execution structural reviews by an independent non-author,
the second final and the only source of READY_FOR_EXECUTION; then a section 7
evidence review (rerun, gut one path, diff the evidence) by a non-executor.

CHARTER_DISPOSITION: READY_FOR_INDEPENDENT_REVIEW
