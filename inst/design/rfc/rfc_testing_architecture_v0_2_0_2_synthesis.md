# Synthesis: Testing Architecture For v0.2.0.2 And After

**Status:** Decision synthesis; ready for independent Type 1 final review.
**Author:** Codex
**Date:** 2026-09-21
**Inputs:** Seed v3 at `a4516d5`, both Type 2 responses, the 930-row
test-suite audit table, and the accepted RFC-cycle review rules.

## 1. Decision

Accept Seed v3's direction with the decisions and corrections below. Do not
write a fourth seed.

The bound architecture is deliberately small: one parameterized runner,
two membership profiles, CRAN as a mode over `fast`, one claims registry,
one selected-versus-executed census, and canonical-R evidence in ordinary
feedback. It replaces the present undifferentiated 948-second suite without
turning test metadata into a second product.

Seed v3 does not bind literally in three places. Its inline-oracle-note
preference is rejected. Its census must obtain expected and actual sets
from independent mechanisms. Its first two workstreams are reordered so
that neither the runner nor the census depends on a workstream that assumes
they already exist.

## 2. Bound Architecture

### 2.1 One runner and two memberships

There is one parameterized runner. `fast` is the default membership;
`review` is the only other ordinary membership. Heavy protocols remain
named scripts with their own checkers and owners. They are not a third
membership hidden behind the runner.

A block has one profile authority. A homogeneous-file declaration may be
syntactic shorthand only if it expands into that same authority. Unknown,
missing, or contradictory profile metadata fails closed.

The runner always emits and reconciles an expected selection and an actual
execution census. A timing result without a reconciled census is not a
valid gate result.

### 2.2 CRAN is a mode

The exact `fast` membership runs in ordinary and CRAN modes. CRAN mode uses
a recorded isolated-library construction, a read-only working directory,
the CRAN check environment, and its own clock. Installed optional packages
must not leak into the supposedly absent dependency set. No block uses
`skip_on_cran`.

The graphics, warning, and finalizer repairs in Seed v3 Section 4.2 are
prerequisites to a passing CRAN mode. Ordinary optional-dependency skips
remain permitted when they report the dependency and do not leave a
load-bearing claim without a non-optional detecting block.

### 2.3 Canonical R remains ordinary evidence

The three audited canonical differential blocks, measured at 6.16 seconds,
run in every `fast` invocation. The current 70.80-second candidate plus
that core is 76.96 seconds, leaving enough measured room under the bound
without a path trigger.

Public-sweep parity and full-scale records remain `review` evidence and run
unconditionally at release. The repository maintainer owns the cheap core
and the extended overlay. An implementation workstream may consume this
evidence but never becomes its permanent authority.

### 2.4 The claims registry is bounded authority

`tests/claims.yml` registers declared load-bearing claims; it does not
claim completeness. Each row records a claim ID, authoritative contract
section or named defect, scope, oracle class, detecting block IDs, promised
profile, and owner.

The registry checker fails on missing or duplicate IDs, an unresolved
detecting block, a missing owner, an unknown profile, or a census showing
that a promised block did not execute where promised. It reads structure
and run output, never prose or line counts.

Shrink, Merge, and Delete reviews remain responsible for undeclared claims.
The registry narrows that inquiry; it cannot answer it.

### 2.5 Rules follow observed mechanisms

Bind Seed v3's cleanup, determinism, mock, and frozen-artifact rules. The
twelve files using mocked bindings and the seven frozen availability CSVs
make those rules evidence-based rather than aspirational.

Do not add snapshot-file rules while no `expect_snapshot` artifact exists.
Do not add a general failure-message policy without an observed defect.

`tests/README.md` stays under sixty lines and describes the runner, modes,
registry, checker, four rules, and budget response. No test reads it.

## 3. The Five Open Decisions

### D1. Stable block identifier

Use an immutable title prefix of the form `[LTB-0001]` on registered
detecting blocks only. The human description after the prefix may change;
the prefix may not be reused. The checker enforces format and uniqueness.
It is visible in source diffs and test output without introducing a wrapper
API or attaching governance comments to all 930 blocks.

Unregistered blocks need no durable ID. For a single run, their census key
is current file, description, and syntactic occurrence. A title edit can
therefore remain an ordinary edit without changing registry authority.

### D2. The 90-second gate

Ninety seconds is a hard ceiling, not a baseline plus a percentage. Its
existing headroom is the tolerance. Run once in a fresh process on the
registered CI runner. If it exceeds 90 seconds, run two confirmation
processes at the same commit and environment; fail when the median of all
three exceeds 90 seconds. Retain every measured value. This absorbs a
single noisy host event without silently widening the promise.

CRAN mode has its own measured gate. Its initial bound is set only after
the isolated mode runs; it is not inferred from the ordinary clock.

### D3. Registry grain

Register one independently falsifiable invariant or named defect per row,
not one row mechanically per `contracts.md` heading. One contract section
may own several rows when its guarantees have different failure conditions,
profiles, or owners. Several blocks may detect one claim.

The prior audit's twelve-row map is the seed set, not a completeness count.
A proposed row that cannot state what defect would make its detecting block
fail is too broad and must be split or omitted.

### D4. Census frequency and independence

