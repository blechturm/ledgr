# RFC: Public API And Representation-Boundary Hardening

**Status:** Seed v1, staged as design preservation; not ready for response.
No decisions or implementation are authorized by this document.

**Date:** 2026-09-09

**Author:** Codex. Response should use a different author under the RFC cycle.

**Proposed window:** v0.2.0, coordinated with the accepted asset-availability
work. This names a planning window, not an approved release packet.

**Source baseline:** remote `v0.1.9.8` at
`c78ab4fc69c32163a4ea96170771ccb3a9ee4cdc`; package version `0.1.9.7`.

**Evidence limitation:** R/Rscript is unavailable in the drafting environment.
No new package execution, fault injection, or timing measurement was performed.
The [spike protocol](../spike_protocol.md) requires an executable probe before
design progression. This requested draft preserves proposals pending that
prerequisite; source observations below are not runtime findings. Section 9
names the single readiness condition for opening response-stage work.

## 1. Problem And Intended Outcome

Make the ordinary research workflow easier to learn and the implementation
safer to change before adding availability semantics. Success means a user can
create an experiment, inspect its results, select explicitly, promote, and
reopen without learning storage internals; a maintainer can locate the owner
of an accounting, identity, or lifecycle invariant without reading one large
coordinator. Fewer files or exports alone would establish neither outcome.

The [September 4 horizon entries](../horizon.md) record API discoverability,
vignette, and representation-boundary concerns. The
[initial test audit](../audits/v0_2_0_test_suite_audit.md) traces uneven protection
of fee conservation, causality, row-operation identity, and resource cleanup.
Its source-confirmed gaps and pending experiments must remain distinguished.
Existing CI success is a baseline, not evidence that these proposals work.

Source inspection identifies mixed responsibilities in `R/backtest.R`,
`R/sweep.R`, and `R/backtest-runner.R`. In particular, `ledgr_run_fold()` is
the committed-run coordinator; it is distinct from the shared pulse engine
in `R/fold-engine.R`. The latter already has execution-spec, pulse-plan, risk,
cost, and output seams. This RFC should strengthen that structure.

## 2. Binding Inputs And Scope

- [Current contracts](../contracts.md): sealed snapshots, causal execution,
  one fold core, full named targets, canonical events, read-only inspection.
- [Accepted naming synthesis](rfc_api_naming_consistency_v0_1_9_5_synthesis.md):
  family-first names and its explicit public exceptions remain the baseline.
- [Research workflow synthesis](rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md)
  and [vignette styleguide](../vignette_styleguide.md): teach artifact ownership
  and concrete tasks using the existing workflow.
- [Accepted availability synthesis](rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md):
  its semantics are settled inputs; its Sections 14-15 own implementation
  obligations and unresolved representation choices.
- [Roadmap](../ledgr_roadmap.md), [test audit](../audits/v0_2_0_test_suite_audit.md),
  and [RFC cycle](../rfc_cycle.md): planning, evidence, and decision process.

In scope: API classification and narrow accessor decisions, result/identity
boundaries, resource ownership, cohesive modules, coordinator extraction,
focused regression strengthening, and teaching the resulting public path.
Out of scope: a new execution engine, broad renaming, package splitting,
availability policy redesign, storage-shape selection, imputation/ML APIs,
OMS, financing, corporate-action settlement, and general CI redesign.

## 3. Recommended API Shape

Retain snapshot → experiment → run/sweep → inspect → explicit candidate
selection → promotion → reopening as the recommended workflow. Walk-forward
remains a consumer of run/sweep, not an alternative execution architecture.
Require explicit cost, timing, and metric assumptions where current contracts
require them; shorter examples must not introduce hidden research defaults.

Use four documentation tiers. Each export gets one primary reference placement
and may be cross-linked elsewhere; tiers introduce no new runtime modes.

| Tier | User task | Representative surface |
| --- | --- | --- |
| Workflow | Run and review a research experiment | Snapshot convenience constructors, `ledgr_experiment`, `ledgr_run`, `ledgr_sweep`, `ledgr_results`, `ledgr_sweep_review`, `ledgr_candidate`, `ledgr_promote`; walk-forward as the next chapter |
| Construction and authoring | State assumptions and write strategies | Feature/strategy grids, indicators, costs, risks, metric context, target helpers, documented `ctx` accessors |
| Advanced inspection | Inspect saved evidence and diagnose a result | Run/sweep/walk-forward readers, return panels, diagnostics, promotion context, streaming fills |
| Infrastructure and development | Build sources, debug features, recover stores | Adapters, indicator registration, precompute/cache controls, preflight, schema validation, explicit recovery tools |

