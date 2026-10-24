# Focused Amendment: Ordinary History Manifestation

**Status:** Accepted by the maintainer on 2026-10-24 after Type 2 review
PASS_AFTER_PATCHES. Implementation is owned by Cut 19 LDG-3105.
**Author:** Codex, for maintainer adjudication.
**Date:** 2026-10-24.
**Amends if accepted:** Sections 3, 5, 7, 10 and 12 of the
[accepted historical-projection v12 synthesis](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md),
and only the matching parts of its "As implemented" appendix.
**Evidence:** the GREEN
[history-manifestation spike](../../../dev/spikes/history-manifestation/spike_closeout.md),
the [spike inventory](../../../dev/spikes/history-manifestation/spike_inventory.md),
and the retained Workstream 55 implementation record.

This is a focused amendment under `../rfc_cycle.md`. Until it is accepted,
v12 and the current contracts remain authoritative. It does not reopen the
causal cutoff, history axis, hydration, treatment, feature-vintage, selection,
readiness, estimator-admission or execution semantics accepted in v12.

## 1. Problem and necessity

The public history surface is semantically correct but its ordinary materialized
results do too much work. A 500-instrument by 252-session direct matrix read
currently takes 24.198 ms in the spike fixture. Most of that time and allocation
comes from rebuilding aligned cell-evidence planes and hashing the transient
numeric result. The same prepared values can become an exact classed matrix in
0.427 ms and an exact wide frame in 0.405 ms, with about two payload copies and
no digest.

The extra integrity work is redundant. ledgr has already verified the sealed
snapshot and the owning run or session has already validated and prepared the
causal substrate. A temporary R matrix or data frame is not another durable
artifact. It should inherit that provenance, not pretend to become a new sealed
object.

The correction is necessary before the minimum-variance teaching and other
history-dependent strategy work. The accepted UX assumes on-demand
manifestation is cheap relative to a pulse. Retaining a 20-30 ms ordinary read
would make that assumption false and would encourage either manual private
access or large retained caches.

## 2. Bound trust boundary

The integrity boundary is:

1. a sealed snapshot verified under its current snapshot-hash rule; and
2. an owner-validated causal substrate prepared once for the run, sweep,
   walk-forward session or supported inspection context.

An ordinary history result inherits the snapshot hash, history-policy identity,
source identity, cutoff, window and selection description from that boundary.
It is not independently content-hashed, sealed, re-verified against the store or
rescanned solely to prove integrity. No public bypass, trust flag or validation
knob is added.

The result is a fresh isolated R value. Caller mutation cannot reach the
prepared substrate or a later read. "Immutable" in v12 is therefore narrowed to
this isolation guarantee; ledgr does not authenticate an ephemeral object after
the caller mutates it. Registered ledgr arithmetic, math, replacement and
subsetting methods drop identity where they dispatch. Base R or third-party
operations may nevertheless change values while preserving custom attributes.

Metadata helpers validate class, dimensions, ordered axis, included IDs and
recorded request metadata. They do not attest that the current numeric cells
still equal the originating read and must not hash or fully rescan them.
Admission, carry disclosure and readiness describe the originating read; they
are stale if a caller preserves the attributes while changing values. The
contract and tests must state this limitation explicitly instead of promising
that every transformed value refuses.

Manually restoring attributes and ordinary attribute-preserving transforms are
both outside the content-integrity guarantee. This is not a weaker snapshot or
run guarantee: the snapshot, policy, strategy, results and ledger remain
identified and verified by their existing owners.

## 3. Two ordinary sibling manifestations

`ledgr_history_matrix(ctx, ...)` and
`ledgr_history_frame(ctx, ..., layout = "wide")` are sibling manifestations of
one private causal read-and-selection description. Neither ordinary context form
is implemented through the other. They share exactly one owner for:

- cutoff and session positions;
- requested and admitted instruments;
- causal value and sparse treatment locations;
- finite-observation counts and exclusion reasons; and
- compact request and provenance metadata.

The prepared value plane keeps its canonical instrument-by-session orientation.
The matrix copies the requested cells into sessions-by-instruments orientation
once. The wide frame constructs its columns directly from the requested
instrument rows; it does not first allocate the matrix or a full transposed
payload. No opposite-orientation history plane, full-history result cache or
collection of prepared data frames is retained.

The existing `ledgr_history_matrix(history)` adapter remains a convenience for
an intact frame supplied by the caller. It reads no substrate and does not make
the context form an adapter path.

## 4. Ordinary metadata and selection

An ordinary matrix or wide frame records only metadata needed to identify the
request, explain estimator admission and safely align downstream output:

- source and resolved feature or bar identity;
- snapshot hash and history-policy identity;
- cutoff, data start, returned-window start, requested lookback and available
  lookback;
