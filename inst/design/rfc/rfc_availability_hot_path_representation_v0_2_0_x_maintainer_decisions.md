# Maintainer Decisions: Availability Hot-Path Representation

**Status:** Accepted on 2026-09-15.
**Authority:** Product-level decisions completing the reviewed RFC synthesis.
**Applies to:** ledgr v0.2.0.1 packet planning.

## Decision 1: release placement

The availability hot- and cold-path optimization work is the v0.2.0.1
release. It is a patch release because the accepted direction changes internal
representation and implementation placement without changing public API,
schema, stored identity, accounting semantics, or availability policy.

## Decision 2: sequencing

The v0.2.0.1 optimization packet precedes the refreshed spot-crypto readiness
probe. Crypto does not share this packet or release number. It returns after
v0.2.0.1 as a separately governed v0.2.0.x planning cycle under the existing
probe-before-prose rule.

## Decision 3: one bounded implementation packet

The v0.2.0.1 packet contains all three accepted workstreams:

1. productionize the reviewed prepared provider, columnar diagnostic writer,
   and per-pulse diagnostic block behind the shared fold core;
2. replace the quadratic seal-time availability validators through a separate
   cold-path gate with randomized semantic equivalence and full-scale
   measurement; and
3. repair interrupted-then-resumed finalization so the complete achieved
   equity prefix survives and reopens under the existing terminal validator.

The cold validator and resumed-run repair are not folded into a performance
claim. Each retains its own correctness and evidence gate inside the packet.

## Decision 4: release-cycle benchmark closeout

The packet requires a fresh peer benchmark during release closeout, after the
production code and parity gates are complete. The comparison uses the existing
standardized public or synthetic workflow at its explicit registered dimensions
and separates snapshot preparation, experiment setup, engine execution, and
result materialization. It records unavailable peer lanes honestly and makes no
public ranking claim without semantic and output reconciliation.

Because the peer workload is dense and static, it does not substitute for a
ledgr-only closeout of the 563-instrument, 757-pulse availability fixture. That
closeout records the warm reused-snapshot experiment and the cold seal as
different clocks. Neither benchmark must run before the packet is drafted.

## Decision 5: deferred directions

The valuation lane remains a separate probe-then-Charter question and does not
block v0.2.0.1. The proposed containerized regression and peer-comparison
laboratory remains a non-binding horizon direction after this release's
benchmark method and workloads are reviewed. Spot crypto, valuation, compiled
execution expansion, and the external benchmark repository are outside the
v0.2.0.1 packet.

## Acceptance

The maintainer accepts
`rfc_availability_hot_path_representation_v0_2_0_x_synthesis.md` with these
decisions after the independent final review disposition
`PASS_AFTER_PATCHES`. The accepted synthesis and this decision record are
binding inputs to the v0.2.0.1 spec. No implementation tickets exist yet; the
next artifact is the spec draft for independent review.
