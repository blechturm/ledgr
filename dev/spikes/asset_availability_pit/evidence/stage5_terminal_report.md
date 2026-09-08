# Stage 5 Terminal Report

**Status:** Independently reviewed terminal outcome. Complete.

**Outcome:** Inconclusive.

**Date:** 2026-09-08.

**Author:** Codex, the maintainer-substituted Stage 3 and Stage 4 executor.

**Independent reviewer:** Claude, who did not execute the prototype stages.

## 1. Verdict

The spike established a useful but narrower result than its charter asked for.
One representation-neutral provider seam supplied three physical
representations to one shared policy fork for ten executable witnesses. All
three representations passed the same 415 checked frozen values or identity
relations, for 1,245 checks in total, and all five deliberate checker
mutations were rejected.

The spike did not establish a representation winner. Twenty-one of the 31
frozen witnesses remained policy examples rather than executable conformance
checks. The missing set includes future-fact perturbation, positional-state
invalidation, revision handling, incomplete-selection behavior, calendar and
age semantics, aliases, and consumer-specific missingness. The redirected
Stage 4 also did not build the empirical-shape workload, user journeys, or
diagnostic-retention tiers required by the charter.

No prototype was therefore eligible for performance ranking. Stage 5 records
no timing, peak-RSS, cache, parallel-replication, or retention-cost claim.
Green would overstate partial conformance; red would misstate three passing
partial implementations. The charter's inconclusive outcome is the honest
result.

Seed v2 may consume the proven semantic boundary and the open questions. It
must not describe dense state planes, dynamic active matrices, or the sparse
fact materializer as a measured production choice.

## 2. Authority And Frozen Boundary

The comparison remained bound to:

- package base commit `1f42cf7`;
- policy `asset_availability_initial_policy_v4`;
- witness contract `asset_availability_witness_v3`;
- the 31-row approved `witness_registry.csv`;
- the LF-normalized hashes in `frozen_hashes.csv`;
- Stage 3 reviewed implementation commit `d7a1fd3`;
- Stage 3 gate-record commit `093e946`; and
- redirected Stage 4 commit `1f7c24a`.

The reviewed terminal report is anchored at
`f80472ab755fad95b18e338ffcf7d693064b1d20`.
No package runtime, package test, public API, manual page, or `inst/design`
file changed after the package base commit.

## 3. Evidence Roles

The result uses three evidence roles:

| Role | Meaning |
| --- | --- |
| `package_control` | A result executed through the current ledgr package |
| `fork_derived` | A result computed by the shared disposable fork |
| `fixture_input` | A frozen policy example shown but not executed |

`fixture_input` is not conformance evidence. A policy example can describe an
accepted rule without proving that any provider or the fork implements it.

The Stage 4 conformance file contains 30 provider-by-witness summary rows:
three providers by ten executable witnesses. Nine executable witnesses check
their complete frozen tables. W20 checks 121 of 208 rows per provider; its 87
retired `cold`, `warm`, and `seq` rows remain disclosed as unchecked.

## 4. Semantic-Oracle Conformance

The following table separates the 26 semantic oracles from the five
representation-discriminating witnesses. A single status applies to all three
providers. `PASS` means the emitted fields matched the frozen table. `NOT RUN`
means Stage 4 emitted only the registered fixture path as `fixture_input`.

| Witness | Dense | Dynamic | Sparse | Coverage per provider |
| --- | --- | --- | --- | ---: |
| W01 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W02 | PASS | PASS | PASS | 57 / 57 |
| W03 | PASS | PASS | PASS | 17 / 17 |
| W04 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W05 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W06 | PASS | PASS | PASS | 26 / 26 |
| W07 | PASS | PASS | PASS | 18 / 18 |
| W08 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W09 | PASS | PASS | PASS | 27 / 27 |
| W10 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W11 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W12 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W13 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W14 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W15 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W16 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W19 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W22 | PASS | PASS | PASS | 44 / 44 |
| W23 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W24 | PASS | PASS | PASS | 15 / 15 |
| W26 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W27 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W28 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W29 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W30 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W31 | NOT RUN | NOT RUN | NOT RUN | 0 |

Seven of 26 semantic oracles executed. Nineteen remained policy examples.

