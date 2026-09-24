# Settlement Quantity Primitive Spike Inventory

**Question:** Can settlement use the existing operation-3 accounting primitive
inside the fold, or is a new ledger event type required?

**Observed outcome:** operation 3 is a usable mid-fold insertion primitive, but
it is not a complete settlement primitive. Positive quantity works. A negative
leg that should extinguish a holding reaches net zero by appending an opposing
lot and leaves both lots live.

## What Ran

One seam was inserted after ordinary pulse accounting in a scratch copy of the
package. It accepted operation-3-shaped rows only on the canonical-R arm,
replayed each row against live fold state, and used the existing output
handler.
No package source was changed.

| Case | Observed fold evidence |
| --- | --- |
| 1. Before-fold baseline | Classified as operation 3; position and lot net both 5. |
| 2. Mid-run, no fill | One operation-3 row; final parent position and lot net both 3. |
| 3. Same-pulse fill | Event order 1 then 3; fill 2 plus injection 3 produced position and lot net 5. |
| 4. Positive child leg | Final child position and lot net both 2 with one live lot. |
| 5. Negative parent leg | Net position and basis reached zero, but two opposing parent lots remained live. |
| 6. Two same-source legs | Both operation-3 rows retained one source identity; parent net zero still held two opposing lots. |
| 7. Malformed second leg | Fold errored after the first row persisted; the child prefix position and lot both remained 1. |
| 8. Compiled arm | Fold completed with zero injected events and zero position: silent drop confirmed. |
| 9. Resume and reopen | A child quantity of 2 survived interruption, resume, durable storage, and reopen. |

All rows in `evidence/cases.csv` are derived from emitted ledger rows, fold
status, accounting replay, or the reopened durable result. No narrated output
row is counted as evidence.

## Demoted, Deleted, Learned

Demoted:

- The source-read claim that operation 3 is a general settlement primitive.
  It is an append-only lot insertion primitive at the observed boundary.
- The claim that its preparer is the sole authority for operation-3 behavior.
  Lot application independently recognizes opening-position metadata.

Deleted from the working theory:

- A new top-level event type is necessary merely because the fold cannot emit
  quantity-changing accounting rows mid-run. One seam emitted and persisted
  positive rows, including across resume and reopen.
- A multi-leg group is atomic by construction. Case 7 preserved leg 1 after
  leg 2 failed on the memory path.

Learned about the package:

- Same-pulse order can be explicit: the existing fill was event operation 1,
  followed by injected operation 3.
- Negative operation 3 does not consume FIFO lots. Net and total basis alone
  conceal the two opposing live lots.
- The compiled spot-FIFO path has no route for this event and drops it without
  changing fold status.
- Durable reconstruction already understands a persisted operation-3 row.

## Gutted Path

The gut disabled the `opening_position` classifier in the scratch copy of
`R/accounting-replay.R`. Case 1 changed from operation 3 to operation 2, and
Case 7 changed from `ERROR` to `DONE`; the checker rejected the changed CSV.
Quantity still reached lot accounting because `R/lot-accounting.R` contains an
independent opening-metadata classifier. That surviving behavior is evidence
of duplicated classification, not a passing gut.

## Reproduction

From the repository root with R 4.6.1:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/spikes/settlement_quantity_primitive/spike_checker.R
```

The checker reruns normal and gutted forks in scratch directories, byte-diffs
the normal CSV, and confirms package-scope Git status is unchanged.
