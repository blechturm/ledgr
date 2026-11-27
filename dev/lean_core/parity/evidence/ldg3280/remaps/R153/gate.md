# R153: Cut 28 gate

The text of [WS4a D22] needs no change. Its dictionaries, text helpers and
`ledgr_plan_side` are all kept. Its only affected dependency is the helper
`ledgr_test_next_open_fill` (helper-fixtures.R, inventory row R175). That
helper builds the BUY and SELL fills with `ledgr_plan_resolve` and
`ledgr_plan_groups`. Deletion-readiness seed v2, Section 4.4, deletes
`ledgr_plan_resolve()` and merges the batch cost resolve into one function in
R/cost-model.R. Cut 28 must create that merged resolve. Then the remap is
R175's: in the helper,

- replace `ledgr_plan_resolve(resolver, side, qty, open)` with the merged
  resolve on the resolver's compiled steps;
- replace `ledgr_plan_groups(...)` with `lean_plan_groups(...)`, with the
  same arguments.

This block then runs unchanged. Its witness is the existing side-token
control (BUY/SELL from `ledgr_fill_event_payload`) together with the
renumbered-dictionary control.
