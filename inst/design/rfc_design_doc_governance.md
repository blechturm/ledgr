# RFC: Design Doc Governance

**Status:** Request for comment — no implementation started.
**Author:** ledgr maintainer
**Reviewer:** Codex
**Date:** 2026-05-12
**Context files:**
- `inst/design/` — current directory (see listing below)
- `inst/design/ledgr_roadmap.md` — active roadmap
- `inst/design/contracts.md` — execution contracts
- `inst/design/ledgr_v0_1_8_sweep_architecture.md` — active architecture input

---

## Background

ledgr uses a design-doc-first workflow. Every architectural decision, execution
contract, RFC, audit, and milestone spec lives under `inst/design/`. Coding
agents (Codex, Claude) are pointed at these files as context and are expected to
stay aligned with them across sessions.

The workflow is working. The cost-model architectural gap was caught through
this process before any implementation was locked. But three friction points
have emerged as the project grows:

1. `inst/design/` has no index. Agents reading the directory cold have no
   signal about which documents are load-bearing and which are historical.

2. The roadmap is long. It carries full scope and DoD for milestones that are
   2–4 cycles out. Those sections drift from the spec packets that supersede
   them and add maintenance overhead without adding alignment value.

3. Ideas that are not ready for the roadmap have no home. The roadmap has been
   a de facto parking lot for half-formed future considerations. Mixing committed
   planning and exploratory ideation in one document makes both harder to
   maintain.

---

## Current `inst/design/` State

Root-level files (15 loose, plus `adr/` subdirectory and 13 versioned spec
packet directories):

```text
inst/design/
  adr/                             ← exists; 3 ADRs
  contracts.md
  execution_engine_audit.md
  ledgr_design_document.md
  ledgr_design_philosophy.md
  ledgr_feature_map_ux.md
  ledgr_parallelism_spike.md
  ledgr_roadmap.md
  ledgr_sweep_mode_ux.md
  ledgr_ux_decisions.md
  ledgr_v0_1_8_sweep_architecture.md
  model_routing.md
  release_ci_playbook.md
  rfc_cost_model_architecture.md
  rfc_cost_model_architecture_response.md
  sweep_mode_code_review.md

  ledgr_v0_1_7_9_spec_packet/
  ledgr_v0_1_7_8_spec_packet/
  ... (11 older spec packets)
```

---

## Proposed Change 1: Directory Reorganization + README Index

Add `README.md` as a canonical entry point. Create four subdirectories for
loose cross-cycle documents. Keep versioned spec packets in place — they are
already self-contained and heavily cross-referenced by path.

Proposed shape:

```text
inst/design/
  README.md                        ← new; opinionated index
  contracts.md                     ← root; load-bearing, read first
  ledgr_roadmap.md                 ← root; load-bearing, read first
  ledgr_design_document.md         ← root; foundational
  ledgr_design_philosophy.md       ← root; foundational
  model_routing.md                 ← root
  ledgr_ux_decisions.md            ← root; ADR-like, cross-cutting
  release_ci_playbook.md           ← root; operational
  horizon.md                       ← root; new (see Change 3)

  adr/                             ← exists unchanged
    0001-split-db-semantics.md
    0002-registry-fingerprint-policy.md
    0003-closure-fingerprinting.md

  architecture/
    ledgr_v0_1_8_sweep_architecture.md
    ledgr_sweep_mode_ux.md         ← companion to architecture note
    ledgr_feature_map_ux.md        ← feature design spec
    sweep_mode_code_review.md      ← code review that fed architecture note

  rfc/
    cost_model_architecture.md
    cost_model_architecture_response.md
    design_doc_governance.md       ← this file, after merge

  audits/
    execution_engine_audit.md

  spikes/
    ledgr_parallelism_spike.md

  ledgr_v0_1_7_9_spec_packet/
  ledgr_v0_1_7_8_spec_packet/
  ... (older packets unchanged)
```

Proposed README structure:

```markdown
# ledgr Design Documents

## Start here
- contracts.md — execution contracts; authoritative
- ledgr_roadmap.md — milestone arc and active DoD
- [active spec packet] — current cycle tickets and spec

## Current architecture inputs
- architecture/ledgr_v0_1_8_sweep_architecture.md
- architecture/ledgr_sweep_mode_ux.md
- architecture/sweep_mode_code_review.md
- rfc/cost_model_architecture_response.md

## Parked ideas and future considerations
- horizon.md

## Audits and code reviews
- audits/execution_engine_audit.md

## Platform spikes
- spikes/ledgr_parallelism_spike.md

## Historical spec packets
- ledgr_v0_1_7_9_spec_packet/ (active)
- ledgr_v0_1_7_8_spec_packet/
- ...
```

**Implementation note:** All moves must use `git mv`. All path references in
moved files and in documents that cite them must be updated in the same commit.
A grep sweep for all current paths should happen before any file is moved.
Timing: after the v0.1.7.9 release gate, as the first v0.1.8 prep commit.

---

## Proposed Change 2: Roadmap Shortening

The roadmap should carry two tiers of content at different densities.

**Tier 1 — stable arc** (rarely changes): Vision, Guiding Principles, Roadmap
Discipline, and a short milestone sequence. This is the "what we're building
and in what order" section. Every agent reads this to orient. It should be
stable enough that reading it twice in a month produces the same mental model.

**Tier 2 — active horizon** (current milestone + next one): Full scope and
Definition of Done. The roadmap DoD is architectural intent; the spec packet
DoD is ticket-level. Both serve different purposes and both should be maintained
for the active milestones.

