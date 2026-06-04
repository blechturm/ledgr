# Maintainer Review Wind-Down

**Status:** Wound down as an active authoring location on 2026-06-04.

**Authority:** Directory policy only. Binding contracts remain in
`../contracts.md`, accepted RFCs, ADRs, versioned spec packets, and the
maintainer manual under `../manual/`.

## Why This Pattern Is Wound Down

The workbooks in this directory were useful while the manual was being formed,
but they created a split documentation surface: synthesis lived in
`inst/design/manual/`, while the implementation trace lived in
`inst/design/maintainer_review/`. The v0.1.8.11 manual standard now requires
both layers in the manual article itself.

Going forward, implementation-depth material belongs in the relevant manual
article's `## Implementation Trace` section. That section must carry source
file and line anchors, runtime data structures, dispatch paths, edge cases,
hot/cold path boundaries, and concrete examples.

## When To Author New Workbooks

Never, for this release line. New maintainer-facing depth should be authored in
the manual article that owns the topic. If a future spike needs scratch notes,
put them in a versioned spike packet and migrate any durable conclusions into
the manual before closeout.

## Existing Records

| Former record | Disposition |
| --- | --- |
| `fold_core_workbook.qmd` | Absorbed into `../manual/execution_fold_core.qmd` under `## Implementation Trace`; deleted in LDG-2546. |
| `v0_1_8_7_optimization_round.qmd` | Absorbed into `../manual/performance_arc_v0_1_8_x.qmd` under `## Implementation Trace`; deleted in LDG-2546. |
| `feature_value_path_workbook.qmd` | Temporarily retained as the depth source for LDG-2543. Its content should migrate into the manual feature article before this directory is fully removed. |

## Migration Plan

1. Keep only this README and `feature_value_path_workbook.qmd` while LDG-2543
   remains open.
2. Do not add generated render artifacts to this directory.
3. When the feature article receives its implementation trace, migrate or delete
   `feature_value_path_workbook.qmd`.
4. Remove this directory entirely if no records remain after LDG-2543.

## Related References

- `../manual/README.qmd`
- `../manual/execution_fold_core.qmd`
- `../manual/performance_arc_v0_1_8_x.qmd`
- `../ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md`, Section 3.7