## 5. Representation-Discriminating Conformance

| Witness | Dense | Dynamic | Sparse | Coverage per provider |
| --- | --- | --- | --- | ---: |
| W17 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W18 | NOT RUN | NOT RUN | NOT RUN | 0 |
| W20 | PASS | PASS | PASS | 121 / 208 |
| W21 | PASS | PASS | PASS | 58 / 58 |
| W25 | PASS | PASS | PASS | 32 / 32 |

Three of five representation-discriminating witnesses executed. W17 and W18
did not test causal invariance or stale positional-state rejection. W20 did
test direct, serialized-restore, and PSOCK paths, but no longer tested the
retired cold, warm, and sequential cache paths.

## 6. Checker Mutations

Every Stage 4 mutation began from a passing baseline and caused conformance to
fail on the intended fields.

| Mutation | Witness | Defect | Rejected fields |
| --- | --- | --- | --- |
| M1 | W22 | Stale valuation used as execution evidence | `execution_bar_available`, `fill_price` |
| M2 | W09 | Superseded halt left active | `resolved_status`, `fill_status` |
| M3 | W24 | Held non-member omitted at reopen | `opening_axis`, `held_qty`, `held_nonmember_count` |
| M4 | W25 | Fit identity omitted its population | `fit_identity` |
| M5 | W02 | Funding sale credited but not applied | fill, position, cash, and reconciliation fields |

This proves sensitivity for the five named defects. It does not substitute for
execution of the 21 policy examples.

## 7. Representation Diagrams

The semantic table comes first because physical shape has no value if it
changes the accepted result.

```text
frozen effective-dated facts
            |
            v
  representation provider
    | decision view
    | execution view
    | bounded history
    | fact and identity recovery
            |
            v
 one shared Stage 4 policy fork
            |
            v
 typed evidence -> frozen-table checker
```

The three retained shapes were:

```text
dense_state_planes
  fixed superset matrices by case and field + scalar records

dynamic_active_matrices
  one effective-dated row table -> pulse-local filtered frames

sparse_fact_materializer
  sparse fact rows + exact-key index -> bounded hydration
```

All three used the same provider generics and the same `stage4_run_case()`
entry point. Representation-specific code did not own targets, risk closure,
fill policy, affordability, FIFO accounting, or evidence interpretation.

## 8. Structural Accounting, Not Measurement

W20 recorded retained R object size and serialization size. These are small
fixture structural observations, not workload measurements.

| Provider | Retained objects | Retained bytes | Serialized bytes |
| --- | ---: | ---: | ---: |
| Dense state planes | 11 | 118,192 | 26,236 |
| Dynamic active matrices | 1 | 12,616 | 8,697 |
| Sparse fact materializer | 2 | 24,816 | 13,107 |

The temporary-row and temporary-byte counters mostly measure Stage 4 adapter
flattening and hydration. For example, the dense and sparse decision-view
methods reconstruct row views that a production implementation would not
necessarily allocate. Ranking representations from these counts would rank
prototype adapters, not the underlying architecture.

No result exists for:

- the required `500 x 750` or larger empirical-shape workload;
- near-dense, moderate, and low occupancy;
- smooth versus bursty membership change;
- actual rolling plus cross-sectional feature work at scale;
- cold and warm materialization with rotated repetitions;
- per-fold, per-candidate, or per-pulse timing;
- peak process RSS or worker replication;
- cache-key counts and invalidation cost; or
- minimal versus detailed diagnostic-retention cost.

The measurement bundle is therefore intentionally absent.

## 9. Why No Prototype Was Timed

The charter permits measurement tables or an explicit reason no prototype was
eligible. The latter applies.

| Timing prerequisite | Result |
| --- | --- |
| Frozen expected evidence approved before timing | PASS |
| Shared fork and three provider representations | PASS |
| Dense package control and checker sensitivity | PASS for implemented subset |
| W01-W31 conformance classified by prototype | PARTIAL: 10 run, 21 not run |
| Future-fact and positional-cache discrimination | NOT RUN |
| Empirical-shape workload and scalable full-fork path | NOT BUILT |
| User journeys and comprehension check | NOT RUN |
| Diagnostic-retention tiers | NOT BUILT |

