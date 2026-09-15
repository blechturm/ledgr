# Availability Hot-Path Representation - Spike Charter v2

## Status and source state

Charter v2; supersedes Charter v1 by applying Charter Review v1 findings B1,
B2, M1, and L1 only. Author: Claude (Response v1 author and prerequisite-probe
executor; not the Seed v2 author). Non-binding until reviewed under
`spike_protocol.md` sections 2, 4, and 8. Branch `v0.2.0.1`, commit
`cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2`; nothing staged or committed.

## One question

> Can one bounded columnar/chunked diagnostic writer replace the current
> list-of-one-row-data-frames path while preserving exact direct-run,
> interrupted/resumed, persisted, reopened, and explained evidence on the
> shared availability fold?

## Cheaper prerequisite

Question: which lane dominates wall time and allocation pressure in the current
availability-aware flat fold on a shortened, public, production-shaped
synthetic fixture? Answer: `DIAGNOSTICS_DOMINANT` at the registered 40-pulse
shape (`dev/spikes/availability-hot-path-representation/lane_profile_findings.md`):
diagnostics 67.0% of in-loop samples, provider 31.2%, valuation 1.0%, residual
0.8%. It authorizes the diagnostic comparison first; it proves nothing at 757
pulses, and no result may be extrapolated across pulse counts.

## Smallest runnable fork

One seam: replace diagnostic-row accumulation and final binding behind the
existing fold and output-handler boundary: the per-row constructor, retained
list, final `do.call(rbind, diagnostic_rows)` with its single persistence
call, and write-time `MAX(diagnostic_seq) + 1` renumbering
(`R/availability-economics.R:386-432`; `R/fold-engine.R:318-327, 1082-1108`;
`R/backtest-runner.R:426-446`).

Unchanged: provider resolution, valuation, strategy invocation, accounting and
ledger events, the `run_diagnostics` schema and every stored column, public
diagnostics as data frames/tibbles, `ledgr_run_explain()`, and the transaction
owner (`R/fold-engine.R:1116`; exception evidence only after rollback at
1120-1140). Base assignment and
`collapse::setv()` are details inside the one alternative; buffer ownership and
chunk policy are the fork's choice. The executor starts from the smallest
runnable fork; its failures generate at most ten initial cases, and no expected
answers, witness rows, or checker exist before it has failed.

## Comparison arms

1. The current production list-of-one-row-data-frames implementation.
2. One bounded columnar/chunked diagnostic-writer implementation.

No third arm. Both arms run two registered public fixtures that the runner
regenerates from the lane profile's construction. Shared shape: 563
instruments, 505-member axis, weekday sessions with
every civil day declared, complete bars, identical complete lists knowable the
day before, `active` status and `known_active` lifetime facts for all 563,
flat targets, zero holdings, stale limit 2. Comparison fixture: 40 pulses,
four lists at sessions 1, 11, 21, 31. Envelope fixture: 757 pulses, 60 lists
at evenly spaced sessions from session 1. Both assert no `execution_view()`
call: zero actionable targets, zero execution-stage rows, zero fills.

## Evidence claims

Contract-level categories for later fork-derived cases; not a witness list.

1. Identical diagnostic schema, values, row count, nullable meaning, and the
   authoritative pulse/stage/axis order (`v0_2_0_0_spec.md:424-429`;
   `contracts.md:462-471`).
2. Continuous, exactly-once `diagnostic_seq` across direct execution,
   `max_pulses` interruption, and resume; no second write through
   `write_run_evidence()` (`R/backtest-runner.R:441-446`).
3. Identical completion status, ledger events, fills, equity, and strategy
   state, compared through ledgr's own run and snapshot identity.
4. Identical fresh-connection diagnostics and `ledgr_run_explain()` results
   (`contracts.md:877-884`), including exception evidence after rollback.
5. Same-host wall and process peak-memory measurements with explicit timing
   boundaries and no public performance claim.

Existing append, resume, rollback (`test-availability-economics.R`) and parity
tests remain the regression net; the fork adds cases only where it fails.

## One kill and recharter condition

If the alternative removes diagnostic construction and final binding as the
largest measured lane, but the unchanged production-shaped run still breaches
its registered resource envelope, close the spike without adding another
alternative and route provider resolution into a separate RFC or spike
question. The envelope applies to the 757-pulse fixture: wall around
`ledgr_run()` at most 1,800 seconds (the external control's clock: it stopped
a `RUNNING` process at 1,804 elapsed seconds and never persisted `t_loop`),
and process peak working set at most 4,096 MiB, a newly registered charter
stop rather than an external measurement. `t_loop` is secondary only.

## Executor deliverables

Exactly the three items of `spike_protocol.md` section 6: a runner that
regenerates both fixtures, executes both arms, and writes evidence CSVs; a
checker that reruns into scratch space, diffs the recorded CSVs, and guards
package scope as section 6 lists it; and an inventory showing one gutted path
failing and listing what was demoted, deleted, and learned. Identity uses
ledgr's own run and snapshot identity or is labelled `proto:` once. No hash
ledgers, registries, ancestry or workspace gates, tripwires, or review modes.
Harness within 1,500 lines; a diff over 500 lines is a stop-and-talk.

## Measurement boundary

Same host, R, and dependency versions; one fresh process, scratch store, and
run ID per run. Wall is `proc.time()` around `ledgr_run()`; `t_loop`
(`R/fold-engine.R:1113-1141`, spanning transaction, loop, final bind, and
persistence) is a secondary decomposition. Peak working set comes from an
external per-process sampler. Profiler samples, positive Vcell growth, retained
`object.size()`, and process working set stay distinct. At 40 pulses: one
unmeasured warm-up and three measured runs per arm, medians beside raw values;
GREEN requires the alternative's median wall and peak working set below the
current path's medians by more than that path's run-to-run spread, after every
claim holds. At 757 pulses: one unprofiled run per arm
against the envelope plus one profiled run of the alternative, using the lane
profile's classifier to identify the largest lane; the current arm is stopped
at either ceiling, recorded as stopped with no achieved horizon, and is not
obliged to finish. Terminal outcomes interpret the one result, not gates: GREEN,
the alternative preserves the bounded claims and removes the diagnosed
mechanism with materially lower same-host wall and peak memory; RED, it cannot
preserve the binding evidence contract or does not remove the mechanism;
INCONCLUSIVE, the measurement cannot separate the arms within this boundary.

## Non-goals

Provider, membership, status, lifetime, or valuation optimization;
`execution_view()` redesign; evidence retention tiers or dropping, sampling,
or coalescing diagnostic rows; schema, hash, snapshot, experiment, or public
API redesign; a second or compiled execution engine; parallel pulse execution;
Sharadar-specific code or licensed fixtures; broad package-wide collapse
adoption; choosing a release number; public benchmark or performance claims.

## Review contract

Two distinct reviews. Before execution, an independent reviewer applies
sections 8, 2, and 4 to this charter; Charter Review v1 was round one and this
v2's review is the second and final. After execution, a reviewer who did not
execute the spike performs the section 7 evidence review: rerun, gut one path,
diff the evidence. The charter author may review neither.

## Revision history

- 2026-09-14 - Charter v1 at `cb3047b`: Seed v2, Response Review v1, both probes.
- 2026-09-14 - Charter v2 applying Charter Review v1: B1 envelope clock and
  memory-stop label, B2 757-pulse fixture, M1 per-fixture repetitions, L1
  separated reviews. Structure unchanged; index not advanced.

CHARTER_DISPOSITION: READY_FOR_INDEPENDENT_REVIEW
