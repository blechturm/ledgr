stage3_reference_w02 <- function(provider, package_controls) {
  fixture <- stage3_provider_w02(provider)
  e <- stage3_evidence()
  put <- e$put
  s1 <- "2024-01-02T21:00:00Z"
  s2_open <- "2024-01-03T14:30:00Z"
  s2_close <- "2024-01-03T21:00:00Z"

  c0a <- package_controls$c0a
  stage3_assert(
    identical(c0a$error_class, "LEDGR_SNAPSHOT_COVERAGE_ERROR"),
    "W02 c0a did not reach the package snapshot-coverage guard."
  )
  put("c0a", "interface", "production_ledgr_run", s1)
  put("c0a", "stop_reason", c0a$error_class, s1, reason_code = c0a$error_class)
  put("c0a", "pulses_executed", c0a$pulses_executed, s1)
  put("c0a", "fill_count", c0a$fill_count, s1)
  put("c0a", "cash_after", c0a$cash_after, s1)

  c0b <- package_controls$c0b
  stage3_assert(is.null(c0b$error_class), "W02 c0b package control failed.")
  c0b_a01 <- c0b$fills[c0b$fills$asset_id == "A01", , drop = FALSE]
  c0b_a02 <- c0b$fills[c0b$fills$asset_id == "A02", , drop = FALSE]
  stage3_assert(
    nrow(c0b_a01) == 1L && nrow(c0b_a02) == 1L,
    "W02 c0b did not produce the expected package fills."
  )
  put("c0b", "affordability_applied", FALSE, s1)
  put("c0b", "event_order", paste(c0b$fills$asset_id, collapse = "|"), s2_open)
  put("c0b", "fill_qty", as.integer(c0b_a01$qty[[1L]]), s2_open, "A01")
  put("c0b", "cash_delta", c0b_a01$cash_delta[[1L]], s2_open, "A01")
  put("c0b", "event_cash_after", c0b_a01$event_cash_after[[1L]], s2_open, "A01")
  put("c0b", "fill_qty", as.integer(c0b_a02$qty[[1L]]), s2_open, "A02")
  put("c0b", "cash_delta", c0b_a02$cash_delta[[1L]], s2_open, "A02")
  put("c0b", "cash_after", c0b$cash_after, s2_open)
  put("c0b", "equity", c0b$equity, s2_close)

  c1_proposals <- data.frame(
    asset_id = c("A02", "A01"),
    cash_delta = c(
      -(fixture$targets_a02[["c1"]] * fixture$prices[["A02"]]),
      fixture$opening_a01 * fixture$prices[["A01"]]
    ),
    status = c("active", "halted"),
    execution_price = c(
      fixture$prices[["A02"]],
      fixture$prices[["A01"]]
    ),
    stringsAsFactors = FALSE
  )
  c1_budget <- stage3_affordability(fixture$opening_cash[["c1"]], c1_proposals)
  put("c1", "visible_domain", "A02|A01", s1)
  put("c1", "target_restricted", FALSE, s1, "A01")
  put("c1", "pre_risk_target", 0L, s1, "A01")
  put("c1", "pre_risk_target", 500L, s1, "A02")
  put("c1", "feasibility_order", "A01|A02", s1)
  put("c1", "fill_status", "no_fill", s2_open, "A01", "trading_halted")
  put("c1", "virtual_cash_after", 10000, s2_open, "A01")
  put("c1", "trial_virtual_cash_after", c1_budget$trial[[1L]], s2_open, "A02")
  put("c1", "fill_status", "rejected", s2_open, "A02", "insufficient_cash")
  put("c1", "virtual_cash_after", c1_budget$after[[1L]], s2_open, "A02")
  put("c1", "governing_rule", "rejection", s2_open)
  put("c1", "virtual_final_cash", c1_budget$final_cash, s2_open)
  put("c1", "cash_after", 10000, s2_open)
  put("c1", "reconciled", TRUE, s2_open)
  put("c1", "position_after", 300L, s2_open, "A01")
  put("c1", "position_after", 0L, s2_open, "A02")
  put("c1", "gross_exposure_intended", 500 * 50, s2_open)
  put("c1", "gross_exposure_actual", 300 * 100, s2_open)
  put("c1", "equity", 10000 + 300 * 100, s2_close)
  put("c1", "diagnostic_count", 2L, s2_close)

  c2_proposals <- data.frame(
    asset_id = c("A02", "A01"),
    cash_delta = c(
      -(fixture$targets_a02[["c2"]] * fixture$prices[["A02"]]),
      fixture$opening_a01 * fixture$prices[["A01"]]
    ),
    status = c("active", "active"),
    execution_price = c(
      fixture$prices[["A02"]],
      fixture$prices[["A01"]]
    ),
    stringsAsFactors = FALSE
  )
  c2_budget <- stage3_affordability(
    fixture$opening_cash[["c2"]],
    c2_proposals,
    tolerance = fixture$cash_tolerance
  )
  event_cash <- c2_proposals$cash_delta[[1L]]
  event_final <- sum(c2_proposals$cash_delta)
  put("c2", "opening_cash", 0, s1)
  put("c2", "cash_tolerance", fixture$cash_tolerance, s1)
  put("c2", "pre_risk_target", 0L, s1, "A01")
  put("c2", "pre_risk_target", 600L, s1, "A02")
  put("c2", "feasibility_order", "A01|A02", s1)
  put("c2", "cash_delta", c2_proposals$cash_delta[[2L]], s2_open, "A01")
  put("c2", "virtual_cash_after", c2_budget$after[[2L]], s2_open, "A01")
  put("c2", "cash_delta", c2_proposals$cash_delta[[1L]], s2_open, "A02")
  put("c2", "trial_virtual_cash_after", c2_budget$trial[[1L]], s2_open, "A02")
  put("c2", "fill_status", "filled", s2_open, "A02")
  put("c2", "virtual_cash_after", c2_budget$after[[1L]], s2_open, "A02")
  put("c2", "fill_status", "filled", s2_open, "A01")
  put("c2", "event_order", "A02|A01", s2_open)
  put("c2", "event_cash_after", event_cash, s2_open, "A02")
  put("c2", "event_cash_after", event_final, s2_open, "A01")
  put("c2", "virtual_final_cash", c2_budget$final_cash, s2_open)
  put("c2", "cash_after", event_final, s2_open)
  put("c2", "reconciled", abs(c2_budget$final_cash - event_final) <= 1e-8, s2_open)
  put("c2", "completed_pulse_valid", event_final >= -1e-8, s2_open)
  put("c2", "position_after", 0L, s2_open, "A01")
  put("c2", "position_after", 600L, s2_open, "A02")
  put("c2", "equity", event_final + 600 * 50, s2_close)
  put("c2", "stop_reason", NA_character_, s2_close)
  e
}

