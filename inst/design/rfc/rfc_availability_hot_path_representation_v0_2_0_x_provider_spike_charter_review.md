# Availability Hot-Path Representation - Provider Charter Review v1

**Status:** First pre-execution structural review.
**Reviewer:** Codex; not the Charter author or prospective spike executor.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD
  `b0fe6b8fb8c44981ad9fc6f8692ce076be72e764`.
- Charter v1 is untracked, exactly 150 lines, ASCII-only, LF-terminated, and
  within the 79-character line limit it set for itself.
- No spike code or evidence was executed. This review applies
  `spike_protocol.md` sections 8, 2, and 4 and inspects the cited production
  paths.
- The pre-existing modified and untracked paths are unchanged. This review is
  the only additional file.

## Verdict

**CHANGES_REQUIRED.** The Charter has the right architecture and evidence
boundary, but its execution contract is not yet total or reproducible enough
to unlock the fork. Write Charter v2 as a historical successor; do not edit v1
in place. Five bounded findings follow.

## Findings

### B1 - The kill/recharter condition leaves the known bad state unclassified

Lines 106-110 fire only when semantics hold, the provider is no longer the
largest lane, and the envelope is breached. If semantics hold, the prepared
arm breaches 180 seconds, and provider resolution remains largest, GREEN is
false, RED does not apply, INCONCLUSIVE need not apply, and the sole recharter
condition is false. That is the most likely failed optimization outcome.

Make any valid semantic arm's breach of either envelope component the single
close-and-recharter condition. Use the profile only to choose the destination:
recharter provider preparation if provider still leads; otherwise route the
new leader. While editing, fix the clock account: 82.7% of 506.98-second
`t_loop` is 419.1 seconds and the remainder is 87.9, not 98. The approximately
98-second remainder comes from full wall (516.75) minus the scaled provider
lane and must be labelled as a cross-clock estimate.

### B2 - The full-scale fixture cannot rule out a static-only optimization

Lines 61-63 say the fold fixture is regenerated from `probe.R`, but
`dev/spikes/availability-provider-preparation/probe.R` has no bars, snapshot,
or `ledgr_run()`. The actual runnable 757-pulse fold fixture is
`dev/spikes/availability-hot-path-representation/spike_runner.R` via
`spike_fixture(FIXTURES$envelope757)`.

More importantly, all 60 lists and every status/lifetime answer in that
fixture are constant. Small dynamic cases can prove correctness but cannot
expose a prepared resolver whose cost degrades with event count at full scale.
Cite the runnable source exactly and add one deterministic 757-pulse eventful
provider pass, with constant axis width and public synthetic facts, to the
existing provider-only decomposition. It need not be another full fold or a
third arm. This closes the static-specialization loophole without discarding
the registered fold control.

### M1 - The option does not select the prepared arm on parallel workers

Lines 27-30 claim a process-local R option is shared by sweep and walk-forward
workers. `ledgr_parallel_worker_setup()` starts mirai processes and
`ledgr_parallel_ledgr_load_expr()` transfers source path and `.libPaths()`
only (`R/parallel-workers.R:159-211,289-308`). It transfers no options. A worker
can therefore silently run the default current arm while the controller says
prepared.

Either remove parallel workers from this spike's claimed scope, or define a
bounded arm-selection propagation plus an evidence field proving which arm
each worker used. Do not let an unobserved default satisfy parity.

### M2 - `ledgr_facts_resolve()` is only a membership/session reference

Lines 39-40 correctly identify its direct membership resolver, but lines
85-87 then require complete decision and execution answers to compare to it.
`R/availability-inspection.R:96-137` resolves only membership or sessions; it
does not return status, lifetime, terminal events, restrictions, held state,
or either provider view shape.

Keep full-view parity arm-to-arm. Use `ledgr_facts_resolve()` only for the
membership component and its public evidence rows at shuffled/repeated
cutoffs.

### M3 - The Charter contains two literal research questions

The operative question ends at line 14, but the prerequisite is restated as a
second question at lines 16-19. The file therefore contains two question marks
despite `spike_protocol.md` section 2 and the claimed one-question structure.
Restate the already-answered prerequisite declaratively.

## Verified non-findings

- There are exactly two implementation arms; collapse is correctly confined
  to an implementation detail.
- The 180-second and 1,024-MiB alternative envelope is meaningfully tighter
  than the completed writer spike and is not presented as a product promise.
- The semantic categories cover the main point-in-time contracts without
  pre-authoring witness rows, and generated cases remain capped at ten.
- The three executor deliverables, 1,500-line harness budget, 500-line
  correction stop, and later Section 7 rerun/gut/diff review are present.
- No provenance ledger, schema change, public API redesign, licensed fixture,
  third arm, or production authorization entered the Charter.

## Required next step

Claude should write
`rfc_availability_hot_path_representation_v0_2_0_x_provider_spike_charter_v2.md`
and change only what these five findings require. Preserve Charter v1 and this
review. Return v2 for the second and final pre-execution structural review.
Stop before implementation, execution, RFC-index changes, commit, or push.

CHARTER_REVIEW_DISPOSITION: CHANGES_REQUIRED
