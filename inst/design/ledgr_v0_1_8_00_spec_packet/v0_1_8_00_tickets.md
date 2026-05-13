# ledgr v0.1.8.00 Tickets

**Version:** 0.1.8.00
**Date:** May 12, 2026
**Total Tickets:** 7

---

## Ticket Organization

v0.1.8.00 is a governance-prep cycle before v0.1.8 sweep implementation. It
does not change runtime behavior, package APIs, vignettes, tests, or release
metadata. It reorganizes `inst/design/` so active contracts, architecture
inputs, RFCs, audits, spikes, horizon notes, and historical spec packets are
easy for agents and human collaborators to distinguish. It also includes two
small v0.1.8 prep tracks: pkgdown discoverability and the parallelism spike
session.

Tracks:

1. **Baseline:** record the governance RFC disposition and lock the non-runtime
   scope.
2. **Index and parking lot:** add the design README and `horizon.md`.
3. **Atomic moves:** move cross-cycle documents, update references, and update
   `AGENTS.md` in one coherent change.
4. **Roadmap density:** shorten the roadmap to stable arc plus active horizon.
5. **pkgdown discoverability:** fix the Articles navbar and verify LLM site
   artefacts.
6. **Parallelism spike session:** run all five spikes and record outcomes for
   v0.1.8 spec prep.
7. **Closeout:** verify paths, directory shape, prep-track completion, and no
   runtime drift.

### Dependency DAG

```text
LDG-2001 -> LDG-2002 -> LDG-2003 -> LDG-2004 --.
LDG-2001 -> LDG-2006 --------------------------+-> LDG-2005
LDG-2001 -> LDG-2007 --------------------------'
```

`LDG-2005` is the v0.1.8.00 final closeout gate. LDG-2006 and LDG-2007
are independent tracks that can proceed in parallel with the governance chain,
but both must complete before closeout. LDG-2007 is a scope extension beyond
the original governance spec: the parallelism spike is included here because it
is a prerequisite for the v0.1.8 spec cut.

### Priority Levels

- **P0 (Blocker):** Required for scope coherence or repository navigability.
- **P1 (Critical):** Required for the governance refactor to be complete.
- **P2 (Important):** Required for release hygiene and future maintainability.
- **P3 (Optional):** Useful, but not required for this prep cycle.

---

## LDG-2001: Governance RFC Disposition And Scope Baseline

**Priority:** P0
**Effort:** 0.5 day
**Dependencies:** None
**Status:** Done

**Description:**
Finalize the v0.1.8.00 governance baseline before file moves begin. Confirm the
governance RFC and response are recorded, confirm v0.1.7.9 has shipped, and
lock the non-runtime scope for this prep cycle.

**Tasks:**
1. Read `v0_1_8_00_spec.md`, `rfc/rfc_design_doc_governance.md`, and
   `rfc/rfc_design_doc_governance_response.md`.
2. Confirm v0.1.7.9 release gate completion is the baseline for this cycle.
3. Confirm the accepted governance model:
   - design README as canonical entry point;
   - role-based organization;
   - roadmap shortening;
   - `horizon.md`;
   - `AGENTS.md` orientation update.
4. Confirm this cycle excludes runtime/package behavior changes.
5. Confirm this ticket file and `tickets.yml` match the spec.

**Acceptance Criteria:**
- [x] Governance RFC and response are present and referenced by the packet.
- [x] v0.1.7.9 is confirmed as the shipped baseline.
- [x] Non-runtime scope is explicitly confirmed before implementation tickets.
- [x] Ticket IDs, dependencies, and statuses match `tickets.yml`.
- [x] No runtime implementation work is promoted into v0.1.8.00.

**Implementation Notes:**
- Confirmed the branch is `v0.1.8.00` and the packet records v0.1.7.9 as the
  shipped baseline.
- Confirmed the governance RFC and response are present and referenced from the
  spec.
