# Workstream 11 Closeout: Policy, Fidelity And Cash

**Status:** Agent-provisional; awaiting independent Type 1 close review and
maintainer acceptance.

**Authority:** cut 6, Workstream 11, LDG-2809 through LDG-2813 in
`tickets.yml`, under the accepted equity-settlement synthesis.

**Implementation range:** `7a63979` through `8eac8c7`, after the accepted
Workstream 10 transition at `319060f`. This closeout is the LDG-2813 record
and does not open Workstream 12.

## What Shipped

- `ledgr_corporate_actions()` constructs a closed, versioned settlement
  policy. `ledgr_corporate_actions_research()` selects gross cash,
  `effective_close`, `last_permissible`, and `report_only`;
  `ledgr_corporate_actions_strict()` refuses every modeled choice. The
  resolved identifiers enter new experiment and run identity.
- Historical stored configs that lack the policy remain absent-policy
  records on reopen. Omission in a new experiment is exactly the explicit
  research preset; one changed choice changes identity.
- Ordinary results distinguish `not_supplied`, `none`, `modeled`, and
  `unsupported`. The print method warns when facts were not supplied, while
  the detailed summary reports exact settings, versioned identities, choice
  and refusal counts, late arrivals, exposure, cash, proceeds, positions,
  realized model PnL, and unsupported facts. Zero is rendered as zero.
- A validated cash distribution fixes entitlement immediately before the
  ex-dividend boundary. `effective_close` credits gross cash before that
  pulse's valuation and strategy context; `next_open` credits it at the next
  pulse. A late-known fact posts at its first knowable pulse without
  recomputing or backdating entitlement.
- Each admitted fact produces one identified `CASHFLOW`. Resume and reopen
  preserve exactly-once posting. Canonical R now declares `CASHFLOW` handled;
  compiled spot-FIFO continues to refuse it before accounting.
- The executable cash-distribution vignette demonstrates the modeled
  research path, its early-spendability limitation, and strict refusal.

No terminal disposition, lot consumption, acquisition composition, exact
recipient quantity, or new compiled economic-event implementation shipped.

## Registered Claims And Gate Cases

| Claim | Detector | Profile | Protected result |
| --- | --- | --- | --- |
| LCL-0027 | LTB-0032 | fast | closed policy choices and versioned identity |
| LCL-0028 | LTB-0033 | review | legacy configs do not acquire today's default |
| LCL-0029 | LTB-0034 | review | absent evidence differs from supplied unused facts |
| LCL-0030 | LTB-0035 | fast | fixed entitlement and one identified posting |
| LCL-0031 | LTB-0036 | review | public durable cash path and exact result evidence |
| LCL-0032 | LTB-0037 | fast | executable modeled and strict quick paths |

LTB-0026 under LCL-0022 was also updated deliberately: canonical R admits
the now-implemented `CASHFLOW`, while compiled spot-FIFO still refuses it.

- Gate case 2 is the split-normalized cash term in LTB-0036. A later parent
  split changes price and not the already canonical cash term.
- Gate case 3 is LTB-0035 and LTB-0036: each posting convention has exact
  cash and clock expectations, and the public durable run observes cash in
  strategy context before valuation completes for the pulse.
- Gate case 11 is complete across LTB-0034 and LTB-0036: bars-only runs say
  `not_supplied`; a dividend-only snapshot needs no availability calendar or
  staleness policy and reports exact modeled evidence.
- Gate case 12 is LTB-0035: entitlement and effective clocks differ; the
  pre-boundary seller receives cash, the ex-date buyer does not, and a
  late-known fact posts without backdating.

## Identity In Both Directions

LTB-0032 changes each policy axis independently and requires every config
hash to move. It also requires an omitted new-experiment argument to equal an
explicit research preset. LTB-0033 removes the policy field from a persisted
config, recomputes that historical record's hash, and proves that public
reopen preserves the absence rather than injecting a contemporary default.

The short user spellings are not the hashed contract. Stable versioned
identifiers bind the behavior and scope, so a future semantic change cannot
retain identity merely by keeping the same friendly word.

## Spec-Cut Decisions

**Public spellings.** The constructors are
`ledgr_corporate_actions()`, `ledgr_corporate_actions_research()`, and
`ledgr_corporate_actions_strict()`. The closed choices are the synthesis's
short values, including `gross`, `effective_close`, `next_open`,
`last_permissible`, `report_only`, and `refuse`. These names match the
package's constructor-and-preset idiom, keep strategy configuration readable,
and reject callbacks or partial matching at the identity boundary.