`_pkgdown.yml` already groups functions; refine its entry path instead of
claiming grouping is absent. Keep `NAMESPACE` and `test-api-exports.R` as the
export manifest and independent lock. The eventual packet records each export
as retain, add, change, or remove with its rationale; do not create another
registry or set an export-count target. Existing exports default to retain.

| Surface | Proposed disposition |
| --- | --- |
| `ledgr_run`, `ledgr_sweep`, `ledgr_walk_forward`, `ledgr_candidate`, `ledgr_promote` | Retain names and roles. Ranking/filtering never silently selects or promotes. |
| `ledgr_results` | Retain the closed `equity`, `returns`, `fills`, `trades`, `ledger` table contract and canonical `as_tibble()` dispatch. No metric catch-all. |
| `ledgr_run_fills` | Retain the explicit streaming surface; document cursor ownership and eager/lazy behavior, including empty-result classes and threshold-driven changes of return type. Validate arguments consistently before empty-result shortcuts. |
| `ledgr_promotion_context`, `ledgr_run_promotion_context`, `ledgr_metric_context` | Reuse existing readers; teach source-selection context separately from committed-run metric context. Do not add a duplicate promotion inspector. |
| `ledgr_backtest` | Retain the accepted lower-level convenience wrapper; use the experiment path for the primary research narrative. |
| `ledgr_db_init`, `ledgr_state_reconstruct`, `ledgr_backtest_bench` | Retain the explicitly accepted recovery/developer roles. Recovery writes must be clearly distinguished from inspection. |
| `ledgr_target_values(x)` | Propose one additive, names-preserving plain-vector reader; response must challenge whether a documented base-R operation is sufficient. |

The proposed target reader accepts a `ledgr_target`, returns a plain named
numeric quantity vector in the same order, and leaves the source unchanged.
It removes wrapper metadata without rescaling, filling, dropping zero targets,
or changing the axis. It is not a general coercer for signals or weights.
Existing documented field access and ordinary numeric indexing remain valid
authoring concepts; do not require a getter for every list field or scalar.
The concrete teaching lead is the `unclass(target)` extraction in
`vignettes/strategy-authoring-tools.qmd`; the probe must establish whether this
needs an accessor or only a better example before the addition is accepted.

## 4. Usability And Explainability Contract

The revised quickstart should execute a small sealed synthetic dataset through
the recommended path using exported functions and documented fields only.
The research workflow should extend it through save/reopen and one explicitly
selected promotion. Walk-forward teaching adds fold selection and opening-state
policy without changing that vocabulary. Reuse existing fixtures and examples.

Teach who owns each snapshot, run handle, and fills cursor, when to close it,
and what operations return a value, require reassignment, or write an artifact.
Register cleanup at acquisition; an example must not rely on a finalizer or a
later chunk to release its resources. Demonstrate deliberate reopening rather
than teaching ordinary reads through an already-closed handle.

Default print output should answer what ran, over which horizon, with what
status, and what to inspect next. Detailed hashes and provenance belong in
readers. Preserve raw numeric units in tables; format percentages only for
display. Errors retain typed classes and identify the offending argument or
asset and the remedy where known. Never hide failed/incomplete candidates to
make a report cleaner; never manufacture an explanation from absent evidence.

The availability RFC owns `ledgr_run_explain()` and its persisted evidence.
This RFC aligns documentation and result ownership with that accepted surface;
it does not add another explanation framework. Repair stale vignette examples
identified by the horizon only after checking them against the current API.

## 5. Internal Ownership Proposal

Each module owns an invariant family. Reuse existing cohesive files where
possible; these proposed file boundaries are internal and may be consolidated
when dependencies justify it. Avoid a generic `utils.R` or a file per helper.

