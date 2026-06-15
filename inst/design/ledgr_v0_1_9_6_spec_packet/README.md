# ledgr v0.1.9.6 Spec Packet

Status: Batch 10 implementation complete; awaiting Claude review.

This packet scopes v0.1.9.6 as the validation-substrate and gated-diagnostics
packet after the v0.1.9.5 naming and teaching consolidation release.

Authoritative files:

- `v0_1_9_6_spec.md`
- `v0_1_9_6_tickets.md`
- `tickets.yml`
- `batch_plan.md`
- `packet_open_verification.md`
- `pbo_spike_synthesis.md`
- `pbo_spike_reference.R`
- `inst/design/audits/v0_1_9_6_intraday_readiness_audit.md`
- `peer_benchmark_redo_preflight.md`

Primary design inputs:

- `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`
  (accepted 2026-06-12; maintainer-amended 2026-06-14)
- `inst/design/vignette_styleguide.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `inst/design/contracts.md`

Scope:

- add the canonical single-run return stream as
  `ledgr_results(bt, what = "returns")`;
- build the retained-return panel bridge and adapter-shaped projection
  substrate;
- run the PBO spike before any public PBO/CSCV implementation;
- implement native PBO/CSCV only through the post-spike LDG-2658 ticket;
- implement only reference-verified, self-contained diagnostics retained at
  ticket cut;
- keep method teachability as a packet-open gate;
- run the intraday-readiness audit and the current-surface peer benchmark redo.

Non-scope:

- no unconditional or adapter-runtime PBO/CSCV implementation;
- no business-objective implementation unless a later maintainer amendment
  records a narrowed override;
- no purged k-fold, embargo, CPCV, benchmark-relative diagnostics, or portfolio
  optimization;
- no intraday runtime implementation;
- no compiled spot-FIFO default flip.
