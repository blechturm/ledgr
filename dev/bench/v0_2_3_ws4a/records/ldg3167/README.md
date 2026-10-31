# LDG-3167 candidate record

Product candidate `042cf097` (LDG-3167: batched application and indexed
publication) on `claude/ws4a-carrier`, base `cc0ea2e6`. The evidence commit
that adds this folder also adds the ticket evidence; it changes no product
file. No timing window, memory workload or real-data workload was run (cut 5
`amendment_performance`; decision (8): the real-data oracle runs at LDG-3164
and LDG-3169).

## Commands and outcomes

All from the worktree `C:/Users/maxth/ledgr-wt/ws4a-impl` with R 4.6.1, run
one at a time (each `load_all` rebuilds the DLL); scratch output under
`C:/Users/maxth/AppData/Local/Temp/ws13-3167/gates/`. `R/cpp11.R` and
`src/cpp11.cpp` were restored after each step. `sequence.log` holds the exit
codes.

| Gate | Command | Outcome |
| --- | --- | --- |
| Cases | `Rscript dev/bench/v0_2_3_ws4a/check.R --base=HEAD --out=<scratch>/check` | exit 0, 23 cases identical |
| Guts | `Rscript dev/bench/v0_2_3_ws4a/guts.R --base=HEAD --out=<scratch>/guts --guts=<32 guts>` | exit 0; 32 of 32 FAIL (expected), invalid-base control REFUSED (`guts.log`) |
| Dense | `Rscript dev/bench/peer_benchmark/dense/check.R --pkg=<worktree> --out=<scratch>/dense` | exit 0, PASS: nine native arms identical |
| A0 | `record.R --pkg=<worktree> --out=<scratch>/a0`, then `compare.R ... --result=<scratch>/a0/a0.csv` | both exit 0; 295 of 295 PASS (`a0-compare.csv`) |
| Refusal probe | `Rscript records/ldg3167/probe_multi.R candidate <scratch>/probe-candidate.rds` | exit 0; identical to the pre-change outcomes (`probe-candidate.txt`) |
| Suite | `Rscript -e "pkgload::load_all(...); testthat::test_local(..., reporter='summary', stop_on_failure=TRUE)"` | exit 0 (one existing skip: quantmod missing-package path) |

The 32 guts: this ticket's C13a_swallow, C13c_swallow_append,
C13c_swallow_fact, C13c_swallow_flush, C14c_reuse_staging,
C14c_reuse_leg_staging, M2_reorder_pulse_fills (M2) and M3_drop_lot_fee
(M3), plus the remaining 24 guts registered for LDG-3164 to LDG-3166.

## Moved case attachments and guts

Recorded case bytes are unchanged; only the attachments moved:

- C13a: the injected "second lot operation" counts rows of the typed fill
  operation, so it fires at the second row of pulse one's single batch call
  (on the base it fired at the second one-row call). The frozen outputs
  (abort, durable rollback, condition, accounting stage, failed memory
  result) are identical. The observed private prefix (not an oracle) now
  shows the fold state unchanged at the fault, which `[WS4a C13b]` asserts.
- C13c: the handler methods keep their names (`write_fill_events`,
  `record_accounting_fact`, `flush_pulse_events`), now block methods; no
  change.
- C14c: the retained handouts are the first typed event block
  (`ledgr_fill_event_payload`) and leg block (`ledgr_fill_leg_block`),
  fingerprinted through views in the base shape of the block's first event
  and of its legs (the frozen fingerprints), and witnessed whole as raw
  serializations (as C14a's typed book is). `leg_flushes` counts the leg
  blocks (3, as recorded). The raw-witness refusal now names the changed
  handouts.
- Guts `C14c_reuse_staging` and `C14c_reuse_leg_staging` write by reference
  into the retained typed event block's `qty` and leg block's `fee` from a
  later pulse; each changes only its own witness (the event and leg blocks
  are separate vectors; on the base an OPEN leg's qty was the event row's
  qty vector). M2 still reorders the typed fill rows at P4 entry and M3
  zeroes the typed fill operation's fee vector.

## Refusal order (base, pre-change and candidate)

`probe_multi.R` runs eight public scenarios with finite inputs and two fills
in one pulse, as a durable run and a memory sweep, against the base library
`E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`, the pre-change product
`167dc947` (load_all, before this ticket's edits) and the candidate. The
candidate equals the pre-change product in all 16 outcomes
(`probe-pre-change-167dc947.txt`, `probe-candidate.txt`). Without the
earlier fills' publication check, `pub1_lot2` would refuse with the second
fill's lot refusal instead of the base's metadata refusal; the
`[WS4a 3167 precedence]` control shows that.

Pre-existing divergence, not introduced here: in six of the 16 outcomes
(`lot_only`, `lot1_pub2`, and the sweeps of `pub1_lot2` and
`pub1_lot2_live`) the base and the pre-change product already differ
(`probe-base-953338df.txt`). Buying 1e308 units at 10 overflows the cost
basis; the base FIFO accepted it (a durable run then refused at the
metadata encoder with `ledgr_config_non_finite`, a sweep completed), while
the typed lot kernel of workstream 12 refuses the non-finite applied row
with `ledgr_lot_state_invariant` ("Invalid applied lot rows."). This
ticket keeps the pre-change behaviour and reports the divergence for
maintainer disposition.

Harness lines: 2,148 to 2,224 (+76: cases.R +12, guts.R +1, this probe +63)
under the 2,500-line budget (cut 5 `amendment_budget`).
