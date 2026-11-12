# The lean loop's skeleton (dev/lean_core/loop.R at 1a420b31) with each
# stage's work cut to the R floor's (dev/spikes/r_floor/floor.R). Not product
# code. Kept from the lean loop: run-long state in the envelope frame written
# by `<<-` from named stage functions, the list hand-offs between them, the
# `live` environment and its stage writes, the 21 typed fill columns with
# doubling capacity, the per-pulse headers, the decision residuals, the
# reconciliation row, the hooks (one `uncovered()` call per pulse), the
# tryCatch around the strategy call and the terminal transfer through
# `hooks$publish`. Cut to the floor: the context (the floor's reused
# environment), validation, planning, the lot book and reconciliation.
#
# Switches, each removing one mechanism from the full skeleton:
#   try = FALSE       no tryCatch around the strategy call
#   hook = FALSE      no per-pulse hook call
#   record = "floor"  the floor's recording only (4 fill columns, equity, cash)
# skel_fold_flat() keeps the containers and the lean recording but runs the
# loop body in the envelope's own frame: no stage functions, no hand-off
# lists, no `<<-`.

skel_hooks <- function() list(
  fold_start = function(live) function() NULL, handler = function(h, live) h,
  uncovered = function() character(), committed = function(reader) NULL,
  capacity = function(default) default, publish = function(fn) fn())

skel_fill_columns <- function(cap) list(
  pulse = integer(cap), k = integer(cap), pos = integer(cap), side = integer(cap),
  qty = numeric(cap), price = numeric(cap), fee = numeric(cap), cash_delta = numeric(cap),
  position_delta = numeric(cap), exec_ts = numeric(cap), position_before = numeric(cap),
  planned_position_after = numeric(cap), clean = logical(cap), info = character(cap),
  infos = character(cap), target = numeric(cap), strategy_target = numeric(cap),
  close_qty = numeric(cap), open_qty = numeric(cap), realized_close = numeric(cap),
  net_after = numeric(cap))

skel_strategy_env <- function(strategy) {
  env <- new.env(parent = asNamespace("stats"))
  env$ledgr_strategy_result <- function(targets, ...) list(targets = targets, state = list(...))
  environment(strategy) <- env
  strategy
}

# The fills and equity in the floor's output form, from the lean columns.
skel_finish <- function(p, fl, nf, ts_num, eq) {
  k <- seq_len(nf)
  r_floor_finish(p, list(inst = fl$pos[k], pulse = match(fl$exec_ts[k], ts_num), qty = fl$qty[k],
                         price = fl$price[k], n = nf), eq$cash + eq$positions_value, eq$cash)
}

