# RFC Synthesis: Availability Hot-Path Representation

**Status:** Accepted by the maintainer on 2026-09-15 after independent final
review and focused verification. Binding for the v0.2.0.1 spec packet until
superseded by that packet, a contract, ADR, or architecture note.

**Date:** 2026-09-15. **Window:** v0.2.0.1, as resolved in Section 14.

**Author:** Claude, synthesis author under the `rfc_cycle.md` rotation: Codex wrote Seed v1, the
Response Review, and Seed v2; Claude wrote the Response and the three spike Charters and executed
the writer and provider spikes. The final review belongs to an author who did not write this.

**Reviewed HEAD:** branch `v0.2.0.1` at `b0fe6b8fb8c44981ad9fc6f8692ce076be72e764`, plus the three
uncommitted, reviewed spike seams (`R/availability-diagnostic-writer.R`, `R/availability-provider.R`,
`R/availability-provider-prepared.R`, `R/fold-engine.R`) and the harnesses and evidence under
`dev/spikes/`. Code citations resolve against that tree. This synthesis changes no package file.

This RFC uses "first correction" for the first implementation of this representation change;
ledgr's roadmap has no such v1 milestone.

## 1. Cycle trail and citation keys

Stages run: seed v1, response, response review, lane-profile probe, seed v2, then three chartered
spikes, each with two structural Charter reviews and Section 7 evidence review by a non-executor
(two rounds for the writer and provider evidence, one for the block evidence). The maintainer
decisions artifact resolves Section 14 and accepts this synthesis. Every spike closed GREEN.

| Key | Artifact (`rfc_availability_hot_path_representation_v0_2_0_x_` prefix unless a path) | Author, outcome |
| --- | --- | --- |
| S1, R, RR, S2 | `seed`, `response`, `response_review`, `seed_v2` | Codex, Claude, Codex, Codex |
| WC, WI, WE | `spike_charter_v2`; `dev/spikes/availability-hot-path-representation/spike_inventory.md`; `spike_evidence_re_review` | Charter Claude, executed Claude, review Codex; GREEN |
| PP, PC, PI, PE | `dev/spikes/availability-provider-preparation/probe_findings.md`; `provider_spike_charter_v2`; `.../spike_inventory.md`; `provider_spike_evidence_re_review` | probe Codex, Charter Claude, executed Claude, review Codex; GREEN |
| BP, BC, BI, BE | `dev/spikes/availability-diagnostic-block-write/probe_findings.md`; `diagnostic_block_spike_charter_v2`; `.../spike_inventory.md`; `diagnostic_block_spike_evidence_review` | probe Codex, Charter Claude, execution Claude then Codex, review Codex root; GREEN |
| SEAL, AUDIT | `dev/spikes/snapshot-sealing/probe_findings.md`, `loop_audit.md` | Claude; `QUADRATIC_VALIDATOR_AT_SEAL`; discovery map |
| STYLE, BENCH, H, RM | `inst/design/manual/optimization_coding_style.qmd`, `benchmark_methodology.qmd`; horizon 2026-09-15 infrastructure entry; roadmap performance-engineering discipline | maintainer-owned context |

Executor handoff (BI, BE): Claude wrote the block seam, runner, and checker and ran the semantic
and regression preflights, then exhausted its context before the registered timing protocol. At
the maintainer's request a Codex subagent resumed from that partial state, corrected one
harness-only checker defect, ran the full protocol, wrote the inventory, and performed the gut;
Codex root, which did not execute, ran the Section 7 rerun, gut, and diff. The block measurements
below are the subagent's, verified by that review; Claude did not produce them. After the review a
stray background run from Claude's earlier session rewrote six deterministic block-evidence CSVs
with byte-identical content before it was stopped; only file times changed.

Evidence labels: *executed*, a recorded spike or probe observation; *contract*, a cited contract or
accepted decision; *source*, a cited source observation; *proposal*, binding only on acceptance.

## 2. Decision summary

1. *proposal* The three reviewed seams are the binding internal representation direction
   (Section 4) and may advance to one implementation packet after acceptance under the gates of
   Section 9. They change no public surface, schema, identity rule, or availability policy.