| Responsibility | Proposed owner / destination | Invariant |
| --- | --- | --- |
| Public construction and delegation | `backtest.R`, `sweep.R` | One normalized request enters the existing shared execution path |
| Handle and cursor lifecycle | `backtest-handle.R`, fill cursor implementation; existing store helpers | Borrowed versus owned connections, explicit close, cleanup on error |
| Tables, fills, metrics, presentation | `backtest-results.R`, `backtest-fills.R`, `backtest-metrics.R`, `backtest-print.R` | Stable table schemas; fees and quantities reconcile; display cannot alter economics |
| Candidate and sweep dispatch | `sweep-candidate.R`, `sweep-dispatch.R`; existing parallel helpers | Selection identity and sequential/parallel semantics agree |
| Memory output and sweep rows | `sweep-memory-output.R`, `sweep-result-schema.R`; existing persistence/retention files | Output buffering, row construction, restoration, and serialization preserve evidence |
| Run registration and snapshot preparation | `run-registration.R`, `run-snapshot.R`; existing snapshot-source helpers | Resume identity cannot drift; snapshot trust and coverage checks retain their owner |
| Resume and persistent output | `run-resume.R`, `run-output.R`; existing run-store helpers | Transactional tail cleanup, checkpoints, event/projection reconciliation |
| Committed-run coordination | `backtest-runner.R` | Explicit phase dependencies and cleanup order |
| Pulse execution | Existing `ledgr_execute_fold()` in `fold-engine.R`, execution-spec, risk/cost/accounting helpers | One causal strategy-to-fill transition for every supported execution path |
| Features and hydration | Existing feature engine/cache modules; extracted sweep feature helpers if needed | Causal histories, alias alignment, and cache identity remain consistent |

For `ledgr_run_fold()`, extract cohesive preparation, registration, snapshot,
resume, execution-setup, and finalization responsibilities while preserving the
observed dependency order. Do not reorder guards, the completed-run shortcut,
schema operations, transaction boundaries, or error-status writes as a side
effect of extraction. An existing behavior that conflicts with a contract
needs a separately evidenced correction, not preservation disguised as a fix.

Phase helpers receive explicit inputs and return the values needed downstream.
Retain mutable state where connection ownership or output buffering requires
it; do not move the coordinator into one shared mutable environment. Reuse the
existing execution-spec and output-handler contracts. No generic stage engine,
new plugin pipeline, or per-asset abstraction layer is proposed. Keep setup
validation outside the hot loop where current trust boundaries permit it.

## 6. Representation Invariants And Audit Disposition

One implementation owner should maintain each row/schema conversion, with
independent test expectations at its boundaries. Sharing production helpers
between two paths cannot by itself prove the shared calculation correct.

| Concern / evidence lead | Proposed obligation and owner |
| --- | --- |
| Reversal fees, audit T-1 | Fill projection owns allocation. For each source event, projected fees sum to its fee; cash and PnL reconcile separately. Specify allocation before blessing row-level expectations; do not interpret reversal fixtures as financing support. |
| No-lookahead, T-2 | Feature tests pair a causal control with a genuinely leaking series function and future-data perturbation. Disabling the diagnostic must fail its rejection assertion. The diagnostic is not a sandbox or a proof for arbitrary user code. |
| Row-operation identity, T-3 | Sweep restoration/persistence owns the complete existing research payload, including risk and cost. Supported subset/reorder/reopen operations preserve each candidate's identity; removal or contradiction of required metadata fails clearly instead of silently assuming defaults. |
| RNG temporary names, horizon lead | Infrastructure naming must not consume caller/strategy random draws. Preserve declared execution seeding semantics; a filename fix is not a new RNG policy. |
| Wide projection collisions, horizon lead | Retention projections own lossless candidate-to-column mapping. Reserve structural columns and use deterministic reversible escaping plus an explicit mapping for conflicts; never overwrite `ts_utc` or change candidate identity. |
| Streaming argument validation, horizon lead | Fills reader owns a scalar logical `lazy` and a finite, non-negative, integer-valued threshold within supported range, checked before empty-result shortcuts. Zero means any positive fill count exceeds the threshold. Reject invalid inputs with typed errors. |
| Cleanup and warnings, T-4 | Resource owners register cleanup immediately; tests assert expected warning classes rather than broadly muffling warnings. Separate base row-operation tests from optional dplyr availability. |
| Documentation checks, T-5 | Keep locks on public names, units, required methodological disclosures, and executable examples. Replace editorial text locks selectively; moving code must not require preserving obsolete explanatory prose. |

