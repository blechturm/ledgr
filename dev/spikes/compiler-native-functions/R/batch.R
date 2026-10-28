compiler_spike_make_batch_data <- function(n_sessions, n_configs, seed = 20261028L) {
  base <- compiler_spike_make_stateful_data(n_sessions, seed)
  phase <- seq_len(n_sessions) / 11
  thresholds <- seq(-0.45, 0.45, length.out = n_configs)
  score <- sin(phase) + stats::rnorm(n_sessions, sd = 0.15)
  signals <- outer(score, thresholds, `>`)
  storage.mode(signals) <- "double"
  list(
    prices = base$prices,
    signals = signals,
    equity_fractions = seq(0.5, 0.98, length.out = n_configs)
  )
}

batch_repeated_reference <- function(
  prices,
  signals,
  initial_cash,
  cost_rate,
  equity_fractions
) {
  nc <- ncol(signals)
  out <- matrix(0, nrow(signals), nc)
  for (j in seq_len(nc)) {
    one <- stateful_reference(
      prices,
      signals[, j],
      initial_cash,
      cost_rate,
      equity_fractions[j]
    )
    out[, j] <- one[seq_len(nrow(signals))]
  }
  out
}

batch_matrix_r <- function(
  prices,
  signals,
  initial_cash,
  cost_rate,
  equity_fractions
) {
  nr <- nrow(signals)
  nc <- ncol(signals)
  out <- matrix(0, nr, nc)
  cash <- rep(initial_cash, nc)
  holdings <- numeric(nc)
  for (i in seq_len(nr)) {
    equity_before <- cash + holdings * prices[i]
    target <- ifelse(
      signals[i, ] > 0.5,
      floor(equity_before * equity_fractions / prices[i]),
      0
    )
    quantity <- target - holdings
    cost <- abs(quantity) * prices[i] * cost_rate
    cash <- cash - quantity * prices[i] - cost
    holdings <- target
    out[i, ] <- cash + holdings * prices[i]
  }
  out
}

batch_quickr_source <- function() {
  function(prices, signals, initial_cash, cost_rate, equity_fractions) {
    declare(
      type(prices = double(NA)),
      type(signals = double(NA, NA)),
      type(initial_cash = double(1)),
      type(cost_rate = double(1)),
      type(equity_fractions = double(NA))
    )
    nr <- nrow(signals)
    nc <- ncol(signals)
    out <- matrix(0, nr, nc)
    for (j in seq_len(nc)) {
      cash <- initial_cash
      holdings <- 0
      for (i in seq_len(nr)) {
        equity_before <- cash + holdings * prices[i]
        target <- 0
        if (signals[i, j] > 0.5) {
          target <- floor(equity_before * equity_fractions[j] / prices[i])
        }
        quantity <- target - holdings
        cost <- abs(quantity) * prices[i] * cost_rate
        cash <- cash - quantity * prices[i] - cost
        holdings <- target
        out[i, j] <- cash + holdings * prices[i]
      }
    }
    out
  }
}

batch_quickr_parallel_source <- function() {
  function(prices, signals, initial_cash, cost_rate, equity_fractions) {
    declare(
      type(prices = double(NA)),
      type(signals = double(NA, NA)),
      type(initial_cash = double(1)),
      type(cost_rate = double(1)),
      type(equity_fractions = double(NA))
    )
    nr <- nrow(signals)
    nc <- ncol(signals)
    out <- matrix(0, nr, nc)
    declare(parallel())
    for (j in seq_len(nc)) {
      cash <- initial_cash
      holdings <- 0
      for (i in seq_len(nr)) {
        equity_before <- cash + holdings * prices[i]
        target <- 0
        if (signals[i, j] > 0.5) {
          target <- floor(equity_before * equity_fractions[j] / prices[i])
        }
        quantity <- target - holdings
        cost <- abs(quantity) * prices[i] * cost_rate
        cash <- cash - quantity * prices[i] - cost
        holdings <- target
        out[i, j] <- cash + holdings * prices[i]
      }
    }
    out
  }
}

batch_ast2ast_source <- function() {
  function(prices, signals, initial_cash, cost_rate, equity_fractions) {
    argtypes(
      prices |> type(vec(double)),
      signals |> type(mat(double)),
      initial_cash |> type(double),
      cost_rate |> type(double),
      equity_fractions |> type(vec(double))
    )
    nr <- nrow(signals)
    nc <- ncol(signals)
    out <- matrix(0.0, nr, nc)
    for (j in 1L:nc) {
      cash <- initial_cash
      holdings <- 0.0
      for (i in 1L:nr) {
        equity_before <- cash + holdings * prices[i]
        target <- 0.0
        if (signals[i, j] > 0.5) {
          target <- floor(equity_before * equity_fractions[j] / prices[i])
        }
        quantity <- target - holdings
        cost <- abs(quantity) * prices[i] * cost_rate
        cash <- cash - quantity * prices[i] - cost
        holdings <- target
        out[i, j] <- cash + holdings * prices[i]
      }
    }
    return(out)
  }
}