skel_fold <- function(p, strategy, try = TRUE, hook = TRUE, record = "lean", gut = "") {
  lean_rec <- identical(record, "lean")
  hooks <- skel_hooks()
  strategy <- skel_strategy_env(strategy)
  ids <- p$ids; n <- length(ids); n_pulse <- ncol(p$close)
  ts_num <- as.numeric(p$ts)
  max_pulses <- n_pulse
  live <- new.env(parent = emptyenv())
  live$cur_ts <- NA_real_; live$cur_stage <- "fold"; live$in_pulses <- FALSE
  end_fold <- hooks$fold_start(live)
  on.exit(end_fold(), add = TRUE)
  handler <- hooks$handler(NULL, live)
  # run-long state (the lean loop's Section 19.3 containers)
  pos <- stats::setNames(numeric(n), ids)
  cash <- 1e7
  strategy_state <- list(above = stats::setNames(logical(n), ids), usable = stats::setNames(logical(n), ids))
  status <- "DONE"; processed <- 0L; full_run <- TRUE; event_seq <- 1L
  last_fully_valued <- NA_real_; last_executed <- NA_real_
  eq <- list(ts = numeric(n_pulse), cash = numeric(n_pulse), positions_value = numeric(n_pulse),
             realized_pnl = numeric(n_pulse), cost_basis = numeric(n_pulse))
  n_eq <- 0L
  fcap <- 1024L; fl <- skel_fill_columns(fcap); nf <- 0L
  dcap <- 1024L
  dr <- list(pulse = integer(dcap), k = integer(dcap), target = numeric(dcap), target_after = numeric(dcap),
             position = numeric(dcap))
  nd <- 0L
  hd_pre <- integer(n_pulse); hd_sizing <- logical(n_pulse); hd_nfill <- integer(n_pulse)
  hd_fill_start <- integer(n_pulse); hd_recon <- matrix(NA_real_, n_pulse, 6L); hd_has_recon <- logical(n_pulse)
  n_done <- 0L; n_committed <- 0L
  capacity <- as.integer(hooks$capacity(max(1L, n_pulse * n)))
  hooks$committed(list(count = function() n_committed))
  on.exit(hooks$committed(NULL), add = TRUE)
  grow <- function(x, cap) lapply(x, function(v) { length(v) <- cap; v })
  ctx <- new.env(parent = emptyenv())
  ctx$hold <- function() pos
  check_uncovered <- function() {
    u <- hooks$uncovered()
    if (length(u)) stop("uncovered: ", u[[1L]])
  }
  out <- NULL

  p1_value <- function(i) {
    live$cur_ts <- ts_num[[i]]
    live$cur_stage <- "valuation"
    close <- p$close[, i]
    pv <- sum(pos * close)
    n_eq <<- n_eq + 1L
    eq$cash[[n_eq]] <<- cash
    eq$positions_value[[n_eq]] <<- pv
    if (lean_rec) {
      last_fully_valued <<- ts_num[[i]]
      eq$ts[[n_eq]] <<- ts_num[[i]]
      eq$realized_pnl[[n_eq]] <<- 0
      eq$cost_basis[[n_eq]] <<- 0
      n_done <<- i
    }
    list(col = i, close = close, pv = pv)
  }

  p2_decide <- function(i, v1) {
    pos_start <- pos
    ctx$fast <- p$fast[, i]; ctx$slow <- p$slow[, i]; ctx$state <- strategy_state
    live$cur_stage <- "strategy"
    result <- if (try) {
      tryCatch(strategy(ctx, NULL), error = function(e) { check_uncovered(); stop(e) })
    } else strategy(ctx, NULL)
    if (hook) check_uncovered()
    if (lean_rec) {
      hd_pre[[i]] <<- 0L
      if (i == 1L) hd_sizing[[i]] <<- TRUE
    }
    list(result = result, sq = result$targets, tq = result$targets, pos_start = pos_start)
  }

  p3_plan <- function(i, v1, v2) {
    live$cur_stage <- "execution"
    batch <- NULL
    if (i < n_pulse) {
      delta <- v2$tq - pos
      hit <- which(delta != 0)
      if (length(hit)) {
        exec <- if (identical(gut, "same_bar_fill")) i else i + 1L
        batch <- list(fill = list(pos = hit, qty = unname(delta[hit]), price = p$open[hit, exec], exec = exec))
      }
    }
    list(batch = batch, stop = FALSE)
  }

  p4_apply <- function(i, v1, v2, batch) {
    n_fill <- if (is.null(batch)) 0L else length(batch$fill$pos)
    differs <- if (lean_rec) which(v2$sq != pos) else integer()
    hit <- integer()
    if (n_fill > 0L) {
      f <- batch$fill
      hit <- f$pos; d <- f$qty; price <- f$price
      live$cur_stage <- "accounting"
      rows <- nf + seq_len(n_fill)
      if (nf + n_fill > fcap) {
        while (nf + n_fill > fcap) fcap <<- fcap * 2L
        fl <<- grow(fl, fcap)
      }
      fl$pos[rows] <<- hit
      fl$qty[rows] <<- d
      fl$price[rows] <<- price
      fl$exec_ts[rows] <<- ts_num[[f$exec]]
      if (lean_rec) {
        hd_fill_start[[i]] <<- nf
        hd_nfill[[i]] <<- n_fill
        fl$pulse[rows] <<- i
        fl$k[rows] <<- hit
        fl$side[rows] <<- d > 0
        fl$fee[rows] <<- 0
        fl$cash_delta[rows] <<- -d * price
        fl$position_delta[rows] <<- d
        fl$position_before[rows] <<- pos[hit]
        fl$planned_position_after[rows] <<- v2$tq[hit]
        fl$clean[rows] <<- TRUE
        fl$info[rows] <<- ""
        fl$infos[rows] <<- ""
        fl$target[rows] <<- v2$tq[hit]
        fl$strategy_target[rows] <<- v2$sq[hit]
        fl$close_qty[rows] <<- 0
        fl$open_qty[rows] <<- 0
        fl$realized_close[rows] <<- 0
        event_seq <<- event_seq + n_fill
      }
      nf <<- nf + n_fill
      pos[hit] <<- v2$tq[hit]
      if (lean_rec) {
        fl$net_after[rows] <<- pos[hit]
        last_executed <<- max(last_executed, ts_num[[f$exec]], na.rm = TRUE)
      }
      # Cash moves fill by fill in event order, as ledgr books it.
      cc <- cash
      for (k in seq_along(hit)) cc <- cc - d[[k]] * price[[k]]
      cash <<- cc
    }
    if (lean_rec) {
      explicit <- if (length(hit)) differs[match(differs, hit, 0L) == 0L] else differs
      m <- length(explicit)
      if (m > 0L) {
        rows <- nd + seq_len(m)
        if (nd + m > dcap) {
          while (nd + m > dcap) dcap <<- dcap * 2L
          dr <<- grow(dr, dcap)
        }
        dr$pulse[rows] <<- i
        dr$k[rows] <<- explicit
        dr$target[rows] <<- v2$sq[explicit]
        dr$target_after[rows] <<- v2$tq[explicit]
        dr$position[rows] <<- v2$pos_start[explicit]
        nd <<- nd + m
      }
    }
    n_fill
  }

  p5_commit <- function(i, v1, v2, batch, n_fill) {
    live$cur_stage <- "accounting"
    if (nf > capacity) stop("Ledger event buffer exceeded the run's maximum event capacity.")
    n_committed <<- nf
    if (lean_rec) {
      hd_recon[i, ] <<- c(0, cash, 0, 0, cash, cash)
      hd_has_recon[[i]] <<- TRUE
    }
    strategy_state <<- v2$result$state
    invisible(NULL)
  }

  e_advance <- function() {
    processed <<- processed + 1L
    if (processed >= max_pulses) {
      full_run <<- FALSE
      return(FALSE)
    }
    TRUE
  }

  publish <- function() out <<- skel_finish(p, fl, nf, ts_num, eq)

  run_loop <- function() {
    live$in_pulses <- TRUE
    on.exit(live$in_pulses <- FALSE)
    for (i in seq_len(n_pulse)) {
      v1 <- p1_value(i)
      v2 <- p2_decide(i, v1)
      v3 <- p3_plan(i, v1, v2)
      if (v3$stop) break
      n_fill <- p4_apply(i, v1, v2, v3$batch)
      p5_commit(i, v1, v2, v3$batch, n_fill)
      if (!e_advance()) break
    }
    live$in_pulses <- FALSE
    hooks$publish(publish)
    invisible(NULL)
  }
  run_loop()
  out
}

