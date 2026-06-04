# Architecture Notes

**Status:** Wound down as a recurring artifact (2026-06-04). All former
architecture records have now been migrated into maintainer manual articles or
absorbed as implementation-trace material, and the source notes have been
deleted.

**Authority:** Directory policy and migration ledger only. New binding
constraints land in `../contracts.md` (the WHAT). New architecture teaching
lives in maintainer manual articles under `../manual/` (the WHY). Decision
history lives in `../rfc/`. Forward direction lives in `../horizon.md`.

## Why This Pattern Is Wound Down

The `architecture/` directory predates the current `contracts.md` + `manual/` +
`horizon.md` + `rfc/` taxonomy. When the existing notes were written, there was
no clear home for content that was neither a binding contract, a forward
direction, nor a formal RFC synthesis, so the directory absorbed:

- pre-RFC architecture teaching, now represented by the migrated
  `fold_core_trust_boundary.md` record;
- synthesis-equivalents for threads that never produced a formal RFC synthesis,
  such as the retired sweep architecture record;
- RFC seed-equivalents for UX exploration that fed into landed tickets, such
  as the retired feature-map and sweep UX records;
- RFC response-equivalents, such as the retired sweep code-review record.

Today every one of those shapes has a canonical home elsewhere in the taxonomy.
The directory does not earn the maintenance cost of being a separate category.
Like the wound-down ADR pattern (see `../adr/README.md`), the content here will
migrate into manual articles or RFC siblings as the corresponding manual
articles land, and the directory will be deleted when empty.

## When To Author A New Architecture Note

Do not. The categories below absorb every shape this directory has held:

- **Binding contract** -> `../contracts.md`.
- **Decision rationale, alternatives, tradeoffs** -> maintainer manual article
  under `../manual/`.
- **Decision history (seed / response / synthesis / final review / maintainer
  decisions)** -> `../rfc/`.
- **Forward direction and scope guards** -> `../horizon.md`.

If a new piece of content does not fit any of these, the right move is to
clarify what it is and which existing bucket it belongs to, not to add a new
file here.

## Existing Records

The records below remain listed so stale citations can be resolved deliberately.

| File | Current shape | Migration target | References |
| --- | --- | --- | --- |
| `fold_core_trust_boundary.md` | Architecture teaching for the snapshot/fold trust boundary. | Migrated and deleted in LDG-2541; see `../manual/snapshots_data.qmd`. | Manual articles, RFC index snapshot-trust-boundary row, and contracts now point at `../manual/snapshots_data.qmd` plus `../contracts.md`. |
| Retired sweep architecture record | Synthesis-equivalent for the parallel-sweep dispatch decision. | Migrated and deleted in LDG-2542; see `../manual/sweep.qmd`. | RFC index, packets, contracts, and manual references now point at `../manual/sweep.qmd`. |
| Retired feature-map UX record | RFC seed-equivalent from the v0.1.7.4 feature-map cycle. | Migrated and deleted in LDG-2543; see `../manual/features.qmd`. | Feature-map and alias citations now point at `../manual/features.qmd`. |
| Retired sweep UX record | RFC seed-equivalent / UX design input that informed the sweep architecture work. | Migrated and deleted in LDG-2542; see `../manual/sweep.qmd`. | Sweep UX citations now point at `../manual/sweep.qmd`. |
| Retired sweep code-review record | RFC response-equivalent feeding the sweep planning cycle. | Absorbed into `../manual/sweep.qmd` under `## Implementation Trace`; deleted in LDG-2542 rather than moved to `../rfc/` because its remaining value was implementation trace, not a standalone decision record. | Code-review findings are carried by the sweep manual implementation trace. |

## Migration Plan

The migration plan follows the same wind-down discipline as `../adr/README.md`:

- Phase 1 (completed, v0.1.8.11): this README codified the wind-down.
- Phase 2 (completed, v0.1.8.11): each architecture source file's content
  migrated into the corresponding manual article, citations were re-pointed,
  and the source files were deleted.

LDG-2541 completed the snapshots/data migration. LDG-2542 completed the sweep
migration, including the code-review disposition. LDG-2543 completed the
features migration.

This directory now contains only this migration ledger.

## Related References

- `../contracts.md` - current binding contracts.
- `../horizon.md` - forward direction and scope guards.
- `../manual/` - maintainer manual articles (the WHY).
- `../adr/README.md` - parallel wind-down policy for ADRs.
- `../rfc/README.md` - RFC decision index.
- `../rfc_cycle.md` - RFC cycle process reference.
