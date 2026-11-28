# R173: finding (no remap of its own)

The text of [WS4a expected cash domain] needs no change. It reaches the
retired planner only through the helper `ws4a_3166_plan`, which is row R189.
R189's patch is this row's whole remap, and R189 uses this block as its pass
and witness title.

The mutation in R189 stops `exec_ts` from being recycled over the fill rows.
That makes the lean producer hand over a plan the validator refuses. This
block's "NA, Inf and finite pass" assertions then fail. So R189's witness
shows that the fixture now goes through the lean producer.

The claim itself (the expected-cash domain is finite, NA or +Inf) belongs to
the kept `ledgr_carrier_new` in R/fold-carrier.R. A lean mutation cannot
reach it. Its registered witness stays a validator fault in kept R/ code.

Recommendation: merge R173 into R189 rather than keep a separate "b" row.

## Resolution (row review F8 and F12, 2026-11-28)

The row now states that it has no remap of its own and rests on R189. R189's
witness is now an identity probe (the plan is identical() to the pin's), not
the fixture crash.