- Confirmed the accepted governance model is recorded: design README,
  role-based organization, roadmap shortening, `horizon.md`, and `AGENTS.md`
  orientation updates.
- Confirmed the cycle remains non-runtime. Runtime package work, sweep
  implementation, fold-core extraction, risk-layer work, and public cost-model
  implementation remain out of scope.
- Confirmed ticket IDs and dependency/status metadata are synchronized with
  `tickets.yml` after LDG-2001 and LDG-2002 status updates.

**Verification:**
```text
documentation/routing review
git status review
```

**Test Requirements:**
- Documentation/routing review only.

**Source Reference:** v0.1.8.00 spec sections 1, 1.1, 2, 3, 6.

**Classification:**
```yaml
risk_level: medium
implementation_tier: L
review_tier: M
classification_reason: >
  This ticket locks the governance-only scope before broad path moves and
  roadmap edits begin. The main risk is accidental expansion into runtime or
  package-release work.
invariants_at_risk:
  - governance scope discipline
  - v0.1.8 prep sequencing
  - non-runtime boundary
required_context:
  - inst/design/ledgr_v0_1_8_00_spec_packet/v0_1_8_00_spec.md
  - inst/design/rfc/rfc_design_doc_governance.md
  - inst/design/rfc/rfc_design_doc_governance_response.md
tests_required:
  - documentation/routing review
escalation_triggers:
  - governance work requires package runtime changes
  - v0.1.7.9 baseline is found not to be released
forbidden_actions:
  - changing R package runtime files
  - changing package version metadata
  - implementing sweep, fold-core, risk, or cost-model work
```

---

## LDG-2002: Design README And Horizon Parking Lot

**Priority:** P1
**Effort:** 0.5-1 day
**Dependencies:** LDG-2001
**Status:** Done

**Description:**
Add the canonical design-document entry point and a low-friction future-idea
parking lot. `inst/design/README.md` should orient agents and humans; 
`inst/design/horizon.md` should hold non-binding observations that are not
ready for the roadmap.

**Tasks:**
1. Add `inst/design/README.md` with:
   - cold-start reading order;
   - role/authority table;
   - current-cycle pointer;
   - task-specific entry points;
   - historical packet guidance.
2. Add `inst/design/horizon.md` with:
   - purpose statement;
   - allowed area tags;
   - `Open` section;
   - `Resolved` section;
   - required entry structure.
3. Include only unplaced horizon candidates; do not duplicate items already
   captured in roadmap, architecture notes, RFC responses, or active packets.
4. Keep both files design-facing and non-runtime.

**Acceptance Criteria:**
- [x] `inst/design/README.md` exists and names authority levels.
- [x] The design README gives a clear cold-start reading order.
- [x] The design README points to the active packet and current v0.1.8 inputs.
- [x] `inst/design/horizon.md` exists and is explicitly non-binding.
- [x] `horizon.md` uses date, area tag, title, and freeform note structure.
- [x] No runtime/package files are touched by this ticket.

**Implementation Notes:**
- Added `inst/design/README.md` as the active design index with authority
  levels, cold-start reading order, active packet pointers, current
  architecture inputs, RFCs, audits/spikes, ADRs, historical packet guidance,
  task entry points, and a maintenance rule.
- Added `inst/design/horizon.md` as a non-binding parking lot with the required
  date/tag/title/freeform entry structure and a compact `Resolved` section.
- Kept horizon entries limited to currently unplaced ideas to avoid duplicating
  roadmap, architecture, RFC, or active-packet decisions.
- Did not move files in this ticket; LDG-2003 owns the atomic reorganization
  and reference updates.
- Touched only design documents.

**Verification:**
```text
manual markdown review
path existence spot check
git diff --name-only
```

**Test Requirements:**
- Manual documentation review.

**Source Reference:** v0.1.8.00 spec Track B, Track D, R4, R7, D1, D2.