2. *proposal* The seal-time quadratic validators are corrected in the same packet as a separately
   gated cold-path workstream (Section 7): not a hot-path prerequisite, and no two-arm spike.
3. *proposal* The interrupted-then-resumed `INCOMPLETE` reopen defect is a correctness
   prerequisite of that packet's release (Section 10).
4. *proposal* Valuation is the next profile-triggered question, routed as its own probe and
   Charter outside this packet (Section 11).
5. *proposal* "Optimize scale-growing work, not loop syntax" is bound (Section 12).
6. The maintainer places this packet at v0.2.0.1, ahead of the separately
   governed crypto probe, and requires both availability and peer benchmark
   closeouts after productionization (Section 14).

## 3. Evidence reconciliation

*executed* Three mechanisms on one fixture family (563 instruments, 505-member axis, 757 weekday
pulses, 60 complete lists, flat targets, zero fills):

- Writer spike (WI, WE): 40 pulses, rows 51.59 s and 786.5 MiB versus columnar 22.14 s and
  369.6 MiB (medians of three); 757 pulses, rows killed at 1,800.3 s while `RUNNING` (3,104.8 MiB),
  columnar `DONE` in 523.4 s at 900.8 MiB. Provider resolution then led at 82.7% of in-loop samples.
- Provider spike (PP, PI, PE): warm 757-pulse fold 552.28 s current versus 102.58 s prepared median
  (98.05 to 104.04 s; peaks 815.7 to 866.5 MiB); provider-only passes 406.27 s versus 0.20 s
  (static) and 425.17 s versus 0.28 s (eventful); provider build about 0.06 s; provider 0.26% of
  in-loop samples, diagnostics 85.3%.
- Block spike (BP, BI, BE): current columnar arm 94.36 s median (93.71 to 94.50 s, spread 0.79 s)
  versus block 24.93 s (24.88 to 25.11 s, spread 0.23 s): 69.43 s lower, 73.6%, 3.79 times; block
  peaks 745.4 to 799.5 MiB. Valuation leads at 67.6%, residual fold 20.7%, diagnostics 10.3%,
  provider 1.4%.

The block spike's current arm is the provider spike's prepared arm, same code; 94.36 s against
102.58 s is session and host variation. Ratios across spikes are not multiplied: each compared two
arms on one host in one session. S1 (diagnostics first) and R (provider first) were each partly
right: diagnostics led at 40 pulses, provider led at 757 once the row list was gone, diagnostics
led again once the provider was prepared; RR's rejection of the 5,960 s provider floor stood, and
PP measured the provider-only cost at 396.02 s. collapse 2.1.8 changed nothing by itself (PP:
395.44 s under 2.1.7, 396.02 s under 2.1.8); the prepared provider uses no collapse operation (PI),
and the block writer uses `collapse::setv()` only on non-character columns
(`R/availability-diagnostic-writer.R:239-265`). Representation and work placement decided; collapse did not.

## 4. Binding internal representation direction

*proposal* After acceptance the shared fold core adopts one direction:

1. **Bounded typed column chunks for diagnostics.** No list of one-row frames and no terminal
   `do.call(rbind, ...)`: typed atomic columns of bounded capacity, one data frame per chunk,
   flushed through the existing output handler, which keeps the transaction and the write-time
   `MAX(diagnostic_seq) + 1` renumbering (`R/backtest-runner.R:426-446`; seam
   `R/availability-diagnostic-writer.R:196-273`).
2. **Facts compiled once before the fold.** Canonical sparse fact tables stay the durable input and
   only persisted truth. Per build, two prepared shapes, exactly as measured, replace per-pulse
   frame scans: membership headers in resolver order with eligibility times behind one
   eligibility cursor that advances on non-decreasing cutoffs and re-seeks by `findInterval()`
   otherwise, with per-header member index sets, plus membership interval assertions kept as flat
   start, end, member, and instrument-index vectors evaluated at each cutoff
   (`R/availability-provider-prepared.R:23-93`); and status, lifetime, and terminal-event planes as
   stable-ID-indexed CSR segment tables with per-instrument cursors that advance monotonically and
   re-seek vectorised on an out-of-order cutoff, each segment resolved at compile time by the
   production predicate (`:99-163`, assembled at `:165-323`). The pulse loop filters, sorts,
   splits, or subsets no data frame. No further membership representation is bound.
