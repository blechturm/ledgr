compiler_spike_make_stateful_data <- function(n_sessions, seed = 20261028L) {
  set.seed(seed)
  returns <- stats::rnorm(n_sessions, mean = 0.0002, sd = 0.012)
  prices <- 100 * cumprod(1 + returns)
  score <- sin(seq_len(n_sessions) / 11) + stats::rnorm(n_sessions, sd = 0.15)
  signals <- as.double(score > 0)
  list(prices = prices, signals = signals)
}

stateful_reference <- function(
  prices,
  signals,
  initial_cash,
  cost_rate,
  equity_fraction
) {
  stopifnot(length(prices) == length(signals), length(prices) >= 1L)
  n <- length(prices)
  out <- double(n + 3L)
  cash <- initial_cash
  holdings <- 0
  total_cost <- 0
  for (i in seq_len(n)) {
    equity_before <- cash + holdings * prices[i]
    target <- 0
    if (signals[i] > 0.5) {
      target <- floor(equity_before * equity_fraction / prices[i])
    }
    quantity <- target - holdings
    cost <- abs(quantity) * prices[i] * cost_rate
    cash <- cash - quantity * prices[i] - cost
    holdings <- target
    total_cost <- total_cost + cost
    out[i] <- cash + holdings * prices[i]
  }
  out[n + 1L] <- cash
  out[n + 2L] <- holdings
  out[n + 3L] <- total_cost
  out
}

stateful_quickr_source <- function() {
  function(prices, signals, initial_cash, cost_rate, equity_fraction) {
    declare(
      type(prices = double(NA)),
      type(signals = double(NA)),
      type(initial_cash = double(1)),
      type(cost_rate = double(1)),
      type(equity_fraction = double(1))
    )
    n <- length(prices)
    out <- double(n + 3)
    cash <- initial_cash
    holdings <- 0
    total_cost <- 0
    for (i in seq_len(n)) {
      equity_before <- cash + holdings * prices[i]
      target <- 0
      if (signals[i] > 0.5) {
        target <- floor(equity_before * equity_fraction / prices[i])
      }
      quantity <- target - holdings
      cost <- abs(quantity) * prices[i] * cost_rate
      cash <- cash - quantity * prices[i] - cost
      holdings <- target
      total_cost <- total_cost + cost
      out[i] <- cash + holdings * prices[i]
    }
    out[n + 1] <- cash
    out[n + 2] <- holdings
    out[n + 3] <- total_cost
    out
  }
}

stateful_ast2ast_source <- function() {
  function(prices, signals, initial_cash, cost_rate, equity_fraction) {
    argtypes(
      prices |> type(vec(double)),
      signals |> type(vec(double)),
      initial_cash |> type(double),
      cost_rate |> type(double),
      equity_fraction |> type(double)
    )
    n <- length(prices)
    out <- numeric(n + 3L)
    cash <- initial_cash
    holdings <- 0.0
    total_cost <- 0.0
    for (i in 1L:n) {
      equity_before <- cash + holdings * prices[i]
      target <- 0.0
      if (signals[i] > 0.5) {
        target <- floor(equity_before * equity_fraction / prices[i])
      }
      quantity <- target - holdings
      cost <- abs(quantity) * prices[i] * cost_rate
      cash <- cash - quantity * prices[i] - cost
      holdings <- target
      total_cost <- total_cost + cost
      out[i] <- cash + holdings * prices[i]
    }
    out[n + 1L] <- cash
    out[n + 2L] <- holdings
    out[n + 3L] <- total_cost
    return(out)
  }
}
