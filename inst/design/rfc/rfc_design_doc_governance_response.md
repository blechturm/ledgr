# Response: Design Doc Governance RFC

**Status:** Reviewer response; recommended governance input for v0.1.8 prep.
**Respondent:** Codex
**Date:** 2026-05-12
**Responds to:** `inst/design/rfc/rfc_design_doc_governance.md`

---

## Summary Verdict

Accept the RFC's direction.

`inst/design/` has reached the point where flat discovery is no longer good
enough. The issue is not just file count. The issue is that files now have
different authority levels:

- some are active contracts;
- some are current architecture inputs;
- some are RFCs awaiting disposition;
- some are audits whose findings have already been routed;
- some are historical packet records.

Agents and human collaborators need an index that says which documents are
load-bearing now and which are background.

The recommended governance model is:

1. Add an opinionated `inst/design/README.md`.
2. Reorganize loose cross-cycle documents by role.
3. Shorten the roadmap so it carries stable direction and active horizon, not
   speculative full DoDs several cycles out.
4. Add `horizon.md` as a low-friction design parking lot.
5. Update `AGENTS.md` so agent startup points at the design index and current
   active packet instead of a stale historical packet.

Versioned spec packets should remain in place. They are already archival units
and should not be scattered.

---

## Core Governance Principle

Organize documents by operational role, not by topic alone.

A document's topic can overlap multiple areas. For example, sweep touches UX,
architecture, execution semantics, feature precomputation, cost semantics, and
parallelism. The useful question for a reader is therefore:

```text
What kind of authority does this document have?
```

Recommended role categories:

| Role | Meaning |
| --- | --- |
| Contract | Must be preserved unless explicitly changed by a new spec or ADR. |
| Roadmap | Directional milestone sequence and active horizon. |
| Architecture input | Current design constraint for an upcoming implementation. |
| RFC | Proposal or response; may be accepted, rejected, or superseded. |
| Audit / review | Findings against code or docs; must be routed before release. |
| Spike | Exploratory technical research; informative, not binding. |
| Spec packet | Versioned implementation record and ticket contract. |

The design README should make these roles explicit.

---

## Q1. README Structure And Agent Orientation

The proposed README structure is sufficient with four additions.

First, add an explicit cold-start reading order:

```text
1. contracts.md
2. ledgr_roadmap.md
3. active spec packet
4. only the architecture/RFC/audit files relevant to the current ticket
```

Second, include authority labels. The index should not merely list paths; it
should say whether a file is authoritative, active input, proposal, historical,
or operational.

Third, include a "current cycle" pointer:

```text
Current release: v0.1.7.9 (shipped)
Current prep target: v0.1.8
Active packet: inst/design/ledgr_v0_1_7_9_spec_packet/
Next architecture inputs:
- architecture/ledgr_v0_1_8_sweep_architecture.md
- architecture/ledgr_sweep_mode_ux.md
```

Fourth, include task-specific entry points:

| Task | Read |
| --- | --- |
| Execution change | `contracts.md`, active spec, relevant architecture note |
| Release operation | `release_ci_playbook.md`, active release ticket |
| Sweep work | sweep architecture note, sweep UX, contracts |
| RFC response | source RFC, related contracts, related roadmap section |
| Audit intake | audit file, active spec, tickets |

This helps agents avoid bulk-loading the whole design directory and then
over-weighting stale context.

---

## Q2. Directory Placement Corrections

Agree with the proposed placements, with one rule:

```text
Put a document where its current authority is used, not where it originated.
```

Recommended shape:

```text
inst/design/
  README.md
  contracts.md
  ledgr_roadmap.md
  ledgr_design_document.md
  ledgr_design_philosophy.md
  model_routing.md
  ledgr_ux_decisions.md
  release_ci_playbook.md
  horizon.md

  adr/
  architecture/
  rfc/
  audits/
  spikes/
  ledgr_v*_spec_packet/
```

Specific placements:

| File | Placement | Rationale |
| --- | --- | --- |
| `ledgr_design_philosophy.md` | root | Foundational orientation, not implementation-specific. |
| `release_ci_playbook.md` | root | Operational entry point; should be easy to find during release. |
| `ledgr_sweep_mode_ux.md` | `architecture/` | Active v0.1.8 design input, despite UX title. |
| `ledgr_feature_map_ux.md` | `architecture/` | Feature-map design input; active architecture surface. |
| `ledgr_ux_decisions.md` | root | Cross-cutting decision log; ADR-like but not ADR format. |
| `execution_engine_audit.md` | `audits/` | Formal audit findings and routing. |
| `ledgr_parallelism_spike.md` | `spikes/` | Technical research, not binding contract. |
| RFCs and responses | `rfc/` | Proposal/response pairs belong together. |

`sweep_mode_code_review.md` is the only debatable file. Put it in
`architecture/` for now because it is an active v0.1.8 architecture input. The
README can list it under "Current architecture inputs" while noting that it is
review-derived. If a later spec fully absorbs it, move or relabel it as
historical audit/review material.

Do not create a separate `reviews/` directory yet. One debatable file does not
justify another category.

---

## Q3. Roadmap Shortening Threshold

Use this threshold:

```text
current milestone + next milestone = full detail
future milestones beyond next = intent bullets only
```

This balances alignment and maintenance cost.