3. **One typed diagnostic block per pulse.** The fold accumulates each pulse's rows as typed
   segments in emission order and appends one block per pulse from vectors it already holds
   (`R/fold-engine.R:332-347`; `R/availability-diagnostic-writer.R:138-186`). The post-rollback
   error row keeps its one-row constructor (`R/fold-engine.R:1249`).
4. **Frames only at boundaries, on the optimized paths.** In provider preparation and diagnostic
   construction and writing, frames manifest only as persistence chunks, public results, and
   inspection surfaces. Unchanged fold components that still build internal frames, such as the
   per-pulse strategy-state rows (`R/backtest-runner.R:469-474`), are governed by Section 12's
   profile-triggered rule, not by this packet.

Productionization: the `ledgr.internal.spike_*` option seams, arm stamps, and retained current
paths do not ship. The packet retires the row-list writer, the scalar per-row path, and the
per-pulse data-frame resolver, keeps one code path per boundary, and routes every provider-build
consumer, including the `availability` result and reopen path that rebuilds a provider at read time
(PI), through the prepared build; the parity gate of Section 9 runs before that deletion.
`ledgr_facts_resolve()` is not a provider consumer: it resolves membership and sessions directly
(`R/availability-inspection.R:94-125`) and stays unchanged in this packet as the independent public
membership reference the provider harness compared against (PC, PI). Changing it would need its own
evidence over its complete `rows`, `evidence`, and metadata contract.

## 5. Semantic and persistence invariants

*contract* The accepted availability synthesis, `contracts.md:343-360` and `:462-471`, and the
v0.2.0.0 spec stay authoritative. The packet preserves, and its tests assert:

- `decision_view()` and `execution_view()` results: shape, names, types, order, membership frozen
  from the decision, held nonmembers after members in stable-ID order, execution facts at the next
  opening; knowledge and effective time, precedence, tie conflicts, supersession once knowable and
  effective, lifetime and terminal events; identical answers at shuffled or repeated cutoffs (PI:
  3,676 queries identical);
- diagnostic schema, values, nullable meaning, reason vocabulary (`contracts.md:408-436`),
  pulse/stage/axis order, continuous exactly-once `diagnostic_seq` across chunks, interruption, and
  resume;
- direct, interrupted and resumed, failed, reopened, and explained behavior: resumed equals direct;
  no failed pulse is partially durable; the error diagnostic is written only after rollback;
  `availability` and `ledgr_run_explain()` are identical whichever build serves the reopen;
- ledger events, fills, equity, strategy state, completion, and run identity (`config_hash`,
  snapshot hash, run-store row), compared as whole persisted tables; for the `runs` row exactly
  `created_at_utc`, `config_json.db_path`, and `config_json.data.snapshot_db_path` are excluded and
  the exclusion is written down (BC, BE);
- one shared `ledgr_run()` and `ledgr_sweep()` fold core with one transaction owner
  (`R/backtest-runner.R:260-262`).

No sampling, coalescing, reconstruction, deferral, or deletion of ordinary decision evidence is
authorized for speed; retention policy is untouched.

## 6. Cold snapshot construction versus warm research iteration

*contract* (`spike_protocol.md` section 10, BENCH) *proposal* bound here: ingestion, validation,
and sealing are cold snapshot-construction costs, paid when source data or snapshot-defining inputs
change; repeated experiments run against the sealed, immutable, verified snapshot, so warm
research-iteration time (experiment-specific setup, execution, required result surface) is the
primary research clock, and provider compilation, rebuilt per experiment (about 0.06 s, PI),
belongs to it; cold end-to-end time remains required for lifecycle reporting and for any peer
comparison. Neither clock may be hidden or substituted for the other; a harness that cannot
separate them labels its warm number incomplete.

## 7. Snapshot-sealing correction

