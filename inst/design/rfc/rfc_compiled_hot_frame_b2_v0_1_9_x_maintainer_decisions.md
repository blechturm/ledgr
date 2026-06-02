# RFC Maintainer Decisions: Compiled Hot Frame B2 (v0.1.9.x)

**Status:** Maintainer decision recorded. Binding input to synthesis.
**Cycle:** Architecture B2 measurement gate / v0.1.9.x promotion scoping.
**Relates to:** `rfc_compiled_hot_frame_b2_v0_1_9_x_seed_v2.md` and
`rfc_compiled_hot_frame_b2_v0_1_9_x_seed_v2_review.md`.
**Authored:** Maintainer decision recorded by Codex on 2026-06-02.

## Decision 1: B2-first sequencing override

The maintainer accepts the B2-first sequencing override requested in
seed v2.

Rationale:

- The Rust/C infrastructure already exists in the external
  `ledgrcore-spike` repo.
- The time required to build a detailed R fold-core attribution harness
  can instead be spent building the compiled core components that the
  project actually wants to measure.
- This is a more direct test of the proposed solution than first
  building a redundant R telemetry path that may be abandoned after the
  compiled-path decision.

This decision does **not** authorize promotion of compiled code into
ledgr. The compiled path must still earn its keep.

Promotion remains gated on:

- production-faithful parity;
- measured wall recovery;
- acceptable integration and toolchain cost;
- no regression of ledgr's existing event, fill, equity, lot-accounting,
  and strategy contracts.

If the compiled core components do not meet those gates, they are parked
and the ephemeral xlarge wall attribution spike becomes the next
diagnostic path.

## Synthesis consequence

Synthesis should treat the sequencing question as resolved:

- B2 measurement runs before the ephemeral attribution spike.
- The attribution spike remains fallback / follow-up if B2 fails or
  produces an ambiguous result.
- The decision-bearing B2 measurement must use the compiled path that is
  actually under consideration, not a handler-preserving approximation
  that leaves the hot work in R.

The remaining seed-v2 review findings still need synthesis or seed-v3
treatment:

- the first-cut recoverable-slice table must match the actual compiled
  scope;
- Pattern A is not K1-equivalent inline output and cannot be the only
  promotion gate;
- the production Sub-B swap mechanism must be decision-bearing rather
  than a prototype-only instrumented copy.
