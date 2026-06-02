# RFC Seed v2 Review: Compiled Hot Frame B2 (v0.1.9.x)

**Status:** Non-binding seed-v2 review requested before synthesis. Not
accepted. Not authorized implementation scope.
**Cycle:** Architecture B2 measurement gate / v0.1.9.x promotion scoping.
**Reviews:** `rfc_compiled_hot_frame_b2_v0_1_9_x_seed_v2.md`.
**Relates to:** seed v1 and
`rfc_compiled_hot_frame_b2_v0_1_9_x_response.md`.
**Authored:** Codex. This is an interstitial review, not the synthesis
stage named by `inst/design/rfc_cycle.md`.

**Revision note 2026-06-02:** Finding 1 is resolved by maintainer
decision in
`rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`. The
review's remaining technical findings still stand unless synthesis
explicitly absorbs or revises them.

## Verdict

Approve the v2 direction with blocking caveats. Seed v2 absorbed most
of the Round-1 response accurately: the stale v0.1.8.9 memory-output
estimate is no longer treated as delivered evidence, K1 rates are
corrected, next-open fill semantics are restored, the parity surface is
expanded, and the event-buffer contract is tied back to the memory
handler. However, the cycle cannot proceed directly to synthesis. The
maintainer override request was a product-level sequencing decision and
has since been resolved in favor of B2-first sequencing. The v2 gate
still overstates what the Pattern A hot frame can recover because it
counts fill-proposal / cost-resolver work that explicitly stays in R and
treats a per-fill R handler write pattern as if it inherits K1's
inline-output authorization.

## Blocking findings

### 1. The maintainer override request is correctly surfaced, but it is not resolved

**Claim reviewed:** Seed v2 asks to override the horizon's attribution-
first sequencing so that "B2 measurement gate runs in v0.1.8.10 Ticket
5" and attribution becomes fallback if B2 fails
(`rfc_compiled_hot_frame_b2_v0_1_9_x_seed_v2.md:62-76`).

**Evidence:** The current horizon entry is explicit: xlarge ephemeral
wall attribution is a gate on both ledgrcore and Architecture B2
commitments (`inst/design/horizon.md:898-940`). The K1 verdict entry
repeats that attribution must complete before either compiled-core path
is authorized (`inst/design/horizon.md:1008-1031`). Seed v2 knows this
and requests an override rather than pretending the horizon already
allows B2-first sequencing (`seed_v2.md:159-163`).

**Review read:** This is a product-level binary choice, not a synthesis
decision. Per `inst/design/rfc_cycle.md`, maintainer decisions are a
separate stage when product-level choices surface. Codex should not bind
the override in synthesis without maintainer adjudication.

**What should happen next:** Create or record a maintainer decision:
accept B2-first override, reject it and restore attribution-first
sequencing, or accept a hybrid where Sub-A runs in ledgrcore-spike but
Sub-B waits for attribution. Synthesis can then bind the chosen sequence.

**Severity:** Blocking next stage. Not a seed bug, but a required
maintainer decision before synthesis.

**Revision 2026-06-02:** Resolved by
`rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`. Synthesis
should bind B2-first sequencing and focus on the remaining gate-shape
and scope findings below.

### 2. The corrected 25-55s hypothesis still includes work that the v2 hot frame leaves in R

**Claim challenged:** The evidence table labels default cost resolver
work (~5-15s) and next-open fill proposal construction (~3-8s) as
"Post-v0.1.8.10 B2-relevant residual hypothesis," sums the table to
25-55s, and calibrates the 30s promotion threshold against that range
(`seed_v2.md:225-248`).

**Evidence:** Seed v2 later narrows the hot frame so the R fold loop
performs next-bar lookup, `ledgr_next_open_fill_proposal()`, and
`ledgr_resolve_fill_proposal()` before calling compiled code
(`seed_v2.md:308-324`, `seed_v2.md:601-616`). That is faithful to
production semantics: current fold uses next-bar lookup and fill
proposal / cost resolution before output and state mutation
(`R/fold-engine.R:295-306`), and the fill model constructs next-open
proposals at `R/fill-model.R:18-96` and resolves default cost at
`R/fill-model.R:118-195`.

Under the v2 scope, fill proposal and cost resolver time are not
compiled by the first-cut hot frame. Pattern A also keeps memory handler
buffer writes in R (`seed_v2.md:498-515`). The first-cut recoverable
slice is therefore closer to fold-owned lot machinery plus state
mutation plus event-row value construction. The v2 table still presents
uncompiled fill proposal and cost resolver work as part of the
B2-relevant total.

**What the seed should say instead:** Split the table into:

