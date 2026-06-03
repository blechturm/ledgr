# ADR 0005: B2 Spot-FIFO Scope Guard

## Status

Accepted for v0.1.8.11 as a documentation and governance consolidation of
decisions shipped in v0.1.8.10.

## Context

The v0.1.8.10 B2 work measured and shipped a scoped compiled hot-frame
accelerator for memory-backed sweep execution. The accepted B2 RFC synthesis
bound B2 as a production-parity measurement gate, and the maintainer-decisions
artifact narrowed that synthesis for one public opt-in:
`compiled_accounting_model = "spot_fifo"` for memory-backed sweeps.

That opt-in is intentionally narrow. It is not a general compiled fold core,
not a durable committed-run execution path, not a derivatives or margin
accounting model, and not a new default. Current contracts keep
`compiled_accounting_model = NULL` as the canonical R fold path and limit the
compiled model enum to `"spot_fifo"` for the supported memory-backed sweep
case.

Authoritative source records:

- `inst/design/rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_synthesis.md`
- `inst/design/rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`
- `inst/design/rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_final_review.md`
- `inst/design/ledgr_v0_1_8_10_spec_packet/v0_1_8_10_spec.md`
- `inst/design/contracts.md`
- `inst/design/horizon.md`

## Decision

ledgr treats the v0.1.8.10 B2 path as a spot-asset FIFO fill-batch accelerator
only. The supported public opt-in is memory-backed sweep execution with
`compiled_accounting_model = "spot_fifo"`. Canonical R remains the default
execution path.

The B2 spot-FIFO kernel must not be generalized into durable compiled run
execution, default compiled execution, non-spot accounting, derivatives,
margin, options, additional compiled accounting models, or a broad compiled
fold core without a new RFC and explicit release-packet scope.

Unsupported compiled accounting modes must fail closed rather than silently
falling back or widening the compiled path.

## Consequences

- Future v0.1.9.x or v0.2.x work cannot cite the v0.1.8.10 B2 pass as
  authorization for a general compiled fold core.
- Durable compiled integration, non-spot compiled accounting, additional
  compiled accounting models, and default compiled execution require fresh RFC
  review.
- The existing B2 opt-in remains valid for its measured memory-backed
  spot-FIFO sweep scope.
- Contracts and user-facing documentation should describe B2 as a scoped
  accelerator, not as the ledgr execution engine.