- selector, `min_observations`, `min_instruments` and `passed_warmup`;
- requested, included and excluded stable instrument IDs;
- the ordered returned session axis and exact requested and included ID order;
- the current selection-table fields for each requested or decision-axis
  instrument: requested, cutoff admissibility, inclusion, exclusion reason,
  finite-observation count, required-input count, carried-input count and
  carried-input share;
- `used_before_window`; and
- layout and returned dimensions.

This information remains available through `ledgr_history_info()`. Its retained
size is O(returned sessions plus requested or decision-axis instruments), not
O(sessions times instruments), apart from the one numeric payload the caller
requested. It contains no session-by-instrument evidence matrix and no duplicate
numeric payload. `ledgr_passed_warmup()` reads the recorded originating result.
`ledgr_align_weights()` uses the structurally valid result and included IDs;
neither helper hashes or scans history values.

Estimator admission is unchanged. Finite values in the treated returned window
count, including permitted input- or output-carried values. The least-machinery
baseline permits one bounded semantic scan of the requested treated slice to
derive finite counts, carried-input disclosure, exclusion-reason predicates and
`used_before_window`. It may be fused with the copy, but fusion is not required
unless the bounded form misses a binding resource gate. A second scan of the
completed public result solely for integrity is forbidden.

The correction does not add a dense finite-count prefix plane. A prepared
sparse or cumulative summary requires new evidence and design only if the
bounded semantic scan misses a gate; its retained bytes, cutoff-overlay
correctness and removal condition must then be measured before it can replace
the baseline.

`used_before_window` remains the v12 Boolean with its existing bar, bounded
feature and history-dependent feature meaning. Its answer comes from the
prepared treatment and dependency summaries plus the bounded requested-cell
scan and request bounds; it may not trigger reconstruction of cell evidence or
a scan of unrequested history.

## 5. Diagnostic evidence

The ordinary estimator path is not the only history use. The existing explicit
long layout remains the diagnostic manifestation. It may return the v12
cell-level columns because the caller asked for a row-per-cell evidence view.
It remains derived from the same cutoff, selection and prepared causal answers;
it is not a second semantic reader.

The wide result no longer stores hidden copies of those planes. Reproducible
diagnosis means reacquiring the same supported experiment or owner context at
the cutoff, then requesting the recorded resolved source and exact requested IDs
explicitly with the recorded lookback and requirements. The compact ordinary
metadata contains those request coordinates. Long values and cell evidence must
then agree with the originating ordinary read. Original decision-axis and
admissibility evidence comes from the retained selection table unless the same
execution context itself is reopened.

This is context-backed replay, not a detached reader. The history result does
not by itself reconstruct strategy parameters, holdings or a walk-forward
session, and the amendment adds no such mechanism. Native experiment, run and
session identity remains the provenance required to reacquire the owner context.

No new diagnostic helper, durable evidence table or cache is introduced by this
amendment. If the existing long layout cannot reproduce a concrete required
diagnostic from the compact coordinates, that is a blocking implementation
finding for the correction cut rather than permission to restore eager evidence
to ordinary reads.

## 6. Empty shapes, identity and parity

The accepted empty-shape rules are unchanged. Matrix and wide-frame siblings
must agree on numeric values, timestamps, stable instrument IDs, selection,
cutoff, policy identity and compact provenance for ordinary, empty-axis and
zero-instrument requests. Frame and matrix differ only in their public R shape.

Dense contexts and unsupported snapshot-only inspection still refuse as v12
requires. Run, sweep, walk-forward, explicit precompute and supported pulse
inspection use the same manifestation description. Bar, feature, late-known
fact, carried-input, carried-output and barrier semantics remain those of the
accepted substrate; this amendment only removes redundant result construction.

A fresh result from the same prepared request is value-identical but need not be
object-identical after caller mutation. No transient result hash enters config,
run, sweep, candidate, promotion or result identity.

## 7. Resource and detecting gates

The correction cut owns these binding gates on the registered Windows reference
host and the spike's deterministic 500-instrument by 252-session fixture:

1. matrix and wide-frame medians are each at most 0.75 ms;
2. both have exact values, dimensions, dimnames, selected IDs and compact
   metadata parity with the registered oracle;
3. both perform zero digest calls and at most 2.5 returned-double-payload copies;
4. instrument-axis growth at 252 sessions and session-axis growth at 500
   instruments are gated separately, each over at least three registered sizes
   and with a log-log exponent from 0.65 through 1.30;
5. expanding the source from 252 to 1,260 sessions while holding the complete
   500 by 252 ordinary request fixed changes median latency by at most 0.1 ms;
6. the retained result contains neither the sibling representation nor
   cell-aligned wide evidence.

