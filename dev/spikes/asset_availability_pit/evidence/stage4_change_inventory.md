# Stage 4 Shared-Fork Inventory

**Status:** Complete after independent review on 2026-09-08.

**Executor:** Codex, by maintainer substitution. Claude independently reviewed
the implementation, required three Medium corrections, and accepted the
corrected comparison with no remaining High or Medium findings.

## What Survived

- One `stage4_run_case(provider, case_spec)` execution entry point.
- Three representations behind fact, decision-view, execution-view, history,
  serialization, and inventory methods.
- Policy-v4 target validation, ordered no-fill reasons, affordability,
  stale-mark exhaustion, and evidence status.
- Stage 3 FIFO, max-weight, status-resolution, carry-forward, and rolling-mean
  semantics called directly rather than reimplemented.
- W21 as the real ledgr package control, with ledgr snapshot and config hashes.
- W20 direct, serialized-restore, and PSOCK paths. The PSOCK worker runs the
  shared fork itself.
- One pass of M1-M5 through the new fork.

The recorded run executes ten witnesses through all three providers and checks
1,245 of 1,506 frozen field values or identity relations. All pass. W02's
`c0a` and `c0b` rows execute through the existing package control. Nine of the
ten executable witnesses check every frozen row.

W20 checks 121 of 208 frozen rows per provider. Its 87 unchecked rows are the
retired `cold`, `warm`, and `seq` paths. Stage 4 keeps only `direct`, serialized
`restore`, and PSOCK `par`, as required by the redirection. The conformance CSV
records `checked_fields`, `expected_fields`, and `unchecked_fields` for every
provider/witness pair. The five mutations all fail conformance on their
intended fields.

## What Was Demoted

The frozen registry retains all 31 approved witness records and remains
unchanged. Stage 4 owns its role classification: W02, W03, W06, W07, W09, W20,
W21, W22, W24, and W25 are executable. The remaining 21 are labelled
`policy_example` because this bounded fork does not execute their complete
stories. Some rules overlap executable witnesses, but Stage 4 does not claim
coverage of W04, W23, W31, or any other demoted witness from that overlap.

Demotion is evidence discipline. A policy example is still an approved design
example, but it is not counted as representation conformance.

## What Was Deleted

- Witness-specific core, lifecycle, and representation evaluators.
- W20 cold, warm, sequential, and path-sensitivity matrices.
- Provider-identity and graph/cache mutation grids.
- The stale-purchase probe, workflow journeys, process-memory snapshot, and
  comprehension CSVs.
- The Stage 4 code registry, ancestry gate, frozen-hash ledger, clean-workspace
  rule, file tripwire, and review/gate checker modes.

The redirected Stage 4 keeps one shared policy fork and seven supporting files.
It remains materially smaller than the discarded ten-file, 3,484-line attempt;
the added lines in this review close frozen-table coverage rather than add a
second execution path or governance framework.

## Representation Evidence

W20 inventories direct and restored providers. The temporary-row counts mostly
measure each Stage 4 adapter's row-flattening and hydration work, not an
intrinsic property of the underlying representation. They are structural
accounting for Stage 5 design, not performance measurements.

| Provider | Retained shape | Direct retained bytes | Serialized bytes |
| --- | --- | ---: | ---: |
| Dense state planes | 11 objects | 118,192 | 26,236 |
| Dynamic active matrices | 1 object | 12,616 | 8,697 |
| Sparse fact materializer | 2 objects | 24,816 | 13,107 |

## Package Facts Learned

- The dense package control preserves the declared instrument order in fills;
  feasibility ordering therefore cannot also dictate event emission order.
- W21 reproduces package fills, post-risk targets, FIFO state, cash, equity,
  realized P&L, and final-bar no-fill behavior from provider-recovered rows.
- Held non-members must remain on the opening/decision axis; W24 and mutation M3
  make that requirement executable.
- A stale valuation mark may support valuation and a reducing risk step, but it
  must not stand in for a missing execution price; W22 and mutation M1 keep the
  distinction executable.
- The existing package does not provide identities for prototype provider
  representations. Those values are labelled `proto:` once; no parallel hash
  governance system is maintained.

## Boundary

No package runtime, API, tests, manual pages, or `inst/design` file changed.
Stage 4 contains no timing primitive and does not select a representation.
Its result is evidence for the later architecture synthesis, not mergeable
production code.