- **B2 first-cut recoverable:** lot accounting, cash/position mutation,
  and event-row value construction.
- **Fold-loop residual that remains R in v2:** next-open proposal,
  cost resolver, target validation, and handler writes under Pattern A.
- **Future B2 extension candidates:** default-cost compilation and
  Pattern B direct handler-column writes.

Then recalibrate the 30s gate against the first-cut recoverable slice,
not the broader residual.

**Severity:** Blocking. It affects the ROI argument, gate threshold, and
the maintainer override rationale.

### 3. Pattern A is not the inline-output design K1 authorized

**Claim challenged:** Seed v2 says B2 is an inline-output design and
"inherits" K1 authorization (`seed_v2.md:984-986`), while the gate's
recommended Pattern A returns an event batch and then calls
`handler$buffer_event()` per fill in R (`seed_v2.md:498-515`,
`seed_v2.md:887-890`).

**Evidence:** K1's actionable conclusion is precise: compiled headroom
exists when fill events stay inside the compiled loop and are
materialized once; per-fill R output-handler cells are near 1x and are
not load-bearing
(`C:/Users/maxth/Documents/GitHub/ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md:18-27`,
`C:/Users/maxth/Documents/GitHub/ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md:57-72`).
Production memory output buffering still does
per-event R writes through `handler$buffer_event()` and
`append_event_row_list()` (`R/sweep.R:1035-1056`,
`R/sweep.R:1157-1180`).

Pattern A avoids per-fill FFI, which is valuable, but it does not keep
event accumulation inside compiled code. It leaves the R handler write
loop in place. If Pattern A fails the 30s gate, that result rejects the
conservative Pattern A shape; it does not necessarily reject B2 as the
K1-style inline-output architecture.

**What the seed should say instead:** Name Pattern A as a conservative
contract-preserving measurement. Either:

- make Pattern B the decision-bearing K1-equivalent gate, or
- state that a Pattern A failure does not fully park B2; it triggers a
  Pattern B follow-up or attribution, depending on the observed wall
  split.

Do not say Pattern A inherits K1 inline-output authorization.

**Severity:** Blocking. This changes what a failed Sub-B measurement
means.

### 4. The Sub-B swap mechanism is still not production-grade enough for a decision-bearing gate

**Claim challenged:** Sub-B can use `assignInNamespace()` or an internal
flag, with v2 recommending `assignInNamespace()` for measurement
(`seed_v2.md:781-784`, `seed_v2.md:892-905`).

**Evidence:** The fold hot path being swapped is not a standalone
namespace function. The current fill loop is a statement range inside
`ledgr_execute_fold()` (`R/fold-engine.R:275-365`), while
`handler$buffer_event()` is a closure created by
`ledgr_memory_output_handler()` at runtime (`R/sweep.R:957-1190`). The
attribution spec uses `assignInNamespace()` for function-boundary
wrappers but uses instrumented copies for statement-range subframes
(`inst/design/spikes/ephemeral_wall_attribution_spike/spec.md:330-367`).

For a performance gate, an instrumented copy is weaker than production
code because the measurement itself is meant to prove a production
integration path. Conversely, a hidden production flag has real code
surface and must be tested. The seed's two options are not equivalent.

**What the seed should say instead:** Promote this to a spec-cut or
maintainer choice:

- use an internal, unexported execution-spec flag with tests if Sub-B
  is intended to be decision-bearing; or
- keep Sub-B as an instrumented-copy prototype and explicitly prevent it
  from passing the promotion gate alone.

**Severity:** Blocking for the gate design; not blocking the B2 concept.

## Caveat-worthy findings

### 5. Production lot side support is slightly overstated at the fresh-fill boundary

**Claim challenged:** The hot frame input table says `fill_intent$side`
can include COVER / BUY_TO_COVER / SHORT / SELL_SHORT via "Production Lot
Semantics" (`seed_v2.md:298-306`), and the B2-specific parity gate
requires full production lot direction support (`seed_v2.md:829-839`).

**Evidence:** Production lot accounting accepts those aliases during
replay (`R/lot-accounting.R:13-19`, `R/lot-accounting.R:74-162`), but
fresh fill intent generation currently emits only BUY or SELL:
`ledgr_next_open_fill_proposal()` maps positive delta to BUY and
negative delta to SELL (`R/fill-model.R:68-96`), and durable write
validation accepts only BUY / SELL at the fill-intent boundary
(`R/ledger-writer.R:27-39`). The in-memory event payload also emits
`event_type = "FILL"` and uses BUY/SELL signed quantity logic
(`R/backtest-runner.R:163-218`).

