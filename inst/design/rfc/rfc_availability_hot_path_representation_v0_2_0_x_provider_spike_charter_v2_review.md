# Availability Hot-Path Representation - Provider Charter v2 Review

**Status:** Second and final pre-execution structural review.
**Reviewer:** Codex; not the Charter author or prospective spike executor.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD
  `b0fe6b8fb8c44981ad9fc6f8692ce076be72e764`.
- Charter v2 is a new historical successor. Charter v1 and Charter Review v1
  remain present and unchanged.
- Charter v2 is exactly 150 lines, ASCII-only, LF-terminated, has one question
  mark and one kill/recharter clause, and passes `git diff --no-index --check`.
- No spike code or evidence was executed. The cited provider, inspection,
  worker, contract, fixture, and evidence paths were inspected directly.

## Verdict

**PASS_WITH_LOW_OBSERVATIONS. Spike execution is unlocked.** Charter v2 closes
all five Review v1 findings without adding an arm, changing product semantics,
or authorizing production implementation. It is the operative Charter.

## Review v1 findings

| Finding | Result | Deciding evidence |
| --- | --- | --- |
| B1: incomplete recharter outcome | CLOSED | Lines 112-115 make any semantic arm's breach of any of the three envelope components close and recharter. The profile chooses only the destination. Lines 103-108 now distinguish the 87.9-second in-loop remainder from the approximately 98-second cross-clock wall estimate. |
| B2: unusable/static-only full-scale fixture | CLOSED | Lines 63-71 cite the runnable `spike_fixture(FIXTURES$envelope757)` control and add a separate 757-cutoff, constant-width, eventful provider pass with changing membership, status, lifetime, and knowledge lags. It remains a fixture, not a third arm or second fold. |
| M1: process-local option claimed on workers | CLOSED | Lines 29-37 explicitly exclude parallel sweep/walk-forward workers, cite the actual mirai transfer boundary, and require an observed per-provider arm stamp outside identity and view values. |
| M2: over-broad public reference | CLOSED | Lines 91-94 compare full views only arm-to-arm and restrict `ledgr_facts_resolve()` to membership evidence. This matches `R/availability-inspection.R:96-137`. |
| M3: two literal questions | CLOSED | The prerequisite at lines 17-23 is declarative. The operative blockquote is the file's only question mark. |

## Final smell test

- **One question and prerequisite:** PASS. The question asks whether one
  prepared provider preserves both views inside the registered envelope; the
  executed prerequisite is named and answered `PREPARATION_REQUIRED`.
- **Exactly two arms:** PASS. Current production and one prepared provider;
  collapse remains an implementation detail.
- **One kill condition:** PASS. Semantic failure is RED; valid semantics plus
  any envelope breach closes and recharters; valid, separable evidence inside
  all components is GREEN; unusable comparison evidence is INCONCLUSIVE.
- **Runnable core before cases:** PASS. One provider-build seam comes first,
  failure-derived cases remain capped at ten, and no expected row or witness
  list appears.
- **Falsifiable scale result:** PASS. The prepared arm must meet 180 seconds
  fold wall, every 1,024-MiB peak bound, and 82 seconds on the eventful
  provider-only pass. The current fold and provider references are rerun once.
- **Semantic reach:** PASS. Effective/knowledge time, complete/partial
  membership, status conflicts and supersession, lifetime/terminal behavior,
  held nonmembers, both views, arbitrary cutoff order, resume/rollback/reopen,
  economics, diagnostics, completion, and identity are represented.
- **Containment:** PASS. Sparse facts remain canonical and durable; compiled
  state is transient; view shape and provider identity stay unchanged;
  workers, policy, schema, public API, licensed data, other fold lanes, and
  public benchmark claims remain out of scope.
- **Protocol:** PASS. Runner, checker, and inventory only; 1,500 R-line budget,
  500-line correction stop, no provenance machinery, and one later independent
  Section 7 rerun/gut/diff review.

## Low observations for execution

### L1 - Freeze event density before the first measured run

The eventful fixture requires a deterministic registered formula and counts,
but intentionally leaves their exact values to the runnable fork. The executor
must write the membership-rotation, status, lifetime, and knowledge-lag formula
into the runner and emit its counts in `fixture.csv` before the first timing
run. Do not tune the event density after observing performance. If the formula
changes because the fork exposes a semantic defect, record that case history
and rerun the complete measurement protocol. No hash ledger is needed.

### L2 - Gut the arm attestation, not only a resolver operation

The `spike_arm` attribute is outside product identity and returned view values,
which is correct, but the full-fold provider object is internal. The checker
must prove its evidence is not self-asserted: gut or force the selected arm to
fall back to `current` and require the observed-arm evidence to fail before
semantic equality can pass. This can be the inventory's one required gutted
path; it does not add a case or arm.

## Decision

Charter v2 is the execution authority. Preserve Charter v1 and both structural
reviews. The executor may now build the smallest runnable provider fork, let
failures generate at most ten cases, freeze the eventful fixture as noted, and
produce only the runner, checker, inventory, and evidence CSVs.

After execution, a reviewer who did not execute must perform
`spike_protocol.md` section 7: rerun, gut one path, and diff the evidence. No
implementation tickets, RFC-index change, commit, push, or production adoption
are authorized by this review.

CHARTER_REVIEW_DISPOSITION: PASS_WITH_LOW_OBSERVATIONS
