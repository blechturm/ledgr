# ledgr v0.2.0.0 Spec Packet

Status: Batches 0-7 complete after review. Batches 8-11 are pending.

This packet scopes v0.2.0.0 as an ordered hardening-and-availability release.
It first corrects known API and representation boundaries, then extracts the
existing coordinator without moving effects, and only then implements the
first point-in-time asset-availability path on the shared fold.
No user-facing changes have shipped from this packet at ticket cut.

Ticket-cut baseline:

- source baseline `048b925e5411b7c1a7500d4163163aed72039062`;
- R 4.5.2 ucrt on `x86_64-w64-mingw32`;
- duckdb 1.4.3 and dplyr 1.1.4;
- no named maintainer-owned store inventory was supplied at cut, so LDG-2684
  must inventory those stores and affected wide artifacts before editing.

Authoritative files:

- `v0_2_0_0_spec.md`
- `v0_2_0_0_tickets.md`
- `tickets.yml`
- `batch_plan.md`
- `wide_projection_store_inventory.md`
- `availability_walkthrough_fixture.md` (design-only fixture shape; not runtime evidence)

Binding design inputs:

- `inst/design/rfc/rfc_api_representation_hardening_v0_2_0_synthesis.md`
- `inst/design/rfc/rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md`
- `inst/design/contracts.md`
- `inst/design/spike_protocol.md`
- `inst/design/vignette_styleguide.md`
- `inst/design/release_ci_playbook.md`
- `inst/design/audits/v0_2_0_test_suite_audit.md`

Scope:

- correct reversal-fee projection, eager fills, review lineage, retained risk
  provenance, and run-info risk identity;
- make run handles durable locators and repair the public target/workflow
  teaching path;
- split `R/backtest.R` by ownership and extract four coordinator stages in
  bounded, behavior-preserving commits;
- add the finalization failure/recovery contract and the remaining causal,
  RNG, cleanup, and wide-name boundary corrections;
- add normalized point-in-time fact families, a complete session clock,
  acknowledged invalid-observation quarantine, hash rule 2, and transactional
  schema migration;
- add availability activation, the internal provider, dynamic pulse axes,
  stable-key asset state, and strict expected-session features;
- implement target restrictions, the active short-exposure guard, stale-mark
  valuation, bounded affordability, and controlled incomplete outcomes on the
  shared fold;
- persist completion and diagnostic evidence through direct runs, sweeps,
  parallel dispatch, and walk-forward evaluation;
- ship durable explanation/result views and a survivorship-bias article with
  one connected ingest-run-explain-reopen workflow.

Non-scope:

- no second execution engine, package split, broad rename, public cursor,
  generic registry, witness framework, or export-count target;
- no short-account financing, borrow/margin, corporate-action settlement,
  OMS, live recovery, configurable cash tolerance, or generalized liquidity;
- no imputation graph, fitted preprocessing, cross-sectional cache, calendar
  expansion, multi-venue/subdaily scheduling, or representation optimization;
- no public benchmark claim, CI redesign, or coverage reduction.

Review protocol:

- implement one numbered batch at a time;
- update this README, `batch_plan.md`, `v0_2_0_0_tickets.md`, and `tickets.yml`
  together;
- stop for independent review before committing unless the maintainer directs
  otherwise;
- Batch 8 must pass its economics/controlled-prefix review before Batch 9;
- Batch 9 must pass terminal recovery and cross-path evidence review before
  documentation closeout;
- Batch 11 begins by reading `inst/design/release_ci_playbook.md`.
