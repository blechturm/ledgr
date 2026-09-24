# Closeout: Settlement Quantity Primitive Spike

**Status:** RED under Charter section 2: an operation-3 event can be emitted
and persisted during the fold, but it cannot express the charter's full
settlement set because a negative extinguishing leg appends an opposing live
lot instead of consuming the held lot.

## What Ran

The runner built a scratch package fork with one injection seam after pulse
accounting. Case 1 first executed the source-read premise: the existing
opening-position CASHFLOW was classified as operation 3 and produced matching
position and lot state. Only after that passed were the other eight observed
answers recorded.

The final evidence contains one row per charter case. The checker reproduced
the CSV byte-for-byte, ran the prescribed operation-3 gut, and found no change
to Git status under `R`, `src`, `tests`, `NAMESPACE`, `DESCRIPTION`, `man`, or
`inst/design` during either rerun.

## What Was Learned

The cheaper prerequisite in Charter section 3 is answered yes. On canonical R,
one seam emitted positive operation-3 rows mid-fold. They coexisted with a fill
on the same pulse, two rows retained one source identity, and a positive row
survived an interrupted durable run, resume, and reopen.

The general claim fails at quantity reduction. A negative row taking a held
parent from 5 to zero left two live FIFO lots, +5 and -5, even though net
position and total cost basis were zero. The two-leg case repeated that shape.
Operation 3 therefore inserts declared lots; it does not settle or extinguish
existing lots.

Case 7 also found a non-atomic memory boundary: leg 1 remained persisted and
effective when malformed leg 2 failed. Case 8 confirmed the expected compiled
boundary: spot-FIFO completed while silently omitting the injected event.
Neither was fixed.

The gut removed the preparer's operation-3 classification. It changed the
recorded operation and disabled malformed-leg rejection, so the checker failed
loudly. Quantity effects survived through a second opening-metadata classifier
in lot accounting, exposing duplicated classification.

## What the RFC May Consume

- Mid-fold emission alone does not justify a new top-level event type.
- Existing operation 3 is evidence for positive lot insertion only.
- An extinguishing settlement needs semantics that consume existing lots;
  this spike does not decide whether those semantics use a new operation or a
  new event type.
- Multi-leg atomicity and compiled handling remain explicit design boundaries.

## What Remains Open

The spike does not choose vocabulary, event identity, timing, basis policy, or
release scope. It does not establish corporate-action semantics. Those remain
for synthesis after it accounts for the observed append-only lot behavior.