The RFC correctly notes the counterexample: sometimes a next-next milestone
contains a constraint that affects the current architecture. The cost-model RFC
is exactly that case. The fix is not to keep full DoDs for every future
milestone. The fix is to add a small "Downstream Constraints" subsection to the
active or next milestone when a future dependency is load-bearing.

Example:

```markdown
### Downstream Constraints

- The v0.1.8 fold-core split must leave room for v0.1.9 risk transforms.
- The fill timing/cost boundary must not expose a public cost API yet, but it
  must avoid hard-coding `spread_bps` and `commission_fixed` as primitive fold
  arguments.
```

This preserves the important constraint without pretending the future milestone
has a stable DoD.

Completed milestones should become one-line historical references plus a spec
packet link.

---

## Q4. Roadmap Stable Arc Content

The stable arc should contain:

- Vision
- Guiding Principles
- Roadmap Discipline
- Current invariant links, pointing to `contracts.md` rather than duplicating
  the contract text
- Milestone sequence table
- One-line goal for each milestone
- Status and authoritative record path for completed milestones

The per-milestone goal one-liners should live in the milestone sequence table.
The sequence table alone is too thin if it only lists version numbers and
titles. A good table has:

| Milestone | Status | Goal | Record |
| --- | --- | --- | --- |
| v0.1.7.9 | Done | Stabilize execution accounting and docs before sweep. | `ledgr_v0_1_7_9_spec_packet/` |
| v0.1.8 | Next | Extract fold core and ship sweep mode. | architecture inputs |

Do not put full scope, tickets, or acceptance criteria in the stable arc.

---

## Q5. `horizon.md` Structure And Discipline

Add slightly more structure than the RFC proposes, but keep it lightweight.

Freeform entries without dates will become hard to prune. Full backlog fields
will make the file feel bureaucratic. The middle ground is:

```markdown
# ledgr Horizon

This is a parking lot for design observations that are not commitments.

## Open

### 2026-05-12 [cost] Fill context should reserve OHLCV

Volume is required for future market-impact and participation-rate diagnostics.
The v0.1.8 internal proposal shape should reserve full execution-bar data even
if the default cost resolver only uses open.

## Resolved

- 2026-05-20 [cost] Fill context should reserve OHLCV -> promoted to
  `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`.
```

Required fields:

- date;
- area tag;
- short title;
- freeform note.

Do not require owner, priority, due date, acceptance criteria, or checkboxes.
Those are backlog mechanics, and `horizon.md` is explicitly not a backlog.

Use the RFC's area tags:

```text
execution, ux, data, risk, cost, research, infrastructure, adapters
```

Promoted or dropped items should not simply disappear. Move them to a compact
`Resolved` section with a one-line disposition. Periodically prune old resolved
items after the linked spec or ADR has shipped.

---

## Q6. Implementation Sequencing

Because v0.1.7.9 has shipped, implement the governance change as v0.1.8 prep.

Recommended sequence:

1. Merge this RFC response document.
2. Add `inst/design/README.md` and `inst/design/horizon.md`.
3. Move loose cross-cycle documents with `git mv` and update references.
4. Shorten `ledgr_roadmap.md` in a separate commit.
5. Update `AGENTS.md` to point agents at `inst/design/README.md` and the
   current active packet.

The directory reorganization and README should be one commit because the README
will refer to the new paths. The roadmap shortening should be a separate commit
because it is content-heavy and easier to review on its own.

Creating `horizon.md` before the reorganization is acceptable if the
reorganization is delayed. But if the governance pass is happening now, create
it in its final root location and avoid churn.

---

## Implementation Checklist

When implementing the accepted governance change:

- Use `git mv` for file moves.
- Keep versioned spec packet directories unchanged.
- Update path references in moved files and in files that cite them.
- Run a path grep before and after moves:

```text
rg "rfc_cost_model_architecture|sweep_mode_code_review|execution_engine_audit|ledgr_parallelism_spike|ledgr_sweep_mode_ux|ledgr_feature_map_ux" inst/design AGENTS.md README.Rmd
```

- Do not change execution contracts, tickets, or code in the same commit as the
  directory move unless strictly necessary for path references.
- Add a short README note that old spec packets are historical records and
  should not be treated as current instructions unless a task explicitly asks
  for them.

---

## Additional Recommendation: Status Headers

Every root-level or cross-cycle design document should have a small status
header:

```markdown
**Status:** Active architecture input / Historical audit / Accepted RFC response
**Authority:** Contract / Proposal / Background / Operational
**Supersedes:** optional
**Superseded by:** optional
```

This is more useful for agents than directory structure alone. Directory
structure answers "where is this?" The status header answers "how should I use
this?"

Do not retrofit this into every historical spec packet. Apply it to root-level
and moved cross-cycle documents first.

---

## Final Recommendation

Accept the governance RFC with two refinements:

1. Make authority levels explicit in the README and document headers.
2. Keep the roadmap detailed only for the current and next milestone, while
   preserving future load-bearing constraints as short downstream-constraint
   notes.

The project should move from:

```text
flat design folder as memory dump
```

to:

```text
indexed design system with contracts, active architecture inputs, RFCs, audits,
spikes, horizon notes, and archival spec packets clearly separated
```

That will make both human and agent collaboration more reliable without turning
design work into a heavy process.
