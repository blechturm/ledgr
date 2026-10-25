# Cut 20 review: Cross-asset correctness and disclosure corrections

Mode: Type 1 cut review with an independent input and necessity check.

Verdict: **CHANGES_REQUIRED**.

The three-ticket direction is necessary, bounded and supported by the current
implementation and the completed crypto-readiness spike. No Type 2 decision is
needed. Two specification patches are required before implementation.

## F1: bind the durable default-calendar carrier

LDG-3107 correctly keeps omitted and explicitly equal metric contexts identical
for computation and identity, but it did not name how the omitted-versus-explicit
distinction survives reopen. Omission is erased by
`ledgr_metric_context_resolve()`, and reopened runs recover the context from the
stored metric-context record.

The existing calendar display label is the smallest valid carrier. It is stored
in `metric_context_json` and deliberately excluded from the metric-context hash.
The ticket must use that label rather than add an unversioned record field. It
must also cover every public calendar-omission form: `metric_context = NULL`,
numeric or risk-free-rate shorthand, and `ledgr_metric_context()` without a
calendar. Explicit US-equity and crypto calendars remain unmarked.

## F2: scope the terminal witness to availability

LDG-3106 can prove dust normalization through both dense and availability runs,
but a lifetime terminal disposition is an availability fixture. Its first
criterion must say that the later disposition belongs to that fixture. The
ticket should also state that replay, resume, reconstruction and carried openings
reuse the accounting transition's normalized result rather than inventing a
reader-side dust tolerance.

## Independently checked and clean

- The ordinary fold path applies `ledgr_lot_dust_tolerance()` to FIFO lots but
  adds the fill quantity to the canonical position without normalization. The
  compiled spot-FIFO path has the same boundary, so D1 is vendor-neutral and
  real.
- LDG-3106 otherwise covers dense and availability execution, ordinary and
  compiled accounting, reconstruction and carried state without inventing
  quantity granularity or changing trade economics.
- An omitted metric context still resolves to US-equity daily and 252 periods
  per year; the declared session axis does not choose annualization.
- The existing hash/storage split makes LDG-3107 feasible without an identity
  change or schema migration once F1 is applied.
- One helper emits all four current `Corporate actions` fidelity headlines.
  `Economic events` is already established package terminology and remains
  truthful when the existing suffixes, states and non-support disclaimer stay.
- D2 and D3 consistently route to the post-v0.2.2 cross-asset precision and
  tradability RFC. D5 stays adapter or strategy policy pending broader evidence,
  and the public `ledgr.crypto2` package remains deferred.
- The macro plan, horizon, RFC index and roadmap agree. Workstream 59 depends on
  Workstream 58, the three tickets are independent, ticket IDs are unique, and
  the YAML parses.
- The spike supplies runnable public-API evidence without requiring its private
  provider data. Workstream 59 must not open until Cut 19 closes and the spike
  commits are integrated.