*executed* (SEAL, BI, PI) Cold sealing of the registered fixture took 747.91 s in the block spike's
unprofiled clock and 850 to 868 s in the provider spike. Profiled (1,448.58 s total),
`ledgr_snapshot_validate_availability_for_seal()` consumed 1,377.96 s, 95.1%. *source* The cause
is the pairwise `ledgr_fact_validate_membership_conflicts()` (`R/availability-facts.R:1324-1343`)
run at seal over all 30,300 persisted rows (`R/availability-persistence.R:318`): about 459 million
pair checks, 47.7 s per 6,000 rows on slices. The status and lifetime validators share the shape
(`R/availability-facts.R:1305`, `:1347`; seal call `R/availability-persistence.R:343`).

*proposal* In this packet, as its own gated workstream:

- replace each pairwise validator with a grouped, state-aware sort-and-sweep: within each group
  (instrument and universe for membership; instrument, source, and precedence for status;
  instrument for lifetime), sort by `effective_from`, keep a running maximum end per state, and
  flag a row whose start lies before the running maximum of any opposing state; half-open
  intervals, open ends, opposing-state semantics, precedence, and the supersession exemption
  survive unchanged (STYLE gives the reference form);
- complete-set rows bypass the sweep only after a setwise validation proves every persisted set row
  has `member = TRUE`, a valid header, and the snapshot invariants, which the database does not
  enforce;
- gates: randomized semantic equivalence against the retained pairwise validators over random and
  adversarial sets (overlap, touching ends, nesting, open ends, precedence, supersession, same-state
  overlap); the existing fact and seal tests; one full-scale post-fix cold seal of the registered
  fixture in the packet closeout. The 60 to 90 s post-fix figure (SEAL) stays a forecast until then.

Same packet because the mechanism is attributed, the replacement known, the code disjoint from the
hot-path seams, and RM already scopes hot and cold paths together; a spike would only rediscover a
known quadratic. Not a hot-path prerequisite because the warm result stands on a reused sealed
snapshot. AUDIT's other seal items (about 30 s together) are candidates to measure, not bound.

## 8. Performance evidence and permitted claims

*executed* Permitted internal statements, each tied to its spike, fixture, host, and clock:

| Claim | Basis |
| --- | --- |
| Rows to columnar at 40 pulses: 51.59 s to 22.14 s, 786.5 to 369.6 MiB | WI, medians of three |
| Rows did not finish 757 pulses in 1,800 s; columnar finished in 523 s | WI, one run each |
| Prepared provider: 552.28 s to 102.58 s warm fold; 406.27 s to 0.20 s and 425.17 s to 0.28 s provider-only | PI |
| Block: 94.36 s to 24.93 s warm fold, 3.79 times, peaks below 1,024 MiB | BI, BE |
| Arc lower bound: the original representation did not finish within 1,800 s; the cumulative path completes the same fixture in about 25 s warm | different sessions and host load; not a controlled 72-fold benchmark |

Not permitted: peer superiority, LEAN or Nautilus parity, a package-wide runtime, or any public
speed claim. The 24.93 s figure is a warm research-iteration clock over a reused sealed snapshot on
a flat fixture with zero fills and identical lists; the semantic suites cover eventful behavior, the
timed population does not. Profiler shares are sampled attribution (Windows `Rprof()` captured about
64% of loop time, S2), never a wall partition. Small-fixture numbers never appear in a ranking.

## 9. Implementation and spec-cut gates

*proposal* The packet may open only with, and its release gate must show:

1. **Two-arm parity gate before deletion.** The writer, provider, and block checkers pass against
   the productionized code: byte-exact deterministic reruns, DuckDB set-difference parity of every
   persisted table on the 757-pulse pair, the 3,676-cutoff provider parity, observed mechanism.
2. **Ported scenario suite.** The spike scenarios (direct at 7-row and 4,096-row chunks, interrupt
   and resume, injected rollback, classed nonmember-increase rollback, resume then exception, early
   terminal exit, the missing-bar fixture) become durable tests with recorded expected persisted
   rows; `test-availability-*.R` stays green, including the opening-halt no-fills.
3. **Identity rule.** Parity tests compare the `runs` row with exactly `created_at_utc`,
   `config_json.db_path`, and `config_json.data.snapshot_db_path` excluded; run IDs at both levels
   and `archived_at_utc` are compared, as BC required and BE verified after PE had recorded the
   provider spike's exclusion of `archived_at_utc` as a low observation.
