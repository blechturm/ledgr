# ledgr v0.2.0.1 Spec Packet

Status: Batches 0 through 9 complete after review and maintainer acceptance.
Batch 10 is diagnostic history and does not satisfy final evidence. The
trusted-timestamp and benchmark-boundary amendment ticket cut passed
independent review. Batches 11 through 14 are complete after review; Batch 15
is complete after independent review and maintainer acceptance. The local
release gate is complete and the branch is ready for remote branch CI; merge,
main CI, tag, tag CI, and release publication remain later evidence.
The accepted hot-path complexity amendment is cut as LDG-2736 through
LDG-2740, and its ticket cut was independently accepted before implementation.
The maintainer accepted the trusted-timestamp and benchmark-boundary amendment
on 2026-09-18. Its required pre-cut probe selected `NEITHER`, so LDG-2741
through LDG-2744 contain no availability-ingestion source change.

This packet scopes v0.2.0.1 as an internal implementation and correctness
release. It productionizes the three reviewed availability hot-path
representations behind the shared fold, replaces the quadratic seal-time
conflict validators through a separately gated cold-path workstream, repairs
resumed-run equity finalization, and closes with separated cold, warm, and peer
benchmark records. No user-facing changes have shipped from this packet at
ticket cut. The first amendment adds only the two release-material costs
found by the bounded closeout audit: event-buffer writes and fold-time
availability valuation. The first Batch 8 records are provisional diagnostic
evidence and cannot close the release. The second amendment corrects the
public benchmark boundary, dense timestamp validation, within-chunk
snapshot-hash formatting, and proof infrastructure before one new final
record.

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

Hot-path amendment ticket-cut baseline:

- source baseline `6b09a1b57ff42293091130d2dca565f224a29aea`, package
  `0.2.0.1`, R 4.6.1, duckdb 1.5.2, testthat 3.3.2, collapse 2.1.7 in the
  default library and 2.1.8 in the isolated and AppData libraries;
- the accepted audit is
  `dev/spikes/v0_2_0_1_hot_path_complexity_audit/`; and
- raising the package floor to collapse 2.1.8 is pending LDG-2736. This
  baseline records resolution; it does not claim the dependency change has
  landed.

Timestamp/benchmark amendment ticket-cut baseline:

- source baseline `9686229`, package `0.2.0.1`, R 4.6.1 ucrt, duckdb 1.5.2,
  testthat 3.3.2, and collapse 2.1.8 from the isolated library;
- the prerequisite is
  `dev/spikes/v0_2_0_1_availability_timestamp_prerequisite/` and records ten
  exact semantic cases, a 0.763561 session-close ratio, and the binding
  `NEITHER` outcome; and
- R 4.6.1 is the active ticket-cut and implementation runtime. Historical
  baseline versions above remain evidence labels, not current runtime locks.

Authoritative files:

- `v0_2_0_1_spec.md` (accepted 2026-09-16 after two independent review rounds;
  the review drafts are retained in Git history rather than this packet)
- `v0_2_0_1_hot_path_complexity_amendment_proposed.md` (accepted 2026-09-17
  after independent review and focused re-review; the filename preserves its
  proposal history)
- `v0_2_0_1_timestamp_and_benchmark_amendment_proposed.md` (accepted
  2026-09-18 after independent review and focused re-review; the filename
  preserves its proposal history)
- `v0_2_0_1_tickets.md`
- `tickets.yml`
- `batch_plan.md`
- `batch1-baseline-evidence.md` (checker reruns, durable witnesses, test-only
  reference locations, and the draft retirement guard)
- `batch2-provider-evidence.md` (production switch, consumer-boundary tests,
  and focused parity verification)
- `batch3-diagnostic-evidence.md` (production writer boundary, chunk and
  rollback tests, deterministic replay, and dual-collapse verification)
- `batch4-parity-evidence.md` (pre-retirement same-session measurement,
  six-table parity, path retirement, and source-guard verification)
- `batch5-finalization-evidence.md` (interrupted-prefix persistence, atomic
  terminal merge, strict failure matrix, dense-path exclusion, and reopen)
- `batch6-seal-validator-evidence.md` (randomized and adversarial equivalence,
  grouped sweeps, status hybrid, setwise bypass, and structural retirement)
