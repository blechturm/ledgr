# ledgr v0.1.9.7 Spec Packet

Status: Batches 0-9 complete after review; Batch 10 pending; Batch 11 blocked.

This packet scopes v0.1.9.7 as the business-objective eligibility and
validation-polish release after v0.1.9.6 shipped the validation substrate and
selection-integrity diagnostics.

Authoritative files:

- `v0_1_9_7_spec.md`
- `v0_1_9_7_tickets.md`
- `tickets.yml`
- `batch_plan.md`
- `stable_region_spike_synthesis.md`
- `stable_region_spike_reference.R`
- `closed_trade_retention_storage_smoke.md`

Primary design inputs:

- `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`
  (accepted 2026-06-12; maintainer-amended 2026-06-14 and 2026-06-26)
- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md`
- `inst/design/research/Stable-Parameter-Region-Detection.md`
- `inst/design/audits/v0_1_9_6_intraday_readiness_audit.md`
- `inst/design/vignette_styleguide.md`
- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`

Scope:

- run the `stable_region` detector spike and ship the strict-lattice detector
  only if the spike is accepted;
- add opt-in retained closed-trade evidence for completed sweep candidates;
- add a public return-panel entry point so the selection-integrity diagnostics
  accept a return table directly (no sweep-object boilerplate);
- add the worked-example craft clause and rebuild the Selection Integrity article
  from scratch on that entry point, consuming only the Selection Integrity
  findings from the 2026-09-04 all-vignette review;
- add the intraday metric-context M-1 guardrail as warning-only honesty
  protection;
- conditionally add native K-Ratio if a named variant is reference-verified;
- add `ledgr_business_objective()` and the internal all-pass criterion-step
  contract;
- implement the seven D2 criteria and v1 diagnostic-threshold criteria;
- add `ledgr_sweep_filter()` as an all-candidates evidence surface that cannot
  be used for selection or promotion;
- close release surfaces and deferral ledgers.

Non-scope:

- no automatic promotion or winner selection;
- no objective-filtered walk-forward identity and no
  `business_objective_hash` participation in walk-forward session identity;
- no scored or weighted objective composition;
- no public third-party criterion-extension contract;
- no broader non-lattice robustness criteria;
- no Triple Penance;
- no walk-forward short-window cadence rework or intraday example;
- no first-class intraday runtime;
- no broad all-vignette freshness pass; the remaining 2026-09-04 review
  findings are parked in `inst/design/horizon.md`;
- no talib adapter, crypto-readiness spike, target-helper Pass 2, strategy
  schedule decorator, purging/embargo/CPCV, portfolio optimization,
  point-in-time data tables, paper/live, OMS, or liquidity/capacity work.
