# v0.1.8.9 Ticket-Cut Review Closeout

Date: 2026-05-31

Scope: Batch 0 / `LDG-2495` packet alignment and ticket-cut review.

## Verdict

Claude reviewed the v0.1.8.9 ticket cut and returned:

> Approve With Caveats.

The caveats were small packet edits, not a re-cut:

- move the Kahan-vs-cumsum parity-attribution correction out of optional P2
  cleanup and into the mandatory release gate;
- require Claude review feedback to be patched or explicitly accepted before
  implementation starts;
- name Spike 3's `state$positions` disposition in optional cleanup triage;
- require a full test-suite gate after yyjsonr fixture regeneration.

## Patches Applied

- `v0_1_8_9_spec.md` now states the Kahan-vs-cumsum attribution correction is
  mandatory release-gate work.
- `v0_1_8_9_tickets.md` moves the Kahan attribution task to `LDG-2504`,
  updates `LDG-2502` to cover Spike 3 disposition, and tightens `LDG-2495`
  review acceptance.
- `tickets.yml` mirrors those gates with
  `claude_review_caveats_resolved`, `spike3_disposition_review`,
  `full_test_suite_after_fixture_regeneration`, and
  `parity_attribution_grep`.
- `batch_plan.md` records the same Batch 0, Batch 7, and Batch 9 exit
  criteria.
- Future review prompts should be sent in chat instead of written into the
  repository, to avoid cluttering the packet with transient review requests.

## Batch 0 Checks

- Spec, tickets, YAML, and batch plan agree on the `LDG-2495` through
  `LDG-2504` ticket spine.
- `inst/design/README.md` points to v0.1.8.9 as the active packet.
- No implementation ticket is missing a measurement gate.
- Deferred scopes remain deferred: public ephemeral fast path, `ledgrcore`,
  target risk, walk-forward, OMS, public cost/liquidity APIs, public benchmark
  claims, and memory-handler `meta_json`.
- Claude review caveats are patched into the packet.

Batch 0 is closed. Batch 1 (`LDG-2496`, fills extractor `setv`) is ready to
start.