**Completed milestones:** one line plus a reference to the spec packet. The
spec packet is the record; the roadmap does not duplicate it. Example:

```text
## v0.1.7.x — Execution Engine Stabilisation (DONE)
Sealed snapshot correctness, FIFO lot accounting, opening position cost basis,
fill model refactor. See ledgr_v0_1_7_9_spec_packet/.
```

**Future milestones beyond the next one:** three to five intent bullets, no
DoD. DoDs for milestones two or more cycles out are speculative and will be
rewritten when the spec is cut anyway.

The current roadmap at the time of writing runs to approximately 1,800 lines.
The target after shortening is roughly 500–700 lines, with the stable arc and
active horizon sections accounting for most of that.

---

## Proposed Change 3: `horizon.md` as a Design Parking Lot

Add `inst/design/horizon.md` as a low-friction home for ideas that are not
ready for the roadmap.

**Purpose:** The project maintainer's brain surfaces future architectural
considerations continuously — often while working on unrelated tasks. The cost
model gap (noticed during v0.1.7.9 execution engine work) is an example.
Without a parking lot, those observations either pollute the roadmap with
speculative content or get lost entirely.

**Writing mode:** Append-friendly, no required format, incomplete thoughts are
acceptable. An entry can be one sentence or a paragraph. The only structure
required is a loose area tag per entry for scanability during spec prep.

**Proposed area tags:** `execution`, `ux`, `data`, `risk`, `cost`, `research`,
`infrastructure`, `adapters`.

**Example entries:**

```markdown
## execution
The fill context must carry full OHLCV, not just open. Volume is required for
future market-impact and participation-rate diagnostics. Current next-bar query
fetches only open; it will need widening when the cost-model boundary is
extracted.

## research
Walk-forward needs to express "warmup range" separately from "scoring range".
An instrument can have enough history in the full snapshot while still being
unwarmed at the start of a fold. Feature contract checks are currently
snapshot-scoped; they will need a slice-aware variant.

## ux
Consider whether ledgr_tune() is the right name for a future convenience
wrapper over ledgr_sweep() + candidate promotion. Park until fold core is
stable.
```

**Workflow:**
- Idea surfaces during any session → appended to `horizon.md`
- During spec prep for a milestone → `horizon.md` is reviewed; any item in the
  relevant area that has matured is either promoted to the roadmap or crossed off
- Items do not expire automatically; they accumulate until deliberately resolved

**What `horizon.md` is not:** it is not a backlog, not a feature request queue,
and not a commitment of any kind. Nothing in `horizon.md` implies it will be
built. It is a thinking surface, not a plan.

---

## Questions For Codex

### Q1. README structure and agent-orientation

The proposed README is opinionated: it names which documents to read first and
in what order. For a coding agent starting a session cold, is this structure
sufficient to orient correctly? Is there anything missing from the index that
an agent would commonly need but currently has to discover by scanning the
directory?

### Q2. Directory placement corrections

The original Codex reorganization proposal missed five files:
`ledgr_design_philosophy.md`, `ledgr_sweep_mode_ux.md`,
`ledgr_feature_map_ux.md`, `ledgr_ux_decisions.md`, and
`release_ci_playbook.md`. The placements proposed here are:

- `ledgr_design_philosophy.md` and `release_ci_playbook.md` → root
- `ledgr_sweep_mode_ux.md` and `ledgr_feature_map_ux.md` → `architecture/`
- `ledgr_ux_decisions.md` → root (ADR-like in character but different format)
- `sweep_mode_code_review.md` → `architecture/` (despite being a code review)

Do you agree with these placements? `sweep_mode_code_review.md` is debatable —
it's a code review that fed the architecture note but is audit-flavored. Should
it move to `audits/` instead, with the README index listing it under
architecture inputs by path?

### Q3. Roadmap shortening threshold

The proposal says: current + next one milestone at full detail, future
milestones as intent bullets only. Is that the right threshold? The argument
for tightening further (current only at full detail) is that the next milestone
DoD also drifts before the spec is cut. The argument for loosening (current +
next two) is that some downstream constraints in the next-next milestone are
load-bearing for current architecture decisions — as the cost model RFC
demonstrated.

What threshold balances alignment value against maintenance overhead?

### Q4. Roadmap stable arc content

The stable arc (Tier 1) should not change often. What belongs in it beyond
Vision, Guiding Principles, Roadmap Discipline, and the milestone sequence
table? Specifically: should the per-milestone "goal" one-liners live in the
stable arc alongside the sequence table, or is the sequence table sufficient?

### Q5. `horizon.md` structure and discipline

The proposed structure is deliberately minimal: area tag, freeform entry. Is
there a risk that without slightly more structure the file becomes unreadable
after 20–30 entries? For example, would a date stamp per entry help with
knowing when to cross things off? Or does any additional structure tip it from
"low friction" to "bureaucracy"?

Should `horizon.md` entries have any explicit status (e.g., `parked`,
`promoted`, `dropped`) or should promoted/dropped items simply be removed?

### Q6. Implementation sequencing

The three changes are interdependent: the README index references the new
directory structure, and `horizon.md` should appear in the README. Should all
three be implemented in a single commit or is there a preferred sequence?

The suggested sequence is:
1. Create `horizon.md` immediately (no file moves required, adds value now)
2. Shorten the roadmap (no file moves required, can happen before release gate)
3. Directory reorganization + README in one commit after v0.1.7.9 release gate

Is there a reason to defer `horizon.md` until after the directory
reorganization, or does creating it at root now and moving it later create
acceptable churn?
