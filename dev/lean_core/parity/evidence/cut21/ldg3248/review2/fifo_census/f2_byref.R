# The one capture/census difference outside the rng file: rebuild the
# test's book (test-ws4a-carrier.R ws4a_book(), D15 test lines 609-619) with
# the pinned package, digest it with the call's input before and after the
# test's by-reference write, as the census (at the call) and the capture
# (serialized later) see it.
.libPaths(c("C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151", .libPaths()))
setwd("C:/Users/maxth/ledgr-wt/ws40-scratch")
ns <- asNamespace("ledgr")
book <- ns$ledgr_lot_book(3L)
book <- ns$ledgr_lot_fill(book, 1L, 1L, 2, 100, 0.5)$book
book <- ns$ledgr_lot_fill(book, 1L, 1L, 1.5, 102, 0)$book
book <- ns$ledgr_lot_fill(book, 2L, -1L, 3, 50, 0.25)$book
shared <- unserialize(serialize(book, NULL))
seen <- NULL
trace_env <- new.env()
orig <- ns$ledgr_lot_apply
unlockBinding("ledgr_lot_apply", ns)
assign("ledgr_lot_apply", function(book, input) { seen <<- input; orig(book, input) }, envir = ns)
out <- ns$ledgr_lot_fill(shared, 1L, 1L, 1, 101)
assign("ledgr_lot_apply", orig, envir = ns)
at_call <- digest::digest(list(shared, seen), algo = "xxhash64")
collapse::setv(shared$lot_qty, seq_along(out$book$lot_qty), out$book$lot_qty, vind1 = TRUE)
after <- digest::digest(list(shared, seen), algo = "xxhash64")
cat(sprintf("digest at the call: %s (census A and B: 08f3659ff00704e6)\n", at_call))
cat(sprintf("digest after the test's by-reference write: %s (capture: f75bcf74ea363a34)\n", after))