stage3_reference_w09 <- function(provider) {
  e <- stage3_evidence()
  put <- e$put
  facts <- stage3_provider_status_facts(provider)
  cases <- data.frame(
    case_id = paste0("c", 1:5),
    decision = as.POSIXct(
      c(
        "2024-01-02 21:00:00", "2024-01-03 21:00:00",
        "2024-01-04 21:00:00", "2024-01-05 21:00:00",
        "2024-01-08 21:00:00"
      ),
      tz = "UTC"
    ),
    execution = as.POSIXct(
      c(
        "2024-01-03 14:30:00", "2024-01-04 14:30:00",
        "2024-01-05 14:30:00", "2024-01-08 14:30:00",
        "2024-01-09 14:30:00"
      ),
      tz = "UTC"
    ),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(cases))) {
    case <- cases$case_id[[i]]
    decision_status <- stage3_resolve_status(facts, "A01", cases$decision[[i]])
    execution_status <- stage3_resolve_status(facts, "A01", cases$execution[[i]])
    if (i <= 4L) {
      restricted <- decision_status != "active"
      put(case, "target_restricted", restricted, stage3_iso(cases$decision[[i]]), "A01", stage3_status_fill_reason(decision_status))
    }
    put(case, "resolved_status", execution_status, stage3_iso(cases$execution[[i]]), "A01")
    if (identical(execution_status, "active")) {
      put(case, "fill_status", "filled", stage3_iso(cases$execution[[i]]), "A01")
      if (case == "c1") put(case, "fill_price", 100, stage3_iso(cases$execution[[i]]), "A01")
      if (case == "c4") put(case, "fill_qty", 100L, stage3_iso(cases$execution[[i]]), "A01")
      put(case, "cash_after", 100000, stage3_iso(cases$execution[[i]]))
    } else {
      put(case, "fill_status", "no_fill", stage3_iso(cases$execution[[i]]), "A01", stage3_status_fill_reason(execution_status))
      put(case, "position_after", 100L, stage3_iso(cases$execution[[i]]), "A01")
      if (case == "c2") put(case, "later_fields_consulted", FALSE, stage3_iso(cases$execution[[i]]))
    }
  }
  c6_time <- "2024-01-03T14:30:00Z"
  put("c6", "status_assertion_count", 0L, "2024-01-02T21:00:00Z", "A05")
  put("c6", "resolved_status", "status_unknown", c6_time, "A05")
  put("c6", "fill_status", "no_fill", c6_time, "A05", "status_unknown")
  put("c6", "position_after", 100L, c6_time, "A05")
  put("c6", "cash_after", 90000, c6_time)
  e
}

