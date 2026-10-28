pfb_generate_market <- function(n_sessions, n_instruments, seed = 41L) {
  stopifnot(n_sessions >= 3L, n_instruments >= 1L)
  old_seed <- if (exists(".Random.seed", .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", .GlobalEnv, inherits = FALSE)
  } else NULL
  on.exit({
    if (is.null(old_seed)) {
      if (exists(".Random.seed", .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
    } else assign(".Random.seed", old_seed, envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(seed)
  t <- seq_len(n_sessions)
  ids <- sprintf("I%04d", seq_len(n_instruments))
  base <- 60 + seq_len(n_instruments) / 5
  close <- vapply(seq_len(n_instruments), function(j) {
    base[[j]] * exp(0.00015 * t + 0.012 * sin(t / 13 + j / 7) +
      cumsum(stats::rnorm(n_sessions, 0, 0.004)))
  }, numeric(n_sessions))
  open <- rbind(close[1L, ], close[-n_sessions, , drop = FALSE] *
    (1 + outer(seq_len(n_sessions - 1L), seq_len(n_instruments),
      function(i, j) 0.0008 * sin(i / 5 + j / 11))))
  colnames(close) <- colnames(open) <- ids
  list(open = open, close = close, instrument_ids = ids)
}

pfb_make_params <- function(n_configs,
                            family = c("signal", "stateful", "constant"),
                            feature_mode = c("common", "varying"),
                            fee_rate = 0) {
  family <- match.arg(family)
  feature_mode <- match.arg(feature_mode)
  i <- seq_len(n_configs)
  lookbacks <- if (identical(feature_mode, "common")) {
    rep(20L, n_configs)
  } else {
    rep(c(5L, 20L, 63L), length.out = n_configs)
  }
  data.frame(
    candidate_id = sprintf("C%05d", i),
    family = family,
    lookback = lookbacks,
    threshold = if (identical(family, "stateful")) {
      0.02 + (i %% 5L) * 0.005
    } else {
      -0.005 + (i %% 7L) * 0.002
    },
    allocation = 0.55 + (i %% 4L) * 0.05,
    fee_rate = fee_rate,
    constant_qty = 1 + (i %% 3L),
    stringsAsFactors = FALSE
  )
}

pfb_feature_matrix <- function(close, lookback) {
  nr <- nrow(close)
  out <- matrix(NA_real_, nr, ncol(close), dimnames = dimnames(close))
  if (lookback < nr) {
    rows <- (lookback + 1L):nr
    out[rows, ] <- close[rows, , drop = FALSE] /
      close[rows - lookback, , drop = FALSE] - 1
  }
  out
}

pfb_prepare <- function(market, params) {
  lookbacks <- sort(unique(as.integer(params$lookback)), method = "radix")
  features <- stats::setNames(
    lapply(lookbacks, function(x) pfb_feature_matrix(market$close, x)),
    as.character(lookbacks)
  )
  n_sessions <- nrow(market$close)
  views <- lapply(seq_len(n_sessions), function(i) {
    list(
      open = market$open[i, ],
      close = market$close[i, ],
      final_pulse = i >= n_sessions
    )
  })
  list(
    open = market$open,
    close = market$close,
    instrument_ids = market$instrument_ids,
    features = features,
    views = views,
    n_sessions = n_sessions,
    n_instruments = ncol(market$close),
    unique_lookbacks = lookbacks
  )
}

pfb_prepare_params <- function(params) {
  lapply(seq_len(nrow(params)), function(i) as.list(params[i, , drop = FALSE]))
}

pfb_serialized_bytes <- function(x) {
  length(serialize(x, NULL, version = 3L))
}

pfb_counter <- function() {
  x <- new.env(parent = emptyenv())
  x$market_preparations <- 0L
  x$feature_extractions <- 0L
  x$context_builds <- 0L
  x
}

pfb_shared_pulse <- function(prepared, pulse, counter = NULL) {
  if (!is.null(counter)) {
    counter$market_preparations <- counter$market_preparations + 1L
    counter$feature_extractions <- counter$feature_extractions + length(prepared$features)
  }
  list(
    pulse = pulse,
    market = prepared$views[[pulse]],
    features = lapply(prepared$features, function(x) x[pulse, ])
  )
}

pfb_candidate_context <- function(prepared, pulse, param, shared = NULL, counter = NULL) {
  if (is.null(shared)) {
    if (!is.null(counter)) {
      counter$market_preparations <- counter$market_preparations + 1L
      counter$feature_extractions <- counter$feature_extractions + 1L
    }
    market <- prepared$views[[pulse]]
    feature <- prepared$features[[as.character(param$lookback)]][pulse, ]
  } else {
    market <- shared$market
    feature <- shared$features[[as.character(param$lookback)]]
  }
  if (!is.null(counter)) counter$context_builds <- counter$context_builds + 1L
  list(
    pulse = pulse,
    open = market$open,
    close = market$close,
    feature = feature,
    final_pulse = pulse >= prepared$n_sessions
  )
}

pfb_state_new <- function(prepared, initial_cash = 1e6, retention = "summary") {
  x <- new.env(parent = emptyenv())
  x$cash <- initial_cash
  x$positions <- stats::setNames(rep(0, prepared$n_instruments), prepared$instrument_ids)
  x$peak_equity <- initial_cash
  x$pending_target <- NULL
  x$fill_count <- 0L
  x$turnover <- 0
  x$last_equity <- initial_cash
  x$retention <- retention
  if (identical(retention, "full")) {
    x$cash_history <- rep(NA_real_, prepared$n_sessions)
    x$equity_history <- rep(NA_real_, prepared$n_sessions)
    x$positions_history <- matrix(
      NA_real_, prepared$n_sessions, prepared$n_instruments,
      dimnames = list(NULL, prepared$instrument_ids)
    )
    x$fills <- vector("list", prepared$n_sessions)
  }
  x
}

pfb_strategy_targets <- function(context, param, state) {
  if (context$final_pulse) return(state$positions)
  if (identical(param$family, "constant")) {
    return(stats::setNames(rep(param$constant_qty, length(context$close)), names(context$close)))
  }
  equity <- state$cash + sum(state$positions * context$close)
  score <- context$feature
  score[!is.finite(score)] <- -Inf
  selected <- which(score > param$threshold)
  if (length(selected) > 5L) {
    selected <- selected[order(score[selected], decreasing = TRUE, method = "radix")[1:5]]
  }
  target <- rep(0, length(context$close))
  if (identical(param$family, "stateful")) {
    drawdown <- if (state$peak_equity > 0) 1 - equity / state$peak_equity else 0
    if (drawdown > param$threshold) return(stats::setNames(target, names(context$close)))
  }
  if (length(selected) > 0L) {
    budget <- max(0, equity * param$allocation) / length(selected)
    target[selected] <- floor(budget / context$close[selected])
  }
  if (identical(param$family, "stateful")) {
    target <- floor((target + state$positions) / 2)
  }
  stats::setNames(target, names(context$close))
}

pfb_execute_pulse <- function(param, context, state) {
  fills <- NULL
  if (!is.null(state$pending_target)) {
    delta <- state$pending_target - state$positions
    active <- which(delta != 0)
    if (length(active) > 0L) {
      prices <- context$open[active]
      fees <- abs(delta[active]) * prices * param$fee_rate
      cash_delta <- -sum(delta[active] * prices) - sum(fees)
      state$cash <- state$cash + cash_delta
      state$positions[active] <- state$pending_target[active]
      state$fill_count <- state$fill_count + length(active)
      state$turnover <- state$turnover + sum(abs(delta[active]) * prices)
      if (identical(state$retention, "full")) {
        fills <- data.frame(
          pulse = context$pulse,
          instrument_id = names(state$positions)[active],
          quantity = as.numeric(delta[active]),
          price = as.numeric(prices),
          fee = as.numeric(fees),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  equity <- state$cash + sum(state$positions * context$close)
  state$peak_equity <- max(state$peak_equity, equity)
  state$pending_target <- if (context$final_pulse) NULL else
    pfb_strategy_targets(context, param, state)
  state$last_equity <- equity
  if (identical(state$retention, "full")) {
    state$cash_history[[context$pulse]] <- state$cash
    state$equity_history[[context$pulse]] <- equity
    state$positions_history[context$pulse, ] <- state$positions
    state$fills[context$pulse] <- list(fills)
  }
  invisible(state)
}

pfb_summarize_state <- function(state, candidate_id) {
  out <- list(
    candidate_id = candidate_id,
    cash = state$cash,
    positions = state$positions,
    equity = state$last_equity,
    fill_count = state$fill_count,
    turnover = state$turnover
  )
  if (identical(state$retention, "full")) {
    out$cash_history <- state$cash_history
    out$equity_history <- state$equity_history
    out$positions_history <- state$positions_history
    out$fills <- state$fills
  }
  out
}

pfb_counter_values <- function(counter) {
  c(
    market_preparations = counter$market_preparations,
    feature_extractions = counter$feature_extractions,
    context_builds = counter$context_builds
  )
}