**Classification:**
```yaml
risk_level: medium
implementation_tier: L
review_tier: M
classification_reason: >
  The design README and horizon file set the navigation model future agents
  will use. Incorrect authority labels or duplicated horizon content would
  preserve the current context-drift problem.
invariants_at_risk:
  - design document discoverability
  - authority-label clarity
  - horizon is not a backlog
required_context:
  - inst/design/ledgr_v0_1_8_00_spec_packet/v0_1_8_00_spec.md
  - inst/design/rfc/rfc_design_doc_governance_response.md
  - inst/design/ledgr_roadmap.md
  - inst/design/contracts.md
tests_required:
  - manual markdown review
escalation_triggers:
  - active packet or current-cycle pointer is ambiguous
  - horizon candidates duplicate already placed decisions
forbidden_actions:
  - converting horizon.md into a ticket backlog
  - moving files before the atomic move ticket
  - changing package runtime behavior
```

---

## LDG-2003: Atomic Design-Doc Reorganization And Reference Updates

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-2002
**Status:** Done

**Description:**
Move loose cross-cycle design documents into role-based subdirectories and
update active references in the same change. This ticket also updates
`AGENTS.md` so agents start from the new design index and active packet.

This ticket must be atomic: moving files without updating active references is
not an acceptable intermediate state.

**Tasks:**
1. Create the subdirectories:
   - `inst/design/architecture/`;
   - `inst/design/rfc/`;
   - `inst/design/audits/`;
   - `inst/design/spikes/`.
2. Use `git mv` for all file moves.
3. Move active architecture inputs:
   - `ledgr_v0_1_8_sweep_architecture.md`;
   - `ledgr_sweep_mode_ux.md`;
   - `ledgr_feature_map_ux.md`;
   - `sweep_mode_code_review.md`.
4. Move RFCs and responses:
   - `rfc_cost_model_architecture.md`;
   - `rfc_cost_model_architecture_response.md`;
   - `rfc_design_doc_governance.md`;
   - `rfc_design_doc_governance_response.md`.
5. Move audit and spike files:
   - `execution_engine_audit.md`;
   - `ledgr_parallelism_spike.md`.
6. Keep versioned spec packet directories in place.
7. Update active path references in design docs and `AGENTS.md`.
8. Update `inst/design/README.md` to list final paths.
9. Run before/after path greps for all moved filenames.

**Acceptance Criteria:**
- [x] All moved files are moved with `git mv`.
- [x] Root load-bearing files remain at root.
- [x] Versioned spec packet directories remain in place.
- [x] `AGENTS.md` points at `inst/design/README.md`, `contracts.md`,
      `ledgr_roadmap.md`, and the active packet.
- [x] Active references to moved files are updated.
- [x] Stale references that remain are explicitly historical text.
- [x] Directory shape matches the v0.1.8.00 spec.

**Implementation Notes:**
- Created the role-based directories and moved all LDG-2003 files with
  `git mv`.
- Updated the design README, AGENTS.md, roadmap, UX decisions, architecture
  notes, RFC responses, active spec packet, and active ticket metadata to point
  at the final locations.
- Left historical spec-packet references in place where they are archival text.

**Verification:**
```text
rg "rfc_cost_model_architecture|rfc_cost_model_architecture_response|rfc_design_doc_governance|rfc_design_doc_governance_response|sweep_mode_code_review|execution_engine_audit|ledgr_parallelism_spike|ledgr_sweep_mode_ux|ledgr_feature_map_ux|ledgr_v0_1_8_sweep_architecture" inst/design AGENTS.md README.Rmd
directory shape check
manual link/path spot check
git diff --name-status
```

**Test Requirements:**
- Path grep.
- Directory shape check.
- Manual link/path spot check.

**Source Reference:** v0.1.8.00 spec Track C, Track F, R2, R3, R5, R8, R9,
R10, T1, T2, T3.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  This ticket moves many design documents and changes agent-facing context.
  The risk is broken active references or agents following historical files as
  current authority.
