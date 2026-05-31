# Claude Review Prompt: ledgr v0.1.8.9 Ticket Cut

Please peer review the v0.1.8.9 implementation-ticket cut in
`inst/design/ledgr_v0_1_8_9_spec_packet/`.

Read:

- `v0_1_8_9_spec.md`
- `v0_1_8_9_tickets.md`
- `tickets.yml`
- `batch_plan.md`
- the source synthesis at
  `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/architecture_synthesis.md`

Review goals:

1. Verify that `LDG-2496` through `LDG-2501` map cleanly to the measured
   headline lanes from the synthesis:
   - fills extractor `setv`;
   - persistent durable handler `setv`;
   - memory output handler `setv`;
   - position valuation vectorization;
   - target-delta vectorization;
   - yyjsonr and canonical JSON byte-format v2.
2. Verify that each headline lane is its own ticket and cannot be bundled with
   another hot-path change without losing the required per-lane attribution.
3. Verify that the Kahan-vs-cumsum attribution correction is mandatory release
   gate work, not parked in optional cleanup triage.
4. Verify that yyjsonr migration covers:
   - package-wide `jsonlite` call-site removal;
   - `simplifyVector = FALSE` and `simplifyVector = TRUE` read parity;
   - canonical JSON v2 byte fixtures;
   - hard-coded hash regeneration;
   - strategy provenance fingerprint fallout;
   - DESCRIPTION, contracts, tests, and NEWS alignment.
5. Verify that `LDG-2502` remains conditional cleanup triage only, with Spike 3,
   Spike 5, and residual fills extraction robustness either measured separately
   or explicitly deferred.
6. Verify that `LDG-2503` requires both:
   - aggregation of the per-lane attribution table; and
   - the final v0.1.8.8 to v0.1.8.9 workload-grid / peer-benchmark comparison.
7. Verify that `LDG-2504` contains the release gate, full tests/checks, release
   closeout review, documentation index updates, and no-public-speed-claim
   framing.

Anti-shortcut checks:

- No public ephemeral fast path is introduced by the memory-handler ticket.
- No `ledgrcore`, target risk, walk-forward, OMS, public cost API, or public
  benchmark claim is promoted into this release.
- No ticket can close without a measurement gate where the spec requires one.
- No optional cleanup lane can land without its own attribution row.
- The batch plan matches the ticket DAG and preserves sequential measurement
  discipline.

Please report:

- Verdict: approve / approve with caveats / block.
- Critical issues that must be fixed before implementation starts.
- Optional governance or wording improvements.
- Any mismatch between the spec, markdown tickets, YAML tickets, and batch plan.
