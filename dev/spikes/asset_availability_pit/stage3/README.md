# Stage 3 Shared Fork And Reference Provider

This directory contains disposable evidence scaffolding for Stage 3 of the
asset-availability spike. It is not package code and cannot merge into a
release branch.

The reference representation is `dense_state_planes_reference` version 1. The
shared fork owns the tested policy mechanics. The provider supplies fixture
facts and declared identities; it does not supply expected answers. The
conformance checker compares independently produced observations with the
frozen Stage 2 tables.

Stage 3 deliberately covers:

- the full W21 dense package/fork control;
- the complete frozen tables for W02, W09, W22, W24, and W25 needed by the
  five checker mutations; and
- M1-M5 rejection with the frozen finding named for each mutation.

The remaining witness/provider matrix belongs to Stage 4. No timing from this
stage is representation evidence.

Run from the repository root:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/run_stage3.R
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/check_stage3.R --mode=review
```

The gate mode is available only after the reviewed code is committed and
`evidence/stage3_code.csv` records each executable's first-appearance commit.

## Dense-Control Adapter

The package's daily fold records a next-open fill at the next pulse timestamp.
W21's external calendar names both the session open and close. The comparison
adapter maps each package fill to the corresponding declared open label while
comparing its raw order, side, quantity, price, fee, and cash delta.

The package fill table exposes gross close P&L. The adapter reads the
fold-owned fee-net accounting attribute and checks it by reconstructing the
actual event prefix through `ledgr_lot_state_from_events()`. The frozen W21
contract uses that fee-net evidence. This translation is explicit in
`package_dense_control.R`.
