# Decision Catalogue Reconciliation

**Status:** LDG-2925 migration evidence.
**Authority:** None. The destinations linked below remain authoritative.
**Baseline:** `61c00f5` on branch `v0.2.2`.

This inventory reconciles every data row in the two catalogues retired by the
accepted design-memory plan. `Bridge` means the accepted choice still awaits
consolidation and therefore appears in `inst/design/decisions.md`. `Standing`
means a current contract or process document already carries it. `Historical`
means the row describes completed implementation or explanatory provenance.
No row is resolved by paraphrasing its old summary into a new rule.

## 1. `inst/design/README.md` accepted-decision catalogue

| Old row | Disposition | Current route |
| --- | --- | --- |
| Sweep single-core optimization arc | Historical and standing | [Execution Contract](../contracts.md#execution-contract); released optimization packets |
| Multi-output indicator bundle UX | Standing | [Context Contract](../contracts.md#context-contract) |
| Metric context and risk metrics | Standing | [Result Contract](../contracts.md#result-contract) |
| Target-risk chain boundary | Standing, with the accepted OMS remainder in the bridge | [Execution Contract](../contracts.md#execution-contract); [OMS bridge](../decisions.md#oms-order-lifecycle) |
| Indicator codebase simplification | Historical | Accepted synthesis and released refactor packets |
| Active parameterized feature aliases | Standing | [Context Contract](../contracts.md#context-contract) |
| Research workflow and artifact topology | Historical teaching | Accepted synthesis and current manuals |
| Feature projection shape, materialization policy, and lookback access | Standing in part; bridge for the unconsolidated historical/read boundary | [Context Contract](../contracts.md#context-contract); [historical projection](../decisions.md#point-in-time-historical-projection); [recursive boundary](../decisions.md#recursive-indicator-boundary) |
| Primitive internals and conditional collapse acceleration | Historical implementation guidance | [Optimization manual](../manual/optimization_coding_style.md) and current contracts |
| Availability hot- and cold-path representation | Standing and historical | [Availability Contract](../contracts.md#availability-contract); v0.2.0.1 packet |
| Walk-forward evaluation | Standing, with one deferred identity rule in the bridge | [Execution Contract](../contracts.md#execution-contract); [Result Contract](../contracts.md#result-contract); [objective identity](../decisions.md#objective-filtered-walk-forward-identity) |
| Sweep artifact persistence | Standing | [Sweep Promotion Contract](../contracts.md#sweep-promotion-contract) and [Persistence Contract](../contracts.md#persistence-contract) |
| OMS semantics and order lifecycle | Bridge | [OMS bridge](../decisions.md#oms-order-lifecycle) |

Count: 13 old rows reconciled to 13 dispositions.

## 2. `inst/design/rfc/README.md` Topic Decision Index

| Old row | Disposition | Current route |
| --- | --- | --- |
| Testing architecture | Standing process | [RFC cycle](../rfc_cycle.md), test control plane and claims registry |
| Equity corporate actions | Standing | [Availability Contract](../contracts.md#availability-contract), [Execution Contract](../contracts.md#execution-contract) and [Result Contract](../contracts.md#result-contract) |
| Accounting-core consolidation | Standing and historical | [Execution Contract](../contracts.md#execution-contract) and accepted synthesis |
| Post-v0.2.0.1 governance loop | Standing process | [RFC cycle](../rfc_cycle.md) and `AGENTS.md` |
| Design-governance process | Standing process | [RFC cycle](../rfc_cycle.md) |
| Sweep candidate contract and promotion | Standing | [Sweep Promotion Contract](../contracts.md#sweep-promotion-contract) |
| Parallel sweep dispatch | Standing | [Execution Contract](../contracts.md#execution-contract) and sweep manual |
| Single-core optimization arc | Historical and standing | [Execution Contract](../contracts.md#execution-contract) |
| Runtime projection and feature artifacts | Standing in part; bridge for pending history | [Context Contract](../contracts.md#context-contract); [historical projection](../decisions.md#point-in-time-historical-projection) |
| Pulse-context data model | Standing | [Context Contract](../contracts.md#context-contract) |
| Snapshot trust boundary | Standing | [Snapshot Contract](../contracts.md#snapshot-contract) |
| Strategy callback accessor addendum | Standing | [Context Contract](../contracts.md#context-contract) |
| Strategy authoring helpers | Standing | [Strategy Contract](../contracts.md#strategy-contract) |
| Active parameterized feature aliases | Standing | [Context Contract](../contracts.md#context-contract) |
| Multi-output indicator UX | Standing | [Context Contract](../contracts.md#context-contract) |
| Indicator simplification and determinism | Historical | Accepted synthesis and released refactor packets |
| Primitive internals and collapse | Historical implementation guidance | [Optimization manual](../manual/optimization_coding_style.md) |
| Availability hot- and cold-path representation | Standing and historical | [Availability Contract](../contracts.md#availability-contract); v0.2.0.1 packet |
| B2 compiled hot frame | Standing current boundary | [Execution Contract](../contracts.md#execution-contract) |
| API naming consistency and surface tightening | Standing except four bridge gaps | [Public Naming Contract](../contracts.md#public-naming-contract); [execution-window](../decisions.md#execution-window-minimum); [fill validity](../decisions.md#fill-transition-validity); [cost order](../decisions.md#cost-rounding-and-fees); [override](../decisions.md#walk-forward-snapshot-override) |
| Validation toolkit | Standing in part; bridge for deferred D4 identity | [Result Contract](../contracts.md#result-contract); [objective identity](../decisions.md#objective-filtered-walk-forward-identity) |
| Public transaction-cost model | Standing | [Execution Contract](../contracts.md#execution-contract) |
| Metric context and risk-free assumptions | Standing | [Result Contract](../contracts.md#result-contract) |
| Target-risk / OMS policy boundary | Standing in part; bridge for OMS | [Execution Contract](../contracts.md#execution-contract); [OMS bridge](../decisions.md#oms-order-lifecycle) |
| OMS order lifecycle | Bridge | [OMS bridge](../decisions.md#oms-order-lifecycle) |
| Walk-forward evaluation | Standing, with deferred D4 identity in the bridge | [Execution Contract](../contracts.md#execution-contract); [Result Contract](../contracts.md#result-contract); [objective identity](../decisions.md#objective-filtered-walk-forward-identity) |
| Research workflow topology | Historical teaching | Accepted synthesis and current manuals |

Count: 27 old rows reconciled to 27 dispositions.

## 3. Contract-census additions

The old catalogues omitted one accepted operative synthesis and did not expose
four shipped rules whose semantics remained only in the v0.1.9.5 spec. The
bridge therefore also includes:

- point-in-time historical projection:
  [bridge row](../decisions.md#point-in-time-historical-projection);
  accepted after both catalogues had drifted;
- [execution-window minimum](../decisions.md#execution-window-minimum);
- [fill-transition validity](../decisions.md#fill-transition-validity);
- [cost rounding and fees](../decisions.md#cost-rounding-and-fees); and
- walk-forward snapshot override:
  [bridge row](../decisions.md#walk-forward-snapshot-override).

The recursive-indicator pipeline row is not itself an accepted design. The
bridge records only the accepted boundary already present in the historical-
projection and lookback syntheses; the future RFC must make the remaining
semantic choices.

## 4. Routed conflict check

No conflict between accepted semantic sources was found. Partial sources are
kept side by side for historical projection, recursive-indicator boundaries,
objective-filtered walk-forward identity and OMS. The bridge introduces no
combined replacement rule.
