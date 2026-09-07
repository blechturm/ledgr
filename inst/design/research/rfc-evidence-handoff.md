# Ragged-Universe RFC Evidence Handoff

This memo supplies evidence for a later upstream RFC. It does not choose an
architecture or authorize implementation.

## Established facts

The strongest result is negative and real: exhaustive Gate 4 enumeration of
the complete supported 2019-2021 population found a qualifying ragged shape.
The full population—757 expected sessions, 563 point-in-time members, and
382,288 expected member/session rows—entered ledgr pressure without a secondary
selector, survivor filtering, date intersection, price filling, or fabricated
rows. ledgr could seal the available bars but its static instrument input could
not preserve daily membership and expected-absence semantics.

The dense seam is independently real. The frozen 5-by-20 rectangle sealed,
verified on reopen, and completed reconciled flat and next-open round-trip runs.
This proves storage and execution plumbing for a dense/static slice, not
historical universe validity.

External lineage remains in a hash-bound sidecar. The ledgr snapshot stores and
seals bars and instruments but has no first-class channel for the vendor build,
universe construction, quality policy, or limitations. Corporate-action census
evidence also confirms that current accounting does not support dividend or
terminal-event performance claims.

The absence diagnostics distinguish missing market observations, unavailable
execution prices, potentially stale valuation inputs, feature warm-up,
model-input missingness, and censored labels. No imputation was performed.

## Supported inferences

A future runtime needs some explicit availability state beyond a static list of
instruments if it is to distinguish outside-lifetime, outside-membership,
expected-but-absent, invalid, and unresolved cells without inventing prices.
Strategy visibility, valuation, orderability, and execution may need different
responses to those states.

Deterministic as-of transformations and statistically fitted fold-local
transformations are likely to have different state, identity, and caching
needs. The evidence supports investigating that distinction, but does not prove
that these are the final abstraction families.

## Unresolved questions

- What representation should bind snapshot identity, security lifetime,
  point-in-time membership, availability, and external lineage?
- Which states should a strategy see, which can be valued, and which can accept
  an order or execution?
- Should the LFB-002 metadata channel be a prerequisite RFC or part of the
  ragged-universe design?
- What dependency, identity, caching, and delivery model should govern simple
  as-of and walk-forward fitted indicators or imputers?
- How should dividends and terminal events enter ledger accounting and the
  validity of performance claims?
- What evidence is required before the umbrella seed may leave draft status?

## Deferred implementation

The later cycle decides whether to use one umbrella architecture RFC followed
by smaller implementation RFCs or several coordinated seeds. This packet does
not prescribe interval tables, masks, event streams, metadata APIs, indicator
DAGs, imputation APIs, or accounting mechanics. Broad-equity and dynamic-
membership strategy research remain closed unless the independent closeout
explicitly approves the one narrow allow-listed scope—and even that scope does
not authorize those broader claims.