4. **Dependency posture.** No collapse version floor: the adopted paths use `setv()` only on
   non-character columns and the provider uses none; the release gate runs the parity suite under
   the default library (2.1.7) and under 2.1.8.
5. **Measurement record.** One warm 757-pulse record and one cold seal record on the registered
   fixture, phase-separated per BENCH, cited by prefix in the closeout; no public claim.
6. The Section 7 seal gates and the Section 10 correctness prerequisite.

Spec-cut questions, open but not blocking acceptance: chunk capacity (4,096 measured; internal, no
public option); whether the old resolver survives inside `tests/` as an oracle or is deleted after
the gate; how the `availability` result and reopen path consumes the prepared build; the
finalization fix (Section 10); telemetry lane names after the diagnostic lanes shrink.

## 10. Package correctness finding

*executed* (PI, PE, BI, BE) An interrupted-then-resumed run that finalizes `INCOMPLETE` cannot be
reopened: finalization deletes and rewrites `equity_curve` from the finalizing invocation only
(`R/run-finalize.R:422-424`); terminal-evidence validation then requires the whole achieved prefix
(`R/run-finalize.R:97-113`) and raises `ledgr_run_terminal_evidence_invalid`. Both arms of both
later spikes reproduce it identically; it predates and is independent of every seam.

*proposal* A correctness ticket and release prerequisite of the packet, with the
interrupt-and-resume scenario as its regression test. Bound invariant: a finalized run's equity
curve covers every achieved pulse across all invocations, and every `DONE` or `INCOMPLETE` run
reopens. The repair preserves the complete historical equity prefix: it deterministically merges
the prior invocations' rows with the finalizing invocation's rows, with no missing and no
duplicate pulse, and is proven by successful reopen of both `DONE` and `INCOMPLETE` resumed runs.
Weakening the validator to the finalizing invocation's own prefix is rejected, because it would
reopen a run whose earlier equity evidence is absent. Exact implementation is spec-cut work.

## 11. Valuation and other future obligations

*executed* (BE) Valuation is the largest captured in-loop lane at 67.6% of the 25 s fold. *source*
`ledgr_availability_valuation_marks()` rescans each axis instrument's whole close history on every
pulse (`R/availability-economics.R:3-42`, loop at `:16`).

*proposal* If the maintainer continues the arc, the next question is narrow: prepare price and mark
history once before the fold (last observed close, its session index, and age per instrument as
advancing state) instead of rescanning per pulse, preserving stale-mark permissibility and age,
held-former-member marks, missing-bar behavior, valuation exhaustion, the reference price, and
point-in-time semantics. It follows `spike_protocol.md` sections 1 and 2: probe, then a Charter by a
non-seed author, two arms, one kill condition. It is not added to the existing seams and does not
block this synthesis; no semantic or implementation dependency on it was found. The residual fold
lane (20.7%) is a secondary observation, unrouted. Future obligations for horizon parking: AUDIT's
seal-path and reader items, measured individually; a cold-to-cold peer record after the seal fix;
`execution_view()` once per pulse rather than per actionable target
(`R/availability-economics.R:251`) if an eventful profile makes it material; the sweep memory
handler's character-column copies (STYLE).

## 12. Documentation and engineering-style disposition

*proposal* Bound rule:

> Optimize scale-growing work, not loop syntax. A loop is not defective by form. It becomes a
> measured optimization candidate when its iteration count grows with bars, facts, instruments x
> pulses, diagnostics, events, candidates, or folds and each iteration allocates a frame, scans or
> subsets a table, parses repetitive values, grows a container, or computes discarded work. Prepare
> data-scale inputs once; keep primitive vectors, matrices, segment tables, indexes, cursors, or
> bounded typed buffers inside; do vectorised or indexed work over those shapes; manifest frames at
> public and persistence boundaries; preserve the production rule at compile time; prove exact
> semantic and persisted-output parity; optimize measured high-impact sites, never every loop
> mechanically.

This absorbs S2 section 8 and matches H and RM. AUDIT's "about 68 HIGH and 90 MEDIUM" are discovery
estimates, admissible as direction only, never as a census or an RFC evidence count.

