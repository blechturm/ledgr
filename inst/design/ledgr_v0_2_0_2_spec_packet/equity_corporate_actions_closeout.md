# Cut 6 Closeout: Usable Equity Corporate Actions

**Status:** Accepted 2026-09-25. All four workstreams are accepted.
Workstream 12 passed independent Type 1 close review at `3adb8bd`; the
maintainer accepted it and the three closeout-only corrections were applied
under the same ninth review invocation.

**Authority:** cut 6, Workstreams 10, 11, 14 and 12, under the accepted
equity-settlement synthesis. The active cut contains eighteen tickets.

**Implementation range for Workstream 12:** `b25a9f7` through the LDG-2818
closeout commit, after the accepted Workstream 14 transition at `6d70315`.

## What Shipped

- The sealed `equity_corporate_actions` family records canonical, vendor-
  neutral facts with explicit clocks, completeness, refusal, provenance and
  independently validated terms. Declaring this family alone does not
  activate the availability provider.
- Both accounting arms declare the event kinds they handle. Canonical R
  handles `FILL`, `CASHFLOW` and `DISPOSITION`; compiled spot-FIFO refuses
  every non-`FILL` kind before accounting rather than dropping it.
- `corporate_action_policy` is a closed, versioned part of experiment and run
  identity. The research preset models gross cash and terminal disposition;
  the strict preset refuses modeled settlement.
- `corporate_action_fidelity` distinguishes facts not supplied, supplied but
  unused, modeled and unsupported. The ordinary result reports the selected
  policy, identities, exact choice and refusal counts, cash, proceeds,
  exposure, disposed positions and realized model PnL.
- Gross distributions bind entitlement immediately before the ex-dividend
  boundary. `effective_close` posts before that pulse's valuation and
  strategy context; `next_open` posts at the next pulse. Late-known facts post
  once at their first knowable pulse without recomputing entitlement.
- `DISPOSITION` consumes canonical FIFO lots, removes the position, moves
  modeled cash and reports realized model PnL. Missing admissible marks and
  strict policy refuse without account mutation.
- Acquisition composition prevents double credit. Exact recipient quantity
  remains unsupported; the retrospective four-quantity report makes the
  omitted successor exposure visible without entering strategy context.
- Durable interruption, resume, replay and reopen preserve one disposition.
  Memory candidates retain their existing failure-containment boundary and
  acquire no transaction, rollback or reopen promise.
- The quick-path and fictional-adapter articles execute. The latter teaches
  clocks, term normalization, provenance, physical-axis closure and refusal
  without importing a vendor adapter.

## Fourteen-Case Gate

| Case | Claim | Detector | Protected rule |
| ---: | --- | --- | --- |
| 1 | LCL-0045 | LTB-0030 | fictional vendor normalization is canonical and vendor-neutral |
| 2 | LCL-0046 | LTB-0036 | a later split does not change a canonical cash term |
| 3 | LCL-0047 | LTB-0036 | posting conventions produce exact cash, equity and context |
| 4 | LCL-0048 | LTB-0051 | a current admissible mark disposes the held parent |
| 5 | LCL-0049 | LTB-0051 | permitted stale and opt-in expired marks record source age |
| 6 | LCL-0050 | LTB-0051 | no finite mark refuses before event or account mutation |
| 7 | LCL-0051 | LTB-0054 | durable resume preserves exactly one disposition |
| 8 | LCL-0052 | LTB-0052, LTB-0053 | stock and mixed effects never double-credit cash |
| 9 | LCL-0053 | LTB-0056 | physical closure does not leak into membership, features or fills |
| 10 | LCL-0054 | LTB-0026 | compiled spot-FIFO refuses every non-FILL event kind |
| 11 | LCL-0055 | LTB-0034, LTB-0036 | the quick path reports supplied and absent evidence honestly |
| 12 | LCL-0056 | LTB-0036 | entitlement uses its own clock and late facts do not backdate |
| 13 | LCL-0057 | LTB-0052 | omitted successor exposure is numerical and retrospective only |
| 14 | LCL-0058 | LTB-0054, LTB-0055 | durable recovery and memory containment remain distinct |

