# Stage 4 Shared-Fork Comparison

**Status:** Complete after independent review on 2026-09-08.

Stage 4 asks one bounded question: can three candidate data representations
supply the same policy fork without changing its decisions, fills, accounting,
or evidence? It does not select a production representation and contains no
timing work.

## Shape

`stage4_run_case(provider, case_spec)` is the only execution entry point. The
provider supplies exact facts, decision views, execution views, and bounded
history. The fork owns targets, risk closure, ordered no-fill reasons,
affordability, FIFO accounting, valuation staleness, and evidence rows.

| Provider | Retained shape | Fold view |
| --- | --- | --- |
| `dense_state_planes` | Fixed superset planes | Member-plus-held mask |
| `dynamic_active_matrices` | Effective-dated rows | Pulse-local frame |
| `sparse_fact_materializer` | Sparse facts plus index | Bounded hydration |

The frozen registry keeps all 31 approved witnesses visible and is unchanged.
Stage 4 owns the role classification. Ten witnesses are executable because
this fork can independently fail their implemented paths:

| Witnesses | Reason |
| --- | --- |
| W02, W03 | Affordability, event order, explicit retry, and no-fill behavior |
| W06, W07 | Stale-mark exhaustion and unsupported terminal settlement |
| W09 | Effective/knowledge-time status resolution |
| W20 | Direct, restore, and PSOCK provider/fork paths |
| W21 | Real ledgr dense package control plus FIFO/risk parity |
| W22 | Risk marks, stale reductions, and missing-mark failure |
| W24 | Held non-member state across a fold boundary |
| W25 | Transform ordering and fitted-artifact identity |

The other 21 are `policy_example` records. Several contain rules that overlap
an executable case, while others require data-preparation, model, selection,
calendar, alias, or consumer machinery that this bounded fork does not
implement. No overlap is reported as execution of the demoted witness itself.
Demotion avoids reporting hand-authored answers as representation conformance.

## Run

From the repository root:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/run_stage4.R
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/check.R
```

The checker reruns into a fresh scratch directory without replacing recorded
evidence, compares every recorded CSV, checks frozen-table coverage and the
three allowed evidence roles, and rejects changes under package runtime or
`inst/design` since base commit `1f42cf7`. An independent review should rerun
both commands, gut one provider fact path and confirm conformance fails, then
inspect the `evidence_role` values.

W20 records provider identity from rows recovered through each provider. W21
uses ledgr's own snapshot and config hashes with a fixed snapshot ID. Other
prototype identities are labelled `proto:` without a separate identity ledger.
Structural object sizes are accounting evidence only, not performance results.
Temporary-row counts primarily describe the adapters' flattening and hydration
work; they do not isolate representation-level memory behavior.
