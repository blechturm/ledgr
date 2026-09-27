# Workstream 22: Session-Axis Documentation Repair Closeout

**Status:** Agent-provisional; awaiting Type 1 close review and maintainer
acceptance.
**Date:** 2026-09-27
**Cut:** 15
**Tickets:** LDG-2866 and LDG-2867
**Baseline:** `0cf20e7`
**Implementation:** `5bd2059` and `180413a`, plus this closeout record.

## Outcome

The live contract now reports the engine that ships: strict feature windows
count venue open sessions on the shared pulse axis. Accepted lifetime facts,
including `known_inactive`, do not remove sessions from that feature axis.
Missing required observations keep affected windows `NA_real_`; real
observations inside an inactive interval remain admissible feature inputs even
while trading is restricted.

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

The complete literal matrix also requires all five venue pulses. A temporary
mutation that carried prior values across missing expected sessions changed
AAA's post-interval result from `NA` to 15 and failed LTB-0093's matrix and
post-interval assertions. The mutation was removed before commit.

## Historical Supersession

Availability gate 21 in
`rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md`
states that sessions inside known inactivity leave the feature and
classification expected set. Its feature clause is superseded by the live
contract because the shipped engine never implemented that narrowing. The
gate's other requirements remain in force.

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

- `test-availability-features.R` passed after the mutation was restored.
- The ordinary fast profile passed 466 of 466 selected blocks with no failure
  in 87.500 seconds. The independent checker returned
  `LEDGR_TEST_GATE_OK` against the 112-second bound. Records are at
  `C:/tmp/ledgr-ws22-fast`.
- The claims registry parses with unique IDs and registers LCL-0093 against
  LTB-0093 in the fast profile.
- A scoped search of README.md, README.Rmd, `vignettes/` and `man/` found no
  live teaching claim that inactive sessions leave the feature expected set.
- The implementation diff touches no production source, accepted RFC, prior
  packet or prior closeout.

The seven-shape optimization walk and a before-and-after performance clock are
not required here because the workstream ships no engine code. The fast record
is a regression and lane-budget check, not an optimization claim.

## Governance

At review request time there have been zero independent review invocations.
The compressed cut and close review will be one invocation over two completed
tickets: `1 / 2 = 0.500`, exactly at the gate. Any correction review would
exceed the gate and must be recorded honestly rather than hidden or padded.

Cut 15 remains open and Workstream 22 remains review-pending until the Type 1
close review passes and the maintainer accepts it. The release gate remains
blocked on that acceptance.