Timing after the redirected Stage 4 would have violated the rule that only
semantic survivors are measured. It also would have encouraged a false choice
from provider methods designed for small exact witnesses rather than scale.

## 10. Causality And Identity Perturbation

| Question | Evidence | Result |
| --- | --- | --- |
| Do providers recover the same Stage 4 inputs? | Cross-provider recovered-fact identity assertion | PASS; policy examples contain only their registered fixture path |
| Do direct, restore, and PSOCK recover the same W20 evidence? | W20 path checks | PASS for retained paths |
| Does the dense fork match current ledgr behavior? | W21 package control | PASS on the compact control |
| Does fit identity include the estimation population? | W25 and M4 | PASS; omission rejected |
| Do transform orderings have distinct graph identity? | W25 | PASS |
| Are earlier outputs invariant to future facts? | W17 | NOT RUN |
| Is stale positional state rejected after an axis change? | W18 | NOT RUN |
| Do cache descendants invalidate while unaffected ancestors remain? | Full W25 cache path | PARTIAL |

Prototype identities are labelled `proto:` except where W21 reports actual
ledgr snapshot and configuration hashes. They are evidence labels, not a new
package identity system.

## 11. Explainability And Workflow Evidence

The executed subset exposes reason-coded evidence for membership plus held
axes, target restriction, stale valuation, max-weight behavior, fill or
no-fill outcomes, affordability, cash, positions, and incomplete evidence.
Those rows demonstrate that the provider seam can support an explanation
chain for the tested cases.

The charter's three connected user journeys were not implemented after Stage
4 was redirected. A blind five-question comprehension exercise was run against
the discarded first Stage 4 attempt: all five predictions matched the key,
one answer was locatable without a manual join, and question 3 exposed a
missing diagnostic. That result belongs to the preserved failed-attempt
record. No equivalent exercise was run against the redirected implementation.
No current result therefore supports a claim about redirected discoverability,
manual joins, effective-plan printing, or retention tiers. Seed v2 should use
the proposed workflow in the response as a design input, not as tested UX.

## 12. Failures, Repairs, And Effort

Stage 3 preserved corrections for pre-prototype gate use, package-control
construction, fee-net FIFO evidence, surplus evidence, fractional max-weight,
and affordability reconciliation. The complete record is
`stage3_change_inventory.md`.

The first Stage 4 attempt grew to ten files and 3,484 added lines while mixing
witness-specific evaluators, governance duplication, workflow exercises, and
measurement scaffolding. The maintainer stopped it before commit. The reviewed
redirect retained one shared fork and seven support files. Commit `1f7c24a`
added 2,647 lines across 17 files, including evidence and documentation.

Provider code is centralized in `stage4/providers.R`. Each representation has
one builder and methods for the common fact, decision-view, execution-view,
history, and inventory interface. Sparse hydration is an additional
representation method. No provider-specific semantic failure survived the
reviewed run; the shared limitation is incomplete witness and workload scope.

Implementation effort was not tracked per prototype because all three
adapters share the same row-scan helpers and policy fork. The shapes below are
code inventory, not comparable effort estimates.

| Provider | Representation-specific implementation shape |
| --- | --- |
| Dense state planes | Builder, plane constructor, and five interface methods |
| Dynamic active matrices | Builder and five interface methods over one row table |
| Sparse fact materializer | Builder, key index, bounded hydrator, and five interface methods |

The three providers are not marked disqualified. They are marked ineligible
for ranking because the experimental design stopped before the charter's
semantic and workload gates. This distinction prevents a scope reduction from
being misreported as a representation defect.

## 13. Conclusions By Evidence Strength

### Semantic conclusions

- A representation-neutral provider seam can preserve one policy fork for the
  ten implemented witnesses.
- Decision views and execution views can remain separate across all three
  physical shapes.
- Held non-members can remain on the fold axis without claiming current
  membership.
- A stale valuation mark can support valuation or reducing risk without
  becoming an execution price.
- Feasibility ordering can differ from target-vector event emission while the
  final pulse still reconciles.
- Effective-time and knowledge-time status resolution can remain provider
  independent.

### Measured conclusions