invariants_at_risk:
  - design path integrity
  - agent orientation
  - historical packet stability
  - active architecture discoverability
required_context:
  - inst/design/ledgr_v0_1_8_00_spec_packet/v0_1_8_00_spec.md
  - inst/design/README.md
  - AGENTS.md
  - inst/design/contracts.md
  - inst/design/ledgr_roadmap.md
tests_required:
  - path grep for moved filenames
  - directory shape check
  - manual link/path spot check
escalation_triggers:
  - a moved file is referenced by package code or public docs
  - historical spec packet references cannot be clearly classified as historical
  - git mv cannot preserve rename history cleanly
forbidden_actions:
  - moving versioned spec packet directories
  - committing file moves without reference updates
  - changing runtime code
  - changing package public documentation beyond required path references
```

---

## LDG-2004: Roadmap Shortening And Future Constraint Preservation

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-2003
**Status:** Done

**Description:**
Shorten `inst/design/ledgr_roadmap.md` so it carries stable project direction,
current/next milestone detail, and future load-bearing constraints without
duplicating completed spec packets or speculative far-future DoDs.

**Tasks:**
1. Preserve the roadmap's vision, guiding principles, and roadmap discipline.
2. Add or maintain a milestone sequence table with status, one-line goal, and
   authoritative record path.
3. Compress completed milestones to one-line records plus links to spec packets.
4. Keep full detail only for the active prep/implementation milestone and the
   next milestone.
5. Convert future milestones beyond the next to three to five intent bullets.
6. Preserve downstream constraints needed for v0.1.8 architecture.
7. Move or preserve speculative content according to R11:
   - linked spec packet;
   - `horizon.md`;
   - architecture/RFC document;
   - deliberate drop with implementation note.

**Acceptance Criteria:**
- [x] Roadmap retains stable vision and roadmap discipline.
- [x] Completed milestones no longer duplicate ticket-level or DoD detail.
- [x] Current and next milestone retain sufficient detail for agent alignment.
- [x] Future milestones beyond next are intent-level only.
- [x] v0.1.8 sweep/fold-core and downstream cost/risk constraints remain
      discoverable.
- [x] Removed speculative content is preserved or deliberately dropped with a
      note.
- [x] No runtime/package files are touched by this ticket.

**Implementation Notes:**
- Replaced the long roadmap with a compact authority document: vision,
  principles, roadmap discipline, milestone sequence table, completed milestone
  records, active v0.1.8.00 prep detail, next v0.1.8 sweep detail, and concise
  downstream constraints.
- Preserved load-bearing v0.1.8 constraints by linking to the sweep
  architecture note, sweep UX note, parallelism spike, contracts, and cost-model
  RFC response.
- Parked broad deferred strategy/integration families in `horizon.md` rather
  than duplicating far-future DoDs in the roadmap.

**Verification:**
```text
manual roadmap review
diff review for removed sections
path/link spot check for spec packet references
```

**Test Requirements:**
- Manual documentation review.

**Source Reference:** v0.1.8.00 spec Track E, R6, R11, D3.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  The roadmap is a high-authority planning document. Shortening it improves
  maintainability, but careless cuts can erase load-bearing future constraints
  needed for v0.1.8 architecture.
invariants_at_risk:
  - roadmap sequencing
  - active horizon clarity
  - future constraint preservation
  - spec packet authority
required_context:
  - inst/design/ledgr_v0_1_8_00_spec_packet/v0_1_8_00_spec.md
  - inst/design/ledgr_roadmap.md
  - inst/design/horizon.md
  - inst/design/contracts.md
  - inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md
  - inst/design/rfc/rfc_cost_model_architecture_response.md
tests_required:
  - manual roadmap review
escalation_triggers:
  - a future section contains constraints not captured elsewhere
  - active v0.1.8 scope becomes ambiguous after shortening
  - completed packet links are missing or stale
forbidden_actions:
  - silently deleting load-bearing constraints
  - changing project scope while shortening prose
  - editing runtime code
```

