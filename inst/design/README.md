# ledgr Design Documents

**Status:** Active design index.
**Authority:** Operational map for agents and human collaborators.
**Current release:** v0.1.7.9 shipped.
**Current implementation branch:** `v0.1.8`.
**Active packet:** `inst/design/ledgr_v0_1_8_spec_packet/`.

This directory is the design memory for ledgr. Files here do not all have the
same authority. Use this README to decide what to read first and how much weight
to give each document.

## Start Here

For any non-trivial change, read in this order:

1. `contracts.md` - current execution, snapshot, persistence, feature, and
   strategy contracts.
2. `ledgr_roadmap.md` - milestone arc and active horizon.
3. `ledgr_v0_1_8_spec_packet/` - active implementation spec packet for
   v0.1.8 sweep/fold-core work.
4. Only the architecture, RFC, audit, or spike documents relevant to the active
   ticket.

Historical spec packets are records, not current instructions, unless a task
explicitly asks you to inspect one.

## Authority Levels

| Role | Meaning |
| --- | --- |
| Contract | Must be preserved unless changed by a new spec or ADR. |
| Roadmap | Milestone sequence, active horizon, and downstream constraints. |
| Spec packet | Versioned implementation plan and ticket record. |
| Architecture input | Active design constraint for upcoming implementation. |
| RFC / response | Proposal or reviewer disposition; binding only after accepted into spec, roadmap, contract, or ADR. |
| Audit / review | Findings that must be routed before release; not all findings remain active after routing. |
| Spike | Exploratory technical research; informative unless promoted into spec or architecture. |
| Operational playbook | Process instructions for release and collaboration. |
| Horizon note | Non-binding parking lot for future design observations. |

## Active Cycle

The active implementation cycle is `v0.1.8`.

- Spec: `ledgr_v0_1_8_spec_packet/v0_1_8_spec.md`
- Tickets: `ledgr_v0_1_8_spec_packet/v0_1_8_tickets.md`
- Machine-readable tickets: `ledgr_v0_1_8_spec_packet/tickets.yml`

The active implementation target is v0.1.8 sweep/fold-core work.

## Core Documents

- `contracts.md` - authoritative contract index.
- `ledgr_roadmap.md` - milestone arc and active horizon.
- `ledgr_design_document.md` - foundational design document.
- `ledgr_design_philosophy.md` - product and design philosophy.
- `model_routing.md` - model/task routing guidance.
- `ledgr_ux_decisions.md` - cross-cutting UX decisions.
- `release_ci_playbook.md` - release gate and CI playbook.
- `horizon.md` - non-binding future-idea parking lot.

## Current Architecture Inputs

These files are active inputs for v0.1.8 planning.

- `architecture/ledgr_v0_1_8_sweep_architecture.md`
- `architecture/ledgr_sweep_mode_ux.md`
- `architecture/sweep_mode_code_review.md`
- `architecture/ledgr_feature_map_ux.md`

## RFCs

- `rfc/rfc_design_doc_governance.md`
- `rfc/rfc_design_doc_governance_response.md`
- `rfc/rfc_cost_model_architecture.md`
- `rfc/rfc_cost_model_architecture_response.md`
- `rfc/rfc_rng_contract_v0_1_8.md`
- `rfc/rfc_rng_contract_v0_1_8_response.md`
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8.md`
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_response.md`
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis_response.md`
- `rfc/rfc_sweep_promotion_context_v0_1_8.md`
- `rfc/rfc_sweep_promotion_context_v0_1_8_response.md`
- `rfc/rfc_sweep_promotion_context_v0_1_8_synthesis.md`
- `rfc/rfc_sweep_promotion_context_v0_1_8_synthesis_response.md`
- `rfc/rfc_sweep_promotion_context_v0_1_8_decision.md`
- `rfc/rfc_parallelism_spike_architecture_consequences.md`
- `rfc/rfc_parallelism_spike_architecture_consequences_response.md`

The governance RFC and response drove the completed `v0.1.8.00` prep cycle.
The cost model response is an active downstream constraint for v0.1.8 fold-core design.
The parallelism spike RFC and response are active inputs for the v0.1.8 spec.
The RNG RFC and response split v0.1.8 seed boundary work from later stochastic
strategy helpers.
The promotion RFC and response add `execution_seed` as a visible column and
establish `ledgr_candidate()` / `ledgr_promote()` as the canonical promotion API.
The promotion-context decision adds durable `run_promotion_context`
selection-audit metadata for runs promoted from sweep candidates; full sweep
artifact persistence remains future work.

## Audits And Spikes

- `audits/execution_engine_audit.md` - v0.1.7.9 execution-engine audit and routing.
- `audits/v0_1_8_spec_deep_review.md` - v0.1.8 spec review and routing.
- `spikes/ledgr_parallelism_spike/` - v0.1.8 parallelism spike episode.

## ADRs

ADRs live under `adr/`.

- `adr/0001-split-db-semantics.md` - snapshot and run database split.
- `adr/0002-registry-fingerprint-policy.md` - registry fingerprint policy.
- `adr/0003-closure-fingerprinting.md` - closure fingerprinting policy.

## Spec Packets

Versioned spec packets include the active implementation packet and archival release
records. Keep them in place.

- `ledgr_v0_1_8_spec_packet/` - active implementation packet.
- `ledgr_v0_1_8_00_spec_packet/` - completed design-governance prep packet.
- `ledgr_v0_1_7_9_spec_packet/` - latest shipped release packet.
- `ledgr_v0_1_7_8_spec_packet/` and older - historical records.

Do not treat an older packet as current just because it contains detailed
instructions. Current work follows the active packet plus the contract index.

## Task Entry Points

| Task | Read |
| --- | --- |
| Runtime/execution change | `contracts.md`, active packet, relevant architecture note |
| Sweep/fold-core planning | `contracts.md`, `architecture/ledgr_v0_1_8_sweep_architecture.md`, `architecture/ledgr_sweep_mode_ux.md` |
| Design-doc governance | `ledgr_v0_1_8_00_spec_packet/`, `rfc/rfc_design_doc_governance.md`, `rfc/rfc_design_doc_governance_response.md` |
| Release operation | `release_ci_playbook.md`, active release/closeout ticket |
| Audit intake | relevant audit, active packet, tickets |
| RFC response | source RFC, related contract section, related roadmap section |
| Spike execution | spike document, active packet, architecture note that consumes results |

## Maintenance Rule

When adding, moving, renaming, or retiring a cross-cycle design document, update
this README in the same change or record why the document is intentionally not
indexed. At release gate, this README and `AGENTS.md` must both point to the
current active design context.
