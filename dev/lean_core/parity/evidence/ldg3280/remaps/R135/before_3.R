  kernel <- fns[c(intersect(ws4a_kernel_names, names(fns)), "ledgr_lot_apply_blocks", "ledgr_fold_stage_apply",
    "ledgr_fold_fill_candidate")]
  testthat::expect_length(ws4a_hits(kernel, check), 0L)
  p4_loop <- paste("for (i in seq_along(fill$k)) fold_state$lot_state <- ledgr_lot_fill(fold_state$lot_state,",
    "fill$pos[[i]], fill$side[[i]], fill$qty[[i]], fill$price[[i]], fill$fee[[i]])$book")
  testthat::expect_gt(length(ws4a_hits(list(p4 = ws4a_inject(fns$ledgr_fold_stage_apply, p4_loop)), check)), 0L)