None. Small-fixture object sizes are structural accounting only.

### Inferences that remain plausible

- Sparse immutable source facts plus bounded fold-local materialization remain
  compatible with the tested provider boundary.
- Dense planes may remain useful as bounded compute views even if they are not
  the canonical store.
- Dynamic pulse-local frames remain compatible with the tested boundary. The
  spike neither confirmed nor eliminated them as a separately named storage
  alternative.

These are architecture inferences, not measured selections.

### Product and architecture choices still open

- canonical storage representation and fold-local materialization shape;
- whether dynamic active matrices remain a distinct alternative;
- residual-budget and removal-policy defaults;
- direct strategy partial reductions for restricted holdings;
- the default response to an exhausted valuation horizon;
- the response to a not-knowable source row;
- price-dependent risk admissibility for unpriced targets;
- fixed-member versus broader causal estimation populations;
- one-venue calendar scope and later cross-venue pulse semantics;
- public constructors and exact context fields; and
- diagnostic retention and persistence tiers.

## 14. Empirical Limitations Carried Forward

The following limits are copied verbatim from the reviewed RFC response. This
spike did not relax any of them.

- Accepted empirical scope is only `dense_static_method_validation_v001`
  (seed 2.1; Sharadar closeout table).
- No confirmed `expected_session_absence` cell was observed (seed 2.1, 18
  row 3; Sharadar Gate 3: zero of 101).
- No imputation experiment was performed (seed 2.1; Sharadar claim ledger).
- The successful trade proof covered one instrument and zero costs (seed
  2.1; Sharadar Gate 2).
- Simultaneous multi-position and nonzero-cost behavior was not established
  (seed 2.1; Sharadar Gate 2 limitations).
- Broad-equity, dynamic-membership, dividend-inclusive, and terminal-event
  performance remain unauthorized (seed 2.2, 19; Sharadar non-conclusions).
- Vendor labels are evidence, not ledgr schema or event types (seed 2.2, 5,
  19; Sharadar census note).

The synthetic witnesses do add exact method evidence for selected semantics.
They do not convert the empirical study into a real-data ragged-universe test.

## 15. Reproduction

From repository root, with R 4.5.2 and the repository library available:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/check_stage3.R --mode=review
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/run_stage4.R
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/check.R
```

The Stage 5 author reran the Stage 3 review and Stage 4 checker on 2026-09-08.
Both passed. Stage 4 reproduced three providers, ten executable witnesses, 21
policy examples, 30 passing conformance summaries, five rejected mutations,
and byte-identical recorded CSV evidence.

The only retained environment record is
`stage3_results/environment.csv`: Windows x86-64, R 4.5.2, ledgr 0.1.9.7.
It predates Stage 4; Stage 4 and Stage 5 recorded no separate environment
bundle. Expected tables remain under `../expected/`. Stage 4 fixture
construction is in `../stage4/fixtures.R`; the frozen source tables are
embedded in the fixture manifests. The exact witnesses use no RNG, and Stage
5 created no empirical fixture or measurement seed.

## 16. Seed v2 Handoff

After independent review accepts this terminal classification, Seed v2 may:

1. bind the tested representation-neutral provider operations as an
   architecture requirement;
2. consume the tested policy-v4 semantics and exact witness outcomes;
3. preserve Seed v1's sparse-storage and fold-local-materialization direction
   as an unconfirmed prior; this spike neither confirmed nor refuted it, and
   all three representations remain compatible with the tested boundary;
4. distinguish the 10 executed witnesses from the 21 policy examples; and
5. carry the untested causal, cache, calendar, workflow, and scale questions as
   unresolved gates for specification or a separately chartered experiment.

Seed v2 must not fill the evidence gap by selecting the smallest W20 object,
timing the small witness adapters, or describing policy examples as executed.
If a measured representation choice is required before synthesis, it needs a
new bounded measurement design with a scalable common fold and the omitted
semantic gates. That is new authorization, not a continuation hidden inside
this closeout.

## 17. Non-Authorization

This report authorizes no package API, production schema, migration, runtime
mode, second engine, availability policy, accounting behavior, implementation
ticket, or representation choice. The disposable fork remains on its
non-release branch and must never merge into a release or default branch.
