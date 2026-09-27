# Workstream 22: Session-Axis Documentation Repair Closeout

**Status:** Accepted and closed.
**Date:** 2026-09-27
**Cut:** 15
**Tickets:** LDG-2866 and LDG-2867
**Baseline:** `0cf20e7`
**Implementation:** `5bd2059` and `180413a`, plus this closeout record.

## Outcome

The live contract now reports the engine that ships: strict feature windows
count venue open sessions on the shared pulse axis. Accepted lifetime facts,
including `known_inactive`, do not remove sessions from that feature axis.
Any missing required observation on that axis keeps the affected window
`NA_real_`; an inactive interval is one instance of that general rule. Real
observations inside an inactive interval remain feature inputs even while the
availability plane restricts target changes.

This workstream changes no engine behaviour. It corrects one live authority,
adds one missing failure-sensitive fixture and records why historical design
text is not rewritten.

## Contract And Detector

LDG-2866 replaced the former `contracts.md` sentence, "Strict feature windows
count expected sessions," with the explicit venue-axis rule above. It also
retains the existing rules that valuation marks never enter feature
computation and that scalar and series implementations agree on certified
strict windows.

LTB-0093 is the new fixture. It runs one public five-pulse experiment with two
instruments sharing an accepted inactive interval:

- AAA has prints before and after the interval but none inside it. Its first
  post-interval two-session SMA remains `NA`, so the window cannot bridge from
  the pre-interval print.
- BBB has real prints inside the same interval. Its two-session SMA is exactly
  23 and 25 on those pulses, so the repair cannot be satisfied by masking
  inactive-interval observations.
- The public explanation for BBB on the first inactive pulse reports
  `target_restricted = TRUE` with reason `lifetime_inactive`. This positive
  control proves the fixture actually applied the lifetime family; dropping
  that family cannot satisfy the detector merely because the bars are
  unchanged.

The complete literal matrix also requires all five venue pulses. A temporary
mutation that carried prior values across missing expected sessions changed
AAA's post-interval result from `NA` to 15 and failed LTB-0093's matrix and
post-interval assertions. The mutation was removed before commit.

## Historical Supersession

Availability gate 21 in
`rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md`
states that sessions inside known inactivity leave the feature and
classification expected set. That entire expected-set clause is superseded:
feature hydration keeps the venue-session axis, while ingestion classifies
observations against venue closes rather than removing inactive sessions from
a separate classification set. Enforcing either half would discard real prints,
which the live contract now expressly retains as feature inputs. Gate 21's
target restriction, execution refusal, venue-session valuation ageing and
terminal behavior remain in force.

The accepted availability synthesis and
`ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md` deliberately keep their original
text. They are historical records of the surfaces they accepted, not mutable
live documentation. The same convention keeps the accepted point-in-time
historical-projection RFC versions and prior closeouts unchanged.

The mismatch survived v0.2.0.0 and v0.2.0.1 because no fixture combined an
accepted lifetime interval with an asserted feature value. Lifetime tests
covered trading and terminal restrictions, while feature tests covered
ordinary gaps, venue closures and source parity. LTB-0093 joins those claims.

The reasoning and the deferred design goal remain recoverable in
`inst/design/horizon.md`, under the 2026-09-27 data entries, especially
"Instrument-narrowed expected sessions, deferred." The roadmap row
"Post-v0.2.0.2 point-in-time historical projection and missing-data policy"
schedules instrument-narrowed expected sessions for the next release. That
later work may reinstate the superseded gate clause only with its own engine
change and evidence.

## Verification

- `test-availability-features.R` passed after the mutation was restored. Its
  positive control also proves the lifetime restriction is active on the same
  pulse whose real print remains a feature input.
- The ordinary fast profile passed 466 of 466 selected blocks with no failure
  in 87.500 seconds. The independent checker returned
  `LEDGR_TEST_GATE_OK` against the 112-second bound. Records are at
  `C:/tmp/ledgr-ws22-fast`.
- The claims registry parses with unique IDs and registers LCL-0093 against
  LTB-0093 in the fast profile.
- A scoped search found that README.md, README.Rmd, the articles and the help
  pages contain no claim that lifetime inactivity removes an instrument from
  the decision axis or a session from an expected set.
- The implementation diff touches no production source, accepted RFC, prior
  packet or prior closeout.

After the first close review, the focused availability-feature,
documentation-contract, point-in-time documentation and test-control-plane
files all passed. The missing-data article was regenerated and its freshness
check passed. `tickets.yml` parsed and `git diff --check` was clean. The full
fast profile was not repeated because the corrections change contract prose,
one article sentence and assertions inside the existing LTB-0093 block; the
pre-review 466-block record remains the lane-budget evidence.

The seven-shape optimization walk and a before-and-after performance clock are
not required here because the workstream ships no engine code. The fast record
is a regression and lane-budget check, not an optimization claim.

## Governance

The first independent Type 1 close review of `0cf20e7..310506f` returned
CHANGES_REQUIRED on 2026-09-27. It found the narrowed general missing-data
sentence, the half-superseded gate clause and the incorrect article description
of the decision axis. The focused re-review returned PASS after verifying all
three corrections and two failure-sensitive positive-control mutations. The
final historical ratio is `2 / 2 = 1.000`, above the 0.5 gate; it is recorded
as a historical breach rather than hidden or padded.

The maintainer accepted the PASS on 2026-09-27. Cut 15 and Workstream 22 are
closed. Workstream 23 is now unblocked; the release gate remains blocked on
that downstream workstream.
