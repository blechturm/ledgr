# Closeout: Settlement Axis Density Spike

**Status:** GREEN under Charter section 2: a sealed non-member recipient with
no pre-entitlement bars became held at its first real bar, completed the public
availability run, and reopened with outputs identical to a complete-history
control without fabricated history.

## What Ran

The runner copied tracked package source to scratch and added one pre-valuation
injection seam. It sealed two instruments while complete membership facts named
only the parent. At pulse three it injected a positive child holding. The
complete control had five child bars; the late-start arm had bars only from
pulse three onward. A boundary case began bars at pulse four.

All observed outputs came through `ledgr_run()`, durable ledgers, equity and
availability readers, and `ledgr_run_open()`. The checker reproduced both CSVs
byte-for-byte, gutted the injection path, detected changed evidence and
found package scope unchanged.

## What Was Learned

The complete and late-start arms both reached `DONE`. Each produced five equity
rows, child position two, positions value 40 and final equity 100040. Their
equity, availability and ledger surfaces were identical after identity fields,
with zero numeric difference.

The child was invisible before entitlement, never a member, held and priced at
entitlement from `current_close`, and preserved through reopen. The dense
row-count guard cited in the Type 2 response is therefore not a blocker on this
public availability path; ragged matrices and fold equity carry the run.

The boundary case with no bar at entitlement failed with
`ledgr_config_non_finite`. That confirms a valid mark is required when quantity
appears, while exposing an imprecise lower-level failure path.

## What The RFC May Consume

- No pre-entitlement price backfill or full-window recipient history is needed.
- On the public availability path with its prepared ragged bar matrix and fold
  equity, static physical-axis closure remains feasible when a real current
  mark exists at the effective holding pulse.
- Physical-axis inclusion did not reveal the child to the strategy before it
  became held in this executed case.
- The one-row persistence finding from the earlier Type 2 response remains
  untouched. This spike answers density, not settlement serialization.

## What Remains Open

The RFC still must bind grouped event serialization and complete-group
validation. Upstream work still must prove fixed-point recipient closure and
membership invariance. The package may separately replace the non-finite JSON
error with its intended valuation condition; this spike authorizes no fix.
