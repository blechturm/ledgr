# Closeout: Atomic Class B Settlement

**GREEN under the Charter question:** one validated grouped operation consumed
parent lots, created on-axis recipient lots, preserved caller-supplied model
basis, and survived fold, replay, interruption, resume, and reopen.

Nine cases ran. Pure-stock exchange, spin-off, multiple recipients, an existing
recipient position, and multiple parent lots completed with positions equal to
lot state and total model basis preserved. Malformed allocation and a short
recipient failed before an event was appended. The compiled arm refused the
unknown operation explicitly rather than completing after dropping it.

The group was persisted as one schema-compatible prototype row. That choice
demonstrates feasibility only; it does not select `CASHFLOW`, a new event type,
or another production serialization. Basis fractions were inputs, not derived
economics. Cash and mixed consideration were not tested.

The checker reran the nine cases and reproduced the evidence CSV byte-for-byte.
Gutting parent-lot consumption caused the basis invariant to fail before
append. No package source, tests, namespace, description, manual, or design
file changed during execution.

The RFC may consume three conclusions: Class B is implementable on the current
lot carrier; validate-then-apply can make a multi-leg group atomic at this
boundary; and the compiled envelope must refuse the operation until it gains
an independently verified implementation.

What remains open is economic rather than primitive: model-basis derivation,
cash and mixed consideration, fractional units, posting policy, final event
vocabulary, and the two unresolved Sharadar recipients.