LCL-0059 and LTB-0057 bind the executable adapter-authoring article. LCL-0060
and LTB-0060 bind the release boundary on README, NEWS and the source and
rendered forms of both new articles. The documentation detector requires the
exact boundary sentence and rejects each prohibited claim when its negative
limiter is removed.

## Failure Sensitivity Added In Workstream 12

- Removing the `DISPOSITION` lot branch failed LTB-0050, LTB-0054 and
  LTB-0056. The direct replay exposed the invalid live-lot state; the durable
  recovery and physical-axis scenarios independently exposed the same missing
  accounting behavior through their public outputs.
- Removing the cash leg from acquisition consideration made four LTB-0052
  assertions fail, including both mixed-case totals. Removing the strict
  quantity check made LTB-0053 fail.
- Dropping the disposition append failed LTB-0050, LTB-0051, LTB-0052,
  LTB-0054 and LTB-0055 across twelve assertions: direct emission, public
  summary, composition, durable recovery and memory observation all detected
  the missing event. Giving a failed memory candidate zero final equity
  instead of `NA` made LTB-0055 fail. An independent double-credit gut also
  made LTB-0053 fail.
- Replacing the membership axis with the complete physical axis changed the
  cross-sectional feature means from 10.5 and 11.5 to 15.5 and 16.5 and made
  LTB-0056 fail twice.
- Collapsing `next_open` onto the entitlement pulse made three exact
  LTB-0036 assertions fail across cash, equity and strategy context.
- Inserting a `ledgr.sharadar` reference into the fictional adapter article
  made LTB-0057 fail.
- Changing README from "does not claim" to "claims" made LTB-0060 fail on
  the required boundary sentence and all five prohibited claims.

No whole-file source hash is used as a behavioral oracle.

## Release Boundary

The release may claim: evidenced gross distributions, modeled terminal
disposition under a named convention, visible refusal, reproducible sealed
facts, and a fidelity signal over supplied facts. It may not claim
corporate-action completeness, broker-exact settlement, net cash, tax
correctness, exact recipient exposure, or that no unknown event existed.

The same non-claim is stated on every release-facing surface checked by
LTB-0060. Fidelity describes supplied facts only; it is not evidence that a
source supplied every economically relevant event.

## Upstream Private Gate

The distribution-population reconciliation, corrected census and Sharadar
producer specification live in the private `ledgr-research` repository and
are not evidence for this cut. Synthetic ledgr work did not wait for them.
Real-data integration must not begin until the upstream canonical producer is
accepted and its output passes ledgr's public constructor and seal boundary.

## Test Gates And Frozen Evidence

The exact-tree R 4.6.1 fast profile passed 454 of 454 selected blocks with
zero failures and zero skips in 74.780 seconds. The ordinary 90-second gate
passed under its one-run rule. The corrected full review profile passed 265
selected blocks in 351.640 seconds: 264 passed and one declared optional
Yahoo-adapter block skipped because `quantmod` was unavailable.

The operator session named `.tmp/ws12-close-fast` and
`.tmp/ws12-close-review`, but neither directory was retained and neither
exists in the reviewed tree. Those two timings are session-output evidence,
not durable record artifacts. The independent Type 1 close-review session at
`3adb8bd` reran both lanes and reproduced the claims: fast 454 of 454, zero
non-passed, 75.060 seconds, ordinary gate green; review 265 selected, 264
passed, the same optional block skipped, 439.990 seconds. That independent
session likewise did not retain a record directory. No later release gate may
cite either absent path as artifact-backed evidence.

The first review-profile run was rejected after one frozen identity witness
still expected schema 115 and a pre-policy config. Every economic table and
result matched. The fixture was regenerated from the current public run, its
historical engine version was retained as `0.2.0.1`, and its negative
perturbation still fails. The corrected identity records schema 117 and the
explicit corporate-action policy now carried by new-run identity. The focused
file then passed before the complete review profile was repeated.

## Performance And Complexity Boundary