---

## LDG-2005: v0.1.8.00 Closeout

**Priority:** P0
**Effort:** 0.5 day
**Dependencies:** LDG-2004, LDG-2006, LDG-2007
**Status:** Todo

**Description:**
Close the prep cycle by verifying directory shape, path references, agent
orientation, roadmap density, pkgdown discoverability, spike findings, and
non-runtime scope. This is the merge gate for v0.1.8.00.

**Tasks:**
1. Confirm `inst/design/README.md` is the design entry point.
2. Confirm `inst/design/horizon.md` exists and is non-binding.
3. Confirm role-based directories contain the intended files.
4. Confirm versioned spec packets stayed in place.
5. Confirm `AGENTS.md` points to the design index and active packet.
6. Run the required path greps from the spec.
7. Spot-check links/paths in README and moved documents.
8. Confirm no runtime/package files changed.
9. Confirm LDG-2006 site-discoverability evidence is recorded.
10. Confirm LDG-2007 spike outcomes are recorded.
11. Update ticket statuses and `tickets.yml`.

**Acceptance Criteria:**
- [ ] Design README, horizon, subdirectories, and roadmap changes are complete.
- [ ] Path greps show no broken active references to moved files.
- [ ] `AGENTS.md` is aligned with the new design-document system.
- [ ] Historical packet references are either preserved as historical text or
      updated where active.
- [ ] No runtime/package behavior changes are included.
- [ ] LDG-2006 is complete or explicitly deferred with maintainer approval.
- [ ] LDG-2007 is complete or explicitly deferred with maintainer approval.
- [ ] `v0_1_8_00_tickets.md` and `tickets.yml` are synchronized.
- [ ] Branch is ready to merge as v0.1.8 prep.

**Implementation Notes:**
- Pending.

**Verification:**
```text
path grep for moved filenames
directory shape check
manual link/path spot check
git diff --name-only
git status --short
```

**Test Requirements:**
- Path grep.
- Directory shape check.
- Manual diff review.

**Source Reference:** v0.1.8.00 spec sections 5 and 8.

**Classification:**
```yaml
risk_level: medium
implementation_tier: L
review_tier: M
classification_reason: >
  The closeout gate ensures the governance refactor is coherent before v0.1.8
  implementation work starts on top of the new design-document layout.
invariants_at_risk:
  - design path integrity
  - agent orientation
  - non-runtime scope
  - prep-track completion
  - ticket/status consistency
required_context:
  - inst/design/ledgr_v0_1_8_00_spec_packet/v0_1_8_00_spec.md
  - inst/design/ledgr_v0_1_8_00_spec_packet/v0_1_8_00_tickets.md
  - inst/design/ledgr_v0_1_8_00_spec_packet/tickets.yml
  - inst/design/README.md
  - AGENTS.md
tests_required:
  - path grep
  - directory shape check
  - manual diff review
escalation_triggers:
  - final diff includes runtime files
  - moved-file references remain broken
  - roadmap shortening removes a load-bearing constraint
  - site-discoverability or spike work remains incomplete
forbidden_actions:
  - merging with broken design paths
  - leaving tickets.yml out of sync
  - adding runtime changes during closeout
```

---

## LDG-2006: pkgdown Site Discoverability

**Priority:** P2
**Effort:** 0.5 day
**Dependencies:** LDG-2001
**Status:** Done

**Description:**
Improve discoverability of the published ledgr pkgdown site for both human
visitors and LLM-based agents. Two changes: fix the Articles navbar dropdown
so section groupings are visible without clicking through to the index, and
verify that `build_llm_docs()` is generating LLM-optimized site artefacts.

**Tasks:**
1. Apply the `_pkgdown.yml` navbar fix: set `navbar:` to a non-null label for
   each article section so the Articles dropdown shows section headers.
   *(Already applied in working tree - verify and commit.)*