- `batch7-benchmark-manual-evidence.md` (peer phase boundaries, smoke evidence,
  rendered manuals, and documentation contracts)
- `batch8-event-buffer-evidence.md` (collapse route choice, exact parity,
  semantic and failure matrix, five-point scaling, and source retirement)
- `batch9-valuation-evidence.md` (transient valuation state, structural gate,
  paired 757-pulse gate, combined eventful case, and source retirement)
- `batch10-benchmark-evidence.md` (diagnostic first-closeout record; not final
  evidence and not a completed LDG-2733 or LDG-2734 artifact)
- `batch11-boundary-oracle-evidence.md` (public one-candidate benchmark
  boundary, parity and rendering gates, frozen current-arm prefixes, source
  guard, and prospective dense/hash proof plans)
- `batch12-dense-timestamp-evidence.md` (dense semantic matrix, structural
  mutation gate, and paired Stage M record)
- `batch13-snapshot-hash-evidence.md` (byte/hash identity, structural gate,
  and paired Stage N record)
- `batch14-final-evidence.md` and `batch14-stage-o-records.csv` (final-source
  cold, warm, hash, profile, peer, parity, and record-prefix evidence)
- `v0_2_0_1_release_closeout.md` (accepted local release-gate evidence, gate
  adjudication, rerun history, and remote-evidence boundary)
- `dev/spikes/v0_2_0_1_availability_timestamp_prerequisite/probe_findings.md`
  (binding pre-cut `NEITHER` outcome)
- `inst/design/exact_parity_internal_optimization_proof_template.md`
  (accepted evidence infrastructure; not independent implementation authority)

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
- `dev/spikes/v0_2_0_1_hot_path_complexity_audit/` (accepted amendment input;
  its audit probe is not a release benchmark)

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
- require collapse 2.1.8 and linearize character and list event writes in both
  memory and durable handlers under exact parity and paired scaling gates;
- replace fold-time availability matching and price-prefix rescans with
  transient prepared `O(N*P)` valuation state under semantic, structural, and
  paired 757-pulse gates;
- split the peer benchmark's ingestion phase, refresh the manuals, record the
  availability warm, cold seal, and peer benchmarks, review those results at a
  separate checkpoint, and only then run the release gate if authorized;
- measure the two memory peer rows through public one-candidate
  `ledgr_sweep()` calls and bind compensated production-inline equity as their
  reference;
- replace per-bar dense static-coverage timestamp formatting under the full
  semantic, mutation-sensitive structural, and paired performance gates;
- deduplicate timestamp formatting within existing snapshot-hash chunks only
  under byte/hash identity and bounded-memory gates; and
- independently finalize, index, and contract-lock the exact-parity proof
  template before the final accepted-source record.

Non-scope:

- no valuation or mark-history optimization beyond the exact accepted
  fold-time correction; no general loop or frame removal;
- no event-buffer optimization beyond the exact memory and durable correction;
  no public tuning option, cache, persisted prepared artifact, schema table,
  hash, or identity field;
- no spot-crypto probe, compiled availability execution, parallel architecture
  change, Docker benchmark repository, or hosted LEAN;
- no public peer ranking, engine-parity claim, or promotion of the seal
  forecast to a measurement.
- no availability-ingestion timestamp optimization: the accepted prerequisite
  selected `NEITHER` and an exact observation candidate may not ship alone;
- no cross-chunk hash cache, hash-rule change, new memory execution API, or
  other item from the remaining optimization inventory.

Review protocol:

- implement one numbered batch at a time;
- update this README, `batch_plan.md`, `v0_2_0_1_tickets.md`, and `tickets.yml`
  together;
- stop for independent review before committing unless the maintainer directs
  otherwise;
- Batches 2, 3, 5, 6, 8, 9, 11, 12, 13, and 14 each end at a named independent
  review stop;
- the two-arm production parity record (Batch 4) precedes any retirement;
- Batch 10 remains diagnostic history. Batch 14 reruns final records from one
  accepted source commit, stops for independent evidence review, and requires
  an explicit maintainer decision; Batch 15 begins by reading
  `inst/design/release_ci_playbook.md` only after that go-ahead.
