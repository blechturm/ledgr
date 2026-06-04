# Architecture Notes

**Status:** Wound down as a recurring artifact (2026-06-04). The
`fold_core_trust_boundary.md` note has been migrated into the snapshots/data
manual article and deleted. Remaining files are historical records pending
migration into the appropriate maintainer manual article.

**Authority:** Architecture notes in this directory are historical. One
load-bearing sweep architecture note remains pending migration; the other
remaining files are historical context from cycles that landed. New binding
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
  such as `ledgr_v0_1_8_sweep_architecture.md`;
- RFC seed-equivalents for UX exploration that fed into landed tickets, such
  as `ledgr_feature_map_ux.md` and `ledgr_sweep_mode_ux.md`;
- RFC response-equivalents, such as `sweep_mode_code_review.md`.

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

One file is currently load-bearing pending migration; three are historical
context. The fold-core trust-boundary note remains listed as a migrated record
so stale citations can be resolved deliberately.

| File | Current shape | Migration target | References |
| --- | --- | --- | --- |
| `fold_core_trust_boundary.md` | Architecture teaching for the snapshot/fold trust boundary. | Migrated and deleted in LDG-2541; see `../manual/snapshots_data.qmd`. | Manual articles, RFC index snapshot-trust-boundary row, and contracts now point at `../manual/snapshots_data.qmd` plus `../contracts.md`. |
| `ledgr_v0_1_8_sweep_architecture.md` | Synthesis-equivalent for the parallel-sweep dispatch decision. | `../manual/` sweep article OR rename to `../rfc/` with synthesis-equivalent naming. | Heavily cited; load-bearing pending migration. |
| `ledgr_feature_map_ux.md` | RFC seed-equivalent from the v0.1.7.4 feature-map cycle. | Migrate residual rationale into the features manual article when it lands; delete the file. | Historical context. |
| `ledgr_sweep_mode_ux.md` | RFC seed-equivalent / UX design input that informed the sweep architecture work. | Migrate into the sweep manual article when it lands; delete. | Historical context but heavily cited. |
| `sweep_mode_code_review.md` | RFC response-equivalent feeding the sweep planning cycle. | Stay as historical provenance OR migrate into rfc/ with a response-suffix name; defer deletion. | Historical context. |

## Migration Plan

The migration plan follows the same wind-down discipline as `../adr/README.md`:

- Phase 1 (completed, v0.1.8.11): this README codified the wind-down.
- Phase 2 (v0.1.8.11 continuing manual batches): when each manual article
  lands, its corresponding architecture file's content migrates into the manual
  article, citations are re-pointed, and the architecture file is deleted.
  Specifically:
  - sweep manual article -> migrate `ledgr_v0_1_8_sweep_architecture.md` and
    `ledgr_sweep_mode_ux.md`, optionally fold `sweep_mode_code_review.md` as
    appendix or rfc/ response;
  - features manual article -> migrate `ledgr_feature_map_ux.md`.

LDG-2541 completed the snapshots/data migration of
`fold_core_trust_boundary.md`.

When the last file is migrated, this directory is deleted.

## Related References

- `../contracts.md` - current binding contracts.
- `../horizon.md` - forward direction and scope guards.
- `../manual/` - maintainer manual articles (the WHY).
- `../adr/README.md` - parallel wind-down policy for ADRs.
- `../rfc/README.md` - RFC decision index.
- `../rfc_cycle.md` - RFC cycle process reference.
