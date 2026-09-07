stage3_w21_evidence <- function(trace) {
  evidence <- stage3_evidence()
  put <- evidence$put
  put_identity <- evidence$put_identity
  case <- "c1"
  decision_times <- stage3_iso(trace$fixture$pulses)
  fill_times <- as.character(trace$fills$event_time)

  put(case, "opening_lot_qty", 100L, decision_times[[1L]], "A01")
  put(case, "opening_lot_basis", 100, decision_times[[1L]], "A01")
  put(case, "equity", trace$equity[[1L]], decision_times[[1L]])
  put(case, "pre_risk_target", as.integer(trace$targets_pre[[1L]][["A02"]]), decision_times[[1L]], "A02")
  put(case, "post_risk_target", as.integer(trace$targets_post[[1L]][["A02"]]), decision_times[[1L]], "A02", "max_weight_reduction")
  put(case, "post_risk_target", as.integer(trace$targets_post[[1L]][["A01"]]), decision_times[[1L]], "A01", "max_weight_pass_through")
  put(case, "strategy_validation", "accepted", decision_times[[1L]])
  put(case, "event_order", paste(trace$fills$asset_id[1:2], collapse = "|"), fill_times[[1L]])

  for (i in seq_len(nrow(trace$fills))) {
    fill <- trace$fills[i, , drop = FALSE]
    time <- fill_times[[i]]
    id <- fill$asset_id[[1L]]
    put(case, "fill_index", as.integer(i), time, id)
    put(case, "fill_side", fill$side[[1L]], time, id)
    put(case, "fill_qty", as.integer(fill$qty[[1L]]), time, id)
    put(case, "fill_price", fill$price[[1L]], time, id)
    if (i < 3L) put(case, "fill_fee", fill$fee[[1L]], time, id)
    put(case, "cash_delta", fill$cash_delta[[1L]], time, id)
    if (i < 3L) put(case, "event_cash_after", fill$cash_after[[1L]], time, id)
    put(case, "realized_delta", fill$realized_delta[[1L]], time, id)
    put(case, "lot_qty_after", as.integer(fill$lot_qty_after[[1L]]), time, id)
    if (!is.na(fill$lot_basis_after[[1L]])) {
      put(case, "lot_basis_after", fill$lot_basis_after[[1L]], time, id)
    }
  }
  put(case, "realized_pnl_cumulative", trace$fills$realized_cumulative[[2L]], fill_times[[2L]])
  put(case, "position_after", as.integer(trace$fills$position_after[[1L]]), fill_times[[1L]], "A02")
  put(case, "position_after", as.integer(trace$fills$position_after[[2L]]), fill_times[[2L]], "A01")
  put(case, "equity", trace$equity[[2L]], decision_times[[2L]])
  put(case, "post_risk_target", as.integer(trace$targets_post[[2L]][["A02"]]), decision_times[[2L]], "A02", "max_weight_pass_through")
  put(case, "cash_after", trace$fills$cash_after[[3L]], fill_times[[3L]])
  put(case, "realized_pnl_cumulative", trace$fills$realized_cumulative[[3L]], fill_times[[3L]])
  put(case, "fees_total", sum(trace$fills$fee), fill_times[[3L]])
  put(case, "position_after", as.integer(trace$fills$position_after[[3L]]), fill_times[[3L]], "A01")
  put(case, "equity", trace$equity[[3L]], decision_times[[3L]])
  put(case, "post_risk_target", as.integer(trace$targets_post[[3L]][["A02"]]), decision_times[[3L]], "A02", "max_weight_pass_through")
  put(case, "fill_count", 0L, stage3_iso(trace$fixture$execution_times[[4L]]))
  put(case, "pre_risk_target", as.integer(trace$targets_pre[[4L]][["A02"]]), decision_times[[4L]], "A02")
  put(case, "fill_status", trace$final_no_fill$status, decision_times[[4L]], "A02", trace$final_no_fill$reason_code)
  put(case, "position_after", as.integer(trace$positions[["A02"]]), decision_times[[4L]], "A02")
  unrealized <- (trace$fixture$bars$close[
    trace$fixture$bars$instrument_id == "A02" &
      stage3_iso(trace$fixture$bars$ts_utc) == decision_times[[4L]]
  ] - 50) * trace$positions[["A02"]]
  put(case, "unrealized_pnl", unrealized, decision_times[[4L]], "A02")
  put(case, "equity", trace$equity[[4L]], decision_times[[4L]])
  put(case, "total_return", trace$equity[[4L]] / trace$equity[[1L]] - 1, decision_times[[4L]])
  put(case, "fill_count_total", as.integer(nrow(trace$fills)), decision_times[[4L]])
  put(case, "realized_pnl_final", trace$realized, decision_times[[4L]])
  put(case, "new_version_identity_reported_separately", TRUE)

  put_identity(case, "snapshot_hash", "snapshot_hash", trace$source_identity$snapshot_hash)
  put_identity(case, "config_hash", "config_hash", trace$source_identity$config_hash)
  evidence
}

stage3_compare_w21_traces <- function(fork, package) {
  fields <- c("asset_id", "side", "qty", "price", "fee", "cash_delta")
  stage3_assert(
    identical(fork$fills[, fields], package$fills[, fields]),
    "W21 fork/package fill values or ordering differ."
  )
  stage3_assert(
    isTRUE(all.equal(fork$equity, package$equity, tolerance = 1e-10)),
    "W21 fork/package equity differs."
  )
  stage3_assert(
    identical(
      lapply(fork$targets_post, as.numeric),
      lapply(package$targets_post, as.numeric)
    ),
    "W21 fork/package risk output differs."
  )
  stage3_assert(identical(fork$positions, package$positions), "W21 final positions differ.")
  stage3_assert(isTRUE(all.equal(fork$cash, package$cash)), "W21 final cash differs.")
  stage3_assert(isTRUE(all.equal(fork$realized, package$realized)), "W21 realized P&L differs.")
  stage3_assert(
    identical(fork$final_no_fill, package$final_no_fill),
    "W21 final-pulse no-fill evidence differs."
  )
  invisible(TRUE)
}
