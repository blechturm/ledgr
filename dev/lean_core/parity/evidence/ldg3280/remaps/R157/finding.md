# R157: finding (no remap of its own; no lean witness)

The text of [WS4b F1 arithmetic NaN] needs no change. It reaches the retired
planner only through the helper `ws4a_3166_plan`, which is row R189. R189's
patch is this row's whole remap, and R189 lists this block as a pass title.

Its claim belongs entirely to the kept validator `ledgr_carrier_new`. The
block asserts that a plan is refused after an NA fee, an NA cash_delta, or a
NaN cash_delta with a finite fee. It makes no positive assertion about the
fixture. So no mutation of the candidate's lean files can make the block
fail by removing a refusal. Any malformed plan from the lean producer is
still refused. The only way to make it fail is a producer fault that errors
under debug, and that is a crash of the fixture, not a witness of the claim.
The registered witness for this claim is a fault in R/fold-carrier.R, and
the remap leaves that file unchanged.

Recommendation: reclassify R157 as "covered by R189; block text unchanged".
Its witness stays a validator fault in kept R/ code, outside the candidate.
