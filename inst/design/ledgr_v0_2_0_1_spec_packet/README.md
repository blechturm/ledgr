# ledgr v0.2.0.1 Spec Packet

Status: Batches 0 through 3 complete after review and maintainer acceptance.
Batches 4-8 are pending.

This packet scopes v0.2.0.1 as an internal implementation and correctness
release. It productionizes the three reviewed availability hot-path
representations behind the shared fold, replaces the quadratic seal-time
conflict validators through a separately gated cold-path workstream, repairs
resumed-run equity finalization, and closes with separated cold, warm, and peer
benchmark records. No user-facing changes have shipped from this packet at
ticket cut.

Ticket-cut baseline:

These versions record the environment used to cut the packet. They do not set
the package support floor or constrain later implementation verification;
`DESCRIPTION` remains authoritative for supported R versions.

- source baseline `f0b847d02c2cf66a9871fdda119f55e0ccfd7e42` on branch
  `v0.2.0.1`, package `0.2.0.1`;
- R 4.5.2 ucrt on `x86_64-w64-mingw32`;
- duckdb 1.4.3, testthat 3.3.1, and collapse 2.1.7 in the default library, with
  collapse 2.1.8 available from the isolated library
  `C:/tmp/ledgr-collapse-218-lib` for the dual-version gate;
- the reviewed spike seams are present at the baseline behind their internal
  options and default to the old paths; the spike checkers reported 37 of 37,
  54 of 54, and 54 of 54 checks at their evidence reviews and are rerun against
  the baseline in Batch 1 before any production change.

Authoritative files:

- `v0_2_0_1_spec.md` (accepted 2026-09-16 after two independent review rounds;
  the review drafts are retained in Git history rather than this packet)
- `v0_2_0_1_tickets.md`
- `tickets.yml`
- `batch_plan.md`
- `batch1-baseline-evidence.md` (checker reruns, durable witnesses, test-only
  reference locations, and the draft retirement guard)
- `batch2-provider-evidence.md` (production switch, consumer-boundary tests,
  and focused parity verification)
- `batch3-diagnostic-evidence.md` (production writer boundary, chunk and
  rollback tests, deterministic replay, and dual-collapse verification)

Binding design inputs:

- `inst/design/rfc/rfc_availability_hot_path_representation_v0_2_0_x_synthesis.md`
- `inst/design/rfc/rfc_availability_hot_path_representation_v0_2_0_x_maintainer_decisions.md`
- `inst/design/rfc/rfc_availability_hot_path_representation_v0_2_0_x_final_review.md`
- `inst/design/contracts.md`
- `inst/design/spike_protocol.md` (section 10 clocks)
- `inst/design/manual/benchmark_methodology.qmd`
- `inst/design/manual/optimization_coding_style.qmd`
- `inst/design/release_ci_playbook.md`

Reviewed execution evidence (starting points, not automatic merges):

- `dev/spikes/availability-hot-path-representation/`
- `dev/spikes/availability-provider-preparation/`
- `dev/spikes/availability-diagnostic-block-write/`
- `dev/spikes/snapshot-sealing/`

Scope:

- port the spike scenarios into durable tests and retain test-only references;
- productionize the prepared provider (two measured membership shapes, CSR
  status, lifetime, and terminal-event planes with monotone re-seeking
  cursors) and route every provider-build consumer through it;
- productionize the typed diagnostic writer and the per-pulse diagnostic block;
- prove full persisted parity before retiring the old paths, then retire them
  with a source guard;
- merge the complete equity prefix for resumed availability-aware runs and
  keep the strict terminal validator;
- replace the membership, status, and lifetime pairwise validators with
  grouped sweeps under randomized and adversarial equivalence, with setwise
  validation before any complete-set bypass;
- split the peer benchmark's ingestion phase, refresh the manuals, and record
  the availability warm, cold seal, and peer closeouts.

Non-scope:

- no valuation or mark-history optimization; no general loop or frame removal;
- no public tuning option, cache, persisted prepared artifact, schema table,
  hash, or identity field;
- no spot-crypto probe, compiled availability execution, parallel architecture
  change, Docker benchmark repository, or hosted LEAN;
- no public peer ranking, engine-parity claim, or promotion of the seal
  forecast to a measurement.

Review protocol:

- implement one numbered batch at a time;
- update this README, `batch_plan.md`, `v0_2_0_1_tickets.md`, and `tickets.yml`
  together;
- stop for independent review before committing unless the maintainer directs
  otherwise;
- Batches 2, 3, 5, and 6 each end at a named independent review stop;
- the two-arm production parity record (Batch 4) precedes any retirement;
- Batch 8 begins by reading `inst/design/release_ci_playbook.md`.
