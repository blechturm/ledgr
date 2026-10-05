# Final Review: Terminal Outcomes and Frozen Holdings for v0.2.2

**Status:** Type 1 final review.
**Reviewer:** Claude. Claude wrote both seeds but not the synthesis; the
rotation rule allows that.
**Date:** 2026-10-05.
**Reviews:** `rfc_terminal_outcomes_v0_2_2_synthesis.md`.

## Verdict

PASS_AFTER_PATCHES.

The synthesis is faithful to the response, seed v2 and the maintainer
decisions. It records the maintainer's acceptance of Section 3.4 and finds no
design concern requiring Type 2. Two precision patches, P1 and P2, are needed
so that two binding rules cannot be implemented in conflict. Both are
statements of rules the synthesis already implies.

## Inputs challenged

- **The freeze probe and the census measure different things,** and the
  synthesis says so (Section 2). The probe proves in-budget carry on *missing*
  bars. The census shows Sharadar encodes untraded sessions as *carried* bars
  that bypass that mechanism. Section 6 correctly makes the Sharadar claim a
  release gate rather than an assumption.
- **The 118 frozen-before-delisting instruments.** The synthesis rightly
  refuses to read them as "worthless". Reason evidence, added after the
  synthesis (`dev/spikes/terminal-outcomes/frozen_terminal_reasons.R`), shows:
  - 74 bankruptcies and 15 regulatory delistings (at least 76% distress);
  - 10 acquisitions (0.13% of all acquisitions) and 4 voluntary delistings;
  - 15 with no recorded reason.

  This supports `write_off` as a conservative default whose misfires are
  rare and correctable by exact-label override once the adapter passes reasons
  through.

## Verified against the tree

| Synthesis claim | Result |
| --- | --- |
| Terminal and expiry are separate; existing dispositions post before the terminal check and before the strategy decision (3.1, 3.2) | Holds: `R/fold-engine.R:462-523` |
| Existing held-terminal choices and identities; `v002` for a widened trigger (3.2) | Holds: `R/corporate-action-policy.R:18-46` |
| A no-mark disposition aborts today, so a typed stop is a change (3.2) | Holds: `R/corporate-action-settlement.R:455-470` |
| Frozen holdings are preserved and reserved by `ledgr_target_rebalance()` (3.5) | Holds **if** frozen is target-restricted (so not admissible) and `risk_mark` stays finite. Non-admissible held positions become `held_nonmembers`, keep their quantity and reserve `quantity * risk_mark`; a non-finite risk mark aborts (`R/strategy-helpers.R:342-403`, `R/strategy-types.R:80-92`). Both conditions are bound in 3.3 |
| Restricted targets may hold or go to zero (3.5) | Holds: `R/availability-economics.R:155-168` |
| DSR inputs stay on completed panels (5) | Holds: `R/validation-dsr.R:420-436` |
| In-budget carry, no fill without a bar, realization on resumption, one-shot non-queueing (2, 7.4) | Holds: `freeze_probe.R`, rerun by the synthesis author |

Each Section 7 case can fail under a mutation of its economic rule.

## Required patches (synthesis author)

- **P1. Freezing must exclude lifetime-inactive holdings.** Section 3.1 says a
  `known_inactive` holding with an empty `terminal_event` stops as a typed
  `INCOMPLETE`. Section 3.3 defines freezing for any mark past
  `max_sessions`, and today such a holding reaches the horizon as
  `valuation_horizon_exhausted|lifetime_inactive`
  (`R/fold-engine.R:511-515`). As written, a generic implementation of 3.3
  would freeze, and so carry indefinitely, a security ledgr knows has ended.
  That is fabricated value.

  State in 3.3: freezing applies only to holdings not covered by an effective
  `known_inactive` lifetime row. Labeled terminals follow 3.2 or 3.4, and
  unlabeled terminals take the 3.1 typed stop. Add the unlabeled case to
  Section 7.
- **P2. Schema versions.** The identity changes need explicit schema bumps;
  the current validators would reject the new fields.
  - `ledgr_valuation_stale()` has `schema_version = 1L` and only
    `max_sessions`; adding `exhausted` needs schema version 2.
  - The corporate-action identity is validated as exactly
    `policy_schema_version = 1L` with a fixed field set
    (`R/corporate-action-policy.R:118-163`); adding `frozen_terminal_position`
    and exact-label maps needs `policy_schema_version = 2`.

  State both. Pre-release, no compatibility path is owed.

## Notes (non-blocking)

- **N1.** The synthesis drops seed v2's contract-change list. The ticket cut
  must still update the Availability Contract stop-token table
  (`valuation_horizon_exhausted` and `terminal_settlement_unsupported` become
  conditional stops, plus a new no-mark token and the freeze diagnostics), the
  valuation policy and the Result Contract. A short list would spare the cut a
  rediscovery.
- **N2.** The Section 3.4 rationale could cite the reason table above.
- **N3.** "Every ordinary result surface gains one valuation headline"
  includes dense runs, which have no valuation policy. Show
  `Valuation: CURRENT` there, or omit the line for dense runs; either is fine.

## Maintainer decision recorded

The maintainer accepted Section 3.4 on 2026-10-05: `frozen_terminal_position`
defaults to `"write_off"` in the research preset and `"refuse"` in the strict
preset. The synthesis marker was updated in place, as `rfc_cycle.md` allows
for in-file maintainer resolutions.

## Next

The synthesis author applies P1 and P2. The maintainer accepts the synthesis.
Accepted obligations route to the v0.2.2 WS2 ticket cut; the Sharadar claim
gate routes to the release gate (Section 6).