**Summary layout.** `corporate_action_fidelity` is a headline field on the
ordinary result. `not_supplied` prints the exact warning "Corporate actions:
NOT SUPPLIED - returns may omit distributions". Detailed evidence remains a
structured summary containing selected choices and versioned identifiers,
exact counts by exercised choice and refusal reason, late arrivals, aggregate
affected marked exposure, gross cash, modeled terminal proceeds, positions
disposed, realized model PnL, and unsupported facts. Keeping the headline
small while retaining exact details avoids both false reassurance and a
specialist-only reader.

## Failure Sensitivity

- Changing the research cash default to `refuse` made two LTB-0032
  assertions fail. A one-axis identity mutation therefore cannot hide behind
  the preset spelling.
- Forcing the fact-family lookup false broke three LTB-0034 observations,
  including the distinction between `not_supplied` and `none`.
- Adding one unit to the production cash delta made seven exact LTB-0035 and
  LTB-0036 assertions fail across cash, context, ledger, and summary.
- Replacing the vignette's rendered 2.5 gross cash with zero made LTB-0037
  fail. The source also rejects non-executing chunks.
- A duplicate source-fact posting is rejected. Removing either entitlement
  timing, knowledge timing, or either policy identity changes LTB-0035.
- Removing canonical `CASHFLOW` handling fails LTB-0026; allowing compiled
  `CASHFLOW` execution fails its separate compiled-arm expectation.

No whole-file source hash was introduced as a behavioral oracle.

## Test Gate And Performance

The final exact-tree fast profile used R 4.6.1 and testthat 3.3.2. All three
runs passed 444 of 444 selected blocks with zero failures and zero skips:
90.360, 88.270, and 88.380 seconds. The registered ordinary gate passed on
the required three-run median of 88.380 seconds against the 90-second bound.
Records:

`C:/Users/maxth/ledgr-research/.tmp/ws11/ldg-2813-final-fast`

The vignette render completed in about nine seconds, but that is a document
build rather than a performance benchmark. The corporate-action family still
has no registered full-population workload, so this closeout makes no
full-scale settlement speed claim and does not convert focused test clocks
into one.

## Hot-Path And Complexity Audit

The production delta was walked against the seven optimization shapes.

- Fact selection and validation are column operations. Knowledge-to-pulse
  mapping uses one vectorized `findInterval`, not a fact-by-pulse scan.
- Resume entitlement groups existing corporate cash deltas by instrument and
  takes cumulative values once. It does not rescan the event stream for each
  prior fact.
- Entitlement uses prepared position vectors. Per-pulse work is a null check
  plus the facts due at that pulse; it does not scan all past facts.
- Due events are prepared as one typed block and appended through the existing
  handler boundary, not as one-row frames or one database call per event.
- The ordinary result summarizes the persisted corporate cash rows linearly
  at the result boundary. No nested event or instrument rescan was added.
- Sweep workers receive prepared immutable settlement rows and own their fold
  state locally. No mutable cursor is shared across candidates.
- No row-wise timestamp formatting, JSON parsing, growing-vector append,
  pairwise validator, or environment-held vector write was added.

The audit initially found a fact-by-pulse lookup and a fact-by-event resume
scan before close. LDG-2811 replaced both before this record was frozen. No
hidden quadratic path remains in the Workstream 11 delta.

## Governance And Declined Work

Four review invocations have completed over the cut's fifteen tickets: two
cut-review rounds and two Workstream 10 close-review rounds. The requested
Workstream 11 close review is the fifth, giving 5/15 = 0.333 if completed,
below the 0.5 gate. The denominator is the fifteen tickets present at cut.

Declined here:

- `DISPOSITION`, lot consumption, composition, recovery, and the complete
  fourteen-case release gate: Workstream 12;
- exact recipient-quantity transformations and dynamic axis growth: the
  separately scheduled exact-quantity work;
- payment-date receivables, withholding, investor tax, or broker-net cash:
  unsupported by the accepted gross/effective-close model;
- compiled support for non-`FILL` events or a second accounting engine:
  outside the accepted release scope;
- vendor decoding, price adjustment, or quantity normalization inside ledgr:
  those remain adapter responsibilities.

Maintainer acceptance after the independent close review closes Workstream 11
and opens Workstream 12.
