# ledgr v0.2.3 Spec Packet

Role: living; current packet front door.
Status: working. Cut 24 (feature engine stages 2-3) is the current cut.
Authority: routing only. The roadmap owns scope, the macro plan owns uncut
order, and the tickets file owns accepted cuts and implementation sequence.

## Start here

- [Tickets](tickets.yml) for current status, decisions, reviews and evidence.
- [Macro plan](macro_plan.md) for the remaining release sequence.
- [Lean-core interface](lean_core_interface.md) and [rules ledger](lean_core_rules_ledger.md)
  for the lean-core implementation and switch.
- [Horizon classification](horizon_open_classification.md) for the active
  governance checker.
- [M4 install-floor brief](m4_install_floor_brief.md) for the pending
  release-certification measurement.

Release scope lives in the [roadmap](../ledgr_roadmap.md#next-release).
See the [RFC pipeline](../rfc/README.md#rfc-pipeline),
[contracts](../contracts.md) and [decisions bridge](../decisions.md) for
design and behavior. The [v0.2.2 packet](../ledgr_v0_2_2_spec_packet/README.md)
records the previous release.

## Closed-cut records

This packet keeps review files for open cuts. The original closed-cut reviews
and superseded working documents remain available in the
[packet at the pre-cleanup commit](https://github.com/blechturm/ledgr/tree/ea580bc6b1d345f7aae9e6836b4f12fe94e18afe/inst/design/ledgr_v0_2_3_spec_packet).
The cut and ticket records point to individual files or to their evidence
owners. Local recovery uses `git show <commit>:<repo-relative-path>`.
See the [review record rule](../rfc_cycle.md#review-modes-workstreams-and-routes).