**What the seed should say instead:** Split the parity requirement:

- fresh B2 fold path must match current fill-intent semantics
  (BUY/SELL only unless another ticket changes the fill model);
- reconstruction / verifier parity must preserve the broader
  `ledgr_lot_apply_event()` side alias behavior for persisted events.

**Severity:** Caveat-worthy. The broader test coverage is good, but the
seed currently blurs fresh-fill and replay semantics.

### 6. Ticket ownership is ambiguous

**Claim challenged:** The header says v0.1.8.10 Ticket 5 "lives in
ledgrcore-spike" (`seed_v2.md:5-8`), while Sub-B is a ledgr
`dev/bench/` production-harness measurement (`seed_v2.md:772-795`).

**Evidence:** The decision-bearing gate cannot live wholly in
ledgrcore-spike because it compares the post-v0.1.8.10 production fold
engine to a hot-frame swap in ledgr (`seed_v2.md:772-811`). Sub-A can
live in ledgrcore-spike; Sub-B is ledgr-owned.

**What the seed should say instead:** Ticket 5 has two artifacts:
Sub-A in ledgrcore-spike and Sub-B in ledgr. If the maintainer rejects
the B2-first override, only the reusable Sub-A design remains as a
future spike input.

**Severity:** Caveat-worthy bookkeeping. It matters for ticket cut.

### 7. The middle-band gate needs a defined disposition

**Claim challenged:** Seed v2 says 15-30s recovery is "maintainer
judgment" (`seed_v2.md:241-248`) while the Sub-B gate threshold later
requires wall recovery >= 30s for pass (`seed_v2.md:797-811`).

**Evidence:** These can coexist, but the outcome matrix only has pass /
fail rows (`seed_v2.md:813-820`). A 20s recovery currently reads as
both "maintainer judgment" and "fail."

**What the seed should say instead:** Add an explicit "review band":
15-30s does not pass promotion, but it triggers maintainer review on
Pattern B / attribution sequencing rather than automatic deferral.

**Severity:** Caveat-worthy. It avoids ambiguity at ticket closeout.

## Confirmed absorption from Round-1 response

- **Finding 1 absorbed:** v2 explicitly requests maintainer override
  instead of treating B2-first sequencing as already authorized
  (`seed_v2.md:62-163`).
- **Finding 2 mostly absorbed:** stale v0.1.8.9 memory-output recovery
  is no longer counted as delivered current residual (`seed_v2.md:218-239`).
  The remaining issue is the narrower first-cut scope, covered above.
- **Finding 3 absorbed:** current-close K1 shorthand is replaced by
  next-open proposal / cost-resolution semantics
  (`seed_v2.md:285-365`).
- **Finding 4 mostly absorbed:** feasibility and production gates are
  separated (`seed_v2.md:734-811`). The remaining issue is the Sub-B
  swap mechanism.
- **Finding 5 absorbed:** K1 rates are corrected and B2's per-pulse FFI
  cost is treated as unknown (`seed_v2.md:250-283`).
- **Finding 6 absorbed:** equity stays R and user-supplied cost
  resolvers stay out of the hot frame (`seed_v2.md:601-616`,
  `seed_v2.md:918-928`).
- **Finding 7 mostly absorbed:** all eight substrate-decision gates are
  named, plus a B2-specific lot-semantics gate (`seed_v2.md:822-845`).
  Fresh-fill vs replay side semantics need wording cleanup.
- **Finding 8 mostly absorbed:** event-buffer handling is tied to
  `ledgr_memory_output_handler()` (`seed_v2.md:456-562`). Pattern A vs
  Pattern B meaning still needs gate semantics.
- **Finding 9 absorbed:** build flags are narrowed to a measured gate
  variant with no fast-math / unsafe-math flags (`seed_v2.md:741-768`,
  `seed_v2.md:918-928`).
- **Finding 10 absorbed:** "all eight compilable" is softened to a
  candidate categorization (`seed_v2.md:563-581`).

## Recommendation on next step

Proceed to synthesis only after the maintainer decision artifact is read
as binding input. The sequencing blocker is resolved in favor of
B2-first. Synthesis still needs to close or request a targeted seed-v3
patch on three points before ticket cut: the first-cut recoverable slice
table, Pattern A's gate meaning, and the Sub-B swap mechanism.

## Process notes

This review is an extra interstitial artifact. `inst/design/rfc_cycle.md`
does not name a standard "seed v2 review" file, but the maintainer
requested one before synthesis. The file is therefore deliberately named
`rfc_compiled_hot_frame_b2_v0_1_9_x_seed_v2_review.md` rather than
editing v2 in place or pretending this is synthesis.