stage3_reference_w22 <- function(provider) {
  fixture <- stage3_provider_w22(provider)
  e <- stage3_evidence()
  put <- e$put
  put_identity <- e$put_identity
  decision <- "2024-01-03T21:00:00Z"
  execution <- "2024-01-04T14:30:00Z"
  equity <- fixture$opening_cash + fixture$held_qty * fixture$mark
  risk_hash <- getFromNamespace("ledgr_risk_chain_hash", "ledgr")
  risk_005 <- risk_hash(
    ledgr::ledgr_risk_max_weight(fixture$max_weight[["c0"]])
  )
  risk_05 <- risk_hash(
    ledgr::ledgr_risk_max_weight(fixture$max_weight[["c2"]])
  )
  valuation_fresh <- stage3_hash(list(A02 = list(mark = 50, age = 0, source = "observed_close")))
  valuation_stale <- stage3_hash(list(A02 = list(mark = 50, age = 1, source = "stale_mark")))

  put("c0", "mark_source", "observed_close", decision, "A02")
  put("c0", "mark_age", fixture$mark_age_fresh, decision, "A02")
  put("c0", "equity", equity, decision)
  put("c0", "pre_risk_target", 200L, decision, "A02")
  put("c0", "post_risk_target", as.integer(fixture$max_weight[["c0"]] * equity / fixture$mark), decision, "A02", "max_weight_reduction")
  put("c0", "post_risk_validation", "accepted", decision, "A02")
  put("c0", "execution_bar_available", TRUE, execution, "A02")
  put("c0", "fill_price", fixture$execution_price, execution, "A02")
  put("c0", "fill_status", "filled", execution, "A02")
  put("c0", "fill_qty", 100L, execution, "A02")
  put("c0", "cash_after", fixture$opening_cash + 100 * fixture$execution_price, execution)
  put_identity("c0", "risk_chain_hash", "risk_chain_hash", risk_005, step = 7L)
  put_identity("c0", "valuation_evidence_identity", "proto:valuation_evidence_id", valuation_fresh, step = 8L)

  put("c1", "strategy_close_available", FALSE, decision, "A02")
  put("c1", "mark_source", "stale_mark", decision, "A02")
  put("c1", "mark_age", fixture$mark_age_stale, decision, "A02")
  put("c1", "mark_value", fixture$mark, decision, "A02")
  put("c1", "equity", equity, decision)
  put("c1", "risk_aborted", FALSE, decision)
  put("c1", "post_risk_target", as.integer(fixture$max_weight[["c1"]] * equity / fixture$mark), decision, "A02", "stale_mark_reduction")
  put("c1", "risk_mark_source", "stale_mark", decision, "A02")
  put("c1", "risk_mark_age", 1L, decision, "A02")
  put_identity("c1", "risk_chain_hash", "risk_chain_hash", risk_005)
  put_identity("c1", "valuation_evidence_identity", "proto:valuation_evidence_id", valuation_stale)
  put("c1", "execution_bar_available", TRUE, execution, "A02")
  put("c1", "fill_price", fixture$execution_price, execution, "A02")
  put("c1", "fill_status", "filled", execution, "A02")
  put("c1", "fill_qty", 100L, execution, "A02")
  put("c1", "cash_after", fixture$opening_cash + 100 * fixture$execution_price, execution)

  put("c2", "post_risk_target", 200L, decision, "A02", "stale_mark_pass_through")
  put("c2", "risk_mark_source", "stale_mark", decision, "A02")
  put_identity("c2", "risk_chain_hash", "risk_chain_hash", risk_05)
  put("c2", "fill_status", "not_attempted", execution, "A02")

  put("c3", "held_qty", 0L, decision, "A03")
  put("c3", "pre_risk_target", 100L, decision, "A03")
  put("c3", "mark_source", "none", decision, "A03")
  put("c3", "stop_reason", "risk_mark_unavailable", decision)
  put("c3", "stop_asset_id", "A03", decision)
  put("c3", "stop_target", 100L, decision)
  put("c3", "stop_risk_step", "max_weight", decision)
  put("c3", "fill_proposals", 0L, decision)
  put("c3", "state_mutated", FALSE, decision)
  put("c3", "cash_after", fixture$opening_cash, decision)
  put("c3", "reason_is_valuation_exhaustion", FALSE, decision)
  e
}