Reconcile the census on every invocation of the parameterized runner,
including local, ordinary CI, CRAN, and review runs. Gates retain it; local
runs may print only a summary.

Expected selection is derived by a static preflight over the source profile
metadata. Actual execution is reported by testthat. The selector may not
produce both sides of the comparison. The preflight also fails when it
cannot classify a syntactic test block. Heavy protocols remain responsible
for their own diff-based checkers.

### D5. Inline oracle note

Reject it as a rule. "Not evident" is subjective, duplicates the registry
for important tests, and would gradually become a universal comment mandate.
Authors may write ordinary explanatory comments, but no checker or review
requires an `Oracle` line.

Retain one useful discipline from the v1 response that v3 dropped. For a
new load-bearing claim or a new `review`/heavy test, Type 1 review must be
able to answer, without persistent per-block boilerplate: what contract or
defect it protects, whether its oracle is independent enough, what smallest
change makes it fail, why this is the cheapest adequate lane, and which
existing evidence overlaps it. Supporting `fast` tests do not acquire a
five-field form.

## 4. Workstreams And Order

The first two Seed v3 workstreams were circular: Oracle and claims said it
built the census, while Move said it built the runner that produces it.
Bind these five workstreams instead:

1. **Oracle repair.** Repair the 21 identified oracle defects and three CRAN
   blockers. Repair or replace the nine currently red blocks, which carry
   23 failing assertions. A version-stamped
   prose pin with no current claim is deleted with its reason; it is not
   converted into a permanent skip. Preserve historical `engine_version`
   and compare it separately from economic equality.
2. **Control plane.** Add the runner, single profile authority, static
   expected census, reporter-derived actual census, registry and checker,
   canonical fast core, isolated CRAN mode, and both gates.
3. **Shrink.** Reduce the 134 nominated fixtures only when the original
   failure condition still fails under deliberate perturbation.
4. **Merge.** Merge the 126 nominated blocks by claim family only after the
   overlap question is answered and detecting evidence remains.
5. **Delete.** Perform the 26 replace-then-delete candidates only after the
   replacement is named and executable in a bound lane.

Each is one review workstream with one Type 1 review. The control-plane
workstream additionally demonstrates its own failure sensitivity. The
packet closeout records the resulting clocks and counts; no batch evidence
essay is created.

## 5. What Is Rejected, And What Survives

Rejected from v1: directory routing, mass file moves or splits, the
single-axis oracle taxonomy, three mandatory comment lines per survivor,
an untested grep map, and deletion before the architecture binds.

Rejected from v2: four runners, CRAN as separate membership, a path trigger
for the cheap canonical core, file-and-title registry references, a
universal Oracle line, pre-synthesis skips, and a dynamic historical version
witness.

Rejected from v3: the conditional inline oracle note and any interpretation
of quarantine as a skipped test that may ship indefinitely.

Kept from v1 and v2 where v3 was silent: the audit's five review questions,
but only for new load-bearing or slower evidence and without persistent
boilerplate. Kept from v2 and v3: separate ordinary and CRAN measurements,
the unconditional release backstop for extended parity, maintainer ownership,
two-axis vocabulary, and explicit rules for mechanisms that actually exist.

## 6. Control-Plane Scenario, Applied To The Bound Design

Scenario: a runner refactor silently drops a promised `review` block.

Before selection, the static preflight reads the source profile authority
and includes the block in the expected set. The selector omits it. The
testthat reporter therefore lacks its actual execution record. Reconciliation
fails the invocation before timing or test success can satisfy a gate. If
the omitted block has a registered claim, the registry checker supplies a
second release failure through its promised profile.

The control-plane workstream must prove this with a small fixture by gutting
selection, by supplying an unknown profile, and by suppressing one reporter
record. Each mutation must make the control-plane check fail for the intended
reason.

The residual is honest: a defect shared by the static preflight and its own
fixture can still hide a block. No finite checker proves its own completeness.
The Type 1 final review therefore compares source declarations, expected
census, and actual census independently rather than accepting the runner's
summary. That is a bounded residual, not grounds for another mechanism.

## 7. Release Boundary And Final Review

This architecture gates v0.2.0.2. No equity-accounting implementation packet
opens until the five workstreams are ticketed in this order and the first
two establish a trustworthy green baseline. Cleanup may implement this
synthesis directly; it does not need another RFC.

The final Type 1 review should verify fidelity, not redesign the system. It
must independently check the inputs: the measured block membership, the
three canonical blocks, the optional-dependency isolation, the mock and
frozen-fixture inventory, and the source-versus-census comparison. A design
failure routes to `NEEDS_TYPE_2` under the accepted governance process.

The design is now specific enough to cut an implementation packet after
Type 1 acceptance and small enough to live under. Its success criterion is
not the elegance of its taxonomy; it is a fast ordinary check whose missing
evidence cannot become invisible merely by making the run shorter.

## Revision history

- 2026-09-21 — Decision synthesis by Codex from Seed v3 and both responses.
- 2026-09-21 — Type 1 final-review patch by Claude, in place: §4 item 1
  said 23 red blocks; the audit and table say nine blocks with 23 failing
  assertions. No decision changed.

ready for Type 1 final review