These are proposed hardening obligations, not eight completed experiments or
a new witness registry. Start with the audit's existing suites and append
measured results to the audit. Confirm operation-specific behavior before
choosing fixes. Keep narrowly evidenced correctness changes separate from
mechanical moves, so historical bugs do not become the equivalence oracle.
Fee projection repair must not silently redefine lot cost basis, realized PnL,
or trade metrics merely to make projected rows reconcile.

## 7. Compatibility And Availability Boundary

Mechanical moves preserve function formals/bodies initially, public classes,
numeric schemas, event order, error classes, and resource behavior. Test
economic equality and identity under the same engine/serialization versions;
do not demand unchanged incidental timestamps or hashes whose declared input
includes a changed package version. Any intentional schema, hash, argument, or
economic correction needs an explicit before/after example and disposition of
maintainer-owned saved artifacts. Pre-CRAN status does not erase that cost.

Document tiers and a target reader do not authorize removing exports, aliases,
or recovery support. Renames/removals require their own evidence and accepted
decision in this cycle; the starting proposal contains none. Keep supported
base and dplyr transformations distinct from arbitrary external coercions that
discard class/provenance and are no longer promotable research artifacts.

Availability will change the decision axis to members plus holdings, separate
valuation from execution, retain incomplete evidence, and permit the accepted
empty-axis behavior. Do not harden the current dense/nonempty assumption into
a new public wrapper or generic validator. Its legacy-mode requirements remain
qualified by mode. No future identifiers or execution evidence enter strategy
context through a new accessor. Storage representation and imputation remain
the availability packet's open/deferred work, not prerequisites for these moves.

## 8. Alternatives And Proposed Implementation Order

**A: Documentation plus mechanical file moves.** Lowest immediate change risk;
improves navigation but leaves representation invariants and phase coupling
without explicit ownership. Choose this if the probe shows no additional work
is needed and a cohesive move already gives each contract a clear owner.

**B: Targeted API hardening plus owned phase extraction (recommended).** Retain
the workflow, decide the narrow accessor question, strengthen/fix demonstrated
boundaries, then move code unchanged before extracting coordinator phases.
The benefit must be demonstrable ownership and simpler callers, not line count.

After the probe and accepted cycle, establish the corrected regression baseline
before mechanical moves; extract phases in separate reviewable changes.
Implement availability semantics afterward against those owners. This ordering
does not require unrelated diagnostic, CI, or whole-package cleanup first.
Use existing release checks and benchmark workloads for impacted paths, with
paired baseline/refactor runs under the same data, mode, cache state, and
environment. Investigate repeatable regressions beyond measured baseline noise
before accepting them; this RFC promises no speedup or new peer ranking.

## 9. Next Evidence And Response Brief

**Readiness condition:** execute and record the prerequisite probe before
requesting a response. Its question is: *does the documented public workflow
provide the access needed for safe selection and promotion, or does it require
new public surface?* Exercise the existing quickstart/research path, including
target extraction and a nondefault-risk candidate carried through supported
row operations and reopening. Record surprises rather than prewriting results.

Use `dev/spikes/api-representation-hardening/probe.R` and a one-page
`probe_findings.md`. Follow the spike protocol: smallest runnable example,
at most ten initial cases, existing ledgr identity primitives, no harness
registry. If the workflow cannot produce a trustworthy baseline because an
existing correctness defect intervenes, stop the refactor comparison and
resolve that cheaper prerequisite. A comparative architecture spike is not
automatically required. Any subsequently chartered fork follows the protocol's
runner, diff checker, and deliberately broken-path demonstration requirements.

The different-author response should address at most these five questions:

1. Does the proposed first path reduce actual user decisions, and is the target
   reader needed beyond documented numeric indexing/coercion?
2. Do the module owners remove concrete coupling while preserving lifecycle,
   transaction, resume, and completed-run behavior?
3. Can independent checks catch fee, causality, or identity defects that parity
   alone would preserve, without growing a second test framework?
4. Are compatibility costs and read/write boundaries understandable from public
   examples, including streaming and saved artifacts?
5. Can the accepted availability behavior land without undoing these boundaries
   or importing its storage/ML decisions into this RFC?

Record disagreements and evidence in the response; use seed v2 only if findings
warrant it. Acceptance belongs to synthesis and the later spec packet, not this
staged proposal. The next action is the small runtime probe, not implementation.
