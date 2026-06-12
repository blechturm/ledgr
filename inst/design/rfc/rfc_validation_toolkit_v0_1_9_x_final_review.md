# RFC Final Review: Validation Toolkit

**Status:** Final review complete. **Verdict: APPROVED WITH PATCHES** --
three small in-place synthesis patches, none reopening design. Applied
2026-06-12 with a revision note on the synthesis. With the patches
applied, the synthesis is binding on maintainer acceptance.
**Date:** 2026-06-12
**Reviewer:** Claude (final reviewer; wrote seeds v1/v2 and the
response review; Codex wrote the response, v2 review, and synthesis).
**Scope:** verification only -- D1-D4 not reopened, bound deferrals not
re-litigated, no new design space.

---

## Findings (severity order)

### F1 (medium): the diagnostics entry points are neither named nor delegated

The synthesis binds public names for the constructor surface
(`ledgr_business_objective()`, the seven `ledgr_objective_*` steps,
`ledgr_sweep_filter()`, `ledgr_sweep_cluster()`) but the
selection-integrity pillar's own entry points -- the DSR, PBO/CSCV,
minimum-track-record, and K-Ratio surfaces, and the external-evidence
bridge -- appear nowhere as names, and naming is not delegated to
spec-cut either. Under the accepted naming synthesis every new export
must comply with R1-R7; leaving the names silently unaddressed means
the ticket-cut writer either invents them without a rule pointer or
stalls. The seed had the same gap (illustrative `ledgr_sweep_pbo()`
appeared only in conversation), so this is a cycle-level omission the
synthesis was positioned to close.

**Patch:** Q4 broadened to "Result-object, print, and entry-point
naming contracts" -- spec-cut binds the diagnostics entry-point names
under the accepted naming synthesis (family-first; the natural lean is
sweep-family diagnostics, e.g. `ledgr_sweep_pbo()`-shaped, recorded as
a lean not a binding). A matching 10.6 criterion is added: every new
public export complies with the accepted naming synthesis (coverage by
the export lock alone is not compliance).

### F2 (low-medium): Section 8 left a one-way door to new durable storage

"V1 persistence is session-object persistence ... unless the spec
packet explicitly binds a small storage table" grants the spec packet
authority to add a durable diagnostics table family without further
review. Seed v2 bound session-objects for v1 (the Q5 lean, stated as
the v1 posture); new durable table families are schema decisions of
exactly the kind this corpus binds at RFC level, not packet level.

**Patch:** Section 8 binds session-object persistence for v1, full
stop; a saved-diagnostics storage table is added to Section 12 future
obligations.

### F3 (low): a freshly minted condition class duplicates an existing one

Section 3.1 / 10.2 introduce `ledgr_validation_returns_unretained` for
the missing-retained-returns gate. That classed error already exists:
`ledgr_sweep_returns_resolve()` raises
`c("ledgr_sweep_returns_unretained", "ledgr_invalid_args")` with the
exact retention-opt-in guidance (`R/sweep-retention.R:188-194`), and
the toolkit's adapters reach retained returns through that very path.
Minting a second class for the same condition is duplicate condition
vocabulary -- the same drift class the naming RFC just cleaned out of
function space -- and would require catch-and-rethrow to even surface.

**Patch:** Sections 3.1 and 10.2 bind reuse of
`ledgr_sweep_returns_unretained`. The two genuinely new classes
(`ledgr_validation_pbo_incomplete_panel`,
`ledgr_validation_adapter_contract_mismatch`) stand -- no existing
class covers those conditions.

---

## Verified clean (no action)

- **D1-D4 bindings are faithful to seed v2**, including the maintainer
  rationale preserved verbatim (D4's "it changes the whole story") and
  the D1 resolution context. Nothing reopened.
- **The forbidden list is complete** against seed v2's non-goals and
  correctly adds the fold-retention and `train_pbo` items with the
  horizon cross-reference.
- **Citations verified accurate**: the DELETE-INSERT overwrite-hazard
  citation (`R/walk-forward.R:765-780` -- the three DELETEs sit at
  765-777); the horizon evaluation-entry span (`horizon.md:78-126`);
  the metric-context conditional-payload precedent
  (`R/metric-context.R:510-523`); the walk-forward identity payload
  citations; the PA-boundary triple anchor (DESCRIPTION:42, the
  optionality test file, contracts.md:628-631); the panel-shape
  citations into `R/sweep-retention.R`.
- **Collision checks clean**: zero existing definitions for
  `ledgr_business_objective`, `ledgr_objective_*`,
  `ledgr_sweep_filter`, `ledgr_sweep_cluster`.
- **Naming compliance** for all names the synthesis does bind:
  family-first throughout; the `ledgr_pardo_*` withdrawal carried;
  Pardo attribution routed to docs.
- **The tear-down table contract** (4.2) faithfully carries the D2
  maintainer additions and strengthens them with reason codes,
  evidence source, and input identity -- within synthesis latitude.
- **Gates are mechanically checkable** across 10.1-10.6, including the
  identity gates' no-objective byte-identity fixture and the
  objective-distinct-sessions overwrite-prevention test.
- **Future obligations and spec-cut questions are correctly
  separated**; the per-fold `train_pbo` item is referenced, not
  absorbed.

## Note for maintainer acceptance (not a patch)

The window line reads "first feature packet after v0.1.9.5," matching
the seed. Conversation on 2026-06-12 resolved this to v0.1.9.6; pinning
the number is a roadmap edit at acceptance time (per the bundling
entry's packet-open rescope discipline), not a synthesis change.

---

## Disposition

Three patches applied in place with a revision note. With them, the
synthesis is internally consistent, faithful to seed v2 and the D1-D4
resolutions, citation-accurate, collision-checked, and ticket-cuttable.
The cycle closes pending maintainer acceptance; on acceptance, the
rfc/README.md pipeline row moves to the Topic Decision Index and the
roadmap v0.1.9.x slot rescopes to "validation toolkit" with the
v0.1.9.6 number if confirmed.
