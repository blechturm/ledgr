# ledgr v0.1.9.5 Spec Packet

Status: Batch 1C+2 implementation complete; awaiting Claude review.

This packet scopes v0.1.9.5 as a naming and teaching consolidation release
after the v0.1.9.1-v0.1.9.4 feature arc.

Authoritative files:

- `v0_1_9_5_spec.md`
- `v0_1_9_5_tickets.md`
- `tickets.yml`
- `batch_plan.md`

Primary design inputs:

- `inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md`
- `inst/design/audits/v0_1_9_4_deep_code_review_audit.md`
- `inst/design/audits/v0_1_9_4_vignette_screening_audit.md`
- `inst/design/ledgr_roadmap.md`

Scope:

- consolidate public API naming after the v0.1.9.x feature arc;
- fix the v0.1.9.4 deep-review audit findings scheduled for this release;
- split and refresh the user-facing vignette surface;
- add the teaching and maintainer-manual surfaces needed before the validation
  toolkit packet;
- close with the normal release gate.

Non-scope:

- no validation toolkit implementation;
- no strategy-decorator implementation;
- no crypto-readiness work;
- no target-construction helper expansion;
- no new feature work beyond the accepted naming synthesis and scheduled audit
  fixes.