The 0.75 ms bound includes exact estimator admission and all retained compact
metadata. It is an implementation margin above the spike's 0.5 ms research
target, not a claim about every host. Gate 5 strengthens the spike's raw-slice
measurement to a complete-read implementation gate. CI binds exactness and
structural detectors; the reference host binds clocks and allocation.

Registered detectors must fail when a mutation:

- restores transient value hashing, sealing or a whole-result integrity scan;
- rebuilds aligned evidence during an ordinary matrix or wide-frame read;
- builds either ordinary representation through the other;
- touches source columns outside a fixed requested window, detected by an exact
  access counter or mock rather than inferred only from a clock;
- gives frame and matrix different selection or `used_before_window` answers;
- loses mutation isolation and lets a returned object modify the substrate;
- adds a dense finite-count plane or an unreviewed prepared count index; or
- makes the diagnostic long view disagree with the ordinary values and compact
  request coordinates.

Feature values, late-known overlays, carry and barrier cases need independent
witnesses. The bar-only spike does not prove them.

## 8. Supersession map

If accepted, this amendment makes only these changes to v12:

| v12 location | Disposition |
| --- | --- |
| Section 3, fresh immutable results and transformed-result refusal | Replace authenticated value equality and universal transformed-result refusal with fresh isolation and provenance-only structural validation, including the attribute-preserving-transform limitation in Section 2 here. |
| Section 3, wide cell evidence, selection table and `ledgr_history_info()` | Remove eager aligned evidence only. Retain the ordered axis, ordered IDs and all current selection fields named in Section 4 here. |
| Section 3, matrix reader and adapter | Retain the public forms; bind the sibling context manifestations in Section 3 here. |
| Section 5, evidence delivered with values | Retain the evidence vocabulary, selection disclosure and long diagnostic layout; ordinary wide and matrix results carry compact summaries, not aligned planes. Diagnostic replay is context-backed cell replay, not detached selection replay. |
| Section 7, transient views | Replace "views" where it implies rich reconstruction with the direct bounded manifestations and trust boundary here. |
| Section 10, evidence gates | Add Section 7's resource, mutation and feature/late-knowledge gates. |
| Section 12 and implementation appendix | Route the correction into Cut 19 before Workstream 58 teaching. |

All other v12 decisions remain accepted. In particular, this amendment does
not alter what data is causal, how missingness is treated, which instruments
are admitted, how readiness is computed or what a strategy does with an
excluded holding.

## 9. Ticket-cut obligations

The Cut 19 amendment must:

1. reopen or replace LDG-3099 and LDG-3100 without rewriting their historical
   evidence;
2. give one ticket ownership of the private read description, compact metadata,
   sibling manifestations and removal of the transient hash;
3. use one bounded semantic scan of the requested treated cells as the
   least-machinery baseline; a fused copier is required only if that baseline
   misses a gate, and no prepared count index is introduced by this cut;
4. preserve the explicit long diagnostic layout or demonstrate before removal
   that no current contract, article or test relies on its evidence;
5. amend the Context Pulse Data and Axis-Aligned Accessors contract, its
   `ledgr_history_info()` clause and the strategy-context teaching only after
   implementation evidence exists;
6. run the gates in Section 7 plus run, sweep, walk-forward, precompute and
   supported inspection parity; and
7. add the correction ticket as an explicit `tickets.yml` dependency of
   LDG-3104, rather than relying on prose to keep Workstream 58 blocked.

No schema, durable format, snapshot hash, execution identity or public bypass is
authorized. The correction is a refactoring of a transient public result
boundary with a deliberate narrowing of its eager evidence payload.

## 10. Evidence limits and next stage

The spike proved the bar-fixture value path, selected IDs, direct manifestation
cost, allocation, zero digests and returned-cell scaling. It did not prove the
production count-summary representation, compact exclusion reasons,
`used_before_window`, feature values, late-known overlays or diagnostic replay.
Those remain binding review targets. The v1 bounded semantic scan is evidence
for the least-machinery baseline: its approximately 0.490 ms matrix and 0.619 ms
frame results are both inside the amendment's 0.75 ms implementation gate.

The adversarial Type 2 review returned REVISE. The accepted amendment adopts
provenance-only structural identity and the bounded semantic scan, retains the
full selection disclosure and ordered axis, narrows diagnostic replay, splits
the growth gates by axis and makes the Cut 19 dependency executable. Next is a
focused confirmation of those corrections. Cut 19 LDG-3105 owns
implementation; this acceptance does not itself change shipped behavior.

## Revision history

- 2026-10-24: initial focused amendment draft.
- 2026-10-24: revised for Type 2 findings F1-F6: narrowed transient integrity,
  restored compact disclosure, chose the bounded semantic scan baseline,
  specified context-backed replay, split resource gates and completed routing.
- 2026-10-24: accepted by the maintainer; implementation routed to Cut 19
  LDG-3105 before Workstream 58.