Workstream 12 adds no fact-by-pulse or event-by-instrument nested scan. Facts
are indexed by pulse, due identities are matched to prepared position vectors,
one event frame is appended per posting pulse, and retrospective summaries
are computed at the result boundary. DISPOSITION delegates lot mutation to
the consolidated canonical accounting core rather than introducing a second
lot engine.

One scale-growing result-boundary loop remains and is disclosed rather than
hidden: `ledgr_corporate_action_summary()` maps each selected source fact to
`which(source_fact_id == fact_id)`, a full corporate-action event scan per
fact, or O(selected facts x corporate-action events). The close reviewer
measured that expression at 0.010 seconds for 2,000 by 2,000 and 0.380 seconds
for 10,000 by 10,000, versus below clock resolution for grouped
`rowsum()`/`match()`. It is retained in this release because it is outside the
fold, is immaterial at the evidenced fact counts, and changing the accepted
result path was not needed for settlement correctness. A grouped replacement
is a bounded result-reader optimization, not a performance claim of this cut.

The fast lane remained between 73.25 and 74.78 seconds across the five
Workstream 12 ticket records. These are gate clocks, not an end-to-end
settlement benchmark or an effect estimate. The cut makes no full-population
corporate-action speed claim. Workstream 14 separately removed the measured
row-wise fact-family construction, seal and run-start costs before this
workstream opened.

## Pilot Counters

The requested Workstream 12 review is the ninth invocation over eighteen
active cut tickets: 9/18 = 0.500, exactly the D8 ceiling. A correction round
would exceed the gate and must be recorded rather than hidden.

Before this close review, the cut accumulated 21 Type 1 findings:

- five in the first ticket-cut review and one residual in its focused
  re-review;
- one in the Workstream 10 close review;
- four in the Workstream 11 close review;
- seven in the fact-family-scaling amendment review; and
- three record-only corrections in the Workstream 14 close review.

Eighteen Type 1 findings changed implementation, ticket acceptance or its
detecting evidence. The other three corrected the closeout's record without
changing accepted production code. Two Type 2 findings changed the amendment
boundary. No finding was dismissed.

Five gate or review executions were repeated after a correction or execution-
context problem: Workstream 10 after its silent-drop correction; Workstream 11
after four close-review corrections; Workstream 14 after the non-binding
elevated-context run; LDG-2817 after a claims-profile mismatch; and LDG-2818
after the stale frozen identity was exposed. Four records were rejected or
declared non-binding: the original Workstream 10 correction target, the
elevated-context Workstream 14 timing record, the first LDG-2817 fast attempt,
and the first LDG-2818 review run. The Workstream 11 provisional record is
retained as historical evidence rather than classified as rejected.

Three classifications were disputed and resolved explicitly:

- exact summary values, rather than field presence, were required by the
  ticket-cut reviewer and patched before implementation;
- Workstream 14's elevated-context all-green run was non-binding because it
  did not share the registered execution context; its failure remained
  disclosed and the unchanged tree was rerun ordinarily; and
- the LDG-2818 frozen-identity failure was an intentionally stale literal,
  not an economic regression. The literal moved, the historical engine label
  remained, and its independent perturbation stayed failure-sensitive.

## Declined Or Deferred

- Exact recipient quantity, basis allocation and dynamic axis growth remain
  outside this release and require their own accepted design and evidence.
- Payment-date receivables, withholding, investor tax, net settlement and
  broker-exact cash are unsupported by the gross/effective-close model.
- Compiled handling of non-`FILL` economic events and a second accounting
  engine remain out of scope; the compiled arm refuses visibly.
- Vendor decoding, vendor adjustment arithmetic and identity resolution do
  not move into ledgr. Adapters produce canonical facts.
- Broad availability-provider decoupling is not part of this cut. The fact
  family itself remains runtime-inert, while terminal disposition uses the
  existing availability-aware path.
- LDG-2820, the resume-only metadata preparation optimization, remains
  deferred and does not alter the accepted recovery contract.

Maintainer acceptance after the independent Type 1 close review will close
Workstream 12 and cut 6. This provisional draft does not do so.