STYLE enters the packet as an internal engineering article under `inst/design/manual/`, not a
contract and not pkgdown content. The packet cuts its review and rendering ticket and requires:
replacing the "diagnostics is next" material (evidence-table row and "Where Next") with the
completed block result and valuation as the profiled lane; adding the per-pulse block as shape 1's
fold-side replacement; re-anchoring every `R/...:line` reference after productionization; keeping
every number labelled by clock and fixture per BENCH.

## 13. Rejected alternatives and non-goals

*proposal* Rejected: a package-wide mechanical removal of loops; forbidding data frames at API or
persistence boundaries; durable expanded membership matrices or any second persisted truth; changes
to availability policy or evidence retention; a second execution engine or compiled fold; default
or expanded compiled accounting; parallel pulse execution; Sharadar-specific runtime code or
licensed fixtures; treating the spike harnesses, option seams, or arm stamps as production
architecture; hash ledgers, provenance registries, or new identity machinery; a collapse version
floor or package-wide collapse adoption; using warm timing as cold end-to-end timing; presenting
the 25 s flat workload as a peer benchmark; claiming the unmeasured 60 to 90 s seal forecast as
achieved; and any public API, schema, hash, snapshot, experiment, or run-identity change.

## 14. Resolved maintainer and spec-cut decisions

The maintainer accepted this synthesis on 2026-09-15 and recorded the complete
resolution in
`rfc_availability_hot_path_representation_v0_2_0_x_maintainer_decisions.md`:

1. **Release placement:** v0.2.0.1.
2. **Sequencing:** this optimization packet precedes the refreshed spot-crypto
   readiness probe; crypto returns as a separate v0.2.0.x cycle.
3. **Packet scope:** the three warm-path seams, the separately gated cold seal
   correction, and the resumed-run correctness prerequisite share one packet.
4. **Closeout evidence:** run both a ledgr-only availability closeout and the
   existing standardized peer benchmark after productionization, with cold and
   warm clocks separated and no unsupported public ranking claim.
5. **Deferred work:** valuation and the Docker benchmark laboratory remain
   outside this packet.

Spec-cut questions (Section 9) resolve at ticket cut, not here.

## 15. Final-review checklist

Verify mechanically that: every number in Sections 3, 7, 8, and 11 traces to the keyed artifact
and its evidence CSV; the three seams keep the shared fold core and every Section 5 contract; no
forecast appears as a measurement (Sections 7 and 8); cold and warm clocks are never conflated
(Sections 6 to 8); exact semantic and persisted parity remains a productionization gate (Section 9
items 1 to 3); the reopen defect is routed with an invariant (Section 10); the sweep correction
preserves opposing-state, half-open, open-end, precedence, and supersession semantics with setwise
validation before any bypass (Section 7); valuation is routed outside this packet (Section 11); no
public API, schema, or identity change is invented (Sections 4 and 13); release placement and scope
match the maintainer decisions (Section 14); and every cited line resolves at the reviewed HEAD
plus the seams.

## 16. Revision history

- 2026-09-15 -- Draft synthesis consuming S1, R, RR, S2, the three GREEN spike cycles, the sealing
  probe, the loop audit, and the manual drafts. No package file, evidence, roadmap, horizon, manual,
  or index edited; nothing staged, committed, or pushed. Awaiting independent final review and
  maintainer decisions 1 to 3.
- 2026-09-15 -- In-place patch applying the final review
  (`rfc_availability_hot_path_representation_v0_2_0_x_final_review.md`): H1, Section 10 binds the
  complete-prefix merge and rejects validator weakening; M1, `ledgr_facts_resolve()` stays the
  independent public reference and only provider-build consumers are rerouted (Sections 4 and 9);
  M2, Section 4 describes the two measured prepared shapes with full ranges; M3, the frame-boundary
  rule is scoped to the optimized paths; L1, review lineage, decision-stage wording, and the identity
  exclusions and their citations corrected (Sections 1, 5, 9). Text only; awaiting focused
  verification and maintainer decisions 1 to 3.
- 2026-09-15 -- Maintainer accepted the synthesis for v0.2.0.1. Section 14 now
  records release placement, sequencing, combined packet scope, benchmark
  closeout, and deferred work through the dedicated maintainer-decisions
  artifact. No tickets or implementation packet were created by acceptance.