stage3_reference_w24 <- function(provider) {
  fixture <- stage3_provider_w24(provider)
  e <- stage3_evidence()
  put <- e$put
  fill_time <- "2024-01-03T14:30:00Z"
  fold1_close <- "2024-01-04T21:00:00Z"
  fold2_open <- "2024-01-05T21:00:00Z"
  closing_cash <- fixture$opening_cash - fixture$buy_qty * fixture$buy_price
  put("c1", "fill_qty", as.integer(fixture$buy_qty), fill_time, "A01")
  put("c1", "fold1_closing_cash", closing_cash, fold1_close)
  put("c1", "fold1_closing_qty", as.integer(fixture$buy_qty), fold1_close, "A01")
  put("c1", "member", FALSE, fold1_close, "A01")
  put("c1", "mark_age", 0L, fold1_close, "A01")
  put("c1", "equity", closing_cash + fixture$buy_qty * fixture$buy_price, fold1_close)
  opening_axis <- c(fixture$fold2_members, fixture$carried_id)
  put("c1", "opening_axis", paste(opening_axis, collapse = "|"), fold2_open)
  put("c1", "opening_validation", "accepted", fold2_open)
  put("c1", "requires_current_membership", FALSE, fold2_open)
  put("c1", "held_qty", as.integer(fixture$buy_qty), fold2_open, "A01")
  put("c1", "lot_basis", fixture$carried_basis, fold2_open, "A01")
  put("c1", "opening_cash", closing_cash, fold2_open)
  put("c1", "held_nonmember_count", 1L, fold2_open)
  put("c1", "pre_risk_target", as.integer(fixture$buy_qty), fold2_open, "A01")
  put("c1", "package_walk_forward_claimed", FALSE, fold2_open)
  e
}

stage3_reference_w25 <- function(provider) {
  fixture <- stage3_provider_w25(provider)
  e <- stage3_evidence()
  put <- e$put
  put_identity <- e$put_identity
  times <- fixture$times
  raw <- fixture$raw
  g1_values <- stage3_rolling_mean_two(stage3_carry_forward(raw))
  g2_values <- stage3_carry_forward(stage3_rolling_mean_two(raw))
  raw_id <- stage3_hash(list(kind = "raw", values = c("1", "3", "NA", "9")))
  graph_inputs <- list(calendar = fixture$calendar, classifier = fixture$classifier)
  g1_id <- stage3_hash(c(list(order = c("carry", "roll2")), graph_inputs))
  g2_id <- stage3_hash(c(list(order = c("roll2", "carry")), graph_inputs))
  fit_id <- stage3_hash(list(
    recipe = "label_mean_v1", population = fixture$population,
    cutoff = fixture$cutoff, calendar = fixture$calendar,
    classifier = fixture$classifier, rng = fixture$rng, fitted = 15
  ))
  for (i in seq_along(times)) {
    put("g1", "feature_value", g1_values[[i]], times[[i]], "A01")
    put("g2", "feature_value", g2_values[[i]], times[[i]], "A01")
  }
  put("g1", "bars_created", 0L)
  put_identity("g1", "raw_series_identity", "proto:raw_series_id", raw_id, step = 6L)
  put_identity("g1", "graph_identity", "proto:graph_id", g1_id, step = 7L)
  put_identity("g1", "fit_identity", "proto:fitted_artifact_id", fit_id, step = 8L)
  put_identity("g2", "graph_identity", "proto:graph_id", g2_id)
  put_identity("g2", "graph_identity_g2", "proto:graph_id", g2_id, step = 6L)
  put("g2", "bars_created", 0L)

  mutation_ids <- list(
    m_cal = list(calendar = "XSYN_v2", classifier = "observed_v1", population = "A01", cutoff = times[[4L]]),
    m_cls = list(calendar = "XSYN_v1", classifier = "observed_v2", population = "A01", cutoff = times[[4L]]),
    m_pop = list(calendar = "XSYN_v1", classifier = "observed_v1", population = "A01|A02", cutoff = times[[4L]]),
    m_cut = list(calendar = "XSYN_v1", classifier = "observed_v1", population = "A01", cutoff = "2024-01-04T21:00:00Z")
  )
  for (case in names(mutation_ids)) {
    x <- mutation_ids[[case]]
    graph1 <- stage3_hash(list(order = c("carry", "roll2"), calendar = x$calendar, classifier = x$classifier))
    graph2 <- stage3_hash(list(order = c("roll2", "carry"), calendar = x$calendar, classifier = x$classifier))
    fitted <- stage3_hash(list(
      recipe = "label_mean_v1", population = x$population,
      cutoff = x$cutoff, calendar = x$calendar,
      classifier = x$classifier, rng = "fixed:20240105", fitted = 15
    ))
    put_identity(case, "raw_series_identity", "proto:raw_series_id", raw_id)
    put_identity(case, "graph_identity_g1", "proto:graph_id", graph1)
    put_identity(case, "graph_identity_g2", "proto:graph_id", graph2)
    put_identity(case, "fit_identity", "proto:fitted_artifact_id", fitted)
  }
  put("m_cut", "warm_cache_ancestors_preserved", TRUE)
  e
}
