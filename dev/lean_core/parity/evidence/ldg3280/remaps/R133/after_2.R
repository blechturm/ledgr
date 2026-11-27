ws4a_d11_sources <- c(
  # P4: the fill and rejection records' instrument columns (run-axis
  # indices, not positions); lean P4 writes positions only from the lot net.
  lean_p4_apply = "fl$pos[rows] <<- fill$pos",
  lean_p4_apply = "rj$pos <<- c(rj$pos, rejection$pos)",
  # Replay: initial positions imported as given (cut 5 amendment); each
  # touched instrument's position_after from its applied rows (lot net).
  ledgr_replay_accounting_events = "positions <- stats::setNames(rep(0, length(ids)), ids)",
  ledgr_replay_accounting_events = "positions[matched] <- as.numeric(initial_positions[matched])",
  ledgr_replay_accounting_events = "positions[idx[last]] <- position_after[last]",
  # Settlement install: positions returned by the settlement boundary.
  ledgr_carrier_settlement_install = "positions <- value$positions",
  ledgr_carrier_settlement_install = "positions <- as.numeric(positions)",
  ledgr_carrier_settlement_install = "fold_state$positions <- positions"
)
ws4a_d11_hits <- function(fns) {
  unlist(lapply(names(fns), function(nm) {
    unlist(lapply(ws4a_assigns(fns[[nm]]), function(x) {
      if (!any(c("positions", "pos") %in% all.names(x[[2L]]))) return(NULL)
      rhs <- all.names(x[[3L]])
      from_net <- "net_by_inst" %in% rhs && !any(c("+", "-", "*", "/") %in% rhs)
      if (!from_net && !ws4a_txt(x) %in% ws4a_d11_sources[names(ws4a_d11_sources) == nm]) paste0(nm, ": ", ws4a_txt(x))
    }))
  }))
}

testthat::test_that("[WS4a D11] P4 and replay read positions from the lot-derived net", {
  fns <- ws4a_sources()
  examined <- fns[c("lean_p4_apply", "ledgr_replay_accounting_events", "ledgr_disposition_post",
    "ledgr_carrier_settlement_install")]
  testthat::expect_length(ws4a_d11_hits(examined), 0L)
  testthat::expect_true(any(grepl("net_by_inst", vapply(examined, ws4a_txt, ""))))
  # Every named source is still a write in its function.
  writes <- unlist(lapply(names(examined), function(nm) paste(nm, vapply(ws4a_assigns(examined[[nm]]), ws4a_txt, ""))))
  testthat::expect_true(all(paste(names(ws4a_d11_sources), ws4a_d11_sources) %in% writes))
  p4 <- function(stmt) list(lean_p4_apply = ws4a_inject(fns$lean_p4_apply, stmt))
  testthat::expect_gt(length(ws4a_d11_hits(p4("positions[[inst_idx]] <- positions[[inst_idx]] + qty"))), 0L)
  testthat::expect_gt(length(ws4a_d11_hits(p4("fold_state$positions <- planned"))), 0L)
  testthat::expect_gt(length(ws4a_d11_hits(p4("positions[[inst_idx]] <- lot_res$book$net_by_inst[[inst_idx]] + qty"))), 0L)
})