# The same containers and lean recording, the loop body in one frame.
skel_fold_flat <- function(p, strategy) {
  hooks <- skel_hooks()
  strategy <- skel_strategy_env(strategy)
  ids <- p$ids; n <- length(ids); n_pulse <- ncol(p$close)
  ts_num <- as.numeric(p$ts)
  max_pulses <- n_pulse
  live <- new.env(parent = emptyenv())
  live$cur_ts <- NA_real_; live$cur_stage <- "fold"; live$in_pulses <- FALSE
  end_fold <- hooks$fold_start(live)
  on.exit(end_fold(), add = TRUE)
  handler <- hooks$handler(NULL, live)
  pos <- stats::setNames(numeric(n), ids)
  cash <- 1e7
  strategy_state <- list(above = stats::setNames(logical(n), ids), usable = stats::setNames(logical(n), ids))
  status <- "DONE"; processed <- 0L; full_run <- TRUE; event_seq <- 1L
  last_fully_valued <- NA_real_; last_executed <- NA_real_
  eq <- list(ts = numeric(n_pulse), cash = numeric(n_pulse), positions_value = numeric(n_pulse),
             realized_pnl = numeric(n_pulse), cost_basis = numeric(n_pulse))
  n_eq <- 0L
  fcap <- 1024L; fl <- skel_fill_columns(fcap); nf <- 0L
  dcap <- 1024L
  dr <- list(pulse = integer(dcap), k = integer(dcap), target = numeric(dcap), target_after = numeric(dcap),
             position = numeric(dcap))
  nd <- 0L
  hd_pre <- integer(n_pulse); hd_sizing <- logical(n_pulse); hd_nfill <- integer(n_pulse)
  hd_fill_start <- integer(n_pulse); hd_recon <- matrix(NA_real_, n_pulse, 6L); hd_has_recon <- logical(n_pulse)
  n_done <- 0L; n_committed <- 0L
  capacity <- as.integer(hooks$capacity(max(1L, n_pulse * n)))
  hooks$committed(list(count = function() n_committed))
  on.exit(hooks$committed(NULL), add = TRUE)
  grow <- function(x, cap) lapply(x, function(v) { length(v) <- cap; v })
  ctx <- new.env(parent = emptyenv())
  ctx$hold <- function() pos
  check_uncovered <- function() {
    u <- hooks$uncovered()
    if (length(u)) stop("uncovered: ", u[[1L]])
  }
  live$in_pulses <- TRUE
  for (i in seq_len(n_pulse)) {
    # P1
    live$cur_ts <- ts_num[[i]]
    live$cur_stage <- "valuation"
    close <- p$close[, i]
    pv <- sum(pos * close)
    n_eq <- n_eq + 1L
    eq$cash[[n_eq]] <- cash
    eq$positions_value[[n_eq]] <- pv
    last_fully_valued <- ts_num[[i]]
    eq$ts[[n_eq]] <- ts_num[[i]]
    eq$realized_pnl[[n_eq]] <- 0
    eq$cost_basis[[n_eq]] <- 0
    n_done <- i
    # P2
    pos_start <- pos
    ctx$fast <- p$fast[, i]; ctx$slow <- p$slow[, i]; ctx$state <- strategy_state
    live$cur_stage <- "strategy"
    result <- tryCatch(strategy(ctx, NULL), error = function(e) { check_uncovered(); stop(e) })
    check_uncovered()
    hd_pre[[i]] <- 0L
    if (i == 1L) hd_sizing[[i]] <- TRUE
    sq <- tq <- result$targets
    # P3
    live$cur_stage <- "execution"
    hit <- integer(); n_fill <- 0L
    if (i < n_pulse) {
      delta <- tq - pos
      hit <- which(delta != 0)
      n_fill <- length(hit)
    }
    # P4
    differs <- which(sq != pos)
    if (n_fill > 0L) {
      d <- unname(delta[hit]); price <- p$open[hit, i + 1L]; exec_ts <- ts_num[[i + 1L]]
      live$cur_stage <- "accounting"
      rows <- nf + seq_len(n_fill)
      if (nf + n_fill > fcap) {
        while (nf + n_fill > fcap) fcap <- fcap * 2L
        fl <- grow(fl, fcap)
      }
      fl$pos[rows] <- hit
      fl$qty[rows] <- d
      fl$price[rows] <- price
      fl$exec_ts[rows] <- exec_ts
      hd_fill_start[[i]] <- nf
      hd_nfill[[i]] <- n_fill
      fl$pulse[rows] <- i
      fl$k[rows] <- hit
      fl$side[rows] <- d > 0
      fl$fee[rows] <- 0
      fl$cash_delta[rows] <- -d * price
      fl$position_delta[rows] <- d
      fl$position_before[rows] <- pos[hit]
      fl$planned_position_after[rows] <- tq[hit]
      fl$clean[rows] <- TRUE
      fl$info[rows] <- ""
      fl$infos[rows] <- ""
      fl$target[rows] <- tq[hit]
      fl$strategy_target[rows] <- sq[hit]
      fl$close_qty[rows] <- 0
      fl$open_qty[rows] <- 0
      fl$realized_close[rows] <- 0
      event_seq <- event_seq + n_fill
      nf <- nf + n_fill
      pos[hit] <- tq[hit]
      fl$net_after[rows] <- pos[hit]
      last_executed <- max(last_executed, exec_ts, na.rm = TRUE)
      for (k in seq_along(hit)) cash <- cash - d[[k]] * price[[k]]
    }
    explicit <- if (length(hit)) differs[match(differs, hit, 0L) == 0L] else differs
    m <- length(explicit)
    if (m > 0L) {
      rows <- nd + seq_len(m)
      if (nd + m > dcap) {
        while (nd + m > dcap) dcap <- dcap * 2L
        dr <- grow(dr, dcap)
      }
      dr$pulse[rows] <- i
      dr$k[rows] <- explicit
      dr$target[rows] <- sq[explicit]
      dr$target_after[rows] <- tq[explicit]
      dr$position[rows] <- pos_start[explicit]
      nd <- nd + m
    }
    # P5
    live$cur_stage <- "accounting"
    if (nf > capacity) stop("Ledger event buffer exceeded the run's maximum event capacity.")
    n_committed <- nf
    hd_recon[i, ] <- c(0, cash, 0, 0, cash, cash)
    hd_has_recon[[i]] <- TRUE
    strategy_state <- result$state
    # E
    processed <- processed + 1L
    if (processed >= max_pulses) { full_run <- FALSE; break }
  }
  live$in_pulses <- FALSE
  out <- NULL
  hooks$publish(function() out <<- skel_finish(p, fl, nf, ts_num, eq))
  out
}