2. Verify that `LLMs.txt` exists at `https://blechturm.github.io/ledgr/LLMs.txt`
   after the next site build. pkgdown 2.1+ runs `build_llm_docs()` as part of
   `build_site()` unless `llm-docs: false` is set; no explicit call should be
   needed.
3. If `LLMs.txt` is absent, add an explicit `build_llm_docs()` call to the
   CI/CD site-build step.
4. Run a local CI-equivalent site rebuild. The public deployment happens from
   `main`, so the release/closeout step must re-check the public URL after the
   next Pages deployment.

**Acceptance Criteria:**
- [x] `_pkgdown.yml` navbar sections have non-null labels.
- [x] The Articles dropdown in the site navbar shows the three section headers
      (Start Here, Core Workflow, Design / Background).
- [x] `LLMs.txt` is present and populated in the locally built site. The public
      URL returned 404 before this branch is deployed; re-check after release
      deployment.
- [x] `.md` mirrors exist for reference and article pages in the locally built
      site. Re-check after release deployment.
- [x] No runtime/package files are touched by this ticket.

**Implementation Notes:**
- The `_pkgdown.yml` articles navbar fix was applied before pickup and verified.
- pkgdown 2.2.0 is installed locally. `build_llm_docs()` was introduced in
  pkgdown 2.1.0 and runs by default - no config change is expected to be
  required.
- `LLMs.txt` and `.md` files improve AI assistant responses for users of ledgr,
  distinct from `inst/design/README.md` which orients agents working on ledgr.
- Local CI-equivalent smoke command passed:
  `pkgdown::build_site(new_process = FALSE)`.
- Local build evidence:
  - `docs/articles/index.html` contains navbar dropdown headers for Start Here,
    Core Workflow, and Design / Background.
  - `docs/LLMs.txt` was generated and populated.
  - `docs/reference/ledgr_run.md` and `docs/articles/getting-started.md` were
    generated as markdown mirrors.
- Network check of `https://blechturm.github.io/ledgr/LLMs.txt` returned 404
  before this branch is deployed. The release/closeout step should re-check the
  public URL after the next Pages deployment.

**Verification:**
```text
curl https://blechturm.github.io/ledgr/LLMs.txt
manual site navbar check
pkgdown::build_site() local smoke test
```

**Test Requirements:**
- Site build smoke test.
- Manual navbar check.

**Source Reference:** pkgdown `build_llm_docs()` and `build_articles()` docs;
session analysis 2026-05-13.

**Classification:**
```yaml
risk_level: low
implementation_tier: L
review_tier: L
classification_reason: >
  pkgdown site configuration only. No runtime package behavior changes. The
  only risk is a broken site build if the _pkgdown.yml change is malformed.
invariants_at_risk:
  - pkgdown site builds cleanly
required_context:
  - _pkgdown.yml
  - inst/design/ledgr_v0_1_8_00_spec_packet/v0_1_8_00_spec.md
tests_required:
  - pkgdown build smoke test
escalation_triggers:
  - build_llm_docs() produces empty or malformed LLMs.txt
  - site build fails after _pkgdown.yml change
forbidden_actions:
  - changing runtime R code
  - changing vignette content
  - adding llm-docs: false to _pkgdown.yml
```

---

## LDG-2007: Parallelism Spike Session

**Priority:** P1
**Effort:** 2-3 days
**Dependencies:** LDG-2001
**Status:** Todo

**Description:**
Execute the five parallelism spikes defined in `inst/design/spikes/ledgr_parallelism_spike.md`
and record findings in that document. The spike results determine key v0.1.8
design decisions: mirai dependency classification, mori serialization viability,
bar-data fetch strategy, and feature-cache warming semantics. All five spikes
must complete before the v0.1.8 spec can be opened.

This ticket extends the v0.1.8.00 governance scope at the maintainer's request.
The spike work is v0.1.8 prep, not a governance deliverable, but including it
here avoids a separate micro-cycle.

