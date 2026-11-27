# R013 - FINDING (the b half is a new test, not a remap)

Block: test-availability-state.R, "fixed baskets use the canonical
valuation-state service".

The pin block has two oracles, both about the fold run:
- the run finishes `DONE`;
- `ledgr_availability_valuation_state` is called at least once
  (`expect_gt(calls, 0L)`).

It has no oracle on what the service returns. It never looks at a valued
basket, a mark or an age.

Amendment decision (3) splits the claim:
- **c half.** "The fold calls the service on a fixed basket" retires under
  interface Section 19.11. This is the existing `expect_gt(calls, 0L)`. It
  can be deleted by that decision, as the inventory says.
- **b half.** The inventory's b target is "a direct test that
  `ledgr_availability_valuation_state` values a fixed basket, with no fold".
  This half cannot be written by changing call sites. Once the fold run is
  dropped, nothing in the block exercises the service. A direct call needs
  inputs the block does not build: `bars_mat`, `instrument_ids`,
  `pulses_posix`, `max_sessions`, and `exhausted`/`pulse_columns`. It also
  needs expected values (the valued closes, mark sources and ages) that the
  block never asserted. That means a new fixture and a new oracle. By the
  remap rules this is not mechanical: it adds an expected value rather than
  preserving one.

What it needs instead: the owner test is written as a new test, with its own
stated reason in the ticket evidence and an oracle that is independent of the
service. For example, the two-bar AAA fixture's close 100 marked
`current_close` with age 0 on both pulses. If a stale bar is used, the
mark-age and exhaustion cases also need oracles. Two candidate homes:
- test-ws4a-carrier.R or test-workstream8-exact-parity.R, which already call
  the service directly;
- the R013 block itself, rewritten.

Either way it is a maintainer-approved new test, not a remap.

A direct owner test with value oracles may already exist. test-ws4a-carrier.R
"[WS4a F4.19] the provider adapter keeps unpriced provenance field by field"
calls `ledgr_availability_valuation_state(list(close = close), ids, pulses,
2L, exhausted)$advance(...)` with no fold and asserts its fields.
workstream8's exact-parity helper also calls it directly. If the maintainer
accepts F4.19 as the owner witness, R013 needs no new test: its c half
retires by decision (3), and the block keeps only its public-run `DONE`
check, unchanged. The inventory row should then cite F4.19 as the b-half
owner instead of describing a remap. The `DONE`
status assertion on the public run can stay as it is.
