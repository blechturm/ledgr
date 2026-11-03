# Stage 2: ledgr's guarantees added back to the floor one layer at a time, in
# lean form. Each layer must still reproduce ledgr's output exactly.
#
# layers$validate  strategy-target checks at the boundary, every pulse
# layers$ctx       "lean" (fast, slow, state, hold) or "rich" (adds the
#                  pulse fields a ledgr context exposes)
# layers$avail     fixed-basket availability: eligibility mask, mark source
#                  and age, restricted targets held (all-pass on this fixture)
# layers$trace     "none"; "full" builds ledgr's logical decision trace every
#                  pulse; "diff" keeps only intent/outcome differences, and
#                  r_floor_rebuild_trace() rebuilds the full trace afterwards
#                  from the fills and prepared planes, without the strategy

r_floor_prepare_rich <- function(fx, p) {
  bars <- fx$bars
  n <- length(p$ids); t_n <- fx$n_pulse
  plane <- function(col) matrix(bars[[col]], nrow = n, ncol = t_n, byrow = TRUE,
                                dimnames = list(p$ids, NULL))
  p$high <- plane("high"); p$low <- plane("low"); p$volume <- plane("volume")
  p$ts_iso <- format(p$ts, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  p$has_bar <- matrix(TRUE, n, t_n)
  p
}

r_floor_gross <- function(q, mark) {
  contributions <- ifelse(q == 0, 0, abs(q * mark))
  if (anyNA(contributions) || any(!is.finite(contributions))) NA_real_ else sum(contributions)
}

r_floor_detail <- function(cash_before, virtual, recorded, intended, post_risk, actual) {
  ledgr:::ledgr_json_write_canonical_v2(list(
    actual_gross_exposure = actual, cash_before = cash_before,
    exposure_basis = "decision_mark_gross", intended_gross_exposure = intended,
    post_risk_gross_exposure = post_risk, recorded_final_cash = recorded,
    virtual_final_cash = virtual))
}

# Typed trace buffers: stage 1 decision, 2 execution, 3 reconciliation,
# 4 the run's raw-sizing notice, 5 a final-pulse request that cannot execute.
r_floor_trace_buffer <- function(cap) {
  list(pulse = integer(cap), inst = integer(cap), stage = integer(cap),
       target = numeric(cap), qty = numeric(cap), price = numeric(cap),
       before = numeric(cap), after = numeric(cap), exec = integer(cap),
       event = integer(cap), detail = character(cap), n = 0L)
}

r_floor_fold_layers <- function(p, strategy, layers, capacity = 1e6) {
  n <- length(p$ids); t_n <- ncol(p$close); ids <- p$ids
  pos <- stats::setNames(numeric(n), ids); cash <- 1e7
  state <- list(above = stats::setNames(logical(n), ids), usable = stats::setNames(logical(n), ids))
  equity <- cash_path <- numeric(t_n)
  fills <- r_floor_fill_buffer(capacity)
  ctx <- new.env(parent = emptyenv())
  ctx$hold <- function() pos
  ctx$universe <- ids
  env <- new.env(parent = asNamespace("stats"))
  env$ledgr_strategy_result <- function(targets, ...) list(targets = targets, state = list(...))
  environment(strategy) <- env
  rich <- identical(layers$ctx, "rich")
  avail <- isTRUE(layers$avail)
  trace <- layers$trace
  if (avail) { last_close <- p$close[, 1L]; mark_age <- numeric(n) }
  full <- identical(trace, "full")
  if (full) {
    cap <- 1L + t_n * (n + 1L) + capacity
    tr_pulse <- integer(cap); tr_inst <- integer(cap); tr_stage <- integer(cap)
    tr_target <- numeric(cap); tr_qty <- numeric(cap); tr_price <- numeric(cap)
    tr_before <- numeric(cap); tr_after <- numeric(cap); tr_exec <- integer(cap)
    tr_event <- integer(cap); tr_detail <- character(cap)
    tr_stage[1L] <- 4L; tr_pulse[1L] <- 1L; tr_n <- 1L
    event_seq <- 0L
  }
  # The diff layer's residual: requests that did not end in the requested
  # position (pulse, instrument, target); nothing else is stored.
  res_pulse <- integer(); res_inst <- integer(); res_target <- numeric()
  for (t in seq_len(t_n)) {
    cl <- p$close[, t]
    if (avail) {
      eligible <- p$has_bar[, t]
      cl <- ifelse(eligible, cl, last_close)
      mark_age <- ifelse(eligible, 0, mark_age + 1)
      last_close <- cl
    }
    cash_path[t] <- cash
    equity[t] <- cash + sum(pos * cl)
    ctx$fast <- p$fast[, t]; ctx$slow <- p$slow[, t]; ctx$state <- state
    if (rich) {
      ctx$ts_utc <- p$ts_iso[[t]]; ctx$cash <- cash; ctx$equity <- equity[[t]]
      ctx$positions <- pos; ctx$open <- p$open[, t]; ctx$high <- p$high[, t]
      ctx$low <- p$low[, t]; ctx$close <- cl; ctx$volume <- p$volume[, t]
    }
    res <- strategy(ctx, NULL)
    target <- res$targets
    state <- res$state
    if (isTRUE(layers$validate)) {
      if (!is.numeric(target) || length(target) != n || !identical(names(target), ids) ||
          anyNA(target) || !all(is.finite(target))) stop("invalid strategy targets at pulse ", t)
    }
    if (avail) target[!eligible] <- pos[!eligible]
    before <- pos
    if (full) {
      k <- tr_n + seq_len(n)
      tr_pulse[k] <- t; tr_inst[k] <- seq_len(n); tr_stage[k] <- 1L
      tr_target[k] <- target; tr_qty[k] <- before; tr_price[k] <- cl
      tr_before[k] <- before; tr_after[k] <- before
      tr_n <- tr_n + n
    }
    cash_start <- cash
    hit <- integer(); fill_cash <- numeric()
    if (t < t_n) {
      delta <- target - pos
      hit <- which(delta != 0)
      if (length(hit)) {
        price <- p$open[hit, t + 1L]
        dest <- fills$n + seq_along(hit)
        fills$inst[dest] <- hit; fills$pulse[dest] <- t + 1L
        fills$qty[dest] <- unname(delta[hit]); fills$price[dest] <- price
        fills$n <- fills$n + length(hit)
        pos[hit] <- target[hit]
        fill_cash <- -unname(delta[hit]) * price
        for (k in seq_along(hit)) cash <- cash + fill_cash[[k]]
      }
    }
    # A request that did not end in the requested position cannot be
    # rebuilt from the fills; the diff layer would store it.
    unmet <- which(target != pos)
    if (identical(trace, "diff") && length(unmet)) {
      res_pulse <- c(res_pulse, rep(t, length(unmet))); res_inst <- c(res_inst, unmet)
      res_target <- c(res_target, unname(target[unmet]))
    }
    if (full) {
      if (length(hit)) {
        k <- tr_n + seq_along(hit)
        tr_pulse[k] <- t; tr_inst[k] <- hit; tr_stage[k] <- 2L
        tr_target[k] <- target[hit]; tr_qty[k] <- abs(unname(delta[hit]))
        tr_price[k] <- price; tr_before[k] <- before[hit]; tr_after[k] <- pos[hit]
        tr_exec[k] <- t + 1L; tr_event[k] <- event_seq + seq_along(hit)
        event_seq <- event_seq + length(hit); tr_n <- tr_n + length(hit)
      }
      if (length(unmet)) {
        k <- tr_n + seq_along(unmet)
        tr_pulse[k] <- t; tr_inst[k] <- unmet; tr_stage[k] <- 5L
        tr_target[k] <- target[unmet]; tr_qty[k] <- pos[unmet]
        tr_before[k] <- pos[unmet]; tr_after[k] <- pos[unmet]
        tr_n <- tr_n + length(unmet)
      }
      tr_n <- tr_n + 1L
      tr_pulse[tr_n] <- t; tr_stage[tr_n] <- 3L
      # ledgr's expected (virtual) cash is booked fill by fill with sells
      # first, then buys (ordered affordability).
      virtual <- cash_start
      for (k in order(fill_cash < 0)) virtual <- virtual + fill_cash[[k]]
      tr_detail[tr_n] <- r_floor_detail(cash - sum(fill_cash), virtual, cash,
        r_floor_gross(target, cl), r_floor_gross(target, cl), r_floor_gross(pos, cl))
    }
  }
  out <- r_floor_finish(p, fills, equity, cash_path)
  out$residual <- list(pulse = res_pulse, inst = res_inst, target = res_target)
  out$unmet <- length(res_pulse)
  if (full) {
    k <- seq_len(tr_n)
    out$trace <- list(pulse = tr_pulse[k], inst = tr_inst[k], stage = tr_stage[k],
      target = tr_target[k], qty = tr_qty[k], price = tr_price[k], before = tr_before[k],
      after = tr_after[k], exec = tr_exec[k], event = tr_event[k], detail = tr_detail[k])
  }
  out
}

# The diff layer's read side: rebuild the full trace from the fills and the
# prepared planes plus the stored residual, vectorised over pulses, with no
# strategy call.
r_floor_rebuild_trace <- function(p, fills, residual) {
  n <- length(p$ids); t_n <- ncol(p$close)
  f_inst <- match(fills$instrument_id, p$ids)
  f_exec <- match(as.numeric(fills$ts_utc), as.numeric(p$ts))
  f_qty <- ifelse(fills$side == "BUY", fills$qty, -fills$qty)
  f_cash <- -f_qty * fills$price
  # Position at decision t: every fill executed at or before pulse t.
  delta <- matrix(0, n, t_n); delta[cbind(f_inst, f_exec)] <- f_qty
  before <- t(apply(delta, 1L, cumsum))
  after <- cbind(before[, -1L, drop = FALSE], before[, t_n])
  target <- after
  target[cbind(residual$inst, residual$pulse)] <- residual$target
  # Cash after each fill in event order, added in plain double precision as
  # the fold books it (cumsum() accumulates in long double and differs in the
  # last digit). Decision t's fills execute at the open of t + 1, so the cash
  # at decision t has every fill executed at or before t, and after decision
  # t every fill executed at or before t + 1.
  cs <- numeric(length(f_cash) + 1L); cs[[1L]] <- 1e7
  for (j in seq_along(f_cash)) cs[[j + 1L]] <- cs[[j]] + f_cash[[j]]
  f_dec <- f_exec - 1L
  start <- cs[findInterval(seq_len(t_n), f_exec) + 1L]
  recorded <- cs[findInterval(seq_len(t_n) + 1L, f_exec) + 1L]
  dec_cash <- tapply(f_cash, f_dec, sum)
  # Expected cash per decision: the same fills with sells first, then buys.
  # One pass over all fills sorted by decision, sells before buys.
  virtual <- start
  ord <- order(f_dec, f_cash < 0, seq_along(f_dec), method = "radix")
  prev <- 0L; v <- 0
  for (k in ord) {
    t <- f_dec[[k]]
    if (t != prev) { v <- start[[t]]; prev <- t }
    v <- v + f_cash[[k]]
    virtual[[t]] <- v
  }
  fc <- numeric(t_n); fc[as.integer(names(dec_cash))] <- dec_cash
  details <- vapply(seq_len(t_n), function(t) {
    r_floor_detail(recorded[t] - fc[t], virtual[t], recorded[t],
      r_floor_gross(target[, t], p$close[, t]), r_floor_gross(target[, t], p$close[, t]),
      r_floor_gross(after[, t], p$close[, t]))
  }, character(1))
  # Assemble in ledgr's order: notice, then per pulse decisions, executions
  # of that pulse's decision, reconciliation.
  per <- n + 1L + tabulate(f_dec, t_n) + tabulate(residual$pulse, t_n)
  total <- 1L + sum(per)
  b <- r_floor_trace_buffer(total)
  b$stage[1L] <- 4L; b$pulse[1L] <- 1L
  offs <- 1L + c(0L, cumsum(per)[-t_n])
  dec_rows <- as.vector(outer(seq_len(n), offs, "+"))
  b$pulse[dec_rows] <- rep(seq_len(t_n), each = n); b$inst[dec_rows] <- rep(seq_len(n), t_n)
  b$stage[dec_rows] <- 1L; b$target[dec_rows] <- as.vector(target)
  b$qty[dec_rows] <- as.vector(before)
  b$price[dec_rows] <- as.vector(p$close); b$before[dec_rows] <- as.vector(before)
  b$after[dec_rows] <- as.vector(before)
  within <- ave(seq_along(f_dec), f_dec, FUN = seq_along)
  ex_rows <- offs[f_dec] + n + within
  b$pulse[ex_rows] <- f_dec; b$inst[ex_rows] <- f_inst; b$stage[ex_rows] <- 2L
  b$target[ex_rows] <- before[cbind(f_inst, f_exec)]; b$qty[ex_rows] <- abs(f_qty)
  b$price[ex_rows] <- fills$price; b$before[ex_rows] <- before[cbind(f_inst, f_dec)]
  b$after[ex_rows] <- before[cbind(f_inst, f_exec)]; b$exec[ex_rows] <- f_exec
  b$event[ex_rows] <- seq_along(f_dec)
  nf <- tabulate(f_dec, t_n)
  res_within <- ave(seq_along(residual$pulse), residual$pulse, FUN = seq_along)
  rs_rows <- offs[residual$pulse] + n + nf[residual$pulse] + res_within
  b$pulse[rs_rows] <- residual$pulse; b$inst[rs_rows] <- residual$inst; b$stage[rs_rows] <- 5L
  b$target[rs_rows] <- residual$target
  held <- before[cbind(residual$inst, residual$pulse)]
  b$qty[rs_rows] <- held; b$before[rs_rows] <- held; b$after[rs_rows] <- held
  rec_rows <- offs + per
  b$pulse[rec_rows] <- seq_len(t_n); b$stage[rec_rows] <- 3L; b$detail[rec_rows] <- details
  b$n <- total
  b[setdiff(names(b), "n")]
}

# ledgr's diagnostics layout for a typed trace, for exact comparison.
r_floor_trace_frame <- function(p, tr) {
  m <- length(tr$stage); s <- tr$stage
  na_num <- function(keep, x) ifelse(keep, x, NA_real_)
  dec <- s == 1L; ex <- s == 2L; rec <- s == 3L; nf <- s == 5L
  data.frame(
    diagnostic_seq = seq_len(m),
    ts_utc = as.numeric(p$ts[tr$pulse]),
    instrument_id = ifelse(dec | ex | nf, p$ids[pmax(tr$inst, 1L)], ""),
    stage = c("decision", "execution", "reconciliation", "sizing", "execution")[s],
    outcome = c("recorded", "filled", "reconciled", "unavailable", "no_fill")[s],
    reason_code = c("decision_recorded", "", "affordability_reconciled", "sizing_intent_unavailable",
                    "final_pulse_no_execution")[s],
    reasons = c("decision_recorded", "", "affordability_reconciled", "raw_quantity_targets",
                "final_pulse_no_execution")[s],
    target = na_num(dec | ex | nf, tr$target), quantity = na_num(dec | ex | nf, tr$qty),
    price = na_num(dec | ex, tr$price),
    mark_source = ifelse(dec, "current_close", ""),
    mark_age = ifelse(dec, 0L, NA_integer_),
    decision_ts_utc = as.numeric(p$ts[tr$pulse]),
    execution_ts_utc = ifelse(ex, as.numeric(p$ts[pmax(tr$exec, 1L)]), NA_real_),
    event_seq = ifelse(ex, tr$event, NA_integer_),
    target_before_risk = na_num(dec | ex | nf, tr$target), target_after_risk = na_num(dec | ex | nf, tr$target),
    position_before = na_num(dec | ex | nf, tr$before), position_after = na_num(dec | ex | nf, tr$after),
    detail_json = ifelse(rec, tr$detail, "{}"),
    stringsAsFactors = FALSE)
}

r_floor_ledgr_trace_frame <- function(d) {
  cols <- c("diagnostic_seq", "ts_utc", "instrument_id", "stage", "outcome", "reason_code",
            "reasons", "target", "quantity", "price", "mark_source", "mark_age",
            "decision_ts_utc", "execution_ts_utc", "event_seq", "target_before_risk",
            "target_after_risk", "position_before", "position_after", "detail_json")
  d <- as.data.frame(d)[cols]
  for (c in c("ts_utc", "decision_ts_utc", "execution_ts_utc")) d[[c]] <- as.numeric(d[[c]])
  d$diagnostic_seq <- as.integer(d$diagnostic_seq); d$event_seq <- as.integer(d$event_seq)
  d$mark_age <- as.integer(d$mark_age)
  rownames(d) <- NULL
  d
}

# The durable-publication layer: one append per table at the end of a run.
r_floor_write <- function(db_path, sk, trace_frame = NULL) {
  con <- DBI::dbConnect(duckdb::duckdb(), db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbWriteTable(con, "fills", sk$fills, overwrite = TRUE)
  DBI::dbWriteTable(con, "equity", sk$equity, overwrite = TRUE)
  if (!is.null(trace_frame)) DBI::dbWriteTable(con, "trace", trace_frame, overwrite = TRUE)
  invisible(TRUE)
}