**Spike Inventory (from `spikes/ledgr_parallelism_spike.md`):**
- SPIKE-1: mirai daemon lifecycle on Windows (native) and Ubuntu/WSL
- SPIKE-2: mirai task serialization - plain R objects, closures, environments
- SPIKE-3: mori cross-process serialization with mirai's NNG layer
- SPIKE-4: bar-data fetch strategy - pre-fetch vs. per-worker read-only DuckDB
- SPIKE-5: feature-cache cross-task survival in mirai daemon processes

**Tasks:**
1. Create `dev/spikes/` directory and add it to `.Rbuildignore`.
2. For each spike, create a subdirectory `dev/spikes/0N_<name>/` with
   exploratory scripts. Spike code is not package code; it does not need tests,
   documentation, or R package conventions.
3. Execute each spike against the local environment (Windows primary,
   Ubuntu/WSL secondary where relevant).
4. Record findings in `inst/design/spikes/ledgr_parallelism_spike.md`.
5. For each spike, record: outcome (confirmed / refuted / inconclusive),
   platform results, blocking implications for v0.1.8, and any required
   follow-up.
6. After all five spikes complete, summarize the v0.1.8 design decisions that
   are now unblocked or newly constrained.

**Acceptance Criteria:**
- [ ] `dev/spikes/` exists and is in `.Rbuildignore`.
- [ ] All five spikes have recorded outcomes in the spike document.
- [ ] Each spike outcome includes platform results (Windows, Ubuntu/WSL as
      applicable).
- [ ] The spike document summarizes which v0.1.8 design decisions are resolved.
- [ ] mirai dependency classification is stated (Suggests / user-managed / not
      viable).
- [ ] mori cross-process serialization outcome is stated.
- [ ] Bar-data fetch strategy recommendation is stated.
- [ ] Feature-cache warming recommendation is stated.
- [ ] No production package code is changed by this ticket.

**Implementation Notes:**
- Spike code lives in `dev/spikes/` and is excluded from the package build.
  It does not need to follow R package conventions.
- Results are tracked in the spike document, not in this tickets file.
- Context paths use post-LDG-2003 locations under `inst/design/architecture/`
  and `inst/design/spikes/`.
- The five spikes can be run sequentially or opportunistically; the acceptance
  criteria require all five to have outcomes before this ticket closes.
- If a spike is inconclusive, record what was tested, what the blocker was, and
  what additional environment or information is needed.

**Verification:**
```text
inst/design/spikes/ledgr_parallelism_spike.md has findings for all 5 spikes
dev/spikes/ exists and is listed in .Rbuildignore
no R/ or tests/ files changed
```

**Test Requirements:**
- Manual review of spike findings document.
- `.Rbuildignore` spot check.

**Source Reference:** `inst/design/spikes/ledgr_parallelism_spike.md`;
`inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md` - mirai process
model constraints section.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: M
classification_reason: >
  The spike outcomes determine load-bearing v0.1.8 architecture decisions.
  Inconclusive or missing results would force mid-spec resolution with higher
  revision risk. Spike code itself carries no production risk.
invariants_at_risk:
  - v0.1.8 spec coherence
  - mirai/mori dependency classification
  - no production code changes
required_context:
  - inst/design/spikes/ledgr_parallelism_spike.md
  - inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md
  - inst/design/ledgr_v0_1_8_00_spec_packet/v0_1_8_00_spec.md
tests_required:
  - manual review of spike findings
escalation_triggers:
  - a spike is impossible to run in the available environment
  - mirai is found to be non-viable on Windows, blocking the parallel design
  - mori cross-process behavior is unresolvable without a package patch
forbidden_actions:
  - committing spike code to R/ or tests/
  - recording spike outcomes in tickets.yml rather than the spike document
  - opening the v0.1.8 spec before all five spikes have outcomes
```
