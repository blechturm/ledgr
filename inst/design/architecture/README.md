# Architecture Notes

**Status:** Wound down as a recurring artifact (2026-06-04). The existing
files remain as historical records pending migration into the appropriate
maintainer manual article.

**Authority:** Architecture notes in this directory are historical. Two are
load-bearing pending migration; three are historical context from cycles that
landed. New binding constraints land in `../contracts.md` (the WHAT). New
architecture teaching lives in maintainer manual articles under `../manual/`
(the WHY). Decision history lives in `../rfc/`. Forward direction lives in
`../horizon.md`.

## Why this pattern is wound down

The `architecture/` directory predates the current
`contracts.md` + `manual/` + `horizon.md` + `rfc/` taxonomy. When the existing
notes were written, there was no clear home for content that was neither a
binding contract, a forward direction, nor a formal RFC synthesis, so the
directory absorbed:

- pre-RFC architecture teaching (e.g. `fold_core_trust_boundary.md`);
- synthesis-equivalents for threads that never produced a formal RFC
  synthesis (e.g. `ledgr_v0_1_8_sweep_architecture.md`);
- RFC seed-equivalents for UX exploration that fed into landed tickets (e.g.
  `ledgr_feature_map_ux.md`, `ledgr_sweep_mode_ux.md`);
- RFC response-equivalents (e.g. `sweep_mode_code_review.md`).

Today every one of those shapes has a canonical home elsewhere in the
taxonomy. The directory does not earn the maintenance cost of being a
separate category. Like the wound-down ADR pattern (see `../adr/README.md`),
the content here will migrate into manual articles or RFC siblings as the
corresponding manual articles land, and the directory will be deleted when
empty.

## When to author a new architecture note

Do not. The categories below absorb every shape this directory has held:

- **Binding contract** → `../contracts.md`.
- **Decision rationale, alternatives, tradeoffs** → maintainer manual article
  under `../manual/`.
- **Decision history (seed / response / synthesis / final review / maintainer
  decisions)** → `../rfc/`.
- **Forward direction and scope guards** → `../horizon.md`.

If a new piece of content does not fit any of these, the right move is to
clarify what it is and which existing bucket it belongs to, not to add a new
file here.

## Existing records

Two files are currently load-bearing pending migration; three are historical
context.

| File | Current shape | Migration target | References |
| --- | --- | --- | --- |
| `fold_core_trust_boundary.md` | Architecture teaching (pre-RFC input that became binding teaching for the snapshot/fold trust boundary). | `../manual/execution_fold_core.qmd` (section expansion) or a future snapshots/data manual article. | Manual articles, ADRs 0001 + 0003, RFC index snapshot-trust-boundary row, contracts.md. Load-bearing pending migration. |
| `ledgr_v0_1_8_sweep_architecture.md` | Synthesis-equivalent for the parallel-sweep dispatch decision (the thread never produced a formal RFC synthesis; this note serves that role). | `../manual/` sweep article OR rename to `../rfc/` with synthesis-equivalent naming. | 28 full-path refs, 44 basename refs across packets, manual, contracts, ledgr_ux_decisions, audits, RFC index (named as Primary authority for Parallel Sweep Dispatch). Heavily load-bearing. |
| `ledgr_feature_map_ux.md` | RFC seed-equivalent from the v0.1.7.4 feature-map cycle. The cycle landed long ago. | Migrate residual rationale into the features manual article when it lands; delete the file. | 2 full-path refs, 28 basename refs. Historical context. |
| `ledgr_sweep_mode_ux.md` | RFC seed-equivalent / UX design input that informed the sweep architecture work. | Migrate into the sweep manual article when it lands; delete. | 20 full-path refs, 37 basename refs. Historical context but heavily cited. |
| `sweep_mode_code_review.md` | RFC response-equivalent: pre-implementation readiness review feeding the sweep planning cycle. | Stay as historical provenance OR migrate into rfc/ with a response-suffix name; defer deletion. | 7 full-path refs, 16 basename refs. Historical context. |

## Migration plan

The migration plan follows the same wind-down discipline as `../adr/README.md`:

- Phase 1 (now, v0.1.8.11): this README codifies the wind-down. No file moves
  or deletions in this batch. Citation churn is deferred.
- Phase 2 (v0.1.8.12 / v0.1.9.x manual remainder): when each manual article
  lands, its corresponding architecture file's content migrates into the
  manual article, citations are re-pointed, and the architecture file is
  deleted. Specifically:
  - sweep manual article → migrate `ledgr_v0_1_8_sweep_architecture.md` and
    `ledgr_sweep_mode_ux.md`, optionally fold `sweep_mode_code_review.md` as
    appendix or rfc/ response;
  - features manual article → migrate `ledgr_feature_map_ux.md`;
  - snapshots/data manual article (or execution_fold_core expansion) →
    migrate `fold_core_trust_boundary.md`.

When the last file is migrated, this directory is deleted.

## Related references

- `../contracts.md` — current binding contracts.
- `../horizon.md` — forward direction and scope guards.
- `../manual/` — maintainer manual articles (the WHY).
- `../adr/README.md` — parallel wind-down policy for ADRs.
- `../rfc/README.md` — RFC decision index.
- `../rfc_cycle.md` — RFC cycle process reference.
